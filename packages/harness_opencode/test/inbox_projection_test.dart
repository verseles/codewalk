import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'inbox_test_data.dart';

Matcher failsWith(OpenCodeInboxProjectionFailure failure) => throwsA(
  isA<OpenCodeInboxProjectionException>()
      .having((e) => e.failure, 'failure', failure)
      .having(
        (e) => e.toString(),
        'toString',
        'OpenCodeInboxProjectionException(${failure.name})',
      ),
);

TimelineItem itemOf(SessionEvent event) => (event as ItemUpserted).item;
List<PendingInput> pendingOf(SessionEvent event) =>
    (event as PendingInputChanged).items;

void main() {
  final empty = SessionState(historyRef);
  final userId = inboxItemId('msg_in', 'user');
  final noticeId = inboxItemId('msg_in', 'notice');

  test('a steer prompt is admitted to the timeline and pending', () {
    final events = projectInbox(inboxFrame('enqueued'));
    expect(events.map((e) => e.runtimeType), [
      ItemUpserted,
      PendingInputChanged,
    ]);
    final user = itemOf(events.first) as UserInput;
    expect(user.id, userId);
    expect(user.status.known, ItemStatus.pending);
    expect(user.delivery.known, DeliveryState.accepted);
    expect(user.text, 'hello');
    expect(user.attachments, isEmpty);
    expect(user.mentions, isEmpty);
    expect(user.commandId, isNull);
    expect(
      user.generation,
      jsonEncode([
        'live',
        historyRef.storageKey,
        'msg_in',
        'evt_inbox',
        'observer-a',
        'epoch-a',
      ]),
    );
    expect(pendingOf(events.last).map(pendingJson), [
      {
        'id': userId.value,
        'text': 'hello',
        'delivery': 'steer',
        'command': null,
      },
    ]);
    expect(() => (events as List).add(events.first), throwsUnsupportedError);
  });

  test('a queued prompt stays pending until delivery', () {
    final frame = inboxFrame(
      'enqueued',
      item: userItem('later', delivery: 'queue'),
    );
    final events = projectInbox(frame);
    expect(events.single, isA<PendingInputChanged>());
    expect(pendingOf(events.single).single.delivery.known, Delivery.queue);
    var state = applyInbox(frame, empty, 1);
    expect(state.timeline, isEmpty);

    final delivered = projectInbox(
      inboxFrame('delivered', id: 'evt_done'),
      current: state,
      seq: 2,
    );
    expect(delivered.map((e) => e.runtimeType), [
      ItemUpserted,
      PendingInputChanged,
    ]);
    final user = itemOf(delivered.first) as UserInput;
    expect(user.id, userId);
    expect(user.text, 'later');
    expect(user.status.known, ItemStatus.completed);
    expect(user.delivery.known, DeliveryState.delivered);
    expect(pendingOf(delivered.last), isEmpty);
    state = applyInbox(inboxFrame('delivered', id: 'evt_done'), state, 2);
    expect(state.timeline.single.id, userId);
    expect(state.pending, isEmpty);
  });

  test('live user order follows delivery like native history', () {
    // Native history places a queued prompt after input delivered before it.
    var state = empty;
    var seq = 0;
    void apply(Map<String, Object?> frame) =>
        state = applyInbox(frame, state, ++seq);
    apply(
      inboxFrame(
        'enqueued',
        id: 'evt_q',
        inbox: 'msg_q',
        item: userItem('queued', delivery: 'queue'),
      ),
    );
    apply(
      inboxFrame(
        'enqueued',
        id: 'evt_c',
        inbox: 'msg_c',
        item: userItem('changed', delivery: 'queue'),
      ),
    );
    apply(
      inboxFrame(
        'delivery.changed',
        id: 'evt_cs',
        inbox: 'msg_c',
        delivery: 'steer',
      ),
    );
    apply(inboxFrame('enqueued', id: 'evt_s', inbox: 'msg_s'));
    apply(inboxFrame('delivered', id: 'evt_cd', inbox: 'msg_c'));
    apply(inboxFrame('delivered', id: 'evt_sd', inbox: 'msg_s'));
    apply(inboxFrame('delivered', id: 'evt_qd', inbox: 'msg_q'));
    expect(state.timeline.map((i) => (i as UserInput).text), [
      'changed',
      'hello',
      'queued',
    ]);
    expect(state.timeline.map((i) => (i as UserInput).delivery.known).toSet(), {
      DeliveryState.delivered,
    });
    expect(state.pending, isEmpty);
  });

  test('delivery changes update pending and resident open input', () {
    final queued = applyInbox(
      inboxFrame('enqueued', item: userItem('q', delivery: 'queue')),
      empty,
      1,
    );
    final promoted = projectInbox(
      inboxFrame('delivery.changed', delivery: 'steer'),
      current: queued,
      seq: 2,
    );
    expect(
      (itemOf(promoted.first) as UserInput).delivery.known,
      DeliveryState.accepted,
    );
    expect(pendingOf(promoted.last).single.delivery.known, Delivery.steer);

    final steered = applyInbox(inboxFrame('enqueued'), empty, 1);
    final demoted = projectInbox(
      inboxFrame('delivery.changed', delivery: 'queue'),
      current: steered,
      seq: 2,
    );
    final user = itemOf(demoted.first) as UserInput;
    expect(user.delivery.known, DeliveryState.queued);
    expect(user.generation, steered.timeline.single.generation);
    expect(pendingOf(demoted.last).single.delivery.known, Delivery.queue);

    expect(
      projectInbox(
        inboxFrame('delivery.changed', delivery: 'steer'),
        current: steered,
        seq: 2,
      ),
      isEmpty,
      reason: 'an unchanged delivery mode emits nothing',
    );
    expect(projectInbox(inboxFrame('delivery.changed')), isEmpty);
  });

  test('cancellation retracts queued input and marks admitted input', () {
    final queued = applyInbox(
      inboxFrame('enqueued', item: userItem('q', delivery: 'queue')),
      empty,
      1,
    );
    final retracted = projectInbox(
      inboxFrame('cancelled'),
      current: queued,
      seq: 2,
    );
    expect(pendingOf(retracted.single), isEmpty);

    var steered = applyInbox(inboxFrame('enqueued'), empty, 1);
    final cancelled = projectInbox(
      inboxFrame('cancelled', id: 'evt_x'),
      current: steered,
      seq: 2,
    );
    final user = itemOf(cancelled.first) as UserInput;
    expect(user.delivery.known, DeliveryState.cancelled);
    expect(user.status.known, ItemStatus.completed);
    expect(user.generation, steered.timeline.single.generation);
    expect(pendingOf(cancelled.last), isEmpty);

    // A same-ID re-enqueue after cancellation is a fresh admission.
    steered = applyInbox(inboxFrame('cancelled', id: 'evt_x'), steered, 2);
    final again = applyInbox(
      inboxFrame('enqueued', id: 'evt_again'),
      steered,
      3,
    );
    final readmitted = again.timeline.single as UserInput;
    expect(readmitted.delivery.known, DeliveryState.accepted);
    expect(readmitted.generation, contains('evt_again'));
    expect(again.pending.single.id, userId);

    expect(projectInbox(inboxFrame('cancelled')), isEmpty);
  });

  test('delivered input never regresses and replays are idempotent', () {
    var state = applyInbox(inboxFrame('enqueued'), empty, 1);
    state = applyInbox(inboxFrame('delivered', id: 'evt_d'), state, 2);
    for (final frame in [
      inboxFrame('enqueued', id: 'evt_replay'),
      inboxFrame('delivered', id: 'evt_d2'),
      inboxFrame('cancelled', id: 'evt_c'),
      inboxFrame('delivery.changed', id: 'evt_m', delivery: 'queue'),
    ]) {
      expect(projectInbox(frame, current: state, seq: 3), isEmpty);
    }
    expect(projectInbox(inboxFrame('delivered', id: 'evt_none')), isEmpty);
  });

  test('history rows are settled and never reopened by live frames', () {
    final row = projectOpenCodeHistory(
      [
        message('in', 'user', {'text': 'hello'}),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    ).single;
    final state = reduce(
      empty,
      ItemUpserted(
        meta: EventMeta(
          owner: SessionOwner(historyRef),
          position: StreamPosition(
            id: 'observer-a',
            epoch: 'epoch-a',
            seq: BigInt.zero,
          ),
          receivedAt: DateTime.utc(2026, 10, 13),
          source: row.source,
        ),
        item: row,
      ),
    ).state;
    expect((state.timeline.single as UserInput).delivery.known, isNull);
    for (final frame in [
      inboxFrame('enqueued', id: 'evt_late'),
      inboxFrame(
        'enqueued',
        id: 'evt_q',
        item: userItem('x', delivery: 'queue'),
      ),
      inboxFrame('delivered', id: 'evt_d'),
      inboxFrame('cancelled', id: 'evt_c'),
    ]) {
      expect(projectInbox(frame, current: state, seq: 2), isEmpty);
    }
  });

  test('a cancelled steer row is replaced by a queued re-admission', () {
    var state = applyInbox(inboxFrame('enqueued'), empty, 1);
    state = applyInbox(inboxFrame('cancelled', id: 'evt_c'), state, 2);
    state = applyInbox(
      inboxFrame(
        'enqueued',
        id: 'evt_q',
        item: userItem('again', delivery: 'queue'),
      ),
      state,
      3,
    );
    final queued = state.timeline.single as UserInput;
    expect(queued.delivery.known, DeliveryState.queued);
    expect(queued.text, 'again');
    expect(queued.generation, contains('evt_q'));
    expect(state.pending.single.delivery.known, Delivery.queue);
    state = applyInbox(inboxFrame('delivered', id: 'evt_d'), state, 4);
    final delivered = state.timeline.single as UserInput;
    expect(delivered.delivery.known, DeliveryState.delivered);
    expect(delivered.text, 'again');
    expect(state.pending, isEmpty);
  });

  test('synthetic continuations become notices on delivery', () {
    final frame = inboxFrame('enqueued', item: syntheticItem('continue'));
    expect(projectInbox(frame).single, isA<PendingInputChanged>());
    var state = applyInbox(frame, empty, 1);
    expect(state.pending.single.id, noticeId);
    final delivered = projectInbox(
      inboxFrame('delivered', id: 'evt_d'),
      current: state,
      seq: 2,
    );
    final notice = itemOf(delivered.first) as Notice;
    expect(notice.id, noticeId);
    expect(notice.kind.known, NoticeKind.continuation);
    expect(notice.status.known, ItemStatus.completed);
    expect(notice.text, 'continue');
    state = applyInbox(inboxFrame('delivered', id: 'evt_d'), state, 2);
    expect(projectInbox(frame, current: state, seq: 3), isEmpty);

    final history = projectOpenCodeHistory(
      [
        message('in', 'synthetic', {'text': 'continue'}),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    ).single;
    expect(history.id, notice.id);
    expect(history.status, notice.status);
    expect((history as Notice).text, notice.text);
    expect(history.kind, notice.kind);
  });

  test('user rows and context markers match the history projection', () {
    final frame = inboxFrame(
      'enqueued',
      item: userItem('with context', fields: privateContext),
    );
    final events = projectInbox(frame);
    expect(events.map((e) => e.runtimeType), [
      ItemUpserted,
      ItemUpserted,
      PendingInputChanged,
    ]);
    final history = projectOpenCodeHistory(
      [
        message('in', 'user', {'text': 'with context', ...privateContext}),
      ],
      historyRef,
      sourceVersion: '2.0.22',
    );
    final live = events.take(2).map(itemOf).toList();
    expect(live.map((i) => i.id), history.map((i) => i.id));
    final marker = live.last as UnknownItem;
    final historyMarker = history.last as UnknownItem;
    expect(marker.rawType, historyMarker.rawType);
    expect(marker.raw.value, historyMarker.raw.value);
    expect(marker.status, historyMarker.status);
    expect((live.first as UserInput).text, (history.first as UserInput).text);
    expect(
      events.first.meta.source.extra?.value,
      containsPair('contextNotProjected', true),
    );

    final manifests = events.map(inboxManifest).join();
    for (final secret in [
      'ZmFrZS1wcml2YXRlLWRhdGE=',
      'fake-private-uri',
      'fake-private-name',
      'fake-private-file-description',
      'fake-private-mention',
      'fake-private-agent',
      'fake-private-skill',
      'fake-private-text',
      'fake-private-metadata',
      'fake-private-location',
    ]) {
      expect(manifests, isNot(contains(secret)), reason: secret);
    }
    final synthetic = projectInbox(
      inboxFrame('enqueued', item: syntheticItem('x')),
    ).map(inboxManifest).join();
    expect(synthetic, isNot(contains('fake-private-description')));
  });

  test('compaction and move items are validated and not projected', () {
    expect(
      projectInbox(
        inboxFrame(
          'enqueued',
          item: {
            'type': 'compaction',
            'payload': <String, Object?>{},
            'delivery': 'queue',
          },
        ),
      ),
      isEmpty,
    );
    final move = {
      'type': 'move',
      'payload': {
        'location': {'directory': '/fake-private-target'},
        'projectID': 'fake-private-project',
        'subpath': 'fake/private',
      },
      'delivery': 'steer',
    };
    expect(projectInbox(inboxFrame('enqueued', item: move)), isEmpty);
    expect(
      () => projectInbox(
        inboxFrame(
          'enqueued',
          item: {
            ...move,
            'payload': {'projectID': 'p'},
          },
        ),
      ),
      failsWith(OpenCodeInboxProjectionFailure.malformed),
    );
  });

  test('provenance is shared by every event of one frame', () {
    final events = projectInbox(
      inboxFrame('enqueued', seq: 7.0, item: userItem('x')),
      seq: 9,
    );
    for (final event in events) {
      expect(event.meta.position.seq, BigInt.from(9));
      expect(event.meta.source.nativeType, 'session.inbox.enqueued');
      expect(event.meta.source.nativeEventId, 'evt_inbox');
      expect(event.meta.source.aggregateId, 'ses_a');
      expect(event.meta.source.aggregateSeq, BigInt.from(7));
      expect(event.meta.source.durability.known, Durability.durable);
      expect(event.meta.source.extra?.value, {
        'nativeCreated': 1000,
        'nativeDurableVersion': 1,
        'nativeInboxId': 'msg_in',
        'inboxItemType': 'user',
        'nativeDelivery': 'steer',
      });
    }
    expect(
      projectInbox(
        inboxFrame('cancelled'),
        current: applyInbox(inboxFrame('enqueued'), empty, 1),
        seq: 2,
      ).first.meta.source.extra?.value,
      {
        'nativeCreated': 1000,
        'nativeDurableVersion': 1,
        'nativeInboxId': 'msg_in',
      },
    );
  });

  test('unrelated types and foreign sessions are ignored', () {
    expect(projectInbox({'type': 'session.text.delta'}), isEmpty);
    expect(projectInbox(inboxFrame('enqueued', session: 'ses_other')), isEmpty);
    expect(
      projectInbox(
        inboxFrame('enqueued', session: 'ses_other', item: 'broken'),
      ),
      isEmpty,
    );
  });

  test('malformed and unsupported frames fail atomically by category', () {
    Map<String, Object?> edit(
      Map<String, Object?> frame,
      void Function(Map<String, Object?> data) change,
    ) {
      final copy = jsonDecode(jsonEncode(frame)) as Map<String, Object?>;
      change(copy);
      return copy;
    }

    final base = inboxFrame('enqueued');
    for (final (frame, failure) in [
      (null, OpenCodeInboxProjectionFailure.malformed),
      ({'type': 1}, OpenCodeInboxProjectionFailure.malformed),
      (
        edit(base, (f) => f['id'] = 'bad'),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        edit(base, (f) => f['created'] = 'x'),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        edit(base, (f) => (f['durable']! as Map)['aggregateID'] = 'ses_b'),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        edit(base, (f) => (f['durable']! as Map)['version'] = 2),
        OpenCodeInboxProjectionFailure.unsupportedVersion,
      ),
      (
        edit(base, (f) => (f['durable']! as Map)['seq'] = -1),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        edit(base, (f) => (f['data']! as Map)['inboxID'] = 'evt_x'),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        edit(base, (f) => ((f['data']! as Map)['item']! as Map)['type'] = 'x'),
        OpenCodeInboxProjectionFailure.unsupportedValue,
      ),
      (
        edit(
          base,
          (f) => ((f['data']! as Map)['item']! as Map)['delivery'] = 'now',
        ),
        OpenCodeInboxProjectionFailure.unsupportedValue,
      ),
      (
        inboxFrame('delivery.changed', delivery: 'later'),
        OpenCodeInboxProjectionFailure.unsupportedValue,
      ),
      (
        inboxFrame('enqueued', item: userItem('x', fields: {'files': 'x'})),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        inboxFrame(
          'enqueued',
          item: userItem(
            'x',
            fields: {
              'agents': [
                {
                  'name': 'a',
                  'mention': {'start': 0, 'end': 'x', 'text': ''},
                },
              ],
            },
          ),
        ),
        OpenCodeInboxProjectionFailure.malformed,
      ),
      (
        inboxFrame(
          'enqueued',
          item: userItem(
            'x',
            fields: {
              'agents': List.filled(1025, {'name': 'a'}),
            },
          ),
        ),
        OpenCodeInboxProjectionFailure.limitExceeded,
      ),
      (
        inboxFrame(
          'enqueued',
          item: userItem(
            'x',
            fields: {
              'files': List.filled(17, {
                'data': '',
                'mime': 'm' * 4000,
                'source': {'type': 'inline'},
              }),
            },
          ),
        ),
        OpenCodeInboxProjectionFailure.limitExceeded,
      ),
    ]) {
      expect(() => projectInbox(frame), failsWith(failure));
    }
    for (final version in ['3.0.0', '2.0.22-rc.1', 'x']) {
      expect(
        () => projectInbox(base, version: version),
        failsWith(OpenCodeInboxProjectionFailure.unsupportedVersion),
      );
    }
  });

  test('selected strings are bounded in UTF-8 bytes', () {
    final atLimit = 'é' * (128 * 1024);
    expect(
      projectInbox(inboxFrame('enqueued', item: userItem(atLimit))),
      hasLength(2),
    );
    expect(
      () => projectInbox(inboxFrame('enqueued', item: userItem('${atLimit}x'))),
      failsWith(OpenCodeInboxProjectionFailure.limitExceeded),
    );
    expect(
      () => projectInbox(inboxFrame('enqueued', item: userItem('\ud800'))),
      failsWith(OpenCodeInboxProjectionFailure.malformed),
    );
    expect(
      () => projectInbox(inboxFrame('enqueued', inbox: 'msg_${'a' * 4093}')),
      failsWith(OpenCodeInboxProjectionFailure.limitExceeded),
    );
  });

  test('a resident item of another kind under an inbox ID is rejected', () {
    final state = reduce(
      empty,
      ItemUpserted(
        meta: EventMeta(
          owner: SessionOwner(historyRef),
          position: StreamPosition(
            id: 'observer-a',
            epoch: 'epoch-a',
            seq: BigInt.zero,
          ),
          receivedAt: DateTime.utc(2026, 10, 13),
          source: SourceProvenance(
            harness: historyRef.harnessRef,
            version: '2.0.22',
            nativeType: 'seed',
          ),
        ),
        item: Notice(
          meta: ItemMeta(
            id: userId,
            generation: 'seed',
            status: const OpenValue.known(ItemStatus.completed),
            source: SourceProvenance(
              harness: historyRef.harnessRef,
              version: '2.0.22',
              nativeType: 'seed',
            ),
          ),
          kind: const OpenValue.known(NoticeKind.system),
          text: 'x',
        ),
      ),
    ).state;
    expect(
      () => projectInbox(inboxFrame('delivered'), current: state),
      failsWith(OpenCodeInboxProjectionFailure.itemKindMismatch),
    );
  });
}
