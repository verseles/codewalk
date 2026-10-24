import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/app_shapes.dart';
import '../theme/opencode_theme_presets.dart';
import 'file_path_detector.dart';
import 'file_path_markdown.dart';
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

  @override
  State<MarkdownContent> createState() => _MarkdownContentState();
}

class _MarkdownContentState extends State<MarkdownContent> {
  void _onFile(FilePathMatch file) => widget.onFile?.call(file);

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
        maxLines: MessageRenderBudget.plainFallbackMaxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final builders = <String, MarkdownElementBuilder>{
      'filepath': FilePathBuilder(onFile: _onFile),
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

    return MarkdownBody(
      data: widget.source,
      extensionSet: md.ExtensionSet(
        [...blockSyntaxes, ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
        [...inlineSyntaxes, ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
      ),
      // Tables match v1: a rounded themed border and a raised header row.
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        tableHead: theme.textTheme.bodyMedium?.copyWith(
          color: tokens.textBase,
          fontWeight: FontWeight.bold,
        ),
        tableBody: theme.textTheme.bodyMedium?.copyWith(color: tokens.textBase),
        tableHeadCellsDecoration: BoxDecoration(color: tokens.surfaceRaised),
        tableBorder: TableBorder.all(
          color: tokens.border.withValues(alpha: 0.7),
          borderRadius: AppShapes.borderExtraSmall,
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
      ),
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
