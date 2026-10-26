import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/main_v2.dart' as entry_point;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final originalPlatform = SharedPreferencesAsyncPlatform.instance;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = originalPlatform);
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('v2 entry point mounts at ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      try {
        // main calls runApp directly. Establish this test's frame clock before
        // its warm-up frame starts any progress animation.
        await tester.pumpWidget(const SizedBox.shrink());
        await entry_point.main();
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.text('CodeWalk'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final graph = tester
            .widget<CodeWalkV2Bootstrap>(find.byType(CodeWalkV2Bootstrap))
            .dependencies;
        await tester.pumpWidget(const SizedBox.shrink());
        expect(graph.isDisposed, isTrue);
      } finally {
        // Finish this graph before the next test receives a fresh fake clock.
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
