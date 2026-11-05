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

  test('display defaults show tabs and recent sessions, hint unseen', () async {
    final backend = FakeMetadataBackend();
    final preferences = controller(backend);
    addTearDown(preferences.dispose);
    await preferences.initialize();
    expect(preferences.showSessionTabs, isTrue);
    expect(preferences.showRecentSessions, isTrue);
    expect(preferences.tabsGestureHintDismissed, isFalse);
    expect(backend.writes, ['cw2.schema']);
  });

  test('the display choices survive a reload', () async {
    final backend = FakeMetadataBackend();
    final first = controller(backend);
    addTearDown(first.dispose);
    await first.initialize();
    first.setShowSessionTabs(false);
    first.setShowRecentSessions(false);
    first.setTabsGestureHintDismissed(true);
    await first.flush();

    final second = controller(backend);
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.showSessionTabs, isFalse);
    expect(second.showRecentSessions, isFalse);
    expect(second.tabsGestureHintDismissed, isTrue);
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
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(graph.preferences.showSessionTabs, isFalse);
    await graph.preferences.flush();
    expect(backend.values['cw2.settings.showSessionTabs'], isFalse);
  });
}
