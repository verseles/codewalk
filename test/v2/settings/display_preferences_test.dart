import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(FakeMetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  test('display defaults on a phone hide tabs, hint unseen', () async {
    final backend = FakeMetadataBackend();
    final preferences = controller(backend);
    addTearDown(preferences.dispose);
    await preferences.initialize();
    // Tests run as a phone, whose new install starts without tabs.
    expect(preferences.showSessionTabs, isFalse);
    expect(preferences.expandedTools, isFalse);
    expect(preferences.tabsGestureHintDismissed, isFalse);
    // A new install writes only its theme, GitHub (#553), and its tabs.
    expect(backend.writes, [
      'cw2.schema',
      'cw2.settings.themePreset',
      'cw2.settings.showSessionTabs',
    ]);
  });

  test('the display choices survive a reload', () async {
    final backend = FakeMetadataBackend();
    final first = controller(backend);
    addTearDown(first.dispose);
    await first.initialize();
    first.setShowSessionTabs(false);
    first.setExpandedTools(true);
    first.setTabsGestureHintDismissed(true);
    await first.flush();

    final second = controller(backend);
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.showSessionTabs, isFalse);
    expect(second.expandedTools, isTrue);
    expect(second.tabsGestureHintDismissed, isTrue);
  });

  test('a stored Recent sessions choice is left alone (#534)', () async {
    final backend = FakeMetadataBackend();
    backend.values['cw2.settings.showRecentSessions'] = false;
    final preferences = controller(backend);
    addTearDown(preferences.dispose);
    await preferences.initialize();
    preferences.setShowSessionTabs(false);
    await preferences.flush();
    // The choice is gone: never read back, never written again.
    expect(backend.writes, isNot(contains('cw2.settings.showRecentSessions')));
    expect(
      backend.removals,
      isNot(contains('cw2.settings.showRecentSessions')),
    );
    expect(backend.writes, contains('cw2.settings.showSessionTabs'));
  });

  testWidgets('Settings > Appearance toggles the tab strip', (tester) async {
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
      find.byKey(const ValueKey('settings_destination_appearance')),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('settings_toggle_session_tabs'));
    await tester.scrollUntilVisible(
      toggle,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('appearance_settings_list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    // Tests run as a phone, whose new install starts without tabs.
    expect(graph.preferences.showSessionTabs, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(graph.preferences.showSessionTabs, isTrue);
    await graph.preferences.flush();
    expect(backend.values.containsKey('cw2.settings.showSessionTabs'), isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await graph.preferences.flush();
    expect(backend.values['cw2.settings.showSessionTabs'], isFalse);
  });
}
