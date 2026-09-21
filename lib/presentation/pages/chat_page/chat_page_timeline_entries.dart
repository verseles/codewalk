part of '../chat_page.dart';

extension _ChatPageTimelineEntries on _ChatPageState {
  List<_TimelineEntry> _buildMessageTimelineEntries({
    required String? sessionId,
    required List<ChatMessage> messages,
    required int messagesVersion,
    required bool showRetryIndicator,
    required bool isSessionActivelyResponding,
    required bool isCompactingContext,
    required List<ChatPermissionRequest> interactionPermissions,
  }) {
    final settingsProvider = _settingsProvider;
    final showThinkingBubbles = settingsProvider?.showThinkingBubbles ?? true;
    final showToolCallBubbles = settingsProvider?.showToolCallBubbles ?? true;
    final chatRenderMode =
        settingsProvider?.chatRenderMode ?? ChatRenderMode.live;
    final assistantWorkCompactionDecision =
        _resolveAssistantWorkCompactionDecision(
          messages: messages,
          isResponding: isSessionActivelyResponding,
        );
    final permissionPromptSignature = interactionPermissions
        .map((request) => '${request.id}:${request.sessionId}')
        .join('|');
    final cachedEntry = _consumeSessionTimelineEntriesCache(sessionId);
    if (cachedEntry != null &&
        _canReuseSessionTimelineEntriesCache(
          cachedEntry,
          sourceMessages: messages,
          messagesVersion: messagesVersion,
          isCompactingContext: isCompactingContext,
          isSessionActivelyResponding: isSessionActivelyResponding,
          showRetryIndicator: showRetryIndicator,
          permissionPromptSignature: permissionPromptSignature,
          assistantWorkCompactionDecision: assistantWorkCompactionDecision,
          showThinkingBubbles: showThinkingBubbles,
          showToolCallBubbles: showToolCallBubbles,
          chatRenderMode: chatRenderMode,
        )) {
      return cachedEntry.entries;
    }
    final entries = <_TimelineEntry>[];
    final previousWasCompactingContext = _wasCompactingContext;
    var nextFrozenCompactionBoundaryId = _frozenCompactionBoundaryId;

    // Freeze boundary during compaction to prevent premature collapse.
    if (isCompactingContext && !previousWasCompactingContext) {
      // Compaction just started: freeze the current boundary by message ID.
      final currentIdx = _findLatestCompactionBoundaryIndex(
        messages,
        allowInProgressBoundary: true,
      );
      nextFrozenCompactionBoundaryId = currentIdx != null
          ? messages[currentIdx].id
          : null;
    } else if (!isCompactingContext && previousWasCompactingContext) {
      // Compaction finished: unfreeze so the new boundary takes effect.
      nextFrozenCompactionBoundaryId = null;
    }
    _scheduleCompactionStateSync(
      wasCompactingContext: isCompactingContext,
      frozenCompactionBoundaryId: nextFrozenCompactionBoundaryId,
    );

    // Use the latest compaction marker as the visible history boundary.
    int? boundaryIndex;
    if (isCompactingContext && nextFrozenCompactionBoundaryId != null) {
      // During compaction, resolve the frozen boundary by message ID.
      final frozenIdx = messages.indexWhere(
        (m) => m.id == nextFrozenCompactionBoundaryId,
      );
      boundaryIndex = frozenIdx >= 0 ? frozenIdx : null;
    } else {
      boundaryIndex = _findLatestCompactionBoundaryIndex(
        messages,
        allowInProgressBoundary: !isSessionActivelyResponding,
      );
    }
    if (boundaryIndex != null && boundaryIndex > 0) {
      final boundaryMessage = messages[boundaryIndex];
      final boundary = _resolveCompactionBoundary(boundaryMessage);
      if (boundary != null) {
        final group = _CollapsedHistoryGroup(
          startMessageId: messages.first.id,
          endMessageId: messages[boundaryIndex - 1].id,
          messageCount: boundaryIndex,
          createdAt: boundaryMessage.time,
          compactionId: boundary.compactionId,
          compactionLabel: boundary.compactionLabel,
        );
        final expanded = _expandedCollapsedHistoryGroupId == group.id;
        entries.add(
          _TimelineCollapsedHistoryEntry(group: group, expanded: expanded),
        );
        // Build pre-boundary messages only when user expands the group.
        if (expanded) {
          _appendTimelineEntriesForRange(
            entries: entries,
            messages: messages,
            startIndex: 0,
            endExclusive: boundaryIndex,
            assistantWorkCompactionDecision: assistantWorkCompactionDecision,
            isSessionActivelyResponding: isSessionActivelyResponding,
            chatRenderMode: chatRenderMode,
          );
        }
        _appendTimelineEntriesForRange(
          entries: entries,
          messages: messages,
          startIndex: boundaryIndex,
          endExclusive: messages.length,
          assistantWorkCompactionDecision: assistantWorkCompactionDecision,
          isSessionActivelyResponding: isSessionActivelyResponding,
          chatRenderMode: chatRenderMode,
        );
      }
    }

    if (entries.isEmpty) {
      _appendTimelineEntriesForRange(
        entries: entries,
        messages: messages,
        startIndex: 0,
        endExclusive: messages.length,
        assistantWorkCompactionDecision: assistantWorkCompactionDecision,
        isSessionActivelyResponding: isSessionActivelyResponding,
        chatRenderMode: chatRenderMode,
      );
    }

    for (final request in interactionPermissions) {
      entries.add(_TimelinePermissionPromptEntry(request: request));
    }

    if (showRetryIndicator) {
      entries.add(const _TimelineRetryIndicatorEntry());
    }

    _storeSessionTimelineEntriesCache(
      sessionId,
      _SessionTimelineEntriesCacheEntry(
        sourceMessages: List<ChatMessage>.from(messages, growable: false),
        entries: List<_TimelineEntry>.from(entries, growable: false),
        messagesVersion: messagesVersion,
        isCompacting: isCompactingContext,
        isResponding: isSessionActivelyResponding,
        showRetry: showRetryIndicator,
        permissionPromptSignature: permissionPromptSignature,
        assistantWorkCompactionDecision: assistantWorkCompactionDecision,
        expandedHistoryGroupId: _expandedCollapsedHistoryGroupId,
        expandedAssistantWorkGroupId: _expandedAssistantWorkGroupId,
        wasCompactingContext: _wasCompactingContext,
        frozenCompactionBoundaryId: _frozenCompactionBoundaryId,
        showThinkingBubbles: showThinkingBubbles,
        showToolCallBubbles: showToolCallBubbles,
        chatRenderMode: chatRenderMode,
      ),
    );
    return entries;
  }

  bool _canReuseSessionTimelineEntriesCache(
    _SessionTimelineEntriesCacheEntry entry, {
    required List<ChatMessage> sourceMessages,
    required int messagesVersion,
    required bool isCompactingContext,
    required bool isSessionActivelyResponding,
    required bool showRetryIndicator,
    required String permissionPromptSignature,
    required _AssistantWorkCompactionDecision assistantWorkCompactionDecision,
    required bool showThinkingBubbles,
    required bool showToolCallBubbles,
    required ChatRenderMode chatRenderMode,
  }) {
    final versionMatch =
        entry.messagesVersion == messagesVersion ||
        _areTimelineSourceMessagesIdentical(
          entry.sourceMessages,
          sourceMessages,
        );
    final compactingMatch = entry.isCompacting == isCompactingContext;
    final respondingMatch = entry.isResponding == isSessionActivelyResponding;
    final retryMatch = entry.showRetry == showRetryIndicator;
    final permMatch =
        entry.permissionPromptSignature == permissionPromptSignature;
    final compactionMatch =
        entry.assistantWorkCompactionDecision.shouldDeferLatestCollapse ==
            assistantWorkCompactionDecision.shouldDeferLatestCollapse &&
        entry
                .assistantWorkCompactionDecision
                .settledLatestAssistantWorkGroupId ==
            assistantWorkCompactionDecision.settledLatestAssistantWorkGroupId;
    final historyGroupMatch =
        entry.expandedHistoryGroupId == _expandedCollapsedHistoryGroupId;
    final workGroupMatch =
        entry.expandedAssistantWorkGroupId == _expandedAssistantWorkGroupId;
    final wasCompactingMatch =
        entry.wasCompactingContext == _wasCompactingContext;
    final frozenMatch =
        entry.frozenCompactionBoundaryId == _frozenCompactionBoundaryId;
    final thinkingMatch = entry.showThinkingBubbles == showThinkingBubbles;
    final toolMatch = entry.showToolCallBubbles == showToolCallBubbles;
    final renderModeMatch = entry.chatRenderMode == chatRenderMode;

    final canReuse =
        versionMatch &&
        compactingMatch &&
        respondingMatch &&
        retryMatch &&
        permMatch &&
        compactionMatch &&
        historyGroupMatch &&
        workGroupMatch &&
        wasCompactingMatch &&
        frozenMatch &&
        thinkingMatch &&
        toolMatch &&
        renderModeMatch;

    if (!canReuse) {
      final reasons = <String>[];
      if (!versionMatch) reasons.add('version');
      if (!compactingMatch) reasons.add('compacting');
      if (!respondingMatch) reasons.add('responding');
      if (!retryMatch) reasons.add('retry');
      if (!permMatch) reasons.add('permission');
      if (!compactionMatch) reasons.add('compaction');
      if (!historyGroupMatch) reasons.add('historyGroup');
      if (!workGroupMatch) reasons.add('workGroup');
      if (!wasCompactingMatch) reasons.add('wasCompacting');
      if (!frozenMatch) reasons.add('frozen');
      if (!thinkingMatch) reasons.add('thinking');
      if (!toolMatch) reasons.add('tool');
      if (!renderModeMatch) reasons.add('chatRenderMode');
      AppLogger.debug(
        'CW_CACHE timeline cache invalidated: ${reasons.join(", ")}',
      );
    }

    return canReuse;
  }

  bool _areTimelineSourceMessagesIdentical(
    List<ChatMessage> a,
    List<ChatMessage> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (identical(a[index], b[index])) {
        continue;
      }
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  _SessionTimelineEntriesCacheEntry? _consumeSessionTimelineEntriesCache(
    String? sessionId,
  ) {
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final cachedEntry = _sessionTimelineEntriesCache.remove(sessionId);
    if (cachedEntry == null) {
      return null;
    }
    _sessionTimelineEntriesCache[sessionId] = cachedEntry;
    return cachedEntry;
  }

  void _storeSessionTimelineEntriesCache(
    String? sessionId,
    _SessionTimelineEntriesCacheEntry entry,
  ) {
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    _sessionTimelineEntriesCache.remove(sessionId);
    _sessionTimelineEntriesCache[sessionId] = entry;
    while (_sessionTimelineEntriesCache.length >
        _ChatPageState._maxHydratedTimelineCacheEntries) {
      _sessionTimelineEntriesCache.remove(
        _sessionTimelineEntriesCache.keys.first,
      );
    }
  }

  void _appendTimelineEntriesForRange({
    required List<_TimelineEntry> entries,
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
    required _AssistantWorkCompactionDecision assistantWorkCompactionDecision,
    required bool isSessionActivelyResponding,
    required ChatRenderMode chatRenderMode,
  }) {
    if (startIndex >= endExclusive) {
      return;
    }

    final settingsProvider = _settingsProvider;
    final showThinkingBubbles = settingsProvider?.showThinkingBubbles ?? true;
    final showToolCallBubbles = settingsProvider?.showToolCallBubbles ?? true;
    final isActivelyResponding =
        assistantWorkCompactionDecision.shouldDeferLatestCollapse;

    var index = startIndex;
    while (index < endExclusive) {
      final current = messages[index];
      if (current is! UserMessage) {
        var assistantRunEnd = index;
        if (current is AssistantMessage) {
          assistantRunEnd += 1;
          while (assistantRunEnd < endExclusive &&
              messages[assistantRunEnd] is AssistantMessage) {
            assistantRunEnd += 1;
          }
        }
        if (current is AssistantMessage &&
            _shouldBlockAssistantRunForBlockRenderMode(
              messages: messages,
              startIndex: index,
              endExclusive: assistantRunEnd,
              isSessionActivelyResponding: isSessionActivelyResponding,
              chatRenderMode: chatRenderMode,
            )) {
          final publishedUntil = _appendBlockedAssistantRun(
            entries: entries,
            messages: messages,
            startIndex: index,
            endExclusive: assistantRunEnd,
            anchorMessageId: current.id,
            includePlaceholder: assistantRunEnd == messages.length,
            isSessionActivelyResponding: isSessionActivelyResponding,
          );
          _traceFinalUi(
            'timeline-block-render-active-orphan-assistant-run',
            details:
                'anchorMessageId=${current.id} assistantRunStart=$index '
                'publishedUntil=$publishedUntil assistantRunEnd=$assistantRunEnd',
          );
          index = assistantRunEnd;
          continue;
        }
        if (!isActivelyResponding &&
            _isMergeableAssistantToolOnlyMessage(current)) {
          index = _appendMergedAssistantToolOnlyRun(
            entries: entries,
            messages: messages,
            startIndex: index,
            endExclusive: endExclusive,
          );
        } else {
          entries.add(_TimelineMessageEntry(current));
          index += 1;
        }
        continue;
      }

      entries.add(_TimelineMessageEntry(current));

      final assistantRunStart = index + 1;
      var assistantRunEnd = assistantRunStart;
      while (assistantRunEnd < endExclusive &&
          messages[assistantRunEnd] is AssistantMessage) {
        assistantRunEnd += 1;
      }

      if (assistantRunEnd == assistantRunStart) {
        if (_shouldBlockAssistantRunForBlockRenderMode(
          messages: messages,
          startIndex: assistantRunStart,
          endExclusive: assistantRunEnd,
          isSessionActivelyResponding: isSessionActivelyResponding,
          chatRenderMode: chatRenderMode,
        )) {
          entries.add(
            _TimelinePendingAssistantEntry(anchorMessageId: current.id),
          );
          _traceFinalUi(
            'timeline-block-render-awaiting-first-assistant-delta',
            details:
                'userMessageId=${current.id} assistantRunStart=$assistantRunStart',
          );
        }
        index += 1;
        continue;
      }

      final finalAssistant = messages[assistantRunEnd - 1] as AssistantMessage;
      final workMessageCount = assistantRunEnd - assistantRunStart - 1;
      final shouldDeferCurrentRunCollapse =
          assistantRunEnd == endExclusive &&
          assistantWorkCompactionDecision.shouldDeferLatestCollapse;
      final shouldBlockActiveAssistantRun =
          _shouldBlockAssistantRunForBlockRenderMode(
            messages: messages,
            startIndex: assistantRunStart,
            endExclusive: assistantRunEnd,
            isSessionActivelyResponding: isSessionActivelyResponding,
            chatRenderMode: chatRenderMode,
          );
      if (shouldBlockActiveAssistantRun) {
        final publishedUntil = _appendBlockedAssistantRun(
          entries: entries,
          messages: messages,
          startIndex: assistantRunStart,
          endExclusive: assistantRunEnd,
          anchorMessageId: current.id,
          includePlaceholder: assistantRunEnd == messages.length,
          isSessionActivelyResponding: isSessionActivelyResponding,
        );
        _traceFinalUi(
          'timeline-block-render-active-assistant-run',
          details:
              'userMessageId=${current.id} assistantRunStart=$assistantRunStart '
              'publishedUntil=$publishedUntil assistantRunEnd=$assistantRunEnd',
        );
        index = assistantRunEnd;
        continue;
      }
      if (assistantRunEnd == endExclusive) {
        _traceFinalUi(
          'timeline-current-assistant-run',
          details:
              'finalAssistantId=${finalAssistant.id} completed=${finalAssistant.isCompleted} workMessageCount=$workMessageCount shouldDeferCurrentRunCollapse=$shouldDeferCurrentRunCollapse',
        );
      }
      final visibleWorkPreviewMessages = _visibleAssistantWorkPreviewMessages(
        messages: messages,
        startIndex: assistantRunStart,
        endExclusive: assistantRunEnd - 1,
        showThinkingBubbles: showThinkingBubbles,
        showToolCallBubbles: showToolCallBubbles,
      );
      if (workMessageCount > 0 &&
          visibleWorkPreviewMessages.isNotEmpty &&
          !shouldDeferCurrentRunCollapse &&
          _isSuccessfulFinalAssistantMessage(finalAssistant)) {
        _traceFinalUi(
          'timeline-collapse-assistant-work-run',
          details:
              'workMessageCount=$workMessageCount finalAssistantId=${finalAssistant.id} assistantRunStart=$assistantRunStart assistantRunEnd=$assistantRunEnd',
        );
        final workGroup = _CollapsedAssistantWorkGroup(
          startMessageId: messages[assistantRunStart].id,
          endMessageId: messages[assistantRunEnd - 2].id,
          finalMessageId: finalAssistant.id,
          messageCount: workMessageCount,
          createdAt: finalAssistant.time,
        );
        final expanded = _expandedAssistantWorkGroupId == workGroup.id;
        entries.add(
          _TimelineCollapsedAssistantWorkEntry(
            group: workGroup,
            expanded: expanded,
          ),
        );
        if (expanded) {
          _appendRangeWithAssistantToolMerging(
            entries: entries,
            messages: messages,
            startIndex: assistantRunStart,
            endExclusive: assistantRunEnd - 1,
            isActivelyResponding: false,
          );
        }
        entries.add(_TimelineMessageEntry(finalAssistant));
        if (assistantRunEnd == endExclusive) {
          _traceFinalUi(
            'timeline-current-assistant-run-collapsed',
            details:
                'finalAssistantId=${finalAssistant.id} workGroupId=${workGroup.id}',
          );
        }
      } else {
        if (shouldDeferCurrentRunCollapse) {
          _traceFinalUi(
            'timeline-defer-assistant-work-collapse',
            details:
                'workMessageCount=$workMessageCount finalAssistantId=${finalAssistant.id} endExclusive=$endExclusive',
          );
        }
        _appendRangeWithAssistantToolMerging(
          entries: entries,
          messages: messages,
          startIndex: assistantRunStart,
          endExclusive: assistantRunEnd,
          isActivelyResponding:
              shouldDeferCurrentRunCollapse && assistantRunEnd == endExclusive,
        );
        if (assistantRunEnd == endExclusive) {
          _traceFinalUi(
            'timeline-current-assistant-run-not-collapsed',
            details:
                'finalAssistantId=${finalAssistant.id} workMessageCount=$workMessageCount',
          );
        }
      }

      index = assistantRunEnd;
    }
  }

  /// How much of an in-flight assistant run may already be shown in Block mode.
  ///
  /// Block mode exists to avoid streaming half-written blocks, not to withhold
  /// the whole turn (#116). A message is publishable once it has reached a
  /// terminal state of its own: an assistant message that is completed, or one
  /// that errored — the server reports tool parts individually, so a finished
  /// tool does not have to wait for the final text.
  ///
  /// Returns the exclusive end of the publishable prefix, which equals
  /// [startIndex] when nothing may be shown yet.
  int _publishableAssistantPrefixEnd({
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
  }) {
    var end = startIndex;
    while (end < endExclusive) {
      final message = messages[end];
      if (message is! AssistantMessage) {
        break;
      }
      final isTerminal = message.isCompleted || message.error != null;
      if (!isTerminal) {
        break;
      }
      end += 1;
    }
    return end;
  }

  int _appendBlockedAssistantRun({
    required List<_TimelineEntry> entries,
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
    required String anchorMessageId,
    required bool includePlaceholder,
    required bool isSessionActivelyResponding,
  }) {
    final publishableEnd = _publishableAssistantPrefixEnd(
      messages: messages,
      startIndex: startIndex,
      endExclusive: endExclusive,
    );
    if (publishableEnd > startIndex) {
      _appendRangeWithAssistantToolMerging(
        entries: entries,
        messages: messages,
        startIndex: startIndex,
        endExclusive: publishableEnd,
        isActivelyResponding: isSessionActivelyResponding,
      );
    }
    if (publishableEnd < endExclusive) {
      final message = messages[publishableEnd];
      if (message is AssistantMessage) {
        final terminalTools = _terminalToolSnapshot(message);
        if (terminalTools != null) {
          entries.add(_TimelineMessageEntry(terminalTools));
        }
      }
    }
    if (includePlaceholder) {
      entries.add(
        _TimelinePendingAssistantEntry(anchorMessageId: anchorMessageId),
      );
    }
    return publishableEnd;
  }

  AssistantMessage? _terminalToolSnapshot(AssistantMessage message) {
    final terminalParts = message.parts
        .where((part) {
          return part is ToolPart &&
              (part.state.status == ToolStatus.completed ||
                  part.state.status == ToolStatus.error);
        })
        .toList(growable: false);
    if (terminalParts.isEmpty) {
      return null;
    }
    return AssistantMessage(
      id: message.id,
      sessionId: message.sessionId,
      time: message.time,
      parts: terminalParts,
      completedTime: message.completedTime,
      providerId: message.providerId,
      modelId: message.modelId,
      variant: message.variant,
      cost: message.cost,
      tokens: message.tokens,
      error: message.error,
      mode: message.mode,
      summary: message.summary,
    );
  }

  bool _shouldBlockAssistantRunForBlockRenderMode({
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
    required bool isSessionActivelyResponding,
    required ChatRenderMode chatRenderMode,
  }) {
    if (chatRenderMode != ChatRenderMode.block ||
        !isSessionActivelyResponding) {
      return false;
    }
    if (startIndex == endExclusive) {
      return endExclusive == messages.length;
    }
    final finalMessage = messages[endExclusive - 1];
    if (finalMessage is! AssistantMessage) {
      return false;
    }
    if (endExclusive != messages.length) {
      return !finalMessage.isCompleted && finalMessage.error == null;
    }
    return !_isSuccessfulFinalAssistantMessage(finalMessage);
  }

  void _appendRangeWithAssistantToolMerging({
    required List<_TimelineEntry> entries,
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
    required bool isActivelyResponding,
  }) {
    if (startIndex >= endExclusive) {
      return;
    }

    var index = startIndex;
    while (index < endExclusive) {
      final current = messages[index];
      if (isActivelyResponding ||
          !_isMergeableAssistantToolOnlyMessage(current)) {
        if (isActivelyResponding &&
            _isMergeableAssistantToolOnlyMessage(current)) {
          _traceFinalUi(
            'timeline-tool-merge-deferred-active-turn',
            details: 'messageId=${current.id}',
          );
        }
        entries.add(_TimelineMessageEntry(current));
        index += 1;
        continue;
      }

      index = _appendMergedAssistantToolOnlyRun(
        entries: entries,
        messages: messages,
        startIndex: index,
        endExclusive: endExclusive,
      );
    }
  }

  bool _timelineMessageHasVisibleContent(
    ChatMessage message, {
    required bool showThinkingBubbles,
    required bool showToolCallBubbles,
  }) {
    for (final part in message.parts) {
      switch (part.type) {
        case PartType.reasoning:
          final reasoningPart = part as ReasoningPart;
          if (!showThinkingBubbles) {
            continue;
          }
          if (!isReasoningStatusMarker(reasoningPart.text) &&
              reasoningPart.text.trim().isNotEmpty) {
            return true;
          }
          continue;
        case PartType.tool:
          if (!showToolCallBubbles) {
            continue;
          }
          if (part is ToolPart &&
              part.tool.trim().toLowerCase() == 'todowrite') {
            continue;
          }
          return true;
        case PartType.patch:
          if (!showToolCallBubbles) {
            continue;
          }
          return true;
        case PartType.text:
          if ((part as TextPart).text.trim().isNotEmpty) {
            return true;
          }
          continue;
        case PartType.stepStart:
        case PartType.stepFinish:
          continue;
        default:
          return true;
      }
    }
    return false;
  }

  List<ChatMessage> _visibleAssistantWorkPreviewMessages({
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
    required bool showThinkingBubbles,
    required bool showToolCallBubbles,
  }) {
    final previewMessages = _buildAssistantWorkPreviewMessages(
      messages: messages,
      startIndex: startIndex,
      endExclusive: endExclusive,
    );
    return previewMessages
        .where(
          (message) => _timelineMessageHasVisibleContent(
            message,
            showThinkingBubbles: showThinkingBubbles,
            showToolCallBubbles: showToolCallBubbles,
          ),
        )
        .toList(growable: false);
  }

  List<ChatMessage> _buildAssistantWorkPreviewMessages({
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
  }) {
    final previewEntries = <_TimelineEntry>[];
    _appendRangeWithAssistantToolMerging(
      entries: previewEntries,
      messages: messages,
      startIndex: startIndex,
      endExclusive: endExclusive,
      isActivelyResponding: false,
    );
    return previewEntries
        .whereType<_TimelineMessageEntry>()
        .map((entry) => entry.message)
        .toList(growable: false);
  }

  int _appendMergedAssistantToolOnlyRun({
    required List<_TimelineEntry> entries,
    required List<ChatMessage> messages,
    required int startIndex,
    required int endExclusive,
  }) {
    var mergeEnd = startIndex + 1;
    while (mergeEnd < endExclusive &&
        _isMergeableAssistantToolOnlyMessage(messages[mergeEnd])) {
      mergeEnd += 1;
    }

    if (mergeEnd - startIndex == 1) {
      entries.add(_TimelineMessageEntry(messages[startIndex]));
      return mergeEnd;
    }

    final mergedMessage = _mergeAssistantToolOnlyMessages(
      messages
          .sublist(startIndex, mergeEnd)
          .cast<AssistantMessage>()
          .toList(growable: false),
    );
    entries.add(_TimelineMessageEntry(mergedMessage));
    return mergeEnd;
  }

  bool _isMergeableAssistantToolOnlyMessage(ChatMessage message) {
    if (message is! AssistantMessage || message.error != null) {
      return false;
    }

    var hasToolSurfacePart = false;
    for (final part in message.parts) {
      switch (part.type) {
        case PartType.tool:
        case PartType.patch:
          hasToolSurfacePart = true;
          break;
        case PartType.stepStart:
        case PartType.stepFinish:
        case PartType.agent:
        case PartType.snapshot:
        case PartType.subtask:
        case PartType.retry:
        case PartType.reasoning:
          break;
        case PartType.text:
          if ((part as TextPart).text.trim().isNotEmpty) {
            return false;
          }
          break;
        default:
          return false;
      }
    }

    return hasToolSurfacePart;
  }

  AssistantMessage _mergeAssistantToolOnlyMessages(
    List<AssistantMessage> messages,
  ) {
    final first = messages.first;
    final last = messages.last;
    final mergedParts = <MessagePart>[
      for (final message in messages) ...message.parts,
    ];

    final mergedTokens = _sumAssistantTokens(messages);
    final mergedCost = _sumAssistantCost(messages);

    return AssistantMessage(
      id: 'merged_tool_run_${first.id}',
      sessionId: first.sessionId,
      time: first.time,
      parts: mergedParts,
      completedTime: last.completedTime,
      providerId: last.providerId ?? first.providerId,
      modelId: last.modelId ?? first.modelId,
      cost: mergedCost,
      tokens: mergedTokens,
      mode: last.mode ?? first.mode,
      summary: false,
    );
  }

  MessageTokens? _sumAssistantTokens(List<AssistantMessage> messages) {
    var input = 0;
    var output = 0;
    var reasoning = 0;
    var cacheRead = 0;
    var cacheWrite = 0;
    var hasTokens = false;

    for (final message in messages) {
      final tokens = message.tokens;
      if (tokens == null) {
        continue;
      }
      hasTokens = true;
      input += tokens.input;
      output += tokens.output;
      reasoning += tokens.reasoning;
      cacheRead += tokens.cacheRead;
      cacheWrite += tokens.cacheWrite;
    }

    if (!hasTokens) {
      return null;
    }

    return MessageTokens(
      input: input,
      output: output,
      reasoning: reasoning,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
    );
  }

  double? _sumAssistantCost(List<AssistantMessage> messages) {
    var total = 0.0;
    var hasCost = false;
    for (final message in messages) {
      final cost = message.cost;
      if (cost == null) {
        continue;
      }
      total += cost;
      hasCost = true;
    }
    if (!hasCost) {
      return null;
    }
    return total;
  }

  bool _isSuccessfulFinalAssistantMessage(AssistantMessage message) {
    return message.isCompleted &&
        message.error == null &&
        message.summary != true &&
        !_isMergeableAssistantToolOnlyMessage(message);
  }

  String? _resolveLatestRevealableAssistantMessageId(
    List<ChatMessage> messages, {
    bool? showThinkingBubbles,
    bool? showToolCallBubbles,
  }) {
    final effectiveShowThinkingBubbles =
        showThinkingBubbles ?? _settingsProvider?.showThinkingBubbles ?? true;
    final effectiveShowToolCallBubbles =
        showToolCallBubbles ?? _settingsProvider?.showToolCallBubbles ?? true;
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      final message = messages[index];
      if (message is UserMessage) {
        return null;
      }
      if (message is! AssistantMessage) {
        continue;
      }
      if (message.summary == true ||
          _isMergeableAssistantToolOnlyMessage(message) ||
          !_timelineMessageHasVisibleContent(
            message,
            showThinkingBubbles: effectiveShowThinkingBubbles,
            showToolCallBubbles: effectiveShowToolCallBubbles,
          )) {
        continue;
      }
      return message.id;
    }
    return null;
  }

  String? _resolveLatestSettledAssistantWorkGroupId({
    required List<ChatMessage> messages,
    required bool showThinkingBubbles,
    required bool showToolCallBubbles,
  }) {
    if (messages.isEmpty) {
      return null;
    }

    final endExclusive = messages.length;
    var assistantRunStart = endExclusive;
    while (assistantRunStart > 0 &&
        messages[assistantRunStart - 1] is AssistantMessage) {
      assistantRunStart -= 1;
    }

    if (assistantRunStart <= 0 ||
        assistantRunStart >= endExclusive ||
        messages[assistantRunStart - 1] is! UserMessage) {
      return null;
    }

    final finalAssistant = messages[endExclusive - 1];
    if (finalAssistant is! AssistantMessage ||
        !_isSuccessfulFinalAssistantMessage(finalAssistant)) {
      return null;
    }

    final workMessageCount = endExclusive - assistantRunStart - 1;
    if (workMessageCount <= 0) {
      return null;
    }

    final visibleWorkPreviewMessages = _visibleAssistantWorkPreviewMessages(
      messages: messages,
      startIndex: assistantRunStart,
      endExclusive: endExclusive - 1,
      showThinkingBubbles: showThinkingBubbles,
      showToolCallBubbles: showToolCallBubbles,
    );
    if (visibleWorkPreviewMessages.isEmpty) {
      return null;
    }

    return _CollapsedAssistantWorkGroup(
      startMessageId: messages[assistantRunStart].id,
      endMessageId: messages[endExclusive - 2].id,
      finalMessageId: finalAssistant.id,
      messageCount: workMessageCount,
      createdAt: finalAssistant.time,
    ).id;
  }
}
