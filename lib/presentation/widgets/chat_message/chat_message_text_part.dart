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

    final mathRenderingEnabled = context.select<SettingsProvider?, bool>(
      (s) => s?.showMathRendering ?? true,
    );

    Widget buildMarkdown(String text) {
      final supportsHtml = widget.message is AssistantMessage;
      return MarkdownBody(
        data: text,
        softLineBreak: true,
        styleSheet: _resolveMarkdownStyleSheet(context),
        inlineSyntaxes: [
          if (supportsHtml) BasicHtmlInlineSyntax(),
          if (widget.onFileTap != null) FilePathSyntax(),
          if (mathRenderingEnabled) InlineMathSyntax(),
          if (mathRenderingEnabled) SingleLineBlockMathSyntax(),
        ],
        blockSyntaxes: [
          if (supportsHtml) const BasicHtmlBlockSyntax(),
          if (mathRenderingEnabled) const BlockMathSyntax(),
        ],
        builders: <String, MarkdownElementBuilder>{
          if (supportsHtml) ...{
            basicHtmlTextTag: BasicHtmlTextBuilder(),
            basicHtmlProgressTag: BasicHtmlProgressBuilder(),
            basicHtmlMathTag: BasicHtmlMathBuilder(),
          },
          'pre': _MarkdownCodeBlockTapBuilder(
            partId: part.id,
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
        paddingBuilders: {
          if (supportsHtml) 'a': BasicHtmlLinkPaddingBuilder(),
        },
        onTapLink: (text, href, title) {
          final normalizedHref = href?.trim();
          if (normalizedHref == null || normalizedHref.isEmpty) {
            return;
          }
          unawaited(_openMarkdownLink(context, normalizedHref));
        },
      );
    }

    // Issue #176: while an assistant message streams, its MarkdownBody
    // re-parses + re-highlights the whole text on every batch. Throttle
    // rich re-renders (trailing edge, flush on completion below); settled
    // messages keep the exact current path.
    final message = widget.message;
    final isStreamingMarkdown =
        !usePlainText &&
        searchHighlightedText == null &&
        message is AssistantMessage &&
        !message.isCompleted &&
        isSessionActivelyResponding;
    final markdownChild = isStreamingMarkdown
        ? _StreamingMarkdownThrottle(
            text: textForRender,
            builder: buildMarkdown,
          )
        : buildMarkdown(textForRender);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchHighlightedText != null)
            searchHighlightedText
          else if (usePlainText)
            Text(textForRender, style: Theme.of(context).textTheme.bodyMedium)
          else
            markdownChild,
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

/// Issue #176: trailing-edge throttle for streaming rich-markdown renders.
///
/// While an assistant message streams, the parent rebuilds on every event
/// batch with slightly longer text. Re-rendering Markdown + code highlight
/// per batch re-parses the whole text; this widget caps expensive renders
/// to one per throttle window showing the latest text. Completion
/// switches the parent back to the direct path, so the final paint is
/// always immediate and complete. Plain-text/search paths are unaffected.
class _StreamingMarkdownThrottle extends StatefulWidget {
  const _StreamingMarkdownThrottle({
    required this.text,
    required this.builder,
  });

  // Aligned with the realtime batch per platform (120ms desktop, 16ms
  // mobile/web): markdown never re-parses more often than notifies arrive;
  // completion still flushes. Desktop-only CPU savings must not slow mobile.
  static Duration get throttleWindow {
    if (kIsWeb) {
      return const Duration(milliseconds: 48);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => const Duration(milliseconds: 120),
      _ => const Duration(milliseconds: 48),
    };
  }

  final String text;
  final Widget Function(String text) builder;

  @override
  State<_StreamingMarkdownThrottle> createState() =>
      _StreamingMarkdownThrottleState();
}

class _StreamingMarkdownThrottleState
    extends State<_StreamingMarkdownThrottle> {
  late String _renderedText = widget.text;
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _StreamingMarkdownThrottle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _renderedText) {
      return;
    }
    _timer ??= Timer(_StreamingMarkdownThrottle.throttleWindow, () {
      _timer = null;
      if (!mounted || widget.text == _renderedText) {
        return;
      }
      setState(() => _renderedText = widget.text);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_renderedText);
}

class _MarkdownCodeBlockTapBuilder extends MarkdownElementBuilder {
  _MarkdownCodeBlockTapBuilder({
    required this.partId,
    required this.themeTokens,
    required this.onTapCode,
    this.onMermaidCode,
  });

  final OpenCodeThemeTokens themeTokens;
  final String partId;
  int _blockIndex = 0;
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
    final blockIndex = _blockIndex++;

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
    return _MarkdownScrollableCodeBlock(
      key: ValueKey<String>('markdown_code_${partId}_$blockIndex'),
      themeTokens: themeTokens,
      onTapCode: () => onTapCode(code),
      child: language == null
          ? Text(code, style: style)
          : HighlightView(
              code,
              language: language,
              theme: highlightTheme,
              textStyle: style,
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

class _MarkdownScrollableCodeBlock extends StatefulWidget {
  const _MarkdownScrollableCodeBlock({
    super.key,
    required this.themeTokens,
    required this.onTapCode,
    required this.child,
  });

  final OpenCodeThemeTokens themeTokens;
  final VoidCallback onTapCode;
  final Widget child;

  @override
  State<_MarkdownScrollableCodeBlock> createState() =>
      _MarkdownScrollableCodeBlockState();
}

class _MarkdownScrollableCodeBlockState
    extends State<_MarkdownScrollableCodeBlock> {
  final _controller = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'Markdown code scrolling');
  Timer? _interactionTimer;
  bool _overflow = false;
  bool _hovered = false;
  bool _focused = false;
  bool _interacting = false;
  bool _metricsScheduled = false;

  @override
  void dispose() {
    _interactionTimer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _updateMetrics() {
    if (_metricsScheduled) return;
    _metricsScheduled = true;
    // Layout/streaming can change the extent without changing the offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final overflow = _controller.position.maxScrollExtent > 0;
      if (overflow != _overflow) {
        setState(() => _overflow = overflow);
      }
    });
  }

  void _showDuringInteraction() {
    _interactionTimer?.cancel();
    if (!_interacting) setState(() => _interacting = true);
    _interactionTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _interacting = false);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (!node.hasPrimaryFocus ||
        !_overflow ||
        event is KeyUpEvent ||
        keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final position = _controller.position;
    final double target;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      target = position.pixels - 80;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      target = position.pixels + 80;
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      target = position.minScrollExtent;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      target = position.maxScrollExtent;
    } else {
      return KeyEventResult.ignored;
    }
    _controller.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    _showDuringInteraction();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final desktop =
        platform != TargetPlatform.android && platform != TargetPlatform.iOS;
    final visible =
        _overflow &&
        (desktop ? _hovered || _focused || _interacting : _focused);
    return Focus(
      focusNode: _focusNode,
      canRequestFocus: _overflow,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.themeTokens.codeBlockBackground,
            border: Border.all(
              color: _focused
                  ? Theme.of(context).colorScheme.primary
                  : widget.themeTokens.border.withValues(alpha: 0.7),
            ),
            borderRadius: AppShapes.borderSmall,
          ),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.horizontal)
                _updateMetrics();
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 &&
                    notification.metrics.axis == Axis.horizontal) {
                  _updateMetrics();
                  if (notification is ScrollUpdateNotification) {
                    _showDuringInteraction();
                  }
                }
                return false;
              },
              // This scrollbar belongs to the code box, not the screen edge.
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeTop: true,
                removeRight: true,
                removeBottom: true,
                child: Scrollbar(
                  controller: _controller,
                  interactive: true,
                  thumbVisibility: visible,
                  trackVisibility: desktop && visible,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thickness: 6,
                  child: SingleChildScrollView(
                    controller: _controller,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(8, 8, 8, _overflow ? 20 : 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTapCode,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
