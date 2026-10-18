import 'package:codewalk/features/sessions/session_timeline_tile.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ItemMeta _meta(String id) => ItemMeta(
  id: ItemId('test/$id'),
  generation: 'test',
  status: OpenValue.unknown('test'),
  source: SourceProvenance(
    harness: const HarnessRef(HostId('h'), HarnessInstanceId('test')),
    version: '2.0.22',
    nativeType: 'assistant',
  ),
);

Widget _surface(TimelineItem item, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: V2Localizations.localizationsDelegates,
  supportedLocales: V2Localizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: SessionTimelineTile(item: item))),
);

Finder _rich(String s) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(s),
);

void main() {
  for (final locale in V2Localizations.supportedLocales) {
    testWidgets(
      'timeline tile rich and minimized markers ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // AssistantText rich <b>.
        await tester.pumpWidget(
          _surface(
            AssistantText(meta: _meta('a1'), text: '<b>Bold body</b>', complete: true),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(_rich('Bold body'), findsWidgets);
        expect(find.text('<b>Bold body</b>'), findsNothing);

        // Reasoning without HTML keeps literal tags.
        await tester.pumpWidget(
          _surface(
            Reasoning(meta: _meta('r1'), text: '<b>user</b>', complete: true),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('<b>user</b>'), findsWidgets);

        // ToolCall stays minimized, payload hidden.
        await tester.pumpWidget(
          _surface(
            ToolCall(
              meta: _meta('t1'),
              kind: const OpenValue.known(ToolKind.read),
              rawName: 'read',
              output: CanonicalValue({'private': 'do-not-render'}),
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('do-not-render'), findsNothing);
        expect(find.textContaining('read'), findsOneWidget);

        // Unknown stays neutral.
        await tester.pumpWidget(
          _surface(
            UnknownItem(
              meta: _meta('u1'),
              rawType: 'future',
              raw: CanonicalValue({'hidden': 'x'}),
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('do-not-render'), findsNothing);

        // RTL direction.
        final ctx = tester.element(find.byType(SessionTimelineTile));
        expect(
          Directionality.of(ctx),
          {'ar', 'ur'}.contains(locale.languageCode)
              ? TextDirection.rtl
              : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('2000-item list builds without exception', (tester) async {
    final items = List.generate(
      2000,
      (i) => AssistantText(
        meta: _meta('a$i'),
        text: 'Message $i with **bold**',
        complete: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(
          body: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => SessionTimelineTile(
              key: ValueKey(items[i].id),
              item: items[i],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
