import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Inline code (`like this`) that copies itself on a tap (#492). It returns
/// a plain `Text.rich`, which the Markdown builder merges into the paragraph
/// so the code flows with the words around it. Fenced blocks keep their own
/// copy button: their `pre` builder draws them from the element's text.
class InlineCodeCopyBuilder extends MarkdownElementBuilder {
  InlineCodeCopyBuilder({required this.recognizerFor, required this.linked});

  /// The tap recognizer for one code text, owned by the caller.
  final GestureRecognizer Function(String code) recognizerFor;

  /// For each `code` element of the parsed body, in document order, whether
  /// it sits inside a link's text; such code keeps the link's tap.
  final List<bool> linked;
  var _next = 0;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Every parse visits the same code elements in the same order, and the
    // body may parse more than once with one builder (a theme change does),
    // so the flags wrap around.
    final inLink = linked.isNotEmpty && linked[_next % linked.length];
    _next++;
    final code = element.textContent;
    if (code.isEmpty || inLink) return null;
    return Text.rich(
      TextSpan(
        text: code,
        style: parentStyle?.merge(preferredStyle) ?? preferredStyle,
        recognizer: recognizerFor(code),
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}

/// For each `code` element of [source] parsed as the Markdown body parses it
/// ([extensionSet], lines split the same way), in document order, whether it
/// sits inside a link's text, as in [`name`](url) or a reference link.
List<bool> inlineCodeInLinks(String source, md.ExtensionSet extensionSet) {
  if (!source.contains('`') || !source.contains('[')) return const [];
  final nodes = md.Document(
    extensionSet: extensionSet,
    encodeHtml: false,
  ).parseLines(const LineSplitter().convert(source));
  final flags = <bool>[];
  void visit(List<md.Node>? nodes, bool inLink) {
    for (final node in nodes ?? const <md.Node>[]) {
      if (node is! md.Element) continue;
      if (node.tag == 'code') flags.add(inLink);
      visit(node.children, inLink || node.tag == 'a');
    }
  }

  visit(nodes, false);
  return flags;
}
