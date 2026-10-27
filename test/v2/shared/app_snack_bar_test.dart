import 'dart:io';

import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/widgets/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The snackbar policy (#160, #161, #212): one path, the app's responsive
/// theme, a tap that closes a message without an action.
void main() {
  late ScaffoldMessengerState messenger;

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: Builder(
            builder: (context) => Theme(
              // As the app's bootstrap applies it.
              data: AppTheme.withResponsiveSnackBars(
                Theme.of(context),
                MediaQuery.of(context),
                textDirection: direction,
              ),
              child: child!,
            ),
          ),
        ),
        home: Builder(
          builder: (context) {
            messenger = ScaffoldMessenger.of(context);
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
  }

  testWidgets('a compact message is a toast that a tap closes', (tester) async {
    await mount(tester);
    showAppSnackBar(messenger, 'Copied');
    await tester.pumpAndSettle();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      bar.behavior ?? SnackBarBehavior.floating,
      SnackBarBehavior.floating,
    );
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.text('Copied'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('an action stays the message\'s own, without a close icon', (
    tester,
  ) async {
    await mount(tester);
    var retried = 0;
    showAppSnackBar(
      messenger,
      'Failed',
      action: SnackBarAction(label: 'Retry', onPressed: () => retried++),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byKey(const ValueKey('app-snack-bar-dismiss')), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, 1);
  });

  testWidgets('a wide message sits at the end side, 420 wide, with a close', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await mount(tester, width: 1280, direction: direction);
      showAppSnackBar(
        messenger,
        'Saved',
        action: SnackBarAction(label: 'Open', onPressed: () {}),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rect.width, closeTo(420, 0.5));
      if (direction == TextDirection.ltr) {
        expect(rect.right, closeTo(1280 - 24, 0.5));
      } else {
        expect(rect.left, closeTo(24, 0.5));
      }
      expect(find.text('Open'), findsOneWidget);
      // Always closable by hand, beside the action.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }
  });

  testWidgets('a long message can be kept to one line', (tester) async {
    await mount(tester);
    showAppSnackBar(messenger, 'x' * 400, maxLines: 1);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('x' * 400));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  test('a missing messenger shows nothing', () {
    expect(showAppSnackBar(null, 'Nothing'), isNull);
  });

  test('every v2 message goes through the one snackbar path', () {
    final offenders = <String>[];
    for (final root in [
      'lib/app',
      'lib/features',
      'lib/shared',
      'lib/platform',
    ]) {
      for (final file in Directory(root).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('app_snack_bar.dart')) continue;
        final source = file.readAsStringSync();
        if (source.contains('.showSnackBar(') ||
            RegExp(r'(?<![A-Za-z])SnackBar\(').hasMatch(source)) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
