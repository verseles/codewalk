import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, TextEditingValue, TextSelection;

import '../../platform/sessions/workspace_draft_store.dart';
import '../../shared/sessions/command_ids.dart';
import '../../shared/sessions/session_actions.dart';
import '../hosts/endpoint_health_controller.dart';
import 'sessions_controller.dart';

enum WorkspaceDraftNotice {
  none,
  fenceFailed,
  rejected,
  unavailable,
  uncertain,
  unreadable,
}

/// A first-send intent, kept only in this process. A relaunch never replays it.
final class WorkspaceFirstPrompt {
  const WorkspaceFirstPrompt({
    required this.key,
    required this.summary,
    required this.text,
    required this.commandId,
    required this.profile,
  });
  final WorkspaceDraftKey key;
  final SessionSummary summary;
  final String text;
  final CommandId commandId;
  final EndpointProfile profile;
  SessionRef get session => summary.info.ref;
  String get location =>
      Uri(pathSegments: ['', 's', session.host.value, session.nativeId]).path;
}

class WorkspaceDraftController extends ChangeNotifier {
  WorkspaceDraftController({
    required SessionsController catalog,
    required WorkspaceDraftStore store,
    this.health,
    CommandId Function()? commandIds,
  }) : _catalog = catalog,
       _store = store,
       _commandIds = commandIds ?? mintCommandId {
    _catalog.addListener(_catalogChanged);
    health?.addListener(_notify);
    draft.addListener(_draftChanged);
    _catalogChanged();
  }
  final SessionsController _catalog;
  final EndpointHealthController? health;
  EndpointHealthView get endpointHealth {
    final profile = _catalog.selectedProfile;
    return profile == null
        ? const EndpointHealthView()
        : health?.view(profile) ?? const EndpointHealthView();
  }

  bool get endpointOffline =>
      endpointHealth.status == EndpointHealthStatus.offline;
  final WorkspaceDraftStore _store;
  final CommandId Function() _commandIds;
  final draft = TextEditingController();
  final _activeDraftContexts = <WorkspaceDraftKey>{};
  final _unscopedProfiles = <String>{};
  final _unscopedText = <String, String>{};
  WorkspaceDraftKey? _currentKey;
  WorkspaceDraftEntry? _entry;
  WorkspaceDraftNotice _notice = WorkspaceDraftNotice.none;
  WorkspaceFirstPrompt? _handoff;
  String? _profile;
  EndpointProfile? _binding;
  bool _changingBinding = false;
  ({ProjectRef? project})? _choice;
  String _location = '';
  int _intent = 0;
  int _restoreGeneration = 0;
  int _edit = 0;
  bool _sending = false,
      _disposed = false,
      _applyingDraft = false,
      _loading = false;
  String _draftText = '';

  WorkspaceDraftNotice get notice => _notice;
  bool get sending => _sending;
  bool get loading => _loading;
  WorkspaceDraftKey? get currentKey => _currentKey;
  WorkspaceDraftEntry? get entry => _entry;
  WorkspaceDraftStatus get status =>
      _entry?.status ?? WorkspaceDraftStatus.ready;
  bool get isDraftActive => _currentKey != null
      ? _activeDraftContexts.contains(_currentKey)
      : _profile != null && _unscopedProfiles.contains(_profile);
  bool get needsDirectory => _currentKey == null;
  bool _focusPending = false;

  /// Asks the draft composer for focus once, even when its page is built
  /// only after the request; a launch on a draft never raises the keyboard.
  void focusComposer() {
    if (_disposed) return;
    _focusPending = true;
    _notify();
  }

  /// Takes the pending focus request, so it is honoured once.
  bool takeFocusRequest() {
    final pending = _focusPending;
    _focusPending = false;
    return pending;
  }

  bool get canSend =>
      isDraftActive &&
      _currentKey != null &&
      !_loading &&
      !_sending &&
      !endpointOffline &&
      _catalog.hosts.pendingBindingChange != _profile &&
      status == WorkspaceDraftStatus.ready &&
      !_store.isUnreadable(_currentKey!) &&
      draft.text.trim().isNotEmpty &&
      (_location.isEmpty || _location == '/' || _location == '/sessions') &&
      !_catalog.loading &&
      _catalog.createReason == SessionActionReason.none;

  WorkspaceDraftKey? _deriveKey([String? directory]) {
    final profile = _catalog.selectedProfile;
    if (profile == null) return null;
    final dir =
        directory ??
        _catalog.chosenProject?.project?.canonicalDirectory ??
        _catalog.selectedProject?.project?.canonicalDirectory;
    if (dir == null || dir.isEmpty) return null;
    return WorkspaceDraftKey(
      profileId: profile.id,
      harnessId: profile.id,
      canonicalDirectory: dir,
    );
  }

  Future<void> openDraft({String? directory}) async {
    if (_disposed || _catalog.selectedProfile == null || _sending) return;
    final carry = _currentKey == null ? draft.text : '';
    _intent++;
    _handoff = null;
    _restoreGeneration++;
    _setCurrentKey(_deriveKey(directory));
    _entry = null;
    _profile = _catalog.selectedProfile?.id;
    _choice = _catalog.chosenProject;
    _notice = WorkspaceDraftNotice.none;
    final key = _currentKey;
    if (key == null) {
      _unscopedProfiles.add(_profile!);
      _loading = false;
      _notify();
      return;
    }
    _activeDraftContexts.add(key);
    _loading = true;
    _notify();
    await _restoreDraft(key, carry: carry);
  }

  void exitDraft() {
    if (_disposed) return;
    _intent++;
    _restoreGeneration++;
    _loading = false;
    _handoff = null;
    if (_currentKey != null) _activeDraftContexts.remove(_currentKey);
    if (_profile != null) _unscopedProfiles.remove(_profile);
    _notice = WorkspaceDraftNotice.none;
    _notify();
  }

  /// Capture the incoming URI in the router's synchronous intent listener.
  /// The one route change caused by binding is allowed; any other navigation
  /// invalidates the pending send even when it returns to the same context.
  void locationChanged(String location) {
    if (_disposed || location == _location) return;
    _location = location;
    if (_handoff?.location == location) return;
    _intent++;
    _handoff = null;
    if (location.startsWith('/s/')) {
      if (_currentKey != null) _activeDraftContexts.remove(_currentKey);
      if (_profile != null) _unscopedProfiles.remove(_profile);
    }
  }

  WorkspaceFirstPrompt? firstPromptFor(SessionRef ref) =>
      _handoff?.session == ref && _handoff?.location == _location
      ? _handoff
      : null;
  bool owns(WorkspaceFirstPrompt handoff) =>
      identical(_handoff, handoff) &&
      !endpointOffline &&
      !_catalog.hosts.loading &&
      !_catalog.hosts.storageError &&
      _catalog.hosts.pendingBindingChange != handoff.profile.id &&
      _catalog.selectedProfile?.sameBinding(handoff.profile) == true &&
      _location == handoff.location &&
      _currentKey == handoff.key;

  Future<void> finishHandoff(
    WorkspaceFirstPrompt handoff, {
    required bool recorded,
  }) async {
    if (identical(_handoff, handoff)) _handoff = null;
    if (recorded) {
      await _store.finishAttempt(
        handoff.key,
        handoff.commandId.value,
        handoff.text,
      );
    }
    if (!_disposed && _currentKey == handoff.key) {
      final generation = _restoreGeneration;
      final entry = await _store.read(handoff.key);
      if (!_disposed &&
          _currentKey == handoff.key &&
          generation == _restoreGeneration) {
        _entry = entry;
        _notify();
      }
    }
  }

  Future<void> flush() => _store.flush();

  void _catalogChanged() {
    if (_disposed) return;
    final selected = _catalog.selectedProfile;
    final profile = selected?.id;
    final changing =
        profile != null && _catalog.hosts.pendingBindingChange == profile;
    final invalidated =
        (changing && !_changingBinding) ||
        (_binding != null &&
            selected != null &&
            !_binding!.sameBinding(selected));
    if (invalidated) {
      _intent++;
      _handoff = null;
    }
    _changingBinding = changing;
    _binding = selected;
    final choice = _catalog.chosenProject;
    // A changed row order or a temporarily absent group is not a context
    // switch. Only an explicit choice or another server changes a draft.
    final changed =
        profile != _profile || (choice != null && choice != _choice);
    if (!changed && (isDraftActive || _handoff != null)) {
      if (invalidated) _notify();
      return;
    }
    final key = _deriveKey();
    if (profile == _profile && key == _currentKey) return;
    if (_profile != null && _currentKey == null) {
      _unscopedText[_profile!] = draft.text;
    }
    unawaited(_store.flush());
    _intent++;
    _handoff = null;
    _profile = profile;
    _choice = choice;
    _restoreGeneration++;
    _setCurrentKey(key);
    _entry = null;
    _notice = WorkspaceDraftNotice.none;
    _setText(key == null ? _unscopedText[profile] ?? '' : '');
    if (key != null && _activeDraftContexts.contains(key)) {
      _loading = true;
      unawaited(_restoreDraft(key));
    } else {
      _loading = false;
    }
    _notify();
  }

  void _setText(String text) {
    _applyingDraft = true;
    draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _draftText = text;
    _applyingDraft = false;
  }

  void _setCurrentKey(WorkspaceDraftKey? key) {
    final previous = _currentKey;
    if (previous != null) _store.detach(previous, _draftForgotten);
    _currentKey = key;
    if (key != null) _store.attach(key, _draftForgotten);
  }

  void _draftForgotten(String text) {
    if (_disposed || draft.text != text) return;
    _setText('');
    _notify();
  }

  Future<void> _restoreDraft(WorkspaceDraftKey key, {String carry = ''}) async {
    final edit = _edit;
    final generation = _restoreGeneration;
    final entry = await _store.read(key);
    if (_disposed || _currentKey != key || generation != _restoreGeneration) {
      return;
    }
    _entry = entry;
    _loading = false;
    if (edit == _edit) _setText(entry?.text ?? carry);
    if (_store.isUnreadable(key)) _notice = WorkspaceDraftNotice.unreadable;
    if (entry == null && carry.isNotEmpty) _store.save(key, carry);
    _notify();
  }

  void _draftChanged() {
    final text = draft.text;
    if (text == _draftText) return;
    _draftText = text;
    if (_applyingDraft || _disposed) return;
    _edit++;
    final key = _currentKey;
    if (key != null) {
      _store.save(key, text);
    } else if (_profile != null) {
      _unscopedText[_profile!] = text;
    }
    _notify();
  }

  Future<void> discardAttempt() async {
    final key = _currentKey;
    if (key == null || _disposed || _sending) return;
    final intent = ++_intent;
    _handoff = null;
    if (!await _store.updateStatus(key, WorkspaceDraftStatus.ready)) {
      if (!_disposed && _currentKey == key && intent == _intent) {
        _notice = WorkspaceDraftNotice.fenceFailed;
        _notify();
      }
      return;
    }
    if (_disposed || _currentKey != key || intent != _intent) return;
    final entry = await _store.read(key);
    if (_disposed || _currentKey != key || intent != _intent) return;
    _entry = entry;
    _notice = WorkspaceDraftNotice.none;
    _notify();
  }

  Future<bool> sendFirstPrompt({
    required void Function(
      SessionRef session,
      String prompt,
      CommandId commandId,
    )
    onBound,
  }) async {
    final key = _currentKey;
    final profile = _catalog.selectedProfile;
    if (!canSend || key == null || profile == null || _disposed) return false;
    final intent = _intent;
    final credential = _catalog.hosts.credentialFor(profile);
    bool wanted() =>
        !_disposed &&
        !endpointOffline &&
        _intent == intent &&
        _currentKey == key &&
        isDraftActive &&
        _catalog.selectedProfile?.sameBinding(profile) == true &&
        _catalog.hosts.pendingBindingChange != profile.id &&
        !_catalog.hosts.loading &&
        credential?.matches(_catalog.hosts.credentialFor(profile)) == true;
    final text = draft.text;
    final id = _commandIds();
    _sending = true;
    _notice = WorkspaceDraftNotice.none;
    _notify();
    try {
      if (!await _store.setAttemptFence(key, commandId: id.value, text: text)) {
        if (wanted()) _notice = WorkspaceDraftNotice.fenceFailed;
        return false;
      }
      if (!wanted()) {
        await _store.updateStatus(key, WorkspaceDraftStatus.ready);
        return false;
      }
      _entry = await _store.read(key);
      _notify();
      if (!wanted()) {
        await _store.updateStatus(key, WorkspaceDraftStatus.ready);
        return false;
      }
      final result = await _catalog.create(directory: key.canonicalDirectory);
      final ref = result.session;
      if (result.outcome != SessionActionOutcome.accepted ||
          ref == null ||
          ref.host.value != key.profileId ||
          ref.harness.value != key.harnessId) {
        final state =
            const {
              SessionActionOutcome.rejected,
              SessionActionOutcome.unavailable,
            }.contains(result.outcome)
            ? WorkspaceDraftStatus.failed
            : WorkspaceDraftStatus.uncertain;
        await _store.updateStatus(key, state);
        if (wanted()) {
          _entry = await _store.read(key);
          _notice = state == WorkspaceDraftStatus.uncertain
              ? WorkspaceDraftNotice.uncertain
              : result.outcome == SessionActionOutcome.rejected
              ? WorkspaceDraftNotice.rejected
              : WorkspaceDraftNotice.unavailable;
        }
        return false;
      }
      if (!await _store.updateStatus(
        key,
        WorkspaceDraftStatus.confirming,
        createdSession: ref,
      )) {
        if (wanted()) _notice = WorkspaceDraftNotice.fenceFailed;
        return false;
      }
      if (!wanted()) {
        await _store.updateStatus(key, WorkspaceDraftStatus.uncertain);
        return false;
      }
      final task = _catalog.read(ref);
      SessionSummary? summary;
      try {
        summary = await task?.result;
      } on Object {
        /* Keep the fenced text. */
      }
      if (summary?.info.ref != ref || !wanted()) {
        await _store.updateStatus(key, WorkspaceDraftStatus.uncertain);
        if (wanted()) {
          _entry = await _store.read(key);
          _notice = WorkspaceDraftNotice.uncertain;
        }
        return false;
      }
      if (!await _store.updateStatus(
            key,
            WorkspaceDraftStatus.bound,
            createdSession: ref,
          ) ||
          !wanted()) {
        return false;
      }
      _entry = await _store.read(key);
      if (!wanted()) return false;
      _handoff = WorkspaceFirstPrompt(
        key: key,
        summary: summary!,
        text: text,
        commandId: id,
        profile: profile,
      );
      _activeDraftContexts.remove(key);
      onBound(ref, text, id);
      return true;
    } on Object {
      await _store.updateStatus(key, WorkspaceDraftStatus.uncertain);
      if (wanted()) {
        _entry = await _store.read(key);
        _notice = WorkspaceDraftNotice.uncertain;
      }
      return false;
    } finally {
      if (!_disposed && _currentKey == key && isDraftActive) {
        final current = await _store.read(key);
        if (!_disposed && _currentKey == key) _entry = current;
      }
      _sending = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _intent++;
    _restoreGeneration++;
    _handoff = null;
    if (_currentKey case final key?) _store.detach(key, _draftForgotten);
    unawaited(_store.flush());
    _catalog.removeListener(_catalogChanged);
    health?.removeListener(_notify);
    draft.removeListener(_draftChanged);
    draft.dispose();
    super.dispose();
  }
}
