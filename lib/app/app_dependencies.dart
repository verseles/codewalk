import 'dart:async';

import 'package:go_router/go_router.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/hosts/hosts_controller.dart';
import '../features/pairing/pairing_controller.dart';
import '../features/sessions/project_contexts_controller.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/workspace_draft_controller.dart';
import '../features/settings/release_history_controller.dart';
import '../features/settings/update_check_controller.dart';
import '../platform/pairing/native_pairing_links.dart';
import '../platform/sessions/hidden_session_store.dart';
import '../platform/sessions/permission_mode_store.dart';
import '../platform/sessions/session_draft_store.dart';
import '../platform/sessions/unrestricted_ownership_store.dart';
import '../shared/diagnostics/diagnostics_controller.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/sessions/session_history_source.dart';
import '../shared/sessions/session_live_source.dart';
import 'app_navigation_controller.dart';
import 'app_preferences_controller.dart';
import 'live_wake.dart';
import 'workspace_chrome_controller.dart';
import 'workspace_controller.dart';

/// Explicit graph passed to the app, with one owner for its lifetime.
class AppDependencies {
  AppDependencies({
    required this.preferences,
    required this.navigation,
    required this.localizations,
    required this.router,
    required this.hosts,
    this.endpointHealth,
    this.workspaceChrome,
    this.pairing,
    this.diagnostics,
    this.releaseHistory,
    this.updates,
    this.sessions,
    this.historyFactory,
    this.liveDirectory,
    this.disposeProfileBindings,
    this.liveWake,
    this.permissionModes,
    this.unrestrictedOwnership,
    this.hiddenSessions,
    this.sessionTabs,
    this.workspace,
    this.sessionDrafts,
    this.workspaceDrafts,
    this.projectContexts,
  }) {
    router.routeInformationProvider.addListener(_routeChanged);
    _routeChanged();
  }

  void _routeChanged() {
    final location = router.routeInformationProvider.value.uri.path;
    workspaceDrafts?.locationChanged(location);
    workspaceChrome?.locationChanged(location);
    // The home shows the list or the draft of the active project.
    if (location == '/' || location == '/sessions') {
      projectContexts?.recordHome();
    }
  }

  final WorkspaceDraftController? workspaceDrafts;

  /// The project contexts of the selected server and the list preferences.
  final ProjectContextsController? projectContexts;

  final AppPreferencesController preferences;
  final AppNavigationController navigation;
  final L10nBridge localizations;
  final GoRouter router;
  final HostsController hosts;
  final EndpointHealthController? endpointHealth;
  final WorkspaceChromeController? workspaceChrome;
  final SessionsController? sessions;
  final SessionHistoryFactory? historyFactory;
  final SessionLiveDirectory? liveDirectory;
  final void Function()? disposeProfileBindings;

  /// Reconnects [liveDirectory] on a return from the background or a network
  /// change.
  final LiveWakeCoordinator? liveWake;

  /// CodeWalk's permission policy (ADR-059). The session chip and its settings
  /// surface belong to V2-047B; the live slot consults it already.
  final PermissionModeStore? permissionModes;

  /// CodeWalk's own Unrestricted insertions, loaded with the policy.
  final UnrestrictedOwnershipStore? unrestrictedOwnership;

  /// The sessions hidden in CodeWalk, a local state the endpoint never sees.
  final HiddenSessionStore? hiddenSessions;

  /// The open session tabs and the live views they keep open.
  final SessionTabsController? sessionTabs;

  /// The server and the project the workspace returns to.
  final WorkspaceController? workspace;

  /// The unsent prompt of each session, saved on this device.
  final SessionDraftStore? sessionDrafts;
  final PairingController? pairing;
  final DiagnosticsController? diagnostics;
  final ReleaseHistoryController? releaseHistory;
  final UpdateCheckController? updates;
  NativePairingLinks? links;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void openDeepLink(Uri link) => router.go(navigation.prepareLink(link));

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disposeProfileBindings?.call();
    // No wake may reach a directory that is closing.
    liveWake?.dispose();
    links?.dispose();
    router.routeInformationProvider.removeListener(_routeChanged);
    workspaceChrome?.dispose();
    // It listens to the list and drives the drafts, so it leaves first.
    projectContexts?.dispose();
    workspaceDrafts?.dispose();
    router.dispose();
    pairing?.dispose();
    navigation.dispose();
    // It listens to the tabs and the list, so it leaves first.
    workspace?.dispose();
    // The tabs close their live views before the list and the directory.
    sessionTabs?.dispose();
    // What was typed and not yet written is written now.
    unawaited(sessionDrafts?.flush());
    sessions?.dispose();
    unawaited(liveDirectory?.close());
    endpointHealth?.dispose();
    hosts.dispose();
    preferences.dispose();
    permissionModes?.dispose();
    hiddenSessions?.dispose();
    releaseHistory?.dispose();
    updates?.dispose();
    diagnostics?.dispose();
  }
}
