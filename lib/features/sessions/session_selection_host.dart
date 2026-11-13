import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../platform/sessions/model_preference_store.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/sessions/session_unrestricted.dart';

/// What the composer's agent, model and variant chips and their menus read
/// and change: an open session, or a New Chat draft that applies its pick
/// when its first send creates the session.
abstract interface class SessionSelectionHost implements Listenable {
  bool get supportsSelection;
  bool get canChangeSelection;
  SessionSelectionState get selectionState;

  /// A sub-conversation shows its parent's choice and changes nothing.
  bool get isChild;

  Future<void> refreshSelection();
  Future<void> selectModel(ModelEntry model, {String? variant});
  Future<void> selectAgent(CatalogEntry agent);

  ModelPreferenceStore? get modelPreferences;
  List<String> get favoriteModels;
  List<String> get recentModels;
  bool get canFavoriteModels;
  Future<bool> setFavoriteModel(ModelEntry model, {required bool favorite});

  /// Permission requests waiting for the user, counted on the agent chip.
  int get pendingPermissions;

  /// Null when this host has no per-session permission mode.
  EditablePermissionModePolicy? get permissionModes;
  SessionPermissionModeState get permissionModeState;
  bool get savingPermissionMode;
  bool get canChangePermissionMode;
  Future<bool> setPermissionMode(PermissionMode mode);
  bool get supportsUnrestricted;
  SessionUnrestrictedState get unrestrictedState;

  /// The session's own allow-everything rule, which the permission switch
  /// writes where the server holds it (ADR-059, amended for #494).
  bool get canEnableUnrestricted;
  bool get canDisableUnrestricted;
  bool get canRefreshUnrestricted;
  Future<void> enableUnrestricted();
  Future<void> disableUnrestricted();
  Future<void> refreshUnrestricted();
}
