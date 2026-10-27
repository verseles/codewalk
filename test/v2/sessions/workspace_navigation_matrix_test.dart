import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_live_support.dart';

/// An open session lays out in every window class, direction and text size,
/// with the keyboard open and on a short window, and its composer keeps the
/// focus the keyboard was raised for.
void main() {
  for (final width in const [360.0, 412.0, 600.0, 839.0, 840.0, 1280.0]) {
    for (final locale in const [Locale('en'), Locale('ar'), Locale('ur')]) {
      for (final textScale in const [1.0, 2.0]) {
        testWidgets(
          'an open session at $width, ${locale.languageCode}, ${textScale}x',
          (tester) async {
            addTearDown(tester.view.resetViewInsets);
            final app = await launchWorkspace(
              tester,
              size: Size(width, 800),
              locale: locale,
              textScale: textScale,
            );
            await openLiveSession(tester, app);
            expect(tester.takeException(), isNull);
            final input = find.byKey(const ValueKey('live-composer-input'));
            expect(input, findsOneWidget);
            final pane = find.byKey(const ValueKey('workspace-sidebar'));
            if (width < 600) {
              expect(pane, findsNothing);
            } else {
              // The list stays on the start side.
              final rect = tester.getRect(pane);
              final rtl = locale.languageCode != 'en';
              expect(rtl ? rect.right : rect.left, rtl ? width : 0);
              // The chat keeps its 320 beside the pane.
              expect(width - rect.width, greaterThan(320));
            }
            bool focused() =>
                tester.widget<TextField>(input).focusNode?.hasFocus ?? false;

            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await settleWorkspace(tester);
            expect(focused(), isTrue);

            // The keyboard opens over the window, then the window shortens.
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await settleWorkspace(tester);
            expect(tester.takeException(), isNull);
            expect(focused(), isTrue);
            tester.view.physicalSize = Size(width, 480);
            await settleWorkspace(tester);
            expect(tester.takeException(), isNull);
            expect(focused(), isTrue);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
