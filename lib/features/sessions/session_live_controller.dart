import 'dart:async';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../hosts/hosts_controller.dart';

/// Owns one screen's live lease. Prompts and Stop require explicit user actions;
/// observing, reconnecting and closing never mutate the server.
class SessionLiveController extends ChangeNotifier {
  SessionLiveController({
    required this.hosts,
    required this.profile,
    required SessionSummary summary,
    required this.directory,
    this.permissionModes,
    DateTime Function()? now,
    CommandId Function()? commandIds,
  }) : _summary = summary,
       _now = now ?? DateTime.now,
       _commandIds = commandIds ?? mintCommandId {
    hosts.addListener(_hostsChanged);
    permissionModes?.addListener(_policyChanged);
  }
  final HostsController hosts;
  final EndpointProfile profile;
  SessionSummary _summary;

  /// The listed session. A session tab keeps this view open, so a later row
  /// of the same session, renamed say, replaces it.
  SessionSummary get summary => _summary;

  /// Takes the newer row of the same session; another session is ignored.
  void updateSummary(SessionSummary next) {
    if (_disposed || next.info.ref != session || identical(next, _summary)) {
      return;
    }
    _summary = next;
    _notify();
  }

  /// True once disposed; a disposed view is never shown again.
  bool get disposed => _disposed;
  final SessionLiveDirectory directory;

  /// The acknowledged permission policy for this session, when the app graph
  /// provides one. The controller never owns or disposes it.
  final EditablePermissionModePolicy? permissionModes;
  final DateTime Function() _now;
  final CommandId Function() _commandIds;
  SessionRef get session => summary.info.ref;
  EndpointCredential? _credential;
  SessionLiveHandle? _handle;
  StreamSubscription<SessionLiveView>? _subscription;
  Timer? _expiry;
  bool _disposed = false;
  int _generation = 0;
  final _notes = <String, String>{};
  final _formDrafts = <String, Map<String, dynamic>>{};

  SessionLiveView? view;
  SessionLiveFailure? failure;
  bool opening = false;
  bool _savingPermissionMode = false;

  /// The lease is open or opening, so a page shown again keeps it instead of
  /// opening another.
  bool get started => opening || _handle != null;

  /// The acknowledged effective mode, never a requested-in-flight value.
  SessionPermissionModeState get permissionModeState =>
      permissionModes?.effectiveFor(session) ??
      const SessionPermissionModeState.unavailable('noPolicy');

  bool get savingPermissionMode => _savingPermissionMode;
  bool get canChangePermissionMode =>
      !_disposed &&
      permissionModes != null &&
      permissionModes!.loaded &&
      !permissionModes!.overridesUnreadable &&
      !_savingPermissionMode;

  /// Persists one session override. The returned value is the store's
  /// acknowledgement; nothing changes locally before it resolves. Picking
  /// Allow all while the app default already applies it is a no-op, so the
  /// session never silently pins standing approval authority; an explicit Ask
  /// is always stored, so a later default change cannot widen it.
  Future<bool> setPermissionMode(PermissionMode mode) {
    if (!canChangePermissionMode) return Future.value(false);
    final current = permissionModeState;
    if (mode == PermissionMode.allowAll &&
        current.source != PermissionModeSource.session &&
        current.mode == mode) {
      return Future.value(true);
    }
    return _changePermissionMode(
      () => permissionModes!.setSessionMode(session, mode),
    );
  }

  /// Drops this session's override so the global default applies again.
  Future<bool> useDefaultPermissionMode() =>
      _changePermissionMode(() => permissionModes!.clearSessionMode(session));

  Future<bool> _changePermissionMode(Future<bool> Function() write) async {
    if (!canChangePermissionMode) return false;
    _savingPermissionMode = true;
    notifyListeners();
    var applied = false;
    try {
      applied = await write();
    } on Object {
      applied = false;
    }
    if (_disposed) return applied;
    _savingPermissionMode = false;
    notifyListeners();
    return applied;
  }

  void _policyChanged() {
    if (_disposed) return;
    notifyListeners();
  }

  SessionState? get state => view?.state;
  PromptOutbox? get outbox => _handle?.outbox;
  SessionStopState get stopState =>
      _handle?.stopState ?? const SessionStopState();
  bool get stopping => stopState.busy;
  bool get canStop =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true) &&
      state?.execution?.kind.known == ExecutionKind.running &&
      (_handle?.canStop ?? false);

  Future<void> stopCurrentTurn() async {
    final handle = _handle;
    if (!canStop || handle == null) return;
    final generation = _generation;
    final stopping = handle.stop(id: _commandIds());
    _notify();
    await stopping;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  /// Older history pages into the window one page at a time; once the window
  /// cannot take more, the history viewer is the way back.
  SessionOlderHistoryState get olderHistory =>
      _handle?.olderHistory ?? const SessionOlderHistoryState();
  bool get canLoadOlderHistory =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true) &&
      (_handle?.canLoadOlderHistory ?? false);

  /// More history exists than the window can page in: the window is full or
  /// lost rows in front, or a live, current window cannot page right now. A window that loaded its
  /// whole history, or one paused while not live, offers nothing here; a
  /// partial page keeps [SessionState.hasMoreHistory] set, so it alone does
  /// not tell.
  bool get olderHistoryBeyondWindow {
    final state = this.state;
    if (state == null || !state.hasMoreHistory || olderHistory.loading) {
      return false;
    }
    if (state.timeline.length >= state.limits.maxItems ||
        olderHistory.trimmed) {
      return true;
    }
    return state.nextHistoryCursor != null &&
        phase == SessionLivePhase.live &&
        !(view?.stale ?? true) &&
        !canLoadOlderHistory;
  }

  Future<void> loadOlderHistory() async {
    final handle = _handle;
    if (!canLoadOlderHistory || handle == null) return;
    final generation = _generation;
    final loading = handle.loadOlderHistory();
    _notify();
    await loading;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  /// Unrestricted is the session's own server rule (ADR-059 §7), separate
  /// from [permissionModeState]; it changes only after explicit confirmation.
  bool get supportsUnrestricted =>
      !_disposed && (_handle?.supportsUnrestricted ?? false);
  SessionUnrestrictedState get unrestrictedState =>
      _handle?.unrestrictedState ?? const SessionUnrestrictedState();

  bool get _unrestrictedCurrent =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true);

  bool get canEnableUnrestricted =>
      _unrestrictedCurrent && (_handle?.canEnableUnrestricted ?? false);
  bool get canDisableUnrestricted =>
      _unrestrictedCurrent && (_handle?.canDisableUnrestricted ?? false);
  bool get canRefreshUnrestricted =>
      _unrestrictedCurrent && (_handle?.canRefreshUnrestricted ?? false);

  Future<void> enableUnrestricted() => _changeUnrestricted(
    canEnableUnrestricted,
    (handle) => handle.enableUnrestricted(id: _commandIds()),
  );

  Future<void> disableUnrestricted() => _changeUnrestricted(
    canDisableUnrestricted,
    (handle) => handle.disableUnrestricted(id: _commandIds()),
  );

  Future<void> refreshUnrestricted() => _changeUnrestricted(
    canRefreshUnrestricted,
    (handle) => handle.refreshUnrestricted(),
  );

  Future<void> _changeUnrestricted(
    bool allowed,
    Future<void> Function(SessionLiveHandle) action,
  ) async {
    final handle = _handle;
    if (!allowed || handle == null) return;
    final generation = _generation;
    final running = action(handle);
    _notify();
    await running;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  /// [owner] is the owning session of a child's request shown here.
  SessionPermissionReplyState replyState(
    InteractionId id, {
    SessionRef? owner,
  }) =>
      _handle?.replyState(id, owner: owner) ??
      const SessionPermissionReplyState();

  bool replying(InteractionId id, {SessionRef? owner}) =>
      _handle?.replyState(id, owner: owner).busy ?? false;

  /// Whether this screen's lease can send replies at all. A resident card stays
  /// mounted (disabled) while the lease is not current, so a typed note and the
  /// pending request survive a reconnect instead of disappearing.
  bool get supportsReplies => !_disposed && (_handle?.supportsReplies ?? false);

  /// Manual permission replies need a live, current lease like Stop does, but
  /// never require a running execution: approvals arrive while Turn work runs.
  /// A busy request disables its actions until the stream settles it.
  bool canReply(InteractionRequest request) =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true) &&
      !replying(request.id, owner: _childOwner(request)) &&
      (_handle?.canReply(request) ?? false);

  /// The owning child session of a request shown in this session, if any.
  SessionRef? _childOwner(InteractionRequest request) {
    final owner = request.owner;
    return owner is SessionOwner && owner.session != session
        ? owner.session
        : null;
  }

  Future<void> replyToPermission({
    required InteractionRequest request,
    required ApprovalResponse response,
  }) async {
    final handle = _handle;
    if (!canReply(request) || handle == null) return;
    final generation = _generation;
    final replying = handle.reply(
      request: request,
      response: response,
      id: _commandIds(),
    );
    _notify();
    await replying;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  bool canReplyForm(InteractionRequest request) =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true) &&
      !replying(request.id, owner: _childOwner(request)) &&
      (_handle?.canReplyForm(request) ?? false);

  Future<void> replyToForm({
    required InteractionRequest request,
    required FormAnswers answers,
  }) async {
    final handle = _handle;
    if (!canReplyForm(request) || handle == null) return;
    final generation = _generation;
    final replying = handle.replyForm(
      request: request,
      response: FormResponse(answers),
      id: _commandIds(),
    );
    _notify();
    await replying;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  Future<void> dismissForm({
    required InteractionRequest request,
  }) async {
    final handle = _handle;
    if (!canReplyForm(request) || handle == null) return;
    final generation = _generation;
    final dismissing = handle.dismissForm(
      request: request,
      id: _commandIds(),
    );
    _notify();
    await dismissing;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return;
    }
    _notify();
  }

  Map<String, dynamic> formDraft(InteractionId id, {SessionRef? owner}) =>
      _formDrafts[_noteKey(id, owner)] ?? const <String, dynamic>{};

  void setFormFieldDraft(
    InteractionId id,
    String fieldKey,
    dynamic value, {
    SessionRef? owner,
  }) {
    if (_disposed) return;
    final key = _noteKey(id, owner);
    final current = Map<String, dynamic>.from(_formDrafts[key] ?? const {});
    if (value == null) {
      current.remove(fieldKey);
    } else {
      current[fieldKey] = value;
    }
    if (current.isEmpty) {
      _formDrafts.remove(key);
    } else {
      _formDrafts[key] = current;
    }
    notifyListeners();
  }

  void clearFormDraft(InteractionId id, {SessionRef? owner}) {
    if (_disposed) return;
    _formDrafts.remove(_noteKey(id, owner));
    notifyListeners();
  }

  void _pruneFormDrafts(SessionState? state) {
    if (_formDrafts.isEmpty || state == null) return;
    final resident = {
      for (final r in state.interactions) _noteKey(r.id, _childOwner(r)),
    };
    _formDrafts.removeWhere((key, _) => !resident.contains(key));
  }

  String _noteKey(InteractionId id, SessionRef? owner) =>
      owner != null ? '${owner.nativeId}/${id.value}' : id.value;

  /// Local draft text for a request's rejection note. The card seeds its field
  /// from here and writes every edit back, so an explicit retry or a lease
  /// re-open cannot discard a note the user already typed.
  String permissionNote(InteractionId id, {SessionRef? owner}) =>
      _notes[_noteKey(id, owner)] ?? '';

  void setPermissionNote(
    InteractionId id,
    String value, {
    SessionRef? owner,
  }) {
    if (_disposed) return;
    final key = _noteKey(id, owner);
    if (value.isEmpty) {
      _notes.remove(key);
    } else {
      _notes[key] = value;
    }
  }

  /// Drops drafts whose request left canonical state. A null state means the
  /// lease is being re-opened, so the drafts must survive it.
  void _pruneNotes(SessionState? state) {
    if (_notes.isEmpty || state == null) return;
    final resident = {
      for (final r in state.interactions) _noteKey(r.id, _childOwner(r)),
    };
    _notes.removeWhere((key, _) => !resident.contains(key));
  }

  String? nativeMessageOf(ItemId id) => _handle?.nativeMessageOf(id);
  SessionLivePhase get phase => view?.phase ?? SessionLivePhase.probing;
  bool get loading =>
      opening ||
      const {
        SessionLivePhase.probing,
        SessionLivePhase.connecting,
        SessionLivePhase.hydrating,
      }.contains(view?.phase);

  /// A terminal state the transport will not recover from on its own.
  bool get canRetry =>
      !opening &&
      (failure != null ||
          const {
            SessionLivePhase.degraded,
            SessionLivePhase.authRequired,
            SessionLivePhase.incompatible,
            SessionLivePhase.evicted,
            SessionLivePhase.closed,
          }.contains(view?.phase));

  EndpointCredential? _currentCredential() {
    if (_disposed || hosts.loading || hosts.storageError) return null;
    for (final current in hosts.profiles) {
      if (current.id == profile.id &&
          current.endpoint == profile.endpoint &&
          !hosts.credentialUnreadable(current)) {
        final credential = hosts.credentialFor(current);
        if (credential != null &&
            (credential.expiresAt == null ||
                _now().toUtc().isBefore(credential.expiresAt!))) {
          return credential;
        }
      }
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _detach() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _handle?.close();
    _handle = null;
    _expiry?.cancel();
    _expiry = null;
    opening = false;
  }

  SessionLiveFailure _missingCredential() => hosts.loading || hosts.storageError
      ? SessionLiveFailure.unavailable
      : SessionLiveFailure.authenticationRequired;

  void _hostsChanged() {
    // A reload of the saved servers is not a change of credential; the
    // session is checked against them once they are read again.
    if (_disposed || hosts.loading) return;
    final credential = _currentCredential();
    if (credential == null || _credential?.matches(credential) != true) {
      _detach();
      view = null;
      failure = _missingCredential();
      _notify();
    }
  }

  Future<void> start() async {
    if (_disposed) return;
    _detach();
    final credential = _currentCredential();
    if (credential == null) {
      view = null;
      failure = _missingCredential();
      _notify();
      return;
    }
    _credential = credential;
    failure = null;
    opening = true;
    final generation = _generation;
    _notify();
    try {
      final handle = await directory.open(
        profile: profile,
        credential: credential,
        session: session,
      );
      if (_disposed || generation != _generation) {
        handle.close();
        return;
      }
      if (handle.session != session) {
        handle.close();
        throw const SessionLiveException(
          SessionLiveFailure.incompatibleResponse,
        );
      }
      _handle = handle;
      if (credential.expiresAt case final deadline?) {
        _expiry = Timer(deadline.difference(_now().toUtc()), _hostsChanged);
      }
      _subscription = handle.updates.listen((next) {
        if (_disposed || generation != _generation) return;
        _pruneNotes(next.state);
        _pruneFormDrafts(next.state);
        view = next;
        if (next.phase == SessionLivePhase.evicted) failure = next.failure;
        _notify();
      });
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      failure = error is SessionLiveException
          ? error.failure
          : SessionLiveFailure.connection;
    } finally {
      if (!_disposed && generation == _generation) {
        opening = false;
        _notify();
      }
    }
  }

  /// Opens a fresh lease after a terminal state; reconnecting is the
  /// transport's job, so a live or reconnecting view is left alone.
  Future<void> retry() async {
    if (!canRetry) return;
    view = null;
    await start();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    hosts.removeListener(_hostsChanged);
    permissionModes?.removeListener(_policyChanged);
    _detach();
    super.dispose();
  }
}
