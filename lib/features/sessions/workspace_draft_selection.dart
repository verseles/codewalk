import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../platform/sessions/model_preference_store.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/sessions/session_unrestricted.dart';
import 'session_live_controller.dart';
import 'session_selection_host.dart';

/// A New Chat draft's agent, model and variant, picked with the same chips
/// and menus as an open session. Nothing reaches the server before the first
/// send, which creates the session with [selection].
final class WorkspaceDraftSelection extends ChangeNotifier
    implements SessionSelectionHost {
  WorkspaceDraftSelection({
    required bool Function() canChange,
    required Future<void> Function() refresh,
    required String? Function() profileId,
    required String? Function() project,
    this.modelPreferences,
  }) : _canChange = canChange,
       _refresh = refresh,
       _profileId = profileId,
       _project = project {
    modelPreferences?.addListener(_notify);
  }

  final bool Function() _canChange;
  final Future<void> Function() _refresh;
  final String? Function() _profileId;
  final String? Function() _project;
  DraftDefaults _defaults = const DraftDefaults();
  Selection? _picked;
  bool _loading = false;
  bool _disposed = false;

  @override
  final ModelPreferenceStore? modelPreferences;

  /// What the first send applies: the user's pick, else the defaults.
  Selection? get selection => _picked ?? _defaults.selection;

  /// New defaults for a newly opened draft or location drop an earlier pick.
  void reset(DraftDefaults defaults, {required bool loading}) {
    _defaults = defaults;
    _picked = null;
    _loading = loading;
    _notify();
  }

  /// The lists of the same draft read again keep what the chips show: the
  /// user's pick, or the defaults shown so far, so a send never applies a
  /// selection the user did not see.
  void refreshed(DraftDefaults defaults) {
    _picked ??= _defaults.selection;
    _defaults = defaults;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    modelPreferences?.removeListener(_notify);
    super.dispose();
  }

  @override
  bool get supportsSelection => true;

  @override
  bool get canChangeSelection =>
      !_loading && _defaults.agents.isNotEmpty && _canChange();

  @override
  SessionSelectionState get selectionState => SessionSelectionState(
    selection: _loading ? null : selection,
    models: _defaults.models,
    agents: _defaults.agents,
    providers: _defaults.providers,
    loading: _loading,
    modelUnavailable: !_loading && _defaults.models.isEmpty
        ? SessionSelectionUnavailable.emptyCatalog
        : null,
    agentUnavailable: !_loading && _defaults.agents.isEmpty
        ? SessionSelectionUnavailable.emptyCatalog
        : null,
  );

  @override
  bool get isChild => false;

  @override
  Future<void> refreshSelection() => _refresh();

  @override
  Future<void> selectModel(ModelEntry model, {String? variant}) async {
    if (!canChangeSelection) return;
    _picked = Selection(
      agentId: selection?.agentId,
      modelId: model.id,
      modelProviderId: model.providerId,
      modelVariant: variant,
    );
    _notify();
  }

  /// An agent brings the model it runs with, as the server would apply it.
  @override
  Future<void> selectAgent(CatalogEntry agent) async {
    if (!canChangeSelection) return;
    _picked = _defaults.agentModels[agent.id] ?? Selection(agentId: agent.id);
    _notify();
  }

  @override
  List<String> get favoriteModels => switch (_profileId()) {
    final profile? => modelPreferences?.favorites(profile) ?? const [],
    null => const [],
  };

  @override
  List<String> get recentModels => switch ((_profileId(), _project())) {
    (final profile?, final project?) =>
      modelPreferences?.recents(profile, project) ?? const [],
    _ => const [],
  };

  @override
  bool get canFavoriteModels =>
      _profileId() != null && (modelPreferences?.writable ?? false);

  @override
  Future<bool> setFavoriteModel(ModelEntry model, {required bool favorite}) =>
      switch (_profileId()) {
        final profile? =>
          modelPreferences?.setFavorite(
                profile,
                SessionLiveController.modelKey(model),
                favorite: favorite,
              ) ??
              Future.value(false),
        null => Future.value(false),
      };

  /// A draft has no permission requests and no session to hold a mode yet.
  @override
  int get pendingPermissions => 0;
  @override
  EditablePermissionModePolicy? get permissionModes => null;
  @override
  SessionPermissionModeState get permissionModeState =>
      const SessionPermissionModeState.unavailable('noSession');
  @override
  bool get savingPermissionMode => false;
  @override
  bool get canChangePermissionMode => false;
  @override
  Future<bool> setPermissionMode(PermissionMode mode) => Future.value(false);
  @override
  bool get supportsUnrestricted => false;
  @override
  SessionUnrestrictedState get unrestrictedState =>
      const SessionUnrestrictedState();

  @override
  bool get canEnableUnrestricted => false;

  @override
  bool get canDisableUnrestricted => false;

  @override
  bool get canRefreshUnrestricted => false;

  @override
  Future<void> enableUnrestricted() async {}

  @override
  Future<void> disableUnrestricted() async {}

  @override
  Future<void> refreshUnrestricted() async {}
}
