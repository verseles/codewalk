import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../theme/opencode_theme_presets.dart';

/// V2 port of the legacy `openCodeHighlightTheme` without legacy imports.
///
/// Maps highlight.js scopes onto governed [OpenCodeThemeTokens] so fenced
/// code blocks follow the active preset (including Material You).
Map<String, TextStyle> buildV2HighlightTheme({
  required OpenCodeThemeTokens tokens,
  required Brightness brightness,
  required TextStyle baseStyle,
}) {
  final base = brightness == Brightness.dark ? atomOneDarkTheme : githubTheme;

  TextStyle styleFor(Color color, {Color? backgroundColor}) {
    return baseStyle.copyWith(color: color, backgroundColor: backgroundColor);
  }

  return <String, TextStyle>{
    ...base,
    'root': styleFor(tokens.textBase),
    'comment': styleFor(tokens.syntaxComment),
    'quote': styleFor(tokens.syntaxComment),
    'keyword': styleFor(tokens.syntaxKeyword),
    'selector-tag': styleFor(tokens.syntaxKeyword),
    'subst': styleFor(tokens.textBase),
    'number': styleFor(tokens.syntaxNumber),
    'literal': styleFor(tokens.syntaxNumber),
    'variable': styleFor(tokens.syntaxVariable),
    'template-variable': styleFor(tokens.syntaxVariable),
    'string': styleFor(tokens.syntaxString),
    'doctag': styleFor(tokens.syntaxKeyword),
    'title': styleFor(tokens.syntaxFunction),
    'section': styleFor(tokens.syntaxFunction),
    'selector-id': styleFor(tokens.syntaxFunction),
    'selector-class': styleFor(tokens.syntaxType),
    'type': styleFor(tokens.syntaxType),
    'tag': styleFor(tokens.syntaxKeyword),
    'name': styleFor(tokens.syntaxFunction),
    'attribute': styleFor(tokens.syntaxProperty),
    'attr': styleFor(tokens.syntaxProperty),
    'regexp': styleFor(tokens.syntaxString),
    'link': styleFor(tokens.markdownLink),
    'symbol': styleFor(tokens.syntaxConstant),
    'bullet': styleFor(tokens.syntaxConstant),
    'built_in': styleFor(tokens.syntaxProperty),
    'builtin-name': styleFor(tokens.syntaxProperty),
    'meta': styleFor(tokens.syntaxComment),
    'meta-string': styleFor(tokens.syntaxString),
    'deletion': styleFor(tokens.syntaxKeyword),
    'addition': styleFor(tokens.syntaxString),
    'emphasis': styleFor(tokens.markdownEmphasis),
    'strong': styleFor(tokens.markdownStrong),
    'operator': styleFor(tokens.syntaxOperator),
    'punctuation': styleFor(tokens.syntaxPunctuation),
    'property': styleFor(tokens.syntaxProperty),
    'function': styleFor(tokens.syntaxFunction),
    'class': styleFor(tokens.syntaxType),
    'params': styleFor(tokens.syntaxVariable),
  };
}
