import 'dart:async';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, TextEditingValue, TextSelection;
import '../../platform/sessions/model_preference_store.dart';
import '../../platform/sessions/session_draft_store.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_permission_reply.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/sessions/session_turn_actions.dart';
import '../../shared/sessions/session_unrestricted.dart';
import '../hosts/endpoint_health_controller.dart';
import '../hosts/hosts_controller.dart';
import 'session_composer_controller.dart';
import 'session_input_history.dart';
import 'session_live_scroll.dart';
import 'session_selection_cycle.dart';
import 'session_selection_memory.dart';

/// Owns one screen's live lease. Prompts and Stop require explicit user actions;
/// observing, reconnecting and closing never mutate the server.
class SessionLiveController extends ChangeNotifier {
  SessionLiveController({
    required this.hosts,
    required this.profile,
    required SessionSummary summary,
    required this.directory,
    this.health,
    this.permissionModes,
    this.drafts,
    this.modelPreferences,
    DateTime Function()? now,
    CommandId Function()? commandIds,
  }) : _summary = summary,
       _now = now ?? DateTime.now,
       _commandIds = commandIds ?? mintCommandId {
    hosts.addListener(_hostsChanged);
    health?.addListener(_notify);
    permissionModes?.addListener(_policyChanged);
    modelPreferences?.addListener(_notify);
    draft.addListener(_draftChanged);
    drafts?.attach(session, _draftForgotten);
    unawaited(_restoreDraft());
  }
  final HostsController hosts;
  final EndpointHealthController? health;
  EndpointHealthView get endpointHealth =>
      health?.view(profile) ?? const EndpointHealthView();
  bool get endpointOffline =>
      endpointHealth.status == EndpointHealthStatus.offline;
  final EndpointProfile profile;
  String get profileLabel =>
      hosts.profiles
          .where((saved) => saved.sameBinding(profile))
          .firstOrNull
          ?.label ??
      profile.label;
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

  /// The timeline's place and follow state, kept with the session so a view
  /// shown again resumes where the reader left it.
  final scroll = SessionLiveScroll();

  /// The unsent prompt, kept with the session so switching tabs keeps it,
  /// and saved on this device through [drafts] so a relaunch restores it.
  final draft = TextEditingController();

  /// Where the session's draft is saved, when the app graph provides it.
  final SessionDraftStore? drafts;
  String _draftText = '';
  bool _draftEdited = false;
  bool _draftRead = false;
  bool _applyingDraft = false;

  /// Whether the saved draft was read, or there is none to read: recalling
  /// a sent prompt before that would hide it.
  bool get draftSettled => drafts == null || _draftRead;

  /// The composer's state, kept with the session so a send that ends after
  /// its screen closed still clears the prompt it sent.
  SessionComposerController get composer =>
      _composer ??= SessionComposerController(live: this);
  SessionComposerController? _composer;

  /// The stored draft is shown once it is read, unless the user has typed
  /// meanwhile: what they typed is theirs, and is saved from the first key.
  Future<void> _restoreDraft() async {
    final drafts = this.drafts;
    if (drafts == null) return;
    final text = await drafts.read(session);
    _draftRead = true;
    if (_disposed) return;
    if (!_draftEdited && text != null && draft.text.isEmpty) {
      _applyingDraft = true;
      draft.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _applyingDraft = false;
    }
    _notify();
  }

  void _draftChanged() {
    final text = draft.text;
    // A caret or selection move is not an edit.
    if (text == _draftText) return;
    _draftText = text;
    recall.changed(text);
    if (_applyingDraft) return;
    _draftEdited = true;
    // Saved before the stored draft is read too: the store reads first and
    // never writes over a record it could not read.
    drafts?.save(session, text);
  }

  /// A prompt sent after an earlier screen of this session closed was shown
  /// here again from the saved draft: it leaves the field unless edited.
  void _draftForgotten(String text) {
    if (!_disposed && draft.text == text) draft.clear();
  }

  /// A prompt the outbox took after the session's screen closed must not
  /// come back as its draft.
  void forgetDraft(String text) => drafts?.forget(session, text);

  /// Up and Down through the session's sent prompts, kept with the session
  /// so a tab shown again is still where it was. A recalled prompt is not
  /// saved as the draft: the saved draft stays what the user was writing.
  late final recall = SessionInputRecall(
    show: (value) {
      _applyingDraft = true;
      draft.value = value;
      _applyingDraft = false;
    },
  );

  /// True once disposed; a disposed view is never shown again.
  bool get disposed => _disposed;
  final SessionLiveDirectory directory;

  /// The acknowledged permission policy for this session, when the app graph
  /// provides one. The controller never owns or disposes it.
  final EditablePermissionModePolicy? permissionModes;
  final DateTime Function() _now;

  /// The clock a reported wait, such as a retry's, is counted down with.
  DateTime Function() get clock => _now;
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
  SessionTurnActionPort? get turnActions => _handle?.turnActions;
  SessionStopState get stopState =>
      _handle?.stopState ?? const SessionStopState();
  bool get stopping => stopState.busy;
  bool get canStop =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true) &&
      // A retry wait is still the same execution, so it can be stopped too.
      switch (state?.execution?.kind.known) {
        ExecutionKind.running || ExecutionKind.retrying => true,
        _ => false,
      } &&
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

  bool get _liveCurrent =>
      !_disposed &&
      !opening &&
      _credential?.matches(_currentCredential()) == true &&
      phase == SessionLivePhase.live &&
      !(view?.stale ?? true);

  bool get canEnableUnrestricted =>
      _liveCurrent && (_handle?.canEnableUnrestricted ?? false);
  bool get canDisableUnrestricted =>
      _liveCurrent && (_handle?.canDisableUnrestricted ?? false);
  bool get canRefreshUnrestricted =>
      _liveCurrent && (_handle?.canRefreshUnrestricted ?? false);

  Future<void> enableUnrestricted() => _act(
    canEnableUnrestricted,
    (handle) => handle.enableUnrestricted(id: _commandIds()),
  );

  Future<void> disableUnrestricted() => _act(
    canDisableUnrestricted,
    (handle) => handle.disableUnrestricted(id: _commandIds()),
  );

  Future<void> refreshUnrestricted() =>
      _act(canRefreshUnrestricted, (handle) => handle.refreshUnrestricted());

  /// True when [action] ran and its lease is still this view's.
  Future<bool> _act(
    bool allowed,
    Future<void> Function(SessionLiveHandle) action,
  ) async {
    final handle = _handle;
    if (!allowed || handle == null) return false;
    final generation = _generation;
    final running = action(handle);
    _notify();
    await running;
    if (_disposed || generation != _generation || !identical(handle, _handle)) {
      return false;
    }
    _notify();
    return true;
  }

  /// The session's model and agent. A pending or unconfirmed change holds
  /// this session's sends; the prompt itself never carries a selection.
  bool get supportsSelection =>
      !_disposed && (_handle?.supportsSelection ?? false);
  SessionSelectionState get selectionState =>
      _handle?.selectionState ??
      SessionSelectionState(selection: state?.selection);

  /// A sub-conversation runs with what its parent chose: its own selection
  /// is shown, never changed here.
  bool get isChild => _summary.info.lineage.parent != null;

  bool get canChangeSelection =>
      _liveCurrent && !isChild && (_handle?.canChangeSelection ?? false);

  /// The command id is taken with the gesture, for this lease's session.
  /// A switch the server took is remembered (recents, each agent's model),
  /// also when an unconfirmed switch is settled later.
  Future<void> selectModel(ModelEntry model, {String? variant}) => _switch(
    (project, before) => PendingSelectionSwitch.model(
      model,
      variant,
      project: project,
      before: before,
    ),
    (handle) => handle.selectModel(
      modelId: model.id,
      providerId: model.providerId,
      variant: variant,
      id: _commandIds(),
    ),
  );

  /// Switching to an agent restores the model it last used in this project,
  /// with its variant when the model still lists it (#181), once the server
  /// reports the switch and a next one can be sent. A model changed since
  /// the switch began (by the server with the agent, or by another client),
  /// a refusal, another lease or a newer pick cancels it.
  Future<void> selectAgent(CatalogEntry agent) async {
    final before = selectionState.selection;
    final revision = _modelRevision;
    final generation = _generation;
    final attempt = await _switch(
      (project, before) =>
          PendingSelectionSwitch.agent(agent, project: project, before: before),
      (handle) => handle.selectAgent(agentId: agent.id, id: _commandIds()),
    );
    if (attempt == null ||
        attempt != _switchAttempt ||
        generation != _generation) {
      return;
    }
    _restore = (
      agent: agent.id,
      before: before,
      revision: revision,
      attempt: attempt,
      generation: generation,
    );
    await _restoreAgentModel();
  }

  /// An agent switch the server took, until its model is restored.
  ({
    String agent,
    Selection? before,
    int revision,
    int attempt,
    int generation,
  })?
  _restore;

  /// Counts the model changes this view observed, so a model set and then
  /// set back during an agent switch still cancels its restore.
  int _modelRevision = 0;
  (String?, String?, String?)? _seenModel;

  /// Reads each delivered view's own selection: updates arrive after the
  /// fact, so the latest state could hide a model set and set back.
  void _observeModel(Selection? selection) {
    if (selection == null) return;
    final model = (
      selection.modelProviderId,
      selection.modelId,
      selection.modelVariant,
    );
    if (_seenModel != null && _seenModel != model) _modelRevision++;
    _seenModel = model;
  }

  Future<void> _restoreAgentModel() async {
    final restore = _restore;
    if (restore == null || _disposed) return;
    final state = selectionState;
    final now = state.selection;
    final before = restore.before;
    if (restore.attempt != _switchAttempt ||
        restore.generation != _generation ||
        restore.revision != _modelRevision ||
        state.notice != SessionSelectionNotice.none ||
        now?.agentId != restore.agent ||
        now?.modelId != before?.modelId ||
        now?.modelProviderId != before?.modelProviderId ||
        now?.modelVariant != before?.modelVariant) {
      _restore = null;
      return;
    }
    // A switch the server took waits for its report before the next one.
    if (!canChangeSelection) return;
    _restore = null;
    final project = _project;
    final memory = project == null
        ? null
        : modelPreferences?.agentModel(profile.id, project, restore.agent);
    if (memory == null) return;
    final (key, remembered) = memory;
    final model = state.models
        .where((m) => modelPreferenceKey(m.providerId, m.id) == key)
        .firstOrNull;
    if (model == null) return;
    final variant = remembered != null && model.variants.contains(remembered)
        ? remembered
        : null;
    if (selectionModelKey(now) == key && now?.modelVariant == variant) return;
    await selectModel(model, variant: variant);
  }

  /// Sends one switch; returns its attempt when it was sent and settled
  /// accepted at once, null otherwise.
  Future<int?> _switch(
    PendingSelectionSwitch Function(String project, Selection? before) pending,
    Future<void> Function(SessionLiveHandle) action,
  ) async {
    final allowed = canChangeSelection;
    // Only a pick that sends a switch replaces the one waiting to settle,
    // and an earlier pick that ends after a newer one replaces nothing.
    final attempt = allowed ? ++_switchAttempt : _switchAttempt;
    final project = _project;
    final before = selectionState.selection;
    final sent = await _act(allowed, action);
    if (!sent || attempt != _switchAttempt) return null;
    _pending = project == null ? null : pending(project, before);
    return await _settleSwitch() ? attempt : null;
  }

  /// The last switch this lease sent, until it settles.
  PendingSelectionSwitch? _pending;
  int _switchAttempt = 0;

  /// True when the waiting switch settled as the server taking it.
  Future<bool> _settleSwitch() async {
    final pending = _pending;
    if (pending == null || _disposed) return false;
    final state = selectionState;
    if (state.holdsSend) return false;
    _pending = null;
    final selection = state.selection;
    if (state.notice != SessionSelectionNotice.none ||
        selection == null ||
        !pending.settledIn(selection)) {
      return false;
    }
    final store = modelPreferences;
    if (store != null) await pending.remember(store, profile.id, selection);
    return true;
  }

  /// Alt+Tab-style cycling of the model, agent and variant (#178, #179).
  late final _cycle = SelectionCycle(now: _now);

  /// The next model: favorites, then recents, then the current provider's
  /// models, like the retained reference's `mod+m`.
  Future<void> cycleModel() async {
    if (!canChangeSelection) return;
    final state = selectionState;
    final current = selectionModelKey(state.selection);
    final provider = state.selection?.modelProviderId;
    final offered = {
      for (final m in state.models) modelPreferenceKey(m.providerId, m.id): m,
    };
    final own = state.models.where((m) => m.providerId == provider).toList()
      ..sort((a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()));
    final next = _cycle.next(
      SelectionCycleDomain.model,
      current: current,
      candidates: [
        ...favoriteModels,
        ...recentModels,
        for (final m in own) modelPreferenceKey(m.providerId, m.id),
      ].where(offered.containsKey).toList(),
      history: recentModels,
    );
    final model = offered[next];
    if (model == null || next == current) return;
    await selectModel(model);
  }

  /// The next variant of the current model, Auto among them (`mod+t`).
  Future<void> cycleVariant() async {
    if (!canChangeSelection) return;
    final state = selectionState;
    final key = selectionModelKey(state.selection);
    final model = state.models
        .where((m) => modelPreferenceKey(m.providerId, m.id) == key)
        .firstOrNull;
    final project = _project;
    if (model == null || key == null || model.variants.isEmpty) return;
    const auto = ModelPreferenceStore.autoVariant;
    final current = state.selection?.modelVariant ?? auto;
    final next = _cycle.next(
      SelectionCycleDomain.variant,
      current: current,
      candidates: [auto, ...model.variants],
      history: project == null
          ? const []
          : modelPreferences?.variantRecents(profile.id, project, key) ??
                const [],
    );
    if (next == null || next == current) return;
    await selectModel(model, variant: next == auto ? null : next);
  }

  /// The next agent, or the previous one with [reverse].
  Future<void> cycleAgent({bool reverse = false}) async {
    if (!canChangeSelection) return;
    final state = selectionState;
    final project = _project;
    final current = state.selection?.agentId;
    final next = _cycle.next(
      SelectionCycleDomain.agent,
      current: current,
      candidates: [for (final a in state.agents) a.id],
      history: project == null
          ? const []
          : modelPreferences?.agentRecents(profile.id, project) ?? const [],
      reverse: reverse,
    );
    final agent = state.agents.where((a) => a.id == next).firstOrNull;
    if (agent == null || next == current) return;
    await selectAgent(agent);
  }

  /// Where the favorite and recent models are kept on this device, when the
  /// app graph provides it. The controller never owns or disposes it.
  final ModelPreferenceStore? modelPreferences;

  /// How [modelPreferences] names a model.
  static String modelKey(ModelEntry model) =>
      modelPreferenceKey(model.providerId, model.id);

  /// Recents are kept per project of this server.
  String? get _project =>
      state?.info?.project?.canonicalDirectory ??
      _summary.info.project?.canonicalDirectory;

  /// This server's favorite models, in the order they were starred.
  List<String> get favoriteModels =>
      modelPreferences?.favorites(profile.id) ?? const [];

  /// This project's recent models, newest first.
  List<String> get recentModels => switch (_project) {
    final project? =>
      modelPreferences?.recents(profile.id, project) ?? const [],
    null => const [],
  };

  /// A star can be saved now.
  bool get canFavoriteModels => modelPreferences?.writable ?? false;

  /// Stars or unstars [model] for this server; false when it was not saved.
  Future<bool> setFavoriteModel(ModelEntry model, {required bool favorite}) =>
      modelPreferences?.setFavorite(
        profile.id,
        modelKey(model),
        favorite: favorite,
      ) ??
      Future.value(false);

  Future<void> refreshSelection() => _act(
    _liveCurrent && supportsSelection,
    (handle) => handle.refreshSelection(),
  );

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

  Future<void> dismissForm({required InteractionRequest request}) async {
    final handle = _handle;
    if (!canReplyForm(request) || handle == null) return;
    final generation = _generation;
    final dismissing = handle.dismissForm(request: request, id: _commandIds());
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

  void setPermissionNote(InteractionId id, String value, {SessionRef? owner}) {
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
      if (current.sameBinding(profile) &&
          hosts.pendingBindingChange != profile.id &&
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
    // Another lease starts without this one's switch: it settles nothing.
    _pending = null;
    _restore = null;
    _seenModel = null;
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
    if (_disposed) return;
    if (hosts.pendingBindingChange == profile.id ||
        (!hosts.loading &&
            !hosts.storageError &&
            hosts.profiles.any((saved) => saved.id == profile.id) &&
            !hosts.isCurrentProfile(profile))) {
      _detach();
      view = null;
      failure = SessionLiveFailure.sourceChanged;
      _notify();
      return;
    }
    if (hosts.loading) return;
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
        _observeModel(next.state?.selection);
        unawaited(_settleSwitch());
        unawaited(_restoreAgentModel());
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
    health?.removeListener(_notify);
    permissionModes?.removeListener(_policyChanged);
    modelPreferences?.removeListener(_notify);
    _detach();
    scroll.dispose();
    _composer?.dispose();
    draft.removeListener(_draftChanged);
    drafts?.detach(session, _draftForgotten);
    unawaited(drafts?.flush());
    draft.dispose();
    super.dispose();
  }
}
