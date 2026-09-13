import 'package:codewalk/presentation/widgets/app_tab_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

ColorScheme _flattenedAmoledScheme() {
  const black = Colors.black;
  return ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  ).copyWith(
    surface: black,
    surfaceDim: black,
    surfaceBright: black,
    surfaceContainerLowest: black,
    surfaceContainerLow: black,
    surfaceContainer: black,
    surfaceContainerHigh: black,
    surfaceContainerHighest: black,
  );
}

Widget _strip(ColorScheme scheme, {bool transparent = false}) {
  return AppTabStrip<String>(
    keyPrefix: 'test_tab_',
    isCompact: false,
    transparentBackground: transparent,
    tabs: const [
      AppTab<String>(id: 'a', value: 'a', title: 'Alpha', isSelected: true),
      AppTab<String>(id: 'b', value: 'b', title: 'Beta'),
    ],
    onActivate: (_) {},
    onClose: (_) {},
  );
}

void main() {
  group('AppTabStrip AMOLED selection indicator (#182)', () {
    testWidgets('shows indicator only for the selected tab when flattened', (
      tester,
    ) async {
      final scheme = _flattenedAmoledScheme();
      await tester.pumpWidget(
        localizedMaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(body: _strip(scheme)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('test_tab_selection_indicator_a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('test_tab_selection_indicator_b')),
        findsNothing,
      );

      final selectedMaterial = tester.widget<Material>(
        find.byKey(const ValueKey<String>('test_tab_a')),
      );
      expect(selectedMaterial.color, scheme.surface);

      final indicator = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey<String>('test_tab_selection_indicator_a')),
      );
      final indicatorColor = (indicator.decoration as BoxDecoration).color!;
      expect(indicatorColor, isNot(scheme.surface));
      expect(tester.takeException(), isNull);
    });

    testWidgets('indicator also shows over transparent background', (
      tester,
    ) async {
      final scheme = _flattenedAmoledScheme();
      await tester.pumpWidget(
        localizedMaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(body: _strip(scheme, transparent: true)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('test_tab_selection_indicator_a')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('no indicator when surfaces are distinct', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Scaffold(body: _strip(scheme)),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('test_tab_selection_indicator_a')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
