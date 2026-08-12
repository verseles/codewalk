part of '../chat_message_widget.dart';

/// Part dispatch: routes each [MessagePart] to its specific builder,
/// handles safe rendering, and manages collapsible tool chains.
extension _ChatMessagePartDispatch on _ChatMessageWidgetState {
  Widget _wrapWithPartEntranceIfNeeded({
    required MessagePart part,
    required Widget child,
  }) {
    if (!_shouldAnimatePartArrival(part)) {
      return child;
    }
    return PartEntranceAnimation(
      key: ValueKey<String>(
        'part_entrance_${message.id}_${_partIdentityToken(part)}',
      ),
      child: child,
    );
  }

  Widget _buildAnimatedMessagePartSafely(
    BuildContext context,
    MessagePart part, {
    required String? latestReasoningPartId,
    required String? activeReasoningPartKey,
  }) {
    final built = _buildMessagePartSafely(
      context,
      part,
      latestReasoningPartId: latestReasoningPartId,
      activeReasoningPartKey: activeReasoningPartKey,
    );
    return _wrapWithPartEntranceIfNeeded(part: part, child: built);
  }

  Widget _buildMessagePart(
    BuildContext context,
    MessagePart part, {
    required String? latestReasoningPartId,
    required String? activeReasoningPartKey,
  }) {
    switch (part.type) {
      case PartType.text:
        return _buildTextPart(context, part as TextPart);
      case PartType.file:
        return _buildFilePart(context, part as FilePart);
      case PartType.tool:
        if (!showToolCallBubbles) {
          return const SizedBox.shrink();
        }
        final toolPart = part as ToolPart;
        if (_isTodoToolPart(toolPart)) {
          return const SizedBox.shrink();
        }
        return _buildToolPart(
          context,
          toolPart,
          onNavigateToSubConversation: onTaskToolNavigate == null
              ? null
              : () => onTaskToolNavigate!(toolPart),
          taskChildSummary: taskToolChildSummaryForPart(toolPart.id),
        );
      case PartType.agent:
        return _buildAgentPart(context, part as AgentPart);
      case PartType.reasoning:
        final reasoningPart = part as ReasoningPart;
        if (!showThinkingBubbles ||
            shouldSuppressLiveReasoningPart(reasoningPart)) {
          return const SizedBox.shrink();
        }
        final reasoningPartKey = _reasoningPartKey(
          messageId: reasoningPart.messageId,
          partId: reasoningPart.id,
        );
        return _buildReasoningPart(
          context,
          reasoningPart,
          partKey: reasoningPartKey,
          isLatestReasoningPart: activeReasoningPartKey == null
              ? reasoningPart.id == latestReasoningPartId
              : reasoningPartKey == activeReasoningPartKey,
        );
      case PartType.stepStart:
        return const SizedBox.shrink();
      case PartType.stepFinish:
        return const SizedBox.shrink();
      case PartType.snapshot:
        return _buildSnapshotPart(context, part as SnapshotPart);
      case PartType.patch:
        if (!showToolCallBubbles) {
          return const SizedBox.shrink();
        }
        return _buildPatchPart(context, part as PatchPart);
      case PartType.subtask:
        final subtaskPart = part as SubtaskPart;
        return _buildSubtaskPart(
          context,
          subtaskPart,
          onNavigate: onSubtaskNavigate == null
              ? null
              : () => onSubtaskNavigate!(subtaskPart),
        );
      case PartType.retry:
        return _buildRetryPart(context, part as RetryPart);
      case PartType.compaction:
        return _buildCompactionPart(context, part as CompactionPart);
    }
  }

  Widget _buildMessagePartSafely(
    BuildContext context,
    MessagePart part, {
    required String? latestReasoningPartId,
    required String? activeReasoningPartKey,
  }) {
    try {
      return _buildMessagePart(
        context,
        part,
        latestReasoningPartId: latestReasoningPartId,
        activeReasoningPartKey: activeReasoningPartKey,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to render message part safely',
        error: error,
        stackTrace: stackTrace,
      );
      return _buildInfoContainer(
        context,
        icon: Symbols.warning_amber_rounded,
        title: context.l10n.chatMessageMessagePartUnavailable,
        subtitle: context.l10n.chatLargeContentSkipped,
      );
    }
  }

  List<Widget> _buildMessagePartWidgets(
    BuildContext context, {
    required String? latestReasoningPartId,
    required String? activeReasoningPartKey,
  }) {
    final reorderedParts = _reorderVisibleTaskToolRuns(message.parts);
    final assistantMessage = message is AssistantMessage
        ? message as AssistantMessage
        : null;
    if (assistantMessage == null || !showToolCallBubbles) {
      return reorderedParts
          .map<Widget>(
            (part) => _buildAnimatedMessagePartSafely(
              context,
              part,
              latestReasoningPartId: latestReasoningPartId,
              activeReasoningPartKey: activeReasoningPartKey,
            ),
          )
          .toList(growable: false);
    }

    final allToolSurfaceParts = reorderedParts
        .where(_isToolSurfacePart)
        .toList(growable: false);
    if (allToolSurfaceParts.length < 2) {
      return reorderedParts
          .map<Widget>(
            (part) => _buildAnimatedMessagePartSafely(
              context,
              part,
              latestReasoningPartId: latestReasoningPartId,
              activeReasoningPartKey: activeReasoningPartKey,
            ),
          )
          .toList(growable: false);
    }

    final chainIdentityToken = _partIdentityToken(allToolSurfaceParts.first);
    final chainStartPartId = _toolSurfacePartPublicKey(
      allToolSurfaceParts.first,
    );
    final animateToolChain = allToolSurfaceParts.any(_shouldAnimatePartArrival);
    final rendered = <Widget>[];
    var insertedCollapsedToolChain = false;
    for (final part in reorderedParts) {
      if (_isToolSurfacePart(part)) {
        if (insertedCollapsedToolChain) {
          continue;
        }
        final chainWidget = _CollapsibleToolChain(
          key: ValueKey<String>('tool_chain_${message.id}_$chainIdentityToken'),
          expanded: _resolveToolChainExpanded(
            chainIdentityToken,
            allToolSurfaceParts,
          ),
          messageId: message.id,
          startPartId: chainStartPartId,
          isSessionActivelyResponding: isSessionActivelyResponding,
          onExpandedChanged: (expanded) =>
              _setToolChainExpanded(chainIdentityToken, expanded),
          toolDescriptionLabelBuilder: _resolveToolDescriptionLabel,
          toolTypeLabelBuilder: _resolveToolTypeLabel,
          parts: allToolSurfaceParts,
          partBuilder: (toolPart) => _buildMessagePart(
            context,
            toolPart,
            latestReasoningPartId: latestReasoningPartId,
            activeReasoningPartKey: activeReasoningPartKey,
          ),
        );
        rendered.add(
          animateToolChain
              ? PartEntranceAnimation(
                  key: ValueKey<String>(
                    'tool_chain_entrance_${message.id}_$chainIdentityToken',
                  ),
                  child: chainWidget,
                )
              : chainWidget,
        );
        insertedCollapsedToolChain = true;
        continue;
      }

      rendered.add(
        _buildAnimatedMessagePartSafely(
          context,
          part,
          latestReasoningPartId: latestReasoningPartId,
          activeReasoningPartKey: activeReasoningPartKey,
        ),
      );
    }

    return rendered;
  }

  // Keep unfinished task bubbles grouped at the end of each visible task run
  // without changing the surrounding narrative flow of other message parts.
  List<MessagePart> _reorderVisibleTaskToolRuns(List<MessagePart> parts) {
    final reordered = <MessagePart>[];
    final taskRun = <ToolPart>[];

    void flushTaskRun() {
      if (taskRun.isEmpty) {
        return;
      }
      final settled = <ToolPart>[];
      final active = <ToolPart>[];
      for (final part in taskRun) {
        if (_isActiveTaskToolPart(part)) {
          active.add(part);
        } else {
          settled.add(part);
        }
      }
      reordered.addAll(settled);
      reordered.addAll(active);
      taskRun.clear();
    }

    for (final part in parts) {
      if (part case ToolPart() when _isTaskToolPart(part)) {
        taskRun.add(part);
        continue;
      }
      flushTaskRun();
      reordered.add(part);
    }

    flushTaskRun();
    return reordered;
  }

  bool _isActiveTaskToolPart(ToolPart part) {
    return part.state.status == ToolStatus.pending ||
        part.state.status == ToolStatus.running;
  }

  bool _isToolSurfacePart(MessagePart part) {
    if (part.type == PartType.tool && _isTodoToolPart(part as ToolPart)) {
      return false;
    }
    if (part.type == PartType.tool && _isTaskToolPart(part as ToolPart)) {
      return false;
    }
    return part.type == PartType.tool || part.type == PartType.patch;
  }

  String _toolSurfacePartPublicKey(MessagePart part) {
    if (part case ToolPart(:final callId, :final id)) {
      final normalizedCallId = callId.trim();
      if (normalizedCallId.isNotEmpty) {
        return normalizedCallId;
      }
      return id;
    }
    if (part case PatchPart(:final hash, :final id)) {
      final normalizedHash = hash.trim();
      if (normalizedHash.isNotEmpty) {
        return normalizedHash;
      }
      return id;
    }
    return part.id;
  }

  bool _isTodoToolPart(ToolPart part) {
    final normalized = _normalizeToolName(part.tool);
    return normalized == 'todowrite' || normalized == 'todoread';
  }

  bool _isTaskToolPart(ToolPart part) {
    return _normalizeToolName(part.tool) == 'task';
  }
}

class _CollapsibleToolChain extends StatelessWidget {
  const _CollapsibleToolChain({
    super.key,
    required this.expanded,
    required this.messageId,
    required this.startPartId,
    required this.isSessionActivelyResponding,
    required this.onExpandedChanged,
    required this.toolDescriptionLabelBuilder,
    required this.toolTypeLabelBuilder,
    required this.parts,
    required this.partBuilder,
  });

  final bool expanded;
  final String messageId;
  final String startPartId;
  final bool isSessionActivelyResponding;
  final ValueChanged<bool> onExpandedChanged;
  final String Function(ToolPart part) toolDescriptionLabelBuilder;
  final String Function(ToolPart part) toolTypeLabelBuilder;
  final List<MessagePart> parts;
  final Widget Function(MessagePart part) partBuilder;
  bool _isCompactLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600;
  }

  void _toggleExpanded() {
    onExpandedChanged(!expanded);
  }

  String _buildCollapsedPrimaryLabel(
    BuildContext context, {
    required bool compact,
  }) {
    final toolParts = parts.whereType<ToolPart>().toList(growable: false);
    final patchCount = parts.whereType<PatchPart>().length;

    if (compact) {
      if (toolParts.isEmpty) {
        if (patchCount > 0) {
          return context.l10n.chatMessagePatchCount(patchCount);
        }
        return context.l10n.chatMessageToolRun;
      }

      final callLabel = context.l10n.chatMessageToolChainCallsCompact(
        toolParts.length,
      );
      if (patchCount <= 0) {
        return callLabel;
      }
      final patchLabel = context.l10n.chatMessagePatchCount(patchCount);
      return '$callLabel • $patchLabel';
    }

    final toolDescriptions = toolParts
        .map(toolDescriptionLabelBuilder)
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (toolDescriptions.isEmpty) {
      if (patchCount > 0) {
        return context.l10n.chatMessagePatchCount(patchCount);
      }
      return context.l10n.chatMessageToolExecution;
    }

    if (toolDescriptions.length == 1) {
      final primary = toolDescriptions.first;
      if (patchCount <= 0) {
        return primary;
      }
      final patchLabel = context.l10n.chatMessagePatchCount(patchCount);
      return '$primary • $patchLabel';
    }

    const maxVisible = 2;
    final visible = toolDescriptions.take(maxVisible).join(' • ');
    final remaining = toolDescriptions.length - maxVisible;
    final extraLabel = remaining > 0
        ? ' • ${context.l10n.chatMessageToolChainMore(remaining)}'
        : '';
    final patchLabel = patchCount > 0
        ? ' • ${context.l10n.chatMessagePatchCount(patchCount)}'
        : '';
    return '$visible$extraLabel$patchLabel';
  }

  String? _buildCollapsedSecondaryLabel(BuildContext context) {
    final toolTypes = parts
        .whereType<ToolPart>()
        .map(toolTypeLabelBuilder)
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (toolTypes.isEmpty) {
      return null;
    }

    final unique = LinkedHashSet<String>.from(
      toolTypes,
    ).toList(growable: false);

    if (unique.length == 1) {
      return unique.first;
    }

    if (unique.length <= 3) {
      return unique.join(' • ');
    }

    return '${unique.take(2).join(' • ')} • ${context.l10n.chatMessageToolChainExtraTypes(unique.length - 2)}';
  }

  String? _buildCollapsedProgressLabel(BuildContext context) {
    final toolParts = parts.whereType<ToolPart>().toList(growable: false);
    if (toolParts.isEmpty) {
      return null;
    }

    final pending = toolParts
        .where((part) => part.state.status == ToolStatus.pending)
        .length;
    final running = toolParts
        .where((part) => part.state.status == ToolStatus.running)
        .length;
    final failed = toolParts
        .where((part) => part.state.status == ToolStatus.error)
        .length;

    if (pending == 0 && running == 0 && failed == 0) {
      return null;
    }

    final summaryParts = <String>[
      if (running > 0) context.l10n.chatMessageToolRunningCount(running),
      if (pending > 0) context.l10n.chatMessageToolQueuedCount(pending),
      if (failed > 0) context.l10n.chatMessageToolAttentionCount(failed),
    ];
    return summaryParts.join(' • ');
  }

  String _buildExpandedSummaryLabel(BuildContext context) {
    final toolParts = parts.whereType<ToolPart>().toList(growable: false);
    final patchCount = parts.whereType<PatchPart>().length;
    if (toolParts.isEmpty) {
      return context.l10n.chatMessagePatchCount(patchCount);
    }

    final pending = toolParts
        .where((part) => part.state.status == ToolStatus.pending)
        .length;
    final running = toolParts
        .where((part) => part.state.status == ToolStatus.running)
        .length;
    final completed = toolParts
        .where((part) => part.state.status == ToolStatus.completed)
        .length;
    final failed = toolParts
        .where((part) => part.state.status == ToolStatus.error)
        .length;

    final summaryParts = <String>[
      context.l10n.chatMessageToolChainCallsCompact(toolParts.length),
      if (completed > 0) context.l10n.chatMessageToolDoneCount(completed),
      if (running > 0) context.l10n.chatMessageToolRunningCount(running),
      if (pending > 0) context.l10n.chatMessageToolQueuedCount(pending),
      if (failed > 0) context.l10n.chatMessageToolAttentionCount(failed),
      if (patchCount > 0) context.l10n.chatMessagePatchCount(patchCount),
    ];
    return summaryParts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final _expanded = expanded;
    final colorScheme = Theme.of(context).colorScheme;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final compactLayout = _isCompactLayout(context);
    final collapsedPrimaryLabel = _buildCollapsedPrimaryLabel(
      context,
      compact: compactLayout,
    );
    final collapsedProgressLabel = _buildCollapsedProgressLabel(context);
    final collapsedSecondaryLabelRaw = _buildCollapsedSecondaryLabel(context);
    final collapsedSecondaryLabel =
        collapsedSecondaryLabelRaw != null &&
            collapsedSecondaryLabelRaw.trim().toLowerCase() !=
                collapsedPrimaryLabel.trim().toLowerCase()
        ? collapsedSecondaryLabelRaw
        : null;

    final expandedChild = !_expanded
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...parts.map<Widget>(partBuilder),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey<String>(
                      'tool_chain_bottom_toggle_${messageId}_$startPartId',
                    ),
                    onPressed: _toggleExpanded,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                    ),
                    icon: Icon(
                      Symbols.unfold_less_rounded,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      context.l10n.chatMessageHide,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          );
    final body = disableAnimations || isSessionActivelyResponding
        ? expandedChild
        : AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expandedChild,
          );

    return Container(
      key: ValueKey<String>('tool_chain_container_${messageId}_$startPartId'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: AppShapes.borderSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.account_tree, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expanded
                          ? context.l10n.chatMessageToolCallsTitle
                          : collapsedPrimaryLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_expanded ||
                        (collapsedProgressLabel != null &&
                            collapsedProgressLabel.isNotEmpty) ||
                        (!compactLayout &&
                            collapsedSecondaryLabel != null &&
                            collapsedSecondaryLabel.isNotEmpty)) ...[
                      const SizedBox(height: 2),
                      Text(
                        _expanded
                            ? _buildExpandedSummaryLabel(context)
                            : collapsedProgressLabel ??
                                  collapsedSecondaryLabel!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                key: ValueKey<String>(
                  'tool_chain_toggle_${messageId}_$startPartId',
                ),
                onPressed: _toggleExpanded,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                ),
                child: Text(
                  _expanded
                      ? context.l10n.chatMessageHide
                      : (compactLayout
                            ? context.l10n.chatMessageShow
                            : context.l10n.chatMessageDetails),
                ),
              ),
            ],
          ),
          body,
        ],
      ),
    );
  }
}
