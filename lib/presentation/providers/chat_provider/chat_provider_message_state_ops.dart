part of '../chat_provider.dart';

extension _ChatProviderMessageStateOps on ChatProvider {
  int _messageLocalDeltaVersion(String messageId) {
    return _messageLocalDeltaVersionById[messageId] ?? 0;
  }

  void _markLocalMessageDeltaAdvanced(String messageId) {
    final normalizedMessageId = messageId.trim();
    if (normalizedMessageId.isEmpty) {
      return;
    }
    _messageLocalDeltaVersionById[normalizedMessageId] =
        (_messageLocalDeltaVersionById[normalizedMessageId] ?? 0) + 1;
    while (_messageLocalDeltaVersionById.length >
        ChatProvider._maxMessageLocalDeltaVersions) {
      _messageLocalDeltaVersionById.remove(
        _messageLocalDeltaVersionById.keys.first,
      );
    }
  }

  String? _deltaDedupeFieldKey(MessagePart part) {
    if (part is TextPart || part is ReasoningPart) {
      return '${part.messageId}::${part.id}';
    }
    return null;
  }

  bool _shouldMarkNextDeltaDedupe({
    required MessagePart existingPart,
    required MessagePart incomingPart,
    required String delta,
  }) {
    if (delta.isEmpty) {
      return false;
    }
    if (existingPart is TextPart && incomingPart is TextPart) {
      return incomingPart.text.length > existingPart.text.length &&
          incomingPart.text.startsWith(existingPart.text);
    }
    if (existingPart is ReasoningPart && incomingPart is ReasoningPart) {
      return incomingPart.text.length > existingPart.text.length &&
          incomingPart.text.startsWith(existingPart.text);
    }
    return false;
  }

  String _appendNonOverlappingDelta(String existing, String delta) {
    if (existing.isEmpty || delta.isEmpty) {
      return '$existing$delta';
    }
    final maxOverlap = math.min(math.min(existing.length, delta.length), 4096);
    for (var overlap = maxOverlap; overlap > 0; overlap -= 1) {
      if (existing.endsWith(delta.substring(0, overlap))) {
        return existing + delta.substring(overlap);
      }
    }
    return existing + delta;
  }

  void _rememberNextDeltaDedupeField(String key) {
    if (_dedupeNextDeltaFieldKeys.length >= 256) {
      _dedupeNextDeltaFieldKeys.remove(_dedupeNextDeltaFieldKeys.first);
    }
    _dedupeNextDeltaFieldKeys.add(key);
  }

  String _removedMessageKey(String sessionId, String messageId) {
    return '${sessionId.trim()}::${messageId.trim()}';
  }

  String _removedPartKey(String sessionId, String messageId, String partId) {
    return '${sessionId.trim()}::${messageId.trim()}::${partId.trim()}';
  }

  void _rememberRecentRemoval({
    required String key,
    required Queue<String> queue,
    required Set<String> set,
  }) {
    if (key.trim().isEmpty || !set.add(key)) {
      return;
    }
    queue.addLast(key);
    while (queue.length > ChatProvider._maxRecentRemovalKeys) {
      set.remove(queue.removeFirst());
    }
  }

  void _rememberRemovedMessage(String sessionId, String messageId) {
    if (sessionId.trim().isEmpty || messageId.trim().isEmpty) {
      return;
    }
    final key = _removedMessageKey(sessionId, messageId);
    _rememberRecentRemoval(
      key: key,
      queue: _recentRemovedMessageKeys,
      set: _recentRemovedMessageKeySet,
    );
    _messageFallbackDebounceById.remove(messageId)?.cancel();
  }

  void _rememberRemovedPart(String sessionId, String messageId, String partId) {
    if (sessionId.trim().isEmpty ||
        messageId.trim().isEmpty ||
        partId.trim().isEmpty) {
      return;
    }
    _rememberRecentRemoval(
      key: _removedPartKey(sessionId, messageId, partId),
      queue: _recentRemovedPartKeys,
      set: _recentRemovedPartKeySet,
    );
  }

  bool _isRecentlyRemovedMessage(String sessionId, String messageId) {
    return _recentRemovedMessageKeySet.contains(
      _removedMessageKey(sessionId, messageId),
    );
  }

  bool _isRecentlyRemovedPart(
    String sessionId,
    String messageId,
    String partId,
  ) {
    return _recentRemovedPartKeySet.contains(
      _removedPartKey(sessionId, messageId, partId),
    );
  }

  ChatMessage _withoutRecentlyRemovedParts(ChatMessage message) {
    final nextParts = message.parts
        .where(
          (part) =>
              !_isRecentlyRemovedPart(message.sessionId, message.id, part.id),
        )
        .toList(growable: false);
    if (nextParts.length == message.parts.length) {
      return message;
    }
    return _copyMessageWithParts(message, nextParts);
  }

  ChatMessage _copyMessageWithParts(
    ChatMessage message,
    List<MessagePart> parts,
  ) {
    if (message is AssistantMessage) {
      return AssistantMessage(
        id: message.id,
        sessionId: message.sessionId,
        time: message.time,
        parts: parts,
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
    return UserMessage(
      id: message.id,
      sessionId: message.sessionId,
      time: message.time,
      parts: parts,
    );
  }

  bool _isTerminalToolState(ToolState state) {
    return state.status == ToolStatus.completed ||
        state.status == ToolStatus.error;
  }

  MessagePart _preserveNonRegressivePartUpdate({
    required MessagePart existingPart,
    required MessagePart incomingPart,
  }) {
    if (existingPart.id != incomingPart.id ||
        existingPart.type != incomingPart.type) {
      return incomingPart;
    }
    if (existingPart is TextPart && incomingPart is TextPart) {
      if (existingPart.text == incomingPart.text) {
        return existingPart;
      }
      if (incomingPart.text.isEmpty ||
          existingPart.text.startsWith(incomingPart.text)) {
        return existingPart;
      }
      return incomingPart;
    }
    if (existingPart is ReasoningPart && incomingPart is ReasoningPart) {
      if (existingPart.text == incomingPart.text) {
        return existingPart;
      }
      if (incomingPart.text.isEmpty ||
          existingPart.text.startsWith(incomingPart.text)) {
        return existingPart;
      }
      return incomingPart;
    }
    if (existingPart is ToolPart &&
        incomingPart is ToolPart &&
        _isTerminalToolState(existingPart.state) &&
        !_isTerminalToolState(incomingPart.state)) {
      return existingPart;
    }
    return incomingPart;
  }

  bool _isSamePartSlot(MessagePart existingPart, MessagePart incomingPart) {
    if (existingPart.id == incomingPart.id) {
      return true;
    }
    if (existingPart is TextPart && incomingPart is TextPart) {
      return true;
    }
    if (existingPart is ReasoningPart && incomingPart is ReasoningPart) {
      return true;
    }
    if (existingPart is ToolPart && incomingPart is ToolPart) {
      return existingPart.callId.isNotEmpty &&
          existingPart.callId == incomingPart.callId;
    }
    return false;
  }

  MessagePart _preserveNonRegressiveSlotUpdate({
    required MessagePart existingPart,
    required MessagePart incomingPart,
  }) {
    if (existingPart.id == incomingPart.id) {
      return _preserveNonRegressivePartUpdate(
        existingPart: existingPart,
        incomingPart: incomingPart,
      );
    }
    if (existingPart is TextPart && incomingPart is TextPart) {
      if (incomingPart.text.isEmpty ||
          existingPart.text.startsWith(incomingPart.text)) {
        return TextPart(
          id: incomingPart.id,
          messageId: incomingPart.messageId,
          sessionId: incomingPart.sessionId,
          text: existingPart.text,
          time: incomingPart.time,
        );
      }
      return incomingPart;
    }
    if (existingPart is ReasoningPart && incomingPart is ReasoningPart) {
      if (incomingPart.text.isEmpty ||
          existingPart.text.startsWith(incomingPart.text)) {
        return ReasoningPart(
          id: incomingPart.id,
          messageId: incomingPart.messageId,
          sessionId: incomingPart.sessionId,
          text: existingPart.text,
          time: incomingPart.time,
        );
      }
      return incomingPart;
    }
    if (existingPart is ToolPart &&
        incomingPart is ToolPart &&
        _isTerminalToolState(existingPart.state) &&
        !_isTerminalToolState(incomingPart.state)) {
      return existingPart;
    }
    return incomingPart;
  }

  bool _partContentAlreadyRepresented(
    MessagePart existingPart,
    List<MessagePart> mergedParts,
  ) {
    if (existingPart is TextPart && existingPart.text.length >= 8) {
      return mergedParts.whereType<TextPart>().any(
        (part) => part.text.contains(existingPart.text),
      );
    }
    if (existingPart is ReasoningPart && existingPart.text.length >= 8) {
      return mergedParts.whereType<ReasoningPart>().any(
        (part) => part.text.contains(existingPart.text),
      );
    }
    return false;
  }

  AssistantMessage? _mergeAssistantCompletionMetadataOnly({
    required AssistantMessage existing,
    required AssistantMessage incoming,
  }) {
    if (!incoming.isCompleted) {
      return null;
    }
    final merged = AssistantMessage(
      id: existing.id,
      sessionId: existing.sessionId,
      time: existing.time,
      parts: existing.parts,
      completedTime:
          incoming.completedTime ?? existing.completedTime ?? DateTime.now(),
      providerId: incoming.providerId ?? existing.providerId,
      modelId: incoming.modelId ?? existing.modelId,
      variant: incoming.variant ?? existing.variant,
      cost: incoming.cost ?? existing.cost,
      tokens: incoming.tokens ?? existing.tokens,
      error: incoming.error ?? existing.error,
      mode: incoming.mode ?? existing.mode,
      summary: incoming.summary ?? existing.summary,
    );
    if (merged == existing) {
      return null;
    }
    return merged;
  }

  AssistantMessage _mergeCompletedAssistantUpdate(
    AssistantMessage existing,
    AssistantMessage incoming,
  ) {
    final unmatchedExistingById = <String, MessagePart>{
      for (final part in existing.parts) part.id: part,
    };
    final mergedParts = <MessagePart>[];
    for (var index = 0; index < incoming.parts.length; index += 1) {
      final incomingPart = incoming.parts[index];
      final existingPart = unmatchedExistingById.remove(incomingPart.id);
      if (existingPart != null) {
        mergedParts.add(
          _preserveNonRegressivePartUpdate(
            existingPart: existingPart,
            incomingPart: incomingPart,
          ),
        );
        continue;
      }

      final existingSlotPart = index < existing.parts.length
          ? existing.parts[index]
          : null;
      if (existingSlotPart != null &&
          unmatchedExistingById.containsKey(existingSlotPart.id) &&
          _isSamePartSlot(existingSlotPart, incomingPart)) {
        unmatchedExistingById.remove(existingSlotPart.id);
        mergedParts.add(
          _preserveNonRegressiveSlotUpdate(
            existingPart: existingSlotPart,
            incomingPart: incomingPart,
          ),
        );
        continue;
      }

      mergedParts.add(incomingPart);
    }
    for (final existingPart in existing.parts) {
      if (unmatchedExistingById.containsKey(existingPart.id)) {
        if (_partContentAlreadyRepresented(existingPart, mergedParts)) {
          continue;
        }
        mergedParts.add(existingPart);
      }
    }
    return _copyMessageWithParts(incoming, mergedParts) as AssistantMessage;
  }

  AssistantMessage _mergeAssistantMessageUpdate(
    AssistantMessage existing,
    AssistantMessage incoming,
  ) {
    if (existing.isCompleted && !incoming.isCompleted) {
      return existing;
    }

    final incomingPartIds = incoming.parts.map((part) => part.id).toSet();
    final incomingDropsVisiblePart = existing.parts.any(
      (part) => !incomingPartIds.contains(part.id),
    );
    final localDeltaVersion = _messageLocalDeltaVersion(existing.id);
    final shouldMergeNonRegressively =
        existing.isCompleted ||
        incoming.isCompleted ||
        localDeltaVersion > 0 ||
        incoming.parts.length < existing.parts.length ||
        incomingDropsVisiblePart;

    if (!shouldMergeNonRegressively) {
      return incoming;
    }
    return _mergeCompletedAssistantUpdate(existing, incoming);
  }

  bool _mergeCompletionStatusOnly(ChatMessage incoming, int existingIndex) {
    final existing = _messages[existingIndex];
    if (existing is! AssistantMessage || incoming is! AssistantMessage) {
      return false;
    }
    final merged = _mergeAssistantCompletionMetadataOnly(
      existing: existing,
      incoming: incoming,
    );
    if (merged == null) {
      return false;
    }
    _messages[existingIndex] = merged;
    _messagesVersion++;
    _notifyListeners(reason: 'message-fallback-completion-only');
    _persistOptimisticReconciliation(incoming.sessionId);
    return true;
  }

  bool _hasSameOrderedParts(ChatMessage a, ChatMessage b) {
    if (a.parts.length != b.parts.length) {
      return false;
    }
    for (var index = 0; index < a.parts.length; index += 1) {
      final left = a.parts[index];
      final right = b.parts[index];
      if (left.id != right.id || left != right) {
        return false;
      }
    }
    return true;
  }

  void _persistOptimisticReconciliation(String sessionId) {
    _cacheSessionMessages(sessionId, _messages);
    unawaited(_persistSessionMessagesSnapshotBestEffort(sessionId, _messages));
    unawaited(_persistLastSessionSnapshotBestEffort());
  }

  MessagePart? _mergeIncrementalPartUpdate({
    required MessagePart existingPart,
    required MessagePart incomingPart,
    required String delta,
    bool preferOverlapDedupe = false,
  }) {
    if (delta.isEmpty) {
      return incomingPart;
    }

    if (existingPart is TextPart && incomingPart is TextPart) {
      final mergedText = incomingPart.text.startsWith(existingPart.text)
          ? incomingPart.text
          : preferOverlapDedupe
          ? _appendNonOverlappingDelta(existingPart.text, delta)
          : '${existingPart.text}$delta';
      return TextPart(
        id: incomingPart.id,
        messageId: incomingPart.messageId,
        sessionId: incomingPart.sessionId,
        text: mergedText,
        time: incomingPart.time,
      );
    }

    if (existingPart is ReasoningPart && incomingPart is ReasoningPart) {
      final mergedText = incomingPart.text.startsWith(existingPart.text)
          ? incomingPart.text
          : preferOverlapDedupe
          ? _appendNonOverlappingDelta(existingPart.text, delta)
          : '${existingPart.text}$delta';
      return ReasoningPart(
        id: incomingPart.id,
        messageId: incomingPart.messageId,
        sessionId: incomingPart.sessionId,
        text: mergedText,
        time: incomingPart.time,
      );
    }

    return null;
  }

  MessagePart? _mergeFieldDeltaPart({
    required MessagePart existingPart,
    required String field,
    required String delta,
    bool preferOverlapDedupe = false,
  }) {
    if (delta.isEmpty) {
      return existingPart;
    }
    if (field != 'text') {
      return null;
    }
    if (existingPart is TextPart) {
      final mergedText = preferOverlapDedupe
          ? _appendNonOverlappingDelta(existingPart.text, delta)
          : '${existingPart.text}$delta';
      return TextPart(
        id: existingPart.id,
        messageId: existingPart.messageId,
        sessionId: existingPart.sessionId,
        text: mergedText,
        time: existingPart.time,
      );
    }
    if (existingPart is ReasoningPart) {
      final mergedText = preferOverlapDedupe
          ? _appendNonOverlappingDelta(existingPart.text, delta)
          : '${existingPart.text}$delta';
      return ReasoningPart(
        id: existingPart.id,
        messageId: existingPart.messageId,
        sessionId: existingPart.sessionId,
        text: mergedText,
        time: existingPart.time,
      );
    }
    return null;
  }

  String _extractAutoTitleText(ChatMessage message) {
    if (message is AssistantMessage && message.summary == true) {
      return '';
    }
    final text = message.parts
        .whereType<TextPart>()
        .map((part) => part.text.trim())
        .where((part) => part.isNotEmpty)
        .join('\n')
        .trim();
    return text;
  }

  int _resolveAutoTitleMaxWords() {
    final platform = defaultTargetPlatform;
    final isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (!isMobile && _isForegroundActive) {
      return 6;
    }
    return 4;
  }

  void _scheduleAutoTitleRefresh(String sessionId) {
    if (titleGenerator == null || sessionId.isEmpty) {
      return;
    }
    final session = _sessionById(sessionId);
    final parentId = session?.parentId?.trim();
    if (parentId != null && parentId.isNotEmpty) {
      return;
    }
    if (_autoTitleConsolidatedSessionIds.contains(sessionId)) {
      return;
    }
    if (_autoTitleInFlightSessionIds.contains(sessionId)) {
      _autoTitleQueuedSessionIds.add(sessionId);
      return;
    }
    unawaited(_processAutoTitleQueue(sessionId));
  }

  String _generateSessionTitle(DateTime time) {
    return SessionTitleFormatter.fallbackTitle(time: time);
  }

  void _markIncompleteAssistantMessagesAsCompleted({String? sessionId}) {
    final now = DateTime.now();
    var changed = false;
    _messages = _messages
        .map((message) {
          if (message is! AssistantMessage || message.isCompleted) {
            return message;
          }
          if (sessionId != null && message.sessionId != sessionId) {
            return message;
          }
          changed = true;
          return AssistantMessage(
            id: message.id,
            sessionId: message.sessionId,
            time: message.time,
            parts: message.parts,
            completedTime: now,
            providerId: message.providerId,
            modelId: message.modelId,
            cost: message.cost,
            tokens: message.tokens,
            error: message.error,
            mode: message.mode,
            summary: message.summary,
          );
        })
        .toList(growable: true);
    if (!changed) {
      return;
    }
    _messagesVersion++;
    // Notify only. Final message reveal/collapse sequencing is coordinated
    // by the chat viewport lifecycle on the page side.
    _notifyListeners();
  }

  void _prunePendingLocalUserMessageIdsToVisibleUsers() {
    if (_pendingLocalUserMessageIds.isEmpty) {
      return;
    }
    final visibleUserIds = _messages
        .whereType<UserMessage>()
        .map((message) => message.id)
        .toSet();
    _pendingLocalUserMessageIds.removeWhere(
      (id) => !visibleUserIds.contains(id),
    );
  }

  UserMessage _buildLocalUserMessage({
    required String localMessageId,
    required String sessionId,
    required DateTime time,
    required String text,
    required List<FileInputPart> attachments,
    required bool shellMode,
  }) {
    final userParts = <MessagePart>[];
    if (text.isNotEmpty) {
      userParts.add(
        TextPart(
          id: '${localMessageId}_text',
          messageId: localMessageId,
          sessionId: sessionId,
          text: shellMode ? '!$text' : text,
          time: time,
        ),
      );
    }
    for (var index = 0; index < attachments.length; index += 1) {
      final attachment = attachments[index];
      userParts.add(
        FilePart(
          id: '${localMessageId}_file_$index',
          messageId: localMessageId,
          sessionId: sessionId,
          url: attachment.url,
          mime: attachment.mime,
          filename: attachment.filename,
        ),
      );
    }
    return UserMessage(
      id: localMessageId,
      sessionId: sessionId,
      time: time,
      parts: userParts,
    );
  }

  String _appendLocalUserMessage({
    required String sessionId,
    required String text,
    required List<FileInputPart> attachments,
    required bool shellMode,
  }) {
    final localMessageId = _nextLocalUserMessageId();
    _messages.add(
      _buildLocalUserMessage(
        localMessageId: localMessageId,
        sessionId: sessionId,
        time: DateTime.now(),
        text: text,
        attachments: attachments,
        shellMode: shellMode,
      ),
    );
    _messagesVersion++;
    _pendingLocalUserMessageIds.add(localMessageId);
    return localMessageId;
  }

  void _updateOrAddMessage(ChatMessage message) {
    final currentSessionId = _currentSession?.id;
    if (currentSessionId == null || message.sessionId != currentSessionId) {
      AppLogger.debug(
        'Ignoring off-session message update session=${message.sessionId} current=${currentSessionId ?? "-"}',
      );
      _scheduleAutoTitleRefresh(message.sessionId);
      return;
    }

    var optimisticEchoRemoved = false;
    if (message is UserMessage) {
      final pendingLocalIndex = _findPendingLocalUserMessageIndex(message);
      if (pendingLocalIndex != -1) {
        final previousId = _messages[pendingLocalIndex].id;
        final existingIncomingIndex = _messages.indexWhere(
          (item) => item.id == message.id,
        );
        if (existingIncomingIndex != -1 &&
            existingIncomingIndex != pendingLocalIndex) {
          _setPendingReplacementBranchRootMessage(
            sessionId: message.sessionId,
            messageId: message.id,
          );
          _pendingLocalUserMessageIds.remove(previousId);
          _messages[existingIncomingIndex] = message;
          _messages.removeAt(pendingLocalIndex);
          _messagesVersion++;
          _notifyListeners();
          _persistOptimisticReconciliation(message.sessionId);
          _attemptPendingRemoteSelectionSync(reason: 'message-user-deduped');
          _scheduleAutoTitleRefresh(message.sessionId);
          _scheduleScrollToBottom(reason: 'message-state-user-deduped');
          return;
        }
        _setPendingReplacementBranchRootMessage(
          sessionId: message.sessionId,
          messageId: message.id,
        );
        _pendingLocalUserMessageIds.remove(previousId);
        _messages[pendingLocalIndex] = message;
        _messagesVersion++;
        _notifyListeners();
        _persistOptimisticReconciliation(message.sessionId);
        _attemptPendingRemoteSelectionSync(reason: 'message-user-replaced');
        _scheduleAutoTitleRefresh(message.sessionId);
        _scheduleScrollToBottom(reason: 'message-state-user-replaced');
        return;
      }
      optimisticEchoRemoved = _removeDuplicateOptimisticLocalUserEcho(message);
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      // Monotonic completion guard (ADR-023): once an AssistantMessage has
      // been marked completed (by session.idle →
      // _markIncompleteAssistantMessagesAsCompleted, or by authoritative
      // message.updated with time.completed), never allow a late incomplete
      // event from the draining send stream or a stale fallback fetch to
      // regress it. The guard lifts when the incoming message is also
      // completed — allowing server-authoritative completedTime to replace
      // the locally-synthesized one.
      final existing = _messages[index];
      if (existing is AssistantMessage &&
          existing.isCompleted &&
          message is AssistantMessage &&
          !message.isCompleted) {
        AppLogger.debug(
          'Skipping incomplete overwrite of completed assistant message: '
          '${message.id} (existing completedTime=${existing.completedTime})',
        );
        return;
      }
      // Update existing message without allowing completed snapshots or terminal
      // tool states to lose content already visible to the user.
      final replacement =
          existing is AssistantMessage && message is AssistantMessage
          ? _mergeAssistantMessageUpdate(existing, message)
          : message;
      if (replacement == existing &&
          _hasSameOrderedParts(existing, replacement)) {
        AppLogger.debug('Skipped unchanged message update: ${message.id}');
        return;
      }
      _messages[index] = replacement;
      _messagesVersion++;
      if (message is UserMessage) {
        _pendingLocalUserMessageIds.remove(message.id);
      }
      AppLogger.debug(
        'Updated message: ${message.id}, parts=${message.parts.length}',
      );
    } else {
      // Add new message
      _messages.add(message);
      _messagesVersion++;
      AppLogger.debug('Added new message: ${message.id}, role=${message.role}');
    }

    // Check if there is an unfinished assistant message
    if (message is AssistantMessage) {
      _adoptSelectionFromAssistantMessage(message, reason: 'assistant-message');
      AppLogger.debug(
        'Assistant message status: ${message.isCompleted ? "completed" : "in_progress"}',
      );
      final hasActiveStream =
          _messageSubscription != null &&
          _activeMessageStreamSessionId == message.sessionId;
      final sessionStatus = _sessionStatusById[message.sessionId]?.type;
      final hasBusyStatus =
          sessionStatus == SessionStatusType.busy ||
          sessionStatus == SessionStatusType.retry;
      if (message.isCompleted &&
          _state == ChatState.sending &&
          _currentSession?.id == message.sessionId &&
          !hasActiveStream &&
          !hasBusyStatus) {
        AppLogger.debug(
          'Message completed and stream idle, setting state loaded',
        );
        _clearActiveSendDraft();
        _setState(ChatState.loaded);
      }
    }

    _notifyListeners();
    if (optimisticEchoRemoved) {
      _persistOptimisticReconciliation(message.sessionId);
    }
    _attemptPendingRemoteSelectionSync(reason: 'message-update');
    _scheduleAutoTitleRefresh(message.sessionId);

    // Trigger auto-scroll only while the current session is actively
    // responding, or when a user message is added/replaced.
    if (message is UserMessage ||
        (_currentSession?.id == message.sessionId &&
            isSessionActivelyResponding(message.sessionId) &&
            _shouldSchedulePassiveAutoScrollForSession(
              message.sessionId,
              latestMessage: message,
            ))) {
      _scheduleScrollToBottom(reason: 'message-state-message-update');
    }
  }

  void _adoptSelectionFromAssistantMessage(
    AssistantMessage message, {
    required String reason,
  }) {
    if (_isSelectionNeutralAssistantMessage(message)) {
      return;
    }

    var changed = false;

    final providerId = message.providerId?.trim();
    final modelId = message.modelId?.trim();
    if (providerId != null &&
        providerId.isNotEmpty &&
        modelId != null &&
        modelId.isNotEmpty) {
      final provider = _providers.where((p) => p.id == providerId).firstOrNull;
      if (provider != null && _isUserSelectableModelId(provider, modelId)) {
        final messageVariant = message.variant?.trim();

        // Update provider/model first so stored variant resolution
        // uses the new selection, not the old one.
        if (_selectedProviderId != providerId || _selectedModelId != modelId) {
          _selectedProviderId = providerId;
          _selectedModelId = modelId;
          _selectedVariantId =
              (messageVariant != null && messageVariant.isNotEmpty)
              ? messageVariant
              : _resolveStoredVariantForSelection();
          _lastSyncedRemoteVariantKey = null;
          changed = true;
        }
        _lastSyncedRemoteModelKey = _modelKey(providerId, modelId);

        // If provider and model are already correct but the message declares
        // a different variant, adopt it.
        if (!changed &&
            messageVariant != null &&
            messageVariant.isNotEmpty &&
            _selectedVariantId != messageVariant) {
          _selectedVariantId = messageVariant;
          _lastSyncedRemoteVariantKey = null;
          changed = true;
        }
      }
    }

    final mode = message.mode?.trim();
    if (mode != null && mode.isNotEmpty && mode.toLowerCase() != 'shell') {
      final resolved = _resolvePreferredAgentName(_agents, mode);
      if (resolved != null) {
        _lastSyncedRemoteAgentName = resolved;
        if (_selectedAgentName != resolved) {
          _selectedAgentName = resolved;
          _lastSyncedRemoteVariantKey = null;
          changed = true;
        }
      }
    }

    if (!changed) {
      return;
    }

    AppLogger.info(
      'Adopted assistant selection reason=$reason agent=${_selectedAgentName ?? "-"} provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"}',
    );
    _storeCurrentSessionSelectionOverride();
    unawaited(_persistSelection(syncRemote: false));
  }

  bool _isSelectionNeutralAssistantMessage(AssistantMessage message) {
    if (message.summary == true) {
      return true;
    }
    for (final part in message.parts) {
      if (part is CompactionPart) {
        return true;
      }
    }
    return false;
  }

  String _normalizedUserMessageSignature(UserMessage message) {
    final textSignature = _normalizedUserTextSignature(message);
    final fileSignature = _normalizedUserFileSignature(message);
    if (fileSignature.isEmpty) {
      return textSignature;
    }
    if (textSignature.isEmpty) {
      return fileSignature;
    }
    return '$textSignature\n$fileSignature'.trim();
  }

  String _normalizedUserTextSignature(UserMessage message) {
    return message.parts
        .whereType<TextPart>()
        .map((part) {
          final text = part.text.trim();
          // Strip leading '!' shell-mode prefix for signature comparison so
          // that local '!cmd' matches server-echoed 'cmd'.
          return text.startsWith('!') ? text.substring(1).trim() : text;
        })
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  String _normalizedUserFileSignature(UserMessage message) {
    final fileSignatures =
        message.parts
            .whereType<FilePart>()
            .map(_normalizedFilePartSignature)
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
          ..sort();
    if (fileSignatures.isNotEmpty) {
      return fileSignatures.join('\n');
    }
    return _normalizedUserFileMimeSignature(message);
  }

  String _normalizedUserFileMimeSignature(UserMessage message) {
    final mimeSignatures =
        message.parts
            .whereType<FilePart>()
            .map((part) => part.mime.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
          ..sort();
    return mimeSignatures.join('\n');
  }

  String _normalizedFilePartSignature(FilePart part) {
    final mime = part.mime.trim().toLowerCase();
    final sourcePath = (part.fileSource?.path ?? part.symbolSource?.path ?? '')
        .trim();
    final normalizedSourcePath = sourcePath.toLowerCase();
    final normalizedFilename = (part.filename ?? '').trim().toLowerCase();
    final normalizedUrlHint = _normalizedFileUrlHint(part.url);
    final reference = normalizedSourcePath.isNotEmpty
        ? normalizedSourcePath
        : normalizedFilename.isNotEmpty
        ? normalizedFilename
        : normalizedUrlHint;
    if (mime.isEmpty && reference.isEmpty) {
      return '';
    }
    return '$mime|$reference';
  }

  String _normalizedFileUrlHint(String url) {
    final normalized = url.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.startsWith('data:')) {
      final delimiter = normalized.indexOf(';');
      final commaDelimiter = normalized.indexOf(',');
      final endIndex = switch ((delimiter, commaDelimiter)) {
        (>= 0, >= 0) => delimiter < commaDelimiter ? delimiter : commaDelimiter,
        (>= 0, _) => delimiter,
        (_, >= 0) => commaDelimiter,
        _ => normalized.length,
      };
      return normalized.substring(0, endIndex);
    }

    final parsed = Uri.tryParse(normalized);
    if (parsed == null) {
      return normalized;
    }
    if (parsed.pathSegments.isNotEmpty) {
      final basename = parsed.pathSegments.last.trim();
      if (basename.isNotEmpty) {
        return basename;
      }
    }
    final withoutQuery = parsed.replace(query: '', fragment: '').toString();
    return withoutQuery.trim();
  }

  bool _isLikelyPendingLocalUserMatch({
    required UserMessage pending,
    required UserMessage incoming,
  }) {
    final pendingText = _normalizedUserTextSignature(pending);
    final incomingText = _normalizedUserTextSignature(incoming);
    if (pendingText != incomingText) {
      return false;
    }

    final pendingFileCount = pending.parts.whereType<FilePart>().length;
    final incomingFileCount = incoming.parts.whereType<FilePart>().length;
    if (pendingFileCount == 0 || incomingFileCount == 0) {
      return false;
    }
    if (pendingFileCount != incomingFileCount) {
      return false;
    }

    return _normalizedUserFileMimeSignature(pending) ==
        _normalizedUserFileMimeSignature(incoming);
  }

  int _findPendingLocalUserMessageIndex(UserMessage incoming) {
    for (var index = 0; index < _messages.length; index += 1) {
      final current = _messages[index];
      if (current is! UserMessage) {
        continue;
      }
      if (!_pendingLocalUserMessageIds.contains(current.id)) {
        continue;
      }
      if (current.sessionId != incoming.sessionId) {
        continue;
      }
      if (current.id == incoming.id) {
        return index;
      }
    }

    final incomingSignature = _normalizedUserMessageSignature(incoming);
    if (incomingSignature.isEmpty) {
      // Server echoed with empty parts — fall back to time-proximity-only
      // match when there is exactly one pending local user message for the
      // same session (avoids ambiguity with multiple pending messages).
      return _findSolePendingLocalUserByTimeProximity(incoming);
    }

    var earliestExactSignatureMatchIndex = -1;
    var bestLikelyMatchIndex = -1;
    Duration? bestLikelyMatchDelta;
    for (var index = 0; index < _messages.length; index += 1) {
      final current = _messages[index];
      if (current is! UserMessage) {
        continue;
      }
      if (!_pendingLocalUserMessageIds.contains(current.id)) {
        continue;
      }
      if (current.sessionId != incoming.sessionId) {
        continue;
      }
      final currentSignature = _normalizedUserMessageSignature(current);
      final delta = incoming.time.difference(current.time).abs();
      if (delta > const Duration(minutes: 5)) {
        continue;
      }
      if (currentSignature == incomingSignature) {
        earliestExactSignatureMatchIndex = index;
        continue;
      }
      if (!_isLikelyPendingLocalUserMatch(
        pending: current,
        incoming: incoming,
      )) {
        continue;
      }
      if (bestLikelyMatchDelta == null || delta < bestLikelyMatchDelta) {
        bestLikelyMatchDelta = delta;
        bestLikelyMatchIndex = index;
      }
    }
    if (earliestExactSignatureMatchIndex != -1) {
      return earliestExactSignatureMatchIndex;
    }
    return bestLikelyMatchIndex;
  }

  bool _removeDuplicateOptimisticLocalUserEcho(UserMessage incoming) {
    if (_isOptimisticLocalUserMessageId(incoming.id)) {
      return false;
    }
    final incomingSignature = _normalizedUserMessageSignature(incoming);
    if (incomingSignature.isEmpty) {
      return false;
    }

    var bestIndex = -1;
    Duration? bestDelta;
    for (var index = 0; index < _messages.length; index += 1) {
      final current = _messages[index];
      if (current is! UserMessage) {
        continue;
      }
      if (!_isOptimisticLocalUserMessageId(current.id)) {
        continue;
      }
      if (current.sessionId != incoming.sessionId) {
        continue;
      }
      if (_normalizedUserMessageSignature(current) != incomingSignature) {
        continue;
      }
      final delta = incoming.time.difference(current.time).abs();
      if (delta > const Duration(minutes: 10)) {
        continue;
      }
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        bestIndex = index;
      }
    }

    if (bestIndex == -1) {
      return false;
    }
    // Realtime fallback can sometimes deliver the canonical server user after
    // the pending-local set has already been drained by another merge path.
    // Remove only the nearest exact local_user_* echo so repeated intentional
    // prompts remain distinct.
    final removedId = _messages[bestIndex].id;
    _messages.removeAt(bestIndex);
    _pendingLocalUserMessageIds.remove(removedId);
    return true;
  }

  /// Matches a server [UserMessage] (with empty content signature) to a pending
  /// local user message using only time proximity and session ID. Only returns
  /// a match when exactly one pending candidate exists for the session to avoid
  /// ambiguous replacements.
  int _findSolePendingLocalUserByTimeProximity(UserMessage incoming) {
    var candidateIndex = -1;
    for (var index = 0; index < _messages.length; index += 1) {
      final current = _messages[index];
      if (current is! UserMessage) continue;
      if (!_pendingLocalUserMessageIds.contains(current.id)) continue;
      if (current.sessionId != incoming.sessionId) continue;
      final delta = incoming.time.difference(current.time).abs();
      if (delta > const Duration(minutes: 5)) continue;
      if (candidateIndex != -1) {
        // Multiple candidates — ambiguous, don't guess.
        return -1;
      }
      candidateIndex = index;
    }
    return candidateIndex;
  }

  void _handleFailure(Failure failure) {
    AppLogger.warn(
      'Chat failure handled type=${failure.runtimeType} message=${failure.message}',
    );
    switch (failure) {
      case NetworkFailure _:
        _setError(
          L10nBridge.current?.chatProviderErrorNetwork ??
              'Network connection failed. Please check network settings',
        );
      case ServerFailure _:
        _setError(
          L10nBridge.current?.chatProviderErrorServer ??
              'Server error. Please try again later',
        );
      case NotFoundFailure _:
        _setError(
          L10nBridge.current?.chatProviderErrorNotFound ??
              'Resource not found',
        );
      case ValidationFailure _:
        _setError(
          L10nBridge.current?.chatProviderErrorInvalidInput ??
              'Invalid input parameters',
        );
      default:
        _setError(
          L10nBridge.current?.chatProviderErrorUnknown ??
              'Unknown error. Please try again later',
        );
    }
  }

  void _handleSendFailure(Failure failure, {required String sessionId}) {
    if (_currentSession?.id != sessionId) {
      _handleFailure(failure);
      return;
    }
    final statusCode = switch (failure) {
      ServerFailure(code: final code) => code,
      NetworkFailure(code: final code) => code,
      _ => null,
    };
    if (statusCode == 409) {
      _preserveBusyStatusOnNextStreamDoneSessionId = sessionId;
      _sessionStatusById[sessionId] = SessionStatusInfo(
        type: SessionStatusType.busy,
        message: failure.message,
      );
      _clearSessionAttentionForSession(sessionId);
      _errorMessage = null;
      _enqueueUiNotice(
        type: ChatUiNoticeType.serverError,
        message: failure.message,
      );
      _setState(ChatState.loaded);
      return;
    }
    // V2: 503 Service Unavailable — server starting up, retryable
    if (statusCode == 503) {
      _sessionStatusById[sessionId] = SessionStatusInfo(
        type: SessionStatusType.retry,
        message: failure.message,
      );
      _clearSessionAttentionForSession(sessionId);
      _errorMessage = null;
      _enqueueUiNotice(
        type: ChatUiNoticeType.serverError,
        message: failure.message,
      );
      _setState(ChatState.loaded);
      return;
    }
    _presentServerErrorForCurrentSession(
      sessionId: sessionId,
      rawMessage: failure.message,
      statusCode: statusCode,
    );
  }

  ChatSession? _sessionById(String sessionId) {
    return _sessions.where((session) => session.id == sessionId).firstOrNull;
  }

  void _applySessionLocally(ChatSession session) {
    _upsertSession(session);
    if (_currentSession?.id == session.id) {
      _currentSession = session;
      _dismissNotificationsForSession(session.id);
    }
  }
}
