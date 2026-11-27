import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/app_shapes.dart';
import '../theme/opencode_theme_presets.dart';
import 'file_path_detector.dart';
import 'file_path_markdown.dart';
import 'inline_code_copy.dart';
import 'message_render_budget.dart';
import 'render_basic_html.dart';
import 'render_code_block.dart';
import 'render_math_syntax.dart';

typedef MarkdownLinkCallback =
    void Function(String text, String href, String? title);

/// Canonical rich Markdown bridge (V2-071A, no legacy imports).
///
/// Source content is never translated or edited. Links and file spans emit
/// callbacks; this bridge performs no navigation or file I/O. Images remain
/// text until the media-rendering port is available.
///
/// When all rich flags are false (default), behavior is byte-identical to
/// the minimal GFM bridge: GFM + file-path callbacks, images as text.
/// Enabling [allowBasicHtml], [enableMath], [enableMermaid] /
/// [enableCodeHighlight] ports the retained-legacy rendering patterns
/// without importing them (G4).
class MarkdownContent extends StatefulWidget {
  const MarkdownContent({
    super.key,
    required this.source,
    this.onLink,
    this.onFile,
    this.onCopyCode,
    this.allowBasicHtml = false,
    this.enableMath = false,
    this.enableMermaid = false,
    this.enableCodeHighlight = false,
    this.maxRichCharsForRender = MessageRenderBudget.richRenderMaxChars,
    this.bodyStyle,
    this.onCopyInlineCode,
    this.trailingText,
    this.trailingStyle,
    this.onTapTrailing,
  });

  final String source;
  final MarkdownLinkCallback? onLink;
  final ValueChanged<FilePathMatch>? onFile;
  final ValueChanged<String>? onCopyCode;
  final bool allowBasicHtml;
  final bool enableMath;
  final bool enableMermaid;
  final bool enableCodeHighlight;
  final int maxRichCharsForRender;

  /// The style of running text (paragraphs, lists, quotes, tables and inline
  /// code, which keeps its smaller ratio, file paths included); the theme's
  /// `bodyMedium` when null. Fenced code blocks keep the theme's body size,
  /// and headings their own.
  final TextStyle? bodyStyle;

  /// Copies an inline code span on a tap; inline code is plain when null.
  final ValueChanged<String>? onCopyInlineCode;

  /// A short text right after the last word, in [trailingStyle], that runs
  /// [onTapTrailing] when tapped: the turn's speed and time (#538). After a
  /// last block that is not running text (code, a table, math) it takes a
  /// line of its own.
  final String? trailingText;
  final TextStyle? trailingStyle;
  final VoidCallback? onTapTrailing;

  @override
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent> {
  void _onFile(FilePathMatch file) => widget.onFile?.call(file);

  /// One tap recognizer per inline code text, kept across rebuilds because
  /// the Markdown body keeps its spans until the source changes.
  final _codeTaps = <String, TapGestureRecognizer>{};

  /// The code texts the latest parse of the body used; after the frame that
  /// parsed, the recognizers it no longer uses are let go.
  final _codesInUse = <String>{};
  bool _pruneScheduled = false;

  /// The link flags of the source last parsed for them, since the body
  /// itself parses again only when its source or style changes.
  (String, bool, bool)? _linkedFor;
  List<bool> _linked = const [];

  List<bool> _linkFlags(md.ExtensionSet extensionSet) {
    final key = (widget.source, widget.allowBasicHtml, widget.enableMath);
    if (_linkedFor != key) {
      _linkedFor = key;
      _linked = inlineCodeInLinks(widget.source, extensionSet);
    }
    return _linked;
  }

  GestureRecognizer _codeTap(String code) {
    _codesInUse.add(code);
    if (!_pruneScheduled) {
      _pruneScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _pruneCodeTaps());
    }
    return _codeTaps.putIfAbsent(
      code,
      () =>
          TapGestureRecognizer()
            ..onTap = () => widget.onCopyInlineCode?.call(code),
    );
  }

  void _pruneCodeTaps() {
    _pruneScheduled = false;
    if (!mounted) return;
    _codeTaps.removeWhere((code, recognizer) {
      if (_codesInUse.contains(code)) return false;
      recognizer.dispose();
      return true;
    });
    _codesInUse.clear();
  }

  /// The tap on [MarkdownContent.trailingText], kept across rebuilds.
  TapGestureRecognizer? _trailingTap;

  @override
  void dispose() {
    for (final recognizer in _codeTaps.values) {
      recognizer.dispose();
    }
    _trailingTap?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<OpenCodeThemeTokens>() ??
        classicThemeTokensFrom(theme.colorScheme);
    final partId = widget.key is ValueKey
        ? '${(widget.key! as ValueKey).value}'
        : 'v2tile';

    // Over-budget sources fall back to plain text (same contract as
    // CanonicalMessageBody, defense in depth for direct consumers).
    if (widget.source.runes.length > widget.maxRichCharsForRender) {
      return Text(
        String.fromCharCodes(
          widget.source.runes.take(widget.maxRichCharsForRender),
        ),
        style: widget.bodyStyle,
        maxLines: MessageRenderBudget.plainFallbackMaxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    // The style sheet derives running text from `bodyMedium`.
    final body = widget.bodyStyle;
    final sheet = body == null
        ? theme
        : theme.copyWith(
            textTheme: theme.textTheme.copyWith(
              bodyMedium: theme.textTheme.bodyMedium?.merge(body) ?? body,
            ),
          );
    // Tables match v1: a rounded themed border and a raised header row.
    final styleSheet = MarkdownStyleSheet.fromTheme(sheet).copyWith(
      tableHead: sheet.textTheme.bodyMedium?.copyWith(
        color: tokens.textBase,
        fontWeight: FontWeight.bold,
      ),
      tableBody: sheet.textTheme.bodyMedium?.copyWith(color: tokens.textBase),
      tableHeadCellsDecoration: BoxDecoration(color: tokens.surfaceRaised),
      tableBorder: TableBorder.all(
        color: tokens.border.withValues(alpha: 0.7),
        borderRadius: AppShapes.borderExtraSmall,
      ),
      tableColumnWidth: const IntrinsicColumnWidth(),
    );

    final builders = <String, MarkdownElementBuilder>{
      'filepath': FilePathBuilder(
        onFile: _onFile,
        inlineCodeStyle: styleSheet.code,
      ),
    };
    final paddingBuilders = <String, MarkdownPaddingBuilder>{};
    final inlineSyntaxes = <md.InlineSyntax>[
      InlineFilePathSyntax(),
      FilePathSyntax(),
    ];
    final blockSyntaxes = <md.BlockSyntax>[];

    if (widget.allowBasicHtml) {
      blockSyntaxes.add(const BasicHtmlBlockSyntax());
      inlineSyntaxes.add(BasicHtmlInlineSyntax());
      builders['cwHtmlText'] = BasicHtmlTextBuilder();
      builders['cwHtmlProgress'] = BasicHtmlProgressBuilder();
      paddingBuilders['a'] = BasicHtmlLinkPaddingBuilder();
    }
    if (widget.enableMath) {
      blockSyntaxes.add(const BlockMathSyntax());
      inlineSyntaxes.add(InlineMathSyntax());
      inlineSyntaxes.add(SingleLineBlockMathSyntax());
      builders['inlineMath'] = InlineMathBuilder();
      builders['blockMath'] = BlockMathBuilder();
      builders['cwHtmlMath'] = BasicHtmlMathBuilder();
    }
    if (widget.enableCodeHighlight || widget.enableMermaid) {
      builders['pre'] = RenderCodeBlockBuilder(
        themeTokens: tokens,
        partId: partId,
        onCopyCode: (code) => widget.onCopyCode?.call(code),
        enableMermaid: widget.enableMermaid,
        enableHighlight: widget.enableCodeHighlight,
      );
    }

    final trailing = widget.trailingText;
    if (trailing != null) {
      inlineSyntaxes.insert(0, _TrailingSyntax());
      builders[_TrailingSyntax.tag] = _TrailingBuilder(
        text: trailing,
        style: widget.trailingStyle,
        recognizer: widget.onTapTrailing == null
            ? null
            : ((_trailingTap ??= TapGestureRecognizer())
                ..onTap = widget.onTapTrailing),
      );
    }

    final extensionSet = md.ExtensionSet(
      [...blockSyntaxes, ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
      [...inlineSyntaxes, ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
    );
    if (widget.onCopyInlineCode != null) {
      builders['code'] = InlineCodeCopyBuilder(
        recognizerFor: _codeTap,
        linked: _linkFlags(extensionSet),
      );
    }

    return MarkdownBody(
      data: trailing == null ? widget.source : withTrailingMark(widget.source),
      extensionSet: extensionSet,
      styleSheet: styleSheet,
      builders: builders,
      paddingBuilders: paddingBuilders,
      onTapLink: widget.onLink == null
          ? null
          : (text, href, title) {
              if (href != null) widget.onLink!.call(text, href, title);
            },
      imageBuilder: (uri, title, alt) =>
          Text('![${alt ?? ''}]($uri${title == null ? '' : ' "$title"'})'),
    );
  }
}

/// The private-use character that marks where [MarkdownContent.trailingText]
/// goes; a model's answer has no business using it.
const _trailingMark = '\uE000';

/// [source] with the trailing mark after its last word, or on a line of its
/// own when the last block is not running text: a fence, a table, indented
/// code, display math or HTML, which would swallow or break on it.
@visibleForTesting
String withTrailingMark(String source) {
  final trimmed = source.trimRight();
  if (trimmed.isEmpty) return _trailingMark;
  final last = trimmed.split('\n').last;
  final lead = last.trimLeft();
  final block =
      last.startsWith('    ') ||
      last.startsWith('\t') ||
      lead.startsWith('```') ||
      lead.startsWith('~~~') ||
      lead.startsWith('|') ||
      lead.startsWith(r'$$') ||
      lead.startsWith('<') ||
      _openFence(trimmed);
  return block ? '$trimmed\n\n$_trailingMark' : '$trimmed $_trailingMark';
}

/// Whether [source] ends inside a fenced code block that never closed.
bool _openFence(String source) {
  var open = false;
  for (final line in source.split('\n')) {
    final lead = line.trimLeft();
    if (lead.startsWith('```') || lead.startsWith('~~~')) open = !open;
  }
  return open;
}

class _TrailingSyntax extends md.InlineSyntax {
  _TrailingSyntax() : super(_trailingMark);

  static const tag = 'cwTrailing';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty(tag));
    return true;
  }
}

/// The trailing text as a span of the paragraph it ends, so it flows right
/// after the last word.
class _TrailingBuilder extends MarkdownElementBuilder {
  _TrailingBuilder({required this.text, this.style, this.recognizer});

  final String text;
  final TextStyle? style;
  final GestureRecognizer? recognizer;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      text: text,
      style: (parentStyle ?? preferredStyle)?.merge(style) ?? style,
      recognizer: recognizer,
    ),
  );
}
