import 'package:go_router/go_router.dart';

import '../shared/l10n/l10n_bridge.dart';
import 'app_navigation_controller.dart';
import 'app_preferences_controller.dart';

/// Explicit graph passed to the app, with one owner for its lifetime.
class AppDependencies {
  AppDependencies({
    required this.preferences,
    required this.navigation,
    required this.localizations,
    required this.router,
  });

  final AppPreferencesController preferences;
  final AppNavigationController navigation;
  final L10nBridge localizations;
  final GoRouter router;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void openDeepLink(Uri link) => router.go(navigation.prepareLink(link));

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    router.dispose();
    navigation.dispose();
    preferences.dispose();
  }
}
