@TestOn('vm')
library;

import 'package:codewalk/features/sessions/composer_input.dart';
import 'package:codewalk/features/sessions/session_command_picker.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `/` picker open over a composer field that holds only `/` (#137),
/// with the first command highlighted.
Widget _picker(Locale locale, Brightness brightness, SessionCommandMenu menu) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: V2Localizations.localizationsDelegates,
      supportedLocales: V2Localizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: brightness,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            key: const ValueKey('command_picker_golden'),
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SessionCommandPicker(menu: menu, onRun: (_) {}),
                    Row(
                      children: [
                        Expanded(
                          child: ComposerBubble(
                            child: TextField(
                              controller: menu.text,
                              minLines: 1,
                              maxLines: 4,
                              decoration: composerDecoration(
                                context,
                                'Type a message',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ComposerSendButton(tooltip: 'Send', onPressed: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    testWidgets('command picker, $name', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final text = TextEditingController(text: '/');
      addTearDown(text.dispose);
      final menu = SessionCommandMenu(text);
      addTearDown(menu.dispose);
      await tester.pumpWidget(_picker(locale, brightness, menu));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey('command_picker_golden')),
        matchesGoldenFile('goldens/command_picker_$name.png'),
      );
    });
  }
}
