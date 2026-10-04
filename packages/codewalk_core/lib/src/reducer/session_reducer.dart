import 'dart:convert';

import '../events.dart';
import '../identity.dart';
import '../interactions.dart';
import '../lifecycle.dart';
import '../session.dart';
import '../timeline.dart';
import '../usage.dart';
import '../values.dart';
import '../work.dart';
import 'effects.dart';

/// Memory limits are per resident session. No total-history size is inferred.
final class ReducerLimits {
  const ReducerLimits({
    this.maxItems = 500,
    this.maxSeen = 1024,
    this.maxDiagnostics = 32,
    this.maxObservations = 500,
  });

  final int maxItems;
  final int maxSeen;
  final int maxDiagnostics;
  final int maxObservations;

  void _validate() {
    if (maxItems <= 0 ||
        maxItems > 500 ||
        maxSeen <= 0 ||
        maxDiagnostics <= 0 ||
        maxObservations <= 0) {
      throw ArgumentError(
        'Reducer limits must be positive; resident cap is 500',
      );
    }
  }
}

/// Each collection is immutable. Positions are local observation clocks, never
/// native durable replay cursors. No reducer field holds a mutable wire DTO.
final class SessionState {
  factory SessionState(
    SessionRef ref, {
    ReducerLimits limits = const ReducerLimits(),
    String hydrationGeneration = 'initial',
    StreamPosition? streamPosition,
  }) {
    limits._validate();
    requireText(hydrationGeneration, 'hydrationGeneration');
    return _Draft.initial(
      ref,
      limits,
      hydrationGeneration,
      streamPosition,
    ).freeze();
  }

  SessionState._(_Draft draft)
    : ref = draft.ref,
      limits = draft.limits,
      hydrationGeneration = draft.hydrationGeneration,
      lastPosition = draft.lastPosition,
      connection = draft.connection,
      execution = draft.execution,
      info = draft.info,
      plan = draft.plan,
      selection = draft.selection,
      revert = draft.revert,
      timeline = immutableList(draft.timeline),
      pending = immutableList(draft.pending),
      interactions = immutableList(draft.interactions.values),
      work = immutableList(draft.work),
      usage = immutableList(draft.usage),
      diagnostics = immutableList(draft.diagnostics),
      nextHistoryCursor = draft.nextHistoryCursor,
      hasMoreHistory = draft.hasMoreHistory,
      _itemPositions = immutableMap(draft.itemPositions),
      _itemOrder = immutableMap(draft.itemOrder),
      _fields = immutableMap(draft.fields),
      _snapshotStarts = immutableMap(draft.snapshotStarts),
      _readBarriers = immutableMap(draft.readBarriers),
      _interactionPositions = immutableMap(draft.interactionPositions),
      _interactionRemovals = immutableMap(draft.interactionRemovals),
      _usagePositions = immutableMap(draft.usagePositions),
      _admissions = Set<ItemId>.unmodifiable(draft.admissions),
      _retiredGenerations = immutableList(draft.retiredGenerations),
      _seen = immutableList(draft.seen);

  final SessionRef ref;
  final ReducerLimits limits;
  final String hydrationGeneration;
  final StreamPosition? lastPosition;
  final ConnectionState connection;
  final ExecutionState? execution;
  final SessionInfo? info;
  final PlanSnapshot? plan;
  final Selection? selection;
  final RevertState? revert;
  final List<TimelineItem> timeline;
  final List<PendingInput> pending;
  final List<InteractionRequest> interactions;
  final List<WorkItem> work;
  final List<UsageObservation> usage;

  /// Bounded unsupported observations, separate from assistant timeline text.
  final List<UnknownEvent> diagnostics;
  final HistoryCursor? nextHistoryCursor;

  /// Includes known local incompleteness when the resident window discards
  /// history. It does not invent a native cursor or total-history size.
  final bool hasMoreHistory;
  final Map<ItemId, StreamPosition> _itemPositions;
  final Map<ItemId, StreamPosition> _itemOrder;
  final Map<SessionCollection, StreamPosition> _fields;
  final Map<SessionCollection, StreamPosition> _snapshotStarts;
  final Map<SessionCollection, StreamPosition> _readBarriers;
  final Map<String, StreamPosition> _interactionPositions;
  final Map<String, StreamPosition> _interactionRemovals;
  final Map<String, StreamPosition> _usagePositions;
  final Set<ItemId> _admissions;
  final List<(ItemId, String)> _retiredGenerations;
  final List<String> _seen;

  /// Bounded bookkeeping counts for diagnostics and deterministic limit tests.
  int get retainedItemPositionCount => _itemPositions.length;
  int get retainedObservationCount => _seen.length;
  int get retainedGenerationCount => _retiredGenerations.length;
  int get retainedInteractionPositionCount =>
      _interactionPositions.length + _interactionRemovals.length;
  int get retainedUsagePositionCount => _usagePositions.length;

  TimelineItem? item(ItemId id) {
    for (final item in timeline) {
      if (item.id == id) return item;
    }
    return null;
  }
}

final class Reduction {
  Reduction(this.state, Iterable<ReducerEffect> effects)
    : effects = immutableList(effects);
  final SessionState state;
  final List<ReducerEffect> effects;
}

/// Start a client hydration cycle explicitly. A different epoch is never
/// adopted merely because an untrusted/stale event arrives with that epoch.
SessionState beginHydration(
  SessionState state, {
  required String generation,
  required StreamPosition readStart,
}) {
  requireText(generation, 'generation');
  final draft = _Draft(state);
  draft.hydrationGeneration = generation;
  draft.snapshotStarts.clear();
  if (!_sameStream(draft.lastPosition, readStart)) {
    draft.seen.clear();
    draft.lastPosition = readStart;
  } else if (draft.lastPosition!.seq < readStart.seq) {
    draft.lastPosition = readStart;
  }
  draft.connection = const ConnectionState(
    kind: OpenValue.known(ConnectionKind.hydrating),
  );
  return draft.freeze();
}

/// Lost connection changes confidence and exposes a missing stream prefix; it
/// never completes work, settles interactions, cancels input or replays sends.
SessionState disconnect(SessionState state) {
  final draft = _Draft(state);
  draft.connection = const ConnectionState(
    kind: OpenValue.known(ConnectionKind.reconnecting),
  );
  draft.timeline = [for (final item in draft.timeline) _markGap(item)];
  return draft.freeze();
}

Reduction reduce(SessionState state, SessionEvent event) {
  final draft = _Draft(state);
  final owner = event.meta.owner;
  if (owner is! SessionOwner || owner.session != state.ref) {
    return Reduction(state, [Rehydrate(state.ref, 'eventScopeMismatch')]);
  }
  final position = event.meta.position;
  if (draft.lastPosition != null &&
      !_sameStream(draft.lastPosition, position)) {
    return Reduction(state, [Rehydrate(state.ref, 'streamGenerationMismatch')]);
  }
  final observation = _observationKey(event);
  if (draft.seen.contains(observation)) return Reduction(state, const []);
  draft.seen.add(observation);
  if (draft.seen.length > state.limits.maxSeen) draft.seen.removeAt(0);
  if (draft.lastPosition == null || position.seq > draft.lastPosition!.seq) {
    draft.lastPosition = position;
  }
  switch (event) {
    case ItemUpserted(:final item):
      if (item.source.harness != state.ref.harnessRef) {
        draft.refetch(SessionCollection.timeline, 'itemSourceMismatch');
      } else {
        draft.upsert(item, position);
      }
    case ItemDelta():
      draft.delta(event);
    case ItemsRemoved(:final fromItemId):
      draft.removeFrom(fromItemId, position);
    case ExecutionChanged(:final state):
      if (draft.acceptField(SessionCollection.execution, position)) {
        draft.execution = state;
        draft.changed = true;
      }
    case RetryScheduled(:final at, :final error):
      if (draft.acceptField(SessionCollection.execution, position)) {
        draft.execution = ExecutionState(
          kind: const OpenValue.known(ExecutionKind.retrying),
          retryAt: at,
          error: error,
          lastOutcome: draft.execution?.lastOutcome,
        );
        draft.changed = true;
      }
    case PendingInputChanged(:final items):
      if (draft.acceptField(SessionCollection.pending, position)) {
        draft.pending = draft.bound(items, SessionCollection.pending);
        draft.changed = true;
      }
    case InteractionOpened(:final request):
      if (!draft.relatedOwner(request.owner)) {
        draft.refetch(
          SessionCollection.interactions,
          'interactionScopeMismatch',
        );
      } else if (!draft.beforeReadBarrier(
            SessionCollection.interactions,
            position,
          ) &&
          !_atLeast(
            draft.interactionPositions[request.identityKey],
            position,
          ) &&
          !_atLeast(draft.interactionRemovals[request.identityKey], position)) {
        draft.interactions[request.identityKey] = request;
        draft.interactionPositions[request.identityKey] = position;
        draft.limitInteractions();
        draft.changed = true;
      }
    case InteractionResolved(:final resolution):
      if (!draft.relatedOwner(resolution.owner)) {
        draft.refetch(
          SessionCollection.interactions,
          'interactionScopeMismatch',
        );
      } else if (!draft.beforeReadBarrier(
            SessionCollection.interactions,
            position,
          ) &&
          !_atLeast(
            draft.interactionRemovals[resolution.identityKey],
            position,
          ) &&
          !_atLeast(
            draft.interactionPositions[resolution.identityKey],
            position,
          )) {
        draft.interactions.remove(resolution.identityKey);
        draft.interactionPositions.remove(resolution.identityKey);
        draft.interactionRemovals[resolution.identityKey] = position;
        draft.limitRemovals();
        draft.changed = true;
      }
    case WorkChanged(:final items):
      if (items.any((item) => !draft.relatedWork(item))) {
        draft.refetch(SessionCollection.work, 'workScopeMismatch');
      } else if (draft.acceptField(SessionCollection.work, position)) {
        draft.work = draft.bound(items, SessionCollection.work);
        draft.changed = true;
      }
    case PlanChanged(:final plan):
      if (!draft.relatedOwner(plan.owner)) {
        draft.refetch(SessionCollection.plan, 'planScopeMismatch');
      } else if (draft.acceptField(SessionCollection.plan, position)) {
        draft.plan = plan;
        draft.changed = true;
      }
    case UsageObserved(:final observation):
      draft.observeUsage(observation, position);
    case SelectionChanged(:final selection):
      if (draft.acceptField(SessionCollection.selection, position)) {
        draft.selection = selection;
        draft.changed = true;
      }
    case RevertChanged(:final state):
      if (draft.acceptField(SessionCollection.revert, position)) {
        draft.revert = state;
        draft.changed = true;
      }
    case SessionInfoChanged(:final info):
      if (info.ref != draft.ref) {
        draft.refetch(SessionCollection.info, 'infoScopeMismatch');
      } else if (draft.acceptField(SessionCollection.info, position)) {
        draft.info = info;
        draft.changed = true;
      }
    case ResyncRequired(:final reason):
      draft.effects.add(Rehydrate(state.ref, reason));
    case UnknownEvent():
      draft.diagnostics.add(event);
      if (draft.diagnostics.length > state.limits.maxDiagnostics) {
        draft.diagnostics.removeAt(0);
      }
      draft.changed = true;
  }
  return draft.result();
}

Reduction hydrate(SessionState state, SessionSnapshot snapshot) {
  if (snapshot.ref != state.ref ||
      snapshot.hydrationGeneration != state.hydrationGeneration) {
    return Reduction(state, [
      Rehydrate(state.ref, 'snapshotGenerationMismatch'),
    ]);
  }
  final draft = _Draft(state);
  final info = snapshot.info;
  if (info != null &&
      draft.acceptSnapshot(SessionCollection.info, info.boundary)) {
    draft.recordReadBarrier(SessionCollection.info, info.boundary);
    draft.info = info.value;
    draft.changed = true;
  }
  final execution = snapshot.execution;
  if (execution != null &&
      draft.acceptSnapshot(SessionCollection.execution, execution.boundary)) {
    draft.recordReadBarrier(SessionCollection.execution, execution.boundary);
    draft.execution = execution.value;
    draft.changed = true;
  }
  final timeline = snapshot.timeline;
  if (timeline != null && draft.hydrateTimeline(timeline)) {
    draft.nextHistoryCursor = snapshot.nextHistoryCursor;
    draft.hasMoreHistory =
        snapshot.hasMoreHistory ||
        draft.timelineTruncated ||
        (!draft.canReplace(timeline.boundary, timeline.complete) &&
            state.hasMoreHistory);
  }
  final pending = snapshot.pending;
  if (pending != null &&
      draft.acceptSnapshot(SessionCollection.pending, pending.boundary)) {
    if (draft.canReplace(pending.boundary, pending.complete)) {
      draft.recordReadBarrier(SessionCollection.pending, pending.boundary);
      draft.pending = draft.bound(pending.values, SessionCollection.pending);
    } else {
      final merged = {for (final input in draft.pending) input.id: input};
      for (final input in pending.values) {
        merged[input.id] = input;
      }
      draft.pending = draft.bound(merged.values, SessionCollection.pending);
    }
    draft.changed = true;
  }
  // Authoritative projected user history is positive proof of promotion even
  // when A's separate empty pending observation was only derived.
  final delivered = draft.timeline
      .whereType<UserInput>()
      .where(
        (item) =>
            item.delivery.known == DeliveryState.delivered ||
            item.delivery.known == DeliveryState.cancelled ||
            item.delivery.known == DeliveryState.rejected,
      )
      .map((item) => item.id)
      .toSet();
  if (draft.pending.any((item) => delivered.contains(item.id))) {
    draft.pending.removeWhere((item) => delivered.contains(item.id));
    draft.changed = true;
  }
  final interactions = snapshot.interactions;
  if (interactions != null) draft.hydrateInteractions(interactions);
  final work = snapshot.work;
  if (work != null &&
      draft.acceptSnapshot(SessionCollection.work, work.boundary)) {
    if (work.values.any((item) => !draft.relatedWork(item))) {
      draft.refetch(SessionCollection.work, 'workScopeMismatch');
    } else if (draft.canReplace(work.boundary, work.complete)) {
      draft.recordReadBarrier(SessionCollection.work, work.boundary);
      draft.work = draft.bound(work.values, SessionCollection.work);
      draft.changed = true;
    }
  }
  final plan = snapshot.plan;
  if (plan != null &&
      draft.acceptSnapshot(SessionCollection.plan, plan.boundary)) {
    if (draft.relatedOwner(plan.value.owner)) {
      draft.recordReadBarrier(SessionCollection.plan, plan.boundary);
      draft.plan = plan.value;
      draft.changed = true;
    } else {
      draft.refetch(SessionCollection.plan, 'planScopeMismatch');
    }
  }
  final usage = snapshot.usage;
  if (usage != null) draft.hydrateUsage(usage);
  final selection = snapshot.selection;
  if (selection != null &&
      draft.acceptSnapshot(SessionCollection.selection, selection.boundary)) {
    draft.recordReadBarrier(SessionCollection.selection, selection.boundary);
    draft.selection = selection.value;
    draft.changed = true;
  }
  final revert = snapshot.revert;
  if (revert != null &&
      draft.acceptSnapshot(SessionCollection.revert, revert.boundary)) {
    draft.recordReadBarrier(SessionCollection.revert, revert.boundary);
    draft.revert = revert.value;
    draft.changed = true;
  }
  if (draft.acceptedSnapshots > 0 &&
      !draft.effects.any(
        (effect) =>
            effect is Rehydrate ||
            (effect is Refetch && effect.reason == 'snapshotAuthorityUnknown'),
      )) {
    draft.connection = const ConnectionState(
      kind: OpenValue.known(ConnectionKind.live),
    );
  }
  return draft.result();
}

final class _Draft {
  _Draft.initial(
    this.ref,
    this.limits,
    this.hydrationGeneration,
    this.lastPosition,
  );
  _Draft(SessionState state)
    : ref = state.ref,
      limits = state.limits,
      hydrationGeneration = state.hydrationGeneration,
      lastPosition = state.lastPosition,
      connection = state.connection,
      execution = state.execution,
      info = state.info,
      plan = state.plan,
      selection = state.selection,
      revert = state.revert,
      timeline = List.of(state.timeline),
      pending = List.of(state.pending),
      interactions = {
        for (final request in state.interactions) request.identityKey: request,
      },
      work = List.of(state.work),
      usage = List.of(state.usage),
      diagnostics = List.of(state.diagnostics),
      nextHistoryCursor = state.nextHistoryCursor,
      hasMoreHistory = state.hasMoreHistory,
      itemPositions = Map.of(state._itemPositions),
      itemOrder = Map.of(state._itemOrder),
      fields = Map.of(state._fields),
      snapshotStarts = Map.of(state._snapshotStarts),
      readBarriers = Map.of(state._readBarriers),
      interactionPositions = Map.of(state._interactionPositions),
      interactionRemovals = Map.of(state._interactionRemovals),
      usagePositions = Map.of(state._usagePositions),
      admissions = Set.of(state._admissions),
      retiredGenerations = List.of(state._retiredGenerations),
      seen = List.of(state._seen);

  final SessionRef ref;
  final ReducerLimits limits;
  String hydrationGeneration;
  StreamPosition? lastPosition;
  ConnectionState connection = const ConnectionState(
    kind: OpenValue.known(ConnectionKind.connecting),
  );
  ExecutionState? execution;
  SessionInfo? info;
  PlanSnapshot? plan;
  Selection? selection;
  RevertState? revert;
  List<TimelineItem> timeline = [];
  List<PendingInput> pending = [];
  Map<String, InteractionRequest> interactions = {};
  List<WorkItem> work = [];
  List<UsageObservation> usage = [];
  List<UnknownEvent> diagnostics = [];
  HistoryCursor? nextHistoryCursor;
  bool hasMoreHistory = false;
  Map<ItemId, StreamPosition> itemPositions = {};
  Map<ItemId, StreamPosition> itemOrder = {};
  Map<SessionCollection, StreamPosition> fields = {};
  Map<SessionCollection, StreamPosition> snapshotStarts = {};
  Map<SessionCollection, StreamPosition> readBarriers = {};
  Map<String, StreamPosition> interactionPositions = {};
  Map<String, StreamPosition> interactionRemovals = {};
  Map<String, StreamPosition> usagePositions = {};
  Set<ItemId> admissions = {};
  List<(ItemId, String)> retiredGenerations = [];
  List<String> seen = [];
  final effects = <ReducerEffect>[];
  bool changed = false;
  bool timelineTruncated = false;
  int acceptedSnapshots = 0;

  SessionState freeze() => SessionState._(this);
  Reduction result() {
    if (changed) effects.add(Notify(ref));
    return Reduction(freeze(), effects);
  }

  void refetch(SessionCollection collection, String reason) {
    if (!effects.whereType<Refetch>().any(
      (effect) => effect.collection == collection && effect.reason == reason,
    )) {
      effects.add(Refetch(ref, collection, reason));
    }
  }

  bool acceptField(SessionCollection field, StreamPosition position) {
    if (_atLeast(fields[field], position) ||
        beforeReadBarrier(field, position)) {
      return false;
    }
    fields[field] = position;
    return true;
  }

  bool beforeReadBarrier(SessionCollection field, StreamPosition position) =>
      _atLeast(readBarriers[field], position);

  void recordReadBarrier(SessionCollection field, SnapshotBoundary boundary) {
    if (boundary.authority.known == SnapshotAuthority.authoritative &&
        !_newer(readBarriers[field], boundary.readStart)) {
      readBarriers[field] = boundary.readStart;
    }
  }

  bool acceptSnapshot(
    SessionCollection field,
    SnapshotBoundary boundary, {
    bool overlay = false,
  }) {
    if (boundary.hydrationGeneration != hydrationGeneration ||
        boundary.owner is! SessionOwner ||
        (boundary.owner as SessionOwner).session != ref ||
        !_sameStream(lastPosition, boundary.readStart)) {
      effects.add(Rehydrate(ref, 'snapshotBoundaryMismatch'));
      return false;
    }
    if (boundary.authority.known == null ||
        boundary.authority.known == SnapshotAuthority.unknown) {
      refetch(field, 'snapshotAuthorityUnknown');
      return false;
    }
    if (_newer(snapshotStarts[field], boundary.readStart) ||
        _newer(readBarriers[field], boundary.readStart)) {
      return false;
    }
    snapshotStarts[field] = boundary.readStart;
    if (!overlay && _newer(fields[field], boundary.readStart)) return false;
    acceptedSnapshots++;
    return true;
  }

  bool canReplace(SnapshotBoundary boundary, bool complete) =>
      complete && boundary.authority.known == SnapshotAuthority.authoritative;

  List<T> bound<T>(Iterable<T> values, SessionCollection collection) {
    final result = values.toList();
    if (result.length > limits.maxObservations) {
      result.removeRange(0, result.length - limits.maxObservations);
      refetch(collection, 'residentCollectionLimit');
    }
    return result;
  }

  bool relatedOwner(DomainOwner owner) {
    if (!owner.isKnown) {
      return true; // neutral observation; no authority granted
    }
    if (owner.harness != ref.harnessRef) return false;
    return owner is! SessionOwner ||
        owner.session == ref ||
        owner.origin == ref;
  }

  bool relatedWork(WorkItem item) =>
      relatedOwner(item.owner) ||
      (item.owner.harness == ref.harnessRef &&
          item.parent == ref &&
          item.owner is SessionOwner &&
          (item.owner as SessionOwner).session == item.child);

  void upsert(TimelineItem item, StreamPosition position) {
    if (beforeReadBarrier(SessionCollection.timeline, position)) return;
    if (retiredGenerations.contains(_generationKey(item))) {
      refetch(SessionCollection.timeline, 'retiredItemGeneration');
      return;
    }
    final at = timeline.indexWhere((current) => current.id == item.id);
    if (at >= 0) {
      final old = timeline[at];
      final oldPosition = itemPositions[item.id];
      if (_atLeast(oldPosition, position)) {
        // A late start can clarify relative ordering without reopening content.
        if (_sameStream(itemOrder[item.id], position) &&
            position.seq < itemOrder[item.id]!.seq) {
          itemOrder[item.id] = position;
          orderLive();
        }
        return;
      }
      if (old.generation == item.generation &&
          _completed(old) &&
          !_completed(item)) {
        return;
      }
      if (old.runtimeType != item.runtimeType) {
        refetch(SessionCollection.timeline, 'itemKindMismatch');
        return;
      }
      if (old.generation != item.generation) retire(old);
      timeline[at] = item;
    } else {
      timeline.add(item);
      itemOrder[item.id] = position;
    }
    itemPositions[item.id] = position;
    if (item is UserInput) {
      if (item.delivery.known == DeliveryState.cancelled ||
          item.delivery.known == DeliveryState.rejected) {
        admissions.remove(item.id);
      } else {
        admissions.add(item.id);
      }
    }
    orderLive();
    limitTimeline();
    changed = true;
  }

  void orderLive() {
    // Positions order newly observed items only when both are comparable.
    // Authoritative history publication supplies its own explicit order.
    if (timeline.every(
      (item) => _sameStream(itemOrder[item.id], lastPosition),
    )) {
      timeline.sort(
        (a, b) => itemOrder[a.id]!.seq.compareTo(itemOrder[b.id]!.seq),
      );
    }
  }

  void limitTimeline() {
    if (timeline.length > limits.maxItems) {
      timeline.removeRange(0, timeline.length - limits.maxItems);
      hasMoreHistory = true;
      timelineTruncated = true;
    }
    final retained = timeline.map((item) => item.id).toSet();
    itemPositions.removeWhere((id, _) => !retained.contains(id));
    itemOrder.removeWhere((id, _) => !retained.contains(id));
    admissions.removeWhere((id) => !retained.contains(id));
    retiredGenerations.removeWhere((key) => !retained.contains(key.$1));
  }

  void retire(TimelineItem item) {
    final key = _generationKey(item);
    retiredGenerations.remove(key);
    retiredGenerations.add(key);
    if (retiredGenerations.length > limits.maxSeen) {
      retiredGenerations.removeAt(0);
    }
  }

  void delta(ItemDelta event) {
    if (beforeReadBarrier(SessionCollection.timeline, event.meta.position)) {
      return;
    }
    final at = timeline.indexWhere((item) => item.id == event.itemId);
    if (at < 0) {
      refetch(SessionCollection.timeline, 'deltaTargetMissing');
      return;
    }
    final item = timeline[at];
    if (item.generation != event.generation ||
        _completed(item) ||
        item.status.known != ItemStatus.streaming) {
      return;
    }
    if (_atLeast(itemPositions[item.id], event.meta.position)) {
      refetch(SessionCollection.timeline, 'deltaOrderUnknown');
      return;
    }
    final field = event.field.known;
    final replacement = switch (item) {
      AssistantText() when field == DeltaField.text => AssistantText(
        meta: item.meta,
        text: item.text + event.text,
        complete: false,
        prefixMissing: item.prefixMissing,
      ),
      Reasoning()
          when field == DeltaField.reasoning || field == DeltaField.text =>
        Reasoning(
          meta: item.meta,
          text: item.text + event.text,
          complete: false,
          prefixMissing: item.prefixMissing,
        ),
      ToolCall()
          when field == DeltaField.toolInput && item.input?.value is String =>
        ToolCall(
          meta: item.meta,
          kind: item.kind,
          rawName: item.rawName,
          input: CanonicalValue('${item.input!.value}${event.text}'),
          output: item.output,
          outputRef: item.outputRef,
          child: item.child,
          error: item.error,
        ),
      _ => null,
    };
    if (replacement == null) {
      refetch(SessionCollection.timeline, 'unsupportedDeltaField');
      return;
    }
    timeline[at] = replacement;
    itemPositions[item.id] = event.meta.position;
    changed = true;
  }

  void removeFrom(ItemId id, StreamPosition position) {
    if (!acceptField(SessionCollection.timeline, position)) return;
    final at = timeline.indexWhere((item) => item.id == id);
    if (at < 0) {
      refetch(SessionCollection.timeline, 'removalBoundaryMissing');
      return;
    }
    timeline.removeRange(at, timeline.length);
    limitTimeline();
    changed = true;
  }

  bool hydrateTimeline(SnapshotCollection<TimelineItem> collection) {
    if (!acceptSnapshot(
      SessionCollection.timeline,
      collection.boundary,
      overlay: true,
    )) {
      return false;
    }
    if (_newer(
      fields[SessionCollection.timeline],
      collection.boundary.readStart,
    )) {
      refetch(SessionCollection.timeline, 'historyReadBeforeRemoval');
      return false;
    }
    if (collection.values.any(
      (item) => item.source.harness != ref.harnessRef,
    )) {
      refetch(SessionCollection.timeline, 'itemSourceMismatch');
      return false;
    }
    if (canReplace(collection.boundary, collection.complete)) {
      recordReadBarrier(SessionCollection.timeline, collection.boundary);
    }
    final old = {for (final item in timeline) item.id: item};
    final fetched = <ItemId>{};
    final merged = <TimelineItem>[];
    for (final incoming in collection.values) {
      fetched.add(incoming.id);
      final current = old[incoming.id];
      final newer = _newer(
        itemPositions[incoming.id],
        collection.boundary.readStart,
      );
      if (current != null &&
          (newer ||
              retiredGenerations.contains(_generationKey(incoming)) ||
              (current.generation == incoming.generation &&
                  _completed(current) &&
                  !_completed(incoming)))) {
        merged.add(current);
      } else {
        if (current != null && current.generation != incoming.generation) {
          retire(current);
        }
        merged.add(incoming);
        itemPositions[incoming.id] = collection.boundary.readStart;
        itemOrder.remove(incoming.id);
      }
      // A positive history row settles protection against absent racing reads.
      if (incoming is UserInput &&
          incoming.delivery.known == DeliveryState.delivered) {
        admissions.remove(incoming.id);
      }
    }
    for (final current in timeline) {
      if (!fetched.contains(current.id) &&
          (!canReplace(collection.boundary, collection.complete) ||
              admissions.contains(current.id) ||
              _newer(
                itemPositions[current.id],
                collection.boundary.readStart,
              ))) {
        merged.add(current);
        if (admissions.contains(current.id)) {
          refetch(SessionCollection.timeline, 'admissionMissingFromHistory');
        }
      }
    }
    timeline = merged;
    limitTimeline();
    changed = true;
    return true;
  }

  void hydrateInteractions(SnapshotCollection<InteractionRequest> collection) {
    if (!acceptSnapshot(
      SessionCollection.interactions,
      collection.boundary,
      overlay: true,
    )) {
      return;
    }
    if (collection.values.any((request) => !relatedOwner(request.owner))) {
      refetch(SessionCollection.interactions, 'interactionScopeMismatch');
      return;
    }
    if (canReplace(collection.boundary, collection.complete)) {
      recordReadBarrier(SessionCollection.interactions, collection.boundary);
    }
    final merged = canReplace(collection.boundary, collection.complete)
        ? <String, InteractionRequest>{}
        : Map.of(interactions);
    for (final request in collection.values) {
      final key = request.identityKey;
      if (_atLeast(interactionRemovals[key], collection.boundary.readStart)) {
        continue;
      }
      if (_newer(interactionPositions[key], collection.boundary.readStart)) {
        merged[key] = interactions[key] ?? request;
      } else {
        merged[key] = request;
        interactionPositions[key] = collection.boundary.readStart;
      }
    }
    for (final entry in interactions.entries) {
      if (_newer(
        interactionPositions[entry.key],
        collection.boundary.readStart,
      )) {
        merged[entry.key] = entry.value;
      }
    }
    interactions = merged;
    interactionPositions.removeWhere(
      (key, _) => !interactions.containsKey(key),
    );
    limitInteractions();
    changed = true;
  }

  void limitInteractions() {
    while (interactions.length > limits.maxObservations) {
      final key = interactions.keys.first;
      interactions.remove(key);
      interactionPositions.remove(key);
      refetch(SessionCollection.interactions, 'residentCollectionLimit');
    }
  }

  void limitRemovals() {
    while (interactionRemovals.length > limits.maxObservations) {
      interactionRemovals.remove(interactionRemovals.keys.first);
    }
  }

  void observeUsage(UsageObservation observation, StreamPosition position) {
    if (beforeReadBarrier(SessionCollection.usage, position)) return;
    if (!relatedOwner(observation.owner) ||
        (observation.provenance != null &&
            observation.provenance!.harness != ref.harnessRef)) {
      refetch(SessionCollection.usage, 'usageScopeMismatch');
      return;
    }
    final key = _usageKey(observation);
    if (_atLeast(usagePositions[key], position)) return;
    final aggregation = observation.aggregationIdentity;
    final at = usage.indexWhere(
      (current) =>
          _usageKey(current) == key ||
          (observation.cumulative &&
              !observation.partial &&
              aggregation != null &&
              current.cumulative &&
              !current.partial &&
              current.aggregationIdentity == aggregation),
    );
    if (at >= 0) {
      final previous = usage[at];
      final previousKey = _usageKey(previous);
      if (_atLeast(usagePositions[previousKey], position)) return;
      usagePositions.remove(previousKey);
      usage[at] = observation;
    } else {
      usage.add(observation);
    }
    usagePositions[key] = position;
    limitUsage();
    changed = true;
  }

  void hydrateUsage(SnapshotCollection<UsageObservation> collection) {
    if (!acceptSnapshot(
      SessionCollection.usage,
      collection.boundary,
      overlay: true,
    )) {
      return;
    }
    if (collection.values.any(
      (observation) =>
          !relatedOwner(observation.owner) ||
          (observation.provenance != null &&
              observation.provenance!.harness != ref.harnessRef),
    )) {
      refetch(SessionCollection.usage, 'usageScopeMismatch');
      return;
    }
    final old = List.of(usage);
    if (canReplace(collection.boundary, collection.complete)) {
      recordReadBarrier(SessionCollection.usage, collection.boundary);
      usage.clear();
    }
    for (final observation in collection.values) {
      final previous = old
          .where((value) => _usageMatches(value, observation))
          .firstOrNull;
      if (previous != null &&
          _newer(
            usagePositions[_usageKey(previous)],
            collection.boundary.readStart,
          )) {
        if (!usage.contains(previous)) usage.add(previous);
      } else {
        usage.removeWhere((value) => _usageMatches(value, observation));
        usage.add(observation);
        if (previous != null) usagePositions.remove(_usageKey(previous));
        usagePositions[_usageKey(observation)] = collection.boundary.readStart;
      }
    }
    for (final observation in old) {
      if (_newer(
            usagePositions[_usageKey(observation)],
            collection.boundary.readStart,
          ) &&
          !usage.any((value) => _usageKey(value) == _usageKey(observation))) {
        usage.add(observation);
      }
    }
    limitUsage();
    changed = true;
  }

  void limitUsage() {
    if (usage.length > limits.maxObservations) {
      usage.removeRange(0, usage.length - limits.maxObservations);
    }
    final retained = usage.map(_usageKey).toSet();
    usagePositions.removeWhere((key, _) => !retained.contains(key));
  }
}

bool _sameStream(StreamPosition? a, StreamPosition? b) =>
    a != null && b != null && a.id == b.id && a.epoch == b.epoch;
bool _newer(StreamPosition? a, StreamPosition? b) =>
    _sameStream(a, b) && a!.seq > b!.seq;
bool _atLeast(StreamPosition? a, StreamPosition? b) =>
    _sameStream(a, b) && a!.seq >= b!.seq;
bool _completed(TimelineItem item) =>
    item.status.known == ItemStatus.completed ||
    item.status.known == ItemStatus.failed ||
    item.status.known == ItemStatus.interrupted ||
    (item is AssistantText && item.complete) ||
    (item is Reasoning && item.complete);

TimelineItem _markGap(TimelineItem item) => switch (item) {
  AssistantText() when !_completed(item) => AssistantText(
    meta: item.meta,
    text: item.text,
    complete: item.complete,
    prefixMissing: true,
  ),
  Reasoning() when !_completed(item) => Reasoning(
    meta: item.meta,
    text: item.text,
    complete: item.complete,
    prefixMissing: true,
  ),
  _ => item,
};

String _observationKey(SessionEvent event) {
  final native = event.meta.source.nativeEventId;
  if (native == null) {
    final position = event.meta.position;
    return jsonEncode([
      'position',
      position.id,
      position.epoch,
      position.seq.toString(),
    ]);
  }
  final target = switch (event) {
    ItemUpserted(:final item) => jsonEncode(['item', item.id.value]),
    ItemDelta(:final itemId, :final field) => jsonEncode([
      'delta',
      itemId.value,
      field.value,
    ]),
    InteractionOpened(:final request) => request.identityKey,
    InteractionResolved(:final resolution) => resolution.identityKey,
    UsageObserved(:final observation) => _usageKey(observation),
    _ => '',
  };
  return jsonEncode(['native', native, event.runtimeType.toString(), target]);
}

String _usageKey(UsageObservation observation) => jsonEncode([
  observation.owner.scopeKey,
  observation.scope.value,
  observation.source.value,
  observation.id,
  observation.provenance?.version,
]);

(ItemId, String) _generationKey(TimelineItem item) =>
    (item.id, item.generation);

bool _usageMatches(UsageObservation a, UsageObservation b) =>
    _usageKey(a) == _usageKey(b) ||
    (a.cumulative &&
        b.cumulative &&
        !a.partial &&
        !b.partial &&
        a.aggregationIdentity != null &&
        a.aggregationIdentity == b.aggregationIdentity);
