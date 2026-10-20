import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../features/hosts/hosts_controller.dart';
import '../features/pairing/pairing_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/settings/release_history_controller.dart';
import '../platform/endpoints/pairing_factory.dart';
import '../platform/endpoints/probe_factory.dart';
import '../platform/pairing/native_pairing_links.dart';
import '../platform/pairing/qr_input.dart';
import '../platform/profiles/endpoint_profile_store.dart';
import '../platform/releases/release_source_factory.dart';
import '../platform/sessions/hidden_session_store.dart';
import '../platform/sessions/permission_mode_store.dart';
import '../platform/sessions/session_action_source.dart';
import '../platform/sessions/session_catalog_factory.dart';
import '../platform/sessions/session_history_factory.dart';
import '../platform/sessions/session_live_factory.dart';
import '../platform/sessions/unrestricted_ownership_store.dart';
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
  DateTime Function()? releaseClock,
  SessionCatalogFactory? sessionCatalogFactory,
  SessionHistoryFactory? sessionHistoryFactory,
  DateTime Function()? sessionClock,
  SessionLiveDirectory? Function()? sessionLiveDirectory,
  PermissionModeStore? permissionModeStore,
  SessionActionFactory? sessionActionFactory,
  HiddenSessionStore? hiddenStore,
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
    ),
  );
  locator.registerSingleton(
    AppPreferencesController(
      store: metadataStore,
      diagnostics: locator<DiagnosticsController>(),
    ),
  );
  // The live directory owns the endpoint's single event stream; the session
  // catalog listens to the same one, so the directory is created first and
  // the catalog borrows its feed.
  final liveDirectory =
      (sessionLiveDirectory ??
      () => createSessionLiveDirectory(
        payloads: createV2PayloadStore(metadata),
        permissionModes: permissionModes,
        unrestrictedOwnership: unrestrictedOwnership,
      ))();
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
    sessions: locator<SessionsController>(),
    historyFactory: sessionHistoryFactory ?? createSessionHistorySource,
    liveDirectory: liveDirectory,
    permissionModes: permissionModes,
    hiddenSessions: hiddenSessions,
    unrestrictedOwnership: unrestrictedOwnership,
    pairing: locator<PairingController>(),
    diagnostics: locator<DiagnosticsController>(),
    releaseHistory: locator<ReleaseHistoryController>(),
  );
}

/// Production hydrates appearance before mounting; tests can inject a store.
Future<AppDependencies> loadAppDependencies({
  Uri? initialLink,
  V2MetadataStore? metadataStore,
  bool listenNativeLinks = false,
}) async {
  final dependencies = createAppDependencies(
    initialLink: initialLink,
    metadataStore:
        metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend()),
  );
  await dependencies.preferences.initialize();
  // A cold read grants no approval authority: the policy is loaded before any
  // session can be watched, and a failed read stays explicit instead of
  // defaulting to Allow all.
  await dependencies.permissionModes?.initialize();
  await dependencies.unrestrictedOwnership?.initialize();
  await dependencies.hiddenSessions?.initialize();
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
