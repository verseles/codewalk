import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';

/// Synthetic test support, not an implementation of any native protocol.
/// Scripts describe observations; only the real core reducer projects them.
final class ScriptedClock {
  ScriptedClock(DateTime now) : _now = now.toUtc();
  DateTime _now;
  DateTime get now => _now;

  void advance(Duration duration) {
    if (duration.isNegative) throw ArgumentError('Clock cannot go backwards');
    _now = _now.add(duration);
  }
}

/// All nullable restrictions default to unknown, including in this fake.
final class ScriptedAccess {
  const ScriptedAccess({
    required this.capabilities,
    required this.evidence,
    this.negotiated,
    this.modelAllowed,
    this.policyAllowed,
    this.platformAllowed,
    this.stateAllowed,
    this.selectedModelId,
  });

  final CapabilitySet capabilities;
  final ScopedCapabilityEvidence evidence;
  final bool? negotiated;
  final bool? modelAllowed;
  final bool? policyAllowed;
  final bool? platformAllowed;
  final bool? stateAllowed;
  final String? selectedModelId;
}

final class ScriptedOutcome {
  ScriptedOutcome({
    required this.command,
    required this.receipt,
    this.created,
  }) {
    if (command.id != receipt.id ||
        !command.owner.hasSameScope(receipt.owner)) {
      throw ArgumentError('Outcome must correlate to its original command');
    }
    if (created != null &&
        (command.operation.known != MutationOperation.create ||
            !receipt.admissionKnown ||
            created!.harnessRef != command.harness ||
            created!.nativeId != receipt.nativeRef)) {
      throw ArgumentError('Created session requires explicit known admission');
    }
  }

  final OriginalCommand command;
  final CommandReceipt receipt;
  final SessionRef? created;
}

/// A finite authored read. Its builder receives actual client read boundaries,
/// never a completion position substituted for an earlier read start.
final class ScriptedRead {
  ScriptedRead({
    required this.id,
    required this.ref,
    required this.generation,
    required Iterable<SessionCollection> collections,
    required this.build,
    this.deferred = false,
    this.before,
    this.limit = 50,
  }) : collections = Set.unmodifiable(collections) {
    requireText(id);
    requireText(generation);
    if (this.collections.isEmpty || limit <= 0 || limit > 500) {
      throw ArgumentError('Read must have collections and a bounded limit');
    }
  }

  final String id;
  final SessionRef ref;
  final String generation;
  final Set<SessionCollection> collections;
  final SessionSnapshot Function(Map<SessionCollection, SnapshotBoundary>)
  build;
  final bool deferred;
  final String? before;
  final int limit;
}

sealed class ScriptedStep {
  const ScriptedStep();
}

final class EmitEvent extends ScriptedStep {
  const EmitEvent(this.observer, this.event);
  final SessionRef observer;
  final SessionEvent event;
}

final class EmitConnection extends ScriptedStep {
  const EmitConnection(this.state);
  final ConnectionState state;
}

final class AdvanceClock extends ScriptedStep {
  const AdvanceClock(this.duration);
  final Duration duration;
}

final class StartCollectionRead extends ScriptedStep {
  const StartCollectionRead(this.read, this.collection);
  final String read;
  final SessionCollection collection;
}

final class FinishRead extends ScriptedStep {
  const FinishRead(this.read);
  final String read;
}

/// No timers, I/O, native calls, implicit outcomes, automatic responses or replay.
/// Consumers subscribe before stepping. Multiple handles observe independently.
final class ScriptedHarnessAdapter implements HarnessAdapter {
  ScriptedHarnessAdapter({
    required this.descriptor,
    required this.clock,
    required Map<DomainOwner, ScriptedAccess> access,
    required Iterable<SessionInfo> sessions,
    Iterable<ModelEntry> models = const [],
    Iterable<ScriptedStep> steps = const [],
    Iterable<ScriptedRead> reads = const [],
    Iterable<ScriptedOutcome> outcomes = const [],
    this.enableInteractions = true,
    this.maxProofAge = const Duration(minutes: 5),
  }) : _access = {
         for (final entry in access.entries) entry.key.scopeKey: entry.value,
       },
       _sessions = Map.unmodifiable({
         for (final info in sessions) info.ref: info,
       }),
       _models = List.unmodifiable(models),
       _steps = List.unmodifiable(steps),
       _reads = List.unmodifiable(reads),
       _outcomes = List.unmodifiable(outcomes) {
    if (maxProofAge.isNegative ||
        _access.length != access.length ||
        _access.length > 64 ||
        access.keys.any(
          (owner) => !owner.isKnown || owner.harness != descriptor.ref,
        ) ||
        _sessions.length > 16 ||
        _steps.length > 256 ||
        _reads.length > 32 ||
        _outcomes.length > 32 ||
        _models.length > 32 ||
        _sessions.keys.any((ref) => ref.harnessRef != descriptor.ref) ||
        _reads.map((read) => read.id).toSet().length != _reads.length) {
      throw ArgumentError('Script must be bounded and scoped to its harness');
    }
    for (final ref in _sessions.keys) {
      _positions[ref] = StreamPosition(
        id: 'scripted-observer',
        epoch: 'epoch',
        seq: BigInt.zero,
      );
    }
  }

  @override
  final HarnessDescriptor descriptor;
  final ScriptedClock clock;
  final bool enableInteractions;
  final Duration maxProofAge;
  final Map<String, ScriptedAccess> _access;
  final Map<SessionRef, SessionInfo> _sessions;
  final List<ModelEntry> _models;
  final List<ScriptedStep> _steps;
  final List<ScriptedRead> _reads;
  final List<ScriptedOutcome> _outcomes;
  final _connection = StreamController<ConnectionState>.broadcast(sync: true);
  final _handles = <_ScriptedHandle>{};
  final _positions = <SessionRef, StreamPosition>{};
  final _pendingInteractions = <String, InteractionRequest>{};
  final _interactionPositions = <(SessionRef, String), StreamPosition>{};
  final _seenObservations = <Object>{};
  final _appliedNativeInteractions = <Object>{};
  final _pendingReads = <String, _PendingRead>{};
  final _usedReads = <String>{};
  final _commands = <OriginalCommand>[];
  int _stepIndex = 0;
  int _outcomeIndex = 0;
  bool _disposed = false;

  List<OriginalCommand> get commands => List.unmodifiable(_commands);
  int get remainingSteps => _steps.length - _stepIndex;
  int get remainingOutcomes => _outcomes.length - _outcomeIndex;
  int get pendingReadCount => _pendingReads.length;
  int get observerCount => _handles.length;
  StreamPosition position(SessionRef ref) => _positions[ref]!;

  void setAccess(DomainOwner owner, ScriptedAccess access) {
    if (_disposed || !_access.containsKey(owner.scopeKey)) {
      throw StateError('Cannot replace access for an unregistered scope');
    }
    _access[owner.scopeKey] = access;
  }

  @override
  Stream<ConnectionState> get connection =>
      _connection.stream.where((_) => !_disposed);
  @override
  CatalogFacet get catalog => _ScriptedCatalog(this);
  @override
  WorkspaceFacet? get workspace => null;
  @override
  InteractionFacet? get interactions =>
      enableInteractions ? _ScriptedInteractions(this) : null;

  ScriptedAccess _lookup(DomainOwner owner, String capability) {
    if (_disposed) throw CapabilityUnavailable(capability, reason: 'disposed');
    if (!owner.isKnown ||
        owner.harness != descriptor.ref ||
        !_access.containsKey(owner.scopeKey)) {
      throw CapabilityUnavailable(capability, reason: 'unknownScope');
    }
    return _access[owner.scopeKey]!;
  }

  CapabilityContext _context(
    DomainOwner owner,
    ScriptedAccess access, {
    required bool mutating,
  }) => CapabilityContext(
    owner: owner,
    connectedVersion: descriptor.version,
    evidence: access.evidence,
    now: clock.now,
    maxProofAge: maxProofAge,
    mutating: mutating,
    negotiated: access.negotiated,
    modelAllowed: access.modelAllowed,
    policyAllowed: access.policyAllowed,
    platformAllowed: access.platformAllowed,
    stateAllowed: access.stateAllowed,
  );

  void _readGuard(DomainOwner owner, String name) {
    final access = _lookup(owner, name);
    access.capabilities.requireAvailable(
      name,
      context: _context(owner, access, mutating: false),
    );
  }

  @override
  Future<CapabilitySet> capabilities({DomainOwner? owner}) async => _lookup(
    owner ?? GlobalOwner(descriptor.ref),
    'capabilities',
  ).capabilities;

  @override
  Future<Page<SessionSummary>> listSessions(SessionQuery query) async {
    if (query.project != null && query.project!.host != descriptor.ref.host) {
      throw CapabilityUnavailable('history.list', reason: 'unknownScope');
    }
    final owner = query.project == null
        ? GlobalOwner(descriptor.ref)
        : ProjectOwner(query.project!, harness: descriptor.ref);
    _readGuard(owner, 'history.list');
    final infos = _sessions.values
        .where((info) => query.project == null || info.project == query.project)
        .toList();
    if (query.cursor != null ||
        query.activeOnly ||
        infos.length > query.limit) {
      throw CapabilityUnavailable('history.list', reason: 'queryNotScripted');
    }
    return Page(items: infos.map((info) => SessionSummary(info: info)));
  }

  @override
  Future<SessionHandle> open(SessionRef ref, OpenIntent intent) async {
    _readGuard(
      SessionOwner(ref),
      intent == OpenIntent.attachLive ? 'history.liveAttach' : 'history.read',
    );
    if (!_sessions.containsKey(ref)) {
      throw CapabilityUnavailable('history.read', reason: 'unknownSession');
    }
    return _newHandle(ref);
  }

  _ScriptedHandle _newHandle(SessionRef ref) {
    if (_handles.length >= 16) throw StateError('Observer limit exceeded');
    final handle = _ScriptedHandle(this, ref);
    _handles.add(handle);
    return handle;
  }

  Future<CommandReceipt> _mutate({
    required DomainOwner owner,
    required CommandId id,
    required String capability,
    required MutationOperation operation,
    required CanonicalValue intent,
    bool detached = false,
    void Function()? validate,
    void Function(ScriptedOutcome)? onOutcome,
  }) async {
    try {
      if (detached) throw CapabilityUnavailable(capability, reason: 'detached');
      final access = _lookup(owner, capability);
      return await access.capabilities.invoke(
        capability,
        context: _context(owner, access, mutating: true),
        mutation: () async {
          validate?.call();
          if (_commands.any(
            (command) => command.id == id && command.owner.hasSameScope(owner),
          )) {
            throw CapabilityUnavailable(
              capability,
              reason: 'reconciliationRequired',
            );
          }
          if (_outcomeIndex == _outcomes.length) {
            throw StateError('No scripted outcome');
          }
          final original = OriginalCommand(
            id: id,
            harness: descriptor.ref,
            owner: owner,
            operation: OpenValue.known(operation),
            connectedVersion: descriptor.version,
            intent: intent,
          );
          final outcome = _outcomes[_outcomeIndex];
          final expected = outcome.command;
          if (expected.id != id ||
              !expected.owner.hasSameScope(owner) ||
              expected.harness != original.harness ||
              expected.connectedVersion != original.connectedVersion ||
              expected.operation != original.operation ||
              expected.intent != intent) {
            throw StateError(
              'Command does not match the finite authored outcome',
            );
          }
          _outcomeIndex++;
          _commands.add(original);
          onOutcome?.call(outcome);
          return outcome.receipt;
        },
      );
    } on CapabilityUnavailable catch (error) {
      return CommandReceipt.unavailable(
        id: id,
        owner: owner,
        unavailable: error,
      );
    }
  }

  @override
  Future<CreateResult> create(CreateSession request) async {
    final owner = ProjectOwner(request.project, harness: request.harness);
    ScriptedOutcome? matched;
    final receipt = await _mutate(
      owner: owner,
      id: request.id,
      capability: 'scripted.create',
      operation: MutationOperation.create,
      intent: createIntent(request),
      validate: () => _validateSelection(request.selection),
      onOutcome: (outcome) => matched = outcome,
    );
    SessionHandle? handle;
    if (receipt.admissionKnown) {
      final created = matched?.created;
      if (created != null) {
        if (!_sessions.containsKey(created)) {
          throw StateError('Created session is not scripted');
        }
        try {
          _readGuard(SessionOwner(created), 'history.liveAttach');
          if (_handles.length < 16) {
            handle = _newHandle(created);
          }
        } on CapabilityUnavailable {
          // Optional observation cannot discard an already known admission.
          return CreateResult(receipt: receipt);
        }
      }
    }
    return CreateResult(receipt: receipt, handle: handle);
  }

  void _validateSelection(Selection? selection) {
    if (selection == null) return;
    if ((selection.modelId != null &&
            !_models.any((model) => model.id == selection.modelId)) ||
        selection.agentId != null ||
        selection.effort != null ||
        selection.permissionMode != null) {
      throw CapabilityUnavailable(
        'scripted.selection',
        reason: 'selectionNotOffered',
      );
    }
  }

  Future<CommandReceipt> _respond(
    DomainOwner owner,
    InteractionId interaction,
    InteractionResponse response,
    CommandId id, {
    bool detached = false,
  }) => _mutate(
    owner: owner,
    id: id,
    capability: 'approval.interactive',
    operation: MutationOperation.respond,
    intent: responseIntent(interaction, response),
    detached: detached,
    validate: () {
      if (!enableInteractions) {
        throw CapabilityUnavailable(
          'approval.interactive',
          reason: 'facetAbsent',
        );
      }
      final matches = _pendingInteractions.values.where(
        (request) =>
            request.id == interaction && request.owner.hasSameScope(owner),
      );
      if (matches.isEmpty) {
        throw CapabilityUnavailable(
          'approval.interactive',
          reason: 'interactionNotPending',
        );
      }
      final issues = matches.single.validateResponse(response);
      if (response is! ApprovalResponse || issues.isNotEmpty) {
        throw CapabilityUnavailable(
          'approval.interactive',
          reason: issues.isEmpty ? 'formsUnavailable' : issues.first.name,
        );
      }
    },
  );

  Future<SessionSnapshot> _snapshot(
    _ScriptedHandle handle,
    HistoryCursor? before,
    int limit,
  ) {
    _readGuard(SessionOwner(handle.ref), 'history.read');
    if (handle._detached) {
      throw CapabilityUnavailable('history.read', reason: 'detached');
    }
    final candidates = _reads.where(
      (read) => read.ref == handle.ref && !_usedReads.contains(read.id),
    );
    if (limit <= 0 || limit > 500 || candidates.isEmpty) {
      throw CapabilityUnavailable('history.read', reason: 'readNotScripted');
    }
    final plan = candidates.first;
    if (plan.before != before?.value || plan.limit != limit) {
      throw CapabilityUnavailable('history.read', reason: 'queryNotScripted');
    }
    _usedReads.add(plan.id);
    final pending = _PendingRead(plan, handle);
    _pendingReads[plan.id] = pending;
    if (!plan.deferred) {
      for (final collection in plan.collections) {
        if (!_startRead(plan.id, collection, propagate: false)) {
          return pending.completer.future;
        }
      }
      _finishRead(plan.id, propagate: false);
    }
    return pending.completer.future;
  }

  bool _startRead(
    String id,
    SessionCollection collection, {
    bool propagate = true,
  }) {
    final pending = _pendingReads[id];
    if (pending == null) throw StateError('Read is not pending');
    try {
      if (!pending.plan.collections.contains(collection) ||
          pending.starts.containsKey(collection)) {
        throw StateError('Collection read is unoffered or already started');
      }
      _readGuard(SessionOwner(pending.handle.ref), 'history.read');
      pending.starts[collection] = SnapshotBoundary(
        owner: SessionOwner(pending.handle.ref),
        hydrationGeneration: pending.plan.generation,
        readStart: position(pending.handle.ref),
        readStartedAt: clock.now,
        authority: const OpenValue.known(SnapshotAuthority.authoritative),
      );
      return true;
    } catch (error, stack) {
      _failRead(pending, error, stack);
      if (propagate) rethrow;
      return false;
    }
  }

  void _finishRead(String id, {bool propagate = true}) {
    final pending = _pendingReads[id];
    if (pending == null) throw StateError('Read is not pending');
    try {
      _completeRead(pending);
    } catch (error, stack) {
      _failRead(pending, error, stack);
      if (propagate) rethrow;
    }
  }

  void _failRead(_PendingRead pending, Object error, StackTrace stack) {
    _pendingReads.remove(pending.plan.id);
    pending.completer.completeError(error, stack);
  }

  void _completeRead(_PendingRead pending) {
    if (pending.starts.length != pending.plan.collections.length) {
      throw StateError(
        'Every collection must actually start before completion',
      );
    }
    final boundaries = <SessionCollection, SnapshotBoundary>{
      for (final entry in pending.starts.entries)
        entry.key: SnapshotBoundary(
          owner: entry.value.owner,
          hydrationGeneration: entry.value.hydrationGeneration,
          readStart: entry.value.readStart,
          readStartedAt: entry.value.readStartedAt,
          readCompletedAt: clock.now,
          authority: entry.value.authority,
        ),
    };
    final snapshot = pending.plan.build(Map.unmodifiable(boundaries));
    final actual = <SessionCollection, SnapshotBoundary?>{
      SessionCollection.info: snapshot.info?.boundary,
      SessionCollection.execution: snapshot.execution?.boundary,
      SessionCollection.timeline: snapshot.timeline?.boundary,
      SessionCollection.pending: snapshot.pending?.boundary,
      SessionCollection.interactions: snapshot.interactions?.boundary,
      SessionCollection.work: snapshot.work?.boundary,
      SessionCollection.plan: snapshot.plan?.boundary,
      SessionCollection.usage: snapshot.usage?.boundary,
      SessionCollection.selection: snapshot.selection?.boundary,
      SessionCollection.revert: snapshot.revert?.boundary,
    }..removeWhere((_, boundary) => boundary == null);
    if (snapshot.ref != pending.handle.ref ||
        snapshot.hydrationGeneration != pending.plan.generation ||
        snapshot.timeline != null &&
            snapshot.timeline!.values.length > pending.plan.limit ||
        actual.length != boundaries.length ||
        actual.entries.any(
          (entry) => !identical(entry.value, boundaries[entry.key]),
        )) {
      throw StateError(
        'Authored snapshot must retain each actual read boundary',
      );
    }
    _pendingReads.remove(pending.plan.id);
    pending.completer.complete(snapshot);
  }

  bool _firstObservation(SessionRef observer, SessionEvent event) {
    final nativeId = event.meta.source.nativeEventId;
    final key = switch (event) {
      InteractionOpened(:final request) => request.identityKey,
      InteractionResolved(:final resolution) => resolution.identityKey,
      _ => null,
    };
    // Position fallback is shared by all event kinds. Record even stale
    // observations before considering an interaction's causal position.
    final Object observation = nativeId == null
        ? (observer, event.meta.position)
        : (observer, nativeId, event.runtimeType, key);
    return _seenObservations.add(observation);
  }

  void _observeInteraction(
    SessionRef observer,
    SessionEvent event, {
    InteractionRequest? request,
    InteractionResolution? resolution,
  }) {
    final owner = request?.owner ?? resolution!.owner;
    if (owner.harness != descriptor.ref ||
        !_access.containsKey(owner.scopeKey) ||
        owner is SessionOwner &&
            owner.session != observer &&
            owner.origin != observer) {
      return;
    }
    final key = request?.identityKey ?? resolution!.identityKey;
    final position = event.meta.position;
    final observerKey = (observer, key);
    final previous = _interactionPositions[observerKey];
    if (previous != null && previous.seq >= position.seq) {
      return;
    }
    _interactionPositions[observerKey] = position;
    // Local clocks still advance on fanout, but its shared registry effect
    // must not be applied again after another observer has resolved it.
    final nativeId = event.meta.source.nativeEventId;
    if (nativeId != null &&
        !_appliedNativeInteractions.add((nativeId, event.runtimeType, key))) {
      return;
    }
    if (request != null) {
      _pendingInteractions[key] = request;
    } else {
      _pendingInteractions.remove(key);
    }
  }

  Future<void> step() async {
    if (_disposed || remainingSteps == 0) {
      throw StateError('Script disposed or exhausted');
    }
    final step = _steps[_stepIndex++];
    switch (step) {
      case AdvanceClock(:final duration):
        clock.advance(duration);
      case EmitConnection(:final state):
        _connection.add(state);
      case StartCollectionRead(:final read, :final collection):
        _startRead(read, collection);
      case FinishRead(:final read):
        _finishRead(read);
      case EmitEvent(:final observer, :final event):
        final position = _positions[observer];
        if (position == null) {
          throw StateError('Observer session is not scripted');
        }
        if (event.meta.owner.hasSameScope(SessionOwner(observer))) {
          final next = event.meta.position;
          final currentStream =
              next.id == position.id && next.epoch == position.epoch;
          if (currentStream && next.seq > position.seq) {
            _positions[observer] = next;
          }
          if (currentStream && _firstObservation(observer, event)) {
            switch (event) {
              case InteractionOpened(:final request):
                _observeInteraction(observer, event, request: request);
              case InteractionResolved(:final resolution):
                _observeInteraction(observer, event, resolution: resolution);
              default:
                break;
            }
          }
        }
        for (final handle in _handles.toList()) {
          if (handle.ref == observer && !handle._detached) {
            handle._events.add(event);
          }
        }
    }
  }

  void _cancelReads(_ScriptedHandle handle) {
    for (final pending
        in _pendingReads.values
            .where((read) => identical(read.handle, handle))
            .toList()) {
      _pendingReads.remove(pending.plan.id);
      pending.completer.completeError(
        CapabilityUnavailable(
          'history.read',
          reason: _disposed ? 'disposed' : 'detached',
        ),
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final handle in _handles.toList()) {
      await handle.detach();
    }
    _pendingInteractions.clear();
    _interactionPositions.clear();
    _seenObservations.clear();
    _appliedNativeInteractions.clear();
    // A paused subscriber must not hold disposal hostage. No timers remain.
    unawaited(Future<void>.microtask(_connection.close));
  }
}

final class _PendingRead {
  _PendingRead(this.plan, this.handle);
  final ScriptedRead plan;
  final _ScriptedHandle handle;
  final completer = Completer<SessionSnapshot>();
  final starts = <SessionCollection, SnapshotBoundary>{};
}

final class _ScriptedHandle implements SessionHandle {
  _ScriptedHandle(this.adapter, this.ref);
  final ScriptedHarnessAdapter adapter;
  @override
  final SessionRef ref;
  final _events = StreamController<SessionEvent>.broadcast(sync: true);
  bool _detached = false;
  @override
  Stream<SessionEvent> get events => _events.stream.where((_) => !_detached);
  @override
  QueueFacet? get queue => null;
  @override
  UndoFacet? get undo => null;
  @override
  WorkFacet? get work => null;
  @override
  LifecycleFacet? get lifecycle => null;
  @override
  Future<SessionSnapshot> snapshot({
    HistoryCursor? before,
    int limit = 50,
  }) async => adapter._snapshot(this, before, limit);

  @override
  Future<CommandReceipt> send(
    PromptDraft draft, {
    required CommandId id,
    OpenValue<Delivery>? delivery,
  }) => adapter._mutate(
    owner: SessionOwner(ref),
    id: id,
    capability: 'scripted.prompt',
    operation: MutationOperation.prompt,
    intent: promptIntent(draft, delivery: delivery),
    detached: _detached,
    validate: () {
      if (delivery != null && delivery.known != Delivery.immediate) {
        throw CapabilityUnavailable(
          'scripted.prompt',
          reason: 'deliveryUnavailable',
        );
      }
      adapter._validateSelection(draft.selection);
      final modelId =
          draft.selection?.modelId ??
          adapter._access[SessionOwner(ref).scopeKey]?.selectedModelId;
      final models = adapter._models.where((model) => model.id == modelId);
      if (draft.attachments.isNotEmpty &&
          (models.length != 1 ||
              draft.attachments.any(
                (attachment) =>
                    models.single.inputModalities[attachment.mimeType] != true,
              ))) {
        throw CapabilityUnavailable(
          'scripted.prompt',
          reason: 'modalityUnverified',
        );
      }
    },
  );

  @override
  Future<CommandReceipt> interrupt(
    InterruptTarget target, {
    required CommandId id,
  }) => adapter._mutate(
    owner: SessionOwner(ref),
    id: id,
    capability: 'scripted.interrupt',
    operation: MutationOperation.interrupt,
    intent: interruptIntent(target),
    detached: _detached,
    validate: () {
      if (target.kind.known != InterruptKind.turn || target.child != null) {
        throw CapabilityUnavailable(
          'scripted.interrupt',
          reason: 'targetUnavailable',
        );
      }
    },
  );

  @override
  Future<CommandReceipt> select(
    SelectionChange change, {
    required CommandId id,
  }) => adapter._mutate(
    owner: SessionOwner(ref),
    id: id,
    capability: 'scripted.selection',
    operation: MutationOperation.selection,
    intent: CanonicalValue(selectionIntent(change.selection)),
    detached: _detached,
    validate: () => adapter._validateSelection(change.selection),
  );

  @override
  Future<CommandReceipt> respond(
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  }) => adapter._respond(
    SessionOwner(ref),
    interaction,
    response,
    id,
    detached: _detached,
  );

  @override
  Future<void> detach() async {
    if (_detached) return;
    _detached = true;
    adapter._handles.remove(this);
    adapter._cancelReads(this);
    // Closing on the next microtask is safe even from a synchronous listener.
    unawaited(Future<void>.microtask(_events.close));
  }
}

final class _ScriptedCatalog implements CatalogFacet {
  const _ScriptedCatalog(this.adapter);
  final ScriptedHarnessAdapter adapter;
  @override
  Future<List<ModelEntry>> models() async {
    adapter._readGuard(GlobalOwner(adapter.descriptor.ref), 'catalog.models');
    return adapter._models;
  }

  @override
  Future<List<CatalogEntry>> entries(OpenValue<CatalogKind> kind) async {
    adapter._readGuard(GlobalOwner(adapter.descriptor.ref), 'catalog.models');
    if (kind.known != CatalogKind.model) {
      throw CapabilityUnavailable('catalog.entries', reason: 'kindNotScripted');
    }
    return List.unmodifiable(
      adapter._models.map(
        (model) => CatalogEntry(id: model.id, kind: kind, label: model.label),
      ),
    );
  }
}

final class _ScriptedInteractions implements InteractionFacet {
  const _ScriptedInteractions(this.adapter);
  final ScriptedHarnessAdapter adapter;
  @override
  Future<Page<InteractionRequest>> pending(DomainOwner owner) async {
    adapter._readGuard(owner, 'approval.interactive');
    return Page(
      items: adapter._pendingInteractions.values.where(
        (request) => request.owner.hasSameScope(owner),
      ),
    );
  }

  @override
  Future<CommandReceipt> respond(
    DomainOwner owner,
    InteractionId interaction,
    InteractionResponse response, {
    required CommandId id,
  }) => adapter._respond(owner, interaction, response, id);
}

// Original canonical intents include correlation-relevant optional fields.
// These are test values, not native serialization or persistence guarantees.
Map<String, Object?>? selectionIntent(Selection? selection) => selection == null
    ? null
    : {
        'modelId': selection.modelId,
        'agentId': selection.agentId,
        'effort': selection.effort,
        'permissionMode': selection.permissionMode,
        'metadata': selection.metadata?.toJson(),
      };

CanonicalValue promptIntent(
  PromptDraft draft, {
  OpenValue<Delivery>? delivery,
}) => CanonicalValue({
  'text': draft.text,
  'delivery': delivery?.value,
  'selection': selectionIntent(draft.selection),
  'metadata': draft.metadata?.toJson(),
  'attachments': [
    for (final attachment in draft.attachments)
      {
        'id': attachment.id,
        'mimeType': attachment.mimeType,
        'name': attachment.name,
        'content': {
          'id': attachment.content.id,
          'mimeType': attachment.content.mimeType,
          'sizeBytes': attachment.content.sizeBytes,
          'truncated': attachment.content.truncated,
        },
      },
  ],
  'mentions': [
    for (final mention in draft.mentions)
      {
        'id': mention.id,
        'kind': mention.kind.value,
        'label': mention.label,
        'target': mention.target,
      },
  ],
});

CanonicalValue createIntent(CreateSession request) => CanonicalValue({
  'project': request.project.toJson(),
  'title': request.title,
  'selection': selectionIntent(request.selection),
  'metadata': request.metadata?.toJson(),
});

CanonicalValue interruptIntent(InterruptTarget target) => CanonicalValue({
  'kind': target.kind.value,
  'child': target.child?.toJson(),
  'turn': target.turn?.value,
});

CanonicalValue responseIntent(
  InteractionId interaction,
  InteractionResponse response,
) => CanonicalValue({
  'interaction': interaction.value,
  'response': response is ApprovalResponse
      ? {'choiceId': response.choiceId, 'note': response.note}
      : {'kind': 'unsupportedForm'},
});
