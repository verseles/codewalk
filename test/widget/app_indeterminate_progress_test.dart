import 'package:codewalk/presentation/theme/app_animations.dart';
import 'package:codewalk/presentation/widgets/app_indeterminate_progress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  setUp(AppIndeterminateClock.instance.resetForTest);
  tearDown(() {
    AppIndeterminateClock.instance.resetForTest();
    debugDefaultTargetPlatformOverride = null;
  });

  Widget buildRing() {
    return const MaterialApp(
      home: Scaffold(body: AppIndeterminateRing(size: 28, strokeWidth: 2)),
    );
  }

  group('AppIndeterminateRing', () {
    testWidgets('mobile keeps the native spinner', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(buildRing());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('desktop steps without a vsync ticker', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(buildRing());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(AppAnimations.indeterminateStep);
      expect(tester.binding.transientCallbackCount, 0);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('reduced motion renders a static icon', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: AppIndeterminateRing(size: 28, strokeWidth: 2),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Symbols.progress_activity), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('compact slots render static on desktop', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppIndeterminateRing(size: 16)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Symbols.progress_activity), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('AppIndeterminateClock', () {
    test('stops when the last consumer releases', () {
      final clock = AppIndeterminateClock.instance;
      clock.acquire();
      clock.acquire();
      clock.release();
      clock.release();
      // Releasing with no consumers must not throw or go negative.
      clock.release();
      expect(clock.tick.value, 0);
    });
  });
}
