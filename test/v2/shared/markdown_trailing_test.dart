import 'package:codewalk/shared/rendering/markdown_content.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the trailing text after the last word (#538)', () {
    test('follows running text on its own last line', () {
      expect(withTrailingMark('Done.'), 'Done. \uE000');
      expect(withTrailingMark('- one\n- two\n\n'), '- one\n- two \uE000');
      expect(withTrailingMark('# Title'), '# Title \uE000');
    });

    test('takes a line of its own after a block it would break', () {
      for (final source in [
        '```dart\nfinal a = 1;\n```',
        '| a | b |\n|---|---|\n| 1 | 2 |',
        '    indented code',
        r'$$x^2$$',
        '<details>open</details>',
        '```\nnever closed',
      ]) {
        expect(withTrailingMark(source), '${source.trimRight()}\n\n\uE000');
      }
      expect(withTrailingMark('   '), '\uE000');
    });

    testWidgets('renders inside the last paragraph and runs its tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownContent(
              source: 'All **done** here',
              trailingText: '138tps 28s',
              trailingStyle: const TextStyle(fontSize: 12),
              onTapTrailing: () => taps++,
            ),
          ),
        ),
      );
      TextSpan? hit;
      RichText? paragraph;
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          if (span is TextSpan && span.text == '138tps 28s') {
            hit = span;
            paragraph = rich;
            return false;
          }
          return true;
        });
      }
      expect(hit, isNotNull);
      // One paragraph holds both the answer and the trailing run.
      expect(paragraph!.text.toPlainText(), 'All done here 138tps 28s');
      expect(hit!.style?.fontSize, 12);
      (hit!.recognizer! as TapGestureRecognizer).onTap!();
      expect(taps, 1);
    });
  });
}
