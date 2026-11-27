import 'dart:io';
import 'dart:ui' show SemanticsRole;

import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/widgets/app_indeterminate_progress.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Indeterminate progress (ADR-062, #510): native smooth animation on every
/// platform, static only with reduced motion, paused by TickerMode.
void main() {
  Future<void> show(
    WidgetTester tester,
    Widget indicator, {
    bool reducedMotion = false,
    bool withL10n = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: withL10n
            ? V2Localizations.localizationsDelegates
            : null,
        supportedLocales: withL10n
            ? V2Localizations.supportedLocales
            : const [Locale('en')],
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(body: Center(child: indicator)),
        ),
      ),
    );
  }

  testWidgets(
    'every platform uses native indeterminate rings (including compact) and bars',
    (tester) async {
      await show(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIndeterminateRing(size: 16),
            AppIndeterminateRing(size: 36),
            SizedBox(width: 200, child: AppIndeterminateBar()),
          ],
        ),
      );
      final rings = tester
          .widgetList<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .toList();
      expect(rings, hasLength(2));
      for (final ring in rings) {
        expect(ring.value, isNull);
      }
      expect(find.byIcon(Symbols.progress_activity), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'reduced motion is static on every platform',
    (tester) async {
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
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.35,
      );
      // Nothing keeps drawing once the first frames are done.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'TickerMode pauses native desktop animations when hidden and resumes them',
    (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await show(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, on, child) =>
              TickerMode(enabled: on, child: child!),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIndeterminateRing(size: 20),
              SizedBox(width: 200, child: AppIndeterminateBar()),
            ],
          ),
        ),
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      enabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isFalse);
      enabled.value = true;
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('the ring is announced once, by its explicit or default label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await show(
        tester,
        const AppIndeterminateRing(size: 36, semanticsLabel: 'Loading'),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await show(tester, const AppIndeterminateRing(size: 16));
      expect(find.bySemanticsLabel('In progress'), findsOneWidget);
      await show(tester, const AppIndeterminateRing(size: 16), withL10n: true);
      expect(find.bySemanticsLabel('In progress'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final reduced in [false, true]) {
    testWidgets(
      'busy indicators keep their loading role without a percentage '
      '(reduced motion: $reduced)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await show(
            tester,
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIndeterminateRing(size: 36, semanticsLabel: 'Loading ring'),
                SizedBox(
                  width: 200,
                  child: AppIndeterminateBar(semanticsLabel: 'Loading bar'),
                ),
              ],
            ),
            reducedMotion: reduced,
          );
          for (final label in ['Loading ring', 'Loading bar']) {
            final data = tester
                .getSemantics(find.bySemanticsLabel(label))
                .getSemanticsData();
            expect(data.role, SemanticsRole.loadingSpinner);
            expect(data.value, isEmpty);
          }
          await tester.pumpWidget(const SizedBox());
        } finally {
          semantics.dispose();
        }
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.linux,
        TargetPlatform.android,
      }),
    );
  }

  test(
    'every v2 indeterminate indicator routes through AppIndeterminateRing or AppIndeterminateBar',
    () {
      final offenders = <String>[];
      final start = RegExp(
        r'(?<![A-Za-z])(Circular|Linear)ProgressIndicator\(',
      );
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
            final valueMatch = RegExp(r'\bvalue\s*:').firstMatch(call);
            if (valueMatch == null) {
              offenders.add(file.path);
              continue;
            }
            var argDepth = 0;
            var argEnd = valueMatch.end;
            for (; argEnd < call.length; argEnd++) {
              final ch = call[argEnd];
              if (ch == '(' || ch == '[' || ch == '{') {
                argDepth++;
              } else if (ch == ')' || ch == ']' || ch == '}') {
                if (argDepth == 0) break;
                argDepth--;
              } else if (ch == ',' && argDepth == 0) {
                break;
              }
            }
            final valueExpr = call.substring(valueMatch.end, argEnd);
            if (RegExp(r'\bnull\b').hasMatch(valueExpr)) {
              offenders.add(file.path);
            }
          }
        }
      }
      expect(offenders, isEmpty);
    },
  );
}
