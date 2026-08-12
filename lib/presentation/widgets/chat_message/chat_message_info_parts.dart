part of '../chat_message_widget.dart';

/// Info-style part builders: reasoning, agent, snapshot, patch, subtask,
/// retry, and compaction.
extension _ChatMessageInfoPartsBuilder on _ChatMessageWidgetState {
  Widget _buildReasoningPart(
    BuildContext context,
    ReasoningPart part, {
    required String partKey,
    required bool isLatestReasoningPart,
  }) {
    final compactLayout = MediaQuery.sizeOf(context).width < 600;
    if (shouldSuppressLiveReasoningPart(part)) {
      return const SizedBox.shrink();
    }
    if (isReasoningStatusMarker(part.text)) {
      return const SizedBox.shrink();
    }

    // Don't display if reasoning text is empty or only whitespace
    if (part.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visualTokens.isRefined
            ? visualTokens.selectedSurface
            : colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: visualTokens.isRefined ? visualTokens.enabledBorderWidth : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.psychology, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                compactLayout
                    ? context.l10n.chatMessageThinking
                    : context.l10n.chatMessageThinkingProcess,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSearchHighlightedText(
                context,
                part.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ) ??
              _CollapsibleReasoningContent(
                partKey: partKey,
                text: part.text,
                collapsedMaxLines:
                    _ChatMessageWidgetState._collapsedReasoningMaxLines,
                expandedMaxLines:
                    _ChatMessageWidgetState._expandedReasoningMaxLines,
                isLatestReasoningPart: isLatestReasoningPart,
                textStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
        ],
      ),
    );
  }

  Widget _buildAgentPart(BuildContext context, AgentPart part) {
    return _buildInfoContainer(
      context,
      icon: Symbols.support_agent,
      title: context.l10n.msgInfoAgent,
      subtitle: part.name,
    );
  }

  Widget _buildSnapshotPart(BuildContext context, SnapshotPart part) {
    return _buildInfoContainer(
      context,
      icon: Symbols.camera_alt,
      title: context.l10n.msgInfoSnapshot,
      subtitle: part.snapshot,
    );
  }

  Widget _buildPatchPart(BuildContext context, PatchPart part) {
    final files = part.files.take(4).join(', ');
    final suffix = part.files.length > 4
        ? ' (${context.l10n.chatMessageToolChainMore(part.files.length - 4)})'
        : '';
    return _buildInfoContainer(
      context,
      icon: Symbols.compare_arrows,
      title: context.l10n.msgInfoPatch,
      subtitle: files.isEmpty ? part.hash : '$files$suffix',
    );
  }

  Widget _buildSubtaskPart(
    BuildContext context,
    SubtaskPart part, {
    VoidCallback? onNavigate,
  }) {
    final model = part.model == null
        ? ''
        : ' • ${part.model!.providerId}/${part.model!.modelId}';
    if (onNavigate == null) {
      return _buildInfoContainer(
        context,
        icon: Symbols.task,
        title: context.l10n.msgInfoSubtaskPartAgent(part.agent),
        subtitle: context.l10n.msgInfoPartDescriptionModel(
          part.description,
          model,
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: visualTokens.isRefined
            ? visualTokens.mutedControlSurface
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.task, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.msgInfoSubtaskPartAgent(part.agent),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.msgInfoPartDescriptionModel(
                    part.description,
                    model,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: ValueKey<String>('subtask_open_session_${part.id}'),
            onPressed: onNavigate,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            ),
            child: Text(context.l10n.msgInfoView),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryPart(BuildContext context, RetryPart part) {
    return _buildInfoContainer(
      context,
      icon: Symbols.refresh,
      title: context.l10n.msgInfoRetry + ' #${part.attempt}',
      subtitle: part.error.message,
    );
  }

  Widget _buildCompactionPart(BuildContext context, CompactionPart part) {
    return _buildInfoContainer(
      context,
      icon: Symbols.compress,
      title: context.l10n.msgInfoCompaction,
      subtitle: part.auto
          ? context.l10n.compactionAutomatic
          : context.l10n.compactionManual,
    );
  }

  String _reasoningPartKey({
    required String messageId,
    required String partId,
  }) {
    return '$messageId::$partId';
  }
}

class _CollapsibleReasoningContent extends StatefulWidget {
  const _CollapsibleReasoningContent({
    required this.partKey,
    required this.text,
    required this.collapsedMaxLines,
    required this.expandedMaxLines,
    required this.isLatestReasoningPart,
    this.textStyle,
  });

  final String partKey;
  final String text;
  final int collapsedMaxLines;
  final int expandedMaxLines;
  final bool isLatestReasoningPart;
  final TextStyle? textStyle;

  @override
  State<_CollapsibleReasoningContent> createState() =>
      _CollapsibleReasoningContentState();
}

class _CollapsibleReasoningContentState
    extends State<_CollapsibleReasoningContent> {
  late bool _expanded;
  late final ScrollController _scrollController;
  late bool _canExpandSticky;

  bool _computeCanExpand(String text) {
    if (text.trim().isEmpty) {
      return false;
    }
    final lineCount = '\n'.allMatches(text).length + 1;
    return lineCount > widget.collapsedMaxLines || text.length > 160;
  }

  bool get _canExpand {
    if (widget.text.trim().isEmpty) {
      return false;
    }
    return _canExpandSticky || _computeCanExpand(widget.text);
  }

  @override
  void initState() {
    super.initState();
    _expanded = false;
    _scrollController = ScrollController();
    _canExpandSticky = _computeCanExpand(widget.text);
    _scheduleLatestReasoningAutoScroll(forceJump: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CollapsibleReasoningContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLatestReasoningPart && !widget.isLatestReasoningPart) {
      if (_expanded) {
        setState(() {
          _expanded = false;
        });
      }
      return;
    }

    if (!_canExpandSticky && _computeCanExpand(widget.text)) {
      _canExpandSticky = true;
    }

    if (oldWidget.text != widget.text ||
        oldWidget.isLatestReasoningPart != widget.isLatestReasoningPart) {
      _scheduleLatestReasoningAutoScroll(forceJump: false);
    }
  }

  double _resolveViewportHeight(BuildContext context) {
    final fallbackStyle = Theme.of(context).textTheme.bodyMedium;
    final resolvedStyle = widget.textStyle ?? fallbackStyle;
    final fontSize = resolvedStyle?.fontSize ?? 14;
    final lineHeightFactor = resolvedStyle?.height ?? 1.4;
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeight = textScaler.scale(fontSize) * lineHeightFactor;
    final lineTarget = _expanded
        ? widget.expandedMaxLines
        : widget.collapsedMaxLines;
    return math.max(1, lineTarget) * lineHeight;
  }

  void _scheduleLatestReasoningAutoScroll({required bool forceJump}) {
    if (!widget.isLatestReasoningPart) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) {
        return;
      }
      final currentOffset = _scrollController.position.pixels;
      if ((maxScrollExtent - currentOffset).abs() < 1.0) {
        return;
      }
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (forceJump || disableAnimations) {
        _scrollController.jumpTo(maxScrollExtent);
        return;
      }
      unawaited(
        _scrollController
            .animateTo(
              maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            )
            .catchError((_) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final compactLayout = MediaQuery.sizeOf(context).width < 600;
    final textWidget = Text(
      widget.text,
      key: ValueKey<String>('thinking_content_text_${widget.partKey}'),
      style: widget.textStyle,
    );
    if (!_canExpand) {
      return textWidget;
    }

    final scrollView = SingleChildScrollView(
      key: ValueKey<String>('thinking_content_scroll_${widget.partKey}'),
      controller: _scrollController,
      primary: false,
      child: textWidget,
    );

    final scrollableContent = _expanded
        ? Scrollbar(
            key: ValueKey<String>(
              'thinking_content_scrollbar_${widget.partKey}',
            ),
            controller: _scrollController,
            thumbVisibility: true,
            child: scrollView,
          )
        : scrollView;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          key: ValueKey<String>('thinking_content_viewport_${widget.partKey}'),
          constraints: BoxConstraints(
            maxHeight: _resolveViewportHeight(context),
          ),
          child: scrollableContent,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: ValueKey<String>('thinking_content_toggle_${widget.partKey}'),
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
              _scheduleLatestReasoningAutoScroll(forceJump: true);
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            child: Text(
              _expanded
                  ? (compactLayout
                        ? context.l10n.chatMessageShowLessCompact
                        : context.l10n.chatMessageShowLess)
                  : (compactLayout
                        ? context.l10n.chatMessageShowMoreCompact
                        : context.l10n.chatMessageShowMore),
            ),
          ),
        ),
      ],
    );
  }
}
