@TestOn('vm')
library;

import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(String id) => ItemMeta(
  id: ItemId('golden/$id'),
  generation: 'golden',
  status: OpenValue.unknown('golden'),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'assistant',
  ),
);

Widget _goldenBody() => SessionTimelineTile(
  item: AssistantText(
    meta: _meta('a1'),
    text: '# Title\n\n- item\n\n| a | b |\n|---|---|\n| c | d |\n\n'
        '```dart\nfinal x = 1;\n```\n\n'
        r'Inline $E = mc^2$ text.' '\n\n'
        '<b>Bold</b> <progress value="40" max="100"></progress>\n\n'
        '```mermaid\ngraph TD; A-->B\n```',
    complete: true,
  ),
);

Future<void> _pumpGolden(
  WidgetTester tester,
  Locale locale,
  Size size,
  Brightness brightness,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
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
        body: RepaintBoundary(
          key: const ValueKey('rich_golden'),
          child: SingleChildScrollView(child: _goldenBody()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final cases = [
    ('mobile_light', const Size(390, 844), const Locale('en'), Brightness.light),
    ('mobile_dark', const Size(390, 844), const Locale('en'), Brightness.dark),
    ('desktop_light', const Size(1280, 800), const Locale('en'), Brightness.light),
    ('desktop_dark', const Size(1280, 800), const Locale('en'), Brightness.dark),
    ('mobile_ar_rtl', const Size(390, 844), const Locale('ar'), Brightness.light),
  ];
  for (final (name, size, locale, brightness) in cases) {
    testWidgets('rich rendering golden $name', (tester) async {
      await _pumpGolden(tester, locale, size, brightness);
      await expectLater(
        find.byKey(const ValueKey('rich_golden')),
        matchesGoldenFile('goldens/$name.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
