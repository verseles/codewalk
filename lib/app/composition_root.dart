import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../features/hosts/hosts_controller.dart';
import '../features/pairing/pairing_controller.dart';
import '../features/settings/release_history_controller.dart';
import '../platform/endpoints/pairing_factory.dart';
import '../platform/endpoints/probe_factory.dart';
import '../platform/pairing/native_pairing_links.dart';
import '../platform/pairing/qr_input.dart';
import '../platform/profiles/endpoint_profile_store.dart';
import '../platform/releases/release_source_factory.dart';
import '../platform/storage/credential_factory.dart';
import '../platform/storage/metadata_store.dart';
import '../platform/storage/preferences_backend.dart';
import '../shared/diagnostics/diagnostics_controller.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/releases/release_source.dart';
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
}) {
  WidgetsFlutterBinding.ensureInitialized();
  final locator = GetIt.asNewInstance();
  final navigator = GlobalKey<NavigatorState>();
  final metadata =
      metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend());
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
      prober: endpointProber ?? createEndpointProber(),
      diagnostics: locator<DiagnosticsController>(),
    ),
  );
  locator.registerSingleton(
    AppPreferencesController(
      store: metadataStore,
      diagnostics: locator<DiagnosticsController>(),
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
