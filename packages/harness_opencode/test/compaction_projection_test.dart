import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

Map<String, Object?> frame(
  String type, {
  String id = 'evt_begin',
  Map<String, Object?> data = const {},
}) => {
  'type': 'session.compaction.$type',
  'id': id,
  'created': 1000,
  'durable': {'aggregateID': 'ses_a', 'version': 1, 'seq': 1},
  'data': {'sessionID': 'ses_a', 'reason': 'manual', 'recent': '', ...data},
};

List<SessionEvent> project(
  Object? value,
  SessionState state, {
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeCompactionEvent(
  value,
  state,
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 28),
);

SessionState apply(SessionState state, List<SessionEvent> events) {
  for (final event in events) {
    state = reduce(state, event).state;
  }
  return state;
}

void main() {
  test('2.2.2 compaction accepts the removed recent field', () {
    final start = frame('started');
    (start['data']! as Map<String, Object?>).remove('recent');
    expect(
      project(start, SessionState(historyRef), version: '2.2.2'),
      isNotEmpty,
    );
    expect(
      () => project(start, SessionState(historyRef)),
      throwsA(isA<OpenCodeCompactionProjectionException>()),
    );
  });

  test('held terminal cannot complete a newer hydrated running notice', () {
    final empty = SessionState(historyRef);
    final hydrated = projectOpenCodeHistory(
      [
        message('old', 'compaction', {
          'status': 'completed',
          'reason': 'manual',
          'summary': 'Old checkpoint',
          'recent': '',
        }),
        message('new', 'compaction', {
          'status': 'running',
          'reason': 'manual',
          'summary': '',
          'recent': '',
        }),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    );
    final seed = project(frame('started'), empty).single.meta;
    final state = apply(empty, [
      for (final item in hydrated) ItemUpserted(meta: seed, item: item),
    ]);
    for (final terminal in [
      frame('ended', id: 'evt_old_end', data: {'text': 'Old checkpoint'}),
      frame(
        'failed',
        id: 'evt_old_failed',
        data: {
          'inputID': 'msg_old',
          'error': {'type': 'compaction.failed', 'message': 'Old failure'},
        },
      ),
    ]) {
      expect(
        () => project(terminal, state, seq: 2),
        throwsA(
          isA<OpenCodeCompactionProjectionException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeCompactionProjectionFailure.identityUnproven,
          ),
        ),
      );
    }
    // A live start supplies the correlation that history alone cannot prove.
    var correlated = apply(
      state,
      project(
        frame('started', id: 'evt_new_start', data: {'inputID': 'msg_new'}),
        state,
        seq: 3,
      ),
    );
    correlated = apply(
      correlated,
      project(
        frame('ended', id: 'evt_new_end', data: {'text': 'New checkpoint'}),
        correlated,
        seq: 4,
      ),
    );
    expect(correlated.timeline.whereType<Notice>().map((item) => item.text), [
      'Old checkpoint',
      'New checkpoint',
    ]);
  });

  test(
    'ended after hydration requires repair rather than a duplicate notice',
    () {
      final empty = SessionState(historyRef);
      final hydrated = projectOpenCodeHistory(
        [
          message('input', 'compaction', {
            'status': 'completed',
            'reason': 'manual',
            'summary': 'Checkpoint',
            'recent': '',
          }),
        ],
        historyRef,
        sourceVersion: '2.0.22',
      ).single;
      final seed = project(frame('started'), empty).single.meta;
      final state = apply(empty, [ItemUpserted(meta: seed, item: hydrated)]);
      expect(
        () => project(
          frame('ended', id: 'evt_held_end', data: {'text': 'Checkpoint'}),
          state,
          seq: 2,
        ),
        throwsA(
          isA<OpenCodeCompactionProjectionException>().having(
            (e) => e.failure.name,
            'repair reason',
            'identityUnproven',
          ),
        ),
      );
      expect(state.timeline.single.id, hydrated.id);
    },
  );

  test('failed without start retains the official input identity', () {
    final state = SessionState(historyRef);
    final failed = project(
      frame(
        'failed',
        data: {
          'inputID': 'msg_input',
          'error': {'type': 'compaction.failed', 'message': 'No summary'},
        },
      ),
      state,
    );
    final notice = (failed.first as ItemUpserted).item as Notice;
    expect(openCodeMessageIdOf(notice.id, historyRef), 'msg_input');
  });

  test('unpaired surrogates produce finite malformed diagnostics', () {
    final state = SessionState(historyRef);
    for (final bad in [
      String.fromCharCodes([0xD800]),
      String.fromCharCodes([0xDC00]),
    ]) {
      expect(
        () => project(frame('ended', data: {'text': bad}), state),
        throwsA(
          isA<OpenCodeCompactionProjectionException>().having(
            (e) => e.failure,
            'failure',
            OpenCodeCompactionProjectionFailure.malformed,
          ),
        ),
      );
    }
  });

  test('an old terminal replay never completes a newer compaction', () {
    var state = SessionState(historyRef);
    state = apply(
      state,
      project(frame('started', data: {'inputID': 'msg_first'}), state),
    );
    final oldEnd = frame(
      'ended',
      id: 'evt_old_end',
      data: {'text': 'Old checkpoint'},
    );
    state = apply(state, project(oldEnd, state, seq: 2));
    state = apply(
      state,
      project(
        frame('started', id: 'evt_next_begin', data: {'inputID': 'msg_second'}),
        state,
        seq: 3,
      ),
    );
    final newerId = state.timeline.last.id;
    state = apply(state, project(oldEnd, state, seq: 4));
    final running = state.timeline.whereType<Notice>().where(
      (item) => item.status.known == ItemStatus.streaming,
    );
    expect(running.map((item) => item.id), [newerId]);
    expect(state.timeline, hasLength(2));
    state = apply(
      state,
      project(
        frame('ended', id: 'evt_next_end', data: {'text': 'New checkpoint'}),
        state,
        seq: 5,
      ),
    );
    expect(state.timeline.whereType<Notice>().map((item) => item.text), [
      'Old checkpoint',
      'New checkpoint',
    ]);
  });

  test(
    'terminal summary replaces the running notice and ignores opaque state',
    () {
      var state = SessionState(historyRef);
      final start = frame('started', data: {'inputID': 'msg_input'});
      state = apply(state, project(start, state));
      final running = state.timeline.single as Notice;
      expect(running.kind.known, NoticeKind.compaction);
      expect(running.status.known, ItemStatus.streaming);
      expect(
        project(frame('delta', data: {'text': 'partial'}), state),
        isEmpty,
      );
      final end = frame(
        'ended',
        id: 'evt_end',
        data: {
          'text': 'Complete checkpoint',
          'recent': 'private-recent-context',
          'providerState': Object(),
          'providerContext': Object(),
        },
      );
      state = apply(state, project(end, state, seq: 2));
      final complete = state.timeline.single as Notice;
      expect(complete.id, running.id);
      expect(complete.status.known, ItemStatus.completed);
      expect(complete.text, 'Complete checkpoint');
      expect(
        jsonEncode(complete.meta.source.extra!.value),
        isNot(contains('private-recent')),
      );
      // Replayed terminal frames and a late copy of the start never append or regress.
      state = apply(state, project(end, state, seq: 3));
      expect(project(start, state, seq: 4), isEmpty);
      expect(state.timeline.single.id, running.id);
    },
  );

  test('start consumes only its native pending control item', () {
    ItemId id(String message) =>
        ItemId(jsonEncode([historyRef.storageKey, message, 'notice', 0]));
    final empty = SessionState(historyRef);
    final seed = project(frame('started', id: 'evt_seed'), empty).single.meta;
    final state = apply(empty, [
      PendingInputChanged(
        meta: seed,
        items: [
          PendingInput(
            id: id('msg_input'),
            text: '',
            delivery: const OpenValue.known(Delivery.steer),
          ),
          PendingInput(
            id: id('msg_other'),
            text: 'Keep',
            delivery: const OpenValue.known(Delivery.queue),
          ),
        ],
      ),
    ]);
    final next = apply(
      state,
      project(frame('started', data: {'inputID': 'msg_input'}), state, seq: 2),
    );
    expect(next.pending.single.id, id('msg_other'));
  });

  test(
    'history and durable terminal notices keep identical native identity',
    () {
      for (final failed in [false, true]) {
        var state = SessionState(historyRef);
        state = apply(
          state,
          project(frame('started', data: {'inputID': 'msg_input'}), state),
        );
        final error = {
          'type': 'compaction.failed',
          'message': 'No valid summary',
        };
        final terminal = frame(
          failed ? 'failed' : 'ended',
          id: 'evt_end',
          data: {
            if (failed) 'inputID': 'msg_input',
            if (failed) 'error': error else 'text': 'Checkpoint',
          },
        );
        state = apply(state, project(terminal, state, seq: 2));
        final live = state.timeline.single as Notice;
        final history =
            projectOpenCodeHistory(
                  [
                    message('input', 'compaction', {
                      'status': failed ? 'failed' : 'completed',
                      'reason': 'manual',
                      if (failed) 'error': error else 'summary': 'Checkpoint',
                      'recent': 'private-recent',
                      'providerState': Object(),
                      'providerContext': Object(),
                    }),
                  ],
                  historyRef,
                  sourceVersion: '2.0.22',
                ).single
                as Notice;
        expect(history.id, live.id);
        expect(history.text, live.text);
        expect(history.status, live.status);
        expect(history.kind, live.kind);
      }
    },
  );

  test('foreign, malformed, oversized and unverified frames stay finite', () {
    final state = SessionState(historyRef);
    final foreign = frame(
      'started',
      data: {'sessionID': 'ses_foreign', 'inputID': 'msg_other'},
    );
    expect(project(foreign, state), isEmpty);
    for (final (value, version) in [
      (frame('started', data: {'reason': 'private-invalid-reason'}), '2.0.22'),
      (frame('ended', data: {'text': 'x' * (256 * 1024 + 1)}), '2.0.22'),
      (frame('started'), '3.0.0'),
    ]) {
      expect(
        () => project(value, state, version: version),
        throwsA(
          isA<OpenCodeCompactionProjectionException>().having(
            (e) => e.toString(),
            'finite diagnostic',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });

  test(
    'observed native success and failure captures replay to canonical notices',
    () {
      final fixtures = OpenCodeFixtures();
      var completed = 0;
      var failed = 0;
      for (final name in [
        'capture.json',
        'capture-r2.json',
        'compaction-failed-diagnostic.json',
      ]) {
        final raw = jsonDecode(
          File(
            '${fixtures.root.path}/turn-actions-071g/$name',
          ).readAsStringSync(),
        );
        for (final list in eventLists(raw)) {
          final states = <String, SessionState>{};
          for (var i = 0; i < list.length; i++) {
            final event = list[i];
            final type = event['type']! as String;
            if (!type.startsWith('session.compaction.')) continue;
            final sid =
                (event['data']! as Map<String, Object?>)['sessionID']!
                    as String;
            final state = states[sid] ?? SessionState(refOf(sid));
            final next = apply(state, project(event, state, seq: i + 1));
            states[sid] = next;
            if (type == 'session.compaction.ended') {
              expect(
                (next.timeline.single as Notice).status.known,
                ItemStatus.completed,
              );
              completed++;
            }
            if (type == 'session.compaction.failed') {
              expect(
                (next.timeline.single as Notice).status.known,
                ItemStatus.failed,
              );
              failed++;
            }
          }
        }
      }
      expect(completed, 4);
      expect(failed, 2);
    },
  );
}
