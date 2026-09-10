part of '../chat_provider.dart';

extension _ChatProviderMessageMergeOps on ChatProvider {
  bool _areMessageListsSemanticallyEqual(
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

  void _scheduleDebouncedMessageFallback(
    String sessionId,
    String messageId, {
    bool applyToCurrentSession = true,
    Duration delay = const Duration(milliseconds: 120),
    int? expectedLocalDeltaVersion,
  }) {
    _messageFallbackDebounceById.remove(messageId)?.cancel();
    final scheduledLocalDeltaVersion =
        expectedLocalDeltaVersion ?? _messageLocalDeltaVersion(messageId);
    _messageFallbackDebounceById[messageId] = Timer(delay, () {
      _messageFallbackDebounceById.remove(messageId);
      unawaited(
        _fetchMessageFallback(
          sessionId,
          messageId,
          applyToCurrentSession: applyToCurrentSession,
          expectedLocalDeltaVersion: scheduledLocalDeltaVersion,
        ),
      );
    });
  }

  Future<void> _fetchMessageFallback(
    String sessionId,
    String messageId, {
    bool applyToCurrentSession = true,
    int? expectedLocalDeltaVersion,
  }) async {
    _messageFallbackDebounceById.remove(messageId)?.cancel();
    final scheduledLocalDeltaVersion =
        expectedLocalDeltaVersion ?? _messageLocalDeltaVersion(messageId);
    _traceFinal(
      'fetch-message-fallback-start',
      sessionId: sessionId,
      details:
          'messageId=$messageId applyToCurrentSession=$applyToCurrentSession',
    );
    final result = await getChatMessage(
      GetChatMessageParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
        messageId: messageId,
        directory: projectProvider.currentDirectory,
      ),
    );
    result.fold(
      (failure) {
        AppLogger.warn(
          'Message fallback fetch failed for $messageId: ${failure.toString()}',
        );
        _traceFinal(
          'fetch-message-fallback-failure',
          sessionId: sessionId,
          details: 'messageId=$messageId failure=${failure.runtimeType}',
        );
      },
      (message) {
        if (_isRecentlyRemovedMessage(sessionId, message.id)) {
          _traceFinal(
            'fetch-message-fallback-skipped-removed-message',
            sessionId: sessionId,
            details: 'messageId=${message.id}',
          );
          return;
        }
        final resolvedMessage = _withoutRecentlyRemovedParts(message);
        final isAssistant = resolvedMessage is AssistantMessage;
        final isCompleted = isAssistant
            ? (resolvedMessage as AssistantMessage).isCompleted
            : false;
        _traceFinal(
          'fetch-message-fallback-success',
          sessionId: sessionId,
          details:
              'messageId=${resolvedMessage.id} role=${resolvedMessage.role.name} assistantCompleted=$isCompleted applyToCurrentSession=$applyToCurrentSession',
        );
        if (applyToCurrentSession && _currentSession?.id == sessionId) {
          final existingIndex = _messages.indexWhere(
            (item) => item.id == resolvedMessage.id,
          );
          final currentLocalDeltaVersion = _messageLocalDeltaVersion(
            resolvedMessage.id,
          );
          if (existingIndex != -1 &&
              currentLocalDeltaVersion > scheduledLocalDeltaVersion) {
            final completionMerged = _mergeCompletionStatusOnly(
              resolvedMessage,
              existingIndex,
            );
            _traceFinal(
              completionMerged
                  ? 'fetch-message-fallback-merged-completion-only'
                  : 'fetch-message-fallback-skipped-stale-content',
              sessionId: sessionId,
              details:
                  'messageId=${resolvedMessage.id} scheduledVersion=$scheduledLocalDeltaVersion currentVersion=$currentLocalDeltaVersion',
            );
            return;
          }
          _updateOrAddMessage(resolvedMessage);
          _traceFinal(
            'fetch-message-fallback-applied-current',
            sessionId: sessionId,
            details: 'messageId=${resolvedMessage.id}',
          );
        } else {
          final cached =
              _cachedSessionMessages(sessionId) ?? const <ChatMessage>[];
          final next = List<ChatMessage>.from(cached);
          final existingIndex = next.indexWhere(
            (item) => item.id == resolvedMessage.id,
          );
          final currentLocalDeltaVersion = _messageLocalDeltaVersion(
            resolvedMessage.id,
          );
          if (existingIndex != -1 &&
              currentLocalDeltaVersion > scheduledLocalDeltaVersion) {
            final existing = next[existingIndex];
            if (existing is AssistantMessage &&
                resolvedMessage is AssistantMessage) {
              final merged = _mergeAssistantCompletionMetadataOnly(
                existing: existing,
                incoming: resolvedMessage,
              );
              if (merged != null) {
                next[existingIndex] = merged;
                _cacheSessionMessages(sessionId, next);
                unawaited(
                  _persistSessionMessagesSnapshotBestEffort(sessionId, next),
                );
                _traceFinal(
                  'fetch-message-fallback-merged-cache-completion-only',
                  sessionId: sessionId,
                  details:
                      'messageId=${resolvedMessage.id} scheduledVersion=$scheduledLocalDeltaVersion currentVersion=$currentLocalDeltaVersion',
                );
                return;
              }
            }
            _traceFinal(
              'fetch-message-fallback-skipped-stale-cache-content',
              sessionId: sessionId,
              details:
                  'messageId=${resolvedMessage.id} scheduledVersion=$scheduledLocalDeltaVersion currentVersion=$currentLocalDeltaVersion',
            );
            return;
          }
          if (existingIndex == -1) {
            next.add(resolvedMessage);
          } else {
            final existing = next[existingIndex];
            next[existingIndex] =
                existing is AssistantMessage &&
                    resolvedMessage is AssistantMessage
                ? _mergeAssistantMessageUpdate(existing, resolvedMessage)
                : resolvedMessage;
          }
          next.sort((a, b) => a.time.compareTo(b.time));
          _cacheSessionMessages(sessionId, next);
          unawaited(_persistSessionMessagesSnapshotBestEffort(sessionId, next));
          _traceFinal(
            'fetch-message-fallback-applied-cache',
            sessionId: sessionId,
            details:
                'messageId=${resolvedMessage.id} cachedCount=${next.length}',
          );
        }
      },
    );
  }

  // Determines whether a locally-appended optimistic user bubble should be
  // suppressed because the server has already echoed it in the merged message list.
  //
  // INVARIANT — the prefix check on line below is load-bearing (see ADR-023 Pitfall P-001):
  // Only messages with the `local_user_*` prefix are candidates for echo suppression.
  // If the optimistic ID ever uses a server-format prefix (e.g. `msg_*`), this guard
  // returns `false` immediately, the bubble is treated as a confirmed server message,
  // and subsequent SSE reconciliation silently discards assistant responses. The prefix
  // must always match what `_nextLocalUserMessageId()` produces. (Regression: b0660a2)
  bool _shouldSkipLocalUserAppendAsDuplicateEcho({
    required UserMessage localMessage,
    required List<ChatMessage> mergedMessages,
  }) {
    if (!_isOptimisticLocalUserMessageId(localMessage.id)) {
      return false;
    }
    final localSignature = _normalizedUserMessageSignature(localMessage);
    if (localSignature.isNotEmpty) {
      for (final serverMessage in mergedMessages) {
        if (serverMessage is! UserMessage) {
          continue;
        }
        final serverSignature = _normalizedUserMessageSignature(serverMessage);
        if (serverSignature.isNotEmpty && serverSignature == localSignature) {
          // Exact content echoes can arrive after long model turns or under
          // mobile/server clock skew. Keep this broader than the fuzzy-prefix
          // fallback below, but still bounded so intentional repeated prompts do
          // not reconcile against very old server messages.
          final earliestEchoTime = localMessage.time.subtract(
            const Duration(minutes: 10),
          );
          final latestEchoTime = localMessage.time.add(
            const Duration(minutes: 10),
          );
          final serverTime = serverMessage.time;
          return !serverTime.isBefore(earliestEchoTime) &&
              !serverTime.isAfter(latestEchoTime);
        }
      }
    }

    UserMessage? latestServerUserMessage;
    var hasInProgressAssistant = false;
    for (final message in mergedMessages) {
      if (message is UserMessage) {
        latestServerUserMessage = message;
      } else if (message is AssistantMessage && !message.isCompleted) {
        hasInProgressAssistant = true;
      }
    }

    // Attachment-tolerant echo match (issue #179 image variant): the server
    // may rewrite FilePart URLs/filenames, so the exact signature above can
    // miss while text + file count + mime still identify the send. Unlike the
    // fuzzy prefix path below this needs no in-progress assistant (the turn
    // may long be completed) but stays within ±10 minutes so repeated
    // intentional prompts remain distinct.
    for (final serverMessage in mergedMessages) {
      if (serverMessage is! UserMessage) {
        continue;
      }
      if (_isOptimisticLocalUserMessageId(serverMessage.id)) {
        continue;
      }
      if (serverMessage.sessionId != localMessage.sessionId) {
        continue;
      }
      if (!_isLikelyPendingLocalUserMatch(
        pending: localMessage,
        incoming: serverMessage,
      )) {
        continue;
      }
      final delta = serverMessage.time
          .difference(localMessage.time)
          .abs();
      if (delta > const Duration(minutes: 10)) {
        continue;
      }
      return true;
    }

    if (!hasInProgressAssistant || latestServerUserMessage == null) {
      return false;
    }

    final latestServerSignature = _normalizedUserMessageSignature(
      latestServerUserMessage,
    );
    if (localSignature.isNotEmpty && latestServerSignature.isNotEmpty) {
      final sharesPrefix =
          localSignature.startsWith(latestServerSignature) ||
          latestServerSignature.startsWith(localSignature);
      if (!sharesPrefix) {
        return false;
      }
    }

    final earliestEchoTime = localMessage.time.subtract(
      const Duration(seconds: 2),
    );
    final latestEchoTime = localMessage.time.add(const Duration(seconds: 45));
    final serverTime = latestServerUserMessage.time;
    if (serverTime.isBefore(earliestEchoTime) ||
        serverTime.isAfter(latestEchoTime)) {
      return false;
    }

    return true;
  }

  /// Inserts an unresolved optimistic user bubble into [merged] at the slot
  /// it holds in the visible [_messages] list instead of appending it after
  /// newer server content (issue #179: tail-appending is what rendered an old
  /// prompt — or an old image message — as the most recent bubble).
  void _insertPendingLocalPreservingAnchor(
    List<ChatMessage> merged,
    UserMessage message,
  ) {
    if (merged.any((existing) => existing.id == message.id)) {
      return;
    }
    final localIndex = _messages.indexWhere(
      (existing) => existing.id == message.id,
    );
    if (localIndex == -1) {
      merged.add(message);
      return;
    }
    merged.insert(
      timelineInsertIndexForLocalMessage(
        target: merged,
        localSnapshot: _messages,
        localIndex: localIndex,
      ),
      message,
    );
  }

  /// Merges server messages with any pending local user messages that haven't
  /// been echoed by the server yet. Returns both the merged list and the set of
  /// local IDs that were reconciled (matched to a server message by content
  /// signature), so callers can avoid re-adding them during tail preservation.
  ({List<ChatMessage> messages, Set<String> reconciledLocalIds})
  _mergeServerMessagesWithPendingLocalUsers(List<ChatMessage> serverMessages) {
    // Internal provider state appends messages in-place during sends/streaming,
    // so merged results must stay growable even when the source list is not.
    final emptyResult = (
      messages: List<ChatMessage>.from(serverMessages),
      reconciledLocalIds: const <String>{},
    );
    if (_pendingLocalUserMessageIds.isEmpty) return emptyResult;

    final merged = List<ChatMessage>.from(serverMessages);
    final existingIds = serverMessages.map((message) => message.id).toSet();
    final reconciledLocalIds = <String>{};

    // Track IDs matched by exact server ID before removing from pending.
    for (final id in _pendingLocalUserMessageIds) {
      if (existingIds.contains(id)) reconciledLocalIds.add(id);
    }
    _pendingLocalUserMessageIds.removeWhere(existingIds.contains);

    // Track IDs matched by content signature (different local vs server ID).
    for (final serverMessage in serverMessages) {
      if (serverMessage is! UserMessage) {
        continue;
      }
      final pendingLocalIndex = _findPendingLocalUserMessageIndex(
        serverMessage,
      );
      if (pendingLocalIndex == -1) {
        continue;
      }
      final localId = _messages[pendingLocalIndex].id;
      reconciledLocalIds.add(localId);
      _pendingLocalUserMessageIds.remove(localId);
    }

    if (_pendingLocalUserMessageIds.isEmpty) {
      return (messages: merged, reconciledLocalIds: reconciledLocalIds);
    }

    final reconciledLocalSignatureCounts = <String, int>{};
    for (final message in _messages) {
      if (message is! UserMessage) {
        continue;
      }
      if (!reconciledLocalIds.contains(message.id)) {
        continue;
      }
      final signature = _normalizedUserMessageSignature(message);
      if (signature.isEmpty) {
        continue;
      }
      reconciledLocalSignatureCounts.update(
        signature,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    for (final message in _messages) {
      if (message is! UserMessage) {
        continue;
      }
      if (!_pendingLocalUserMessageIds.contains(message.id)) {
        continue;
      }
      final localSignature = _normalizedUserMessageSignature(message);
      final signatureAlreadyReconciledThisPass =
          localSignature.isNotEmpty &&
          (reconciledLocalSignatureCounts[localSignature] ?? 0) > 0;
      if (signatureAlreadyReconciledThisPass) {
        _insertPendingLocalPreservingAnchor(merged, message);
        continue;
      }
      if (_shouldSkipLocalUserAppendAsDuplicateEcho(
        localMessage: message,
        mergedMessages: merged,
      )) {
        reconciledLocalIds.add(message.id);
        _pendingLocalUserMessageIds.remove(message.id);
        continue;
      }
      if (existingIds.contains(message.id)) {
        continue;
      }
      _insertPendingLocalPreservingAnchor(merged, message);
    }

    return (messages: merged, reconciledLocalIds: reconciledLocalIds);
  }

  bool _hasVisibleAssistantContent(AssistantMessage message) {
    if (message.parts.isEmpty) {
      return message.isCompleted;
    }
    for (final part in message.parts) {
      if (part is TextPart && part.text.trim().isNotEmpty) {
        return true;
      }
      if (part is ReasoningPart && part.text.trim().isNotEmpty) {
        return true;
      }
      if (part is ToolPart && _isTerminalToolState(part.state)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldPreserveSettledLocalTailMessage({
    required ChatMessage message,
    required DateTime? latestServerTime,
  }) {
    if (message is! AssistantMessage) {
      return false;
    }
    if (!message.isCompleted || !_hasVisibleAssistantContent(message)) {
      return false;
    }
    if (latestServerTime == null) {
      return true;
    }
    return !message.time.isBefore(latestServerTime);
  }

  DateTime? _latestMessageTime(List<ChatMessage> messages) {
    DateTime? latest;
    for (final message in messages) {
      if (latest == null || message.time.isAfter(latest)) {
        latest = message.time;
      }
    }
    return latest;
  }

  ({List<ChatMessage> messages, bool requiresFullFetch, bool usedGapRecovery})
  _mergeServerTailWithCachedMessages({
    required List<ChatMessage> serverMessages,
    required List<ChatMessage> cachedMessages,
    required String sessionId,
  }) {
    final serverForSession = serverMessages
        .where((message) => message.sessionId == sessionId)
        .toList(growable: false);
    if (serverForSession.isEmpty) {
      return (
        messages: serverMessages,
        requiresFullFetch: false,
        usedGapRecovery: false,
      );
    }

    final cachedForSession = cachedMessages
        .where((message) => message.sessionId == sessionId)
        .toList(growable: false);
    if (cachedForSession.isEmpty) {
      return (
        messages: serverForSession,
        requiresFullFetch: false,
        usedGapRecovery: false,
      );
    }

    final cachedIndexById = <String, int>{
      for (var index = 0; index < cachedForSession.length; index += 1)
        cachedForSession[index].id: index,
    };

    var overlapServerIndex = -1;
    var overlapCachedIndex = -1;
    for (var index = 0; index < serverForSession.length; index += 1) {
      final cachedIndex = cachedIndexById[serverForSession[index].id];
      if (cachedIndex == null) {
        continue;
      }
      overlapServerIndex = index;
      overlapCachedIndex = cachedIndex;
      break;
    }

    if (overlapServerIndex == -1 || overlapCachedIndex == -1) {
      final optimisticOverlap = _findOptimisticTailOverlap(
        serverForSession: serverForSession,
        cachedForSession: cachedForSession,
      );
      if (optimisticOverlap != null) {
        overlapServerIndex = optimisticOverlap.serverIndex;
        overlapCachedIndex = optimisticOverlap.cachedIndex;
      }
    }

    if (overlapServerIndex == -1 || overlapCachedIndex == -1) {
      // No safe overlap means the cached snapshot cannot stay authoritative.
      // Surface the server tail immediately, mark the history as incomplete,
      // and let the caller force a full fetch before persisting any snapshot.
      return (
        messages: serverForSession,
        requiresFullFetch: true,
        usedGapRecovery: true,
      );
    }

    // Drop cached optimistic bubbles whose canonical echo is present in the
    // server list (issue #179): without this, the prefix below keeps the
    // stale `local_user_*` entry while the server list contributes its echo,
    // rendering the same turn twice. Matching is one-to-one (consumed echo
    // IDs) so repeated intentional prompts stay distinct.
    final consumedEchoIds = <String>{};
    final prefix = cachedForSession.take(overlapCachedIndex).where((message) {
      if (message is! UserMessage ||
          !_isOptimisticLocalUserMessageId(message.id)) {
        return true;
      }
      for (final serverMessage in serverForSession) {
        if (serverMessage is! UserMessage ||
            _isOptimisticLocalUserMessageId(serverMessage.id) ||
            consumedEchoIds.contains(serverMessage.id)) {
          continue;
        }
        final localSignature = _normalizedUserMessageSignature(message);
        final serverSignature = _normalizedUserMessageSignature(serverMessage);
        final signatureMatches = localSignature.isNotEmpty &&
            localSignature == serverSignature;
        final likelyMatches =
            !signatureMatches &&
            _isLikelyPendingLocalUserMatch(
              pending: message,
              incoming: serverMessage,
            );
        if (!signatureMatches && !likelyMatches) {
          continue;
        }
        final delta = serverMessage.time.difference(message.time).abs();
        if (delta > const Duration(minutes: 10)) {
          continue;
        }
        consumedEchoIds.add(serverMessage.id);
        _pendingLocalUserMessageIds.remove(message.id);
        return false;
      }
      return true;
    }).toList(growable: false);
    final merged = <ChatMessage>[...prefix, ...serverForSession];
    final deduplicated = <ChatMessage>[];
    final seen = <String>{};
    for (final message in merged) {
      if (seen.add(message.id)) {
        deduplicated.add(message);
      }
    }

    return (
      messages: deduplicated,
      requiresFullFetch: false,
      usedGapRecovery: false,
    );
  }

  ({int serverIndex, int cachedIndex})? _findOptimisticTailOverlap({
    required List<ChatMessage> serverForSession,
    required List<ChatMessage> cachedForSession,
  }) {
    for (
      var serverIndex = 0;
      serverIndex < serverForSession.length;
      serverIndex += 1
    ) {
      final serverMessage = serverForSession[serverIndex];
      if (serverMessage is! UserMessage) {
        continue;
      }

      final serverSignature = _normalizedUserMessageSignature(serverMessage);
      var matchedCachedIndex = -1;
      Duration? matchedDelta;
      var sawAmbiguousEmptySignatureCandidate = false;
      var sawAmbiguousSignatureCandidate = false;
      var matchedCandidateCount = 0;

      for (
        var cachedIndex = 0;
        cachedIndex < cachedForSession.length;
        cachedIndex += 1
      ) {
        final cachedMessage = cachedForSession[cachedIndex];
        if (cachedMessage is! UserMessage) {
          continue;
        }
        final isOptimisticCandidate =
            _pendingLocalUserMessageIds.contains(cachedMessage.id) ||
            _isOptimisticLocalUserMessageId(cachedMessage.id);
        if (!isOptimisticCandidate) {
          continue;
        }

        final delta = serverMessage.time.difference(cachedMessage.time).abs();
        if (delta > const Duration(minutes: 5)) {
          continue;
        }

        if (serverSignature.isEmpty) {
          if (!_pendingLocalUserMessageIds.contains(cachedMessage.id)) {
            continue;
          }
          if (matchedCachedIndex != -1) {
            sawAmbiguousEmptySignatureCandidate = true;
            break;
          }
          matchedCachedIndex = cachedIndex;
          matchedDelta = delta;
          continue;
        }

        final cachedSignature = _normalizedUserMessageSignature(cachedMessage);
        final signaturesMatch =
            cachedSignature == serverSignature ||
            _isLikelyPendingLocalUserMatch(
              pending: cachedMessage,
              incoming: serverMessage,
            );
        if (!signaturesMatch) {
          continue;
        }

        matchedCandidateCount += 1;
        if (matchedCandidateCount > 1) {
          sawAmbiguousSignatureCandidate = true;
          break;
        }

        if (matchedDelta == null || delta < matchedDelta) {
          matchedCachedIndex = cachedIndex;
          matchedDelta = delta;
        }
      }

      if (sawAmbiguousEmptySignatureCandidate ||
          sawAmbiguousSignatureCandidate) {
        continue;
      }
      if (matchedCachedIndex != -1) {
        return (serverIndex: serverIndex, cachedIndex: matchedCachedIndex);
      }
    }

    return null;
  }

  List<ChatMessage> _mergeServerMessagesWithActiveLocalTail(
    List<ChatMessage> serverMessages, {
    required String sessionId,
  }) {
    final serverMessagesForMerge = serverMessages
        .where(
          (message) =>
              !_isRecentlyRemovedMessage(message.sessionId, message.id),
        )
        .map(_withoutRecentlyRemovedParts)
        .toList(growable: false);
    final (:messages, :reconciledLocalIds) =
        _mergeServerMessagesWithPendingLocalUsers(serverMessagesForMerge);
    final merged = messages;
    final localMessages = _messages
        .where((message) => message.sessionId == sessionId)
        .toList(growable: false);
    if (localMessages.isEmpty) {
      return List<ChatMessage>.from(merged);
    }

    final localById = <String, ChatMessage>{
      for (final message in localMessages) message.id: message,
    };
    for (var index = 0; index < merged.length; index += 1) {
      final serverMessage = merged[index];
      final localMessage = localById[serverMessage.id];
      if (localMessage is AssistantMessage &&
          serverMessage is AssistantMessage) {
        merged[index] = _mergeAssistantMessageUpdate(
          localMessage,
          serverMessage,
        );
      }
    }

    final currentSessionId = _currentSession?.id;
    final shouldPreserveLocalTail =
        currentSessionId == sessionId && isSessionActivelyResponding(sessionId);
    final existingIds = merged.map((message) => message.id).toSet();
    // Treat reconciled local IDs as already present so they are not re-added.
    existingIds.addAll(reconciledLocalIds);

    var anchorIndex = -1;
    for (var index = localMessages.length - 1; index >= 0; index -= 1) {
      if (existingIds.contains(localMessages[index].id)) {
        anchorIndex = index;
        break;
      }
    }

    // With no overlap, preserve only a bounded recent tail to avoid keeping
    // stale phantom messages from very old local snapshots.
    const maxTailMessagesWithoutAnchor = 12;
    final tailStart = anchorIndex >= 0
        ? anchorIndex + 1
        : (localMessages.length > maxTailMessagesWithoutAnchor
              ? localMessages.length - maxTailMessagesWithoutAnchor
              : 0);
    final latestServerTime = _latestMessageTime(
      merged.where((message) => message.sessionId == sessionId).toList(),
    );
    for (var index = tailStart; index < localMessages.length; index += 1) {
      final message = localMessages[index];
      if (existingIds.contains(message.id)) {
        continue;
      }
      if (!shouldPreserveLocalTail &&
          !_shouldPreserveSettledLocalTailMessage(
            message: message,
            latestServerTime: latestServerTime,
          )) {
        continue;
      }
      if (message is UserMessage &&
          _isOptimisticLocalUserMessageId(message.id) &&
          !_pendingLocalUserMessageIds.contains(message.id)) {
        continue;
      }
      if (message is UserMessage &&
          _shouldSkipLocalUserAppendAsDuplicateEcho(
            localMessage: message,
            mergedMessages: merged,
          )) {
        _pendingLocalUserMessageIds.remove(message.id);
        continue;
      }
      if (message is UserMessage &&
          isOptimisticLocalUserTimelineId(message.id)) {
        final insertAt = timelineInsertIndexForLocalMessage(
          target: merged,
          localSnapshot: localMessages,
          localIndex: index,
        );
        merged.insert(insertAt.clamp(0, merged.length), message);
      } else {
        merged.add(message);
      }
      existingIds.add(message.id);
    }

    return List<ChatMessage>.from(merged);
  }
}
