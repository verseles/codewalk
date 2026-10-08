@TestOn('vm')
library;

import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Linux Flutter 3.44.x; the test's Ahem font, DPR and inputs are deterministic.
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      final name =
          '${desktop ? 'desktop' : 'mobile'}_${dark ? 'dark' : 'light'}';
      testWidgets('appearance golden $name', (tester) async {
        tester.view.physicalSize = desktop
            ? const Size(1280, 800)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final graph = createAppDependencies(
          initialLink: Uri(path: '/settings'),
        );
        graph.preferences.setLocale(const Locale('en'));
        graph.preferences.setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
        graph.preferences.setDensity(
          desktop ? AppDensity.dense : AppDensity.normal,
        );
        if (dark) graph.preferences.setThemePreset(OpenCodeThemePreset.oc2);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('appearance_golden'),
            child: CodeWalkV2Bootstrap(
              dependencies: graph,
              dynamicColors: (builder) => builder(null, null),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('settings_destination_appearance')),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('appearance_golden')),
          matchesGoldenFile('goldens/$name.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
