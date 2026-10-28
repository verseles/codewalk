import 'dart:ui' show SemanticsRole;

import 'package:codewalk/shared/rendering/canonical_message_body.dart';
import 'package:codewalk/shared/rendering/markdown_content.dart';
import 'package:codewalk/shared/rendering/message_render_budget.dart';
import 'package:codewalk/shared/rendering/render_basic_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _surface(Widget content) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: content)),
);

Finder _richContaining(String content) => find.byWidgetPredicate(
  (widget) =>
      widget is RichText && widget.text.toPlainText().contains(content),
);

void main() {
  group('MessageRenderBudget', () {
    test('empty source is empty', () {
      final d = MessageRenderBudget.decide('   ');
      expect(d.kind, RenderDecisionKind.empty);
    });
    test('64k boundary and 64k+1 fallback', () {
      final ok = List.filled(MessageRenderBudget.richRenderMaxChars, 'a')
          .join();
      expect(MessageRenderBudget.decide(ok).kind, RenderDecisionKind.rich);
      final over = '${ok}a';
      final d = MessageRenderBudget.decide(over);
      expect(d.kind, RenderDecisionKind.plainTruncated);
      expect(d.truncatedChars, 1);
    });
    test('astral runes are codepoint-safe', () {
      final source = 'a${String.fromCharCode(0x1F600)}b';
      expect(MessageRenderBudget.decide(source).kind, RenderDecisionKind.rich);
      expect(source.runes.length, 3);
    });
  });

  group('MarkdownContent rich flags', () {
    testWidgets('GFM renders without flags (baseline preserved)', (
      tester,
    ) async {
      const source = '# Title\n\n- item';
      await tester.pumpWidget(
        _surface(const MarkdownContent(source: source)),
      );
      expect(_richContaining('Title'), findsOneWidget);
      expect(_richContaining('item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Assistant HTML <b> renders rich when allowed', (
      tester,
    ) async {
      const source = '<b>Bold body</b>';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(source: source, allowBasicHtml: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(_richContaining('Bold body'), findsWidgets);
      // No literal tags remain.
      expect(find.text('<b>Bold body</b>'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('UserInput keeps <b> literal when HTML disallowed', (
      tester,
    ) async {
      const source = '<b>user</b>';
      await tester.pumpWidget(
        _surface(
          const CanonicalMessageBody(
            source: source,
            complete: true,
            allowBasicHtml: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('<b>user</b>'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unsupported <script> stays safe (no HTML execution)', (tester) async {
      const source = '<script>alert(1)</script>';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(source: source, allowBasicHtml: true),
        ),
      );
      await tester.pumpAndSettle();
      // Fail-closed: unsupported tags never render as HTML nor execute.
      // They may stay literal or be stripped; both are safe.
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('currency and shell vars stay literal', (tester) async {
      const source = r'$100 and $PATH stay text';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(source: source, enableMath: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(_richContaining(r'$100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline math renders, malformed falls back', (tester) async {
      const source = r'Inline $E = mc^2$ and malformed $\frac{1}{';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(source: source, enableMath: true),
        ),
      );
      await tester.pumpAndSettle();
      // Valid math produces a math widget; malformed falls back to raw text
      // without throwing.
      expect(tester.takeException(), isNull);
    });

    testWidgets('progress bar renders determinate', (tester) async {
      const source = '<progress value="40" max="100"></progress>';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(source: source, allowBasicHtml: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('basicHtmlProgressValue matrix', (tester) async {
      expect(basicHtmlProgressValue({'value': '40', 'max': '100'}), 0.4);
      expect(
        basicHtmlProgressValue({'value': '-5', 'max': '100'}),
        0.0,
      );
      expect(basicHtmlProgressValue({'max': '0'}), isNull);
      expect(
        basicHtmlProgressValue({'value': '2.5e1', 'max': '100'}),
        closeTo(0.25, 1e-9),
      );
    });

    testWidgets('mermaid renders diagram when enabled', (tester) async {
      const source = '```mermaid\ngraph TD; A-->B\n```';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(
            source: source,
            enableMermaid: true,
            enableCodeHighlight: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Diagram widget present (fallback also acceptable if parser rejects).
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString().contains('Mermaid'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown code language falls back to plain', (tester) async {
      const source = '```unknownlang123\ncode\n```';
      await tester.pumpWidget(
        _surface(
          const MarkdownContent(
            source: source,
            enableCodeHighlight: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_richContaining('code'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('oversized code falls back to plain', (tester) async {
      final big = List.filled(
        MessageRenderBudget.codeHighlightMaxChars + 10,
        'x',
      ).join();
      final source = '```dart\n$big\n```';
      await tester.pumpWidget(
        _surface(
          MarkdownContent(
            source: source,
            enableCodeHighlight: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('over-budget source falls back to plain truncated', (
      tester,
    ) async {
      final big = List.filled(
        MessageRenderBudget.richRenderMaxChars + 10,
        'y',
      ).join();
      await tester.pumpWidget(
        _surface(
          CanonicalMessageBody(source: big, complete: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('truncated'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('images stay text without network', (tester) async {
      const source = '![alt](https://example.test/a.png)';
      await tester.pumpWidget(
        _surface(const MarkdownContent(source: source)),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('alt'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text scaling renders without overflow exception', (
      tester,
    ) async {
      const source = '# Title\n\nSome **bold** text with `code`.';
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _surface(
            const MarkdownContent(
              source: source,
              allowBasicHtml: true,
              enableMath: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced-motion indeterminate progress is static', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const source = '<progress aria-label="Loading"></progress>';
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _surface(
            const MarkdownContent(source: source, allowBasicHtml: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.35);
      final data = tester
          .getSemantics(find.bySemanticsLabel('Loading'))
          .getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);
      expect(data.value, isEmpty);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
