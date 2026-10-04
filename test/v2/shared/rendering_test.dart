import 'package:codewalk/shared/rendering/file_path_detector.dart';
import 'package:codewalk/shared/rendering/file_path_markdown.dart';
import 'package:codewalk/shared/rendering/markdown_content.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _surface(Widget content) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: content)),
);

Finder _textContaining(String content) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(content),
);

void main() {
  testWidgets('renders GFM lists, tables, strike-through and fenced code', (
    tester,
  ) async {
    const source =
        '# Heading\n\n- item\n\n~~obsolete~~\n\n'
        '| name | value |\n| --- | --- |\n| cell | data |\n\n'
        '```dart\nfinal answer = 42;\n```';
    await tester.pumpWidget(_surface(const MarkdownContent(source: source)));

    expect(_textContaining('Heading'), findsOneWidget);
    expect(_textContaining('item'), findsOneWidget);
    expect(_textContaining('obsolete'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(_textContaining('final answer = 42;'), findsOneWidget);
    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('URL taps emit source values without navigation', (tester) async {
    final links = <(String, String, String?)>[];
    await tester.pumpWidget(
      _surface(
        MarkdownContent(
          source: '[Official docs](https://example.test/docs "Reference")',
          onLink: (text, href, title) => links.add((text, href, title)),
        ),
      ),
    );
    await tester.tap(_textContaining('Official docs'));
    expect(links, [
      ('Official docs', 'https://example.test/docs', 'Reference'),
    ]);
    expect(find.byType(FilePathLink), findsNothing);
  });

  testWidgets('prose paths emit exact path, line and column', (tester) async {
    final files = <FilePathMatch>[];
    await tester.pumpWidget(
      _surface(
        MarkdownContent(source: 'See lib/main.dart:42:10', onFile: files.add),
      ),
    );
    await tester.tap(find.byType(FilePathLink));

    expect(files, hasLength(1));
    expect(files.single.fullText, 'lib/main.dart:42:10');
    expect(files.single.path, 'lib/main.dart');
    expect(files.single.lineNumber, 42);
    expect(files.single.columnNumber, 10);
  });

  testWidgets('whole inline-code paths work on any client OS', (tester) async {
    final files = <FilePathMatch>[];
    await tester.pumpWidget(
      _surface(
        MarkdownContent(
          source: r'Use `C:\repo\lib\main.dart:42` and `` lib/other.dart:7 ``.',
          onFile: files.add,
        ),
      ),
    );
    expect(find.byType(FilePathLink), findsNWidgets(2));
    await tester.tap(find.byType(FilePathLink).first);
    expect(files.single.path, r'C:\repo\lib\main.dart');
    expect(files.single.lineNumber, 42);
  });

  testWidgets('ordinary snippets and all fenced paths keep code rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      _surface(
        const MarkdownContent(
          source:
              '`open lib/main.dart`\n\n````\nlib/main.dart\n````\n\n'
              '```dart\nlib/other.dart:7\n```\n\n'
              '~~~\nlib/third.dart:8\n~~~',
        ),
      ),
    );

    expect(find.byType(FilePathLink), findsNothing);
    expect(_textContaining('open lib/main.dart'), findsOneWidget);
    expect(_textContaining('lib/other.dart:7'), findsOneWidget);
    expect(_textContaining('lib/third.dart:8'), findsOneWidget);
  });

  testWidgets('unsupported content stays readable and images stay text', (
    tester,
  ) async {
    const source =
        '<custom>Source HTML</custom>\n\n'
        r'$a+b$'
        '\n\n```mermaid\ngraph TD; A-->B\n```\n\n'
        '![source image](https://example.test/image.png)';
    await tester.pumpWidget(_surface(const MarkdownContent(source: source)));

    expect(_textContaining('<custom>Source HTML</custom>'), findsOneWidget);
    expect(_textContaining(r'$a+b$'), findsOneWidget);
    expect(_textContaining('graph TD; A-->B'), findsOneWidget);
    expect(
      find.text('![source image](https://example.test/image.png)'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('file callbacks follow updated consumers and spans dispose', (
    tester,
  ) async {
    final first = <FilePathMatch>[];
    final second = <FilePathMatch>[];
    await tester.pumpWidget(
      _surface(MarkdownContent(source: 'lib/main.dart', onFile: first.add)),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(FilePathLink),
        matching: find.byType(Text),
      ),
    );
    final recognizer =
        (text.textSpan! as TextSpan).recognizer! as TapGestureRecognizer;
    await tester.tap(find.byType(FilePathLink));
    expect(first, hasLength(1));

    await tester.pumpWidget(
      _surface(MarkdownContent(source: 'lib/main.dart', onFile: second.add)),
    );
    await tester.tap(find.byType(FilePathLink));
    expect(first, hasLength(1));
    expect(second, hasLength(1));

    await tester.pumpWidget(_surface(const SizedBox()));
    expect(recognizer.onTap, isNull);
    expect(tester.takeException(), isNull);
  });
}
