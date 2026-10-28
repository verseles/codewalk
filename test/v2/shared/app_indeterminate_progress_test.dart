import 'dart:io';

import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Bounded indeterminate progress (#117): stepped or static on desktop,
/// native on mobile, static with reduced motion.
void main() {
  Future<void> show(
    WidgetTester tester,
    Widget indicator, {
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(body: Center(child: indicator)),
        ),
      ),
    );
  }

  double? ringValue(WidgetTester tester) => tester
      .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator))
      .value;

  testWidgets(
    'a desktop ring steps from one shared timer',
    (tester) async {
      await show(tester, const AppIndeterminateRing(size: 36));
      expect(AppIndeterminateClock.instance.running, isTrue);
      final first = ringValue(tester);
      expect(first, isNotNull);
      await tester.pump(AppIndeterminate.step);
      expect(ringValue(tester), isNot(first));
      // No vsync ticker: nothing is scheduled between steps.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(AppIndeterminateClock.instance.running, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'a small desktop slot shows a static glyph',
    (tester) async {
      await show(tester, const AppIndeterminateRing(size: 16));
      expect(find.byIcon(Symbols.progress_activity), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(AppIndeterminateClock.instance.running, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'reduced motion is static on every platform',
    (tester) async {
      {
        await show(
          tester,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIndeterminateRing(size: 48),
              SizedBox(width: 200, child: AppIndeterminateBar()),
            ],
          ),
          reducedMotion: true,
        );
        expect(find.byIcon(Symbols.progress_activity), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          0.35,
        );
        expect(AppIndeterminateClock.instance.running, isFalse);
        // Nothing keeps drawing once the first frames are done.
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'mobile keeps the native indeterminate animation',
    (tester) async {
      await show(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIndeterminateRing(size: 16),
            SizedBox(width: 200, child: AppIndeterminateBar()),
          ],
        ),
      );
      expect(ringValue(tester), isNull);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(AppIndeterminateClock.instance.running, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a desktop bar steps and stops when hidden by TickerMode',
    (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await show(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, on, child) =>
              TickerMode(enabled: on, child: child!),
          child: const SizedBox(width: 200, child: AppIndeterminateBar()),
        ),
      );
      final bar = find.byType(LinearProgressIndicator);
      final first = tester.widget<LinearProgressIndicator>(bar).value;
      await tester.pump(AppIndeterminate.step);
      expect(tester.widget<LinearProgressIndicator>(bar).value, isNot(first));
      enabled.value = false;
      await tester.pump();
      expect(AppIndeterminateClock.instance.running, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'a hidden indicator stops listening while another keeps the clock alive',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await show(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIndeterminateRing(),
            ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
              child: const SizedBox(
                key: ValueKey('hidden-progress'),
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [AppIndeterminateRing(), AppIndeterminateBar()],
                ),
              ),
            ),
          ],
        ),
      );
      final hiddenListeners = find.descendant(
        of: find.byKey(const ValueKey('hidden-progress')),
        matching: find.byType(ValueListenableBuilder<int>),
      );
      expect(hiddenListeners, findsNWidgets(2));
      visible.value = false;
      await tester.pump();
      expect(AppIndeterminateClock.instance.running, isTrue);
      expect(hiddenListeners, findsNothing);
      visible.value = true;
      await tester.pump();
      expect(hiddenListeners, findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      expect(AppIndeterminateClock.instance.running, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'the ring is announced once, by its label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await show(
        tester,
        const AppIndeterminateRing(size: 36, semanticsLabel: 'Loading'),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  test('every v2 indeterminate indicator is the bounded one', () {
    final offenders = <String>[];
    final start = RegExp(r'(?<![A-Za-z])(Circular|Linear)ProgressIndicator\(');
    for (final root in [
      'lib/app',
      'lib/features',
      'lib/shared',
      'lib/platform',
    ]) {
      for (final file in Directory(root).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('app_indeterminate_progress.dart')) continue;
        final source = file.readAsStringSync();
        for (final match in start.allMatches(source)) {
          // The call's own arguments, up to its closing parenthesis.
          var depth = 0;
          var end = match.end - 1;
          for (; end < source.length; end++) {
            if (source[end] == '(') depth++;
            if (source[end] == ')' && --depth == 0) break;
          }
          final call = source.substring(match.start, end);
          if (!call.contains('value:')) offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
