import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

const _host = HostId('host-a');
const _harness = HarnessInstanceId('inst-a');
const _session = SessionRef(_host, _harness, 'ses-1');
const _owner = SessionOwner(_session);
final _source = SourceProvenance(
  harness: _session.harnessRef,
  version: '2.3.2',
  nativeType: 'test',
);

MessageAnchor _anchor(String id) =>
    MessageAnchor(message: MessageRef(id), orderKey: id);

StreamPosition _pos(int seq) =>
    StreamPosition(id: 'stream', epoch: '1', seq: BigInt.from(seq));

EventMeta _meta(int seq) => EventMeta(
  owner: _owner,
  position: _pos(seq),
  receivedAt: DateTime.utc(2026, 11, 23, 12, 0, seq),
  source: _source,
);

PlanEntry _entry(String id, String title, PlanStatus status) =>
    PlanEntry(id: id, title: title, status: OpenValue.known(status));

UserInput _user(
  String id,
  String msgId, {
  DeliveryState delivery = DeliveryState.delivered,
  bool confirmed = false,
}) => UserInput(
  meta: ItemMeta(
    id: ItemId(id),
    generation: 'g1',
    status: const OpenValue.known(ItemStatus.completed),
    source: _source,
    anchor: _anchor(msgId),
  ),
  text: 'prompt $id',
  delivery: OpenValue.known(delivery),
  confirmed: confirmed,
);

void main() {
  group('PlanSnapshot value semantics and capabilities', () {
    test('PlanEntry and PlanSnapshot implement value equality and anchor', () {
      final a = PlanSnapshot(
        owner: _owner,
        anchor: _anchor('msg_002'),
        entries: [_entry('0', 'Step 1', PlanStatus.inProgress)],
      );
      final b = PlanSnapshot(
        owner: _owner,
        anchor: _anchor('msg_002'),
        entries: [_entry('0', 'Step 1', PlanStatus.inProgress)],
      );
      final c = PlanSnapshot(
        owner: _owner,
        anchor: _anchor('msg_003'),
        entries: [_entry('0', 'Step 1', PlanStatus.inProgress)],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(PlanCapabilities.observe, 'plan.observe');
      expect(PlanCapabilities.keys, ['plan.observe']);
    });
  });

  group('planProgress', () {
    test(
      'excludes unknown status and never credits cancelled as completed',
      () {
        final progress = planProgress([
          _entry('0', 'Done', PlanStatus.completed),
          _entry('1', 'Active A', PlanStatus.inProgress),
          _entry('2', 'Active B', PlanStatus.inProgress),
          _entry('3', 'Waiting', PlanStatus.pending),
          _entry('4', 'Dropped', PlanStatus.cancelled),
          _entry('5', 'Mystery', PlanStatus.unknown),
          PlanEntry(
            id: '6',
            title: 'Future',
            status: OpenValue.unknown('deferred'),
          ),
        ]);
        expect(progress.total, 5);
        expect(progress.completed, 1);
        expect(progress.inProgress, 2);
        expect(progress.extraInProgress, 1);
        expect(progress.pending, 1);
        expect(progress.cancelled, 1);
        expect(progress.fraction, closeTo(0.2, 1e-9));
        expect(progress.allCompleted, isFalse);
        expect(progress.allCancelled, isFalse);
        expect(progress.allFinished, isFalse);
      },
    );

    test('reaches 1.0 only when every counted entry is completed', () {
      final allDone = planProgress([
        _entry('0', 'A', PlanStatus.completed),
        _entry('1', 'B', PlanStatus.completed),
      ]);
      expect(allDone.fraction, 1.0);
      expect(allDone.allCompleted, isTrue);
      expect(allDone.allFinished, isTrue);

      final withCancelled = planProgress([
        _entry('0', 'A', PlanStatus.completed),
        _entry('1', 'B', PlanStatus.cancelled),
      ]);
      expect(withCancelled.fraction, 0.5);
      expect(withCancelled.allCompleted, isFalse);
      expect(withCancelled.allCancelled, isFalse);
      expect(withCancelled.allFinished, isTrue);

      final allCancelled = planProgress([
        _entry('0', 'A', PlanStatus.cancelled),
      ]);
      expect(allCancelled.fraction, 0.0);
      expect(allCancelled.allCancelled, isTrue);
      expect(allCancelled.allFinished, isTrue);

      final empty = planProgress(const []);
      expect(empty.total, 0);
      expect(empty.fraction, 0.0);
      expect(empty.allFinished, isFalse);
    });
  });

  group('planCurrentIndex', () {
    test('prefers inProgress, then pending, then last completed, then 0', () {
      expect(planCurrentIndex(const []), -1);
      expect(
        planCurrentIndex([
          _entry('0', 'Done', PlanStatus.completed),
          _entry('1', 'Pending', PlanStatus.pending),
          _entry('2', 'Active', PlanStatus.inProgress),
        ]),
        2,
      );
      expect(
        planCurrentIndex([
          _entry('0', 'Done', PlanStatus.completed),
          _entry('1', 'Pending 1', PlanStatus.pending),
          _entry('2', 'Pending 2', PlanStatus.pending),
        ]),
        1,
      );
      expect(
        planCurrentIndex([
          _entry('0', 'Done 1', PlanStatus.completed),
          _entry('1', 'Done 2', PlanStatus.completed),
          _entry('2', 'Cancelled', PlanStatus.cancelled),
        ]),
        1,
      );
      expect(
        planCurrentIndex([
          _entry('0', 'Cancelled', PlanStatus.cancelled),
          _entry('1', 'Unknown', PlanStatus.unknown),
        ]),
        0,
      );
    });
  });

  group('visiblePlan', () {
    SessionState stateWith({
      PlanSnapshot? plan,
      List<TimelineItem> items = const [],
      List<PendingInput> pending = const [],
      RevertState? revert,
    }) {
      var s = SessionState(_session);
      var seq = 1;
      for (final item in items) {
        s = reduce(s, ItemUpserted(meta: _meta(seq++), item: item)).state;
      }
      if (pending.isNotEmpty) {
        s = reduce(
          s,
          PendingInputChanged(meta: _meta(seq++), items: pending),
        ).state;
      }
      if (plan != null) {
        s = reduce(s, PlanChanged(meta: _meta(seq++), plan: plan)).state;
      }
      if (revert != null) {
        s = reduce(s, RevertChanged(meta: _meta(seq++), state: revert)).state;
      }
      return s;
    }

    test('returns null for null state, missing plan, or empty entries', () {
      expect(visiblePlan(null), isNull);
      expect(visiblePlan(SessionState(_session)), isNull);
      final empty = stateWith(
        plan: PlanSnapshot(
          owner: _owner,
          anchor: _anchor('msg_002'),
          entries: const [],
        ),
      );
      expect(visiblePlan(empty), isNull);
    });

    test('keeps current-turn plan visible including at 100% completed', () {
      final plan = PlanSnapshot(
        owner: _owner,
        anchor: _anchor('msg_002'),
        entries: [_entry('0', 'Done', PlanStatus.completed)],
      );
      final state = stateWith(
        plan: plan,
        items: [_user('u1', 'msg_001', confirmed: true)],
      );
      expect(visiblePlan(state), equals(plan));
    });

    test(
      'clears when an active UserInput or PendingInput orders after plan',
      () {
        final plan = PlanSnapshot(
          owner: _owner,
          anchor: _anchor('msg_002'),
          entries: [_entry('0', 'Done', PlanStatus.completed)],
        );

        for (final delivery in [
          DeliveryState.submitting,
          DeliveryState.accepted,
          DeliveryState.queued,
          DeliveryState.delivered,
        ]) {
          final s = stateWith(
            plan: plan,
            items: [
              _user('u1', 'msg_001', confirmed: true),
              _user('u2', 'msg_003', delivery: delivery),
            ],
          );
          expect(visiblePlan(s), isNull, reason: 'delivery=$delivery');
        }

        // Draft, cancelled, and rejected prompts do not clear the plan.
        for (final delivery in [
          DeliveryState.draft,
          DeliveryState.cancelled,
          DeliveryState.rejected,
        ]) {
          final s = stateWith(
            plan: plan,
            items: [
              _user('u1', 'msg_001', confirmed: true),
              _user('u2', 'msg_003', delivery: delivery),
            ],
          );
          expect(visiblePlan(s), equals(plan), reason: 'delivery=$delivery');
        }

        // PendingInput after plan anchor clears immediately.
        final queued = stateWith(
          plan: plan,
          pending: [
            PendingInput(
              id: const ItemId('p1'),
              text: 'next prompt',
              delivery: const OpenValue.known(Delivery.queue),
              anchor: _anchor('msg_003'),
            ),
          ],
        );
        expect(visiblePlan(queued), isNull);
      },
    );

    test(
      'respects staged revert cut and ignores committed revert as visual cut',
      () {
        final plan = PlanSnapshot(
          owner: _owner,
          anchor: _anchor('msg_002'),
          entries: [_entry('0', 'Step 1', PlanStatus.inProgress)],
        );

        // Plan at/after staged cut is hidden.
        final cutPlan = stateWith(
          plan: plan,
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.staged),
            anchor: _anchor('msg_002'),
          ),
        );
        expect(visiblePlan(cutPlan), isNull);

        // Anchorless plan is hidden during staged revert, visible otherwise.
        final anchorlessPlan = PlanSnapshot(
          owner: _owner,
          entries: [_entry('0', 'Native step', PlanStatus.inProgress)],
        );
        expect(
          visiblePlan(stateWith(plan: anchorlessPlan)),
          equals(anchorlessPlan),
        );
        expect(
          visiblePlan(
            stateWith(
              plan: anchorlessPlan,
              revert: RevertState(
                kind: const OpenValue.known(RevertKind.staged),
                anchor: _anchor('msg_005'),
              ),
            ),
          ),
          isNull,
        );

        // User prompt inside staged cut does NOT clear an earlier plan.
        final cutNewTurn = stateWith(
          plan: plan,
          items: [
            _user('u1', 'msg_001', confirmed: true),
            _user('u2', 'msg_003', confirmed: true),
          ],
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.staged),
            anchor: _anchor('msg_003'),
          ),
        );
        expect(visiblePlan(cutNewTurn), equals(plan));

        // Committed revert is NOT a visual cut.
        final committed = stateWith(
          plan: plan,
          revert: RevertState(
            kind: const OpenValue.known(RevertKind.committed),
            anchor: _anchor('msg_001'),
          ),
        );
        expect(visiblePlan(committed), equals(plan));

        // useStateRevert: false respects a cleared turnActions overlay.
        expect(
          visiblePlan(cutPlan, stagedCut: null, useStateRevert: false),
          equals(plan),
        );
      },
    );

    test(
      'clears on promoted queued prompt ordered after plan message even with smaller msg ID',
      () {
        final plan = PlanSnapshot(
          owner: _owner,
          anchor: _anchor('msg_003'),
          entries: [_entry('0', 'Turn 1 step', PlanStatus.completed)],
        );
        final planMessageItem = AssistantText(
          meta: ItemMeta(
            id: const ItemId('a1'),
            generation: 'g1',
            status: const OpenValue.known(ItemStatus.completed),
            source: _source,
            anchor: _anchor('msg_003'),
          ),
          text: 'Turn 1 finished',
          complete: true,
        );
        // Queued prompt allocated msg_002 during Turn 1, promoted after msg_003.
        final promoted = _user('u2', 'msg_002', confirmed: true);
        final s = stateWith(
          plan: plan,
          items: [
            _user('u1', 'msg_001', confirmed: true),
            planMessageItem,
            promoted,
          ],
        );
        expect(visiblePlan(s), isNull);
      },
    );

    test(
      'limitTimeline clears superseded plan when evicting its clearing UserInput',
      () {
        var s = SessionState(
          _session,
          limits: const ReducerLimits(maxItems: 4),
        );
        var seq = 1;
        EventMeta meta() => _meta(seq++);
        s = reduce(
          s,
          ItemUpserted(
            meta: meta(),
            item: _user('u1', 'msg_001', confirmed: true),
          ),
        ).state;
        s = reduce(
          s,
          PlanChanged(
            meta: meta(),
            plan: PlanSnapshot(
              owner: _owner,
              anchor: _anchor('msg_002'),
              entries: [_entry('0', 'Old turn task', PlanStatus.completed)],
            ),
          ),
        ).state;
        s = reduce(
          s,
          ItemUpserted(
            meta: meta(),
            item: _user('u2', 'msg_003', confirmed: true),
          ),
        ).state;
        expect(visiblePlan(s), isNull);

        // Push 4 more assistant items so u1 and u2 are both evicted past maxItems=4.
        for (var i = 0; i < 4; i++) {
          s = reduce(
            s,
            ItemUpserted(
              meta: meta(),
              item: AssistantText(
                meta: ItemMeta(
                  id: ItemId('a_$i'),
                  generation: 'g1',
                  status: const OpenValue.known(ItemStatus.completed),
                  source: _source,
                  anchor: _anchor('msg_00${4 + i}'),
                ),
                text: 'Turn 2 item $i',
                complete: true,
              ),
            ),
          ).state;
        }
        expect(s.plan?.entries, isEmpty);
        expect(s.plan?.anchor, _anchor('msg_003'));
        expect(visiblePlan(s), isNull);
      },
    );

    test(
      'limitTimeline clears superseded plan when plan message is evicted before smaller-ID promoted prompt',
      () {
        var s = SessionState(
          _session,
          limits: const ReducerLimits(maxItems: 3),
        );
        var seq = 1;
        EventMeta meta() => _meta(seq++);
        // Plan message at msg_003, followed by promoted queued prompt with smaller ID msg_002.
        s = reduce(
          s,
          ItemUpserted(
            meta: meta(),
            item: AssistantText(
              meta: ItemMeta(
                id: const ItemId('a_plan'),
                generation: 'g1',
                status: const OpenValue.known(ItemStatus.completed),
                source: _source,
                anchor: _anchor('msg_003'),
              ),
              text: 'Plan turn text',
              complete: true,
            ),
          ),
        ).state;
        s = reduce(
          s,
          PlanChanged(
            meta: meta(),
            plan: PlanSnapshot(
              owner: _owner,
              anchor: _anchor('msg_003'),
              entries: [_entry('0', 'Turn 1 task', PlanStatus.completed)],
            ),
          ),
        ).state;
        s = reduce(
          s,
          ItemUpserted(
            meta: meta(),
            item: _user('u_promoted', 'msg_002', confirmed: true),
          ),
        ).state;
        expect(visiblePlan(s), isNull);

        // Add two more items so maxItems=3 evicts a_plan (msg_003) while keeping u_promoted (msg_002).
        for (var i = 0; i < 2; i++) {
          s = reduce(
            s,
            ItemUpserted(
              meta: meta(),
              item: AssistantText(
                meta: ItemMeta(
                  id: ItemId('a_after_$i'),
                  generation: 'g1',
                  status: const OpenValue.known(ItemStatus.completed),
                  source: _source,
                  anchor: _anchor('msg_00${4 + i}'),
                ),
                text: 'After $i',
                complete: true,
              ),
            ),
          ).state;
        }
        expect(s.timeline.first.id, const ItemId('u_promoted'));
        expect(s.plan?.entries, isEmpty);
        expect(s.plan?.anchor, _anchor('msg_002'));
        expect(visiblePlan(s), isNull);
      },
    );
  });
}
