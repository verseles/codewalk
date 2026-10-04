import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'synthetic_reducer_test.dart' as synthetic;

// Controlled event/read interleavings, not additional native acceptance evidence.
void main() {
  test('stream-boundary rejection survives unrelated reads until recovery', () {
    final state = synthetic.hydrating(synthetic.initial(), seq: 10);
    final rejected = hydrate(
      state,
      SessionSnapshot(
        ref: synthetic.ref,
        hydrationGeneration: 'hydration',
        execution: SnapshotValue(
          value: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.running),
          ),
          boundary: synthetic.boundary(10, epoch: 'old-stream'),
        ),
      ),
    );
    expect(rejected.effects.whereType<Rehydrate>(), hasLength(1));
    expect(rejected.state.execution, isNull);
    final unrelated = hydrate(rejected.state, synthetic.history(const [], 11));
    expect(unrelated.state.connection.kind.known, ConnectionKind.hydrating);
    final recovered = hydrate(
      unrelated.state,
      SessionSnapshot(
        ref: synthetic.ref,
        hydrationGeneration: 'hydration',
        execution: SnapshotValue(
          value: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.idle),
          ),
          boundary: synthetic.boundary(12),
        ),
      ),
    );
    expect(recovered.state.connection.kind.known, ConnectionKind.live);
    expect(recovered.state.execution!.kind.known, ExecutionKind.idle);
  });

  test('removed suffix rejects unseen old upserts but admits newer rows', () {
    var state = synthetic.upsert(
      synthetic.initial(),
      synthetic.text('a', 'a'),
      1,
    );
    state = synthetic.upsert(state, synthetic.text('b', 'b'), 2);
    state = reduce(
      state,
      ItemsRemoved(meta: synthetic.meta(4), fromItemId: const ItemId('b')),
    ).state;
    final stale = reduce(
      state,
      ItemUpserted(
        meta: synthetic.meta(3, nativeId: 'unseen-completion'),
        item: synthetic.text('b', 'removed complete text', complete: true),
      ),
    );
    expect(stale.state.timeline.map((item) => item.id.value), ['a']);
    expect(stale.effects.whereType<Refetch>(), hasLength(1));
    final newer = synthetic.upsert(stale.state, synthetic.text('c', 'new'), 5);
    expect(newer.timeline.map((item) => item.id.value), ['a', 'c']);
  });

  test(
    'delayed removal preserves a newer suffix and requests reconciliation',
    () {
      var state = synthetic.upsert(
        synthetic.initial(),
        synthetic.text('a', 'a'),
        1,
      );
      state = synthetic.upsert(state, synthetic.text('b', 'newer'), 5);
      final result = reduce(
        state,
        ItemsRemoved(meta: synthetic.meta(3), fromItemId: const ItemId('b')),
      );
      expect(result.state.timeline.map((item) => item.id.value), ['a', 'b']);
      expect(
        result.effects.whereType<Refetch>().single.reason,
        'removalBeforeItem',
      );
      expect(result.effects.whereType<Notify>(), isEmpty);
    },
  );

  test(
    'late start corrects two-row order and notifies without reopening text',
    () {
      var state = synthetic.upsert(
        synthetic.initial(),
        synthetic.text('b', 'b'),
        3,
      );
      state = synthetic.upsert(
        state,
        synthetic.text('a', 'full', complete: true),
        5,
      );
      final result = reduce(
        state,
        ItemUpserted(meta: synthetic.meta(1), item: synthetic.text('a', '')),
      );
      expect(result.state.timeline.map((item) => item.id.value), ['a', 'b']);
      expect((result.state.timeline.first as AssistantText).text, 'full');
      expect((result.state.timeline.first as AssistantText).complete, isTrue);
      expect(result.effects.whereType<Notify>(), hasLength(1));
    },
  );

  test('published history anchors a sequence-ordered live suffix', () {
    var state = hydrate(
      synthetic.hydrating(synthetic.initial(), seq: 2),
      synthetic.history([
        synthetic.text('history', 'published', complete: true),
      ], 2),
    ).state;
    state = synthetic.upsert(state, synthetic.text('b', 'later'), 4);
    state = synthetic.upsert(state, synthetic.text('a', 'earlier'), 3);
    expect(state.timeline.map((item) => item.id.value), ['history', 'a', 'b']);
  });

  for (final cap in [3, 4]) {
    test(
      'overlapping partial tail preserves chronology with resident cap $cap',
      () {
        var state = hydrate(
          synthetic.hydrating(
            synthetic.initial(limits: ReducerLimits(maxItems: cap)),
            seq: 3,
          ),
          synthetic.history([
            for (final id in ['a', 'b', 'c'])
              synthetic.text(id, id, complete: true),
          ], 3),
        ).state;
        state = hydrate(
          synthetic.hydrating(state, seq: 4),
          synthetic.history(
            [
              for (final id in ['b', 'c', 'd'])
                synthetic.text(id, id, complete: true),
            ],
            4,
            complete: false,
          ),
        ).state;
        expect(
          state.timeline.map((item) => item.id.value),
          cap == 3 ? ['b', 'c', 'd'] : ['a', 'b', 'c', 'd'],
        );
        expect(state.hasMoreHistory, cap == 3);
      },
    );
  }

  test(
    'reverse read completion at equal stream positions retains the later read',
    () {
      SnapshotBoundary boundary(int milliseconds) => SnapshotBoundary(
        owner: const SessionOwner(synthetic.ref),
        hydrationGeneration: 'hydration',
        readStart: synthetic.pos(10),
        readStartedAt: synthetic.now.add(Duration(milliseconds: milliseconds)),
        authority: const OpenValue.known(SnapshotAuthority.authoritative),
      );
      SessionSnapshot snapshot(int milliseconds, bool pending) =>
          SessionSnapshot(
            ref: synthetic.ref,
            hydrationGeneration: 'hydration',
            interactions: SnapshotCollection(
              values: [
                if (pending)
                  InteractionRequest(
                    id: const InteractionId('answered'),
                    owner: const SessionOwner(synthetic.ref),
                    kind: const OpenValue.known(InteractionKind.question),
                    title: 'old question',
                  ),
              ],
              boundary: boundary(milliseconds),
            ),
          );
      final cleared = hydrate(
        synthetic.hydrating(synthetic.initial(), seq: 10),
        snapshot(2, false),
      );
      final late = hydrate(cleared.state, snapshot(1, true));
      expect(late.state.interactions, isEmpty);
      expect(late.effects, isEmpty);
    },
  );

  for (final authority in [
    SnapshotAuthority.authoritative,
    SnapshotAuthority.derived,
  ]) {
    test(
      'unapplied $authority work snapshot requires a refetch before live',
      () {
        final result = hydrate(
          synthetic.hydrating(synthetic.initial(), seq: 10),
          SessionSnapshot(
            ref: synthetic.ref,
            hydrationGeneration: 'hydration',
            execution: SnapshotValue(
              value: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
              boundary: synthetic.boundary(10),
            ),
            work: SnapshotCollection(
              values: const [
                WorkItem(
                  id: WorkId('job'),
                  owner: SessionOwner(synthetic.ref),
                  status: OpenValue.known(WorkStatus.running),
                  completionScope: OpenValue.known(CompletionScope.work),
                ),
              ],
              boundary: synthetic.boundary(10, authority: authority),
              complete: authority == SnapshotAuthority.derived,
            ),
          ),
        );
        expect(result.state.connection.kind.known, ConnectionKind.hydrating);
        expect(
          result.effects.whereType<Refetch>().single.collection,
          SessionCollection.work,
        );
        final unrelated = hydrate(
          result.state,
          SessionSnapshot(
            ref: synthetic.ref,
            hydrationGeneration: 'hydration',
            execution: SnapshotValue(
              value: const ExecutionState(
                kind: OpenValue.known(ExecutionKind.idle),
              ),
              boundary: synthetic.boundary(11),
            ),
          ),
        );
        expect(unrelated.state.connection.kind.known, ConnectionKind.hydrating);
        expect(unrelated.state.work, isEmpty);
        final replacement = hydrate(
          unrelated.state,
          SessionSnapshot(
            ref: synthetic.ref,
            hydrationGeneration: 'hydration',
            work: SnapshotCollection(
              values: const [
                WorkItem(
                  id: WorkId('job'),
                  owner: SessionOwner(synthetic.ref),
                  status: OpenValue.known(WorkStatus.running),
                  completionScope: OpenValue.known(CompletionScope.work),
                ),
              ],
              boundary: synthetic.boundary(11),
            ),
          ),
        );
        expect(replacement.state.work.single.id, const WorkId('job'));
        expect(replacement.state.connection.kind.known, ConnectionKind.live);
      },
    );
  }
  test(
    'unapplied removal still fences older history until authoritative recovery',
    () {
      var state = synthetic.upsert(
        synthetic.initial(),
        synthetic.text('a', 'a'),
        1,
      );
      state = synthetic.upsert(state, synthetic.text('b', 'newer'), 5);
      state = synthetic.hydrating(state, seq: 5);
      state = reduce(
        state,
        ItemsRemoved(meta: synthetic.meta(3), fromItemId: const ItemId('b')),
      ).state;
      final delayed = reduce(
        state,
        ItemUpserted(
          meta: synthetic.meta(2, nativeId: 'unseen-old-row'),
          item: synthetic.text('unseen', 'membership unknown'),
        ),
      );
      expect(delayed.state.timeline.map((item) => item.id.value), ['a', 'b']);
      expect(
        delayed.effects.whereType<Refetch>().single.reason,
        'itemBeforeRemoval',
      );
      final stale = hydrate(
        delayed.state,
        synthetic.history([
          synthetic.text('a', 'a'),
          synthetic.text('removed', 'obsolete history'),
        ], 2),
      );
      expect(stale.state.timeline.map((item) => item.id.value), ['a', 'b']);
      expect(
        stale.effects.whereType<Refetch>().single.reason,
        'historyReadBeforeRemoval',
      );
      final unrelated = hydrate(
        stale.state,
        SessionSnapshot(
          ref: synthetic.ref,
          hydrationGeneration: 'hydration',
          execution: SnapshotValue(
            value: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
            boundary: synthetic.boundary(6),
          ),
        ),
      );
      expect(unrelated.state.connection.kind.known, ConnectionKind.hydrating);
      final recovered = hydrate(
        unrelated.state,
        synthetic.history([
          synthetic.text('a', 'a'),
          synthetic.text('unseen', 'confirmed retained'),
          synthetic.text('b', 'newer'),
        ], 6),
      );
      expect(recovered.state.timeline.map((item) => item.id.value), [
        'a',
        'unseen',
        'b',
      ]);
      expect(recovered.state.connection.kind.known, ConnectionKind.live);
    },
  );
}
