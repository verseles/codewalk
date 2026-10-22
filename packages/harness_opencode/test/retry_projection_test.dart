import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_test_data.dart';
import 'history_test_data.dart';
import 'step_usage_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Every retry input here is contract-derived (`plan/12` §5): no 2.0.22
// capture holds a `session.retry.scheduled` frame, and #243 keeps natural
// retry evidence inconclusive.

Matcher failsWith(OpenCodeExecutionProjectionFailure failure) => throwsA(
  isA<OpenCodeExecutionProjectionException>().having(
    (e) => e.failure,
    'failure',
    failure,
  ),
);

void main() {
  final received = DateTime.utc(2026, 10, 13);
  final previous = ExecutionOutcome(
    const OpenValue.known(ExecutionOutcomeKind.succeeded),
  );

  /// Routes [frame] through the single entry point and reduces its events.
  SessionState apply(
    SessionState state,
    Object? frame,
    int seq, {
    DateTime? at,
  }) {
    for (final event in projectOpenCodeEvent(
      frame,
      state,
      sourceVersion: '2.0.22',
      position: observedPosition(seq),
      receivedAt: at ?? received,
    )) {
      state = reduce(state, event).state;
    }
    return state;
  }

  SessionState running() => reduce(
    SessionState(historyRef),
    ExecutionChanged(
      meta: EventMeta(
        owner: SessionOwner(historyRef),
        position: observedPosition(0),
        receivedAt: received,
        source: SourceProvenance(
          harness: historyRef.harnessRef,
          version: '2.0.22',
          nativeType: 'seed',
        ),
      ),
      state: ExecutionState(
        kind: const OpenValue.known(ExecutionKind.running),
        lastOutcome: previous,
      ),
    ),
  ).state;

  test('a scheduled retry holds the execution in retrying with its wait', () {
    final event = projectRetry(retryFrame()).single as RetryScheduled;
    expect(event.attempt, 1);
    expect(event.at, received.add(const Duration(seconds: 30)));
    expect(event.error.kind.known, ErrorKind.unknown);
    expect(event.error.rawType, 'provider.rate-limit');
    expect(event.error.rawMessage, '');
    expect(event.meta.source.nativeType, 'session.retry.scheduled');
    expect(event.meta.source.durability.known, Durability.durable);
    expect(event.meta.source.extra!.value, {
      'nativeCreated': 1791849600000,
      'nativeDurableVersion': 1,
      'nativeMessageId': 'msg_step',
      'nativeRetryAt': 1791849630000,
      'errorContentNotProjected': true,
    });
    expect(
      jsonEncode(event.meta.source.extra!.value),
      isNot(contains('fake-private')),
    );

    final state = apply(running(), retryFrame(), 1);
    expect(state.execution!.kind.known, ExecutionKind.retrying);
    expect(state.execution!.retryAt, received.add(const Duration(seconds: 30)));
    expect(state.execution!.error!.rawType, 'provider.rate-limit');
    expect(identical(state.execution!.lastOutcome, previous), isTrue);
  });

  test('the wait never outlasts its own delay or the server deadline', () {
    DateTime deadline(DateTime arrival, {num? at}) =>
        (projectRetry(
                  retryFrame(at: at ?? 1791849630000),
                  receivedAt: arrival,
                ).single
                as RetryScheduled)
            .at;
    Duration wait(DateTime arrival, {num? at}) =>
        deadline(arrival, at: at).difference(received);

    // A device clock behind the server's keeps the server's 30 s delay.
    expect(
      wait(received.subtract(const Duration(seconds: 10))),
      const Duration(seconds: 20),
    );
    // A late frame, or a device clock ahead, keeps the server's deadline.
    expect(
      wait(received.add(const Duration(seconds: 10))),
      const Duration(seconds: 30),
    );
    // A deadline already past, or a negative delay, shows no wait.
    final after = received.add(const Duration(seconds: 40));
    expect(deadline(after), after);
    expect(deadline(received, at: 1791849500000), received);
  });

  test('the next step start or the execution end clears the retry', () {
    final retrying = apply(running(), retryFrame(), 1);
    final resumed = apply(retrying, stepFrame('started'), 2);
    expect(resumed.execution!.kind.known, ExecutionKind.running);
    expect(resumed.execution!.retryAt, isNull);
    expect(resumed.execution!.error, isNull);
    expect(identical(resumed.execution!.lastOutcome, previous), isTrue);

    // A step start outside a retry wait leaves the execution to its producer.
    final step = projectOpenCodeStepUsageEvent(
      stepFrame('started'),
      running(),
      sourceVersion: '2.0.22',
      position: observedPosition(3),
      receivedAt: received,
    );
    expect(step, isEmpty);

    for (final (frame, kind) in [
      (executionFrame('succeeded'), ExecutionKind.idle),
      (executionFrame('failed'), ExecutionKind.idle),
      (executionFrame('interrupted', reason: 'user'), ExecutionKind.idle),
      (
        executionFrame('interrupted', reason: 'shutdown'),
        ExecutionKind.interruptedPendingResume,
      ),
      (executionFrame('started'), ExecutionKind.running),
    ]) {
      final ended = apply(retrying, frame, 2);
      expect(ended.execution!.kind.known, kind, reason: '${frame['type']}');
      expect(ended.execution!.retryAt, isNull);
    }
  });

  test('a retry of another session or another type is not projected', () {
    expect(projectRetry(retryFrame(session: 'ses_b')), isEmpty);
    expect(projectRetry(executionFrame('started')), isEmpty);
  });

  test('malformed and unsupported retries fail atomically by category', () {
    const m = OpenCodeExecutionProjectionFailure.malformed;
    const v = OpenCodeExecutionProjectionFailure.unsupportedVersion;
    const u = OpenCodeExecutionProjectionFailure.unsupportedValue;
    for (final (input, failure)
        in <(Object?, OpenCodeExecutionProjectionFailure)>[
          (null, m),
          ({'type': 'session.retry.scheduled'}, m),
          (retryFrame(message: 'evt_step'), m),
          (retryFrame(attempt: 0), m),
          (retryFrame(attempt: 1.5), m),
          (retryFrame(attempt: '1'), m),
          (retryFrame(at: null), m),
          (retryFrame(at: double.infinity), m),
          (retryFrame(at: -1), m),
          (retryFrame(created: -1), m),
          (retryFrame(error: null), m),
          (retryFrame(error: {'type': ''}), u),
          (retryFrame(version: 2), v),
        ]) {
      expect(() => projectRetry(input), failsWith(failure), reason: '$input');
    }
    expect(() => projectRetry(retryFrame(), version: '2.0.21'), failsWith(v));
  });
}
