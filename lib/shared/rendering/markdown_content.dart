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
    this.trailingSemanticsLabel,
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
  /// [onTapTrailing] when tapped or activated from the keyboard: the turn's
  /// speed and time (#538). It joins the last paragraph only when the parsed
  /// source ends in running text; after anything else (code, a table, a
  /// rule, a setext heading, math, HTML) it takes a line of its own below,
  /// and the source is never changed.
  final String? trailingText;
  final TextStyle? trailingStyle;
  final VoidCallback? onTapTrailing;

  /// What a screen reader announces for [trailingText].
  final String? trailingSemanticsLabel;

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

  /// The latest [MarkdownContent.onTapTrailing]: the trailing button built
  /// with an earlier parse still runs it.
  VoidCallback? _onTrailing;

  @override
  void dispose() {
    for (final recognizer in _codeTaps.values) {
      recognizer.dispose();
    }
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

    var extensionSet = md.ExtensionSet(
      [...blockSyntaxes, ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
      [...inlineSyntaxes, ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
    );
    final trailing = widget.trailingText;
    _onTrailing = widget.onTapTrailing;
    Widget? trailingButton() => trailing == null
        ? null
        : _TrailingButton(
            text: trailing,
            style: widget.trailingStyle,
            semanticsLabel: widget.trailingSemanticsLabel,
            onTap: widget.onTapTrailing == null
                ? null
                : () => _onTrailing?.call(),
          );
    final inline =
        trailing != null && trailingFitsInline(widget.source, extensionSet);
    if (inline) {
      builders[_TrailingSyntax.tag] = _TrailingBuilder(trailingButton()!);
      extensionSet = md.ExtensionSet(extensionSet.blockSyntaxes, [
        _TrailingSyntax(),
        ...extensionSet.inlineSyntaxes,
      ]);
    }
    if (widget.onCopyInlineCode != null) {
      builders['code'] = InlineCodeCopyBuilder(
        recognizerFor: _codeTap,
        linked: _linkFlags(extensionSet),
      );
    }

    final markdown = MarkdownBody(
      // A new trailing text parses again: the body keeps its spans until
      // its data changes.
      key: trailing == null ? null : ValueKey((trailing, inline)),
      data: inline
          ? '${widget.source.trimRight()} $_trailingMark'
          : widget.source,
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
    if (trailing == null) return markdown;
    if (inline) {
      // A paragraph reads as its own text, leaving out what flows in it, so
      // a screen reader gets the trailing button as a node of its own.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          markdown,
          Semantics(
            button: widget.onTapTrailing != null,
            label: widget.trailingSemanticsLabel ?? trailing,
            onTap: widget.onTapTrailing == null
                ? null
                : () => _onTrailing?.call(),
            child: const SizedBox(height: 1),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        markdown,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: trailingButton(),
        ),
      ],
    );
  }
}

/// The private-use character that marks where [MarkdownContent.trailingText]
/// goes; a model's answer has no business using it.
const _trailingMark = '\uE000';

/// A link reference definition, which the parse keeps out of the document.
final _linkReference = RegExp(r'^ {0,3}\[[^\]]+\]:');

/// The block elements a trailing text never joins.
const _blockTags = {
  'pre', 'table', 'hr', 'blockquote', 'ul', 'ol', 'li', 'p', //
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockMath', 'details',
};

/// Whether [source] ends in running text that a trailing text can follow
/// on the same line (#538): its parsed last block is a paragraph or an ATX
/// heading, directly or as the end of a list item or a quote, its last line
/// is that text (not a link reference definition), and it does not use the
/// private marker itself.
@visibleForTesting
bool trailingFitsInline(String source, md.ExtensionSet extensionSet) {
  final trimmed = source.trimRight();
  if (trimmed.isEmpty || trimmed.contains(_trailingMark)) return false;
  final lines = trimmed.split('\n');
  if (_linkReference.hasMatch(lines.last)) return false;
  final nodes = md.Document(
    extensionSet: extensionSet,
    encodeHtml: false,
  ).parseLines(lines);
  var node = nodes.lastOrNull;
  var top = true;
  while (node is md.Element) {
    switch (node.tag) {
      case 'p':
        return true;
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        // A setext heading ends in its underline.
        return lines.last.trimLeft().startsWith('#');
      case 'ul' || 'ol' || 'li' || 'blockquote':
        top = false;
        node = node.children?.lastOrNull;
      default:
        // Inside a tight list item, an inline element ends the text.
        return !top && !_blockTags.contains(node.tag);
    }
  }
  // Raw HTML at the top is a block; text inside a tight list item is not.
  return !top && node is md.Text;
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

/// The trailing button as a span of the paragraph it ends, so it flows right
/// after the last word, on the text's baseline.
class _TrailingBuilder extends MarkdownElementBuilder {
  _TrailingBuilder(this.button);

  final Widget button;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: button,
        ),
      ],
    ),
  );
}

/// The trailing text as a quiet button: a tap, Enter or Space runs it, and a
/// screen reader names it. It stays out of a text selection.
class _TrailingButton extends StatelessWidget {
  const _TrailingButton({
    required this.text,
    this.style,
    this.semanticsLabel,
    this.onTap,
  });

  final String text;
  final TextStyle? style;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: style, semanticsLabel: semanticsLabel);
    if (onTap == null) return SelectionContainer.disabled(child: label);
    return SelectionContainer.disabled(
      child: Semantics(
        button: true,
        label: semanticsLabel ?? text,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          key: const ValueKey('message-trailing-stats'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: label,
        ),
      ),
    );
  }
}
