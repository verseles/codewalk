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

Matcher failsWith(OpenCodeNoticeProjectionFailure failure) => throwsA(
  isA<OpenCodeNoticeProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeNoticeProjectionException(${failure.name})',
      ),
);

// Source-shaped inputs, distinct from the immutable observed captures.
Map<String, Object?> noticeFrame(
  String type, {
  String id = 'evt_notice',
  String session = 'ses_a',
  Map<String, Object?>? data,
  Object? version,
}) => {
  'id': id,
  'created': 1000,
  'type': type,
  'location': {'directory': '/fake-private-location'},
  'metadata': {'secret': 'fake-private-frame-metadata'},
  'data': <String, Object?>{
    'sessionID': session,
    ...data ??
        (type == 'session.synthetic'
            ? {
                'text': 'Continue the task.',
                'description': 'fake-private-description',
                'metadata': {'secret': 'fake-private-metadata'},
              }
            : {
                'delta': {'fake-private-source': 'removed'},
                'text': 'Rules changed.',
              }),
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': 4,
    'version': version ?? (type == 'session.synthetic' ? 1 : 2),
  },
};

List<SessionEvent> projectNotice(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String version = '2.0.22',
}) => projectOpenCodeNoticeEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
);

Notice noticeOf(List<SessionEvent> events) =>
    (events.single as ItemUpserted).item as Notice;

void main() {
  for (final (type, row, kind) in [
    ('session.instructions.updated', 'system', NoticeKind.system),
    ('session.synthetic', 'synthetic', NoticeKind.continuation),
  ]) {
    test('$type matches the history $row row', () {
      final events = projectNotice(noticeFrame(type));
      final live = noticeOf(events);
      final history =
          projectOpenCodeHistory(
                [
                  message('notice', row, {
                    'text': live.text,
                    'description': 'x',
                  }),
                ],
                historyRef,
                sourceVersion: '2.0.22',
              ).single
              as Notice;
      expect(live.id, history.id);
      expect(live.kind.known, kind);
      expect(live.kind, history.kind);
      expect(live.text, history.text);
      expect(live.status, history.status);
      expect(live.generation, isNot(history.generation));
      final source = events.single.meta.source;
      expect(source.nativeType, type);
      expect(source.aggregateSeq, BigInt.from(4));
      expect(source.durability.known, Durability.durable);
      expect(source.extra!.value, {
        'nativeCreated': 1000,
        'nativeDurableVersion': type == 'session.synthetic' ? 1 : 2,
        'nativeMessageId': 'msg_notice',
      });
      // A replay of the same frame upserts the same identity.
      final once = reduce(SessionState(historyRef), events.single).state;
      final twice = reduce(
        once,
        projectNotice(noticeFrame(type), current: once, seq: 2).single,
      ).state;
      expect(twice.timeline.map((i) => i.id), [live.id]);
    });
  }

  test('updates without rendered text add no item', () {
    expect(
      projectNotice(
        noticeFrame(
          'session.instructions.updated',
          data: {
            'delta': {'core/date': 'abc'},
          },
        ),
      ),
      isEmpty,
    );
    expect(
      noticeOf(
        projectNotice(
          noticeFrame(
            'session.instructions.updated',
            data: {'delta': <String, Object?>{}, 'text': ''},
          ),
        ),
      ).text,
      '',
    );
  });

  test('sources, descriptions, metadata and location are never copied', () {
    for (final type in ['session.instructions.updated', 'session.synthetic']) {
      final encoded = jsonEncode([
        for (final event in projectNotice(noticeFrame(type)))
          {
            'extra': event.meta.source.extra?.value,
            'text': ((event as ItemUpserted).item as Notice).text,
          },
      ]);
      expect(encoded, isNot(contains('fake-private')));
    }
  });

  test('other sessions and unrelated types project nothing', () {
    expect(
      projectNotice(noticeFrame('session.synthetic', session: 'ses_b')),
      isEmpty,
    );
    expect(
      projectNotice(
        noticeFrame('session.synthetic', session: 'ses_b'),
        version: 'x',
      ),
      isEmpty,
    );
    for (final type in ['session.renamed', 'session.shell.started']) {
      expect(
        projectNotice({...noticeFrame('session.synthetic'), 'type': type}),
        isEmpty,
      );
    }
  });

  test('a resident item of another kind under the ID is rejected', () {
    final id = noticeOf(projectNotice(noticeFrame('session.synthetic'))).id;
    final state = reduce(
      SessionState(historyRef),
      ItemUpserted(
        meta: EventMeta(
          owner: SessionOwner(historyRef),
          position: observedPosition(0),
          receivedAt: DateTime.utc(2026, 10, 14),
          source: SourceProvenance(
            harness: historyRef.harnessRef,
            version: '2.0.22',
            nativeType: 'seed',
          ),
        ),
        item: TurnOutcome(
          meta: ItemMeta(
            id: id,
            generation: 'seed',
            status: const OpenValue.known(ItemStatus.completed),
            source: SourceProvenance(
              harness: historyRef.harnessRef,
              version: '2.0.22',
              nativeType: 'seed',
            ),
          ),
          kind: const OpenValue.known(OutcomeKind.succeeded),
        ),
      ),
    ).state;
    expect(
      () => projectNotice(noticeFrame('session.synthetic'), current: state),
      failsWith(OpenCodeNoticeProjectionFailure.itemKindMismatch),
    );
  });

  test('malformed frames fail with finite categories', () {
    const m = OpenCodeNoticeProjectionFailure.malformed;
    const v = OpenCodeNoticeProjectionFailure.unsupportedVersion;
    const l = OpenCodeNoticeProjectionFailure.limitExceeded;
    final synthetic = noticeFrame('session.synthetic');
    Map<String, Object?> instructions(Map<String, Object?> data) =>
        noticeFrame('session.instructions.updated', data: data);
    for (final (input, failure) in <(Object?, OpenCodeNoticeProjectionFailure)>[
      (null, m),
      ({'type': 7}, m),
      ({'type': 'session.synthetic'}, m),
      ({...synthetic, 'id': 'msg_x'}, m),
      ({...synthetic, 'created': -1}, m),
      (Map<String, Object?>.of(synthetic)..remove('durable'), m),
      (
        {
          ...synthetic,
          'durable': {'aggregateID': 'ses_b', 'seq': 1, 'version': 1},
        },
        m,
      ),
      (
        {
          ...synthetic,
          'durable': {'aggregateID': 'ses_a', 'seq': 1.5, 'version': 1},
        },
        m,
      ),
      (noticeFrame('session.synthetic', version: 2), v),
      (noticeFrame('session.instructions.updated', version: 1), v),
      (noticeFrame('session.synthetic', data: const {}), m),
      (noticeFrame('session.synthetic', data: {'text': null}), m),
      (
        noticeFrame('session.synthetic', data: {'text': 'x', 'description': 3}),
        m,
      ),
      (noticeFrame('session.synthetic', data: {'text': 'x', 'metadata': 3}), m),
      (instructions({'text': 'x'}), m),
      (instructions({'delta': 'x'}), m),
      (
        instructions({
          'delta': {'a': 3},
        }),
        m,
      ),
      (
        instructions({
          'delta': {'': 'removed'},
        }),
        m,
      ),
      (instructions({'delta': <String, Object?>{}, 'text': null}), m),
      (instructions({'delta': <String, Object?>{}, 'text': 'a\ud800'}), m),
      (
        instructions({
          'delta': <String, Object?>{},
          'text': 't' * (256 * 1024 + 1),
        }),
        l,
      ),
      (
        instructions({
          'delta': {for (var i = 0; i < 4097; i++) 'k$i': 'v'},
        }),
        l,
      ),
    ]) {
      expect(
        () => projectNotice(input),
        failsWith(failure),
        reason: '$input'.length > 120 ? '$input'.substring(0, 120) : '$input',
      );
    }
    expect(() => projectNotice(synthetic, version: '2.0.21'), failsWith(v));
    expect(projectNotice(synthetic, version: '2.0.22+build.1'), hasLength(1));
  });

  test(
    'observed captures: every instruction update is a text-free baseline',
    () {
      final fixtures = OpenCodeFixtures();
      final files =
          fixtures.root
              .listSync(recursive: true)
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.json') &&
                    !f.path.contains('/web-configured-origin/'),
              )
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final counts = <String, int>{};
      for (final file in files) {
        for (final events in eventLists(jsonDecode(file.readAsStringSync()))) {
          for (var i = 0; i < events.length; i++) {
            final type = events[i]['type']! as String;
            if (type != 'session.instructions.updated' &&
                type != 'session.synthetic') {
              continue;
            }
            final session =
                (events[i]['data']! as Map<String, Object?>)['sessionID']!
                    as String;
            expect(
              projectOpenCodeNoticeEvent(
                events[i],
                SessionState(refOf(session)),
                sourceVersion: '2.0.22',
                position: observedPosition(i + 1),
                receivedAt: DateTime.utc(2026, 10, 14),
              ),
              isEmpty,
            );
            counts[type] = (counts[type] ?? 0) + 1;
          }
        }
      }
      // Includes eight baselines from the two V2-071G owned-session captures.
      expect(counts, {'session.instructions.updated': 40});
    },
  );
}
