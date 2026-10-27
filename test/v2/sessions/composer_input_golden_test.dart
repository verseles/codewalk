@TestOn('vm')
library;

import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared composer pieces: the bubble with its hint and with text, and
/// the round Send, enabled and disabled.
Widget _composer(Locale locale, Brightness brightness) => MaterialApp(
  locale: locale,
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  theme: ThemeData(
    colorSchemeSeed: Colors.teal,
    brightness: brightness,
    useMaterial3: true,
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('composer_golden'),
      child: Builder(
        builder: (context) {
          Widget row(String text, {required bool enabled}) => Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ComposerBubble(
                    child: TextField(
                      controller: TextEditingController(text: text),
                      minLines: 1,
                      maxLines: 4,
                      decoration: composerDecoration(context, 'Type a message'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ComposerSendButton(
                  tooltip: 'Send',
                  onPressed: enabled ? () {} : null,
                ),
              ],
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('', enabled: false),
              row('Fix the failing test and explain why', enabled: true),
            ],
          );
        },
      ),
    ),
  ),
);

void main() {
  final cases = [
    ('mobile_light', const Locale('en'), Brightness.light),
    ('mobile_dark', const Locale('en'), Brightness.dark),
    ('mobile_ar_rtl', const Locale('ar'), Brightness.light),
  ];
  for (final (name, locale, brightness) in cases) {
    testWidgets('composer input, $name', (tester) async {
      tester.view.physicalSize = const Size(390, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_composer(locale, brightness));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('composer_golden')),
        matchesGoldenFile('goldens/composer_input_$name.png'),
      );
    });
  }
}
