import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/hosts/hosts_controller.dart';
import '../features/pairing/pairing_controller.dart';
import '../features/sessions/project_contexts_controller.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/workspace_draft_controller.dart';
import '../features/settings/release_history_controller.dart';
import '../features/settings/update_check_controller.dart';
import '../platform/connectivity/network_changes.dart';
import '../platform/endpoints/pairing_factory.dart';
import '../platform/endpoints/probe_factory.dart';
import '../platform/pairing/native_pairing_links.dart';
import '../platform/pairing/qr_input.dart';
import '../platform/profiles/endpoint_profile_store.dart';
import '../platform/releases/release_source_factory.dart';
import '../platform/sessions/hidden_session_store.dart';
import '../platform/sessions/permission_mode_store.dart';
import '../platform/sessions/project_workspace_store.dart';
import '../platform/sessions/session_action_source.dart';
import '../platform/sessions/session_catalog_factory.dart';
import '../platform/sessions/session_draft_store.dart';
import '../platform/sessions/session_history_factory.dart';
import '../platform/sessions/session_live_factory.dart';
import '../platform/sessions/session_tabs_store.dart';
import '../platform/sessions/unrestricted_ownership_store.dart';
import '../platform/sessions/workspace_draft_store.dart';
import '../platform/sessions/workspace_store.dart';
import '../platform/storage/credential_factory.dart';
import '../platform/storage/metadata_store.dart';
import '../platform/storage/payload_factory.dart';
import '../platform/storage/preferences_backend.dart';
import '../shared/diagnostics/diagnostics_controller.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/releases/release_source.dart';
import '../shared/sessions/session_actions.dart';
import '../shared/sessions/session_catalog_source.dart';
import '../shared/sessions/session_history_source.dart';
import '../shared/sessions/session_live_source.dart';
import 'app_dependencies.dart';
import 'app_navigation_controller.dart';
import 'app_preferences_controller.dart';
import 'app_router.dart';
import 'live_wake.dart';
import 'workspace_chrome_controller.dart';
import 'workspace_controller.dart';

/// Resolve the private graph before mounting widgets; never use the v1 locator.
AppDependencies createAppDependencies({
  Uri? initialLink,
  V2MetadataStore? metadataStore,
  EndpointProfileRepository? profileRepository,
  EndpointProber? endpointProber,
  EndpointPairing? endpointPairing,
  QrInput? qrInput,
  DiagnosticsController? diagnostics,
  ReleaseSource? releaseSource,
  ReleaseSource? updateSource,
  Future<String> Function()? installedVersion,
  DateTime Function()? releaseClock,
  SessionCatalogFactory? sessionCatalogFactory,
  SessionHistoryFactory? sessionHistoryFactory,
  DateTime Function()? sessionClock,
  SessionLiveDirectory? Function()? sessionLiveDirectory,
  PermissionModeStore? permissionModeStore,
  SessionActionFactory? sessionActionFactory,
  HiddenSessionStore? hiddenStore,
  SessionTabsStore? tabsStore,
  SessionDraftStore? draftStore,
  WorkspaceStore? workspaceStore,
  ProjectWorkspaceStore? projectWorkspaceStore,
  WorkspaceDraftStore? workspaceDraftStore,
  Stream<Object?>? networkChanges,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  final locator = GetIt.asNewInstance();
  final navigator = GlobalKey<NavigatorState>();
  final metadata =
      metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend());
  // The live slot consults this policy before answering anything on its own;
  // it is loaded before the graph is mounted (see loadAppDependencies).
  final permissionModes =
      permissionModeStore ?? PermissionModeStore(store: metadata);
  // Records the Unrestricted rules CodeWalk added, so only those are removed.
  final unrestrictedOwnership = UnrestrictedOwnershipStore(store: metadata);
  // The sessions hidden in CodeWalk: a local state the endpoint never sees.
  final hiddenSessions = hiddenStore ?? HiddenSessionStore(store: metadata);
  // The session actions of a profile: the endpoint's own commands and the
  // local hide.
  final prober = endpointProber ?? createEndpointProber();
  final actionFactory =
      sessionActionFactory ??
      (profile, credential) => createSessionActionSource(
        profile,
        credential,
        prober,
        hidden: hiddenSessions,
      );
  locator.registerSingleton<DiagnosticsController>(
    diagnostics ?? DiagnosticsController(),
  );
  locator.registerSingleton<ReleaseHistoryController>(
    ReleaseHistoryController(
      source: releaseSource ?? createReleaseSource(),
      store: metadata,
      now: releaseClock,
      diagnostics: locator<DiagnosticsController>(),
    ),
  );
  locator.registerSingleton(
    HostsController(
      repository:
          profileRepository ??
          EndpointProfileStore(
            metadata: metadata,
            credentials: createV2EndpointCredentials(metadata),
          ),
      prober: prober,
      diagnostics: locator<DiagnosticsController>(),
      now: sessionClock,
    ),
  );
  locator.registerSingleton(
    AppPreferencesController(
      store: metadataStore,
      diagnostics: locator<DiagnosticsController>(),
    ),
  );
  final endpointHealth = EndpointHealthController(
    hosts: locator<HostsController>(),
    now: sessionClock,
  );
  // One payload store for the outbox and the drafts, which use their own
  // keys.
  final payloads = createV2PayloadStore(metadata);
  // The live directory owns the endpoint's single event stream; the session
  // catalog listens to the same one, so the directory is created first and
  // the catalog borrows its feed.
  final liveDirectory =
      (sessionLiveDirectory ??
      () => createSessionLiveDirectory(
        payloads: payloads,
        permissionModes: permissionModes,
        unrestrictedOwnership: unrestrictedOwnership,
      ))();
  void Function()? disposeProfileBindings;
  if (liveDirectory != null) {
    final hosts = locator<HostsController>();
    void reconcileProfiles() => liveDirectory.reconcileProfiles(
      profiles: hosts.profiles,
      credentials: {
        for (final profile in hosts.profiles)
          profile.id: ?hosts.credentialFor(profile),
      },
      available: hosts.loaded && !hosts.loading && !hosts.storageError,
      changingProfile: hosts.pendingBindingChange,
    );
    hosts.addListener(reconcileProfiles);
    reconcileProfiles();
    disposeProfileBindings = () => hosts.removeListener(reconcileProfiles);
  }
  // Reconnects every open endpoint stream on a return from the background
  // or a network change.
  final liveWake = liveDirectory == null
      ? null
      : LiveWakeCoordinator(wake: liveDirectory.wake, network: networkChanges);
  locator.registerSingleton(
    SessionsController(
      hosts: locator<HostsController>(),
      sourceFactory: sessionCatalogFactory ?? createSessionCatalogSource,
      actionFactory: actionFactory,
      now: sessionClock,
      changesFactory: liveDirectory == null
          ? null
          : (profile, credential) => liveDirectory.catalogChanges(
              profile: profile,
              credential: credential,
            ),
    ),
  );
  // The open session tabs follow the list, which checks their sessions.
  final sessionTabs = SessionTabsController(
    store: tabsStore ?? SessionTabsStore(store: metadata),
    catalog: locator<SessionsController>(),
    now: sessionClock,
  );
  // Brings back the server the workspace was left on.
  final workspaceState = workspaceStore ?? WorkspaceStore(store: metadata);
  final workspace = WorkspaceController(
    catalog: locator<SessionsController>(),
    health: endpointHealth,
    store: workspaceState,
    tabs: sessionTabs,
  );
  final workspaceDrafts = WorkspaceDraftController(
    catalog: locator<SessionsController>(),
    health: endpointHealth,
    store:
        workspaceDraftStore ??
        WorkspaceDraftStore(payloads: payloads, index: metadata),
  );
  // The open projects of each server and the project the list shows.
  final projectContexts = ProjectContextsController(
    catalog: locator<SessionsController>(),
    store: projectWorkspaceStore ?? ProjectWorkspaceStore(store: metadata),
    workspace: workspaceState,
    tabs: sessionTabs,
    drafts: workspaceDrafts,
  );
  locator.registerSingleton(AppNavigationController());
  locator.registerSingleton(L10nBridge());
  locator.registerSingleton(
    PairingController(
      pairing: endpointPairing ?? createEndpointPairing(),
      hosts: locator<HostsController>(),
      qr: qrInput ?? createQrInput(navigator),
    ),
  );
  final navigation = locator<AppNavigationController>();
  final platformLocation =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final initial =
      initialLink ?? Uri.tryParse(platformLocation) ?? Uri(path: '/');
  locator.registerSingleton<GoRouter>(
    createAppRouter(
      navigation: navigation,
      navigatorKey: navigator,
      initialLocation: navigation.prepareLink(initial),
    ),
  );
  return AppDependencies(
    preferences: locator<AppPreferencesController>(),
    navigation: navigation,
    localizations: locator<L10nBridge>(),
    router: locator<GoRouter>(),
    hosts: locator<HostsController>(),
    endpointHealth: endpointHealth,
    workspaceChrome: WorkspaceChromeController(
      health: endpointHealth,
      catalog: locator<SessionsController>(),
      tabs: sessionTabs,
    ),
    sessions: locator<SessionsController>(),
    historyFactory: sessionHistoryFactory ?? createSessionHistorySource,
    liveDirectory: liveDirectory,
    disposeProfileBindings: disposeProfileBindings,
    liveWake: liveWake,
    permissionModes: permissionModes,
    hiddenSessions: hiddenSessions,
    sessionTabs: sessionTabs,
    workspace: workspace,
    workspaceDrafts: workspaceDrafts,
    projectContexts: projectContexts,
    sessionDrafts:
        draftStore ?? SessionDraftStore(payloads: payloads, index: metadata),
    unrestrictedOwnership: unrestrictedOwnership,
    pairing: locator<PairingController>(),
    diagnostics: locator<DiagnosticsController>(),
    releaseHistory: locator<ReleaseHistoryController>(),
    updates: UpdateCheckController(
      source: updateSource ?? createUpdateSource(),
      store: metadata,
      installedVersion:
          installedVersion ??
          () async => (await PackageInfo.fromPlatform()).version,
      target: currentUpdateTarget(),
    ),
  );
}

/// Production hydrates appearance before mounting; tests can inject a store.
Future<AppDependencies> loadAppDependencies({
  Uri? initialLink,
  V2MetadataStore? metadataStore,
  bool listenNativeLinks = false,
  bool listenNetwork = false,
}) async {
  final dependencies = createAppDependencies(
    initialLink: initialLink,
    metadataStore:
        metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend()),
    networkChanges: listenNetwork ? platformNetworkChanges() : null,
  );
  await dependencies.preferences.initialize();
  // A cold read grants no approval authority: the policy is loaded before any
  // session can be watched, and a failed read stays explicit instead of
  // defaulting to Allow all.
  await dependencies.permissionModes?.initialize();
  await dependencies.unrestrictedOwnership?.initialize();
  await dependencies.hiddenSessions?.initialize();
  await dependencies.sessionTabs?.initialize();
  await dependencies.workspace?.initialize();
  if (listenNativeLinks) {
    final links = dependencies.links = NativePairingLinks((uri) {
      if (dependencies.isDisposed) return;
      dependencies.pairing?.empty();
      final route = dependencies.navigation.prepareLink(uri);
      if (route == '/pair' && uri.hasQuery) {
        dependencies.pairing?.input(uri.toString());
      }
      dependencies.router.go(route);
    });
    await links.start();
  }
  return dependencies;
}
