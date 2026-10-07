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
        expect(find.text('Appearance'), findsOneWidget);
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
        find.byKey(const ValueKey('settings_theme_preset_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'dracula');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dracula'));
      await tester.pumpAndSettle();
      expect(graph.preferences.themePreset, OpenCodeThemePreset.dracula);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings_contrast_slider')),
        200,
        scrollable: find.byType(Scrollable).first,
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
    expect(
      Directionality.of(tester.element(find.byType(Scaffold))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
