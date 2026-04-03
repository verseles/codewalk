part of '../chat_message_widget.dart';

/// Text part rendering with markdown support and clipboard actions.
extension _ChatMessageTextPartBuilder on _ChatMessageWidgetState {
  Widget _buildTextPart(BuildContext context, TextPart part) {
    // Don't display if text is empty or only whitespace
    if (part.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final textForRender = _truncatePreview(
      part.text,
      maxChars: _ChatMessageWidgetState._maxMarkdownCharsForRichRender,
      reason: 'Large message preview truncated for app stability.',
    );
    final usePlainText = textForRender != part.text;
    final themeTokens = _resolveThemeTokens(context);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usePlainText)
            Text(textForRender, style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            MarkdownBody(
              data: textForRender,
              softLineBreak: true,
              styleSheet: _resolveMarkdownStyleSheet(context),
              builders: <String, MarkdownElementBuilder>{
                'pre': _MarkdownCodeBlockTapBuilder(
                  themeTokens: themeTokens,
                  onTapCode: (code) => _copyTextToClipboard(context, code),
                ),
                'code': _MarkdownInlineCodeTapBuilder(
                  themeTokens: themeTokens,
                  onTapCode: (code) => _copyTextToClipboard(context, code),
                ),
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
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Future<void> _openMarkdownLink(BuildContext context, String href) async {
    var uri = Uri.tryParse(href);
    if (uri == null) {
      _showLinkOpenFeedback(context, 'Invalid link format');
      return;
    }
    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$href');
    }
    if (uri == null || uri.host.trim().isEmpty) {
      _showLinkOpenFeedback(context, 'Invalid link format');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!launched) {
        _showLinkOpenFeedback(context, 'Unable to open link');
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to open markdown link',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      _showLinkOpenFeedback(context, 'Unable to open link');
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
  });

  final OpenCodeThemeTokens themeTokens;
  final ValueChanged<String> onTapCode;

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
  });

  final OpenCodeThemeTokens themeTokens;
  final ValueChanged<String> onTapCode;

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
      onTap: () => onTapCode(code),
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
}
