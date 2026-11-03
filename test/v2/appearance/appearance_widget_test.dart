import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final density in AppDensity.values) {
      testWidgets('appearance controls do not overflow at $width/$density', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final graph = createAppDependencies(
          initialLink: Uri(path: '/settings'),
        );
        graph.preferences.setDensity(density);
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
        expect(find.text('Appearance'), findsWidgets);
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('settings_toggle_amoled_dark')),
              )
              .onChanged,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'preset picker filters and applies a selection; contrast is gated',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
      graph.preferences.setThemePreset(OpenCodeThemePreset.oc2);
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
      await tester.tap(
        find.byKey(const ValueKey('settings_theme_preset_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'dracula',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dracula'));
      await tester.pumpAndSettle();
      expect(graph.preferences.themePreset, OpenCodeThemePreset.dracula);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_contrast_slider')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('appearance_settings_list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('settings_contrast_slider')),
            )
            .onChanged,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('RTL and large text preserve appearance choices', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
    graph.preferences.setLocale(const Locale('ar'));
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
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final code in ['en', 'pt']) {
    testWidgets('settings appearance has one visual style in $code', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final graph = createAppDependencies(initialLink: Uri(path: '/settings'));
      graph.preferences.setLocale(Locale(code));
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
      expect(
        find.byKey(const ValueKey('settings_theme_family_segmented')),
        findsOneWidget,
      );
      final list = find.byKey(const ValueKey('appearance_settings_list'));
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position;
      final shown = <String>{};
      bool isDensityKey(Widget widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('settings_density_');
      }

      void expectSingleStyle() {
        expect(
          find.byKey(const ValueKey('settings_visual_style_segmented')),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                '${widget.data ?? ''}${widget.textSpan?.toPlainText() ?? ''}'
                    .toLowerCase()
                    .contains('refin'),
          ),
          findsNothing,
        );
        for (final key in const [
          'settings_theme_mode_segmented',
          'settings_theme_family_segmented',
          'settings_contrast_slider',
        ]) {
          if (find.byKey(ValueKey(key)).evaluate().isNotEmpty) shown.add(key);
        }
        if (find.byWidgetPredicate(isDensityKey).evaluate().isNotEmpty) {
          shown.add('settings_density');
        }
      }

      // Lazy list items only exist while visible, so check every scroll step.
      expectSingleStyle();
      for (
        var step = 0;
        step < 40 && position.pixels < position.maxScrollExtent;
        step++
      ) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pumpAndSettle();
        expectSingleStyle();
      }
      expect(
        shown,
        containsAll([
          'settings_theme_mode_segmented',
          'settings_theme_family_segmented',
          'settings_contrast_slider',
          'settings_density',
        ]),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
