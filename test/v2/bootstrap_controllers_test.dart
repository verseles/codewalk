import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/app_navigation_controller.dart';
import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/shared/l10n/l10n_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'hosts/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('composed graphs and the retained global locator are independent', () {
    final globalMarker = _LegacyMarker();
    GetIt.I.registerSingleton<_LegacyMarker>(globalMarker);
    addTearDown(() => GetIt.I.unregister<_LegacyMarker>());
    final first = createAppDependencies(initialLink: Uri(path: '/'));
    final second = createAppDependencies(initialLink: Uri(path: '/'));
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    first.preferences.setLocale(const Locale('pt'));
    first.preferences.setThemeMode(ThemeMode.dark);
    first.localizations.setLocale(const Locale('pt'));
    first.navigation.prepareLink(Uri.parse('codewalk://pair?code=first'));
    expect(second.preferences.locale, isNull);
    expect(second.preferences.themeMode, ThemeMode.system);
    expect(second.localizations.current.settingsTitle, 'Settings');
    expect(second.navigation.consumePairingLink(), isNull);
    expect(GetIt.I<_LegacyMarker>(), same(globalMarker));
  });

  test('one graph owner disposes router before controllers exactly once', () {
    final events = <String>[];
    final dependencies = AppDependencies(
      preferences: _Preferences(events),
      navigation: _Navigation(events),
      localizations: L10nBridge(),
      router: _Router(events),
      hosts: _Hosts(events),
    );
    dependencies.dispose();
    dependencies.dispose();
    expect(events, ['router', 'navigation', 'hosts', 'preferences']);
    expect(dependencies.isDisposed, isTrue);
  });

  test('preferences notify only for changed values', () {
    final preferences = AppPreferencesController();
    addTearDown(preferences.dispose);
    var notifications = 0;
    preferences.addListener(() => notifications++);
    preferences.setThemeMode(ThemeMode.system);
    preferences.setLocale(null);
    expect(notifications, 0);
    preferences.setThemeMode(ThemeMode.dark);
    preferences.setLocale(const Locale('pt'));
    preferences.setLocale(const Locale('pt'));
    expect(notifications, 2);
  });

  test('opaque native identifiers retain spaces and percent escapes once', () {
    final navigation = AppNavigationController();
    addTearDown(navigation.dispose);
    expect(
      navigation.prepareLink(Uri.parse('codewalk://s/%20host%20/id%252Ftail')),
      '/s/%20host%20/id%252Ftail',
    );
    final intent = navigation.pendingIntent as SessionNavigationIntent;
    expect(intent.host, ' host ');
    expect(intent.session, 'id%2Ftail');
  });

  for (final raw in [
    'https://external.example/pair?code=secret',
    'codewalk://pair/extra?code=secret',
    'codewalk://user:secret@pair?code=secret',
    'codewalk://pair:80?code=secret',
    'codewalk://s/host',
    'codewalk://s/host/session/extra',
    'codewalk://s/host/session?token=secret',
    'codewalk://s/host/%00',
    '/settings?token=secret',
    'codewalk://s/host/%FF',
    'codewalk://s/%E2%82/session',
    '/s/host/%FF',
  ]) {
    test('unsupported link is sanitized: ${Uri.parse(raw).path}', () {
      final navigation = AppNavigationController();
      addTearDown(navigation.dispose);
      navigation.prepareLink(Uri.parse('codewalk://pair?code=previous'));
      expect(navigation.prepareLink(Uri.parse(raw)), '/unsupported');
      expect(navigation.pendingIntent, isA<UnsupportedNavigationIntent>());
      expect(navigation.pendingIntent.toString(), isNot(contains('secret')));
      expect(navigation.consumePairingLink(), isNull);
    });
  }

  test('leaving pairing and disposing clears its transient link', () {
    final navigation = AppNavigationController();
    navigation.prepareLink(Uri.parse('codewalk://pair?code=secret'));
    navigation.prepareLink(Uri(path: '/hosts'));
    expect(navigation.pendingIntent, isNull);
    expect(navigation.consumePairingLink(), isNull);
    navigation.prepareLink(Uri.parse('codewalk://pair?code=secret'));
    navigation.dispose();
    expect(navigation.consumePairingLink(), isNull);
    expect(navigation.pendingIntent, isNull);
  });
}

class _Hosts extends HostsController {
  _Hosts(this.events)
    : super(repository: MemoryProfiles(), prober: FakeProber());
  final List<String> events;
  @override
  void dispose() {
    events.add('hosts');
    super.dispose();
  }
}

class _LegacyMarker {}

class _Router extends Fake implements GoRouter {
  _Router(this.events);
  final List<String> events;
  @override
  void dispose() => events.add('router');
}

class _Navigation extends AppNavigationController {
  _Navigation(this.events);
  final List<String> events;
  @override
  void dispose() {
    events.add('navigation');
    super.dispose();
  }
}

class _Preferences extends AppPreferencesController {
  _Preferences(this.events);
  final List<String> events;
  @override
  void dispose() {
    events.add('preferences');
    super.dispose();
  }
}
