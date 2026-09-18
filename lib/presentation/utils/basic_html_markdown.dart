import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../widgets/app_indeterminate_progress.dart';
import 'math_markdown.dart';

const basicHtmlTextTag = 'cwHtmlText';
const basicHtmlProgressTag = 'cwHtmlProgress';
const basicHtmlMathTag = 'cwHtmlMath';
const _tags = {'b', 'i', 'u', 'br', 'sub', 'sup', 'progress'};

/// Keep supported tag-only lines in the normal Markdown paragraph pipeline.
/// The default HTML block parser emits root text which MarkdownBody discards.
class BasicHtmlBlockSyntax extends md.ParagraphSyntax {
  const BasicHtmlBlockSyntax();

  static final _start = RegExp(
    r'^ {0,3}</?(?:b|i|u|br|sub|sup|progress)(?=[\s/>])',
    caseSensitive: false,
  );

  @override
  bool canParse(md.BlockParser parser) =>
      _start.hasMatch(parser.current.content);

  @override
  md.Node? parse(md.BlockParser parser) {
    const table = md.TableSyntax();
    if (table.canParse(parser)) {
      final result = table.parse(parser);
      if (result != null) return result;
      // A delimiter alone is only a hint. A rejected table restores its cursor;
      // keep the paragraph fallback here so HtmlBlockSyntax cannot hide it.
    }
    return super.parse(parser);
  }
}

/// A bounded, presentation-only subset of HTML; source text is never rewritten.
class BasicHtmlInlineSyntax extends md.InlineSyntax {
  BasicHtmlInlineSyntax() : super('<', startCharacter: 60);

  final _pairs = Expando<Map<int, _HtmlTag>>();
  var _depth = 0;

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    if (parser.source.codeUnitAt(start) != 60) return false;
    final tag = _HtmlTag.read(parser.source, start);
    if (tag == null || !_tags.contains(tag.name)) return false;
    parser.writeText();
    final pairs = _pairs[parser] ??= _matchPairs(parser);
    final close = pairs[start];
    if (tag.closing ||
        _depth >= 32 ||
        (tag.name != 'br' &&
            !(tag.name == 'progress' && tag.selfClosing) &&
            close == null)) {
      parser.addNode(md.Text(parser.source.substring(start, tag.end)));
      parser.consume(tag.end - start);
      return true;
    }
    if (tag.name == 'br') {
      parser.addNode(md.Element.empty('br'));
      parser.consume(tag.end - start);
      return true;
    }
    final end = close?.end ?? tag.end;
    final inner = parser.source.substring(tag.end, close?.start ?? tag.end);
    _depth++;
    late final List<md.Node> children;
    try {
      children = _inlineHtmlMath(parser.document.parseInline(inner));
    } finally {
      _depth--;
    }
    if (tag.name == 'progress') {
      final element = md.Element(basicHtmlProgressTag, const []);
      final attributes = tag.attributes;
      for (final key in ['value', 'max', 'aria-label']) {
        if (attributes.containsKey(key)) {
          element.attributes[key] = attributes[key]!;
        }
      }
      element.attributes['fallback'] = children
          .map((n) => n.textContent)
          .join();
      parser.addNode(element);
    } else if (tag.name == 'b' || tag.name == 'i') {
      parser.addNode(md.Element(tag.name == 'b' ? 'strong' : 'em', children));
    } else {
      for (final node in _decorate(children, tag.name)) {
        parser.addNode(node);
      }
    }
    parser.consume(end - start);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;

  // Pair once per inline parser, avoiding repeated scans of unmatched openers.
  Map<int, _HtmlTag> _matchPairs(md.InlineParser parser) {
    final pairs = <int, _HtmlTag>{};
    final stack = <_HtmlTag>[];
    // Let the same lexer mask code, math, raw HTML and link destinations/titles.
    final document = md.Document(
      inlineSyntaxes: [
        _HtmlPairSyntax((tag) {
          if (tag.name == 'br' || tag.selfClosing) return;
          if (!tag.closing) {
            stack.add(tag);
          } else if (stack.isNotEmpty && stack.last.name == tag.name) {
            pairs[stack.removeLast().start] = tag;
          } else {
            stack.clear();
          }
        }),
        ...parser.document.inlineSyntaxes.where(
          (syntax) => syntax is! BasicHtmlInlineSyntax,
        ),
      ],
      extensionSet: md.ExtensionSet(const [], const []),
      encodeHtml: false,
    )..linkReferences.addAll(parser.document.linkReferences);
    document.parseInline(parser.source);
    return pairs;
  }
}

class _HtmlPairSyntax extends md.InlineSyntax {
  _HtmlPairSyntax(this.onTag) : super('<', startCharacter: 60);

  final void Function(_HtmlTag) onTag;

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final start = startMatchPos ?? parser.pos;
    if (parser.source.codeUnitAt(start) != 60) return false;
    final tag = _HtmlTag.read(parser.source, start);
    if (tag == null || !_tags.contains(tag.name)) return false;
    onTag(tag);
    parser.writeText();
    parser.addNode(md.Text(parser.source.substring(start, tag.end)));
    parser.consume(tag.end - start);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}

// Reparsed math may acquire outer Markdown emphasis later. Private inline tags
// keep it safe there without changing the existing global block math builders.
List<md.Node> _inlineHtmlMath(List<md.Node> nodes) => nodes.map((node) {
  if (node is md.Element) {
    if (node.tag == 'inlineMath' || node.tag == 'blockMath') {
      final math = md.Element(basicHtmlMathTag, node.children);
      math.attributes.addAll(node.attributes);
      math.attributes['display'] = '${node.tag == 'blockMath'}';
      return math;
    }
    if (node.children != null) {
      return md.Element(node.tag, _inlineHtmlMath(node.children!))
        ..attributes.addAll(node.attributes);
    }
  }
  return node;
}).toList();

List<md.Node> _decorate(List<md.Node> nodes, String style) {
  return nodes.map((node) {
    if (node is md.Text) {
      final leaf = md.Element(basicHtmlTextTag, [node]);
      leaf.attributes[style == 'u' ? 'underline' : 'script'] = style;
      return leaf;
    }
    if (node is md.Element) {
      if (node.tag == basicHtmlTextTag) {
        if (style == 'u') {
          node.attributes['underline'] = style;
        } else {
          // The innermost script wins; underline composes independently.
          node.attributes.putIfAbsent('script', () => style);
        }
      } else if (const {'strong', 'em', 'del'}.contains(node.tag)) {
        final children = node.children!;
        final decorated = _decorate(children, style);
        children
          ..clear()
          ..addAll(decorated);
      }
      // Links and widget-producing code/math/file paths stay opaque. Replacing
      // their children would discard recognizers or existing custom builders.
    }
    return node;
  }).toList();
}

class _HtmlTag {
  const _HtmlTag(
    this.start,
    this.end,
    this.name,
    this.closing,
    this.selfClosing,
    this.attributes,
  );

  final int start;
  final int end;
  final String name;
  final bool closing;
  final bool selfClosing;
  final Map<String, String> attributes;

  static final _name = RegExp(
    r'</?([a-z][a-z0-9]*)(?=[\s/>])',
    caseSensitive: false,
  );
  static final _attribute = RegExp(
    r'''([^\s/="'<>`]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''',
  );
  static final _entities = md.Document(
    inlineSyntaxes: [md.DecodeHtmlSyntax()],
    withDefaultInlineSyntaxes: false,
    encodeHtml: false,
  );

  static _HtmlTag? read(String source, int start) {
    final match = _name.matchAsPrefix(source, start);
    if (match == null) return null;
    var end = match.end;
    int? quote;
    while (end < source.length) {
      final char = source.codeUnitAt(end++);
      if (quote != null) {
        if (char == quote) quote = null;
      } else if (char == 34 || char == 39) {
        quote = char;
      } else if (char == 60) {
        return null;
      } else if (char == 62) {
        break;
      }
    }
    if (quote != null || source.codeUnitAt(end - 1) != 62) return null;
    final closing = source.startsWith('</', start);
    final attrs = <String, String>{};
    for (final attr in _attribute.allMatches(
      source.substring(match.end, end - 1),
    )) {
      attrs.putIfAbsent(attr[1]!.toLowerCase(), () {
        final value = attr[2] ?? attr[3] ?? attr[4] ?? '';
        return value.contains('&')
            ? _entities
                  .parseInline(value)
                  .map((node) => node.textContent)
                  .join()
            : value;
      });
    }
    return _HtmlTag(
      start,
      end,
      match[1]!.toLowerCase(),
      closing,
      source.codeUnitAt(end - 2) == 47,
      attrs,
    );
  }
}

/// HTML uses a numeric prefix, unlike Dart's whole-string double parser.
double? _htmlNumber(String? source) {
  if (source == null) return null;
  final match = RegExp(
    r'^[\t\n\f\r ]*[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?',
  ).firstMatch(source);
  final value = double.tryParse(match?[0]?.trim() ?? '');
  return value != null && value.isFinite ? value : null;
}

double? basicHtmlProgressValue(Map<String, String> attributes) {
  if (!attributes.containsKey('value')) return null;
  final parsedMax = _htmlNumber(attributes['max']);
  final max = parsedMax != null && parsedMax > 0 ? parsedMax : 1.0;
  final value = _htmlNumber(attributes['value']) ?? 0;
  return value.clamp(0.0, max) / max;
}

class BasicHtmlTextBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var style =
        parentStyle ??
        preferredStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    if (element.attributes.containsKey('underline')) {
      style = style.copyWith(
        decoration: TextDecoration.combine([
          if (style.decoration != null) style.decoration!,
          TextDecoration.underline,
        ]),
      );
    }
    final script = element.attributes['script'];
    if (script == null) {
      return Text.rich(TextSpan(text: element.textContent, style: style));
    }
    final size = style.fontSize ?? 14;
    final shift = MediaQuery.textScalerOf(context).scale(size) * 0.2;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: EdgeInsets.only(
                top: script == 'sup' ? shift : 0,
                bottom: script == 'sub' ? shift : 0,
              ),
              child: Transform.translate(
                offset: Offset(0, script == 'sup' ? -shift : shift),
                child: Text(
                  element.textContent,
                  style: style.copyWith(fontSize: size * 0.75),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keep the package's link recognizers when HTML appears inside a link label.
class BasicHtmlLinkPaddingBuilder extends MarkdownPaddingBuilder {
  @override
  void visitElementBefore(md.Element element) {
    void unwrap(List<md.Node> nodes) {
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node is! md.Element) continue;
        if (node.tag == basicHtmlTextTag) {
          nodes[i] = md.Text(node.textContent);
        } else if (node.children != null) {
          unwrap(node.children!);
        }
      }
    }

    unwrap(element.children ?? []);
  }
}

class BasicHtmlMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final builder = element.attributes['display'] == 'true'
        ? BlockMathBuilder()
        : InlineMathBuilder();
    return builder.visitElementAfterWithContext(
      context,
      element,
      preferredStyle,
      parentStyle,
    );
  }
}

class BasicHtmlProgressBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final value = basicHtmlProgressValue(element.attributes);
    final colors = Theme.of(context).colorScheme;
    final label =
        (element.attributes['aria-label'] ??
                element.attributes['fallback'] ??
                '')
            .trim();
    return SizedBox(
      width: 160,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: value == null
            ? AppIndeterminateBar(
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
                semanticsLabel: label.isEmpty ? null : label,
              )
            : LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
                semanticsLabel: label.isEmpty ? null : label,
              ),
      ),
    );
  }
}
