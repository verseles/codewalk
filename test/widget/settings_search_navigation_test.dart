import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/l10n/generated/app_localizations_en.dart';
import 'package:codewalk/presentation/pages/logs_page.dart';
import 'package:codewalk/presentation/pages/settings/sections/about_settings_section.dart';
import 'package:codewalk/presentation/pages/settings/sections/appearance_settings_section.dart';
import 'package:codewalk/presentation/pages/settings/settings_search_catalog.dart';
import 'package:codewalk/presentation/pages/settings/widgets/settings_search_navigation.dart';
import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

void main() {
  test(
    'search catalog has unique localized control destinations in all locales',
    () async {
      final settings = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      addTearDown(settings.dispose);
      for (final locale in AppLocales.supported) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final options = settingsSearchOptions(l10n, settings);
        expect(options.map((o) => o.targetKey).toSet().length, options.length);
        expect(options.every((o) => o.label.trim().isNotEmpty), isTrue);
        expect(options.map((o) => o.sectionId).toSet().length, 9);
      }
    },
  );

  for (final section in ['appearance', 'about', 'logs']) {
    testWidgets('every $section catalog entry resolves to its exact control', (
      tester,
    ) async {
      PackageInfo.setMockInitialValues(
        appName: 'CodeWalk',
        packageName: 'test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final settings = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      addTearDown(settings.dispose);
      final child = switch (section) {
        'appearance' => const AppearanceSettingsSection(),
        'about' => const AboutSettingsSection(),
        _ => const LogsPage(),
      };
      await tester.pumpWidget(
        localizedMaterialApp(
          home: InheritedProvider<SettingsProvider>.value(
            value: settings,
            child: Scaffold(body: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final option in settingsSearchOptions(
        AppLocalizationsEn(),
        settings,
      ).where((o) => o.sectionId == section)) {
        expect(
          find.byKey(ValueKey(option.targetKey)),
          findsOneWidget,
          reason: option.label,
        );
      }
    });
  }

  testWidgets(
    'reveals exact offscreen key and repeats without remounting edits',
    (tester) async {
      final draft = TextEditingController(text: 'unsaved');
      addTearDown(draft.dispose);
      final request = ValueNotifier<SettingsSearchRequest?>(null);
      addTearDown(request.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: ValueListenableBuilder(
                valueListenable: request,
                builder: (context, value, _) => SettingsSearchDestination(
                  request: value,
                  child: SettingsSectionBody(
                    children: [
                      TextField(controller: draft),
                      const SizedBox(height: 1800),
                      const SizedBox(
                        key: ValueKey('target'),
                        height: 60,
                        child: Text('target'),
                      ),
                      const SizedBox(height: 400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('target')).hitTestable(), findsNothing);
      request.value = const SettingsSearchRequest('target', 'target', 1);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('target')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_highlight_target')),
        findsOneWidget,
      );
      expect(draft.text, 'unsaved');
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byKey(const ValueKey('settings_highlight_target')),
        findsNothing,
      );
      request.value = const SettingsSearchRequest('target', 'target', 2);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_highlight_target')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pending target reveals when async content mounts', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SettingsSearchDestination(
            request: const SettingsSearchRequest('late', 'late', 1),
            child: ValueListenableBuilder(
              valueListenable: ready,
              builder: (context, value, _) => SettingsSectionBody(
                children: [
                  const SizedBox(height: 1200),
                  if (value) const Text('late', key: ValueKey('late')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    ready.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('late')).hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings_highlight_late')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final locale in ['en', 'pt', 'ar']) {
    testWidgets('option search navigates to bottom of appearance in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
        appName: 'CodeWalk',
        packageName: 'test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final settings = SettingsProvider(
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      addTearDown(settings.dispose);
      await pumpLocalizedApp(
        tester,
        localeCode: locale,
        child: InheritedProvider<SettingsProvider>.value(
          value: settings,
          child: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      // Brand name is unchanged across locales; this query matches only an option.
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        'AMOLED',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('settings_search_option_settings_toggle_amoled_dark'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_toggle_amoled_dark')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('settings_highlight_settings_toggle_amoled_dark'),
        ),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(Locale(locale));
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        l10n.settingsAppearanceMathRendering,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'settings_search_option_settings_toggle_math_rendering',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey('settings_toggle_math_rendering'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('settings_highlight_settings_toggle_math_rendering'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
