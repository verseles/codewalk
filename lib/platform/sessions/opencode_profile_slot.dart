import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_catalog_changes.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';
import 'opencode_live_handle.dart';
import 'opencode_selection_lane.dart';
import 'prompt_outbox_store.dart';
import 'unrestricted_ownership_store.dart';

/// The per-profile runtime of one OpenCode 2.0.22 endpoint: the
/// authenticated transport, the session reader, the single global event
/// stream and everything a live session or the session catalog needs from it.
/// It lives in its own file so the live directory stays readable and below the
/// architecture guard's file-size limit.
final class OpenCodeProfileSlot {
  OpenCodeProfileSlot(
    this.profile,
    this.credential,
    this.harness,
    this._now,
    this._release, {
    required this.payloads,
    required this.queue,
    required this.ids,
    required this.answered,
    required this.permissionModes,
    required this.unrestrictedOwnership,
    required this.commandIds,
    required this.isCurrentBinding,
  }) : _transport = IoEndpointHttpTransport(
         endpoint: profile.endpoint,
         headers: basicEndpointHeaders(
           endpoint: profile.endpoint,
           username: 'opencode',
           secret: () => credential.secret,
         ),
       ) {
    _reader = OpenCodeSessionReader(
      _transport,
      harness: harness,
      maxHistoryItems: 500,
    );
  }

  final EndpointProfile profile;
  final EndpointCredential credential;
  final bool Function() isCurrentBinding;
  final lifetimeCancellation = RequestCancellation();
  final HarnessRef harness;
  final DateTime Function() _now;
  final void Function() _release;
  final PayloadStore? payloads;
  final KeySerialExecutor queue;
  final OpenCodeMessageIds ids;
  final PermissionModePolicy? permissionModes;

  /// CodeWalk's own Unrestricted insertions; without it the action is absent.
  final UnrestrictedOwnershipLedger? unrestrictedOwnership;
  late final _unrestrictedBinding = unrestrictedBindingFor(profile);
  int _unrestrictedEpoch = 0;
  final CommandId Function() commandIds;
  PromptOutbox? outbox;
  OpenCodeInterruptClient? _interrupt;
  OpenCodePermissionReplyClient? _replies;
  OpenCodeFormReplyClient? _forms;
  OpenCodeSessionRulesClient? _rules;
  OpenCodeSelectionLane? _selection;
  final _stops = <SessionRef, _StopRequest>{};
  final _older = <SessionRef, SessionOlderHistoryState>{};
  final _unrestricted = <SessionRef, _UnrestrictedEntry>{};
  // Keyed by session and native id: one slot multiplexes several sessions, and
  // ids are only unique inside their own session.
  final _replyStates = <String, _ReplyRequest>{};

  /// One canonical fence for every reply, manual or automatic: a deliberate
  /// human decision wins and a repeated frame never answers the same
  /// session+request twice. The directory owns the set so it survives slot
  /// generations; only the automatic path consults it, so a manual retry
  /// stays possible.
  final Set<String> answered;
  final IoEndpointHttpTransport _transport;
  late final OpenCodeSessionReader _reader;
  final _store = SessionStore(maxSessions: 8);
  IoSseRecovery? _connection;
  OpenCodeStreamOwner? _owner;
  StreamSubscription<OpenCodeStreamUpdate>? _subscription;
  Future<void>? _ready;
  Future<void>? _closing;
  String? version;
  SessionLivePhase _phase = SessionLivePhase.probing;
  final handles = <OpenCodeLiveHandle>{};
  // The catalog feeds holding this profile's stream open.
  int _catalogLeases = 0;
  final _leases = <_CatalogLease>[];
  final _views = <SessionRef, SessionLiveView>{};

  Future<void> ready() => _ready ??= _probe();

  Future<void> _probe() async {
    final assessment = await OpenCodeEndpointProbe(_transport).detect();
    if (_closing != null || !isCurrentBinding()) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    switch (assessment.status) {
      case EndpointStatus.authenticationRequired:
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      case EndpointStatus.unreachable:
        throw const SessionLiveException(SessionLiveFailure.timeout);
      case EndpointStatus.cancelled:
        throw const SessionLiveException(SessionLiveFailure.cancelled);
      default:
        break;
    }
    final observed = assessment.version;
    if (!assessment.canUse || observed == null) {
      throw const SessionLiveException(SessionLiveFailure.unavailable);
    }
    // The stream reader is verified against 2.0.22 only; fail closed before
    // opening the stream instead of hydrating an unverified version.
    if (OpenCodeCompatibility.parse(observed)?.toString() != '2.0.22') {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    version = observed;
    _interrupt = OpenCodeInterruptClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
    );
    _replies = OpenCodePermissionReplyClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
    );
    _forms = OpenCodeFormReplyClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
    );
    _rules = OpenCodeSessionRulesClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
    );
    _selection = OpenCodeSelectionLane(
      reader: _reader,
      client: OpenCodeSessionLifecycleClient(
        _transport,
        harness: harness,
        connectedVersion: observed,
      ),
      view: view,
      publish: (ref) => _publish(ref, view(ref)),
    );
    if (payloads case final store?) {
      outbox = OpenCodePromptOutbox(
        store: store,
        client: OpenCodePromptClient(
          _transport,
          harness: harness,
          connectedVersion: observed,
        ),
        reader: _reader,
        ids: ids,
        now: _now,
        queue: queue,
        profile: profile,
        isCurrentBinding: () => !isClosed && isCurrentBinding(),
        cancellation: lifetimeCancellation,
      );
    }
    final connection = IoSseRecovery(
      _transport,
      'api/event',
      connectedWhen: openCodeServerConnected,
    );
    final owner = OpenCodeStreamOwner(
      connection: connection,
      reader: _reader,
      store: _store,
      harness: harness,
      sourceVersion: observed,
      observeChildren: true,
    );
    _connection = connection;
    _owner = owner;
    _phase = SessionLivePhase.connecting;
    _subscription = owner.updates.listen(_onUpdate);
    owner.start();
  }

  /// Reconnects the stream now; one still probing has nothing to wake, and a
  /// terminal stream stays stopped until the user retries.
  void wake() {
    if (!_activeBinding ||
        _phase == SessionLivePhase.authRequired ||
        _phase == SessionLivePhase.incompatible) {
      return;
    }
    _connection?.wake();
  }

  /// A feed of the session lifecycle of every session of this profile.
  ///
  /// The endpoint keeps exactly one stream: the feed only listens to the
  /// owner's payload-free catalog signal, and this profile stays open while
  /// the catalog holds it.
  SessionCatalogChanges catalogLease() {
    final owner = _owner;
    if (owner == null || _closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    _catalogLeases++;
    final lease = _CatalogLease(this, owner);
    _leases.add(lease);
    return lease;
  }

  /// Releases one catalog feed; the profile closes with its last holder.
  void _releaseCatalog(_CatalogLease lease) {
    _leases.remove(lease);
    if (_catalogLeases == 0) return;
    _catalogLeases--;
    if (handles.isEmpty && _catalogLeases == 0) {
      _release();
      unawaited(close());
    }
  }

  OpenCodeLiveHandle lease(SessionRef session) {
    final owner = _owner;
    if (owner == null || _closing != null) {
      throw const SessionLiveException(SessionLiveFailure.cancelled);
    }
    final previous = _views[session];
    // A retry re-hydrates a session set aside; its other screens follow.
    if (previous?.phase == SessionLivePhase.degraded) owner.unwatch(session);
    if (!owner.watch(session)) {
      throw const SessionLiveException(SessionLiveFailure.capacity);
    }
    if (previous == null || previous.phase == SessionLivePhase.degraded) {
      final state = _store.peek(session);
      _publish(
        session,
        SessionLiveView(
          session: session,
          // A session added to a live stream hydrates on its own first.
          phase: _phase == SessionLivePhase.live && !_isLive(state)
              ? SessionLivePhase.hydrating
              : _phase,
          version: version,
          lastSyncedAt: previous?.lastSyncedAt,
          stale: previous?.lastSyncedAt != null,
          // Other screens keep the last content while it re-hydrates.
          state: previous?.state ?? state,
        ),
      );
    }
    if (supportsUnrestricted) {
      _unrestricted.putIfAbsent(session, _UnrestrictedEntry.new);
    }
    _selection?.open(session);
    final handle = OpenCodeLiveHandle(this, session);
    handles.add(handle);
    // A session that is already live reads its rules and catalog now.
    _considerUnrestrictedRead(session, view(session));
    _selection?.consider(session, view(session));
    return handle;
  }

  static bool _isLive(SessionState? state) =>
      state?.connection.kind.known == ConnectionKind.live;

  SessionLiveView view(SessionRef session) =>
      _views[session] ??
      SessionLiveView(session: session, phase: SessionLivePhase.closed);

  void _publish(SessionRef session, SessionLiveView view) {
    _pruneReplies(session, view);
    final stop = _stops[session];
    final execution = view.state?.execution;
    if (stop != null &&
        execution != null &&
        view.phase == SessionLivePhase.live &&
        !view.stale) {
      if (execution.kind.known == ExecutionKind.idle) {
        stop.settled = true;
      }
    }
    // Hydration reconstructs lastOutcome objects even for the same running
    // execution, and a retry wait or a pending resume is still that execution.
    // Only an observed idle state proves settlement. Latch it if it beats
    // HTTP, and clear an uncertain wait too when it arrives late.
    if (stop != null &&
        stop.settled &&
        !stop.inFlight &&
        (stop.state.phase == SessionStopPhase.requested ||
            stop.state.phase == SessionStopPhase.unconfirmed)) {
      stop.timer?.cancel();
      stop.state = const SessionStopState();
    }
    _views[session] = view;
    for (final handle in handles.toList()) {
      if (handle.session == session) handle.emit(view);
    }
    _considerUnrestrictedRead(session, view);
    _selection?.consider(session, view);
  }

  /// The model and agent of the watched sessions; absent until the endpoint
  /// is verified and after the profile closes.
  OpenCodeSelectionLane? get selection => _activeBinding ? _selection : null;

  SessionStopState stopState(SessionRef ref) =>
      _stops[ref]?.state ?? const SessionStopState();

  bool canStop(SessionRef ref) {
    final current = view(ref);
    return _activeBinding &&
        _interrupt != null &&
        !stopState(ref).busy &&
        _stops[ref]?.inFlight != true &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        switch (current.state?.execution?.kind.known) {
          ExecutionKind.running || ExecutionKind.retrying => true,
          _ => false,
        };
  }

  Future<void> stop(SessionRef ref, CommandId id) async {
    final client = _interrupt;
    if (client == null || !canStop(ref)) return;
    _stops[ref]?.dispose();
    final request = _StopRequest();
    _stops[ref] = request;
    _publish(ref, view(ref));
    final attempt = await client.interrupt(
      session: ref,
      id: id,
      cancellation: request.cancellation,
    );
    if (isClosed || !identical(_stops[ref], request)) return;
    request.inFlight = false;
    final receipt = attempt.receipt;
    final phase = switch (receipt.state.known) {
      ReceiptState.accepted when attempt.interrupted == false =>
        SessionStopPhase.idle,
      ReceiptState.accepted when request.settled => SessionStopPhase.ready,
      ReceiptState.accepted => SessionStopPhase.requested,
      ReceiptState.rejected ||
      ReceiptState.unavailable => SessionStopPhase.refused,
      _ => SessionStopPhase.unconfirmed,
    };
    request.state = SessionStopState(phase: phase, receipt: receipt);
    if (phase == SessionStopPhase.requested) {
      // The request was accepted, not settled. Bound the local waiting state
      // without inferring success or automatically repeating the mutation.
      request.timer = Timer(const Duration(seconds: 30), () {
        if (isClosed || !identical(_stops[ref], request)) return;
        request.state = SessionStopState(
          phase: SessionStopPhase.unconfirmed,
          receipt: receipt,
        );
        _publish(ref, view(ref));
      });
    }
    _publish(ref, view(ref));
  }

  SessionOlderHistoryState olderHistory(SessionRef ref) {
    final local = _older[ref];
    return SessionOlderHistoryState(
      loading: local?.loading ?? false,
      failure: local?.failure,
      trimmed: _owner?.olderHistoryTrimmed(ref) ?? false,
    );
  }

  bool canLoadOlderHistory(SessionRef ref) {
    final current = view(ref);
    return _activeBinding &&
        _older[ref]?.loading != true &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        (_owner?.canLoadOlderHistory(ref) ?? false);
  }

  /// One older page through the stream owner; its window update reaches the
  /// leases as any other session update. A failure keeps the window.
  Future<void> loadOlderHistory(SessionRef ref) async {
    final owner = _owner;
    if (owner == null || !canLoadOlderHistory(ref)) return;
    _older[ref] = const SessionOlderHistoryState(loading: true);
    _publish(ref, view(ref));
    // Any other error is a defect: it still ends the read, as unavailable,
    // so the pill never spins forever, and it is not swallowed.
    SessionLiveFailure? failure = SessionLiveFailure.unavailable;
    try {
      await owner.loadOlderHistory(ref);
      failure = null;
    } on OpenCodeSessionReadException catch (error) {
      failure = switch (error.failure) {
        OpenCodeSessionReadFailure.authenticationRequired =>
          SessionLiveFailure.authenticationRequired,
        OpenCodeSessionReadFailure.notFound => SessionLiveFailure.notFound,
        OpenCodeSessionReadFailure.rateLimited =>
          SessionLiveFailure.rateLimited,
        OpenCodeSessionReadFailure.timeout => SessionLiveFailure.timeout,
        OpenCodeSessionReadFailure.connection => SessionLiveFailure.connection,
        OpenCodeSessionReadFailure.unavailable =>
          SessionLiveFailure.unavailable,
        OpenCodeSessionReadFailure.cancelled ||
        OpenCodeSessionReadFailure.closed => SessionLiveFailure.cancelled,
        _ => SessionLiveFailure.incompatibleResponse,
      };
    } finally {
      // The last lease of this session may have closed during the read.
      if (!isClosed && _views.containsKey(ref)) {
        _older[ref] = SessionOlderHistoryState(failure: failure);
        _publish(ref, view(ref));
      }
    }
  }

  /// Unrestricted is the session's own server rule (ADR-059 §7), separate
  /// from the local Ask / Allow all mode. It exists only with an ownership
  /// ledger, and nothing here runs from the automatic responder.
  bool get supportsUnrestricted =>
      _activeBinding && _rules != null && unrestrictedOwnership != null;

  SessionUnrestrictedState unrestrictedState(SessionRef ref) =>
      _unrestricted[ref]?.state ?? const SessionUnrestrictedState();

  bool _unrestrictedReady(SessionRef ref) {
    final ledger = unrestrictedOwnership;
    final entry = _unrestricted[ref];
    final current = view(ref);
    return supportsUnrestricted &&
        ledger != null &&
        ledger.loaded &&
        !ledger.unreadable &&
        entry != null &&
        !entry.state.busy &&
        current.phase == SessionLivePhase.live &&
        !current.stale;
  }

  bool canEnableUnrestricted(SessionRef ref) =>
      _unrestrictedReady(ref) &&
      unrestrictedState(ref).phase == SessionUnrestrictedPhase.off;

  bool canDisableUnrestricted(SessionRef ref) =>
      _unrestrictedReady(ref) &&
      unrestrictedState(ref).phase == SessionUnrestrictedPhase.on;

  bool canRefreshUnrestricted(SessionRef ref) => _unrestrictedReady(ref);

  /// Reads the rules once per live period: when a lease opens on a live
  /// session and again after every reconnect.
  void _considerUnrestrictedRead(SessionRef ref, SessionLiveView current) {
    final entry = _unrestricted[ref];
    if (entry == null || !supportsUnrestricted) return;
    if (current.phase != SessionLivePhase.live || current.stale) {
      // A read in flight may predate the reconnect, so read again after it.
      entry
        ..needsRead = true
        ..retried = false;
      return;
    }
    if (!entry.needsRead || entry.state.busy) return;
    entry.needsRead = false;
    unawaited(_automaticRead(ref, entry));
  }

  /// The read a live period starts with; a failure is retried once in the
  /// same period, then waits for a reconnect or an explicit refresh.
  Future<void> _automaticRead(SessionRef ref, _UnrestrictedEntry entry) async {
    await refreshUnrestricted(ref);
    if (!_currentUnrestricted(ref, entry) || entry.retried) return;
    if (entry.state.phase != SessionUnrestrictedPhase.unavailable) return;
    // An unreadable ledger stays unavailable however often the rules load.
    final ledger = unrestrictedOwnership;
    if (ledger == null || !ledger.loaded || ledger.unreadable) return;
    entry
      ..retried = true
      ..needsRead = true;
    _considerUnrestrictedRead(ref, view(ref));
  }

  Future<OpenCodeSessionRules?> _readRules(
    SessionRef ref,
    _UnrestrictedEntry entry,
  ) async {
    try {
      return await _reader.readSessionRules(
        ref,
        cancellation: entry.cancellation,
      );
    } on OpenCodeSessionReadException {
      return null;
    }
  }

  void _setUnrestricted(
    SessionRef ref,
    _UnrestrictedEntry entry,
    SessionUnrestrictedState state,
  ) {
    entry.state = state;
    _publish(ref, view(ref));
  }

  /// The binding's catalog became unknown: a read or write in flight never
  /// continues, even once the same binding is confirmed again.
  void suspendUnrestricted() => _unrestrictedEpoch++;

  bool _currentUnrestricted(SessionRef ref, _UnrestrictedEntry entry) =>
      _activeBinding &&
      identical(_unrestricted[ref], entry) &&
      entry.epoch == _unrestrictedEpoch;

  /// A read or write that lost its binding stops here and sends nothing more.
  /// A screen still attached keeps its last known state, no longer busy:
  /// nothing changed before a write, and a write already sent keeps its
  /// receipt, unconfirmed unless it was refused.
  void _stopUnrestricted(
    SessionRef ref,
    _UnrestrictedEntry entry, {
    bool write = false,
    CommandReceipt? receipt,
  }) {
    if (isClosed || !identical(_unrestricted[ref], entry)) return;
    final known = receipt?.state.known;
    final state = entry.state;
    _setUnrestricted(
      ref,
      entry,
      SessionUnrestrictedState(
        phase: state.phase,
        inEffect: state.inEffect,
        notice:
            known == ReceiptState.rejected ||
                known == ReceiptState.unavailable ||
                (receipt == null && write)
            ? SessionUnrestrictedNotice.refused
            : receipt == null
            ? SessionUnrestrictedNotice.none
            : SessionUnrestrictedNotice.unconfirmed,
        receipt: receipt,
      ),
    );
  }

  /// Classifies [rules] against the ledger and stores the record transition.
  /// A failed or unrecognized read keeps nothing writable, and keeps the last
  /// known "in effect" so an active rule is never hidden by a failed read.
  Future<void> _settleUnrestricted(
    SessionRef ref,
    _UnrestrictedEntry entry,
    OpenCodeSessionRules? rules, {
    SessionUnrestrictedNotice notice = SessionUnrestrictedNotice.none,
    CommandReceipt? receipt,
  }) async {
    final ledger = unrestrictedOwnership;
    if (rules == null ||
        !rules.recognized ||
        ledger == null ||
        !ledger.loaded ||
        ledger.unreadable) {
      _setUnrestricted(
        ref,
        entry,
        SessionUnrestrictedState(
          phase: SessionUnrestrictedPhase.unavailable,
          inEffect: rules != null && rules.recognized
              ? rules.endsWithWildcardAllow
              : entry.state.inEffect,
          notice: notice,
          receipt: receipt,
        ),
      );
      return;
    }
    final previous = ledger.recordFor(_unrestrictedBinding, ref);
    final reading = classifyUnrestricted(rules, previous);
    final next = reading.record;
    var stored = true;
    if (!_sameRecord(previous, next)) {
      // A failed transition leaves the older stage; it is reported, and the
      // next read classifies that stage again.
      bool current() => _currentUnrestricted(ref, entry);
      stored = next == null
          ? await ledger.remove(_unrestrictedBinding, ref, when: current)
          : await ledger.put(_unrestrictedBinding, ref, next, when: current);
    }
    if (!_currentUnrestricted(ref, entry)) {
      return _stopUnrestricted(ref, entry, receipt: receipt);
    }
    // CodeWalk could not record its own state. After an accepted write the
    // rules did change, so that is unconfirmed rather than refused.
    if (!stored && notice != SessionUnrestrictedNotice.unconfirmed) {
      notice = receipt?.state.known == ReceiptState.accepted
          ? SessionUnrestrictedNotice.unconfirmed
          : SessionUnrestrictedNotice.refused;
    }
    _setUnrestricted(
      ref,
      entry,
      SessionUnrestrictedState(
        phase: reading.phase,
        inEffect: rules.endsWithWildcardAllow,
        notice:
            reading.phase == SessionUnrestrictedPhase.conflict &&
                notice == SessionUnrestrictedNotice.none
            ? SessionUnrestrictedNotice.changedElsewhere
            : notice,
        receipt: receipt,
      ),
    );
  }

  static bool _sameRecord(UnrestrictedOwnership? a, UnrestrictedOwnership? b) =>
      a == null
      ? b == null
      : b != null &&
            a.stage == b.stage &&
            a.base == b.base &&
            a.owned == b.owned;

  void _markUnrestrictedBusy(SessionRef ref, _UnrestrictedEntry entry) {
    entry.epoch = _unrestrictedEpoch;
    final state = entry.state;
    _setUnrestricted(
      ref,
      entry,
      SessionUnrestrictedState(
        phase: state.phase,
        inEffect: state.inEffect,
        busy: true,
      ),
    );
  }

  /// Re-reads the rules without writing anything.
  Future<void> refreshUnrestricted(SessionRef ref) async {
    final entry = _unrestricted[ref];
    if (entry == null || !supportsUnrestricted || entry.state.busy) return;
    _markUnrestrictedBusy(ref, entry);
    final rules = await _readRules(ref, entry);
    if (!_currentUnrestricted(ref, entry)) return _stopUnrestricted(ref, entry);
    await _settleUnrestricted(ref, entry, rules);
  }

  /// Appends CodeWalk's allow-everything rule to a fresh read of the rules,
  /// after the record of that insertion is stored. One attempt; the result is
  /// confirmed by reading the rules again, never by the 204 alone.
  Future<void> enableUnrestricted(SessionRef ref, CommandId id) async {
    final client = _rules;
    final ledger = unrestrictedOwnership;
    final entry = _unrestricted[ref];
    if (client == null ||
        ledger == null ||
        entry == null ||
        !canEnableUnrestricted(ref)) {
      return;
    }
    bool current() => _currentUnrestricted(ref, entry);
    _markUnrestrictedBusy(ref, entry);
    final rules = await _readRules(ref, entry);
    if (!current()) return _stopUnrestricted(ref, entry, write: true);
    final record = ledger.recordFor(_unrestrictedBinding, ref);
    final fresh = rules != null && rules.recognized;
    // Only from a clean state: no wildcard yet, and no record other than an
    // unapplied insertion over these exact rules.
    if (!fresh ||
        rules.endsWithWildcardAllow ||
        (record != null &&
            (record.stage != UnrestrictedStage.applying ||
                unrestrictedFingerprint(rules) != record.base))) {
      // Nothing is written; a readable change is reported as such.
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: fresh
            ? SessionUnrestrictedNotice.changedElsewhere
            : SessionUnrestrictedNotice.none,
      );
    }
    // One more rule would no longer be readable, so CodeWalk could neither
    // show nor remove it.
    if (rules.rules.length >= OpenCodeSessionRules.maxRules) {
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: SessionUnrestrictedNotice.refused,
      );
    }
    final next = rules.withWildcardAllow();
    final pending = UnrestrictedOwnership(
      stage: UnrestrictedStage.applying,
      base: unrestrictedFingerprint(rules),
      owned: unrestrictedFingerprint(next),
    );
    if (!await ledger.put(_unrestrictedBinding, ref, pending, when: current)) {
      if (!current()) return _stopUnrestricted(ref, entry, write: true);
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: SessionUnrestrictedNotice.refused,
      );
    }
    if (!current()) return _stopUnrestricted(ref, entry, write: true);
    final attempt = await client.replace(
      session: ref,
      rules: next,
      change: 'enable',
      id: id,
      cancellation: entry.cancellation,
    );
    final receipt = attempt.receipt;
    if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
    switch (receipt.state.known) {
      case ReceiptState.accepted:
        final after = await _readRules(ref, entry);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          after,
          notice: after != null && after.endsWithWildcardAllow
              ? SessionUnrestrictedNotice.none
              : SessionUnrestrictedNotice.unconfirmed,
          receipt: receipt,
        );
      case ReceiptState.rejected || ReceiptState.unavailable:
        // Definitely not applied: the pending record is dropped.
        await ledger.remove(_unrestrictedBinding, ref, when: current);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          rules,
          notice: SessionUnrestrictedNotice.refused,
          receipt: receipt,
        );
      default:
        // Unknown outcome: one verification read, never a second write.
        final after = await _readRules(ref, entry);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          after,
          notice: SessionUnrestrictedNotice.unconfirmed,
          receipt: receipt,
        );
    }
  }

  /// Removes only CodeWalk's own insertion, and only while a fresh read still
  /// matches what CodeWalk wrote; otherwise it warns and writes nothing.
  Future<void> disableUnrestricted(SessionRef ref, CommandId id) async {
    final client = _rules;
    final ledger = unrestrictedOwnership;
    final entry = _unrestricted[ref];
    if (client == null ||
        ledger == null ||
        entry == null ||
        !canDisableUnrestricted(ref)) {
      return;
    }
    bool current() => _currentUnrestricted(ref, entry);
    _markUnrestrictedBusy(ref, entry);
    final rules = await _readRules(ref, entry);
    if (!current()) return _stopUnrestricted(ref, entry, write: true);
    final record = ledger.recordFor(_unrestrictedBinding, ref);
    final fresh = rules != null && rules.recognized;
    // Any stage counts once the rules match CodeWalk's insertion exactly: an
    // earlier stage that failed to persist must not strand the rule.
    if (!fresh ||
        !rules.endsWithWildcardAllow ||
        record == null ||
        unrestrictedFingerprint(rules) != record.owned) {
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: fresh
            ? SessionUnrestrictedNotice.changedElsewhere
            : SessionUnrestrictedNotice.none,
      );
    }
    final removing = record.at(UnrestrictedStage.removing);
    if (!await ledger.put(_unrestrictedBinding, ref, removing, when: current)) {
      if (!current()) return _stopUnrestricted(ref, entry, write: true);
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: SessionUnrestrictedNotice.refused,
      );
    }
    if (!current()) return _stopUnrestricted(ref, entry, write: true);
    final attempt = await client.replace(
      session: ref,
      rules: rules.withoutTrailingWildcardAllow(),
      change: 'disable',
      id: id,
      cancellation: entry.cancellation,
    );
    final receipt = attempt.receipt;
    if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
    switch (receipt.state.known) {
      case ReceiptState.accepted:
        final after = await _readRules(ref, entry);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          after,
          notice: after != null && !after.endsWithWildcardAllow
              ? SessionUnrestrictedNotice.none
              : SessionUnrestrictedNotice.unconfirmed,
          receipt: receipt,
        );
      case ReceiptState.rejected || ReceiptState.unavailable:
        // Definitely not applied: the insertion is still CodeWalk's.
        final owned = record.at(UnrestrictedStage.owned);
        await ledger.put(_unrestrictedBinding, ref, owned, when: current);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          rules,
          notice: SessionUnrestrictedNotice.refused,
          receipt: receipt,
        );
      default:
        final after = await _readRules(ref, entry);
        if (!current()) return _stopUnrestricted(ref, entry, receipt: receipt);
        await _settleUnrestricted(
          ref,
          entry,
          after,
          notice: SessionUnrestrictedNotice.unconfirmed,
          receipt: receipt,
        );
    }
  }

  static String _replyKey(SessionRef ref, String id) => '${ref.storageKey}|$id';

  /// The session that owns [request]: a child's request shown in its parent
  /// keeps the child, so every view and both paths share one fence.
  static SessionRef? _owning(InteractionRequest request) {
    final owner = request.owner;
    return owner is SessionOwner ? owner.session : null;
  }

  static String _requestKey(InteractionRequest request) {
    final owner = request.owner;
    if (owner is SessionOwner) {
      return _replyKey(owner.session, request.id.value);
    }
    return 'global|${request.id.value}';
  }

  /// [owner] is the request's owning session when it is not [ref] itself.
  SessionPermissionReplyState replyState(
    SessionRef ref,
    InteractionId id, {
    SessionRef? owner,
  }) =>
      _replyStates[_replyKey(owner ?? ref, id.value)]?.state ??
      _replyStates['global|${id.value}']?.state ??
      const SessionPermissionReplyState();

  bool get supportsReplies =>
      (_replies != null || _forms != null) && _activeBinding;

  bool canReply(SessionRef ref, InteractionRequest request) {
    final owner = request.owner;
    if (!_activeBinding ||
        _replies == null ||
        owner is! SessionOwner ||
        (owner.session != ref && owner.origin != ref)) {
      return false;
    }
    final key = _requestKey(request);
    if ((_replyStates[key]?.inFlight ?? false) ||
        (_replyStates[key]?.state.busy ?? false)) {
      return false;
    }
    final current = view(ref);
    return current.phase == SessionLivePhase.live &&
        !current.stale &&
        (current.state?.interactions.any(
              (r) => r.identityKey == request.identityKey,
            ) ??
            false);
  }

  Future<void> reply({
    required SessionRef ref,
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  }) => _send(
    ref: ref,
    request: request,
    response: response,
    id: id,
    automatic: false,
  );

  /// The manual and the automatic path share this fence, timer and receipt
  /// mapping: both are one caller-invoked reply for one request. [automatic]
  /// only selects the native `once`-only client call.
  Future<void> _send({
    required SessionRef ref,
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
    required bool automatic,
  }) {
    final client = _replies;
    if (client == null || !canReply(ref, request)) return Future.value();
    return _dispatchReply(
      ref: ref,
      request: request,
      send: (cancellation) async =>
          (automatic
                  ? await client.approveOnce(
                      request: request,
                      id: id,
                      cancellation: cancellation,
                    )
                  : await client.reply(
                      request: request,
                      response: response,
                      id: id,
                      cancellation: cancellation,
                    ))
              .receipt,
    );
  }

  bool canReplyForm(SessionRef ref, InteractionRequest request) {
    final owner = request.owner;
    if (!_activeBinding || _forms == null) return false;
    if (owner is SessionOwner) {
      if (owner.session != ref && owner.origin != ref) return false;
    } else if (owner is GlobalOwner) {
      if (owner.harness != harness) return false;
    } else {
      return false;
    }
    final key = _requestKey(request);
    if ((_replyStates[key]?.inFlight ?? false) ||
        (_replyStates[key]?.state.busy ?? false)) {
      return false;
    }
    final current = view(ref);
    return current.phase == SessionLivePhase.live &&
        !current.stale &&
        (current.state?.interactions.any(
              (r) => r.identityKey == request.identityKey,
            ) ??
            false);
  }

  Future<void> replyForm({
    required SessionRef ref,
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
  }) => _sendForm(
    ref: ref,
    request: request,
    response: response,
    id: id,
    isDismiss: false,
  );

  Future<void> dismissForm({
    required SessionRef ref,
    required InteractionRequest request,
    required CommandId id,
  }) => _sendForm(
    ref: ref,
    request: request,
    response: null,
    id: id,
    isDismiss: true,
  );

  Future<void> _sendForm({
    required SessionRef ref,
    required InteractionRequest request,
    required FormResponse? response,
    required CommandId id,
    required bool isDismiss,
  }) {
    final client = _forms;
    if (client == null || !canReplyForm(ref, request)) return Future.value();
    return _dispatchReply(
      ref: ref,
      request: request,
      send: (cancellation) async =>
          (isDismiss
                  ? await client.dismiss(
                      request: request,
                      id: id,
                      cancellation: cancellation,
                    )
                  : await client.reply(
                      request: request,
                      response: response!,
                      id: id,
                      cancellation: cancellation,
                    ))
              .receipt,
    );
  }

  Future<void> _dispatchReply({
    required SessionRef ref,
    required InteractionRequest request,
    required Future<CommandReceipt> Function(RequestCancellation) send,
  }) async {
    final key = _requestKey(request);
    _replyStates[key]?.dispose();
    final reply = _ReplyRequest(ref);
    _replyStates[key] = reply;
    answered.add(key);
    _publish(ref, view(ref));
    final receipt = await send(reply.cancellation);
    if (isClosed || !identical(_replyStates[key], reply)) return;
    reply.inFlight = false;
    final phase = switch (receipt.state.known) {
      ReceiptState.accepted => SessionPermissionReplyPhase.requested,
      ReceiptState.rejected ||
      ReceiptState.unavailable => SessionPermissionReplyPhase.refused,
      _ => SessionPermissionReplyPhase.unconfirmed,
    };
    reply.state = SessionPermissionReplyState(phase: phase, receipt: receipt);
    if (receipt.state.known == ReceiptState.rejected &&
        (receipt.error?.rawType == 'NotFoundError' ||
            receipt.error?.rawType == 'FormAlreadySettledError')) {
      _owner?.refresh(ref);
    }
    if (phase == SessionPermissionReplyPhase.requested) {
      reply.timer = Timer(const Duration(seconds: 30), () {
        if (isClosed || !identical(_replyStates[key], reply)) return;
        reply.state = SessionPermissionReplyState(
          phase: SessionPermissionReplyPhase.unconfirmed,
          receipt: receipt,
        );
        _publish(ref, view(ref));
      });
    }
    _publish(ref, view(ref));
  }

  /// Drops local reply state whose request left canonical state. Cards only
  /// disappear through the stream/hydration; this just frees their fences.
  void _pruneReplies(SessionRef ref, SessionLiveView view) {
    final state = view.state;
    final resident = {
      for (final r in state?.interactions ?? const <InteractionRequest>[])
        _requestKey(r),
    };
    // The answered fence only shrinks on an authoritative live snapshot that
    // no longer lists the request. Native ids are unique, so a removed request
    // never returns and cannot re-open a replay window. A parent's snapshot
    // is authoritative for the children it follows too.
    if (state != null && view.phase == SessionLivePhase.live && !view.stale) {
      final prefixes = [
        '${ref.storageKey}|',
        'global|',
        for (final child in _owner?.childrenOf(ref) ?? const <SessionRef>{})
          if (!_views.containsKey(child)) '${child.storageKey}|',
      ];
      answered.removeWhere(
        (key) =>
            prefixes.any(key.startsWith) &&
            !resident.contains(key) &&
            !(_replyStates[key]?.inFlight ?? false),
      );
    }
    if (_replyStates.isEmpty) return;
    _replyStates.removeWhere((key, reply) {
      if (reply.session != ref) return false;
      final drop = !resident.contains(key) && !reply.inFlight;
      if (drop) reply.dispose();
      return drop;
    });
  }

  /// The complete gate for answering [request] without the user. Only the
  /// policy's acknowledged Allow all opens it; every other value keeps the
  /// manual card, and the request must still be answerable right now.
  bool _canAutoApprove(SessionRef ref, InteractionRequest request) {
    final policy = permissionModes;
    if (policy == null || !policy.loaded) return false;
    final owning = _owning(request);
    if (owning == null) return false;
    final SessionPermissionModeState state;
    if (owning == ref) {
      final parentRef = view(ref).state?.info?.lineage.parent;
      state = parentRef != null
          ? policy.effectiveForChild(child: ref, parent: parentRef)
          : policy.effectiveFor(ref);
    } else {
      state = policy.effectiveForChild(child: owning, parent: ref);
    }
    if (!state.answering) return false;
    // The native `once` choice is the only thing this path may send.
    if (request.automaticChoice?.id != 'once') return false;
    if (answered.contains(_requestKey(request))) return false;
    return canReply(ref, request);
  }

  /// Re-runs automatic eligibility for watched sessions after a policy change.
  void considerAutoApproval() {
    if (isClosed) return;
    for (final ref in _views.keys.toList()) {
      if (handles.any((handle) => handle.session == ref)) _autoApprove(ref);
    }
  }

  /// Answers every eligible resident request of a watched session once. Only
  /// called for a session with a lease and a current live state, so a session
  /// nobody is looking at is never answered on the user's behalf.
  void _autoApprove(SessionRef ref) {
    if (isClosed) return;
    final requests = view(ref).state?.interactions;
    if (requests == null || requests.isEmpty) return;
    for (final request in requests.toList()) {
      if (!_canAutoApprove(ref, request)) continue;
      // _send latches the canonical key before its first await.
      unawaited(
        _send(
          ref: ref,
          request: request,
          response: ApprovalResponse('once'),
          id: commandIds(),
          automatic: true,
        ),
      );
    }
  }

  void _onUpdate(OpenCodeStreamUpdate update) {
    switch (update) {
      case OpenCodeSessionUpdated(:final ref, :final state):
        final previous = _views[ref];
        if (previous == null) return;
        _observe(ref, state);
        // A disconnect snapshot arrives before the reconnecting update.
        final live = _phase == SessionLivePhase.live && _isLive(state);
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: previous.phase == SessionLivePhase.degraded
                ? SessionLivePhase.degraded
                : _phase == SessionLivePhase.live && !live
                ? SessionLivePhase.hydrating
                : _phase,
            failure: previous.failure,
            version: version,
            lastSyncedAt: live ? _now() : previous.lastSyncedAt,
            // Stale means it was current once; a first hydration is not.
            stale: !live && previous.lastSyncedAt != null,
            state: state,
          ),
        );
        // After publishing: the gate reads the phase this frame established.
        _autoApprove(ref);
      case OpenCodeSessionEvicted(:final ref):
        if (!_views.containsKey(ref)) return;
        _publish(
          ref,
          SessionLiveView(
            session: ref,
            phase: SessionLivePhase.evicted,
            failure: SessionLiveFailure.notFound,
            version: version,
          ),
        );
      case OpenCodeSessionRulesUpdated(:final ref, :final rules):
        final entry = _unrestricted[ref];
        if (entry == null || !supportsUnrestricted) return;
        if (entry.state.busy) {
          entry.needsRead = true;
          return;
        }
        _markUnrestrictedBusy(ref, entry);
        unawaited(_settleUnrestricted(ref, entry, rules));
      case OpenCodeConnectionUpdated(:final kind, :final session):
        final phase = switch (kind) {
          ConnectionKind.hydrating => SessionLivePhase.hydrating,
          ConnectionKind.live => SessionLivePhase.live,
          ConnectionKind.reconnecting => SessionLivePhase.reconnecting,
          ConnectionKind.degraded => SessionLivePhase.degraded,
          ConnectionKind.authRequired => SessionLivePhase.authRequired,
          ConnectionKind.incompatible => SessionLivePhase.incompatible,
          _ => SessionLivePhase.connecting,
        };
        final failure = switch (phase) {
          SessionLivePhase.degraded => SessionLiveFailure.unavailable,
          SessionLivePhase.authRequired =>
            SessionLiveFailure.authenticationRequired,
          SessionLivePhase.incompatible =>
            SessionLiveFailure.incompatibleResponse,
          _ => null,
        };
        if (session == null) {
          _phase = phase;
          // A terminal stream never recovers; new leases get a fresh slot
          // while open screens keep showing this one until they retry.
          if (phase == SessionLivePhase.authRequired ||
              phase == SessionLivePhase.incompatible) {
            _release();
          }
        }
        final autoCandidates = <SessionRef>[];
        for (final MapEntry(key: ref, value: previous)
            in _views.entries.toList()) {
          if (session != null && session != ref) continue;
          // A session set aside stays aside until a new generation hydrates.
          final keep =
              session == null &&
              previous.phase == SessionLivePhase.degraded &&
              phase == SessionLivePhase.live;
          if (previous.phase == SessionLivePhase.evicted) continue;
          final live = phase == SessionLivePhase.live && !keep;
          _publish(
            ref,
            SessionLiveView(
              session: ref,
              phase: keep ? SessionLivePhase.degraded : phase,
              failure: keep ? previous.failure : failure,
              version: version,
              lastSyncedAt: live && previous.state != null
                  ? _now()
                  : previous.lastSyncedAt,
              stale: !live && previous.lastSyncedAt != null,
              state: previous.state,
            ),
          );
          // Initial hydration publishes its state before the stream is live,
          // so its SessionUpdated cannot answer yet. Once live is
          // established, answer every eligible resident request of the
          // sessions this update brought live.
          if (live && previous.state != null) autoCandidates.add(ref);
        }
        for (final ref in autoCandidates) {
          _autoApprove(ref);
        }
    }
  }

  /// Minted ids must sort after the server's: ids rise, so the pending rows
  /// and the newest items carry the floor.
  void _observe(SessionRef ref, SessionState state) {
    final timeline = state.timeline;
    for (final id in [
      for (final entry in state.pending) entry.id,
      for (final item in timeline.skip(max(0, timeline.length - 16))) item.id,
    ]) {
      if (openCodeMessageIdOf(id, ref) case final message?) {
        ids.observe(message);
      }
    }
  }

  void release(OpenCodeLiveHandle handle) {
    if (!handles.remove(handle)) return;
    if (!handles.any((h) => h.session == handle.session)) {
      _owner?.unwatch(handle.session);
      _views.remove(handle.session);
      _stops.remove(handle.session)?.dispose();
      _older.remove(handle.session);
      _unrestricted.remove(handle.session)?.dispose();
      _selection?.release(handle.session);
      _replyStates.removeWhere((_, reply) {
        if (reply.session != handle.session) return false;
        reply.dispose();
        return true;
      });
    }
    if (handles.isEmpty && _catalogLeases == 0) {
      _release();
      unawaited(close());
    }
  }

  /// The catalog feeds holding this profile's stream open.
  int get catalogLeases => _catalogLeases;

  bool get isClosed => _closing != null;
  bool get _activeBinding => !isClosed && isCurrentBinding();

  Future<void> close() {
    final closing = _closing;
    if (closing != null) return closing;
    final completion = Completer<void>();
    _closing = completion.future;
    lifetimeCancellation.cancel();
    unawaited(
      _shutdown().then<void>(
        (_) => completion.complete(),
        onError: completion.completeError,
      ),
    );
    return completion.future;
  }

  Future<void> _shutdown() async {
    for (final lease in _leases.toList()) {
      lease.close();
    }
    _leases.clear();
    for (final stop in _stops.values) {
      stop.dispose();
    }
    _stops.clear();
    _older.clear();
    for (final entry in _unrestricted.values) {
      entry.dispose();
    }
    _unrestricted.clear();
    _selection?.close();
    for (final reply in _replyStates.values) {
      reply.dispose();
    }
    _replyStates.clear();
    for (final handle in handles.toList()) {
      handle.detach();
    }
    handles.clear();
    await _subscription?.cancel();
    await _owner?.close();
    await _connection?.close();
    _reader.dispose();
    _transport.close();
    _store.clear();
  }
}

final class _StopRequest {
  final cancellation = RequestCancellation();
  bool inFlight = true;
  bool settled = false;
  Timer? timer;
  SessionStopState state = const SessionStopState(
    phase: SessionStopPhase.requesting,
  );
  void dispose() {
    timer?.cancel();
    cancellation.cancel();
  }
}

final class _UnrestrictedEntry {
  final cancellation = RequestCancellation();
  bool needsRead = true;

  /// The slot's epoch when the operation in flight started.
  int epoch = 0;

  /// The current live period already retried a failed automatic read.
  bool retried = false;
  SessionUnrestrictedState state = const SessionUnrestrictedState();
  void dispose() => cancellation.cancel();
}

final class _ReplyRequest {
  _ReplyRequest(this.session);
  final SessionRef session;
  final cancellation = RequestCancellation();
  bool inFlight = true;
  Timer? timer;
  SessionPermissionReplyState state = const SessionPermissionReplyState(
    phase: SessionPermissionReplyPhase.requesting,
  );
  void dispose() {
    timer?.cancel();
    cancellation.cancel();
  }
}

/// The catalog's hold on one profile's stream.
///
/// The feed is the endpoint's single stream: the lease only forwards the
/// owner's payload-free catalog signal and keeps the profile alive while the
/// catalog needs it.
final class _CatalogLease implements SessionCatalogChanges {
  _CatalogLease(this._slot, this._owner) {
    _changes = _owner.catalogChanges.listen(
      (change) => _add(switch (change) {
        OpenCodeCatalogChange.started ||
        OpenCodeCatalogChange.waiting => const SessionActivityChanged(),
        _ => const SessionCatalogChanged(),
      }),
    );
    // Only a stream-level update describes the endpoint's stream: a
    // per-session degradation leaves the stream live.
    _connection = _owner.updates
        .where((update) => update is OpenCodeConnectionUpdated)
        .where(
          (update) => (update as OpenCodeConnectionUpdated).session == null,
        )
        .listen((update) {
          final kind = (update as OpenCodeConnectionUpdated).kind;
          _add(SessionCatalogConnection(kind == ConnectionKind.live));
          if (kind == ConnectionKind.authRequired ||
              kind == ConnectionKind.incompatible) {
            // A terminal stream ends the feed: the catalog drops the lease
            // and re-acquires one on the next read.
            unawaited(_controller.close());
          }
        });
  }

  final OpenCodeProfileSlot _slot;
  final OpenCodeStreamOwner _owner;
  final _controller = StreamController<SessionCatalogSignal>.broadcast();
  late final StreamSubscription<OpenCodeCatalogChange> _changes;
  late final StreamSubscription<OpenCodeStreamUpdate> _connection;
  bool _closed = false;

  @override
  Stream<SessionCatalogSignal> get signals => Stream.multi((controller) {
    // A subscriber that arrives late learns the current state first: a
    // broadcast controller would drop it.
    final kind = _owner.connectionKind;
    if (kind != null) {
      controller.add(SessionCatalogConnection(kind == ConnectionKind.live));
    }
    final subscription = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });

  void _add(SessionCatalogSignal signal) {
    if (!_closed && !_controller.isClosed) _controller.add(signal);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_changes.cancel());
    unawaited(_connection.cancel());
    unawaited(_controller.close());
    _slot._releaseCatalog(this);
  }
}
