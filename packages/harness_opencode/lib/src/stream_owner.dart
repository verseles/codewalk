import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'event_projection.dart';
import 'execution_projection.dart';
import 'interaction_projection.dart';
import 'plan_projection.dart';
import 'session_projection.dart';
import 'session_reader.dart';
import 'session_rules.dart';
import 'shell_client.dart';
import 'shell_observation.dart';
import 'stream_owner_watch.dart';

/// Readiness predicate for the event stream connection: the transport must be
/// built with `connectedWhen: openCodeServerConnected`, so it holds every
/// later frame until the owner releases the generation.
bool openCodeServerConnected(SseFrame frame) {
  try {
    final value = jsonDecode(frame.data);
    return value is Map && value['type'] == 'server.connected';
  } on FormatException {
    return false;
  }
}

/// How long the event stream may have been silent and still be kept when
/// the app returns from the background (#503): OpenCode writes a heartbeat
/// comment every 15 s (2.0.22 `server/src/handlers/event.ts`), and its own
/// client keeps a stream quiet for under 20 s on a return to the foreground.
const openCodeResumeQuiet = Duration(seconds: 20);

/// Finite stream-owner failure categories; never native content.
enum OpenCodeStreamFailure { malformedControl, hydrationExhausted, terminal }

/// A session lifecycle change the catalog observes.
///
/// The kind is the whole signal: no session id, title, location or payload
/// travels with it, because the consumer re-reads the authoritative list
/// instead of patching a row. A fork is a new session that starts elsewhere
/// and emits `session.forked` rather than `session.created`; a move changes
/// the location a session belongs to; a view updates the unread watermark; and
/// a session that goes idle advances that watermark. A session that starts
/// running, and a permission request or form that is asked or answered,
/// change only the activity the endpoint reports, not the list.
enum OpenCodeCatalogChange {
  created,
  forked,
  renamed,
  deleted,
  moved,
  archived,
  viewed,
  idled,
  started,
  waiting,
  project,
}

sealed class OpenCodeStreamUpdate {
  const OpenCodeStreamUpdate();
}

/// One reduction applied to a watched session's state.
final class OpenCodeSessionUpdated extends OpenCodeStreamUpdate {
  OpenCodeSessionUpdated(this.ref, this.state, Iterable<ReducerEffect> effects)
    : effects = List.unmodifiable(effects);
  final SessionRef ref;
  final SessionState state;
  final List<ReducerEffect> effects;
}

/// The server no longer has the session; it was closed in the store.
final class OpenCodeSessionEvicted extends OpenCodeStreamUpdate {
  const OpenCodeSessionEvicted(this.ref);
  final SessionRef ref;
}

/// A session's permission rules were updated upstream (via `session.permissions`).
final class OpenCodeSessionRulesUpdated extends OpenCodeStreamUpdate {
  const OpenCodeSessionRulesUpdated(this.ref, this.rules);
  final SessionRef ref;
  final OpenCodeSessionRules rules;
}

/// Connection confidence for the whole stream, with a finite failure when one
/// stopped progress.
final class OpenCodeConnectionUpdated extends OpenCodeStreamUpdate {
  const OpenCodeConnectionUpdated(this.kind, {this.failure, this.session});
  final ConnectionKind kind;
  final OpenCodeStreamFailure? failure;

  /// Set when the failure concerns one session rather than the stream.
  final SessionRef? session;
}

const _maxHeldShellTerminals = 64;
const _maxTrackedShellLocations = 512;

const _retryable = {
  OpenCodeSessionReadFailure.unavailable,
  OpenCodeSessionReadFailure.timeout,
  OpenCodeSessionReadFailure.connection,
  OpenCodeSessionReadFailure.rateLimited,
};

/// The single consumer of `GET /api/event` for one OpenCode 2.0.22 harness.
///
/// For each connection generation it hydrates every watched session from one
/// shared read start (`hydrateSession`), then releases the generation and
/// reduces each later frame, in arrival order, through [projectOpenCodeEvent]
/// into the [SessionStore]. Stream positions use the generation as epoch and
/// count every frame after the connection frame, so a snapshot's read
/// barriers order it against the frames around it.
///
/// A session watched after the release keeps its own frames until its first
/// snapshot, so none is projected against an empty state. Repair requests from
/// the reducer, and frames a producer rejects, coalesce into one bounded
/// re-hydration per session; a session whose hydration keeps failing is set
/// aside (disconnected, frames skipped) instead of holding the others back,
/// and a session the server reports missing is evicted. Disconnects mark every
/// watched session; reconnecting is the transport's job.
final class OpenCodeStreamOwner {
  OpenCodeStreamOwner({
    required this.connection,
    required this.reader,
    required this.store,
    required this.harness,
    required this.sourceVersion,
    DateTime Function()? now,
    Future<void> Function(Duration delay)? delay,
    this.maxHydrationAttempts = 3,
    this.maxRepairs = 3,
    this.maxHeldFrames = 256,
    this.observeChildren = false,
    this.observeShells = false,
    this.maxChildren = 64,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       _customDelay = delay,
       streamId = 'opencode:/api/event:${harness.storageKey}' {
    if (maxHydrationAttempts <= 0 ||
        maxRepairs < 0 ||
        maxHeldFrames <= 0 ||
        maxChildren <= 0) {
      throw ArgumentError('Stream owner limits must be positive.');
    }
  }

  final RecoveringSseConnection connection;
  final OpenCodeSessionReader reader;
  final SessionStore store;
  final HarnessRef harness;
  final String sourceVersion;
  final int maxHydrationAttempts;
  final int maxRepairs;
  final int maxHeldFrames;

  /// Projects the permission requests of each watched session's direct
  /// children (sub-agents) into that session, owned by the child with the
  /// parent as origin (ADR-059 §6), and counts the running ones as its work.
  /// Children are never watched for this.
  final bool observeChildren;

  /// Projects harness-observed shell processes (`/api/shell` + `shell.*` SSE)
  /// into `SessionState.shells`, isolated from subagent `work`.
  final bool observeShells;

  /// Children followed per watched parent; later ones are ignored.
  final int maxChildren;
  final String streamId;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  final Future<void> Function(Duration)? _customDelay;

  final _updates = StreamController<OpenCodeStreamUpdate>.broadcast();
  final _catalogChanges = StreamController<OpenCodeCatalogChange>.broadcast();
  final _locationCatalogs = StreamController<String>.broadcast();
  final _watched = <SessionRef, OpenCodeWatch>{};
  final _children = <SessionRef, Set<SessionRef>>{};
  final _shellLocations = <String, String>{};
  StreamSubscription<SseRecoveryUpdate>? _subscription;
  ConnectionKind? _connectionKind;
  int? _generation;
  bool _released = false;
  bool _woke = false;
  bool _closed = false;
  int _seq = 0;

  Stream<OpenCodeStreamUpdate> get updates => _updates.stream;

  /// The connection state of the stream, for a subscriber that arrives after
  /// the owner already reported one. A per-session update never changes it.
  ConnectionKind? get connectionKind => _connectionKind;

  /// The session lifecycle changes of every session of this harness, watched
  /// or not. The catalog listens here so the list can follow a session that
  /// starts, is renamed, is deleted or is moved elsewhere.
  Stream<OpenCodeCatalogChange> get catalogChanges => _catalogChanges.stream;

  /// The directories whose model, agent or provider catalog changed, as the
  /// endpoint reports them. A report without a location names none, as the
  /// official client ignores it.
  Stream<String> get locationCatalogChanges => _locationCatalogs.stream;

  Iterable<SessionRef> get watched => List.unmodifiable(_watched.keys);

  /// The children whose permission requests [parent] currently shows.
  Set<SessionRef> childrenOf(SessionRef parent) =>
      Set.unmodifiable(_children[parent] ?? const <SessionRef>{});

  /// One coalesced re-read of [ref], for example after a reply was refused
  /// because someone else answered first. Does not consume the error repair
  /// budget.
  void refresh(SessionRef ref) => _refresh(ref);

  /// Adapter-private verified directory for [shellId], retained from its
  /// `shell.created` frame or `listRunning` response for per-shell routing.
  String? shellDirectoryOf(String shellId) => _shellLocations[shellId];

  void _recordShellLocation(String shellId, String directory) {
    _shellLocations.remove(shellId);
    _shellLocations[shellId] = directory;
    while (_shellLocations.length > _maxTrackedShellLocations) {
      _shellLocations.remove(_shellLocations.keys.first);
    }
  }

  void _recordShellLocations(Map<String, String> entries) {
    for (final entry in entries.entries) {
      _recordShellLocation(entry.key, entry.value);
    }
  }

  /// One coalesced shell-only refresh of [ref]'s running/reconciled shells,
  /// without re-hydrating timeline or sub-agent collections.
  ///
  /// Preserves any live shell lifecycle mutations (`shell.created`,
  /// `shell.exited`, `shell.deleted`, or `dropShell`) that arrived while the
  /// HTTP reconciliation was in flight so stale responses can never erase
  /// newly created shells or resurrect stopped/deleted ones.
  Future<void> refreshShells(SessionRef ref) async {
    final generation = _generation;
    final watch = _watched[ref];
    if (!observeShells ||
        _closed ||
        generation == null ||
        watch == null ||
        !watch.ready ||
        watch.stalled ||
        watch.hydrating ||
        watch.shellsRefreshing) {
      return;
    }
    watch
      ..shellsRefreshing = true
      ..shellsRefreshInvalidated = false
      ..mutatedShellIdsWhileRefreshing.clear();
    final refreshStartSeq = _seq;
    final cancellation = RequestCancellation();
    watch.shellsCancellation = cancellation;
    try {
      final state = store.read(ref);
      if (state == null) return;
      final reconciled =
          await OpenCodeShellClient(
            reader.transport,
            harness: harness,
            connectedVersion: sourceVersion,
            deadline: reader.deadline,
          ).reconcileHydration(
            session: ref,
            directory: state.info?.project?.canonicalDirectory,
            residentShells: state.shells,
            knownLocations: Map.of(_shellLocations),
            cancellation: cancellation,
          );
      if (!_current(ref, watch, generation) ||
          watch.stalled ||
          watch.hydrating ||
          watch.shellsRefreshInvalidated) {
        return;
      }
      final mutated = Set<String>.of(watch.mutatedShellIdsWhileRefreshing);
      for (final entry in reconciled.locations.entries) {
        if (!mutated.contains(entry.key)) {
          _recordShellLocation(entry.key, entry.value);
        }
      }
      final latest = store.read(ref);
      if (latest == null) return;
      final incoming = <ShellWork>[
        for (final item in reconciled.shells)
          if (!mutated.contains(item.id)) item,
        for (final item in latest.shells)
          if (mutated.contains(item.id)) item,
      ];
      final merged = mergeShellObservations(
        latest.shells,
        incoming,
        maxObservations: latest.limits.maxObservations,
      );
      final result = store.apply(
        ref,
        ShellChanged(
          meta: EventMeta(
            owner: SessionOwner(ref),
            position: _position(++_seq),
            receivedAt: _now(),
            source: SourceProvenance(
              harness: harness,
              version: sourceVersion,
              nativeType: 'shell.list',
              durability: const OpenValue.known(Durability.ephemeral),
            ),
          ),
          items: merged,
        ),
      );
      _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
      _handle(ref, result.effects);
      // Replay any shell.exited/deleted frames that arrived while refreshing
      // for shell IDs newly discovered by this response.
      if (watch.heldShellTerminals.isNotEmpty) {
        final pending = List.of(watch.heldShellTerminals);
        watch.heldShellTerminals.clear();
        for (final (seq, value, shellId) in pending) {
          if (!_current(ref, watch, generation) || watch.stalled) break;
          if (seq <= refreshStartSeq) continue;
          if (store.read(ref)?.shells.any((s) => s.id == shellId) ?? false) {
            _apply(ref, value, ++_seq);
            if (value['type'] == 'shell.deleted') {
              _shellLocations.remove(shellId);
            }
          }
        }
      }
    } on OpenCodeSessionReadException {
      // Shell refresh is best-effort and never degrades the live session.
    } finally {
      if (identical(watch.shellsCancellation, cancellation)) {
        watch.shellsCancellation = null;
      }
      watch
        ..shellsRefreshing = false
        ..heldShellTerminals.clear()
        ..mutatedShellIdsWhileRefreshing.clear();
    }
  }

  /// Drops [shellId] locally from [ref]'s resident shell set (e.g. after a
  /// deliberate stop returned 404/204), guarded against disconnected or
  /// hydrating watches so it never emits a null epoch or races a snapshot.
  void dropShell(SessionRef ref, String shellId) {
    if (_closed || _generation == null) return;
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    _shellLocations.remove(shellId);
    if (watch.shellsRefreshing) {
      watch.mutatedShellIdsWhileRefreshing.add(shellId);
    }
    if (!watch.ready || watch.hydrating) {
      watch.dirty = true;
      return;
    }
    final state = store.read(ref);
    if (state == null || !state.shells.any((s) => s.id == shellId)) return;
    final result = store.apply(
      ref,
      ShellChanged(
        meta: EventMeta(
          owner: SessionOwner(ref),
          position: _position(++_seq),
          receivedAt: _now(),
          source: SourceProvenance(
            harness: harness,
            version: sourceVersion,
            nativeType: 'shell.deleted',
            durability: const OpenValue.known(Durability.ephemeral),
          ),
        ),
        items: [
          for (final shell in state.shells)
            if (shell.id != shellId) shell,
        ],
      ),
    );
    _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
    _handle(ref, result.effects);
  }

  /// The page size of hydration and of every older page: the history cursor
  /// encodes it, so a continuation must use the same one. Matches the official
  /// OpenCode Web/TUI default (`20`).
  static const historyPageLimit = 20;

  /// Whether [loadOlderHistory] would read: the session is current, an older
  /// cursor exists, the window has room and was never trimmed in front.
  bool canLoadOlderHistory(SessionRef ref) {
    final watch = _watched[ref];
    if (_closed ||
        _generation == null ||
        !_released ||
        watch == null ||
        !watch.ready ||
        watch.stalled ||
        watch.hydrating ||
        watch.olderCancellation != null) {
      return false;
    }
    final state = store.read(ref);
    if (state == null || state.nextHistoryCursor == null) return false;
    return state.timeline.length < state.limits.maxItems &&
        !olderHistoryTrimmed(ref);
  }

  /// Whether the window of [ref] lost rows in front of the oldest one a read
  /// put in it: those rows are known to exist and are no longer resident,
  /// whatever the cursor says.
  bool olderHistoryTrimmed(SessionRef ref) {
    final watch = _watched[ref];
    if (watch == null) return false;
    _noteTrim(ref, watch);
    return watch.trimmed;
  }

  void _noteTrim(SessionRef ref, OpenCodeWatch watch) {
    if (watch.trimmed) return;
    final covered = watch.oldestCovered;
    final first = store.read(ref)?.timeline.firstOrNull;
    if (covered != null && first != null && first.id != covered) {
      watch.trimmed = true;
    }
  }

  /// Reads the next older page of [ref] and prepends it to the window as a
  /// partial timeline snapshot, so live frames and history share the
  /// reducer's ordering. True when a page was applied; false when nothing was
  /// read or the result was dropped because the session moved on. A read
  /// failure is rethrown; it never changes the window or the cursor.
  Future<bool> loadOlderHistory(SessionRef ref) async {
    if (!canLoadOlderHistory(ref)) return false;
    final watch = _watched[ref]!;
    final generation = _generation!;
    final cursor = store.read(ref)!.nextHistoryCursor!;
    final cancellation = RequestCancellation();
    watch.olderCancellation = cancellation;
    try {
      final readStart = _position(_seq);
      final started = _now();
      final page = await reader.readHistory(
        ref,
        sourceVersion: sourceVersion,
        limit: historyPageLimit,
        cursor: cursor.value,
        cancellation: cancellation,
      );
      final completed = _now();
      if (!_current(ref, watch, generation) || cancellation.isCancelled) {
        return false;
      }
      final next = page.nextCursor;
      final result = store.applySnapshot(
        ref,
        SessionSnapshot(
          ref: ref,
          hydrationGeneration: '$generation',
          timeline: SnapshotCollection(
            values: page.items,
            boundary: SnapshotBoundary(
              owner: SessionOwner(ref),
              hydrationGeneration: '$generation',
              readStart: readStart,
              readStartedAt: started,
              readCompletedAt: completed,
              source: SourceProvenance(
                harness: harness,
                version: sourceVersion,
                nativeType: 'session.message.list',
              ),
              authority: const OpenValue.known(SnapshotAuthority.authoritative),
            ),
            complete: false,
          ),
          nextHistoryCursor: next == null ? null : HistoryCursor(next),
          hasMoreHistory: next != null,
        ),
      );
      if (page.items.isNotEmpty) watch.oldestCovered = page.items.first.id;
      _noteTrim(ref, watch);
      _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
      _handle(ref, result.effects);
      // Fill an initially unknown (or unproven empty after revert) plan from the
      // merged timeline without ever replacing a newer plan already observed.
      final existingPlan = result.state.plan;
      final needsPlanFill =
          existingPlan == null ||
          (existingPlan.entries.isEmpty && existingPlan.anchor == null);
      if (needsPlanFill) {
        final stagedCut = result.state.revert?.kind.known == RevertKind.staged
            ? result.state.revert?.anchor
            : null;
        final scanItems = stagedCut == null
            ? result.state.timeline
            : [
                for (final item in result.state.timeline)
                  if (item.meta.anchor == null ||
                      item.meta.anchor!.compareTo(stagedCut) < 0)
                    item,
              ];
        final older = openCodeLatestPlan(
          scanItems,
          ref: ref,
          sourceVersion: sourceVersion,
          hasMoreHistory: result.state.hasMoreHistory,
        );
        if (older.authoritative &&
            older.snapshot != null &&
            older.snapshot != existingPlan) {
          final filled = store.apply(
            ref,
            PlanChanged(
              meta: EventMeta(
                owner: SessionOwner(ref),
                position: _position(++_seq),
                receivedAt: _now(),
                source: SourceProvenance(
                  harness: harness,
                  version: sourceVersion,
                  nativeType: 'session.message.list',
                ),
              ),
              plan: older.snapshot!,
            ),
          );
          _emit(OpenCodeSessionUpdated(ref, filled.state, filled.effects));
          _handle(ref, filled.effects);
        }
      }
      return true;
    } on OpenCodeSessionReadException catch (error) {
      if (!_current(ref, watch, generation) ||
          error.failure == OpenCodeSessionReadFailure.cancelled) {
        return false;
      }
      rethrow;
    } finally {
      if (identical(watch.olderCancellation, cancellation)) {
        watch.olderCancellation = null;
      }
    }
  }

  bool _adopt(SessionRef parent, Iterable<SessionRef> children) {
    final before = _children[parent];
    _reconcileChildren(parent, [...children, ...?before]);
    final after = _children[parent];
    if (before == null) return after != null && after.isNotEmpty;
    if (after == null || before.length != after.length) return true;
    return !after.containsAll(before);
  }

  void _reconcileChildren(SessionRef parent, Iterable<SessionRef> listed) {
    final active = store.read(parent);
    final resident = {
      if (active != null)
        for (final work in active.work)
          if (work.parent == parent && work.child != null) work.child!: work,
    };
    // Ongoing work and human requests outrank the recent page. Old terminal
    // rows must not consume the follow budget ahead of a newly created child.
    final priority = {
      if (active != null)
        for (final r in active.interactions)
          if (r.owner is SessionOwner &&
              (r.owner as SessionOwner).origin == parent)
            (r.owner as SessionOwner).session,
      for (final entry in resident.entries)
        if (entry.value.status.known == WorkStatus.running ||
            entry.value.status.known == WorkStatus.waiting ||
            entry.value.status.known == WorkStatus.queued)
          entry.key,
      // A creation frame can precede its first work projection or listed row.
      for (final child in _children[parent] ?? const <SessionRef>{})
        if (!resident.containsKey(child)) child,
    };
    final next = <SessionRef>{};
    for (final child in [...priority, ...listed, ...resident.keys]) {
      if (child == parent || child.harnessRef != harness) continue;
      next.add(child);
      if (next.length == maxChildren) break;
    }
    _children[parent] = next;
  }

  void start() {
    if (_closed || _subscription != null) return;
    _subscription = connection.updates.listen(_onUpdate);
  }

  /// Opens [ref] in the store and keeps it hydrated; remote work is untouched.
  /// Refused (false) when the store could not keep every watched session,
  /// since its LRU would silently evict one of them.
  bool watch(SessionRef ref) {
    if (_closed || ref.harnessRef != harness) return false;
    if (_watched.containsKey(ref)) return true;
    if (_watched.length >= store.maxSessions) return false;
    store.open(ref);
    _watched[ref] = OpenCodeWatch();
    // During the gate the generation loop picks it up before release.
    if (_generation != null && _released) unawaited(_hydrate(ref));
    return true;
  }

  /// Forgets [ref] locally; it never interrupts remote execution.
  void unwatch(SessionRef ref) {
    final watch = _watched.remove(ref);
    if (watch == null) return;
    _children.remove(ref);
    watch.cancellation?.cancel();
    watch.olderCancellation?.cancel();
    watch.shellsCancellation?.cancel();
    watch.shellsRetryTimer?.cancel();
    store.close(ref);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final watch in _watched.values) {
      watch.cancellation?.cancel();
      watch.olderCancellation?.cancel();
      watch.shellsCancellation?.cancel();
      watch.shellsRetryTimer?.cancel();
    }
    await _subscription?.cancel();
    await _updates.close();
    await _catalogChanges.close();
    await _locationCatalogs.close();
  }

  StreamPosition _position(int seq) => StreamPosition(
    id: streamId,
    epoch: '$_generation',
    seq: BigInt.from(seq),
  );

  void _emit(OpenCodeStreamUpdate update) {
    if (_closed) return;
    if (update case OpenCodeConnectionUpdated(:final kind, :final session)) {
      // A per-session update is not a stream update: the stream stays live
      // while one watched session is degraded.
      if (session == null) _connectionKind = kind;
    }
    _updates.add(update);
  }

  void _emitLocationCatalog(Map<String, Object?> value) {
    if (_closed || _locationCatalogs.isClosed) return;
    final type = value['type'];
    if (type == 'credential.updated' || type == 'credential.switched') {
      // Credential changes affect provider/model catalogs across every watched
      // location (matching the official client, which receives no `location`).
      final directories = <String>{};
      for (final ref in _watched.keys) {
        final dir = store.read(ref)?.info?.project?.canonicalDirectory;
        if (dir != null && dir.isNotEmpty && directories.add(dir)) {
          _locationCatalogs.add(dir);
        }
      }
      return;
    }
    if (type
        case 'model.updated' ||
            'agent.updated' ||
            'provider.updated' ||
            'integration.updated' ||
            'config.updated') {
      if (value['location'] case {
        'directory': final String directory,
      } when directory.isNotEmpty) {
        _locationCatalogs.add(directory);
      }
    }
  }

  void _emitCatalogChange(Object? type) {
    if (_closed) return;
    final change = openCodeCatalogChangeOf(type);
    if (change == null || _catalogChanges.isClosed) return;
    _catalogChanges.add(change);
  }

  void _onUpdate(SseRecoveryUpdate update) {
    if (_closed) return;
    switch (update) {
      case SseConnected(:final generation, :final firstFrame):
        unawaited(_onConnected(generation, firstFrame));
      case SseBatch(:final generation, :final frames):
        if (generation != _generation || !_released) return;
        for (final frame in frames) {
          _onFrame(frame);
        }
      case SseDisconnected(:final generation, :final failure, :final terminal):
        // An attempt that failed before connecting never had a generation
        // here; its terminal end still stops the stream.
        if (generation != _generation && !(terminal && _generation == null)) {
          return;
        }
        _onDisconnected(failure, terminal);
    }
  }

  Future<void> _onConnected(int generation, SseFrame? first) async {
    for (final watch in _watched.values) {
      watch.cancellation?.cancel();
      watch.olderCancellation?.cancel();
      watch.shellsCancellation?.cancel();
      watch.shellsRetryTimer?.cancel();
      watch.heldShellTerminals.clear();
      watch.shellsRetried = false;
    }
    if (first == null || !openCodeServerConnected(first)) {
      _generation = null;
      _emit(
        const OpenCodeConnectionUpdated(
          ConnectionKind.incompatible,
          failure: OpenCodeStreamFailure.malformedControl,
        ),
      );
      return;
    }
    _generation = generation;
    _released = false;
    _woke = false;
    _seq = 0;
    // Fresh per-generation bookkeeping: work left over from an older
    // generation sees a different watch and stops touching this one.
    for (final ref in _watched.keys.toList()) {
      _watched[ref] = OpenCodeWatch();
    }
    _emit(const OpenCodeConnectionUpdated(ConnectionKind.hydrating));
    // Sequential, including sessions watched while the gate is open.
    while (true) {
      if (_closed || _generation != generation) return;
      final next = _watched.entries
          .where((e) => !e.value.ready && !e.value.stalled)
          .map((e) => e.key)
          .firstOrNull;
      if (next == null) break;
      await _hydrate(next);
    }
    if (_closed || _generation != generation) return;
    _released = true;
    connection.releaseGeneration(generation);
    _emit(const OpenCodeConnectionUpdated(ConnectionKind.live));
    for (final MapEntry(key: ref, value: watch) in _watched.entries.toList()) {
      if (watch.dirty) {
        final isRepair = watch.dirtyIsRepair;
        watch
          ..dirty = false
          ..dirtyIsRepair = false;
        if (isRepair) {
          _repair(ref);
        } else {
          _refresh(ref);
        }
      }
    }
  }

  /// Hydrates one session with bounded retries; stale results are dropped.
  Future<void> _hydrate(SessionRef ref) async {
    final watch = _watched[ref];
    final generation = _generation;
    if (watch == null || generation == null || watch.hydrating) return;
    watch
      ..hydrating = true
      ..shellsRefreshInvalidated = true
      ..shellsCancellation?.cancel()
      // A re-hydration replaces the window; an older page read before it
      // would land on the new one.
      ..olderCancellation?.cancel();
    try {
      for (var attempt = 1; ; attempt++) {
        final cancellation = RequestCancellation();
        watch.cancellation = cancellation;
        final readStart = _position(_seq);
        // A shared store may have evicted it; watching keeps it open.
        if (store.peek(ref) == null) store.open(ref);
        store.startHydration(
          ref,
          generation: '$generation',
          readStart: readStart,
        );
        try {
          List<SessionSummary>? childSummaries;
          if (observeChildren) {
            // Installed before the children's pending reads, so frames that
            // arrive meanwhile are held and replayed in order.
            try {
              childSummaries = await reader.listChildSummaries(
                ref,
                cancellation: cancellation,
              );
            } on OpenCodeSessionReadException catch (error) {
              if (error.failure == OpenCodeSessionReadFailure.cancelled) {
                rethrow;
              }
              // Failure to discover children does not make the parent unreadable.
              // Refresh followed records individually instead of losing their outcomes.
              childSummaries = const [];
            }
            if (!_current(ref, watch, generation) || watch.stalled) return;
            _reconcileChildren(ref, childSummaries.map((s) => s.info.ref));
          }
          final followed = observeChildren
              ? Set<SessionRef>.of(_children[ref] ?? const <SessionRef>{})
              : const <SessionRef>{};
          final snapshot = await reader.hydrateSession(
            ref,
            hydrationGeneration: '$generation',
            readStart: readStart,
            sourceVersion: sourceVersion,
            historyLimit: historyPageLimit,
            now: _now,
            cancellation: cancellation,
            children: followed,
            childSummaries: childSummaries,
            residentInteractions: store.read(ref)?.interactions ?? const [],
            observeShells: observeShells,
            residentShells: store.read(ref)?.shells ?? const [],
            knownShellLocations: Map.of(_shellLocations),
            onShellLocations: _recordShellLocations,
          );
          if (!_current(ref, watch, generation) || watch.stalled) return;
          final priorState = store.read(ref);
          final reconciled = openCodeReconcileTailSnapshot(
            priorState,
            snapshot,
          );
          final result = store.applySnapshot(ref, reconciled.snapshot);
          // Evicted by another user of a shared store during the read: the
          // snapshot was not stored, so read again into a reopened state.
          if (result.effects.any(
            (e) => e is Rehydrate && e.reason == 'sessionNotOpen',
          )) {
            if (attempt < maxHydrationAttempts) continue;
            _setAside(ref, watch);
            return;
          }
          _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
          watch
            ..ready = true
            ..stalled = false;
          if (reconciled.preservedPrefix) {
            watch.oldestCovered ??= priorState?.timeline.firstOrNull?.id;
          } else {
            watch
              ..oldestCovered = snapshot.timeline?.values.firstOrNull?.id
              ..trimmed = false;
          }
          if (snapshot.shells != null) watch.shellsRetried = false;
          _noteTrim(ref, watch);
          final held = List.of(watch.held);
          watch.held.clear();
          final heldTerminals = List.of(watch.heldShellTerminals);
          watch.heldShellTerminals.clear();
          // Replay both held queues in strict ascending seq order so shell
          // exits/deletions interleaved with session frames are never dropped
          // as out-of-order by the reducer.
          var hIdx = 0;
          var tIdx = 0;
          while (hIdx < held.length || tIdx < heldTerminals.length) {
            if (!_current(ref, watch, generation)) return;
            final takeHeld =
                tIdx >= heldTerminals.length ||
                (hIdx < held.length && held[hIdx].$1 <= heldTerminals[tIdx].$1);
            if (takeHeld) {
              final (seq, value, child) = held[hIdx++];
              child == null
                  ? _apply(ref, value, seq)
                  : _applyChild(ref, child, value, seq);
            } else {
              final (seq, value, shellId) = heldTerminals[tIdx++];
              if (store.read(ref)?.shells.any((s) => s.id == shellId) ??
                  false) {
                _apply(ref, value, seq);
                if (value['type'] == 'shell.deleted') {
                  _shellLocations.remove(shellId);
                }
              }
            }
          }
          if (observeShells &&
              snapshot.shells == null &&
              !watch.shellsRetried) {
            watch.shellsRetried = true;
            unawaited(_retryShellsOnce(ref, watch, generation));
          }
          final current = store.read(ref);
          if (current != null && followed.isNotEmpty) {
            final resident = {
              for (final work in current.work)
                if (work.parent == ref && work.child != null) work.child!,
              for (final request in current.interactions)
                if (request.owner case SessionOwner(
                  :final session,
                  :final origin,
                ))
                  if (origin == ref) session,
            };
            // A missing record frees its slot only after newer events replay.
            // Children adopted after this read began belong to the next repair.
            _children[ref]?.removeWhere(
              (child) => followed.contains(child) && !resident.contains(child),
            );
          }
          final hadRepairEffects = openCodeEffectsRequestRepair(result.effects);
          _handle(ref, result.effects);
          if (!hadRepairEffects && !watch.dirtyIsRepair && !watch.stalled) {
            watch.lastHealthyHydrationAt ??= _now();
          }
          return;
        } on OpenCodeSessionReadException catch (error) {
          if (!_current(ref, watch, generation) ||
              watch.stalled ||
              error.failure == OpenCodeSessionReadFailure.cancelled) {
            return;
          }
          if (error.failure == OpenCodeSessionReadFailure.notFound) {
            _evict(ref);
            return;
          }
          if (_retryable.contains(error.failure) &&
              attempt < maxHydrationAttempts) {
            await _delay(Duration(seconds: 1 << (attempt - 1)));
            if (!_current(ref, watch, generation) || watch.stalled) return;
            continue;
          }
          _setAside(ref, watch);
          return;
        }
      }
    } finally {
      watch.hydrating = false;
      watch.cancellation = null;
      if (watch.dirty && _released && _current(ref, watch, generation)) {
        final isRepair = watch.dirtyIsRepair;
        watch
          ..dirty = false
          ..dirtyIsRepair = false;
        if (isRepair) {
          _repair(ref);
        } else {
          _refresh(ref);
        }
      }
    }
  }

  bool _current(SessionRef ref, OpenCodeWatch watch, int generation) =>
      !_closed && _generation == generation && identical(_watched[ref], watch);

  Future<void> _retryShellsOnce(
    SessionRef ref,
    OpenCodeWatch watch,
    int generation,
  ) async {
    if (_customDelay != null) {
      await _customDelay(const Duration(seconds: 1));
      if (!_current(ref, watch, generation) || watch.stalled) return;
      await refreshShells(ref);
      return;
    }
    watch.shellsRetryTimer?.cancel();
    watch.shellsRetryTimer = Timer(const Duration(seconds: 1), () {
      watch.shellsRetryTimer = null;
      if (!_current(ref, watch, generation) || watch.stalled) return;
      unawaited(refreshShells(ref));
    });
  }

  void _setAside(SessionRef ref, OpenCodeWatch watch) {
    watch.cancellation?.cancel();
    watch.olderCancellation?.cancel();
    watch.shellsCancellation?.cancel();
    watch.shellsRetryTimer?.cancel();
    watch
      ..ready = false
      ..stalled = true
      ..held.clear()
      ..heldShellTerminals.clear();
    final state = store.disconnected(ref);
    if (state != null) _emit(OpenCodeSessionUpdated(ref, state, const []));
    _emit(
      OpenCodeConnectionUpdated(
        ConnectionKind.degraded,
        failure: OpenCodeStreamFailure.hydrationExhausted,
        session: ref,
      ),
    );
  }

  void _evict(SessionRef ref) {
    _children.remove(ref);
    final watch = _watched.remove(ref);
    watch?.cancellation?.cancel();
    watch?.olderCancellation?.cancel();
    watch?.shellsCancellation?.cancel();
    watch?.shellsRetryTimer?.cancel();
    watch?.heldShellTerminals.clear();
    store.close(ref);
    _emit(OpenCodeSessionEvicted(ref));
  }

  /// One coalesced routine re-hydration (child adoption/deletion or explicit
  /// refresh) that never consumes the error repair budget.
  void _refresh(SessionRef ref) {
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    if (watch.hydrating || !_released) {
      watch.dirty = true;
      return;
    }
    unawaited(_hydrate(ref));
  }

  /// One coalesced, bounded error re-hydration on the current generation.
  /// Restores the repair budget after [openCodeRepairCooldown] of healthy
  /// operation so long-lived sessions survive isolated hiccups while rapid
  /// failure loops still trip [maxRepairs].
  void _repair(SessionRef ref) {
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    if (watch.hydrating || !_released) {
      watch
        ..dirty = true
        ..dirtyIsRepair = true;
      return;
    }
    final healthyAt = watch.lastHealthyHydrationAt;
    if (watch.repairs > 0 &&
        healthyAt != null &&
        _now().difference(healthyAt) >= openCodeRepairCooldown) {
      watch.repairs = 0;
    }
    watch.lastHealthyHydrationAt = null;
    if (watch.repairs >= maxRepairs) {
      _setAside(ref, watch);
      return;
    }
    watch.repairs++;
    unawaited(_hydrate(ref));
  }

  void _onFrame(SseFrame frame) {
    final seq = ++_seq;
    final Object? value;
    try {
      value = jsonDecode(frame.data);
    } on FormatException {
      return;
    }
    if (value is! Map<String, Object?>) return;
    // The catalog observes the lifecycle of every session, watched or not.
    // The signal carries only the kind, and it is emitted before every
    // filter, so a frame the child routing consumes or the watch filter
    // drops still reaches the list.
    _emitCatalogChange(value['type']);
    _emitLocationCatalog(value);
    if (observeShells && isOpenCodeShellLifecycleEvent(value['type'])) {
      _routeShell(value, seq);
      return;
    }
    final data = value['data'];
    Object? session;
    if (data is Map<String, Object?>) {
      final form = data['form'];
      session =
          data['sessionID'] ??
          (form is Map<String, Object?> ? form['sessionID'] : null);
    }
    if (session is! String || session.isEmpty) return;
    if (session == 'global') {
      final type = value['type'];
      if (type is String && type.startsWith('form.')) {
        for (final entry in _watched.entries) {
          if (!entry.value.stalled) {
            _hold(entry.key, entry.value, value, seq, null);
          }
        }
      }
      return;
    }
    final ref = SessionRef(harness.host, harness.harness, session);
    if (observeChildren && data is Map<String, Object?>) {
      _routeChild(ref, data, value, seq);
    }
    final watch = _watched[ref];
    if (watch == null || watch.stalled) return;
    _hold(ref, watch, value, seq, null);
  }

  /// Routes OpenCode ephemeral `shell.*` events (which omit top-level
  /// `data.sessionID`) to the matching watched session(s), validating IDs
  /// upfront and isolating pre-hydration terminal events from [maxHeldFrames].
  void _routeShell(Map<String, Object?> value, int seq) {
    final type = value['type'];
    final data = value['data'];
    if (data is! Map<String, Object?>) return;
    if (type == 'shell.created') {
      final info = data['info'];
      if (info is! Map<String, Object?>) return;
      final String shellId;
      try {
        shellId = openCodeShellId(info['id']);
      } on Object {
        return;
      }
      final sessionId = openCodeShellInfoSessionId(info);
      if (sessionId == null) return;
      final ref = SessionRef(harness.host, harness.harness, sessionId);
      final watch = _watched[ref];
      if (watch == null || watch.stalled) return;
      final dir = openCodeShellFrameDirectory(value);
      if (dir != null) _recordShellLocation(shellId, dir);
      _hold(ref, watch, value, seq, null);
      return;
    }
    final String shellId;
    try {
      shellId = openCodeShellId(data['id']);
    } on Object {
      return;
    }
    for (final entry in _watched.entries) {
      final watch = entry.value;
      if (watch.stalled) continue;
      if (!watch.ready) {
        if (watch.heldShellTerminals.length >= _maxHeldShellTerminals) {
          watch.heldShellTerminals.removeAt(0);
        }
        watch.heldShellTerminals.add((seq, value, shellId));
      } else if (store.read(entry.key)?.shells.any((s) => s.id == shellId) ??
          false) {
        _apply(entry.key, value, seq);
        if (type == 'shell.deleted') _shellLocations.remove(shellId);
      } else if (watch.shellsRefreshing) {
        if (watch.heldShellTerminals.length >= _maxHeldShellTerminals) {
          watch.heldShellTerminals.removeAt(0);
        }
        watch.heldShellTerminals.add((seq, value, shellId));
      }
    }
  }

  void _hold(
    SessionRef ref,
    OpenCodeWatch watch,
    Map<String, Object?> value,
    int seq,
    SessionRef? child,
  ) {
    if (!watch.ready) {
      if (child == null && openCodeIsNoOpToolInputFrame(value)) {
        return;
      }
      if (watch.held.length >= maxHeldFrames) {
        _setAside(ref, watch);
        return;
      }
      watch.held.add((seq, value, child));
      return;
    }
    child == null
        ? _apply(ref, value, seq)
        : _applyChild(ref, child, value, seq);
  }

  /// Adopts a child created under a watched parent and forwards a child's
  /// human-request frames to every watched parent that follows it.
  void _routeChild(
    SessionRef ref,
    Map<String, Object?> data,
    Map<String, Object?> value,
    int seq,
  ) {
    final type = value['type'];
    if (type == 'session.created') {
      final parentId = data['parentID'];
      if (parentId is! String || parentId.isEmpty) return;
      try {
        openCodeSessionId(parentId);
        openCodeSessionId(ref.nativeId);
      } on Object {
        return;
      }
      final parent = SessionRef(harness.host, harness.harness, parentId);
      if (_watched.containsKey(parent) && _adopt(parent, [ref])) {
        _refresh(parent);
      }
      return;
    }
    if (type == 'session.deleted') {
      for (final MapEntry(key: parent, value: known)
          in _children.entries.toList()) {
        if (!known.remove(ref)) continue;
        final state = store.read(parent);
        // Even an empty work set needs the deletion's read barrier: a snapshot
        // already in flight may still carry the child it read before deletion.
        if (state != null) {
          final result = store.apply(
            parent,
            WorkChanged(
              meta: EventMeta(
                owner: SessionOwner(parent),
                position: _position(seq),
                receivedAt: _now(),
                source: SourceProvenance(
                  harness: harness,
                  version: sourceVersion,
                  nativeType: 'session.deleted',
                ),
              ),
              items: [
                for (final work in state.work)
                  if (work.child != ref) work,
              ],
            ),
          );
          _emit(OpenCodeSessionUpdated(parent, result.state, result.effects));
          _handle(parent, result.effects);
        }
        final owned =
            state != null &&
            (state.interactions.any(
                  (r) =>
                      r.owner is SessionOwner &&
                      (r.owner as SessionOwner).session == ref,
                ) ||
                state.work.any((w) => w.child == ref));
        // A snapshot still in flight, first or repair, may have read the
        // child as running.
        final watch = _watched[parent];
        final reading = watch != null && (!watch.ready || watch.hydrating);
        if (owned || reading) _refresh(parent);
      }
      return;
    }
    if (type != 'permission.asked' &&
        type != 'permission.replied' &&
        type != 'form.created' &&
        type != 'form.replied' &&
        type != 'form.cancelled' &&
        !(type is String && type.startsWith('session.execution.'))) {
      return;
    }
    for (final MapEntry(key: parent, value: known)
        in _children.entries.toList()) {
      if (!known.contains(ref)) continue;
      final watch = _watched[parent];
      if (watch == null || watch.stalled) continue;
      _hold(parent, watch, value, seq, ref);
    }
  }

  void _applyChild(
    SessionRef parent,
    SessionRef child,
    Map<String, Object?> value,
    int seq,
  ) {
    final state = store.read(parent);
    if (state == null) {
      _watched[parent]?.ready = false;
      _repair(parent);
      return;
    }
    final SessionEvent? event;
    try {
      final type = value['type'];
      event = type is String && type.startsWith('session.execution.')
          ? projectOpenCodeChildExecutionEvent(
              value,
              state,
              child: child,
              sourceVersion: sourceVersion,
              position: _position(seq),
              receivedAt: _now(),
            )
          : projectOpenCodeInteractionEvent(
              value,
              state,
              sourceVersion: sourceVersion,
              position: _position(seq),
              receivedAt: _now(),
              child: child,
            );
    } on Exception {
      _repair(parent);
      return;
    }
    if (event == null) return;
    final result = store.apply(parent, event);
    _emit(OpenCodeSessionUpdated(parent, result.state, result.effects));
    _handle(parent, result.effects);
  }

  void _apply(SessionRef ref, Map<String, Object?> value, int seq) {
    final type = value['type'];
    if (type == 'session.permissions') {
      try {
        final rules = projectOpenCodeSessionPermissions(
          value,
          ref,
          sourceVersion: sourceVersion,
        );
        _emit(OpenCodeSessionRulesUpdated(ref, rules));
      } on Exception {
        _repair(ref);
      }
      return;
    }
    final state = store.read(ref);
    if (state == null) {
      // Lost from a shared store: never drop frames silently, re-read.
      _watched[ref]?.ready = false;
      _repair(ref);
      return;
    }
    if (observeShells && isOpenCodeShellLifecycleEvent(type)) {
      final ShellChanged? shellEvent;
      try {
        shellEvent = projectOpenCodeShellLifecycleEvent(
          value,
          state,
          sourceVersion: sourceVersion,
          position: _position(seq),
          receivedAt: _now(),
        );
      } on Object {
        _repair(ref);
        return;
      }
      if (shellEvent == null) return;
      final watch = _watched[ref];
      if (watch != null && watch.shellsRefreshing) {
        final data = value['data'];
        if (data is Map<String, Object?>) {
          final rawId = type == 'shell.created'
              ? (data['info'] is Map<String, Object?>
                    ? (data['info']! as Map<String, Object?>)['id']
                    : null)
              : data['id'];
          if (rawId is String && rawId.isNotEmpty) {
            watch.mutatedShellIdsWhileRefreshing.add(rawId);
          }
        }
      }
      final result = store.apply(ref, shellEvent);
      _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
      _handle(ref, result.effects);
      return;
    }
    final List<SessionEvent> events;
    try {
      events = projectOpenCodeEvent(
        value,
        state,
        sourceVersion: sourceVersion,
        position: _position(seq),
        receivedAt: _now(),
        onInlineMedia: reader.onInlineMedia,
      );
    } on Exception {
      // A rejected frame is not guessed around: the session is re-read.
      _repair(ref);
      return;
    }
    var frameRequestedRepair = false;
    for (final event in events) {
      final result = store.apply(ref, event);
      // Before the update is seen, so a removal that empties a trimmed
      // window cannot hide the trim.
      if (_watched[ref] case final watch?) _noteTrim(ref, watch);
      _emit(OpenCodeSessionUpdated(ref, result.state, result.effects));
      if (openCodeEffectsRequestRepair(result.effects)) {
        frameRequestedRepair = true;
      }
      _handle(ref, result.effects);
    }
    // Mirror the official client (`data.ts`): if a terminal execution event
    // settles the turn while any tool call is still streaming or pending,
    // resync the session so no tool stays stuck running. Otherwise, a clean
    // settled turn restores the session's repair budget.
    if (openCodeIsTurnSettlementFrame(value)) {
      final after = store.read(ref);
      final stuckTool =
          after != null &&
          after.timeline.any(
            (item) =>
                item is ToolCall &&
                (item.status.known == ItemStatus.streaming ||
                    item.status.known == ItemStatus.pending),
          );
      if (stuckTool) {
        _repair(ref);
      } else if (!frameRequestedRepair) {
        final watch = _watched[ref];
        if (watch != null &&
            watch.ready &&
            !watch.hydrating &&
            !watch.dirty &&
            watch.lastHealthyHydrationAt != null) {
          watch.repairs = 0;
        }
      }
    }
  }

  /// At most one repair per reduction, however many effects ask for it.
  void _handle(SessionRef ref, List<ReducerEffect> effects) {
    var repair = false;
    for (final effect in effects) {
      switch (effect) {
        case Rehydrate(:final reason):
          if (reason == 'sessionNotOpen') continue;
          if (reason == 'streamGenerationMismatch' ||
              reason == 'snapshotGenerationMismatch') {
            if (!_woke) {
              _woke = true;
              connection.wake();
            }
            continue;
          }
          repair = true;
        case Refetch():
          repair = true;
        case Notify():
          break;
      }
    }
    if (repair) _repair(ref);
  }

  void _onDisconnected(TransportException failure, bool terminal) {
    for (final MapEntry(key: ref, value: watch) in _watched.entries) {
      watch
        ..cancellation?.cancel()
        ..olderCancellation?.cancel()
        ..shellsCancellation?.cancel()
        ..shellsRetryTimer?.cancel()
        ..shellsRefreshInvalidated = true
        ..ready = false
        ..held.clear()
        ..heldShellTerminals.clear()
        ..mutatedShellIdsWhileRefreshing.clear();
      final state = store.disconnected(ref);
      if (state != null) _emit(OpenCodeSessionUpdated(ref, state, const []));
    }
    // Hydration and release of this generation are abandoned with it.
    _generation = null;
    _released = false;
    if (!terminal) {
      _emit(const OpenCodeConnectionUpdated(ConnectionKind.reconnecting));
      return;
    }
    final status = failure.statusCode;
    _emit(
      OpenCodeConnectionUpdated(
        status == 401 || status == 403
            ? ConnectionKind.authRequired
            : ConnectionKind.incompatible,
        failure: OpenCodeStreamFailure.terminal,
      ),
    );
  }
}
