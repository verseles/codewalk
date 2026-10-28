import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_test_data.dart';
import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;
import 'tool_test_data.dart';

Matcher failsWith(OpenCodeExecutionProjectionFailure failure) => throwsA(
  isA<OpenCodeExecutionProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeExecutionProjectionException(${failure.name})',
      ),
);

ExecutionState stateOf(SessionEvent event) => (event as ExecutionChanged).state;
TurnOutcome outcomeOf(SessionEvent event) =>
    (event as ItemUpserted).item as TurnOutcome;

void main() {
  final previous = ExecutionOutcome(
    const OpenValue.known(ExecutionOutcomeKind.succeeded),
  );
  SessionState withExecution(ExecutionState execution) => reduce(
    SessionState(historyRef),
    ExecutionChanged(
      meta: EventMeta(
        owner: SessionOwner(historyRef),
        position: observedPosition(0),
        receivedAt: DateTime.utc(2026, 10, 13),
        source: SourceProvenance(
          harness: historyRef.harnessRef,
          version: '2.0.22',
          nativeType: 'seed',
        ),
      ),
      state: execution,
    ),
  ).state;

  test('started maps to running and keeps the previous outcome', () {
    final empty = projectExecution(executionFrame('started'));
    expect(empty, hasLength(1));
    expect(executionJson(stateOf(empty.single)), {
      'kind': 'running',
      'retryAt': null,
      'error': null,
      'lastOutcome': null,
    });
    final retrying = withExecution(
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.retrying),
        retryAt: DateTime.utc(2026),
        error: ErrorInfo(
          kind: const OpenValue.known(ErrorKind.unknown),
          rawType: 'x',
          rawMessage: '',
        ),
        lastOutcome: previous,
      ),
    );
    final state = stateOf(
      projectExecution(executionFrame('started'), current: retrying).single,
    );
    expect(state.kind.known, ExecutionKind.running);
    expect(state.retryAt, isNull);
    expect(state.error, isNull);
    expect(identical(state.lastOutcome, previous), isTrue);
    expect(() => (empty as List).add(empty.single), throwsUnsupportedError);
  });

  test(
    'terminal frames emit idle execution then a history-matching outcome',
    () {
      for (final (phase, reason, kind) in [
        ('succeeded', null, 'succeeded'),
        ('failed', null, 'failed'),
        ('interrupted', 'user', 'interrupted'),
        ('interrupted', 'superseded', 'interrupted'),
        ('interrupted', 'inactivity', 'interrupted'),
      ]) {
        final events = projectExecution(
          executionFrame(phase, id: 'evt_turn1', reason: reason),
        );
        expect(events.map((e) => e.runtimeType), [
          ExecutionChanged,
          ItemUpserted,
        ]);
        final state = stateOf(events.first);
        expect(state.kind.known, ExecutionKind.idle);
        expect(state.retryAt, isNull);
        expect(state.error, isNull);
        expect(state.lastOutcome!.kind.value, kind);
        expect(state.lastOutcome!.reason, reason);
        final item = outcomeOf(events.last);
        // The server reports a failed turn's error on its last assistant
        // message too; the history attaches it to the idle row.
        final history = projectOpenCodeHistory(
          [
            assistant(
              'a1',
              const [],
              fields: {
                'error': (executionFrame('failed')['data'] as Map)['error'],
              },
            ),
            message('turn1', 'idle', {'outcome': kind}),
          ],
          historyRef,
          sourceVersion: '2.0.22',
        ).whereType<TurnOutcome>().single;
        expect(item.id, history.id);
        expect(item.meta.anchor, history.meta.anchor);
        expect(item.status, history.status);
        expect(item.kind, history.kind);
        expect(item.meta.ordinal, history.meta.ordinal);
        expect(errorJson(item.error), errorJson(history.error));
        expect(
          item.error?.kind.known,
          kind == 'failed' ? ErrorKind.auth : null,
        );
        expect(item.reason, isNull);
        expect(item.turnId, isNull);
        expect(item.generation, isNot(history.generation));
        expect(
          item.generation,
          '["live","${historyRef.storageKey.replaceAll('"', r'\"')}",'
          '"msg_turn1","observer-a","epoch-a"]',
        );
      }
    },
  );

  test('shutdown keeps the claim pending without an outcome item', () {
    final current = withExecution(
      ExecutionState(
        kind: const OpenValue.known(ExecutionKind.running),
        lastOutcome: previous,
      ),
    );
    final events = projectExecution(
      executionFrame('interrupted', reason: 'shutdown'),
      current: current,
    );
    expect(events, hasLength(1));
    final state = stateOf(events.single);
    expect(state.kind.known, ExecutionKind.interruptedPendingResume);
    expect(identical(state.lastOutcome, previous), isTrue);
    final extra = events.single.meta.source.extra!.value as Map;
    expect(extra['interruptReason'], 'shutdown');
    expect(extra.containsKey('nativeMessageId'), isFalse);
    var resumed = applyExecution(
      executionFrame('interrupted', reason: 'shutdown'),
      SessionState(historyRef),
      1,
    );
    expect(resumed.timeline, isEmpty);
    resumed = applyExecution(
      executionFrame('succeeded', id: 'evt_resumed'),
      resumed,
      2,
    );
    expect(resumed.execution!.kind.known, ExecutionKind.idle);
    expect(resumed.timeline.single, isA<TurnOutcome>());
  });

  test('a failure is typed by its type and never reads status or body', () {
    final events = projectExecution(
      executionFrame(
        'failed',
        error: PrivateToolFields(
          {
            'type': 'provider.quota',
            'message':
                'Monthly limit reached. Authorization: Bearer abc.def.ghi',
            'status': 429,
            'response': {'body': 'fake-private-body'},
          },
          {'status', 'response'},
        ),
      ),
    );
    final outcome = stateOf(events.first).lastOutcome!;
    final typed = {
      'kind': 'quota',
      'rawType': 'provider.quota',
      'rawMessage': 'Monthly limit reached. Authorization: Bearer [redacted]',
      'retryable': false,
      'retryAt': null,
      'action': 'changeModel',
      'details': {'messageRedacted': true},
    };
    expect(errorJson(outcome.error), typed);
    expect(stateOf(events.first).error, isNull);
    // The card's host carries the same error as the execution state.
    expect(errorJson(outcomeOf(events.last).error), typed);
    for (final event in events) {
      final manifest = executionManifest(event);
      expect(manifest, isNot(contains('fake-private')));
      expect(manifest, isNot(contains('abc.def.ghi')));
      expect(manifest, isNot(contains('errorContentNotProjected')));
    }
    final unknown = projectExecution(
      executionFrame('failed', error: {'type': 'future.kind', 'message': ''}),
    );
    final future = outcomeOf(unknown.last).error!;
    expect(future.kind.known, ErrorKind.unknown);
    expect(future.rawType, 'future.kind');
    expect(future.rawMessage, '');
    expect(future.action!.known, ErrorAction.changeModel);
  });

  test('an aborted failure keeps the plain outcome marker', () {
    final events = projectExecution(
      executionFrame(
        'failed',
        error: {'type': 'aborted', 'message': 'Step interrupted'},
      ),
    );
    final error = stateOf(events.first).lastOutcome!.error!;
    expect(error.rawType, 'aborted');
    expect(error.kind.known, ErrorKind.unknown);
    expect(error.action, isNull);
    expect(outcomeOf(events.last).kind.known, OutcomeKind.failed);
    expect(outcomeOf(events.last).error, isNull);
  });

  test('a failure without a message keeps an empty one', () {
    final events = projectExecution(
      executionFrame('failed', error: {'type': 'provider.timeout'}),
    );
    final error = outcomeOf(events.last).error!;
    expect(error.kind.known, ErrorKind.network);
    expect(error.rawMessage, '');
    expect(error.details, isNull);
    expect(
      () => projectExecution(
        executionFrame(
          'failed',
          error: {'type': 'provider.timeout', 'message': 42},
        ),
      ),
      failsWith(OpenCodeExecutionProjectionFailure.malformed),
    );
  });

  test('provenance is identical for both events of one frame', () {
    final events = projectExecution(
      executionFrame('interrupted', id: 'evt_p', reason: 'user', seq: 7.0),
      seq: 3,
    );
    for (final event in events) {
      expect(event.meta.owner.scopeKey, SessionOwner(historyRef).scopeKey);
      expect(event.meta.position, observedPosition(3));
      expect(event.meta.receivedAt, DateTime.utc(2026, 10, 13));
      expect(event.meta.rawRef, isNull);
      final source = event.meta.source;
      expect(source.harness, historyRef.harnessRef);
      expect(source.version, '2.0.22');
      expect(source.nativeType, 'session.execution.interrupted');
      expect(source.nativeEventId, 'evt_p');
      expect(source.aggregateId, 'ses_a');
      expect(source.aggregateSeq, BigInt.from(7));
      expect(source.durability.known, Durability.durable);
      expect(source.nativeCursor, isNull);
      expect(source.extra!.value, {
        'nativeCreated': 1000,
        'nativeDurableVersion': 1,
        'nativeMessageId': 'msg_p',
        'interruptReason': 'user',
      });
    }
    expect(
      projectExecution(
        executionFrame('started'),
      ).single.meta.source.extra!.value,
      {'nativeCreated': 1000, 'nativeDurableVersion': 1},
    );
  });

  test('unrelated types and foreign sessions are ignored', () {
    expect(projectExecution(toolFrame('input.started')), isEmpty);
    expect(
      projectExecution({
        ...executionFrame('started'),
        'type': 'session.execution.future',
      }),
      isEmpty,
    );
    expect(projectExecution({'type': 'session.retry.scheduled'}), isEmpty);
    expect(
      projectExecution(
        executionFrame('started', session: 'ses_other'),
        version: '1.0.0',
      ),
      isEmpty,
    );
  });

  test('malformed and unsupported frames fail atomically by category', () {
    Map<String, Object?> edit(
      Map<String, Object?> frame,
      void Function(Map<String, Object?> data, Map<String, Object?> durable)
      change,
    ) {
      final data = Map<String, Object?>.of(
        frame['data']! as Map<String, Object?>,
      );
      final durable = Map<String, Object?>.of(
        frame['durable']! as Map<String, Object?>,
      );
      change(data, durable);
      return {...frame, 'data': data, 'durable': durable};
    }

    const m = OpenCodeExecutionProjectionFailure.malformed;
    const v = OpenCodeExecutionProjectionFailure.unsupportedVersion;
    const u = OpenCodeExecutionProjectionFailure.unsupportedValue;
    final started = executionFrame('started');
    for (final (input, failure)
        in <(Object?, OpenCodeExecutionProjectionFailure)>[
          (null, m),
          ({'type': 7}, m),
          ({'type': 'session.execution.started'}, m),
          ({...started, 'id': 'msg_x'}, m),
          ({...started, 'created': double.nan}, m),
          ({...started, 'created': null}, m),
          (Map<String, Object?>.of(started)..remove('durable'), m),
          (edit(started, (d, du) => d['sessionID'] = 'x_a'), m),
          (edit(started, (d, du) => du['aggregateID'] = 'ses_b'), m),
          (edit(started, (d, du) => du['seq'] = -1), m),
          (edit(started, (d, du) => du['seq'] = 1.5), m),
          (edit(started, (d, du) => du['seq'] = 9007199254740992), m),
          (edit(started, (d, du) => du['version'] = 2), v),
          (executionFrame('failed', error: null), m),
          (executionFrame('failed', error: {'type': 3}), m),
          (executionFrame('failed', error: {'type': ''}), u),
          (executionFrame('failed', error: {'type': 'a\ud800'}), m),
          (edit(executionFrame('interrupted'), (d, du) => d['reason'] = 3), m),
          (executionFrame('interrupted', reason: 'future'), u),
        ]) {
      expect(
        () => projectExecution(input),
        failsWith(failure),
        reason: '$input',
      );
    }
    expect(() => projectExecution(started, version: '2.0.21'), failsWith(v));
    expect(
      () => projectExecution(started, version: '2.1.0-beta.1'),
      failsWith(v),
    );
    expect(projectExecution(started, version: '2.0.22+build.1'), hasLength(1));
  });

  test('selected identity strings are bounded in UTF-8 bytes', () {
    const l = OpenCodeExecutionProjectionFailure.limitExceeded;
    final atCap = 'evt_${'a' * 4092}';
    expect(
      projectExecution(executionFrame('started', id: atCap)),
      hasLength(1),
    );
    expect(
      () => projectExecution(executionFrame('started', id: '${atCap}a')),
      failsWith(l),
    );
    expect(
      () =>
          projectExecution(executionFrame('started', id: 'evt_${'é' * 2047}')),
      failsWith(l),
    );
    final typeAtCap = 'a' * 4096;
    expect(
      stateOf(
        projectExecution(
          executionFrame('failed', error: {'type': typeAtCap}),
        ).first,
      ).lastOutcome!.error!.rawType,
      typeAtCap,
    );
    expect(
      () => projectExecution(
        executionFrame('failed', error: {'type': '${typeAtCap}a'}),
      ),
      failsWith(l),
    );
    expect(
      () => projectOpenCodeExecutionEvent(
        executionFrame('started'),
        SessionState(historyRef),
        sourceVersion: '2.0.22',
        position: StreamPosition(
          id: 'o' * 4097,
          epoch: 'epoch-a',
          seq: BigInt.one,
        ),
        receivedAt: DateTime.utc(2026),
      ),
      failsWith(l),
    );
  });

  test('a resident item of another kind under the outcome ID is rejected', () {
    final history = projectOpenCodeHistory(
      [
        message('exec', 'synthetic', {'text': 'x'}),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    ).single;
    final collision = Notice(
      meta: ItemMeta(
        id: outcomeOf(projectExecution(executionFrame('succeeded')).last).id,
        generation: history.generation,
        status: history.status,
        source: history.source,
      ),
      kind: const OpenValue.known(NoticeKind.system),
      text: 'x',
    );
    expect(
      () => projectExecution(
        executionFrame('succeeded'),
        current: residentState(collision),
      ),
      failsWith(OpenCodeExecutionProjectionFailure.itemKindMismatch),
    );
  });

  test('reduction composes with history rows, ordering and duplicates', () {
    final historyItem = projectOpenCodeHistory(
      [
        message('exec', 'idle', {'outcome': 'succeeded'}),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    ).single;
    var state = residentState(historyItem);
    final events = projectExecution(
      executionFrame('succeeded'),
      current: state,
      seq: 2,
    );
    for (final event in events) {
      final result = reduce(state, event);
      expect(result.effects.every((e) => e is Notify), isTrue);
      state = result.state;
    }
    expect(state.timeline.single.id, historyItem.id);
    expect(state.execution!.kind.known, ExecutionKind.idle);
    final again = applyExecution(executionFrame('succeeded'), state, 2);
    expect(
      again.timeline.map(semanticItem).toList(),
      state.timeline.map(semanticItem).toList(),
    );
    expect(executionJson(again.execution!), executionJson(state.execution!));
    final stale = applyExecution(
      executionFrame('started', id: 'evt_old'),
      state,
      1,
    );
    expect(stale.execution!.kind.known, ExecutionKind.idle);
    final unsettled = applyExecution(
      executionFrame('succeeded', id: 'evt_t'),
      startedTool(),
      2,
    );
    expect(
      unsettled.timeline.whereType<ToolCall>().single.status.known,
      ItemStatus.streaming,
    );
    expect(unsettled.timeline.last, isA<TurnOutcome>());
  });
}
