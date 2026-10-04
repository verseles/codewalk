import 'package:codewalk/main_v2.dart' as entry_point;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('v2 entry point mounts at ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      entry_point.main();
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('CodeWalk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
