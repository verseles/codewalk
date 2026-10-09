import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../features/hosts/hosts_controller.dart';
import '../platform/endpoints/probe_factory.dart';
import '../platform/profiles/endpoint_profile_store.dart';
import '../platform/storage/credential_factory.dart';
import '../platform/storage/metadata_store.dart';
import '../platform/storage/preferences_backend.dart';
import '../shared/l10n/l10n_bridge.dart';
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
}) {
  WidgetsFlutterBinding.ensureInitialized();
  final locator = GetIt.asNewInstance();
  final metadata =
      metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend());
  locator.registerSingleton(
    HostsController(
      repository:
          profileRepository ??
          EndpointProfileStore(
            metadata: metadata,
            credentials: createV2EndpointCredentials(metadata),
          ),
      prober: endpointProber ?? createEndpointProber(),
    ),
  );
  locator.registerSingleton(AppPreferencesController(store: metadataStore));
  locator.registerSingleton(AppNavigationController());
  locator.registerSingleton(L10nBridge());
  final navigation = locator<AppNavigationController>();
  final platformLocation =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  final initial =
      initialLink ?? Uri.tryParse(platformLocation) ?? Uri(path: '/');
  locator.registerSingleton<GoRouter>(
    createAppRouter(
      navigation: navigation,
      initialLocation: navigation.prepareLink(initial),
    ),
  );
  return AppDependencies(
    preferences: locator<AppPreferencesController>(),
    navigation: navigation,
    localizations: locator<L10nBridge>(),
    router: locator<GoRouter>(),
    hosts: locator<HostsController>(),
  );
}

/// Production hydrates appearance before mounting; tests can inject a store.
Future<AppDependencies> loadAppDependencies({
  Uri? initialLink,
  V2MetadataStore? metadataStore,
}) async {
  final dependencies = createAppDependencies(
    initialLink: initialLink,
    metadataStore:
        metadataStore ?? V2MetadataStore(backend: PreferencesMetadataBackend()),
  );
  await dependencies.preferences.initialize();
  return dependencies;
}
