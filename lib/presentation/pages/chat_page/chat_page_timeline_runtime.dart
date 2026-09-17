part of '../chat_page.dart';

extension _ChatPageTimelineRuntime on _ChatPageState {
  Widget _buildInteractionPrompts(
    ChatProvider chatProvider, {
    bool allowInteraction = true,
  }) {
    if (!allowInteraction) {
      return const SizedBox.shrink();
    }
    final permissionRequests = chatProvider.currentThreadPermissionRequests;
    final questionRequests = chatProvider.currentThreadQuestionRequests;
    if (permissionRequests.isEmpty && questionRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final permissionRequest in permissionRequests)
          PermissionRequestCard(
            key: ValueKey<String>(
              'interaction_permission_request_${permissionRequest.id}',
            ),
            request: permissionRequest,
            busy: chatProvider.isRespondingInteraction,
            originBadgeLabel: _interactionOriginBadgeLabel(
              chatProvider,
              sourceSessionId: permissionRequest.sessionId,
            ),
            onDecide: (reply) {
              unawaited(
                chatProvider.respondPermissionRequest(
                  sessionId: permissionRequest.sessionId,
                  requestId: permissionRequest.id,
                  reply: reply,
                ),
              );
            },
          ),
        for (final questionRequest in questionRequests)
          QuestionRequestCard(
            key: ValueKey<String>(
              'interaction_question_request_${questionRequest.id}',
            ),
            request: questionRequest,
            busy: chatProvider.isRespondingInteraction,
            originBadgeLabel: _interactionOriginBadgeLabel(
              chatProvider,
              sourceSessionId: questionRequest.sessionId,
            ),
            onSubmit: (answers) {
              unawaited(
                chatProvider.submitQuestionAnswers(
                  requestId: questionRequest.id,
                  answers: answers,
                ),
              );
            },
            onReject: () {
              unawaited(
                chatProvider.rejectQuestionRequest(
                  requestId: questionRequest.id,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInlinePermissionPromptEntry(
    _TimelinePermissionPromptEntry entry,
    ChatProvider chatProvider,
  ) {
    return PermissionRequestCard(
      key: ValueKey<String>('timeline_permission_request_${entry.request.id}'),
      request: entry.request,
      busy: chatProvider.isRespondingInteraction,
      originBadgeLabel: _interactionOriginBadgeLabel(
        chatProvider,
        sourceSessionId: entry.request.sessionId,
      ),
      onDecide: (reply) {
        unawaited(
          chatProvider.respondPermissionRequest(
            sessionId: entry.request.sessionId,
            requestId: entry.request.id,
            reply: reply,
          ),
        );
      },
    );
  }

  Widget _buildPendingAssistantEntry(_TimelinePendingAssistantEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;
    return Padding(
      key: ValueKey<String>(entry.key),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: visualTokens.isRefined
                  ? visualTokens.cardSurface
                  : colorScheme.surfaceContainerHigh,
              borderRadius: visualTokens.isRefined
                  ? visualTokens.bubbleRadius.copyWith(
                      bottomLeft: visualTokens.bubbleTightCornerRadius,
                    )
                  : AppShapes.borderLarge.copyWith(
                      bottomLeft: const Radius.circular(6),
                    ),
              border: Border.all(
                color: visualTokens.isRefined
                    ? visualTokens.separator
                    : colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: visualTokens.isRefined
                    ? visualTokens.enabledBorderWidth
                    : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: AppIndeterminateRing(
                    size: 18,
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.chatBlockResponsePendingTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.chatBlockResponsePendingDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _interactionOriginBadgeLabel(
    ChatProvider chatProvider, {
    required String sourceSessionId,
  }) {
    final normalizedSessionId = sourceSessionId.trim();
    final currentSessionId = chatProvider.currentSession?.id.trim();
    if (normalizedSessionId.isEmpty ||
        normalizedSessionId == currentSessionId) {
      return null;
    }

    for (final session in chatProvider.sessions) {
      if (session.id == normalizedSessionId) {
        return _sessionDisplayTitle(session);
      }
    }
    return context.l10n.chatStatusSubsession;
  }

  String _sessionStatusLabel(SessionStatusInfo status) {
    switch (status.type) {
      case SessionStatusType.busy:
        return context.l10n.chatStatusBusy;
      case SessionStatusType.retry:
        final attempt = status.attempt ?? 0;
        return attempt > 0
            ? context.l10n.chatStatusRetryCount(attempt)
            : context.l10n.chatStatusRetry;
      case SessionStatusType.idle:
        return context.l10n.statusOnline;
    }
  }

  String _sessionDisplayTitle(ChatSession session) {
    return SessionTitleFormatter.displayTitle(
      time: session.time,
      title: session.title,
    );
  }

  String _sessionEditingValue(ChatSession session) {
    final raw = session.title?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return SessionTitleFormatter.fallbackTitle(time: session.time);
  }

  int? _findTimelineEntryIndexByKey(Key key, List<_TimelineEntry> entries) {
    if (key is! ValueKey<String>) {
      return null;
    }
    final targetKey = key.value;
    for (var index = 0; index < entries.length; index += 1) {
      if (entries[index].key == targetKey) {
        return index;
      }
    }
    return null;
  }

  void _setCollapsedHistoryGroupExpanded({
    required String groupId,
    required bool expanded,
  }) {
    final nextGroupId = expanded ? groupId : null;
    if (_expandedCollapsedHistoryGroupId == nextGroupId) {
      return;
    }
    _setState(() {
      _expandedCollapsedHistoryGroupId = nextGroupId;
    });
  }

  void _setAssistantWorkGroupExpanded({
    required String groupId,
    required bool expanded,
  }) {
    final nextGroupId = expanded ? groupId : null;
    if (_expandedAssistantWorkGroupId == nextGroupId) {
      return;
    }
    _setState(() {
      _expandedAssistantWorkGroupId = nextGroupId;
    });
  }

  Widget _buildCollapsedHistoryEntry(_TimelineCollapsedHistoryEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;
    final group = entry.group;
    final actionLabel = entry.expanded
        ? context.l10n.chatHistoryHideEarlier
        : context.l10n.chatHistoryShowEarlier;
    final actionIcon = entry.expanded
        ? Symbols.unfold_less_rounded
        : Symbols.unfold_more_rounded;

    return Padding(
      key: ValueKey<String>(entry.key),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            key: const ValueKey<String>('timeline_collapsed_history_header'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: visualTokens.isRefined
                  ? visualTokens.mutedControlSurface
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: visualTokens.isRefined
                  ? visualTokens.cardRadius
                  : BorderRadius.circular(12),
              border: Border.all(
                color: visualTokens.isRefined
                    ? visualTokens.separator
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: visualTokens.isRefined
                    ? visualTokens.enabledBorderWidth
                    : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Symbols.history_toggle_off_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.chatHistoryCollapsed,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const ValueKey<String>(
                        'timeline_collapsed_history_toggle',
                      ),
                      onPressed: () => _setCollapsedHistoryGroupExpanded(
                        groupId: group.id,
                        expanded: !entry.expanded,
                      ),
                      icon: Icon(actionIcon, size: 16),
                      label: Text(actionLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.chatHistoryMessagesHidden(
                    group.messageCount,
                    group.compactionLabel,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedAssistantWorkEntry(
    _TimelineCollapsedAssistantWorkEntry entry, {
    required Widget Function(ChatMessage message) buildPreviewMessage,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visualTokens = theme.visualStyleTokens;
    final group = entry.group;
    final actionLabel = entry.expanded
        ? context.l10n.chatWorkHide
        : (entry.showBoundedPreview
              ? context.l10n.chatWorkExpand
              : context.l10n.chatWorkShow);
    final titleLabel = group.messageCount == 1
        ? context.l10n.chatWorkMessageOne
        : context.l10n.chatWorkMessagesMultiple(group.messageCount);
    final previewMessages = entry.previewMessages;
    final showPreview =
        entry.showBoundedPreview &&
        !entry.expanded &&
        previewMessages.isNotEmpty;
    final maxPreviewHeight = MediaQuery.sizeOf(context).height < 700
        ? 220.0
        : 320.0;
    final allowInteractivePreviewScroll = !_isMobileRuntime;

    return Padding(
      key: ValueKey<String>(entry.key),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            key: const ValueKey<String>(
              'timeline_collapsed_assistant_work_header',
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: visualTokens.isRefined
                  ? visualTokens.mutedControlSurface
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: visualTokens.isRefined
                  ? visualTokens.cardRadius
                  : BorderRadius.circular(12),
              border: Border.all(
                color: visualTokens.isRefined
                    ? visualTokens.separator
                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: visualTokens.isRefined
                    ? visualTokens.enabledBorderWidth
                    : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.account_tree_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        titleLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const ValueKey<String>(
                        'timeline_collapsed_assistant_work_toggle',
                      ),
                      onPressed: () => _setAssistantWorkGroupExpanded(
                        groupId: group.id,
                        expanded: !entry.expanded,
                      ),
                      child: Text(actionLabel),
                    ),
                  ],
                ),
                if (showPreview) ...[
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.chatWorkBoundedPanelExplanation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: visualTokens.isRefined
                        ? visualTokens.controlRadius
                        : BorderRadius.circular(10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.95),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: maxPreviewHeight,
                        ),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(overscroll: false),
                          child: SingleChildScrollView(
                            key: ValueKey<String>(
                              'timeline_assistant_work_preview_${group.id}',
                            ),
                            primary: false,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                            physics: allowInteractivePreviewScroll
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final message in previewMessages)
                                  buildPreviewMessage(message),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _findLatestCompactionBoundaryIndex(
    List<ChatMessage> messages, {
    required bool allowInProgressBoundary,
  }) {
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      if (_isCompactionBoundaryMessage(
        messages[index],
        allowInProgressBoundary: allowInProgressBoundary,
      )) {
        return index;
      }
    }
    return null;
  }

  bool _isCompactionBoundaryMessage(
    ChatMessage message, {
    required bool allowInProgressBoundary,
  }) {
    final isBoundary =
        _findCompactionPart(message) != null ||
        _isCompactionSummaryMessage(message);
    if (!isBoundary) {
      return false;
    }
    if (allowInProgressBoundary) {
      return true;
    }
    if (message is AssistantMessage) {
      return message.isCompleted;
    }
    return true;
  }

  bool _isCompactionSummaryMessage(ChatMessage message) {
    return message is AssistantMessage && message.summary == true;
  }

  CompactionPart? _findCompactionPart(ChatMessage message) {
    for (final part in message.parts) {
      if (part is CompactionPart) {
        return part;
      }
    }
    return null;
  }

  Widget _buildRetryingMessageIndicator() {
    return Container(
      key: const ValueKey<String>('timeline_retry_indicator'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const SizedBox(width: 12),
          const SizedBox(
            width: 16,
            height: 16,
            child: AppIndeterminateRing(size: 16, strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.chatRetryingModelRequest,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveLatestReasoningPartKey(ChatProvider chatProvider) {
    final messages = chatProvider.messages;
    // Cache: skip O(N*M) backward scan when message state hasn't changed.
    if (_cachedReasoningKeyComputed &&
        chatProvider.messagesVersion == _cachedReasoningKeyMessagesVersion) {
      return _cachedReasoningKeyResult;
    }

    String? result;
    scanMessages:
    for (
      var messageIndex = messages.length - 1;
      messageIndex >= 0;
      messageIndex -= 1
    ) {
      final message = messages[messageIndex];
      if (message is! AssistantMessage || message.isCompleted) {
        continue;
      }
      for (
        var partIndex = message.parts.length - 1;
        partIndex >= 0;
        partIndex -= 1
      ) {
        final part = message.parts[partIndex];
        if (part is ToolPart) {
          if (_shouldIgnoreProgressTool(part)) {
            continue;
          }
          break scanMessages;
        }
        if (part is PatchPart) {
          break scanMessages;
        }
        if (part is ReasoningPart) {
          if (part.text.trim().isEmpty) {
            continue;
          }
          result = '${part.messageId}::${part.id}';
          break scanMessages;
        }
      }
    }

    _cachedReasoningKeyMessagesVersion = chatProvider.messagesVersion;
    _cachedReasoningKeyResult = result;
    _cachedReasoningKeyComputed = true;
    return result;
  }

  String? _resolveLatestReasoningStatusLabel(List<ChatMessage> messages) {
    for (
      var messageIndex = messages.length - 1;
      messageIndex >= 0;
      messageIndex -= 1
    ) {
      final message = messages[messageIndex];
      if (message is! AssistantMessage || message.isCompleted) {
        continue;
      }
      for (
        var partIndex = message.parts.length - 1;
        partIndex >= 0;
        partIndex -= 1
      ) {
        final part = message.parts[partIndex];
        if (part is! ReasoningPart) {
          continue;
        }
        final label = parseReasoningStatusLabel(part.text);
        if (label != null) {
          return label;
        }
      }
    }
    return null;
  }

  _AssistantProgressStage? _resolveAssistantProgressStage(
    ChatProvider chatProvider,
  ) {
    final messages = chatProvider.messages;
    final lastId = messages.isNotEmpty ? messages.last.id : null;
    final isResponding = chatProvider.isCurrentSessionActivelyResponding;

    // Cache: skip O(N) scan when messages and responding state haven't changed.
    if (_cachedProgressStageComputed &&
        messages.length == _cachedProgressStageMsgCount &&
        lastId == _cachedProgressStageLastMsgId &&
        isResponding == _cachedProgressStageResponding) {
      return _cachedProgressStageResult;
    }

    final statusType = chatProvider.currentSessionStatus?.type;
    final hasStreamingAssistantParts = messages
        .whereType<AssistantMessage>()
        .any((message) => !message.isCompleted && message.parts.isNotEmpty);

    _AssistantProgressStage? result;
    if (!isResponding) {
      result = null;
    } else if (statusType == SessionStatusType.retry) {
      result = _AssistantProgressStage.retrying;
    } else if (hasStreamingAssistantParts) {
      result = _AssistantProgressStage.receiving;
    } else {
      result = _AssistantProgressStage.thinking;
    }

    _cachedProgressStageMsgCount = messages.length;
    _cachedProgressStageLastMsgId = lastId;
    _cachedProgressStageResponding = isResponding;
    _cachedProgressStageResult = result;
    _cachedProgressStageComputed = true;
    return result;
  }
}
