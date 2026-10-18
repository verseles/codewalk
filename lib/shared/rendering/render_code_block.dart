import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_shapes.dart';
import '../theme/opencode_theme_presets.dart';
import 'message_render_budget.dart';
import 'render_highlight_theme.dart';
import 'render_mermaid_block.dart';

/// Fenced code block builder with Mermaid routing and syntax highlighting.
///
/// V2 port without legacy imports. Routes `language == 'mermaid'` (or
/// mermaid-looking source) to [RenderMermaidBlock]; renders blocks <=
/// [MessageRenderBudget.codeHighlightMaxChars] with [HighlightView] and
/// larger blocks as plain monospace to protect frame times.
class RenderCodeBlockBuilder extends MarkdownElementBuilder {
  RenderCodeBlockBuilder({
    required this.themeTokens,
    required this.partId,
    required this.onCopyCode,
    this.onMermaidCode,
    this.enableMermaid = true,
    this.enableHighlight = true,
  });

  final OpenCodeThemeTokens themeTokens;
  final String partId;
  int _blockIndex = 0;
  final ValueChanged<String> onCopyCode;
  final Widget Function(String code)? onMermaidCode;
  final bool enableMermaid;
  final bool enableHighlight;

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
    if (code.trim().isEmpty) return null;
    final language = _markdownCodeLanguage(element);
    final blockIndex = _blockIndex++;
    // Only explicit `mermaid` language routes to diagrams. The previous
    // untagged heuristic hijacked ordinary prose-as-code (timeline, journey).
    final isMermaid = language == 'mermaid';
    if (isMermaid && enableMermaid) {
      if (onMermaidCode != null) return onMermaidCode!(code);
      return RenderMermaidBlock(
        key: ValueKey<String>('mermaid_${partId}_$blockIndex'),
        code: code,
        onCopySource: () => onCopyCode(code),
      );
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
    final useHighlight =
        enableHighlight &&
        language != null &&
        code.runes.length <= MessageRenderBudget.codeHighlightMaxChars;
    final highlightTheme = useHighlight
        ? buildV2HighlightTheme(
            tokens: themeTokens,
            brightness: Theme.of(context).brightness,
            baseStyle: style,
          )
        : null;
    return RenderScrollableCodeBlock(
      key: ValueKey<String>('markdown_code_${partId}_$blockIndex'),
      themeTokens: themeTokens,
      language: language,
      code: code,
      onCopy: () => onCopyCode(code),
      child: useHighlight
          ? HighlightView(
              code,
              language: language,
              theme: highlightTheme!,
              textStyle: style,
            )
          : Text(code, style: style),
    );
  }

  String? _markdownCodeLanguage(md.Element element) {
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'code') continue;
      final className = child.attributes['class']?.trim();
      if (className == null || className.isEmpty) return null;
      for (final token in className.split(RegExp(r'\s+'))) {
        if (token.startsWith('language-')) {
          final language = token.substring('language-'.length).trim();
          if (language.isNotEmpty) return language;
        }
      }
    }
    return null;
  }
}

/// Scrollable code container with copy, keyboard and overflow-gated scrollbar.
class RenderScrollableCodeBlock extends StatefulWidget {
  const RenderScrollableCodeBlock({
    super.key,
    required this.themeTokens,
    required this.language,
    required this.code,
    required this.onCopy,
    required this.child,
  });

  final OpenCodeThemeTokens themeTokens;
  final String? language;
  final String code;
  final VoidCallback onCopy;
  final Widget child;

  @override
  State<RenderScrollableCodeBlock> createState() =>
      _RenderScrollableCodeBlockState();
}

class _RenderScrollableCodeBlockState extends State<RenderScrollableCodeBlock> {
  final _controller = ScrollController();
  final _focusNode = FocusNode(debugLabel: 'V2 code scrolling');
  Timer? _interactionTimer;
  bool _overflow = false;
  bool _hovered = false;
  bool _focused = false;
  bool _interacting = false;
  bool _metricsScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMetrics());
  }

  @override
  void didUpdateWidget(covariant RenderScrollableCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateMetrics());
    }
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final overflow = _controller.position.maxScrollExtent > 0;
      if (overflow != _overflow) setState(() => _overflow = overflow);
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
    if (!node.hasPrimaryFocus ||
        !_overflow ||
        event is KeyUpEvent ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isShiftPressed) {
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
    final l10n = context.v2L10n;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCodeHeader(context, l10n),
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.horizontal) {
                    _updateMetrics();
                  }
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
                        padding: EdgeInsets.fromLTRB(
                          8,
                          8,
                          8,
                          _overflow ? 20 : 8,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: MessageRenderBudget.maxCodeBlockHeight,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            primary: false,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeHeader(BuildContext context, dynamic l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.language ?? 'code',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.content_copy, size: 16),
            tooltip: l10n.commonCopiedToClipboard as String,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              widget.onCopy();
              Clipboard.setData(ClipboardData(text: widget.code));
            },
          ),
        ],
      ),
    );
  }
}
