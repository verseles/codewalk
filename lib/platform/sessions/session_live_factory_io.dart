import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';
import 'prompt_outbox_store.dart';
import 'unrestricted_ownership_store.dart';

SessionLiveDirectory? createSessionLiveDirectory({
  DateTime Function()? now,
  PayloadStore? payloads,
  PermissionModePolicy? permissionModes,
  UnrestrictedOwnershipLedger? unrestrictedOwnership,
  CommandId Function()? commandIds,
}) => _NativeLiveDirectory(
  now ?? DateTime.now,
  payloads,
  permissionModes,
  unrestrictedOwnership,
  commandIds ?? mintCommandId,
);

/// One event stream per endpoint profile, shared by every open handle; the
/// last handle of a session unwatches it and the last of a profile closes the
/// stream. Mutations require an explicit outbox action, Stop or permission
/// reply on a handle.
final class _NativeLiveDirectory implements SessionLiveDirectory {
  _NativeLiveDirectory(
    this._now,
    this._payloads,
    this._permissionModes,
    this._unrestrictedOwnership,
    this._commandIds,
  ) {
    _permissionModes?.addListener(_policyChanged);
  }
  final DateTime Function() _now;
  final PayloadStore? _payloads;
  final PermissionModePolicy? _permissionModes;
  final UnrestrictedOwnershipLedger? _unrestrictedOwnership;
  final CommandId Function() _commandIds;
  // Outlive slot generations: a replaced slot's outbox and its successor
  // write the same ledgers in turn, and minted ids keep rising per server.
  final _queue = KeySerialExecutor();
  final _ids = <String, OpenCodeMessageIds>{};
  // Outlive slot generations, like [_ids]: a request answered before the last
  // screen closed stays answered when the same profile reopens in a new slot.
  final _answered = <String, Set<String>>{};
  final _slots = <String, _ProfileSlot>{};
  // Includes terminal slots detached from [_slots] while screens still hold
  // them, so closing the directory reaches every open stream.
  final _owned = <_ProfileSlot>{};
  bool _closed = false;

  @override
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  }) async {
    if (_closed) throw const SessionLiveException(SessionLiveFailure.cancelled);
    if (session.harnessRef !=
        HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id))) {
      throw const SessionLiveException(SessionLiveFailure.incompatibleResponse);
    }
    final key = '${profile.id}|${profile.endpoint}';
    var slot = _slots[key];
    if (slot != null && !slot.credential.matches(credential)) {
      // Never multiplex two secrets over one stream.
      if (slot.handles.isNotEmpty) {
        throw const SessionLiveException(
          SessionLiveFailure.authenticationRequired,
        );
      }
      _slots.remove(key);
      unawaited(slot.close());
      slot = null;
    }
    final current = slot ?? _createSlot(key, profile, credential, session);
    try {
      await current.ready();
      return current.lease(session);
    } on Object {
      if (current.handles.isEmpty && identical(_slots[key], current)) {
        _slots.remove(key);
        unawaited(current.close());
      }
      rethrow;
    }
  }

  _ProfileSlot _createSlot(
    String key,
    EndpointProfile profile,
    EndpointCredential credential,
    SessionRef session,
  ) {
    late final _ProfileSlot slot;
    slot = _ProfileSlot(
      profile,
      credential,
      session.harnessRef,
      _now,
      () {
        if (identical(_slots[key], slot)) _slots.remove(key);
      },
      payloads: _payloads,
      queue: _queue,
      ids: _ids.putIfAbsent(key, OpenCodeMessageIds.new),
      answered: _answered.putIfAbsent(key, () => <String>{}),
      permissionModes: _permissionModes,
      unrestrictedOwnership: _unrestrictedOwnership,
      commandIds: _commandIds,
    );
    _owned
      ..removeWhere((owned) => owned.isClosed)
      ..add(slot);
    return _slots[key] = slot;
  }

  /// A policy change is the user's decision: re-evaluate resident requests
  /// now, so switching to Allow all does not wait for another frame. Every
  /// gate in [_ProfileSlot._canAutoApprove] still applies.
  void _policyChanged() {
    if (_closed) return;
    for (final slot in _owned.toList()) {
      slot.considerAutoApproval();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _permissionModes?.removeListener(_policyChanged);
    final slots = _owned.toList();
    _slots.clear();
    _owned.clear();
    await Future.wait([for (final slot in slots) slot.close()]);
    _answered.clear();
  }
}

final class _ProfileSlot {
  _ProfileSlot(
    EndpointProfile profile,
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

  final EndpointCredential credential;
  final HarnessRef harness;
  final DateTime Function() _now;
  final void Function() _release;
  final PayloadStore? payloads;
  final KeySerialExecutor queue;
  final OpenCodeMessageIds ids;
  final PermissionModePolicy? permissionModes;

  /// CodeWalk's own Unrestricted insertions; without it the action is absent.
  final UnrestrictedOwnershipLedger? unrestrictedOwnership;
  final CommandId Function() commandIds;
  PromptOutbox? outbox;
  OpenCodeInterruptClient? _interrupt;
  OpenCodePermissionReplyClient? _replies;
  OpenCodeSessionRulesClient? _rules;
  final _stops = <SessionRef, _StopRequest>{};
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
  final handles = <_LiveHandle>{};
  final _views = <SessionRef, SessionLiveView>{};

  Future<void> ready() => _ready ??= _probe();

  Future<void> _probe() async {
    final assessment = await OpenCodeEndpointProbe(_transport).detect();
    if (_closing != null) {
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
    _rules = OpenCodeSessionRulesClient(
      _transport,
      harness: harness,
      connectedVersion: observed,
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

  _LiveHandle lease(SessionRef session) {
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
    final handle = _LiveHandle(this, session);
    handles.add(handle);
    // A session that is already live reads its rules now.
    _considerUnrestrictedRead(session, view(session));
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
      if (execution.kind.known != ExecutionKind.running) {
        stop.settled = true;
      }
    }
    // Hydration reconstructs lastOutcome objects even for the same running
    // execution. Only an observed non-running state proves settlement. Latch
    // it if it beats HTTP, and clear an uncertain wait too when it arrives late.
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
  }

  SessionStopState stopState(SessionRef ref) =>
      _stops[ref]?.state ?? const SessionStopState();

  bool canStop(SessionRef ref) {
    final current = view(ref);
    return !isClosed &&
        _interrupt != null &&
        !stopState(ref).busy &&
        _stops[ref]?.inFlight != true &&
        current.phase == SessionLivePhase.live &&
        !current.stale &&
        current.state?.execution?.kind.known == ExecutionKind.running;
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

  /// Unrestricted is the session's own server rule (ADR-059 §7), separate
  /// from the local Ask / Allow all mode. It exists only with an ownership
  /// ledger, and nothing here runs from the automatic responder.
  bool get supportsUnrestricted =>
      !isClosed && _rules != null && unrestrictedOwnership != null;

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

  bool _currentUnrestricted(SessionRef ref, _UnrestrictedEntry entry) =>
      !isClosed && identical(_unrestricted[ref], entry);

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
    final previous = ledger.recordFor(ref);
    final reading = classifyUnrestricted(rules, previous);
    final next = reading.record;
    var stored = true;
    if (!_sameRecord(previous, next)) {
      // A failed transition leaves the older stage; it is reported, and the
      // next read classifies that stage again.
      stored = next == null
          ? await ledger.remove(ref)
          : await ledger.put(ref, next);
    }
    if (!_currentUnrestricted(ref, entry)) return;
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
    if (!_currentUnrestricted(ref, entry)) return;
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
    _markUnrestrictedBusy(ref, entry);
    final rules = await _readRules(ref, entry);
    if (!_currentUnrestricted(ref, entry)) return;
    final record = ledger.recordFor(ref);
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
    if (!await ledger.put(ref, pending)) {
      if (!_currentUnrestricted(ref, entry)) return;
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: SessionUnrestrictedNotice.refused,
      );
    }
    if (!_currentUnrestricted(ref, entry)) return;
    final attempt = await client.replace(
      session: ref,
      rules: next,
      change: 'enable',
      id: id,
      cancellation: entry.cancellation,
    );
    if (!_currentUnrestricted(ref, entry)) return;
    final receipt = attempt.receipt;
    switch (receipt.state.known) {
      case ReceiptState.accepted:
        final after = await _readRules(ref, entry);
        if (!_currentUnrestricted(ref, entry)) return;
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
        await ledger.remove(ref);
        if (!_currentUnrestricted(ref, entry)) return;
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
        if (!_currentUnrestricted(ref, entry)) return;
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
    _markUnrestrictedBusy(ref, entry);
    final rules = await _readRules(ref, entry);
    if (!_currentUnrestricted(ref, entry)) return;
    final record = ledger.recordFor(ref);
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
    if (!await ledger.put(ref, record.at(UnrestrictedStage.removing))) {
      if (!_currentUnrestricted(ref, entry)) return;
      return _settleUnrestricted(
        ref,
        entry,
        rules,
        notice: SessionUnrestrictedNotice.refused,
      );
    }
    if (!_currentUnrestricted(ref, entry)) return;
    final attempt = await client.replace(
      session: ref,
      rules: rules.withoutTrailingWildcardAllow(),
      change: 'disable',
      id: id,
      cancellation: entry.cancellation,
    );
    if (!_currentUnrestricted(ref, entry)) return;
    final receipt = attempt.receipt;
    switch (receipt.state.known) {
      case ReceiptState.accepted:
        final after = await _readRules(ref, entry);
        if (!_currentUnrestricted(ref, entry)) return;
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
        await ledger.put(ref, record.at(UnrestrictedStage.owned));
        if (!_currentUnrestricted(ref, entry)) return;
        await _settleUnrestricted(
          ref,
          entry,
          rules,
          notice: SessionUnrestrictedNotice.refused,
          receipt: receipt,
        );
      default:
        final after = await _readRules(ref, entry);
        if (!_currentUnrestricted(ref, entry)) return;
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

  static String _requestKey(InteractionRequest request) =>
      _replyKey(_owning(request)!, request.id.value);

  /// [owner] is the request's owning session when it is not [ref] itself.
  SessionPermissionReplyState replyState(
    SessionRef ref,
    InteractionId id, {
    SessionRef? owner,
  }) =>
      _replyStates[_replyKey(owner ?? ref, id.value)]?.state ??
      const SessionPermissionReplyState();

  bool get supportsReplies => _replies != null && !isClosed;

  bool canReply(SessionRef ref, InteractionRequest request) {
    final owner = request.owner;
    if (isClosed ||
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
  }) async {
    final client = _replies;
    if (client == null || !canReply(ref, request)) return;
    final key = _requestKey(request);
    _replyStates[key]?.dispose();
    final reply = _ReplyRequest(ref);
    _replyStates[key] = reply;
    // A deliberate reply wins over any later automatic attempt for the same
    // session and request: both paths latch under the canonical key here,
    // synchronously, before the first await.
    answered.add(key);
    _publish(ref, view(ref));
    final attempt = automatic
        ? await client.approveOnce(
            request: request,
            id: id,
            cancellation: reply.cancellation,
          )
        : await client.reply(
            request: request,
            response: response,
            id: id,
            cancellation: reply.cancellation,
          );
    if (isClosed || !identical(_replyStates[key], reply)) return;
    reply.inFlight = false;
    final receipt = attempt.receipt;
    final phase = switch (receipt.state.known) {
      ReceiptState.accepted => SessionPermissionReplyPhase.requested,
      ReceiptState.rejected ||
      ReceiptState.unavailable => SessionPermissionReplyPhase.refused,
      _ => SessionPermissionReplyPhase.unconfirmed,
    };
    reply.state = SessionPermissionReplyState(phase: phase, receipt: receipt);
    // Someone else answered first (or the request is gone): never resend,
    // read the session once so the card follows the native state.
    if (receipt.state.known == ReceiptState.rejected &&
        receipt.error?.rawType == 'NotFoundError') {
      _owner?.refresh(ref);
    }
    if (phase == SessionPermissionReplyPhase.requested) {
      // The reply was accepted, not settled. Bound the local waiting state
      // without inferring settlement or automatically repeating the mutation.
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
        if (_owning(r) != null) _requestKey(r),
    };
    // The answered fence only shrinks on an authoritative live snapshot that
    // no longer lists the request. Native ids are unique, so a removed request
    // never returns and cannot re-open a replay window. A parent's snapshot
    // is authoritative for the children it follows too.
    if (state != null && view.phase == SessionLivePhase.live && !view.stale) {
      final prefixes = [
        '${ref.storageKey}|',
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
    if (policy == null ||
        !policy.loaded ||
        !policy.effectiveFor(ref).answering) {
      return false;
    }
    // The native `once` choice is the only thing this path may send.
    if (request.automaticChoice?.id != 'once') return false;
    // A child's request shown in its parent stays manual until the child
    // policy lands (V2-047B3b).
    if (_owning(request) != ref) return false;
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

  void release(_LiveHandle handle) {
    if (!handles.remove(handle)) return;
    if (!handles.any((h) => h.session == handle.session)) {
      _owner?.unwatch(handle.session);
      _views.remove(handle.session);
      _stops.remove(handle.session)?.dispose();
      _unrestricted.remove(handle.session)?.dispose();
      _replyStates.removeWhere((_, reply) {
        if (reply.session != handle.session) return false;
        reply.dispose();
        return true;
      });
    }
    if (handles.isEmpty) {
      _release();
      unawaited(close());
    }
  }

  bool get isClosed => _closing != null;

  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    for (final stop in _stops.values) {
      stop.dispose();
    }
    _stops.clear();
    for (final entry in _unrestricted.values) {
      entry.dispose();
    }
    _unrestricted.clear();
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

final class _LiveHandle implements SessionLiveHandle {
  _LiveHandle(this._slot, this.session);
  final _ProfileSlot _slot;
  @override
  final SessionRef session;
  final _controller = StreamController<SessionLiveView>.broadcast();
  bool _closed = false;

  @override
  SessionLiveView get current => _closed
      ? SessionLiveView(session: session, phase: SessionLivePhase.closed)
      : _slot.view(session);

  @override
  Stream<SessionLiveView> get updates => Stream.multi((listener) {
    listener.add(current);
    final subscription = _controller.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  });

  @override
  PromptOutbox? get outbox => _closed ? null : _slot.outbox;

  @override
  SessionStopState get stopState =>
      _closed ? const SessionStopState() : _slot.stopState(session);

  @override
  bool get canStop => !_closed && _slot.canStop(session);

  @override
  Future<void> stop({required CommandId id}) async {
    if (!_closed) await _slot.stop(session, id);
  }

  @override
  bool get supportsUnrestricted => !_closed && _slot.supportsUnrestricted;

  @override
  SessionUnrestrictedState get unrestrictedState => _closed
      ? const SessionUnrestrictedState()
      : _slot.unrestrictedState(session);

  @override
  bool get canEnableUnrestricted =>
      !_closed && _slot.canEnableUnrestricted(session);

  @override
  bool get canDisableUnrestricted =>
      !_closed && _slot.canDisableUnrestricted(session);

  @override
  bool get canRefreshUnrestricted =>
      !_closed && _slot.canRefreshUnrestricted(session);

  @override
  Future<void> enableUnrestricted({required CommandId id}) async {
    if (!_closed) await _slot.enableUnrestricted(session, id);
  }

  @override
  Future<void> disableUnrestricted({required CommandId id}) async {
    if (!_closed) await _slot.disableUnrestricted(session, id);
  }

  @override
  Future<void> refreshUnrestricted() async {
    if (!_closed && _slot.canRefreshUnrestricted(session)) {
      await _slot.refreshUnrestricted(session);
    }
  }

  @override
  bool get supportsReplies => !_closed && _slot.supportsReplies;

  @override
  SessionPermissionReplyState replyState(
    InteractionId id, {
    SessionRef? owner,
  }) => _closed
      ? const SessionPermissionReplyState()
      : _slot.replyState(session, id, owner: owner);

  @override
  bool canReply(InteractionRequest request) =>
      !_closed && _slot.canReply(session, request);

  @override
  Future<void> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  }) async {
    if (!_closed) {
      await _slot.reply(
        ref: session,
        request: request,
        response: response,
        id: id,
      );
    }
  }

  @override
  String? nativeMessageOf(ItemId id) => openCodeMessageIdOf(id, session);

  void emit(SessionLiveView view) {
    if (!_closed) _controller.add(view);
  }

  void detach() {
    if (_closed) return;
    _controller.add(
      SessionLiveView(session: session, phase: SessionLivePhase.closed),
    );
    _closed = true;
    unawaited(_controller.close());
  }

  @override
  void close() {
    if (_closed) return;
    _slot.release(this);
    detach();
  }
}
