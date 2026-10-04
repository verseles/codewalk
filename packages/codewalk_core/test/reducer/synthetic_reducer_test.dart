import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

const ref = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'session',
);
const child = SessionRef(
  HostId('host'),
  HarnessInstanceId('instance'),
  'child',
);
final now = DateTime.utc(2026, 10, 4);

StreamPosition pos(int value, {String epoch = 'epoch'}) =>
    StreamPosition(id: 'stream', epoch: epoch, seq: BigInt.from(value));
SourceProvenance source(String type, {String? id}) => SourceProvenance(
  harness: ref.harnessRef,
  version: 'synthetic-1',
  nativeType: type,
  nativeEventId: id,
);
EventMeta meta(
  int value, {
  String? nativeId,
  DomainOwner? owner,
  String epoch = 'epoch',
}) => EventMeta(
  owner: owner ?? const SessionOwner(ref),
  position: pos(value, epoch: epoch),
  receivedAt: now,
  source: source('synthetic', id: nativeId),
);
ItemMeta itemMeta(
  String id, {
  String generation = 'generation',
  ItemStatus status = ItemStatus.streaming,
}) => ItemMeta(
  id: ItemId(id),
  generation: generation,
  status: OpenValue.known(status),
  source: source('synthetic.item'),
);
AssistantText text(
  String id,
  String value, {
  String generation = 'generation',
  bool complete = false,
}) => AssistantText(
  meta: itemMeta(
    id,
    generation: generation,
    status: complete ? ItemStatus.completed : ItemStatus.streaming,
  ),
  text: value,
  complete: complete,
);
UserInput user(String id, {DeliveryState delivery = DeliveryState.accepted}) =>
    UserInput(
      meta: itemMeta(id, status: ItemStatus.pending),
      text: 'admitted $id',
      delivery: OpenValue.known(delivery),
    );
SessionState initial({ReducerLimits limits = const ReducerLimits()}) =>
    SessionState(ref, limits: limits, streamPosition: pos(0));
SessionState upsert(
  SessionState state,
  TimelineItem item,
  int seq, {
  String? nativeId,
}) => reduce(
  state,
  ItemUpserted(
    meta: meta(seq, nativeId: nativeId),
    item: item,
  ),
).state;
ItemDelta delta(
  String id,
  String value,
  int seq, {
  String generation = 'generation',
  String? nativeId,
  OpenValue<DeltaField>? field,
}) => ItemDelta(
  meta: meta(seq, nativeId: nativeId),
  itemId: ItemId(id),
  field: field ?? const OpenValue.known(DeltaField.text),
  text: value,
  generation: generation,
);
SnapshotBoundary boundary(
  int seq, {
  String generation = 'hydration',
  SnapshotAuthority authority = SnapshotAuthority.authoritative,
  String epoch = 'epoch',
}) => SnapshotBoundary(
  owner: const SessionOwner(ref),
  hydrationGeneration: generation,
  readStart: pos(seq, epoch: epoch),
  readStartedAt: now,
  authority: OpenValue.known(authority),
);
SessionState hydrating(
  SessionState state, {
  int seq = 0,
  String generation = 'hydration',
  String epoch = 'epoch',
}) => beginHydration(
  state,
  generation: generation,
  readStart: pos(seq, epoch: epoch),
);
SessionSnapshot history(
  Iterable<TimelineItem> items,
  int seq, {
  bool complete = true,
  String generation = 'hydration',
  SnapshotAuthority authority = SnapshotAuthority.authoritative,
  bool hasMore = false,
}) => SessionSnapshot(
  ref: ref,
  hydrationGeneration: generation,
  timeline: SnapshotCollection(
    values: items,
    boundary: boundary(seq, generation: generation, authority: authority),
    complete: complete,
  ),
  hasMoreHistory: hasMore,
);

void main() {
  group('synthetic ordering and identity cases', () {
    test('same native IDs on another host do not enter this session', () {
      const foreign = SessionRef(
        HostId('other'),
        HarnessInstanceId('instance'),
        'session',
      );
      final event = ItemUpserted(
        meta: EventMeta(
          owner: const SessionOwner(foreign),
          position: pos(1),
          receivedAt: now,
          source: SourceProvenance(
            harness: foreign.harnessRef,
            version: 'test',
            nativeType: 'text',
          ),
        ),
        item: text('same-native-id', 'foreign'),
      );
      final state = initial();
      final result = reduce(state, event);
      expect(result.state, same(state));
      expect(result.effects.single, isA<Rehydrate>());
    });
    test(
      'native fanout is retained while identical projections are deduplicated',
      () {
        final input = ItemUpserted(
          meta: meta(1, nativeId: 'same'),
          item: user('input'),
        );
        final pending = PendingInputChanged(
          meta: meta(2, nativeId: 'same'),
          items: [
            const PendingInput(
              id: ItemId('input'),
              text: 'input',
              delivery: OpenValue.known(Delivery.steer),
            ),
          ],
        );
        var state = reduce(initial(), input).state;
        state = reduce(state, pending).state;
        expect(state.timeline, hasLength(1));
        expect(state.pending, hasLength(1));
        expect(reduce(state, input).effects, isEmpty);
        expect(reduce(state, pending).effects, isEmpty);
      },
    );
    test('missing delta target requests recovery without creating text', () {
      final result = reduce(initial(), delta('missing', 'untrusted', 1));
      expect(result.state.timeline, isEmpty);
      expect(result.effects.single, isA<Refetch>());
    });
    test(
      'current delta appends once then ended replaces provisional content',
      () {
        var state = upsert(initial(), text('text', 'prefix'), 1);
        final fragment = delta('text', '-fragment', 2, nativeId: 'delta');
        state = reduce(state, fragment).state;
        expect(
          (state.item(const ItemId('text')) as AssistantText).text,
          'prefix-fragment',
        );
        final duplicate = reduce(state, fragment);
        expect(duplicate.state, same(state));
        state = upsert(state, text('text', 'authoritative', complete: true), 3);
        state = reduce(state, delta('text', '-late', 4)).state;
        expect(
          (state.item(const ItemId('text')) as AssistantText).text,
          'authoritative',
        );
      },
    );
    test(
      'ended arriving before start cannot be reopened by reordered fragments',
      () {
        var state = upsert(initial(), text('text', 'final', complete: true), 5);
        state = upsert(state, text('text', ''), 1);
        state = reduce(state, delta('text', 'late', 3)).state;
        expect((state.timeline.single as AssistantText).text, 'final');
        expect((state.timeline.single as AssistantText).complete, isTrue);
      },
    );
    test(
      'out of order distinct deltas request hydration; completion repairs them',
      () {
        var state = upsert(initial(), text('text', ''), 1);
        state = reduce(state, delta('text', 'second', 3)).state;
        final late = reduce(state, delta('text', 'first', 2));
        expect(late.effects.single, isA<Refetch>());
        state = upsert(
          late.state,
          text('text', 'firstsecond', complete: true),
          4,
        );
        expect((state.timeline.single as AssistantText).text, 'firstsecond');
      },
    );
    test(
      'retry opens a fresh generation; retired-generation updates cannot replace it',
      () {
        var state = upsert(initial(), text('text', 'first', complete: true), 1);
        state = upsert(state, text('text', '', generation: 'retry'), 2);
        state = reduce(
          state,
          delta('text', 'new', 3, generation: 'retry'),
        ).state;
        state = reduce(state, delta('text', 'old', 4)).state;
        final old = reduce(
          state,
          ItemUpserted(
            meta: meta(5),
            item: text('text', 'old-generation', complete: true),
          ),
        );
        expect(old.effects.single, isA<Refetch>());
        expect((old.state.timeline.single as AssistantText).text, 'new');
        expect(old.state.timeline.single.generation, 'retry');
        expect(old.state.retainedGenerationCount, 1);
      },
    );
    test(
      'a retry can follow authoritative hydrated completion under the same stable ID',
      () {
        var state = hydrate(
          hydrating(initial()),
          history([text('text', 'done', complete: true)], 0),
        ).state;
        state = upsert(state, text('text', '', generation: 'retry'), 1);
        state = reduce(
          state,
          delta('text', 'restarted', 2, generation: 'retry'),
        ).state;
        expect((state.timeline.single as AssistantText).text, 'restarted');
      },
    );
    test(
      'unknown fields remain passive and unknown events are bounded diagnostics',
      () {
        var state = upsert(
          initial(limits: const ReducerLimits(maxDiagnostics: 2)),
          text('text', ''),
          1,
        );
        final unsupported = reduce(
          state,
          delta('text', 'unknown', 2, field: OpenValue.unknown('future')),
        );
        expect(
          (unsupported.state.timeline.single as AssistantText).text,
          isEmpty,
        );
        expect(unsupported.effects.single, isA<Refetch>());
        state = unsupported.state;
        for (var seq = 3; seq <= 5; seq++) {
          state = reduce(
            state,
            UnknownEvent(
              meta: meta(seq),
              rawType: 'future',
              raw: CanonicalValue({
                'nested': ['kept'],
              }),
            ),
          ).state;
        }
        expect(state.diagnostics, hasLength(2));
        expect(state.timeline, hasLength(1));
        expect(() => state.diagnostics.clear(), throwsUnsupportedError);
      },
    );
    test(
      'an unsolicited stream epoch does not replace the caller-adopted generation',
      () {
        final state = initial();
        final result = reduce(
          state,
          ItemUpserted(
            meta: meta(1, epoch: 'foreign'),
            item: text('text', 'foreign'),
          ),
        );
        expect(result.state, same(state));
        expect(result.effects.single, isA<Rehydrate>());
      },
    );
  });

  group('synthetic non-atomic hydration cases', () {
    test(
      'independent read barriers protect newer execution but accept older pending state',
      () {
        var state = hydrating(initial());
        state = reduce(
          state,
          ExecutionChanged(
            meta: meta(5),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
              lastOutcome: ExecutionOutcome(
                OpenValue.known(ExecutionOutcomeKind.succeeded),
              ),
            ),
          ),
        ).state;
        final snapshot = SessionSnapshot(
          ref: ref,
          hydrationGeneration: 'hydration',
          execution: SnapshotValue(
            value: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.running),
            ),
            boundary: boundary(2),
          ),
          pending: SnapshotCollection(
            values: [
              const PendingInput(
                id: ItemId('queue'),
                text: 'next',
                delivery: OpenValue.known(Delivery.queue),
              ),
            ],
            boundary: boundary(6),
          ),
        );
        final result = hydrate(state, snapshot);
        expect(result.state.execution!.kind.known, ExecutionKind.idle);
        expect(
          result.state.execution!.lastOutcome!.kind.known,
          ExecutionOutcomeKind.succeeded,
        );
        expect(result.state.pending.single.id, const ItemId('queue'));
      },
    );
    test(
      'reverse snapshot completion does not restore an older collection',
      () {
        var state = hydrating(initial());
        SessionSnapshot pendingAt(int start, String id) => SessionSnapshot(
          ref: ref,
          hydrationGeneration: 'hydration',
          pending: SnapshotCollection(
            values: [
              PendingInput(
                id: ItemId(id),
                text: id,
                delivery: const OpenValue.known(Delivery.queue),
              ),
            ],
            boundary: boundary(start),
          ),
        );
        state = hydrate(state, pendingAt(10, 'new')).state;
        state = hydrate(state, pendingAt(5, 'old')).state;
        expect(state.pending.single.id, const ItemId('new'));
      },
    );
    test(
      'two reads that missed live promotion cannot erase an observed admission',
      () {
        var state = hydrating(initial());
        state = upsert(state, user('input'), 1);
        state = reduce(
          state,
          PendingInputChanged(
            meta: meta(2),
            items: [
              const PendingInput(
                id: ItemId('input'),
                text: 'input',
                delivery: OpenValue.known(Delivery.steer),
              ),
            ],
          ),
        ).state;
        state = reduce(
          state,
          PendingInputChanged(meta: meta(3), items: const []),
        ).state;
        final result = hydrate(
          state,
          SessionSnapshot(
            ref: ref,
            hydrationGeneration: 'hydration',
            timeline: SnapshotCollection(
              values: const [],
              boundary: boundary(4),
            ),
            pending: SnapshotCollection(
              values: const [],
              boundary: boundary(4),
            ),
          ),
        );
        expect(result.state.timeline.single.id, const ItemId('input'));
        expect(result.state.pending, isEmpty);
        expect(
          result.effects.whereType<Refetch>().single.reason,
          'admissionMissingFromHistory',
        );
      },
    );
    test(
      'history delivery is positive evidence for a derived empty pending read',
      () {
        var state = hydrating(initial());
        state = upsert(state, user('input'), 1);
        state = reduce(
          state,
          PendingInputChanged(
            meta: meta(2),
            items: [
              const PendingInput(
                id: ItemId('input'),
                text: 'input',
                delivery: OpenValue.known(Delivery.steer),
              ),
            ],
          ),
        ).state;
        state = hydrate(
          state,
          SessionSnapshot(
            ref: ref,
            hydrationGeneration: 'hydration',
            timeline: SnapshotCollection(
              values: [user('input', delivery: DeliveryState.delivered)],
              boundary: boundary(3),
            ),
            pending: SnapshotCollection(
              values: const [],
              boundary: boundary(3, authority: SnapshotAuthority.derived),
            ),
          ),
        ).state;
        expect(state.pending, isEmpty);
        expect(
          (state.timeline.single as UserInput).delivery.known,
          DeliveryState.delivered,
        );
      },
    );
    test('derived empty pending alone cannot erase an admitted queue item', () {
      var state = hydrating(initial());
      state = reduce(
        state,
        PendingInputChanged(
          meta: meta(1),
          items: [
            const PendingInput(
              id: ItemId('input'),
              text: 'input',
              delivery: OpenValue.known(Delivery.queue),
            ),
          ],
        ),
      ).state;
      state = hydrate(
        state,
        SessionSnapshot(
          ref: ref,
          hydrationGeneration: 'hydration',
          pending: SnapshotCollection(
            values: const [],
            boundary: boundary(2, authority: SnapshotAuthority.derived),
          ),
        ),
      ).state;
      expect(state.pending, hasLength(1));
    });
    test(
      'newer live item replaces a stale snapshot base without duplicating its delta',
      () {
        var state = hydrating(
          upsert(initial(), text('text', 'base'), 1),
          seq: 1,
        );
        state = reduce(state, delta('text', '+new', 3)).state;
        state = hydrate(state, history([text('text', 'base')], 1)).state;
        expect((state.timeline.single as AssistantText).text, 'base+new');
      },
    );
    test('newer removal fences the whole stale history page', () {
      var state = upsert(initial(), text('one', 'one'), 1);
      state = upsert(state, text('two', 'two'), 2);
      state = hydrating(state, seq: 2);
      state = reduce(
        state,
        ItemsRemoved(meta: meta(3), fromItemId: const ItemId('two')),
      ).state;
      final result = hydrate(
        state,
        history([
          text('one', 'one'),
          text('two', 'two'),
          text('unseen', 'unseen'),
        ], 2),
      );
      expect(result.state.timeline.map((item) => item.id.value), ['one']);
      expect(
        result.effects.whereType<Refetch>().single.reason,
        'historyReadBeforeRemoval',
      );
    });
    test(
      'unknown removal boundary refetches instead of comparing opaque IDs',
      () {
        final state = upsert(initial(), text('opaque', 'kept'), 1);
        final result = reduce(
          state,
          ItemsRemoved(meta: meta(2), fromItemId: const ItemId('aaa')),
        );
        expect(result.state.timeline.single.id, const ItemId('opaque'));
        expect(result.effects.single, isA<Refetch>());
      },
    );
    test(
      'unknown snapshot authority does not erase state or declare live hydration',
      () {
        final state = hydrating(upsert(initial(), text('text', 'kept'), 1));
        final result = hydrate(
          state,
          history(const [], 2, authority: SnapshotAuthority.unknown),
        );
        expect(result.state.timeline.single.id, const ItemId('text'));
        expect(result.state.connection.kind.known, ConnectionKind.hydrating);
        expect(result.effects.single, isA<Refetch>());
      },
    );
    test('late hydration generation and foreign session cannot commit', () {
      final state = hydrating(initial(), generation: 'current');
      final result = hydrate(state, history([text('text', 'late')], 0));
      expect(result.state, same(state));
      expect(result.effects.single, isA<Rehydrate>());
      const foreign = SessionRef(
        HostId('other'),
        HarnessInstanceId('instance'),
        'session',
      );
      expect(
        hydrate(
          state,
          SessionSnapshot(ref: foreign, hydrationGeneration: 'current'),
        ).state,
        same(state),
      );
    });
    test('disconnect leaves execution, pending and interactions unsettled', () {
      var state = reduce(
        initial(),
        ExecutionChanged(
          meta: meta(1),
          state: const ExecutionState(
            kind: OpenValue.known(ExecutionKind.running),
          ),
        ),
      ).state;
      state = upsert(state, text('text', 'partial'), 2);
      final next = disconnect(state);
      expect(next.execution, same(state.execution));
      expect(next.execution!.lastOutcome, isNull);
      expect(next.connection.kind.known, ConnectionKind.reconnecting);
      expect((next.timeline.single as AssistantText).prefixMissing, isTrue);
      expect((state.timeline.single as AssistantText).prefixMissing, isFalse);
    });
  });

  group('synthetic scoped interaction and work cases', () {
    InteractionRequest request({
      DomainOwner owner = const SessionOwner(child, origin: ref),
    }) => InteractionRequest(
      id: const InteractionId('same'),
      owner: owner,
      kind: const OpenValue.known(InteractionKind.permission),
      title: 'permission',
    );
    test(
      'child interaction displayed in parent keeps its actual owning identity',
      () {
        var state = reduce(
          initial(),
          InteractionOpened(meta: meta(1), request: request()),
        ).state;
        state = reduce(
          state,
          InteractionResolved(
            meta: meta(2),
            resolution: const InteractionResolution(
              id: InteractionId('same'),
              owner: SessionOwner(ref),
              kind: OpenValue.known(InteractionResolutionKind.elsewhere),
            ),
          ),
        ).state;
        expect(state.interactions, hasLength(1));
        expect(
          (state.interactions.single.owner as SessionOwner).session,
          child,
        );
      },
    );
    test(
      'resolved request cannot be resurrected by an older event or read',
      () {
        var state = hydrating(initial());
        state = reduce(
          state,
          InteractionOpened(meta: meta(1), request: request()),
        ).state;
        state = reduce(
          state,
          InteractionResolved(
            meta: meta(3),
            resolution: const InteractionResolution(
              id: InteractionId('same'),
              owner: SessionOwner(child, origin: ref),
              kind: OpenValue.known(InteractionResolutionKind.elsewhere),
            ),
          ),
        ).state;
        state = reduce(
          state,
          InteractionOpened(meta: meta(2), request: request()),
        ).state;
        state = hydrate(
          state,
          SessionSnapshot(
            ref: ref,
            hydrationGeneration: 'hydration',
            interactions: SnapshotCollection(
              values: [request()],
              boundary: boundary(1),
            ),
          ),
        ).state;
        expect(state.interactions, isEmpty);
      },
    );
    test(
      'parent completion notice never completes a child or changes parent execution',
      () {
        var state = reduce(
          initial(),
          ExecutionChanged(
            meta: meta(1),
            state: const ExecutionState(
              kind: OpenValue.known(ExecutionKind.idle),
            ),
          ),
        ).state;
        state = reduce(
          state,
          WorkChanged(
            meta: meta(2),
            items: const [
              WorkItem(
                id: WorkId('work'),
                owner: SessionOwner(ref),
                parent: ref,
                child: child,
                status: OpenValue.known(WorkStatus.completed),
                completionScope: OpenValue.known(CompletionScope.notice),
              ),
            ],
          ),
        ).state;
        expect(state.execution!.kind.known, ExecutionKind.idle);
        expect(state.execution!.lastOutcome, isNull);
        expect(state.work.single.child, child);
        state = reduce(
          state,
          WorkChanged(meta: meta(3), items: const []),
        ).state;
        expect(state.work, isEmpty);
      },
    );
  });

  group('synthetic bounds, usage and LRU cases', () {
    test(
      '2000 flattened history items retain newest500 and bounded position references',
      () {
        final items = [
          for (var n = 0; n < 2000; n++) text('item$n', '$n', complete: true),
        ];
        final result = hydrate(hydrating(initial()), history(items, 0));
        final state = result.state;
        expect(state.timeline, hasLength(500));
        expect(state.timeline.first.id, const ItemId('item1500'));
        expect(state.timeline.last.id, const ItemId('item1999'));
        expect(state.hasMoreHistory, isTrue);
        expect(state.retainedItemPositionCount, 500);
        expect(
          reduce(state, delta('item0', 'late', 1)).state.timeline,
          hasLength(500),
        );
      },
    );
    test(
      'partial older page prepends and obeys the resident cap after flattening',
      () {
        var state = hydrating(
          initial(limits: const ReducerLimits(maxItems: 3)),
        );
        state = hydrate(
          state,
          history([text('two', '2'), text('three', '3')], 0),
        ).state;
        state = hydrate(
          state,
          history(
            [text('zero', '0'), text('one', '1')],
            1,
            complete: false,
            hasMore: true,
          ),
        ).state;
        expect(state.timeline.map((item) => item.id.value), [
          'one',
          'two',
          'three',
        ]);
        expect(state.hasMoreHistory, isTrue);
        expect(state.retainedItemPositionCount, 3);
      },
    );
    test(
      'bounded dedup, item positions and generations never mutate earlier snapshots',
      () {
        var state = initial(
          limits: const ReducerLimits(maxItems: 2, maxSeen: 3),
        );
        final empty = state;
        for (var n = 1; n <= 8; n++) {
          state = upsert(state, text('item$n', '$n'), n);
        }
        expect(state.timeline.map((item) => item.id.value), ['item7', 'item8']);
        expect(state.retainedItemPositionCount, 2);
        expect(state.retainedObservationCount, 3);
        expect(empty.timeline, isEmpty);
        expect(() => state.timeline.clear(), throwsUnsupportedError);
        expect(
          () => reduce(state, delta('item8', 'x', 9)).effects.clear(),
          throwsUnsupportedError,
        );
      },
    );
    test(
      'cumulative usage replaces a matching series and never adds absent components',
      () {
        UsageObservation usage(String id, num input, {bool partial = false}) =>
            UsageObservation(
              id: id,
              owner: const SessionOwner(ref),
              scope: const OpenValue.known(UsageScope.session),
              source: const OpenValue.known(UsageSource.native),
              observedAt: now,
              tokens: TokenBreakdown(input: input),
              aggregationKey: 'session-series',
              cumulative: true,
              partial: partial,
            );
        var state = reduce(
          initial(),
          UsageObserved(meta: meta(1), observation: usage('first', 10)),
        ).state;
        state = reduce(
          state,
          UsageObserved(meta: meta(2), observation: usage('next', 12)),
        ).state;
        expect(state.usage, hasLength(1));
        expect(state.usage.single.tokens!.input, 12);
        expect(state.usage.single.tokens!.output, isNull);
        state = reduce(
          state,
          UsageObserved(
            meta: meta(3),
            observation: usage('partial', 1, partial: true),
          ),
        ).state;
        expect(state.usage, hasLength(2));
      },
    );
    test(
      'newer cumulative reading cannot be overwritten by older snapshot with another ID',
      () {
        UsageObservation usage(String id, num input) => UsageObservation(
          id: id,
          owner: const SessionOwner(ref),
          scope: const OpenValue.known(UsageScope.session),
          source: const OpenValue.known(UsageSource.native),
          observedAt: now,
          tokens: TokenBreakdown(input: input),
          aggregationKey: 'series',
          cumulative: true,
        );
        var state = hydrating(initial());
        state = reduce(
          state,
          UsageObserved(meta: meta(5), observation: usage('live', 15)),
        ).state;
        state = hydrate(
          state,
          SessionSnapshot(
            ref: ref,
            hydrationGeneration: 'hydration',
            usage: SnapshotCollection(
              values: [usage('old', 10)],
              boundary: boundary(1),
            ),
          ),
        ).state;
        expect(state.usage, hasLength(1));
        expect(state.usage.single.tokens!.input, 15);
      },
    );
    test(
      'full SessionRef isolates LRU entries and eviction does not auto-reopen on late events',
      () {
        final store = SessionStore(maxSessions: 2);
        const otherHost = SessionRef(
          HostId('other'),
          HarnessInstanceId('instance'),
          'session',
        );
        const otherInstance = SessionRef(
          HostId('host'),
          HarnessInstanceId('other'),
          'session',
        );
        store.open(ref);
        store.open(otherHost);
        store.read(ref);
        store.open(otherInstance);
        expect(store.refs, [ref, otherInstance]);
        expect(store.peek(otherHost), isNull);
        final result = store.apply(
          otherHost,
          ItemUpserted(meta: meta(1), item: text('late', 'late')),
        );
        expect(result.effects.single, isA<Rehydrate>());
        expect(store.refs, [ref, otherInstance]);
        expect(store.open(otherHost).timeline, isEmpty);
        expect(store.refs, [otherInstance, otherHost]);
        store.clear();
        expect(store.length, 0);
      },
    );
    test('invalid finite bounds fail before constructing stores', () {
      expect(() => SessionStore(maxSessions: 0), throwsArgumentError);
      expect(
        () => initial(limits: const ReducerLimits(maxItems: 501)),
        throwsArgumentError,
      );
      expect(
        () => initial(limits: const ReducerLimits(maxSeen: 0)),
        throwsArgumentError,
      );
    });
  });
}
