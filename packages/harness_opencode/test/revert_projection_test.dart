import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'inbox_test_data.dart';
import 'revert_test_data.dart';

Matcher failsWith(OpenCodeRevertProjectionFailure failure) => throwsA(
  isA<OpenCodeRevertProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeRevertProjectionException(${failure.name})',
      ),
);

RevertState revertOf(SessionEvent event) => (event as RevertChanged).state;

SessionState reduceAll(SessionState state, List<SessionEvent> events) {
  for (final event in events) {
    final result = reduce(state, event);
    expect(result.effects.whereType<Rehydrate>(), isEmpty);
    state = result.state;
  }
  return state;
}

void main() {
  final seeded = seededState();
  final ids = [for (final item in seeded.timeline) messageOf(item.id)];

  test('seed holds three resident messages and two queued prompts', () {
    expect(ids, ['msg_a', 'msg_b', 'msg_c']);
    expect(
      [for (final p in seeded.pending) messageOf(p.id)],
      ['msg_a5', 'msg_c5'],
    );
  });

  test('staged maps the boundary item and a patch-free file summary', () {
    final events = projectRevert(
      revertFrame(
        'staged',
        revert: revertData(
          files: [
            fileDiff('src/a.txt'),
            fileDiff('src/new.txt', status: 'added', deletions: 0),
          ],
          fields: {'partID': 'prt_legacy'},
        ),
      ),
      current: seeded,
    );
    expect(events, hasLength(1));
    final state = revertOf(events.single);
    expect(state.kind.known, RevertKind.staged);
    expect(state.boundary, seeded.timeline[1].id);
    expect(state.details!.value, {
      'messageId': 'msg_b',
      'hasSnapshot': true,
      'files': [
        {
          'file': 'src/a.txt',
          'status': 'modified',
          'additions': 1,
          'deletions': 2,
        },
        {
          'file': 'src/new.txt',
          'status': 'added',
          'additions': 1,
          'deletions': 0,
        },
      ],
      'patchNotProjected': true,
    });
    final source = events.single.meta.source;
    expect(source.nativeType, 'session.revert.staged');
    expect(source.nativeEventId, 'evt_revert');
    expect(source.aggregateId, 'ses_a');
    expect(source.aggregateSeq, BigInt.from(3));
    expect(source.durability.known, Durability.durable);
    expect(source.extra!.value, {
      'nativeCreated': 1000,
      'nativeDurableVersion': 1,
      'nativeMessageId': 'msg_b',
      'patchNotProjected': true,
    });
    final after = reduceAll(seeded, events);
    expect(after.revert, same(state));
    expect(after.timeline, seeded.timeline);
    expect(after.pending, seeded.pending);
  });

  test('absent and empty files stay distinct; snapshot is optional', () {
    final absent = revertOf(
      projectRevert(
        revertFrame(
          'staged',
          revert: revertData(withFiles: false)..remove('snapshot'),
        ),
      ).single,
    );
    expect(absent.details!.value, {'messageId': 'msg_b', 'hasSnapshot': false});
    final empty = revertOf(
      projectRevert(
        revertFrame('staged', revert: revertData(files: <Object?>[])),
      ).single,
    );
    expect(empty.details!.value, {
      'messageId': 'msg_b',
      'hasSnapshot': true,
      'files': <Object?>[],
    });
  });

  test('staged without a resident boundary keeps a null boundary', () {
    final events = projectRevert(
      revertFrame('staged', revert: revertData(message: 'msg_zz')),
      current: seeded,
    );
    expect(events, hasLength(1));
    expect(revertOf(events.single).boundary, isNull);
    expect(
      revertOf(projectRevert(revertFrame('staged')).single).boundary,
      isNull,
    );
  });

  test('cleared records the terminal kind and leaves collections', () {
    final staged = reduceAll(
      seeded,
      projectRevert(revertFrame('staged'), current: seeded),
    );
    final events = projectRevert(
      revertFrame('cleared', id: 'evt_clear', seq: 4),
      current: staged,
      seq: 101,
    );
    expect(events, hasLength(1));
    final state = revertOf(events.single);
    expect(state.kind.known, RevertKind.cleared);
    expect(state.boundary, isNull);
    expect(state.details, isNull);
    expect(events.single.meta.source.extra!.value, {
      'nativeCreated': 1000,
      'nativeDurableVersion': 1,
    });
    final after = reduceAll(staged, events);
    expect(after.revert!.kind.known, RevertKind.cleared);
    expect(after.timeline, seeded.timeline);
    expect(after.pending, seeded.pending);
  });

  test(
    'committed removes the boundary message onward and later queued prompts',
    () {
      final events = projectRevert(revertFrame('committed'), current: seeded);
      expect(
        [for (final e in events) e.runtimeType],
        [RevertChanged, ItemsRemoved, PendingInputChanged],
      );
      final state = revertOf(events.first);
      expect(state.kind.known, RevertKind.committed);
      expect(state.boundary, isNull);
      expect(state.details!.value, {'messageId': 'msg_b'});
      expect((events[1] as ItemsRemoved).fromItemId, seeded.timeline[1].id);
      final after = reduceAll(seeded, events);
      expect([for (final i in after.timeline) messageOf(i.id)], ['msg_a']);
      expect([for (final p in after.pending) messageOf(p.id)], ['msg_a5']);
      expect(after.revert!.kind.known, RevertKind.committed);
    },
  );

  test('committed at the first message empties the resident state', () {
    final events = projectRevert(
      revertFrame('committed', to: 'msg_a'),
      current: seeded,
    );
    final after = reduceAll(seeded, events);
    expect(after.timeline, isEmpty);
    expect(after.pending, isEmpty);
  });

  test('committed past every resident item requests a resync', () {
    final events = projectRevert(
      revertFrame('committed', to: 'msg_d'),
      current: seededState(pending: const ['msg_a5']),
    );
    expect(
      [for (final e in events) e.runtimeType],
      [RevertChanged, ResyncRequired],
    );
    expect((events.last as ResyncRequired).reason, 'revertBoundaryMissing');
  });

  test('an unproven cut requests a resync instead of a guessed removal', () {
    // Boundary not resident while a later message is.
    var events = projectRevert(
      revertFrame('committed', to: 'msg_bb'),
      current: seeded,
    );
    expect(
      [for (final e in events) e.runtimeType],
      [RevertChanged, PendingInputChanged, ResyncRequired],
    );
    expect((events.last as ResyncRequired).reason, 'revertBoundaryMissing');

    // Empty timeline: nothing proves the boundary.
    events = projectRevert(revertFrame('committed'));
    expect((events.last as ResyncRequired).reason, 'revertBoundaryMissing');

    // A resident item that orders before the boundary after the cut.
    final disordered = seededState(
      messages: [
        message('b', 'user', {'text': 'second'}),
        message('a', 'user', {'text': 'first'}),
      ],
      pending: const [],
    );
    events = projectRevert(
      revertFrame('committed', to: 'msg_b'),
      current: disordered,
    );
    expect(
      [for (final e in events) e.runtimeType],
      [RevertChanged, ResyncRequired],
    );
    expect((events.last as ResyncRequired).reason, 'revertOrderMismatch');

    // A resident item whose identity is not the shared canonical shape.
    final foreign = reduce(
      seeded,
      ItemUpserted(
        meta: seedMeta(50),
        item: Notice(
          meta: ItemMeta(
            id: const ItemId('local-notice'),
            generation: 'seed',
            status: const OpenValue.known(ItemStatus.completed),
            source: seedMeta(50).source,
          ),
          kind: const OpenValue.known(NoticeKind.system),
          text: 'x',
        ),
      ),
    ).state;
    events = projectRevert(revertFrame('committed'), current: foreign);
    expect(
      [for (final e in events) e.runtimeType],
      [RevertChanged, PendingInputChanged, ResyncRequired],
    );
    expect((events.last as ResyncRequired).reason, 'revertMembershipUnproven');
    final reduced = reduce(foreign, events.last);
    expect(reduced.effects.whereType<Rehydrate>(), hasLength(1));
  });

  test('a boundary message with several items is cut at its first item', () {
    // An admitted steer prompt with context yields the user item and its
    // manifest under one native message.
    var state = seededState(pending: const []);
    for (final event in projectInbox(
      inboxFrame(
        'enqueued',
        id: 'evt_ctx',
        inbox: 'msg_d',
        item: userItem(
          'with context',
          fields: {
            'files': [
              {
                'data': '',
                'mime': 'text/plain',
                'source': {'type': 'inline'},
              },
            ],
          },
        ),
      ),
      current: state,
      seq: 40,
    )) {
      state = reduce(state, event).state;
    }
    final boundary = [
      for (final item in state.timeline)
        if (messageOf(item.id) == 'msg_d') item,
    ];
    expect(boundary.map((i) => i.runtimeType), [UserInput, UnknownItem]);
    final staged = revertOf(
      projectRevert(
        revertFrame('staged', revert: revertData(message: 'msg_d')),
        current: state,
      ).single,
    );
    expect(staged.boundary, boundary.first.id);
    final events = projectRevert(
      revertFrame('committed', to: 'msg_d'),
      current: state,
    );
    expect((events[1] as ItemsRemoved).fromItemId, boundary.first.id);
    expect(
      [for (final i in reduceAll(state, events).timeline) messageOf(i.id)],
      ['msg_a', 'msg_b', 'msg_c'],
    );
  });

  test('an identity with a non-string kind is not canonical', () {
    final state = reduce(
      seededState(pending: const []),
      ItemUpserted(
        meta: seedMeta(50),
        item: Notice(
          meta: ItemMeta(
            id: ItemId(jsonEncode([historyRef.storageKey, 'msg_d', 7, 0])),
            generation: 'seed',
            status: const OpenValue.known(ItemStatus.completed),
            source: seedMeta(50).source,
          ),
          kind: const OpenValue.known(NoticeKind.system),
          text: 'x',
        ),
      ),
    ).state;
    final events = projectRevert(
      revertFrame('committed', to: 'msg_b'),
      current: state,
    );
    expect(events.whereType<ItemsRemoved>(), isEmpty);
    expect(
      events.whereType<ResyncRequired>().single.reason,
      'revertMembershipUnproven',
    );
  });

  test('an unproven pending identity is never partially filtered', () {
    final state = reduce(
      seeded,
      PendingInputChanged(
        meta: seedMeta(60),
        items: [
          ...seeded.pending,
          const PendingInput(
            id: ItemId('local-draft'),
            text: 'x',
            delivery: OpenValue.known(Delivery.queue),
          ),
        ],
      ),
    ).state;
    final events = projectRevert(revertFrame('committed'), current: state);
    expect(
      [for (final e in events) e.runtimeType],
      [RevertChanged, ItemsRemoved, ResyncRequired],
    );
    expect((events.last as ResyncRequired).reason, 'revertPendingUnproven');

    // One resync per frame: the timeline reason wins.
    final both = projectRevert(
      revertFrame('committed', to: 'msg_bb'),
      current: state,
    );
    expect(
      both.whereType<ResyncRequired>().single.reason,
      'revertBoundaryMissing',
    );
    expect(both.whereType<PendingInputChanged>(), isEmpty);
  });

  test('the staged, cleared, staged, committed machine reduces in order', () {
    var state = seeded;
    final kinds = <RevertKind?>[];
    for (final (i, frame) in [
      revertFrame('staged', id: 'evt_1', seq: 3),
      revertFrame('cleared', id: 'evt_2', seq: 4),
      revertFrame('staged', id: 'evt_3', seq: 5),
      revertFrame('committed', id: 'evt_4', seq: 6),
    ].indexed) {
      state = reduceAll(
        state,
        projectRevert(frame, current: state, seq: 100 + i),
      );
      kinds.add(state.revert!.kind.known);
    }
    expect(kinds, [
      RevertKind.staged,
      RevertKind.cleared,
      RevertKind.staged,
      RevertKind.committed,
    ]);
    expect([for (final i in state.timeline) messageOf(i.id)], ['msg_a']);
  });

  test(
    'patches, snapshots, legacy parts and the location are never copied',
    () {
      for (final frame in [
        revertFrame(
          'staged',
          revert: revertData(fields: {'partID': 'fake-private-part'}),
        ),
        revertFrame('cleared'),
        revertFrame('committed'),
      ]) {
        for (final event in projectRevert(frame, current: seeded)) {
          final manifest = revertManifest(event);
          for (final secret in [
            'fake-private-patch',
            'fake-private-snapshot',
            'fake-private-part',
            'fake-private-location',
          ]) {
            expect(manifest, isNot(contains(secret)));
          }
        }
      }
    },
  );

  test('unrelated types and foreign sessions project nothing', () {
    expect(
      projectRevert({...revertFrame('staged'), 'type': 'session.renamed'}),
      isEmpty,
    );
    expect(projectRevert(revertFrame('staged', session: 'ses_b')), isEmpty);
    expect(
      projectRevert(revertFrame('committed', session: 'ses_b'), version: 'x'),
      isEmpty,
    );
  });

  test('malformed frames fail with finite categories', () {
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

    Map<String, Object?> staged(Map<String, Object?> revert) =>
        revertFrame('staged', revert: revert);
    const m = OpenCodeRevertProjectionFailure.malformed;
    const v = OpenCodeRevertProjectionFailure.unsupportedVersion;
    const l = OpenCodeRevertProjectionFailure.limitExceeded;
    const u = OpenCodeRevertProjectionFailure.unsupportedValue;
    final cleared = revertFrame('cleared');
    for (final (input, failure) in <(Object?, OpenCodeRevertProjectionFailure)>[
      (null, m),
      ({'type': 7}, m),
      ({'type': 'session.revert.cleared'}, m),
      ({...cleared, 'id': 'msg_x'}, m),
      ({...cleared, 'created': null}, m),
      ({...cleared, 'created': double.nan}, m),
      ({...cleared, 'created': -1}, m),
      (Map<String, Object?>.of(cleared)..remove('durable'), m),
      (edit(cleared, (d, du) => d['sessionID'] = 'x_a'), m),
      (edit(cleared, (d, du) => du['aggregateID'] = 'ses_b'), m),
      (edit(cleared, (d, du) => du['seq'] = -1), m),
      (edit(cleared, (d, du) => du['seq'] = 1.5), m),
      (edit(cleared, (d, du) => du['seq'] = 9007199254740992), m),
      (edit(cleared, (d, du) => du['version'] = 2), v),
      (revertFrame('committed', to: 'x_b'), m),
      (edit(revertFrame('committed'), (d, du) => d.remove('to')), m),
      (edit(revertFrame('staged'), (d, du) => d['revert'] = null), m),
      (staged(revertData(message: 'x_b')), m),
      (staged(revertData(fields: {'partID': 3})), m),
      (staged(revertData(fields: {'snapshot': ''})), m),
      (staged(revertData(files: null)), m),
      (staged(revertData(files: ['x'])), m),
      (staged(revertData(files: [fileDiff('')])), m),
      (staged(revertData(files: [fileDiff('a', status: 'renamed')])), u),
      (staged(revertData(files: [fileDiff('a', additions: -1)])), m),
      (staged(revertData(files: [fileDiff('a', deletions: 1.5)])), m),
      (staged(revertData(files: [fileDiff('a\ud800')])), m),
      (
        staged(
          revertData(
            files: [Map<String, Object?>.of(fileDiff('a'))..remove('patch')],
          ),
        ),
        m,
      ),
      (
        staged(
          revertData(
            files: [
              {
                ...Map<String, Object?>.of(fileDiff('a'))..remove('file'),
                'path': 'a',
              },
            ],
          ),
        ),
        m,
      ),
      (staged(revertData(message: 'msg_${'a' * 4093}')), l),
      (staged(revertData(files: [fileDiff('a' * 4097)])), l),
      (staged(revertData(files: List.filled(4097, fileDiff('a')))), l),
    ]) {
      expect(() => projectRevert(input), failsWith(failure), reason: '$input');
    }
    expect(() => projectRevert(cleared, version: '2.0.21'), failsWith(v));
    expect(() => projectRevert(cleared, version: '2.1.0-beta.1'), failsWith(v));
    expect(projectRevert(cleared, version: '2.0.22+build.1'), hasLength(1));
  });

  test('retained details are bounded atomically, never truncated', () {
    final path = 'p' * 4000;
    final fits = [for (var i = 0; i < 15; i++) fileDiff('$path$i')];
    final details = revertOf(
      projectRevert(
        revertFrame('staged', revert: revertData(files: fits)),
      ).single,
    ).details!;
    expect(utf8.encode(jsonEncode(details.value)).length, lessThan(64 * 1024));
    expect(
      () => projectRevert(
        revertFrame(
          'staged',
          revert: revertData(
            files: [...fits, fileDiff('${path}x'), fileDiff('${path}y')],
          ),
        ),
      ),
      failsWith(OpenCodeRevertProjectionFailure.limitExceeded),
    );
    // A patch is never measured: only its type is checked.
    final huge = {...fileDiff('a'), 'patch': 'x' * (1 << 20)};
    expect(
      projectRevert(revertFrame('staged', revert: revertData(files: [huge]))),
      hasLength(1),
    );
  });

  test('a failure message carries no native content', () {
    try {
      projectRevert(revertFrame('committed', to: 'fake-private-boundary'));
      fail('expected a failure');
    } on OpenCodeRevertProjectionException catch (error) {
      expect(error.toString(), isNot(contains('fake-private')));
    }
  });
}
