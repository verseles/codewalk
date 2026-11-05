import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(FakeMetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  test('a stored language hydrates, an unknown one falls back', () async {
    final backend = FakeMetadataBackend();
    backend.values.addAll({'cw2.schema': 1, 'cw2.settings.locale': 'pt'});
    final stored = controller(backend);
    addTearDown(stored.dispose);
    await stored.initialize();
    expect(stored.locale, const Locale('pt'));
    expect(backend.writes, isEmpty);

    final unknown = FakeMetadataBackend();
    unknown.values.addAll({'cw2.schema': 1, 'cw2.settings.locale': 'xx'});
    final fallback = controller(unknown);
    addTearDown(fallback.dispose);
    await fallback.initialize();
    expect(fallback.locale, isNull);
  });

  test(
    'choosing a language persists it and system default clears it',
    () async {
      final backend = FakeMetadataBackend();
      final preferences = controller(backend);
      addTearDown(preferences.dispose);
      await preferences.initialize();

      preferences.setLocale(const Locale('de'));
      await preferences.flush();
      expect(backend.values['cw2.settings.locale'], 'de');
      expect(preferences.locale, const Locale('de'));

      preferences.setLocale(null);
      await preferences.flush();
      expect(backend.values.containsKey('cw2.settings.locale'), isFalse);
      expect(preferences.locale, isNull);
    },
  );

  test('a reload keeps the chosen language from storage', () async {
    final backend = FakeMetadataBackend();
    final first = controller(backend);
    addTearDown(first.dispose);
    await first.initialize();
    first.setLocale(const Locale('ja'));
    await first.flush();

    final second = controller(backend);
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.locale, const Locale('ja'));
  });

  testWidgets('Settings > Behavior applies a language from native names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final backend = FakeMetadataBackend();
    final graph = createAppDependencies(
      initialLink: Uri(path: '/settings'),
      metadataStore: V2MetadataStore(backend: backend),
    );
    addTearDown(graph.dispose);
    await graph.preferences.initialize();
    graph.preferences.setLocale(const Locale('en'));
    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: graph,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('settings_destination_behavior')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings_language_picker')),
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('behavior_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('settings_language_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(graph.preferences.locale, const Locale('de'));
    expect(graph.preferences.locale.toString(), 'de');
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(
        tester.element(find.byKey(const ValueKey('behavior_settings_list'))),
      ),
      const Locale('de'),
    );
  });
}
