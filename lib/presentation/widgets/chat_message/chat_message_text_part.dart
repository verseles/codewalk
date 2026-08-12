part of '../chat_message_widget.dart';

/// Text part rendering with markdown support and clipboard actions.
extension _ChatMessageTextPartBuilder on _ChatMessageWidgetState {
  Widget _buildTextPart(BuildContext context, TextPart part) {
    // Don't display if text is empty or only whitespace
    if (part.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final textForRender = _truncatePreview(
      context,
      part.text,
      maxChars: _ChatMessageWidgetState._maxMarkdownCharsForRichRender,
      reason: context.l10n.chatMessageLargeMessageTruncated,
    );
    final usePlainText = textForRender != part.text;
    final themeTokens = _resolveThemeTokens(context);
    final searchHighlightedText = _buildSearchHighlightedText(
      context,
      textForRender,
      style: Theme.of(context).textTheme.bodyMedium,
    );

    final mathRenderingEnabled =
        context.watch<SettingsProvider?>()?.showMathRendering ?? true;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchHighlightedText != null)
            searchHighlightedText
          else if (usePlainText)
            Text(textForRender, style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            MarkdownBody(
              data: textForRender,
              softLineBreak: true,
              styleSheet: _resolveMarkdownStyleSheet(context),
              inlineSyntaxes: [
                if (widget.onFileTap != null) FilePathSyntax(),
                if (mathRenderingEnabled) InlineMathSyntax(),
                if (mathRenderingEnabled) SingleLineBlockMathSyntax(),
              ],
              blockSyntaxes: mathRenderingEnabled
                  ? const [BlockMathSyntax()]
                  : null,
              builders: <String, MarkdownElementBuilder>{
                'pre': _MarkdownCodeBlockTapBuilder(
                  themeTokens: themeTokens,
                  onTapCode: (code) => _copyTextToClipboard(context, code),
                  onMermaidCode: (code) => MermaidDiagramWidget(
                    code: code,
                    onCopySource: () => _copyTextToClipboard(context, code),
                  ),
                ),
                'code': _MarkdownInlineCodeTapBuilder(
                  themeTokens: themeTokens,
                  onTapCode: (code) => _copyTextToClipboard(context, code),
                  onTapFilePath: widget.onFileTap,
                ),
                if (widget.onFileTap != null)
                  'filepath': FilePathBuilder(onFileTap: widget.onFileTap!),
                if (mathRenderingEnabled) 'inlineMath': InlineMathBuilder(),
                if (mathRenderingEnabled) 'blockMath': BlockMathBuilder(),
              },
              onTapLink: (text, href, title) {
                final normalizedHref = href?.trim();
                if (normalizedHref == null || normalizedHref.isEmpty) {
                  return;
                }
                unawaited(_openMarkdownLink(context, normalizedHref));
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget? _buildSearchHighlightedText(
    BuildContext context,
    String text, {
    TextStyle? style,
  }) {
    final query = searchHighlightQuery?.trim();
    if (query == null || query.isEmpty) {
      return null;
    }
    return SelectableText.rich(
      _buildSearchHighlightedTextSpan(
        context,
        text,
        query: query,
        style: style,
      ),
    );
  }

  TextSpan _buildSearchHighlightedTextSpan(
    BuildContext context,
    String text, {
    required String query,
    TextStyle? style,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final highlightStyle = baseStyle?.copyWith(
      color: colorScheme.onTertiaryContainer,
      backgroundColor: colorScheme.tertiaryContainer,
      fontWeight: FontWeight.w700,
    );
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }
      final end = index + query.length;
      spans.add(
        TextSpan(text: text.substring(index, end), style: highlightStyle),
      );
      start = end;
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  String _composeMessageCopyText(ChatMessage message) {
    final parts = message.parts
        .whereType<TextPart>()
        .map((part) => part.text.trim())
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    return parts.join('\n\n');
  }

  void _copyTextToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.msgCopiedToClipboard)));
  }

  Future<void> _openMarkdownLink(BuildContext context, String href) async {
    var uri = Uri.tryParse(href);
    if (uri == null) {
      _showLinkOpenFeedback(context, context.l10n.chatMessageInvalidLinkFormat);
      return;
    }
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$href');
    }
    if (uri == null || uri.host.trim().isEmpty) {
      _showLinkOpenFeedback(context, context.l10n.chatMessageInvalidLinkFormat);
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        if (!context.mounted) return;
        _showLinkOpenFeedback(
          context,
          context.l10n.chatMessageUnableToOpenLink,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to open markdown link',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      _showLinkOpenFeedback(context, context.l10n.chatMessageUnableToOpenLink);
    }
  }

  void _showLinkOpenFeedback(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MarkdownCodeBlockTapBuilder extends MarkdownElementBuilder {
  _MarkdownCodeBlockTapBuilder({
    required this.themeTokens,
    required this.onTapCode,
    this.onMermaidCode,
  });

  final OpenCodeThemeTokens themeTokens;
  final ValueChanged<String> onTapCode;

  /// If set and the fenced block language is "mermaid", the builder
  /// returns a MermaidDiagramWidget instead of a normal code block.
  final Widget Function(String code)? onMermaidCode;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    if (code.trim().isEmpty) {
      return null;
    }
    final language = _markdownCodeLanguage(element);

    // Route mermaid blocks to the diagram widget.
    if (language == 'mermaid' && onMermaidCode != null) {
      return onMermaidCode!(code);
    }

    final inheritedStyle =
        preferredStyle ??
        parentStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    final style = inheritedStyle.copyWith(
      fontFamily: 'monospace',
      color: themeTokens.markdownCodeBlock,
      backgroundColor: Colors.transparent,
      height: 1.45,
    );
    final highlightTheme = openCodeHighlightTheme(
      tokens: themeTokens,
      brightness: Theme.of(context).brightness,
      baseStyle: style,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapCode(code),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: themeTokens.codeBlockBackground,
          border: Border.all(color: themeTokens.border.withValues(alpha: 0.7)),
          borderRadius: AppShapes.borderSmall,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: language == null
              ? Text(code, style: style)
              : HighlightView(
                  code,
                  language: language,
                  theme: highlightTheme,
                  textStyle: style,
                ),
        ),
      ),
    );
  }

  String? _markdownCodeLanguage(md.Element element) {
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'code') {
        continue;
      }
      final className = child.attributes['class']?.trim();
      if (className == null || className.isEmpty) {
        return null;
      }
      for (final token in className.split(RegExp(r'\s+'))) {
        if (token.startsWith('language-')) {
          final language = token.substring('language-'.length).trim();
          if (language.isNotEmpty) {
            return language;
          }
        }
      }
    }
    return null;
  }
}

class _MarkdownInlineCodeTapBuilder extends MarkdownElementBuilder {
  _MarkdownInlineCodeTapBuilder({
    required this.themeTokens,
    required this.onTapCode,
    this.onTapFilePath,
  });

  final OpenCodeThemeTokens themeTokens;
  final ValueChanged<String> onTapCode;
  final void Function(String path, int? line, int? col)? onTapFilePath;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    if (code.trim().isEmpty) {
      return null;
    }
    final filePathTap = _resolveInlineCodeFilePathTap(code);
    final inheritedStyle =
        preferredStyle ??
        parentStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    final style = inheritedStyle.copyWith(
      fontFamily: 'monospace',
      color: themeTokens.markdownInlineCode,
      backgroundColor: Colors.transparent,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: filePathTap ?? () => onTapCode(code),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: themeTokens.inlineCodeBackground,
          borderRadius: AppShapes.borderSmall,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(code, style: style),
        ),
      ),
    );
  }

  VoidCallback? _resolveInlineCodeFilePathTap(String code) {
    final onTap = onTapFilePath;
    if (onTap == null) {
      return null;
    }
    final trimmed = code.trim();
    final matches = FilePathDetector().detect(trimmed);
    if (matches.length != 1 || matches.single.fullText != trimmed) {
      return null;
    }
    final match = matches.single;
    // Inline code commonly wraps file paths in assistant prose. Treat a whole
    // inline-code file path as navigation, while preserving copy behavior for
    // ordinary code snippets and fenced code blocks.
    return () => onTap(match.path, match.lineNumber, match.columnNumber);
  }
}
