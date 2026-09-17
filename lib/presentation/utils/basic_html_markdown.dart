import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../widgets/app_indeterminate_progress.dart';
import 'math_markdown.dart';

const basicHtmlTextTag = 'cwHtmlText';
const basicHtmlProgressTag = 'cwHtmlProgress';
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
      children = parser.document.parseInline(inner);
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
      for (final node in _emphasize(
        children,
        tag.name == 'b' ? 'strong' : 'em',
      )) {
        parser.addNode(node);
      }
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
    final source = parser.source;
    final pairs = <int, _HtmlTag>{};
    final stack = <_HtmlTag>[];
    final math = parser.document.inlineSyntaxes.where(
      (s) => s is InlineMathSyntax || s is SingleLineBlockMathSyntax,
    );
    var pos = 0;
    while (pos < source.length) {
      if (source.codeUnitAt(pos) == 92) {
        pos += 2;
        continue;
      }
      if (source.codeUnitAt(pos) == 96) {
        final run = RegExp('`+').matchAsPrefix(source, pos)!;
        final length = run.end - pos;
        var end = run.end;
        for (final next in RegExp('`+').allMatches(source, end)) {
          if (next.end - next.start == length) {
            end = next.end;
            break;
          }
        }
        pos = end;
        continue;
      }
      if (source.codeUnitAt(pos) == 36) {
        Match? match;
        for (final syntax in math) {
          match = syntax.pattern.matchAsPrefix(source, pos);
          if (match != null) break;
        }
        if (match != null) {
          pos = match.end;
          continue;
        }
      }
      final tag = source.codeUnitAt(pos) == 60
          ? _HtmlTag.read(source, pos)
          : null;
      if (tag == null) {
        pos++;
        continue;
      }
      pos = tag.end;
      if (!_tags.contains(tag.name) || tag.name == 'br' || tag.selfClosing) {
        continue;
      }
      if (!tag.closing) {
        stack.add(tag);
      } else if (stack.isNotEmpty && stack.last.name == tag.name) {
        pairs[stack.removeLast().start] = tag;
      } else {
        stack.clear();
      }
    }
    return pairs;
  }
}

// Existing math builders are block elements. Keep them outside newly-created
// inline emphasis ancestors, which MarkdownBody cannot lay out around a block.
List<md.Node> _emphasize(List<md.Node> nodes, String tag) {
  final result = <md.Node>[];
  var run = <md.Node>[];
  void flush() {
    if (run.isNotEmpty) result.add(md.Element(tag, run));
    run = <md.Node>[];
  }

  for (final node in nodes) {
    if (node is md.Element &&
        (node.tag == 'inlineMath' || node.tag == 'blockMath')) {
      flush();
      result.add(node);
    } else {
      run.add(node);
    }
  }
  flush();
  return result;
}

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

  static final _token = RegExp(
    r'''</?([a-z][a-z0-9]*)(\s+(?:[^<>"']|"[^"]*"|'[^']*')*)?\s*/?>''',
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
    final match = _token.matchAsPrefix(source, start);
    if (match == null) return null;
    final closing = source.startsWith('</', start);
    final attrs = <String, String>{};
    for (final attr in _attribute.allMatches(match[2] ?? '')) {
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
      match.end,
      match[1]!.toLowerCase(),
      closing,
      match[0]!.endsWith('/>'),
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
    var style = parentStyle ?? Theme.of(context).textTheme.bodyMedium!;
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
