import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'step_usage_test_data.dart';

Matcher failsWith(OpenCodeStepUsageProjectionFailure failure) => throwsA(
  isA<OpenCodeStepUsageProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeStepUsageProjectionException(${failure.name})',
      ),
);

UsageObservation usageOf(SessionEvent event) =>
    (event as UsageObserved).observation;

Map<String, Object?> edit(
  Map<String, Object?> frame,
  void Function(Map<String, Object?> frame) change,
) {
  final copy = jsonDecode(jsonEncode(frame)) as Map<String, Object?>;
  change(copy);
  return copy;
}

Map<String, Object?> dataOf(Map<String, Object?> frame) =>
    frame['data']! as Map<String, Object?>;

void main() {
  final empty = SessionState(historyRef);

  test('started and streamed are validated and emit nothing', () {
    expect(projectStepUsage(stepFrame('started')), isEmpty);
    expect(projectStepUsage(stepFrame('streamed')), isEmpty);
    expect(
      () => projectStepUsage(
        edit(stepFrame('started'), (f) => dataOf(f)['started'] = -1),
      ),
      failsWith(OpenCodeStepUsageProjectionFailure.malformed),
    );
    expect(
      () => projectStepUsage(
        edit(stepFrame('started'), (f) => dataOf(f)['model'] = 'm'),
      ),
      failsWith(OpenCodeStepUsageProjectionFailure.malformed),
    );
  });

  test('an ended step is one partial turn usage observation', () {
    final events = projectStepUsage(stepFrame('ended'));
    expect(events.single, isA<UsageObserved>());
    expect(usageJson(usageOf(events.single)), {
      'id': 'step:msg_step',
      'scope': 'turn',
      'source': 'native',
      'observedAt': DateTime.fromMillisecondsSinceEpoch(
        1000,
        isUtc: true,
      ).toIso8601String(),
      'tokens': [10, 2, 1, 3, 0],
      'cost': {
        'amount': 0.25,
        'currency': 'USD',
        'partial': true,
        'cumulative': false,
      },
      'partial': true,
      'cumulative': false,
      'aggregationKey': 'step:msg_step',
    });
    expect(() => (events as List).add(events.single), throwsUnsupportedError);
    for (final finish in [
      'stop',
      'length',
      'tool-calls',
      'content-filter',
      'error',
      'unknown',
    ]) {
      final frame = stepFrame('ended', fields: {'finish': finish});
      expect(
        projectStepUsage(frame).single.meta.source.extra?.value,
        containsPair('finish', finish),
      );
    }
  });

  test('a restarted step replaces its earlier reading', () {
    var state = empty;
    var seq = 0;
    for (final frame in [
      stepFrame('ended', id: 'evt_a', fields: {'cost': 1}),
      stepFrame('started', id: 'evt_restart'),
      stepFrame('ended', id: 'evt_b', fields: {'cost': 2}),
    ]) {
      for (final event in projectStepUsage(frame, current: state, seq: ++seq)) {
        state = reduce(state, event).state;
      }
    }
    final step = state.usage.single;
    expect(step.id, 'step:msg_step');
    expect(step.cost?.amount, 2);
    expect(step.provenance?.nativeEventId, 'evt_b');
  });

  test('a late older reading never overwrites a newer step reading', () {
    var state = empty;
    for (final event in projectStepUsage(
      stepFrame('ended', id: 'evt_new', fields: {'cost': 2}),
      seq: 5,
    )) {
      state = reduce(state, event).state;
    }
    for (final event in projectStepUsage(
      stepFrame('ended', id: 'evt_old', fields: {'cost': 1}),
      current: state,
      seq: 3,
    )) {
      state = reduce(state, event).state;
    }
    expect(state.usage.single.cost?.amount, 2);
    expect(state.usage.single.provenance?.nativeEventId, 'evt_new');
  });

  test('a fractional native timestamp keeps millisecond precision', () {
    final usage = usageOf(
      projectStepUsage(
        edit(stepFrame('ended'), (f) => f['created'] = 1000.9),
      ).single,
    );
    expect(
      usage.observedAt,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
  });

  test('observed zeros stay zeros', () {
    final usage = usageOf(
      projectStepUsage(
        stepFrame(
          'ended',
          fields: {
            'cost': 0,
            'tokens': {
              'input': 0,
              'output': 0,
              'reasoning': 0,
              'cache': {'read': 0, 'write': 0},
            },
          },
        ),
      ).single,
    );
    expect(usage.cost?.amount, 0);
    expect(usage.tokens?.input, 0);
    expect(usage.tokens?.cacheWrite, 0);
  });

  test('a failed step without usage emits nothing', () {
    // The error reaches the timeline on the failed turn's outcome, from
    // `session.execution.failed`, as the history does from the message.
    expect(projectStepUsage(stepFrame('failed')), isEmpty);
    final history = projectOpenCodeHistory(
      [
        assistant(
          'step',
          [textBlock('partial')],
          fields: {
            'error': {'type': 'provider.auth', 'message': 'x'},
          },
        ),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    );
    expect(history.single, isA<AssistantText>());
  });

  test('failed-step usage requires both cost and tokens', () {
    final both = projectStepUsage(
      stepFrame(
        'failed',
        fields: {
          'error': {'type': 'aborted', 'message': 'Step interrupted'},
          'cost': 0,
          'tokens': tokenJson,
        },
      ),
    );
    final usage = both.single;
    expect(usageOf(usage).aggregationKey, 'step:msg_step');
    expect(
      usage.meta.source.extra?.value,
      containsPair('errorContentNotProjected', true),
    );
    for (final fields in [
      {'cost': 0},
      {'tokens': tokenJson},
      {'finish': 'content-filter'},
    ]) {
      expect(projectStepUsage(stepFrame('failed', fields: fields)), isEmpty);
    }
    final filtered = projectStepUsage(
      stepFrame(
        'failed',
        fields: {'finish': 'content-filter', 'cost': 0, 'tokens': tokenJson},
      ),
    );
    expect(
      filtered.single.meta.source.extra?.value,
      containsPair('finish', 'content-filter'),
    );
  });

  test('usage updates are the cumulative ephemeral session series', () {
    final events = projectStepUsage(usageFrame());
    final usage = usageOf(events.single);
    expect(usageJson(usage), {
      'id': 'evt_usage',
      'scope': 'session',
      'source': 'native',
      'observedAt': DateTime.fromMillisecondsSinceEpoch(
        2000,
        isUtc: true,
      ).toIso8601String(),
      'tokens': [10, 2, 1, 3, 0],
      'cost': {
        'amount': 1.5,
        'currency': 'USD',
        'partial': false,
        'cumulative': true,
      },
      'partial': false,
      'cumulative': true,
      'aggregationKey': 'session-total',
    });
    final source = events.single.meta.source;
    expect(source.durability.known, Durability.ephemeral);
    expect(source.aggregateId, isNull);
    expect(source.aggregateSeq, isNull);

    // A later reading replaces the series; steps remain separate.
    var state = empty;
    var seq = 0;
    for (final frame in [
      stepFrame('ended', id: 'evt_s1', message: 'msg_1'),
      usageFrame(id: 'evt_u1', cost: 0.25),
      stepFrame('ended', id: 'evt_s2', message: 'msg_2'),
      usageFrame(id: 'evt_u2', cost: 0.5),
    ]) {
      for (final event in projectStepUsage(frame, current: state, seq: ++seq)) {
        state = reduce(state, event).state;
      }
    }
    final sessions = state.usage.where((u) => u.cumulative).toList();
    expect(sessions.single.id, 'evt_u2');
    expect(sessions.single.cost?.amount, 0.5);
    expect(state.usage.where((u) => u.partial).map((u) => u.aggregationKey), [
      'step:msg_1',
      'step:msg_2',
    ]);
  });

  test('private fields are never copied', () {
    final manifests = [
      ...projectStepUsage(stepFrame('ended')),
      ...projectStepUsage(stepFrame('failed')),
      ...projectStepUsage(usageFrame()),
    ].map(stepUsageManifest).join();
    for (final secret in [
      'fake-private-message',
      'fake-private-body',
      '401',
      'fake-private-state',
      'fake-private-snapshot',
      'fake-private-raw-finish',
      'fake/private/file.txt',
      'fake-private-location',
    ]) {
      expect(manifests, isNot(contains(secret)), reason: secret);
    }
  });

  test('provenance keeps durable step identity', () {
    final source = projectStepUsage(
      stepFrame('ended', seq: 7.0),
      seq: 9,
    ).single.meta.source;
    expect(source.nativeType, 'session.step.ended');
    expect(source.nativeEventId, 'evt_step');
    expect(source.aggregateId, 'ses_a');
    expect(source.aggregateSeq, BigInt.from(7));
    expect(source.durability.known, Durability.durable);
    expect(source.extra?.value, {
      'nativeCreated': 1000,
      'nativeDurableVersion': 1,
      'nativeMessageId': 'msg_step',
      'finish': 'stop',
    });
  });

  test('unrelated types and foreign sessions are ignored', () {
    expect(projectStepUsage({'type': 'session.text.delta'}), isEmpty);
    expect(projectStepUsage(stepFrame('ended', session: 'ses_b')), isEmpty);
    expect(projectStepUsage(usageFrame(session: 'ses_b')), isEmpty);
    expect(
      projectStepUsage(
        edit(
          stepFrame('ended', session: 'ses_b'),
          (f) => dataOf(f)['cost'] = 'x',
        ),
      ),
      isEmpty,
    );
  });

  test('malformed and unsupported frames fail atomically by category', () {
    final ended = stepFrame('ended');
    for (final (frame, failure) in [
      (null, OpenCodeStepUsageProjectionFailure.malformed),
      ({'type': 1}, OpenCodeStepUsageProjectionFailure.malformed),
      (
        edit(ended, (f) => f['id'] = 'x'),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => f['created'] = -1),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => f['created'] = 8640000000000001),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => f.remove('durable')),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => (f['durable']! as Map)['aggregateID'] = 'ses_b'),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => (f['durable']! as Map)['version'] = 2),
        OpenCodeStepUsageProjectionFailure.unsupportedVersion,
      ),
      (
        edit(ended, (f) => dataOf(f)['assistantMessageID'] = 'evt_x'),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => dataOf(f)['finish'] = 'done'),
        OpenCodeStepUsageProjectionFailure.unsupportedValue,
      ),
      (
        edit(ended, (f) => dataOf(f)['cost'] = -1),
        OpenCodeStepUsageProjectionFailure.unsupportedValue,
      ),
      (
        edit(ended, (f) => dataOf(f)['cost'] = '1'),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => (dataOf(f)['tokens']! as Map)['cache'] = null),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => dataOf(f)['providerState'] = 'x'),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(ended, (f) => dataOf(f)['files'] = List.filled(4097, 'f')),
        OpenCodeStepUsageProjectionFailure.limitExceeded,
      ),
      (
        stepFrame(
          'failed',
          fields: {
            'error': {'type': '', 'message': ''},
          },
        ),
        OpenCodeStepUsageProjectionFailure.unsupportedValue,
      ),
      (
        stepFrame('failed', fields: {'finish': 'stop'}),
        OpenCodeStepUsageProjectionFailure.unsupportedValue,
      ),
      (
        usageFrame(tokens: {'input': 1}),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
      (
        edit(usageFrame(), (f) => f['durable'] = {'version': 1}),
        OpenCodeStepUsageProjectionFailure.malformed,
      ),
    ]) {
      expect(() => projectStepUsage(frame), failsWith(failure));
    }
    for (final version in ['2.0.21', '2.0.22-rc.1', 'x']) {
      expect(
        () => projectStepUsage(ended, version: version),
        failsWith(OpenCodeStepUsageProjectionFailure.unsupportedVersion),
      );
    }
  });

  test('selected strings are bounded in UTF-8 bytes', () {
    final atLimit = 'é' * 2048;
    expect(
      projectStepUsage(
        stepFrame(
          'failed',
          fields: {
            'error': {'type': atLimit, 'message': ''},
          },
        ),
      ),
      isEmpty,
    );
    expect(
      () => projectStepUsage(
        stepFrame(
          'failed',
          fields: {
            'error': {'type': '${atLimit}x', 'message': ''},
          },
        ),
      ),
      failsWith(OpenCodeStepUsageProjectionFailure.limitExceeded),
    );
    expect(
      () => projectStepUsage(stepFrame('started', fields: {'agent': '\ud800'})),
      failsWith(OpenCodeStepUsageProjectionFailure.malformed),
    );
  });
}
