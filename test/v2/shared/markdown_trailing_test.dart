import 'package:codewalk/shared/rendering/markdown_content.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group('the trailing text after the last word (#538)', () {
    final gfm = md.ExtensionSet.gitHubFlavored;
    bool inline(String source) => trailingFitsInline(source, gfm);

    test('joins running text', () {
      expect(inline('Done.'), isTrue);
      expect(inline('All **done** here'), isTrue);
      expect(inline('- one\n- two\n\n'), isTrue);
      expect(inline('1. one\n2. two `code`'), isTrue);
      expect(inline('> quoted text'), isTrue);
      expect(inline('# Title'), isTrue);
    });

    test('takes a line of its own after a block it would break', () {
      for (final source in [
        '```dart\nfinal a = 1;\n```',
        '```\nnever closed',
        '> ```\n> quoted fence',
        '| a | b |\n|---|---|\n| 1 | 2 |',
        'a | b\n--- | ---\n1 | 2',
        '    indented code',
        'Text\n\n---',
        'Title\n===',
        'Title\n---',
        'See [the doc][1].\n\n[1]: https://example.com',
        '<details>open</details>',
        'An answer that uses  itself',
        '   ',
      ]) {
        expect(inline(source), isFalse, reason: source);
      }
    });

    Future<int> pump(WidgetTester tester, String source) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownContent(
              source: source,
              trailingText: '138tps 28s',
              trailingStyle: const TextStyle(fontSize: 12),
              trailingSemanticsLabel: 'Message Info, 138 tok/s, 28s',
              onTapTrailing: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('message-trailing-stats')));
      return taps;
    }

    String? paragraphHolding(WidgetTester tester) {
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        var holds = false;
        rich.text.visitChildren((span) {
          if (span is WidgetSpan) holds = true;
          return !holds;
        });
        if (holds) return rich.text.toPlainText();
      }
      return null;
    }

    testWidgets('flows in the last paragraph and runs its tap', (tester) async {
      expect(await pump(tester, 'All **done** here'), 1);
      // The paragraph holds the button right after its last word.
      expect(paragraphHolding(tester), startsWith('All done here '));
      expect(find.text('138tps 28s'), findsOneWidget);
      // A screen reader names it and can activate it.
      final named = find.bySemanticsLabel('Message Info, 138 tok/s, 28s');
      expect(named, findsOneWidget);
      expect(
        tester
            .getSemantics(named)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('an unclosed fence keeps its code and the stats below', (
      tester,
    ) async {
      expect(await pump(tester, 'Look:\n\n```dart\nfinal a = 1;'), 1);
      expect(paragraphHolding(tester), isNull);
      expect(find.textContaining('', findRichText: true), findsNothing);
      expect(find.text('138tps 28s'), findsOneWidget);
    });

    testWidgets('a new trailing text replaces the old one', (tester) async {
      await pump(tester, 'Done.');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownContent(source: 'Done.', trailingText: '140tps 29s'),
          ),
        ),
      );
      expect(find.text('140tps 29s'), findsOneWidget);
      expect(find.text('138tps 28s'), findsNothing);
    });
  });
}
