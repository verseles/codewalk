import 'dart:convert';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/app_keyboard_shortcuts.dart';
import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/settings/shortcuts_settings_page.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/shortcuts/shortcut_action.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  void settingsTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    TargetPlatform platform = TargetPlatform.linux,
  }) => testWidgets(name, body, variant: TargetPlatformVariant.only(platform));

  Future<AppDependencies> mount(
    WidgetTester tester, {
    double width = 390,
    String route = '/settings',
    Locale locale = const Locale('en'),
    V2MetadataStore? metadataStore,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final graph = createAppDependencies(
      initialLink: Uri(path: route),
      metadataStore: metadataStore,
    );
    await graph.preferences.initialize();
    graph.preferences.setLocale(locale);
    await tester.pumpWidget(
      CodeWalkV2Bootstrap(
        dependencies: graph,
        dynamicColors: (builder) => builder(null, null),
      ),
    );
    await tester.pumpAndSettle();
    return graph;
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey trigger) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(trigger);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String section) async {
    final row = find.byKey(ValueKey('settings_destination_$section'));
    await tester.scrollUntilVisible(
      row,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings_destinations')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  settingsTest(
    'compact search/detail/back preserves the query and actual controls',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        'appearance',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_destination_servers')),
        findsNothing,
      );
      await select(tester, 'appearance');
      expect(
        find.byKey(const ValueKey('settings_toggle_amoled_dark')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_navigation_search')),
            )
            .controller!
            .text,
        'appearance',
      );
      expect(
        find.byKey(const ValueKey('settings_destination_appearance')),
        findsOneWidget,
      );
    },
  );

  settingsTest(
    'wide filtering keeps detail; shrinking preserves selection and back',
    (tester) async {
      await mount(tester, width: 1280);
      expect(
        find.byKey(const ValueKey('settings_toggle_amoled_dark')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('settings_navigation_search')),
        'unmatched',
      );
      await tester.pumpAndSettle();
      expect(find.text('No settings found'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_toggle_amoled_dark')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_detail_back')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_navigation_search')),
            )
            .controller!
            .text,
        'unmatched',
      );
    },
  );

  settingsTest('system Back and scoped Escape return detail to the list', (
    tester,
  ) async {
    await mount(tester);
    await select(tester, 'appearance');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings_navigation_search')),
      findsOneWidget,
    );
    await select(tester, 'appearance');
    await tester.tap(find.byKey(const ValueKey('settings_detail_back')));
    await tester.pumpAndSettle();
    await select(tester, 'shortcuts');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings_navigation_search')),
      findsOneWidget,
    );
  });

  settingsTest(
    'native mobile discovers shortcuts after input; Web exposes them immediately',
    (tester) async {
      final graph = await mount(tester);
      expect(
        find.byKey(const ValueKey('settings_destination_shortcuts')),
        kIsWeb ? findsOneWidget : findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(graph.preferences.hasPhysicalKeyboard, isTrue);
      expect(
        find.byKey(const ValueKey('settings_destination_shortcuts')),
        findsOneWidget,
      );
    },
    platform: TargetPlatform.android,
  );

  settingsTest(
    'actual bootstrap routes available shortcuts and leaves unavailable actions alone',
    (tester) async {
      final graph = await mount(tester, route: '/hosts');
      await chord(tester, LogicalKeyboardKey.keyN);
      expect(graph.router.routeInformationProvider.value.uri.path, '/hosts');
      await chord(tester, LogicalKeyboardKey.comma);
      expect(graph.router.routeInformationProvider.value.uri.path, '/settings');
    },
  );

  settingsTest('root modal priority blocks background navigation', (
    tester,
  ) async {
    final graph = await mount(tester, route: '/hosts');
    final dialog = showDialog<void>(
      context: tester.element(find.byType(Scaffold)),
      builder: (_) => const AlertDialog(content: Text('Modal owns focus')),
    );
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.comma);
    expect(graph.router.routeInformationProvider.value.uri.path, '/hosts');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await dialog;
  });

  settingsTest('editable input owns unmodified and composing shortcuts', (
    tester,
  ) async {
    final p = AppPreferencesController();
    final controller = TextEditingController(text: 'draft');
    addTearDown(p.dispose);
    addTearDown(controller.dispose);
    var count = 0;
    p.setShortcutBinding(ShortcutAction.openSettings, 'a');
    Widget harness() => MaterialApp(
      home: AppKeyboardShortcuts(
        preferences: p,
        openSettings: () => count++,
        child: Scaffold(body: TextField(controller: controller)),
      ),
    );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(count, 0);
    controller.value = const TextEditingValue(
      text: 'compose',
      composing: TextRange(start: 0, end: 7),
    );
    p.setShortcutBinding(ShortcutAction.openSettings, 'mod+,');
    await tester.pumpWidget(harness());
    await chord(tester, LogicalKeyboardKey.comma);
    await tester.pump();
    expect(controller.text, 'compose');
    expect(count, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  settingsTest(
    'capture consumes the chord, rejects conflict and saves an explicit choice',
    (tester) async {
      final graph = await mount(tester);
      await select(tester, 'shortcuts');
      await tester.enterText(
        find.byKey(const ValueKey('settings_shortcuts_search')),
        'Ctrl+,',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shortcut_edit_open_settings')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shortcut_edit_open_settings')),
      );
      await tester.pumpAndSettle();
      await chord(tester, LogicalKeyboardKey.keyN);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('shortcut_capture_apply')),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shortcut_capture_apply')));
      await tester.pumpAndSettle();
      expect(
        graph.preferences.shortcutBindingFor(ShortcutAction.openSettings),
        'alt+x',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('settings_shortcuts_search')),
        findsOneWidget,
      );
    },
  );

  settingsTest('inactive imported conflict can be repaired individually', (
    tester,
  ) async {
    final backend = FakeMetadataBackend()
      ..values.addAll({
        'cw2.schema': 1,
        'cw2.settings.shortcuts': jsonEncode({'close_app': 'mod+,'}),
      });
    final graph = await mount(
      tester,
      metadataStore: V2MetadataStore(backend: backend),
    );
    expect(
      graph.preferences.shortcutConflict(ShortcutAction.openSettings, 'mod+,'),
      ShortcutAction.closeApp,
    );
    await select(tester, 'shortcuts');
    await tester.enterText(
      find.byKey(const ValueKey('settings_shortcuts_search')),
      'close tab/application',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This action is unavailable in this version.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shortcut_unassign_close_app')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('shortcut_unassign_close_app')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('shortcut_unassign_close_app')));
    await graph.preferences.flush();
    await tester.pumpAndSettle();
    expect(
      graph.preferences.shortcutConflict(ShortcutAction.openSettings, 'mod+,'),
      isNull,
    );
    graph.router.go('/hosts');
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.comma);
    expect(graph.router.routeInformationProvider.value.uri.path, '/settings');
  });

  settingsTest('bare Escape is captured without dismissing its editor', (
    tester,
  ) async {
    final graph = await mount(tester);
    graph.preferences.setShortcutBinding(ShortcutAction.escape, 'ctrl+shift+x');
    await select(tester, 'shortcuts');
    await tester.enterText(
      find.byKey(const ValueKey('settings_shortcuts_search')),
      'Ctrl+Shift+X',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shortcut_edit_escape')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shortcut_edit_escape')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('shortcut_capture_apply')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('shortcut_capture_apply')));
    await tester.pumpAndSettle();
    expect(
      graph.preferences.shortcutBindingFor(ShortcutAction.escape),
      'escape',
    );
  });

  settingsTest(
    'resizing during capture preserves detail state and applies the choice',
    (tester) async {
      final graph = await mount(tester, width: 1280);
      await select(tester, 'shortcuts');
      await tester.enterText(
        find.byKey(const ValueKey('settings_shortcuts_search')),
        'Ctrl+,',
      );
      await tester.pumpAndSettle();
      final list = find
          .descendant(
            of: find.byType(ShortcutsSettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('shortcut_edit_open_settings')),
        120,
        scrollable: list,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('shortcut_edit_open_settings')),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shortcut_capture_apply')));
      await tester.pumpAndSettle();
      expect(
        graph.preferences.shortcutBindingFor(ShortcutAction.openSettings),
        'alt+x',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings_shortcuts_search')),
            )
            .controller!
            .text,
        'Ctrl+,',
      );
    },
  );

  for (final width in [320.0, 839.0, 840.0, 1280.0]) {
    settingsTest('RTL and enlarged text remain usable at $width', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, width: width, locale: const Locale('ar'));
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      await select(tester, 'appearance');
      expect(tester.takeException(), isNull);
    });
  }

  settingsTest('one held chord invokes once; key repeat stays ignored', (
    tester,
  ) async {
    final p = AppPreferencesController();
    addTearDown(p.dispose);
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardShortcuts(
          preferences: p,
          openSettings: () => count++,
          child: const Scaffold(body: Text('Idle')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(count, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
