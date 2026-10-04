import 'package:codewalk/app/app_navigation_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('navigation and appearance respond at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dependencies = createAppDependencies(initialLink: Uri(path: '/'));
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();

      expect(
        find.byType(NavigationBar),
        size.width < 840 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationRail),
        size.width >= 840 ? findsOneWidget : findsNothing,
      );
      expect(find.text('CodeWalk'), findsOneWidget);
      expect(dependencies.router.routeInformationProvider.value.uri.path, '/');

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(
        dependencies.router.routeInformationProvider.value.uri.path,
        '/settings',
      );
      expect(find.text('Settings'), findsWidgets);

      dependencies.preferences.setThemeMode(ThemeMode.dark);
      dependencies.preferences.setDensity(AppDensity.dense);
      dependencies.preferences.setLocale(const Locale('pt', 'BR'));
      await tester.pumpAndSettle();
      expect(find.text('Configurações'), findsWidgets);
      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Theme.of(context).visualDensity, VisualDensity.compact);
      expect(Localizations.localeOf(context), const Locale('pt'));
      expect(dependencies.localizations.current.settingsTitle, 'Configurações');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(dependencies.isDisposed, isTrue);
      expect(dependencies.preferences.isDisposed, isTrue);
      expect(dependencies.navigation.isDisposed, isTrue);
    });
  }

  testWidgets(
    'pairing route retains the private link and exposes no credentials',
    (tester) async {
      final link = Uri.parse(
        'codewalk://pair?code=private-code&token=private-token',
      );
      final dependencies = createAppDependencies(initialLink: link);
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();

      expect(
        dependencies.router.routeInformationProvider.value.uri.toString(),
        '/pair',
      );
      expect(
        dependencies.navigation.pendingIntent,
        isA<PairingNavigationIntent>(),
      );
      expect(find.textContaining('private-code'), findsNothing);
      expect(find.textContaining('private-token'), findsNothing);
      expect(dependencies.navigation.consumePairingLink(), link);
      expect(dependencies.navigation.consumePairingLink(), isNull);

      dependencies.router.go('/pair?code=next-private');
      await tester.pumpAndSettle();
      expect(
        dependencies.router.routeInformationProvider.value.uri.toString(),
        '/pair',
      );
      expect(
        dependencies.navigation.consumePairingLink()?.queryParameters['code'],
        'next-private',
      );
      expect(find.textContaining('next-private'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'session deep links preserve opaque identifiers without inventing identity',
    (tester) async {
      final dependencies = createAppDependencies(
        initialLink: Uri.parse(
          'codewalk://s/host%2Fone/session%3F%23%25%20value',
        ),
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      final intent =
          dependencies.navigation.pendingIntent as SessionNavigationIntent;
      expect(intent.host, 'host/one');
      expect(intent.session, 'session?#% value');
      expect(find.text('Conversation'), findsWidgets);
      expect(tester.takeException(), isNull);

      dependencies.openDeepLink(Uri.parse('codewalk://unknown?token=hidden'));
      await tester.pumpAndSettle();
      expect(
        dependencies.navigation.pendingIntent,
        isA<UnsupportedNavigationIntent>(),
      );
      expect(find.text('This link is not supported.'), findsOneWidget);
      expect(find.textContaining('hidden'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Arabic UI resolves RTL and graph replacement disposes the old owner',
    (tester) async {
      final first = createAppDependencies(initialLink: Uri(path: '/settings'));
      first.preferences.setLocale(const Locale('ar'));
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: first));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl,
      );

      final second = createAppDependencies(initialLink: Uri(path: '/hosts'));
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: second));
      await tester.pumpAndSettle();
      expect(first.isDisposed, isTrue);
      expect(second.isDisposed, isFalse);
      expect(second.router.routeInformationProvider.value.uri.path, '/hosts');
      expect(second.localizations.current.settingsTitle, 'Settings');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final raw in [
    'codewalk://s/host/%FF',
    'codewalk://s/%E2%82/session',
    '/s/host/%FF',
  ]) {
    testWidgets(
      'malformed path is safe at bootstrap and later navigation: $raw',
      (tester) async {
        final malformed = Uri.parse(raw);
        final dependencies = createAppDependencies(initialLink: malformed);
        await tester.pumpWidget(
          CodeWalkV2Bootstrap(dependencies: dependencies),
        );
        await tester.pumpAndSettle();
        expect(
          dependencies.navigation.pendingIntent,
          isA<UnsupportedNavigationIntent>(),
        );
        expect(
          dependencies.router.routeInformationProvider.value.uri.toString(),
          '/unsupported',
        );
        expect(find.text('This link is not supported.'), findsOneWidget);
        expect(find.textContaining(raw), findsNothing);
        expect(tester.takeException(), isNull);

        dependencies.openDeepLink(
          Uri.parse('codewalk://pair?code=previous-private'),
        );
        await tester.pumpAndSettle();
        expect(
          dependencies.navigation.pendingIntent,
          isA<PairingNavigationIntent>(),
        );
        dependencies.openDeepLink(malformed);
        await tester.pumpAndSettle();
        expect(dependencies.navigation.consumePairingLink(), isNull);
        expect(
          dependencies.navigation.pendingIntent,
          isA<UnsupportedNavigationIntent>(),
        );
        expect(find.text('This link is not supported.'), findsOneWidget);
        expect(find.textContaining('previous-private'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
