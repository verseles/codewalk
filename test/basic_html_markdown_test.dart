import 'package:codewalk/presentation/utils/basic_html_markdown.dart';
import 'package:codewalk/presentation/utils/math_markdown.dart';
import 'package:codewalk/presentation/widgets/app_indeterminate_progress.dart';
import 'package:codewalk/presentation/widgets/math_expression_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'support/pump_localized_app.dart';

List<md.Node> parse(String text) => md.Document(
  inlineSyntaxes: [BasicHtmlInlineSyntax(), InlineMathSyntax()],
  blockSyntaxes: const [BasicHtmlBlockSyntax()],
  extensionSet: md.ExtensionSet.gitHubFlavored,
  encodeHtml: false,
).parseLines(text.split('\n'));

Iterable<md.Element> elements(List<md.Node> nodes) sync* {
  for (final node in nodes) {
    if (node is md.Element) {
      yield node;
      yield* elements(node.children ?? []);
    }
  }
}

Widget body(
  String text, {
  Brightness brightness = Brightness.light,
  double width = 320,
  double scale = 1,
  ValueChanged<String>? onLink,
}) => localizedMaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: SizedBox(
        width: width,
        child: MarkdownBody(
          data: text,
          softLineBreak: true,
          inlineSyntaxes: [
            BasicHtmlInlineSyntax(),
            InlineMathSyntax(),
            SingleLineBlockMathSyntax(),
          ],
          blockSyntaxes: const [BasicHtmlBlockSyntax()],
          builders: {
            basicHtmlTextTag: BasicHtmlTextBuilder(),
            basicHtmlProgressTag: BasicHtmlProgressBuilder(),
            basicHtmlMathTag: BasicHtmlMathBuilder(),
            'inlineMath': InlineMathBuilder(),
          },
          paddingBuilders: {'a': BasicHtmlLinkPaddingBuilder()},
          onTapLink: (text, href, title) => onLink?.call(href!),
        ),
      ),
    ),
  ),
);

Iterable<TextSpan> spans(WidgetTester tester) sync* {
  Iterable<TextSpan> walk(InlineSpan span) sync* {
    if (span is TextSpan) {
      yield span;
      for (final child in span.children ?? <InlineSpan>[]) {
        yield* walk(child);
      }
    }
  }

  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    yield* walk(rich.text);
  }
}

void main() {
  test('HTML-starting GFM tables retain table parsing', () {
    final nodes = elements(parse('<b>Tool</b> | Status\n--- | ---\nTest | OK'));
    expect(nodes.where((e) => e.tag == 'table'), hasLength(1));
    expect(nodes.where((e) => e.tag == 'strong'), hasLength(1));
  });

  test('opaque Markdown regions cannot close HTML wrappers', () {
    for (final inner in [
      '<!-- </b> -->',
      '<?test </b> ?>',
      '<![CDATA[ </b> ]]>',
      '<custom-tag title="</b>">',
      '[link](https://example.com "</b>")',
      '[link](https://example.com "title <i>")',
    ]) {
      final strong = elements(
        parse('<b>before $inner after</b>'),
      ).singleWhere((e) => e.tag == 'strong');
      expect(strong.textContent, endsWith(' after'), reason: inner);
    }
  });

  test('long incomplete tag scanning remains bounded', () {
    final source = '<b ${List.filled(6000, ' ').join()}x';
    final watch = Stopwatch()..start();
    final nodes = parse(source);
    expect(nodes.map((node) => node.textContent).join(), source);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  for (final tag in ['u', 'sub', 'sup']) {
    testWidgets('HTML $tag inside a link label remains tappable', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        body(
          '[<$tag>label</$tag>](https://example.com)',
          onLink: (value) => tapped = value,
        ),
      );
      await tester.tap(find.text('label'));
      expect(tapped, 'https://example.com');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wrapped link with closing-tag title remains tappable', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      body(
        '<u>[label](https://example.com "</u>")</u>',
        onLink: (value) => tapped = value,
      ),
    );
    await tester.tap(find.text('label'));
    expect(tapped, 'https://example.com');
    expect(tester.takeException(), isNull);
  });

  for (final source in [
    r'**<b>$x^2$</b>**',
    r'*<i>$x^2$</i>*',
    r'<b>$$ x^2 $$</b>',
  ]) {
    testWidgets('HTML math is safe beneath Markdown: $source', (tester) async {
      await tester.pumpWidget(body(source));
      expect(find.byType(MathExpressionWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('balanced nesting, same tag and private script leaves', () {
    final nodes = elements(parse('<u><b>one <b><i>two</i></b></b></u>'));
    expect(nodes.where((e) => e.tag == 'strong'), hasLength(2));
    expect(nodes.where((e) => e.tag == 'em'), hasLength(1));
    expect(
      nodes.where((e) => e.tag == basicHtmlTextTag).map((e) => e.attributes),
      everyElement(containsPair('underline', 'u')),
    );
    expect(
      elements(parse('x<sup>2</sup>')).any((e) => e.tag == 'sup'),
      isFalse,
    );
  });

  test('code, escaped and encoded HTML remains literal', () {
    for (final input in [
      '`<b>code</b>`',
      '```html\n<progress value=".5"></progress>\n```',
      '    <b>indented</b>',
      r'\<b>escaped</b>',
      '&lt;b&gt;encoded&lt;/b&gt;',
    ]) {
      expect(
        elements(
          parse(input),
        ).where((e) => e.tag == 'strong' || e.tag == basicHtmlProgressTag),
        isEmpty,
        reason: input,
      );
    }
  });

  test('closing tags inside code or math do not terminate outer tags', () {
    final nodes = elements(parse(r'<b>`</b>` and $x^{</b>}$ end</b>'));
    final strong = nodes.where((e) => e.tag == 'strong');
    expect(strong.map((e) => e.textContent).join(), contains('end'));
    expect(nodes.any((e) => e.tag == basicHtmlMathTag), isTrue);
  });

  test('standalone tags preserve surrounding Markdown and multiline pairs', () {
    expect(
      elements(parse('<b>\ntext\n</b>')).any((e) => e.tag == 'strong'),
      isTrue,
    );
    final nodes = parse('<br>\nfollowing\n\n<b>\n# heading');
    expect(nodes.map((e) => e.textContent).join(), contains('following'));
    expect(elements(nodes).any((e) => e.tag == 'h1'), isTrue);
    expect(nodes.map((e) => e.textContent).join(), contains('<b>'));
  });

  test('malformed and partial tags remain visible; depth is bounded', () {
    for (final input in [
      '<b>partial',
      '<progress value=".5"',
      '<b><i>x</b></i>',
    ]) {
      expect(parse(input).map((e) => e.textContent).join(), input);
    }
    final deep =
        '${List.filled(100, '<b>').join()}x${List.filled(100, '</b>').join()}';
    expect(elements(parse(deep)).where((e) => e.tag == 'strong').length, 32);
    expect(parse(List.filled(2000, '<b>').join()), isNotEmpty);
  });

  test(
    'progress attributes are quote-aware, case-insensitive and first-wins',
    () {
      final element = elements(
        parse(
          '<PROGRESS title="a > b" VALUE="&#53;" value="9" MAX=10>loading</PROGRESS>',
        ),
      ).singleWhere((e) => e.tag == basicHtmlProgressTag);
      expect(element.attributes['value'], '5');
      expect(element.attributes['max'], '10');
      expect(element.attributes['fallback'], 'loading');
      expect(element.attributes.containsKey('title'), isFalse);
      expect(basicHtmlProgressValue(element.attributes), .5);
    },
  );

  test('progress uses HTML missing/invalid and numeric-prefix semantics', () {
    expect(basicHtmlProgressValue({}), isNull);
    final cases = <Map<String, String>, double>{
      {'value': '.5'}: .5,
      {'value': '25', 'max': '100'}: .25,
      {'value': ''}: 0,
      {'value': 'abc'}: 0,
      {'value': 'NaN'}: 0,
      {'value': 'Infinity'}: 0,
      {'value': '1e999'}: 0,
      {'value': '-3'}: 0,
      {'value': '3'}: 1,
      {'value': '.5', 'max': '0'}: .5,
      {'value': '.5', 'max': '-5'}: .5,
      {'value': '.5', 'max': 'invalid'}: .5,
      {'value': ' +5e-1junk'}: .5,
      {'value': '1e', 'max': '2'}: .5,
      {'value': '70%', 'max': '100'}: .7,
      {'value': '1e308', 'max': '1e-308'}: 1,
    };
    for (final entry in cases.entries) {
      expect(
        basicHtmlProgressValue(entry.key),
        entry.value,
        reason: '${entry.key}',
      );
    }
  });

  testWidgets('nested HTML and Markdown styles compose', (tester) async {
    await tester.pumpWidget(body('<u><b><i>styled</i></b></u>'));
    final span = spans(tester).singleWhere((s) => s.text == 'styled');
    expect(span.style?.fontWeight, FontWeight.bold);
    expect(span.style?.fontStyle, FontStyle.italic);
    expect(span.style?.decoration?.contains(TextDecoration.underline), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('breaks and empty script elements render safely', (tester) async {
    await tester.pumpWidget(body('a<br>b<br/>c <sup></sup><sub></sub>'));
    expect(spans(tester).map((s) => s.text ?? '').join(), contains('a\nb\nc'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('underline preserves links and math widgets', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      body(
        r'<u>[link](https://example.com) and $x^2$</u>',
        onLink: (href) => tapped = href,
      ),
    );
    expect(find.byType(MathExpressionWidget), findsOneWidget);
    // The merged paragraph also contains non-link text; tap the first glyphs.
    await tester.tapAt(
      tester.getTopLeft(find.textContaining('link').first) + const Offset(8, 8),
    );
    expect(tapped, 'https://example.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('bold HTML preserves nested math rendering', (tester) async {
    await tester.pumpWidget(body(r'<b>formula $x^2$</b>'));
    expect(find.byType(MathExpressionWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('scripts and progress fit narrow ${brightness.name} layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        body(
          'H<sub>2</sub>O x<sup>2</sup>\n\n<progress value="1" max="2">half</progress>',
          brightness: brightness,
          width: 100,
          scale: 2,
        ),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final colors = Theme.of(
        tester.element(find.byType(LinearProgressIndicator)),
      ).colorScheme;
      expect(bar.value, .5);
      expect(bar.color, colors.primary);
      expect(bar.semanticsLabel, 'half');
      expect(
        tester.getSize(find.byType(LinearProgressIndicator)).width,
        lessThanOrEqualTo(100),
      );
      expect(find.byType(Transform), findsAtLeastNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing progress value uses app indeterminate policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      body('<progress aria-label="Building"></progress>'),
    );
    expect(find.byType(AppIndeterminateBar), findsOneWidget);
    expect(
      tester
          .widget<AppIndeterminateBar>(find.byType(AppIndeterminateBar))
          .semanticsLabel,
      'Building',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
