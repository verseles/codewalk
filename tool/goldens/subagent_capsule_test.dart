@TestOn('vm')
library;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/v2/sessions/subagent_capsule_support.dart';

/// The x86 Goldens workflow bootstraps these references before the ordinary
/// golden entry point is registered. The same cases then guard normal checks.
void registerSubagentGoldens({required String goldenDirectory}) {
  for (final (name, size, locale, scale, dark, completed) in const [
    ('mobile_light', Size(390, 844), Locale('en'), 1.0, false, false),
    ('mobile_dark_done', Size(390, 844), Locale('en'), 1.0, true, true),
    ('desktop_light', Size(1280, 800), Locale('en'), 1.0, false, false),
    ('mobile_ar_2x', Size(390, 844), Locale('ar'), 2.0, false, false),
  ]) {
    testWidgets('subagent capsule and popup $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rig = await SubagentCapsuleRig.mount(
        tester,
        locale: locale,
        scale: scale,
        fullPage: true,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      );
      rig.emit([
        if (!completed) ...[
          rig.work('Review implementation', WorkStatus.running),
          rig.work('Waiting for your answer', WorkStatus.waiting),
          rig.work('Status unconfirmed', WorkStatus.unknown),
        ],
        rig.work('Explore the repository', WorkStatus.completed),
        rig.work('A previous failure', WorkStatus.failed),
        rig.work('Interrupted work', WorkStatus.cancelled),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('$goldenDirectory/subagents_capsule_$name.png'),
      );
      await tester.tap(find.byKey(const ValueKey('subagent-capsule')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('$goldenDirectory/subagents_popin_$name.png'),
      );
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    });
  }
}

void main() =>
    registerSubagentGoldens(goldenDirectory: '../../test/v2/sessions/goldens');
