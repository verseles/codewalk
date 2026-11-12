@TestOn('vm')
library;

import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:codewalk/features/sessions/session_agent_color.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/symbols_font.dart';

/// The shared composer (#484): closed, a one-line pill with Attach, the
/// field, Voice and Send; open (with focus), the field on top and a row with
/// Attach, the agent-colored model chip, Voice and Send.
Widget _composer(
  Locale locale,
  Brightness brightness,
  FocusNode closed,
  FocusNode open,
) => MaterialApp(
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
          Widget frame(FocusNode focus, String text, {required bool enabled}) =>
              Padding(
                padding: const EdgeInsets.all(12),
                child: ComposerFrame(
                  attachTooltip: 'Attach',
                  voiceTooltip: 'Voice',
                  chip: ActionChip(
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                    color: const WidgetStatePropertyAll(
                      sessionDefaultAgentColor,
                    ),
                    label: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Opus 5.5',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' Extra'),
                        ],
                      ),
                      style: TextStyle(
                        color: sessionAgentForeground(sessionDefaultAgentColor),
                      ),
                    ),
                    onPressed: () {},
                  ),
                  field: (context, isOpen) => TextField(
                    controller: TextEditingController(text: text),
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    decoration: composerDecoration(
                      context,
                      isOpen ? 'Type / for commands' : 'Message',
                    ),
                  ),
                  action: ComposerSendButton(
                    tooltip: 'Send',
                    onPressed: enabled ? () {} : null,
                  ),
                ),
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              frame(closed, '', enabled: false),
              frame(
                open,
                'Fix the failing test and explain why',
                enabled: true,
              ),
            ],
          );
        },
      ),
    ),
  ),
);

void main() {
  setUpAll(loadSymbolsFonts);
  final cases = [
    ('mobile_light', const Locale('en'), Brightness.light),
    ('mobile_dark', const Locale('en'), Brightness.dark),
    ('mobile_ar_rtl', const Locale('ar'), Brightness.light),
  ];
  for (final (name, locale, brightness) in cases) {
    testWidgets('composer input, $name', (tester) async {
      tester.view.physicalSize = const Size(390, 260);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final closed = FocusNode();
      final open = FocusNode();
      addTearDown(closed.dispose);
      addTearDown(open.dispose);
      await tester.pumpWidget(_composer(locale, brightness, closed, open));
      open.requestFocus();
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('composer_golden')),
        matchesGoldenFile('goldens/composer_input_$name.png'),
      );
    });
  }
}
