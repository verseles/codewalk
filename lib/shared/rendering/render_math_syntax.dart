import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import 'render_math_expression.dart';

/// Inline math syntax: `$...$` (single-dollar, must contain LaTeX tokens).
///
/// Ported from legacy `math_markdown.dart` without importing it.
/// The regex requires at least one LaTeX command token between the
/// delimiters, so currency (`$5`) and shell variables (`$PATH`) never
/// match and are left as plain text. Fenced code blocks are block-parsed
/// before inline syntaxes run, so math inside code is naturally excluded.
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(_pattern);

  static const _pattern =
      r'(?<!\S)\$(?!\$)([^$\n]*(?:\\[a-zA-Z]+|[{}\^_~]|\\[\\|!><=])[^$\n]*?)(?<=\S)\$(?!\d)';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.empty('inlineMath');
    element.attributes['expression'] = match[1]!;
    parser.addNode(element);
    return true;
  }
}

/// Block math syntax: `$$...$$` on separate lines.
class BlockMathSyntax extends md.BlockSyntax {
  const BlockMathSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\$\$\s*$');

  @override
  bool canParse(md.BlockParser parser) {
    if (!pattern.hasMatch(parser.current.content)) return false;
    for (var i = 1; i <= 50; i++) {
      final line = parser.peek(i);
      if (line == null) return false;
      if (RegExp(r'^\s*\$\$\s*$').hasMatch(line.content)) {
        return i >= 1;
      }
    }
    return false;
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final contentLines = <String>[];
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (RegExp(r'^\s*\$\$\s*$').hasMatch(line)) {
        parser.advance();
        break;
      }
      contentLines.add(line);
      parser.advance();
    }
    final expression = contentLines.join('\n').trim();
    if (expression.isEmpty) return null;
    return md.Element('blockMath', <md.Node>[md.Text(expression)]);
  }
}

/// Single-line block math: `$$ E=mc^2 $$` on one line.
class SingleLineBlockMathSyntax extends md.InlineSyntax {
  SingleLineBlockMathSyntax() : super(_pattern);

  static const _pattern =
      r'\$\$(.*(?:\\[a-zA-Z]+|[{}\^_~]|\\[\\|!><=]).*?)\$\$';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match[1]!;
    final element = md.Element('blockMath', <md.Node>[
      md.Text(expression),
    ]);
    parser.addNode(element);
    return true;
  }
}

/// Markdown element builder for `inlineMath` elements.
class InlineMathBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final expression = element.attributes['expression'] ?? element.textContent;
    if (expression.trim().isEmpty) return null;
    final textStyle =
        parentStyle ??
        preferredStyle ??
        DefaultTextStyle.of(context).style;
    return RenderMathExpression(
      expression: expression,
      isBlock: false,
      textStyle: textStyle,
    );
  }
}

/// Markdown element builder for `blockMath` elements.
class BlockMathBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final expression = element.textContent;
    if (expression.trim().isEmpty) return null;
    final textStyle = DefaultTextStyle.of(context).style;
    return RenderMathExpression(
      expression: expression,
      isBlock: true,
      textStyle: textStyle,
    );
  }
}
