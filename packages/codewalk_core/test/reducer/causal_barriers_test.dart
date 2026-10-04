import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'synthetic_reducer_test.dart' as synthetic;

// These are controlled canonical interleavings, not additional native capture.
// A client read-start position belongs to one observer stream. Each event uses
// a distinct synthetic native ID so dedup cannot conceal a stale-clock defect.
void main() {
  group('synthetic hydration read-start barriers', () {
    test('authoritative idle at 20 rejects buffered running through 20', () {
      var state = _hydrateAt20(
        SessionSnapshot(
          ref: synthetic.ref,
          hydrationGeneration: 'hydration',
          execution: SnapshotValue(
            value: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
              lastOutcome: ExecutionOutcome(
                OpenValue.known(ExecutionOutcomeKind.succeeded),
              ),
            ),
            boundary: synthetic.boundary(20),
          ),
        ),
      );
      for (final seq in [10, 20]) {
        final stale = reduce(
          state,
          ExecutionChanged(
            meta: _meta(seq, 'running-$seq'),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
          ),
        );
        expect(stale.state.execution!.kind.known, ExecutionKind.idle);
        expect(
          stale.state.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
        expect(stale.effects, isEmpty);
        state = stale.state;
      }
      final newer = reduce(
        state,
        ExecutionChanged(
          meta: _meta(21, 'running-newer'),
          state: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.running),
          ),
        ),
      );
      expect(newer.state.execution!.kind.known, ExecutionKind.running);
      expect(newer.effects.whereType<Notify>(), hasLength(1));
    });

    test(
      'hydrated request rejects old opening and resolution, then accepts new',
      () {
        var state = _hydrateAt20(
          _interactionsAt20([_request('q', 'hydrated')]),
        );
        for (final seq in [10, 20]) {
          final oldResolve = reduce(
            state,
            _resolved('q', seq, 'old-resolve-$seq'),
          );
          expect(oldResolve.state.interactions.single.title, 'hydrated');
          expect(oldResolve.effects, isEmpty);
          final oldOpen = reduce(
            oldResolve.state,
            _opened('q', 'stale', seq, 'old-open-$seq'),
          );
          expect(oldOpen.state.interactions.single.title, 'hydrated');
          expect(oldOpen.effects, isEmpty);
          state = oldOpen.state;
        }
        final newResolve = reduce(state, _resolved('q', 21, 'new-resolve'));
        expect(newResolve.state.interactions, isEmpty);
        expect(newResolve.effects.whereType<Notify>(), hasLength(1));
        final newOpen = reduce(
          newResolve.state,
          _opened('q', 'new current request', 22, 'new-open'),
        );
        expect(newOpen.state.interactions.single.title, 'new current request');
        expect(newOpen.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test(
      'hydrated cumulative series rejects older IDs and accepts newer total',
      () {
        var state = _hydrateAt20(_usageAt20([_usage('hydrated', 100)]));
        for (final seq in [10, 20]) {
          for (final id in ['hydrated', 'different-$seq']) {
            final stale = reduce(
              state,
              _usageEvent(_usage(id, 1), seq, 'usage-$id-$seq'),
            );
            expect(stale.state.usage.single.id, 'hydrated');
            expect(stale.state.usage.single.tokens!.input, 100);
            expect(stale.effects, isEmpty);
            state = stale.state;
          }
        }
        final newer = reduce(
          state,
          _usageEvent(_usage('newer', 125), 21, 'newer-total'),
        );
        expect(newer.state.usage, hasLength(1));
        expect(newer.state.usage.single.id, 'newer');
        expect(newer.state.usage.single.tokens!.input, 125);
        expect(newer.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test(
      'complete authoritative empty timeline fences absent buffered rows',
      () {
        var state = _hydrateAt20(synthetic.history(const [], 20));
        for (final seq in [10, 20]) {
          final stale = reduce(
            state,
            ItemUpserted(
              meta: _meta(seq, 'absent-text-$seq'),
              item: synthetic.text('absent-$seq', 'stale'),
            ),
          );
          expect(stale.state.timeline, isEmpty);
          expect(stale.effects, isEmpty);
          state = stale.state;
        }
        final newer = reduce(
          state,
          ItemUpserted(
            meta: _meta(21, 'new-text'),
            item: synthetic.text('new', 'current'),
          ),
        );
        expect((newer.state.timeline.single as AssistantText).text, 'current');
        expect(newer.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test('complete authoritative empty interactions fence absent requests', () {
      var state = _hydrateAt20(_interactionsAt20(const []));
      for (final seq in [10, 20]) {
        final oldResolve = reduce(
          state,
          _resolved('absent', seq, 'absent-resolution-$seq'),
        );
        expect(oldResolve.state.interactions, isEmpty);
        expect(oldResolve.effects, isEmpty);
        final oldOpen = reduce(
          oldResolve.state,
          _opened('absent', 'stale', seq, 'absent-opening-$seq'),
        );
        expect(oldOpen.state.interactions, isEmpty);
        expect(oldOpen.effects, isEmpty);
        state = oldOpen.state;
      }
      final newer = reduce(
        state,
        _opened('absent', 'current', 21, 'current-q'),
      );
      expect(newer.state.interactions.single.title, 'current');
      expect(newer.effects.whereType<Notify>(), hasLength(1));
    });

    test(
      'complete authoritative empty usage fences absent cumulative series',
      () {
        var state = _hydrateAt20(_usageAt20(const []));
        for (final seq in [10, 20]) {
          final stale = reduce(
            state,
            _usageEvent(_usage('missing-$seq', 1), seq, 'missing-usage-$seq'),
          );
          expect(stale.state.usage, isEmpty);
          expect(stale.effects, isEmpty);
          state = stale.state;
        }
        final newer = reduce(
          state,
          _usageEvent(_usage('new', 8), 21, 'new-usage'),
        );
        expect(newer.state.usage.single.tokens!.input, 8);
        expect(newer.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test(
      'incomplete interaction read protects its row without fencing absence',
      () {
        var state = _hydrateAt20(
          _interactionsAt20([_request('known', 'hydrated')], complete: false),
        );
        for (final seq in [10, 20]) {
          final staleOpen = reduce(
            state,
            _opened('known', 'stale', seq, 'partial-known-open-$seq'),
          );
          expect(staleOpen.state.interactions.single.title, 'hydrated');
          expect(staleOpen.effects, isEmpty);
          final staleResolve = reduce(
            staleOpen.state,
            _resolved('known', seq, 'partial-known-resolve-$seq'),
          );
          expect(staleResolve.state.interactions.single.title, 'hydrated');
          expect(staleResolve.effects, isEmpty);
          state = staleResolve.state;
        }
        final absentOpen = reduce(
          state,
          _opened(
            'unobserved',
            'buffered unrelated request',
            10,
            'partial-absent',
          ),
        );
        expect(absentOpen.state.interactions.map((row) => row.id.value), [
          'known',
          'unobserved',
        ]);
        expect(absentOpen.effects.whereType<Notify>(), hasLength(1));
        final currentResolve = reduce(
          absentOpen.state,
          _resolved('known', 21, 'partial-current-resolve'),
        );
        expect(
          currentResolve.state.interactions.single.id,
          const InteractionId('unobserved'),
        );
        expect(currentResolve.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test(
      'incomplete usage read protects its series without fencing other series',
      () {
        var state = _hydrateAt20(
          _usageAt20([_usage('known', 100)], complete: false),
        );
        for (final seq in [10, 20]) {
          for (final id in ['known', 'same-series-$seq']) {
            final stale = reduce(
              state,
              _usageEvent(_usage(id, 1), seq, 'partial-usage-$id-$seq'),
            );
            expect(stale.state.usage.single.id, 'known');
            expect(stale.state.usage.single.tokens!.input, 100);
            expect(stale.effects, isEmpty);
            state = stale.state;
          }
        }
        final unobserved = reduce(
          state,
          _usageEvent(
            _usage('other', 7, series: 'other-series'),
            10,
            'other-series',
          ),
        );
        expect(unobserved.state.usage.map((row) => row.id), ['known', 'other']);
        expect(unobserved.effects.whereType<Notify>(), hasLength(1));
        final current = reduce(
          unobserved.state,
          _usageEvent(_usage('new-current', 130), 21, 'partial-current-usage'),
        );
        expect(current.state.usage.map((row) => row.id), [
          'new-current',
          'other',
        ]);
        expect(current.state.usage.first.tokens!.input, 130);
        expect(current.effects.whereType<Notify>(), hasLength(1));
      },
    );

    test(
      'derived empty collections leave unobserved buffered rows admissible',
      () {
        final derived = synthetic.boundary(
          20,
          authority: SnapshotAuthority.derived,
        );
        var state = _hydrateAt20(
          SessionSnapshot(
            ref: synthetic.ref,
            hydrationGeneration: 'hydration',
            timeline: SnapshotCollection<TimelineItem>(
              values: const [],
              boundary: derived,
            ),
            interactions: SnapshotCollection<InteractionRequest>(
              values: const [],
              boundary: derived,
            ),
            usage: SnapshotCollection<UsageObservation>(
              values: const [],
              boundary: derived,
            ),
          ),
        );
        final text = reduce(
          state,
          ItemUpserted(
            meta: _meta(10, 'derived-text'),
            item: synthetic.text('buffered', 'retained'),
          ),
        );
        expect(text.state.timeline, hasLength(1));
        expect(text.effects.whereType<Notify>(), hasLength(1));
        state = reduce(
          text.state,
          _opened('q', 'retained', 10, 'derived-q'),
        ).state;
        final usage = reduce(
          state,
          _usageEvent(_usage('buffered', 4), 10, 'derived-usage'),
        );
        expect(usage.state.timeline, hasLength(1));
        expect(usage.state.interactions, hasLength(1));
        expect(usage.state.usage.single.tokens!.input, 4);
        expect(usage.effects.whereType<Notify>(), hasLength(1));
      },
    );
  });

  group('synthetic interaction resolution tombstone ordering', () {
    test('older and equal resolutions cannot weaken a newer tombstone', () {
      var state = reduce(
        synthetic.initial(),
        _resolved('q', 10, 'resolution-first'),
      ).state;
      for (final seq in [5, 10]) {
        final repeated = reduce(
          state,
          _resolved('q', seq, 'resolution-reordered-$seq'),
        );
        expect(repeated.state.interactions, isEmpty);
        expect(repeated.effects, isEmpty);
        state = repeated.state;
      }
      final lateOpen = reduce(
        state,
        _opened('q', 'obsolete', 7, 'obsolete-open'),
      );
      expect(lateOpen.state.interactions, isEmpty);
      expect(lateOpen.effects, isEmpty);
      final currentOpen = reduce(
        lateOpen.state,
        _opened('q', 'current', 11, 'current-open'),
      );
      expect(currentOpen.state.interactions.single.title, 'current');
      expect(currentOpen.effects.whereType<Notify>(), hasLength(1));
      final oldResolve = reduce(
        currentOpen.state,
        _resolved('q', 10, 'old-resolution-after-open'),
      );
      expect(oldResolve.state.interactions.single.title, 'current');
      expect(oldResolve.effects, isEmpty);
    });
  });

  group('synthetic final history page and resident item cap', () {
    test(
      'older final page trims merged 502 rows and preserves older availability',
      () {
        var state = _hydrateAt20(
          synthetic.history([
            for (var i = 0; i < 500; i++)
              synthetic.text('resident-$i', '$i', complete: true),
          ], 20),
        );
        expect(state.timeline, hasLength(500));
        expect(state.hasMoreHistory, isFalse);
        state = synthetic.hydrating(state, seq: 21, generation: 'older-page');
        final finalPage = hydrate(
          state,
          synthetic.history(
            [
              synthetic.text('older-0', 'older zero', complete: true),
              synthetic.text('older-1', 'older one', complete: true),
            ],
            21,
            generation: 'older-page',
            complete: false,
            hasMore: false,
          ),
        );
        expect(finalPage.state.timeline, hasLength(500));
        expect(finalPage.state.timeline.first.id, const ItemId('resident-0'));
        expect(finalPage.state.timeline.last.id, const ItemId('resident-499'));
        expect(finalPage.state.hasMoreHistory, isTrue);
        expect(finalPage.state.nextHistoryCursor, isNull);

        // A later final page containing only already resident rows causes no
        // additional truncation. It cannot restore the two discarded old rows.
        final repeated = hydrate(
          synthetic.hydrating(
            finalPage.state,
            seq: 22,
            generation: 'repeat-page',
          ),
          synthetic.history(
            [
              synthetic.text('resident-0', '0', complete: true),
              synthetic.text('resident-1', '1', complete: true),
            ],
            22,
            generation: 'repeat-page',
            complete: false,
            hasMore: false,
          ),
        );
        expect(repeated.state.timeline, hasLength(500));
        expect(repeated.state.hasMoreHistory, isTrue);
        expect(repeated.state.nextHistoryCursor, isNull);

        // A complete authoritative replacement can truthfully close the history
        // window when the source now contains only these two resident rows.
        final complete = hydrate(
          synthetic.hydrating(
            repeated.state,
            seq: 23,
            generation: 'complete-small',
          ),
          synthetic.history(
            [
              synthetic.text('resident-0', '0', complete: true),
              synthetic.text('resident-1', '1', complete: true),
            ],
            23,
            generation: 'complete-small',
            hasMore: false,
          ),
        );
        expect(complete.state.timeline, hasLength(2));
        expect(complete.state.hasMoreHistory, isFalse);
        expect(complete.state.nextHistoryCursor, isNull);
      },
    );

    test(
      'uncapped partial merge has no known local history incompleteness',
      () {
        var state = _hydrateAt20(
          synthetic.history([
            synthetic.text('resident-0', 'zero', complete: true),
            synthetic.text('resident-1', 'one', complete: true),
          ], 20),
        );
        state = synthetic.hydrating(
          state,
          seq: 21,
          generation: 'small-older-page',
        );
        final result = hydrate(
          state,
          synthetic.history(
            [
              synthetic.text('older-0', 'older zero', complete: true),
              synthetic.text('older-1', 'older one', complete: true),
            ],
            21,
            generation: 'small-older-page',
            complete: false,
            hasMore: false,
          ),
        );
        expect(result.state.timeline.map((row) => row.id.value), [
          'older-0',
          'older-1',
          'resident-0',
          'resident-1',
        ]);
        expect(result.state.hasMoreHistory, isFalse);
        expect(result.state.nextHistoryCursor, isNull);
      },
    );
  });
}

SessionState _hydrateAt20(SessionSnapshot snapshot) =>
    hydrate(synthetic.hydrating(synthetic.initial(), seq: 20), snapshot).state;

EventMeta _meta(int seq, String id) =>
    synthetic.meta(seq, nativeId: 'synthetic-causal:$id');

InteractionRequest _request(String id, String title) => InteractionRequest(
  id: InteractionId(id),
  owner: const SessionOwner(synthetic.ref),
  kind: const OpenValue.known(InteractionKind.question),
  title: title,
);

InteractionOpened _opened(String id, String title, int seq, String eventId) =>
    InteractionOpened(meta: _meta(seq, eventId), request: _request(id, title));

InteractionResolved _resolved(String id, int seq, String eventId) =>
    InteractionResolved(
      meta: _meta(seq, eventId),
      resolution: InteractionResolution(
        id: InteractionId(id),
        owner: const SessionOwner(synthetic.ref),
        kind: const OpenValue.known(InteractionResolutionKind.elsewhere),
      ),
    );

SessionSnapshot _interactionsAt20(
  Iterable<InteractionRequest> requests, {
  bool complete = true,
}) => SessionSnapshot(
  ref: synthetic.ref,
  hydrationGeneration: 'hydration',
  interactions: SnapshotCollection(
    values: requests,
    boundary: synthetic.boundary(20),
    complete: complete,
  ),
);

UsageObservation _usage(
  String id,
  int input, {
  String series = 'session-total',
}) => UsageObservation(
  id: id,
  owner: const SessionOwner(synthetic.ref),
  scope: const OpenValue.known(UsageScope.session),
  source: const OpenValue.known(UsageSource.native),
  observedAt: synthetic.now,
  tokens: TokenBreakdown(input: input),
  cumulative: true,
  aggregationKey: series,
  provenance: synthetic.source('synthetic.cumulative.usage'),
);

UsageObserved _usageEvent(UsageObservation observation, int seq, String id) =>
    UsageObserved(meta: _meta(seq, id), observation: observation);

SessionSnapshot _usageAt20(
  Iterable<UsageObservation> observations, {
  bool complete = true,
}) => SessionSnapshot(
  ref: synthetic.ref,
  hydrationGeneration: 'hydration',
  usage: SnapshotCollection(
    values: observations,
    boundary: synthetic.boundary(20),
    complete: complete,
  ),
);
