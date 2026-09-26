import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/pages/settings/widgets/settings_section_layout.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_localized_app.dart';

void main() {
  testWidgets('G4 scoped card styling preserves controls and live form state', (
    tester,
  ) async {
    final style = ValueNotifier(VisualStyle.refined);
    addTearDown(style.dispose);
    const outside = ValueKey('outside-card');
    const inside = ValueKey('settings-card');
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: style,
        builder: (_, value, _) => localizedMaterialApp(
          theme: AppTheme.lightFrom(
            ColorScheme.fromSeed(seedColor: Colors.blue),
            visualStyle: value,
          ),
          home: const Scaffold(
            body: Column(
              children: [
                Card(key: outside, child: Text('Outside Settings')),
                SettingsSurfaceTheme(
                  child: Card(
                    key: inside,
                    child: Column(children: [TextField(), Divider()]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final outer = Theme.of(tester.element(find.byKey(outside)));
    final scoped = Theme.of(tester.element(find.byKey(inside)));
    expect(
      (outer.cardTheme.shape! as OutlinedBorder).side,
      isNot(BorderSide.none),
    );
    expect((scoped.cardTheme.shape! as OutlinedBorder).side, BorderSide.none);
    expect(scoped.cardTheme.color, outer.cardTheme.color);
    expect(scoped.cardTheme.elevation, outer.cardTheme.elevation);
    expect(
      (scoped.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
      (outer.cardTheme.shape! as RoundedRectangleBorder).borderRadius,
    );
    expect(scoped.inputDecorationTheme, outer.inputDecorationTheme);
    expect(scoped.dividerTheme, outer.dividerTheme);
    await tester.enterText(find.byType(TextField), 'unsaved Settings draft');
    style.value = VisualStyle.classic;
    await tester.pumpAndSettle();
    expect(find.text('unsaved Settings draft'), findsOneWidget);
    final classicOuter = Theme.of(tester.element(find.byKey(outside)));
    final classicScoped = Theme.of(tester.element(find.byKey(inside)));
    expect(classicScoped.cardTheme, classicOuter.cardTheme);
    style.value = VisualStyle.refined;
    await tester.pumpAndSettle();
    expect(find.text('unsaved Settings draft'), findsOneWidget);
  });
}
