part of '../chat_page.dart';

extension _ChatPageRuntimeSupport on _ChatPageState {
  bool _isChatScreenActive() {
    if (!mounted || !_isAppInForeground) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route == null) {
      return true;
    }
    return route.isCurrent;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    return _distanceToBottom() <= _ChatPageState._nearBottomThreshold;
  }

  double _distanceToBottom() {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final position = _scrollController.position;
    final distance = position.maxScrollExtent - position.pixels;
    if (distance < 0) {
      return 0;
    }
    return distance;
  }

  bool _canContinueScrollToBottomRequest(int requestToken) {
    return mounted &&
        _scrollController.hasClients &&
        requestToken == _scrollToBottomRequestToken;
  }

  bool _shouldShowJumpToFirstFab() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    if (position.pixels <= _ChatPageState._nearBottomThreshold) {
      return false;
    }
    return _distanceToBottom() >= _ChatPageState._jumpToFirstFabThreshold;
  }

  bool _handleScrollMetricsChanged(ScrollMetricsNotification notification) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final currentMax = _scrollController.position.maxScrollExtent;
    if (_resumeRefreshViewportRestorePending ||
        _isReturnRevealInFlight ||
        _olderMessagesAnchorRestoreInFlight ||
        _isProgrammaticScrollInFlight ||
        _hasUserScrollPriority() ||
        _responseSettleFramesRemaining > 0 ||
        _scrollFollowMode == _ScrollFollowMode.reading) {
      _lastKnownMaxScrollExtent = currentMax;
      return false;
    }
    final contentChanged = currentMax != _lastKnownMaxScrollExtent;
    final isResponding =
        _chatProvider?.isCurrentSessionActivelyResponding == true;
    if (_scrollFollowMode == _ScrollFollowMode.following &&
        contentChanged &&
        isResponding) {
      final gap = _distanceToBottom();
      if (gap > _ChatPageState._scrollToBottomEpsilon) {
        _setScrollOwner(_ScrollOwner.streaming);
        _scrollController.jumpTo(currentMax);
        _setScrollOwner(_ScrollOwner.none);
      }
    }
    _lastKnownMaxScrollExtent = currentMax;
    return false;
  }

  bool _isLatestAssistantMessageVisibleInViewport() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final chatProvider = _chatProvider;
    if (chatProvider == null || chatProvider.messages.isEmpty) {
      return false;
    }
    final latestMessageId = _resolveLatestRevealableAssistantMessageId(
      chatProvider.messages,
    );
    if (latestMessageId == null || latestMessageId.isEmpty) {
      return false;
    }
    AssistantMessage? latestAssistant;
    for (final message in chatProvider.messages.reversed) {
      if (message is AssistantMessage && message.id == latestMessageId) {
        latestAssistant = message;
        break;
      }
    }
    if (latestAssistant != null &&
        !latestAssistant.isCompleted &&
        chatProvider.isCurrentSessionActivelyResponding) {
      return false;
    }
    final measurementContext =
        _messageRevealMeasurementKeysByMessageId[latestMessageId]
            ?.currentContext;
    final anchorContext =
        _messageRevealAnchorKeysByMessageId[latestMessageId]?.currentContext;
    final targetContext = measurementContext ?? anchorContext;
    if (targetContext == null || !targetContext.mounted) {
      return false;
    }
    final renderObject = targetContext.findRenderObject();
    final viewportRenderObject = _scrollController
        .position
        .context
        .storageContext
        .findRenderObject();
    if (renderObject is! RenderBox || viewportRenderObject is! RenderBox) {
      return false;
    }
    if (!renderObject.attached ||
        !viewportRenderObject.attached ||
        !renderObject.hasSize ||
        !viewportRenderObject.hasSize) {
      return false;
    }
    final viewportHeight = _scrollController.position.viewportDimension;
    final top =
        renderObject.localToGlobal(Offset.zero).dy -
        viewportRenderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    return bottom > -_ChatPageState._scrollToBottomEpsilon &&
        top <= viewportHeight * 0.75;
  }

  void _beginResponseSettleWindow() {
    _responseSettleFramesRemaining = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainResponseSettleWindow();
    });
  }

  void _drainResponseSettleWindow() {
    if (!mounted || _responseSettleFramesRemaining <= 0) {
      return;
    }
    _responseSettleFramesRemaining -= 1;
    if (_responseSettleFramesRemaining <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainResponseSettleWindow();
    });
  }

  void _consumePendingUiNotice(ChatProvider chatProvider) {
    final notice = chatProvider.consumePendingUiNotice();
    if (notice == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final hasRetryAction =
          notice.type == ChatUiNoticeType.remoteAbort && notice.hasAction;
      _showChatPageSnackBar(
        content: Text(notice.message),
        action: hasRetryAction
            ? SnackBarAction(
                label: notice.actionLabel!,
                onPressed: () {
                  unawaited(
                    chatProvider.refreshActiveSessionView(
                      reason: 'ui-notice-remote-abort-retry',
                    ),
                  );
                },
              )
            : null,
      );
    });
  }

  void _consumeRejectedDraft(ChatProvider chatProvider) {
    if (!_isChatScreenActive()) {
      return;
    }
    final currentSessionId = chatProvider.currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      return;
    }
    final rejectedDraft = chatProvider.consumeRejectedDraft(
      sessionId: currentSessionId,
    );
    if (rejectedDraft == null || !rejectedDraft.hasContent) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_chatInputController.hasDraftContent &&
          _chatInputController.hasMaterialDraftContent) {
        return;
      }
      _setState(() {
        _composerPrefilledDraft = rejectedDraft;
        _composerPrefilledDraftVersion += 1;
      });
      if (rejectedDraft.hasContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _inputFocusNode.requestFocus();
        });
      }
    });
  }

  void _consumePendingHistoryComposerSync(ChatProvider chatProvider) {
    if (!_isChatScreenActive()) {
      return;
    }
    final currentSessionId = chatProvider.currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      return;
    }
    final pending = chatProvider.consumePendingHistoryComposerSync(
      sessionId: currentSessionId,
    );
    if (pending == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (pending.clear) {
        _chatInputController.clearDraftWithoutFocus();
      }
      final draft = pending.draft;
      if (draft != null) {
        _setState(() {
          _composerPrefilledDraft = draft;
          _composerPrefilledDraftVersion += 1;
        });
      }
      if (draft != null && draft.hasContent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _inputFocusNode.requestFocus();
        });
      }
    });
  }

  _AssistantWorkCompactionDecision _resolveAssistantWorkCompactionDecision({
    required List<ChatMessage> messages,
    required bool isResponding,
  }) {
    final settingsProvider = _settingsProvider;
    final showThinkingBubbles = settingsProvider?.showThinkingBubbles ?? true;
    final showToolCallBubbles = settingsProvider?.showToolCallBubbles ?? true;
    final latestRevealableAssistantMessageId =
        _resolveLatestRevealableAssistantMessageId(
          messages,
          showThinkingBubbles: showThinkingBubbles,
          showToolCallBubbles: showToolCallBubbles,
        );
    final latestSettledAssistantWorkGroupId =
        _resolveLatestSettledAssistantWorkGroupId(
          messages: messages,
          showThinkingBubbles: showThinkingBubbles,
          showToolCallBubbles: showToolCallBubbles,
        );

    final decision = _AssistantWorkCompactionDecision(
      shouldDeferLatestCollapse: false,
      latestRevealableAssistantMessageId: latestRevealableAssistantMessageId,
      settledLatestAssistantWorkGroupId: latestSettledAssistantWorkGroupId,
    );

    if (!isResponding || decision.hasSettledLatestWorkGroup) {
      return decision;
    }

    return _AssistantWorkCompactionDecision(
      shouldDeferLatestCollapse: true,
      latestRevealableAssistantMessageId: latestRevealableAssistantMessageId,
      settledLatestAssistantWorkGroupId: latestSettledAssistantWorkGroupId,
    );
  }

  bool _isReadingLatestSettledAssistantResponse() {
    if (AppLogger.performanceLoggingEnabled) {
      return AppLogger.measurePerformance<bool>(
        'reading_latest_settled_response_guard',
        _isReadingLatestSettledAssistantResponseBody,
        tags: const <String>{'chat:settlement', 'ui:viewport'},
        context: <String, Object?>{
          'messageCount': _chatProvider?.messages.length ?? 0,
          'scrollMode': _scrollFollowMode.name,
          'hasUnreadBelow': _hasUnreadMessagesBelow,
        },
      );
    }
    return _isReadingLatestSettledAssistantResponseBody();
  }

  bool _isReadingLatestSettledAssistantResponseBody() {
    final chatProvider = _chatProvider;
    if (chatProvider == null ||
        _scrollFollowMode != _ScrollFollowMode.reading ||
        _hasUnreadMessagesBelow) {
      return false;
    }

    final latestRevealableAssistantMessageId =
        _resolveLatestRevealableAssistantMessageId(chatProvider.messages);
    final isLatestSettledOrPending =
        latestRevealableAssistantMessageId ==
            _finalAssistantRevealSettledMessageId ||
        latestRevealableAssistantMessageId ==
            _pendingFinalAssistantRevealMessageId;
    if (latestRevealableAssistantMessageId == null ||
        latestRevealableAssistantMessageId.isEmpty ||
        !isLatestSettledOrPending) {
      return false;
    }

    for (final message in chatProvider.messages) {
      if (message.id == latestRevealableAssistantMessageId) {
        return message is AssistantMessage && message.isCompleted;
      }
    }
    return false;
  }

  void _restoreSettledAssistantWorkOwnership(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    final compactionDecision = _resolveAssistantWorkCompactionDecision(
      messages: chatProvider.messages,
      isResponding: chatProvider.isCurrentSessionActivelyResponding,
    );

    // Passive busy pulses can survive session switches. Rebuild settled
    // ownership from the visible turn first so return/revalidation does not
    // re-enter the active collapse path for an already finished group.
    _settledLatestAssistantWorkGroupId =
        compactionDecision.settledLatestAssistantWorkGroupId;
    _finalAssistantRevealSettledMessageId =
        compactionDecision.latestRevealableAssistantMessageId;
    _wasCurrentSessionActivelyResponding =
        chatProvider.isCurrentSessionActivelyResponding &&
        !compactionDecision.hasSettledLatestWorkGroup;

    _traceFinalUi(
      'restore-settled-assistant-work-ownership',
      details:
          'reason=$reason latestRevealableAssistantMessageId=${compactionDecision.latestRevealableAssistantMessageId ?? "-"} latestSettledAssistantWorkGroupId=${compactionDecision.settledLatestAssistantWorkGroupId ?? "-"} responding=${chatProvider.isCurrentSessionActivelyResponding}',
    );
  }

  _CachedViewportRestoreTarget _resolveCachedViewportRestoreTarget(
    ChatProvider chatProvider,
  ) {
    if (chatProvider.currentSession == null || chatProvider.messages.isEmpty) {
      return _CachedViewportRestoreTarget.none;
    }
    if (chatProvider.isCurrentSessionActivelyResponding) {
      return _CachedViewportRestoreTarget.bottom;
    }
    final latestRevealableAssistantMessageId =
        _resolveLatestRevealableAssistantMessageId(chatProvider.messages);
    if (latestRevealableAssistantMessageId == null ||
        latestRevealableAssistantMessageId.isEmpty) {
      return _CachedViewportRestoreTarget.bottom;
    }
    return _CachedViewportRestoreTarget.latestResponse;
  }

  void _queueCachedViewportRestore(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId == null || sessionId.isEmpty) {
      _pendingInitialScrollSessionId = null;
      _pendingCachedViewportRestoreTarget = _CachedViewportRestoreTarget.none;
      return;
    }
    _pendingInitialScrollSessionId = sessionId;
    _pendingCachedViewportRestoreTarget = _resolveCachedViewportRestoreTarget(
      chatProvider,
    );
    _traceFinalUi(
      'queue-cached-viewport-restore',
      details:
          'reason=$reason target=${_pendingCachedViewportRestoreTarget.name} session=$sessionId',
    );
  }

  bool _consumeQueuedCachedViewportRestore(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId == null ||
        sessionId.isEmpty ||
        _pendingInitialScrollSessionId != sessionId ||
        chatProvider.state == ChatState.loading ||
        chatProvider.messages.isEmpty) {
      return false;
    }

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _consumeQueuedCachedViewportRestore(
          chatProvider,
          reason: '$reason:retry',
        );
      });
      return false;
    }

    final target = _pendingCachedViewportRestoreTarget;
    _pendingInitialScrollSessionId = null;
    _pendingCachedViewportRestoreTarget = _CachedViewportRestoreTarget.none;
    if (target == _CachedViewportRestoreTarget.none) {
      return false;
    }

    final signature = [
      sessionId,
      target.name,
      chatProvider.messages.length,
      chatProvider.messages.last.id,
      chatProvider.isCurrentSessionActivelyResponding,
    ].join('|');
    final now = DateTime.now();
    if (_lastConsumedCachedViewportRestoreAt != null &&
        _lastConsumedCachedViewportRestoreSignature == signature &&
        now.difference(_lastConsumedCachedViewportRestoreAt!) <
            const Duration(milliseconds: 400)) {
      _traceFinalUi(
        'cached-viewport-restore-skip-duplicate',
        details: 'reason=$reason signature=$signature',
      );
      return false;
    }
    _lastConsumedCachedViewportRestoreSignature = signature;
    _lastConsumedCachedViewportRestoreAt = now;

    _traceFinalUi(
      'consume-cached-viewport-restore',
      details: 'reason=$reason target=${target.name} signature=$signature',
    );
    switch (target) {
      case _CachedViewportRestoreTarget.none:
        return false;
      case _CachedViewportRestoreTarget.bottom:
        _scrollToBottom(force: true, animate: false);
        return true;
      case _CachedViewportRestoreTarget.latestResponse:
        _revealLatestMessageForCachedRestore(chatProvider, reason: reason);
        return true;
    }
  }

  void _scheduleQueuedDesktopViewportRestore(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    if (_resumeRefreshViewportRestorePending) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_isChatScreenActive() ||
          _chatProvider?.currentSession?.id !=
              chatProvider.currentSession?.id) {
        return;
      }
      _consumeQueuedCachedViewportRestore(chatProvider, reason: reason);
    });
  }

  void _syncSessionScrollState(ChatProvider chatProvider) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId != _trackedSessionId) {
      // Persist collapse state of the outgoing session before clearing.
      final outgoing = _trackedSessionId;
      if (outgoing != null) {
        _sessionCollapseHistoryCache[outgoing] =
            _expandedCollapsedHistoryGroupId;
        // Evict oldest entry when cache exceeds 20 sessions.
        if (_sessionCollapseHistoryCache.length > 20) {
          _sessionCollapseHistoryCache.remove(
            _sessionCollapseHistoryCache.keys.first,
          );
        }
      }
      _trackedSessionId = sessionId;
      _lastUserScrollIntentAt = null;
      if (sessionId != null) {
        unawaited(
          _notificationService?.clearNotificationsForSession(sessionId),
        );
      }
      _queueCachedViewportRestore(chatProvider, reason: 'session-switch');
      _olderMessagesLoadTriggerArmed = true;
      _setScrollOwner(_ScrollOwner.none);
      // Restore collapse state for the incoming session (null if not cached).
      _expandedCollapsedHistoryGroupId = sessionId != null
          ? _sessionCollapseHistoryCache[sessionId]
          : null;
      _expandedAssistantWorkGroupId = null;
      _frozenCompactionBoundaryId = null;
      _wasCompactingContext = false;
      _nextFrozenCompactionBoundaryId = null;
      _nextWasCompactingContext = false;
      _deferAssistantWorkCollapse = false;
      _shouldRevealFinalAssistantOnCompletion = false;
      _pendingFinalAssistantRevealMessageId = null;
      _restoreSettledAssistantWorkOwnership(
        chatProvider,
        reason: 'session-switch',
      );
      _finalAssistantRevealScheduled = false;
      _pendingFinalAssistantRevealAttempts = 0;
      _messageRevealAnchorKeysByMessageId.clear();
      _lastRevealedAssistantMessageId = null;
      _scrollFollowMode = _ScrollFollowMode.following;
      _showScrollToFirstFab = false;
      _hasUnreadMessagesBelow = false;
      _rememberProviderMessageSignature(chatProvider);
    }

    if (sessionId == _trackedSessionId &&
        _pendingInitialScrollSessionId == sessionId &&
        _pendingCachedViewportRestoreTarget ==
            _CachedViewportRestoreTarget.none &&
        chatProvider.messages.isNotEmpty) {
      _queueCachedViewportRestore(chatProvider, reason: 'messages-hydrated');
    }

    if (sessionId == null) {
      _pendingInitialScrollSessionId = null;
      _pendingCachedViewportRestoreTarget = _CachedViewportRestoreTarget.none;
      _scrollFollowMode = _ScrollFollowMode.following;
      _lastRevealedAssistantMessageId = null;
      _showScrollToFirstFab = false;
      _expandedCollapsedHistoryGroupId = null;
      _expandedAssistantWorkGroupId = null;
      _frozenCompactionBoundaryId = null;
      _wasCompactingContext = false;
      _nextFrozenCompactionBoundaryId = null;
      _nextWasCompactingContext = false;
      _wasCurrentSessionActivelyResponding = false;
      _deferAssistantWorkCollapse = false;
      _setScrollOwner(_ScrollOwner.none);
      _lastUserScrollIntentAt = null;
      _shouldRevealFinalAssistantOnCompletion = false;
      _pendingFinalAssistantRevealMessageId = null;
      _finalAssistantRevealSettledMessageId = null;
      _settledLatestAssistantWorkGroupId = null;
      _finalAssistantRevealScheduled = false;
      _pendingFinalAssistantRevealAttempts = 0;
      _messageRevealAnchorKeysByMessageId.clear();
      _rememberProviderMessageSignature(chatProvider);
      return;
    }

    if (_pendingInitialScrollSessionId == sessionId &&
        chatProvider.state != ChatState.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _consumeQueuedCachedViewportRestore(
          chatProvider,
          reason: 'session-ready',
        );
      });
    }
  }

  void _rememberProviderMessageSignature(ChatProvider chatProvider) {
    _lastProviderMessageTrackingSessionId = chatProvider.currentSession?.id;
    _lastProviderMessageTrackingLastId = chatProvider.messages.lastOrNull?.id;
    _lastProviderMessageTrackingCount = chatProvider.messages.length;
    _lastProviderMessageTrackingVersion = chatProvider.messagesVersion;
  }

  void _syncPassiveProviderMessageIndicator(ChatProvider chatProvider) {
    final sessionId = chatProvider.currentSession?.id;
    final lastId = chatProvider.messages.lastOrNull?.id;
    final count = chatProvider.messages.length;
    final version = chatProvider.messagesVersion;
    final sameSession =
        sessionId != null && sessionId == _lastProviderMessageTrackingSessionId;
    final hadBaseline = sameSession && _lastProviderMessageTrackingVersion >= 0;
    final changed =
        hadBaseline &&
        version != _lastProviderMessageTrackingVersion &&
        (lastId != _lastProviderMessageTrackingLastId ||
            count != _lastProviderMessageTrackingCount);

    _lastProviderMessageTrackingSessionId = sessionId;
    _lastProviderMessageTrackingLastId = lastId;
    _lastProviderMessageTrackingCount = count;
    _lastProviderMessageTrackingVersion = version;

    if (!changed ||
        sessionId == null ||
        chatProvider.messages.isEmpty ||
        _scrollFollowMode == _ScrollFollowMode.following ||
        _resumeRefreshViewportRestorePending ||
        _isReturnRevealInFlight ||
        _olderMessagesAnchorRestoreInFlight) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _chatProvider?.currentSession?.id != sessionId) {
        return;
      }
      if (_scrollFollowMode == _ScrollFollowMode.following) {
        return;
      }
      _traceFinalUi(
        'passive-provider-message-change-mark-unread',
        details: 'session=$sessionId last=${lastId ?? "-"}',
      );
      _markUnreadMessagesBelow();
    });
  }

  void _syncResponseViewportPolicy(ChatProvider chatProvider) {
    if (AppLogger.performanceLoggingEnabled) {
      AppLogger.measurePerformance<void>(
        'response_viewport_policy',
        () => _syncResponseViewportPolicyBody(chatProvider),
        tags: const <String>{'chat:settlement', 'ui:viewport'},
        context: <String, Object?>{
          'messageCount': chatProvider.messages.length,
          'sessionHash': AppLogger.safeContextId(
            chatProvider.currentSession?.id,
          ),
          'isResponding': chatProvider.isCurrentSessionActivelyResponding,
        },
      );
      return;
    }
    _syncResponseViewportPolicyBody(chatProvider);
  }

  void _syncResponseViewportPolicyBody(ChatProvider chatProvider) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId == null) {
      return;
    }

    final previousDebugSessionId = _debugActiveTurnPassiveScrollSessionId;
    if (previousDebugSessionId != null && previousDebugSessionId != sessionId) {
      _debugFinishActiveTurnPassiveScrollTracking(
        sessionId: previousDebugSessionId,
        reason: 'session-switch',
      );
    }

    final isResponding = chatProvider.isCurrentSessionActivelyResponding;
    final compactionDecision = _resolveAssistantWorkCompactionDecision(
      messages: chatProvider.messages,
      isResponding: isResponding,
    );
    final latestRevealableAssistantMessageId =
        compactionDecision.latestRevealableAssistantMessageId;
    final latestSettledAssistantWorkGroupId =
        compactionDecision.settledLatestAssistantWorkGroupId;

    if (isResponding) {
      final readingLatestSettledResponse =
          _isReadingLatestSettledAssistantResponse();
      final readingPendingFinalReveal =
          readingLatestSettledResponse &&
          latestRevealableAssistantMessageId ==
              _pendingFinalAssistantRevealMessageId;
      _debugStartActiveTurnPassiveScrollTracking(sessionId);
      if (_scrollFollowMode != _ScrollFollowMode.following) {
        if (readingLatestSettledResponse) {
          _traceFinalUi(
            'viewport-policy-keep-reading-latest-during-responding-pulse',
            details:
                'latestRevealableAssistantMessageId=${latestRevealableAssistantMessageId ?? "-"}',
          );
        } else {
          // Active updates below a reader-owned viewport should surface unread
          // work without reclaiming the scroll position.
          _markUnreadMessagesBelow();
        }
      }
      _deferAssistantWorkCollapse = readingLatestSettledResponse
          ? false
          : compactionDecision.shouldDeferLatestCollapse;
      _shouldRevealFinalAssistantOnCompletion = readingPendingFinalReveal
          ? true
          : !readingLatestSettledResponse;
      if (!readingPendingFinalReveal) {
        _pendingFinalAssistantRevealMessageId = null;
      }
      if (!readingLatestSettledResponse) {
        _finalAssistantRevealSettledMessageId = null;
        _settledLatestAssistantWorkGroupId = null;
      }
      _pendingFinalAssistantRevealAttempts = 0;
      _wasCurrentSessionActivelyResponding = !readingLatestSettledResponse;
    } else {
      _debugFinishActiveTurnPassiveScrollTracking(
        sessionId: sessionId,
        reason: 'turn-finished',
      );
      if (_wasCurrentSessionActivelyResponding) {
        _wasCurrentSessionActivelyResponding = false;
        _beginResponseSettleWindow();
        _deferAssistantWorkCollapse = false;
        _settledLatestAssistantWorkGroupId = latestSettledAssistantWorkGroupId;
        _pendingFinalAssistantRevealAttempts = 0;
        if (latestRevealableAssistantMessageId != null &&
            _lastRevealedAssistantMessageId !=
                latestRevealableAssistantMessageId) {
          ChatMessage? latestMessage;
          for (final m in chatProvider.messages) {
            if (m.id == latestRevealableAssistantMessageId) {
              latestMessage = m;
              break;
            }
          }
          if (latestMessage is AssistantMessage && latestMessage.isCompleted) {
            _lastRevealedAssistantMessageId =
                latestRevealableAssistantMessageId;
            if (_scrollFollowMode == _ScrollFollowMode.following) {
              _scrollToBottomRequestToken += 1;
              _scrollFollowMode = _ScrollFollowMode.reading;
              _pendingFinalAssistantRevealMessageId =
                  latestRevealableAssistantMessageId;
              _shouldRevealFinalAssistantOnCompletion = true;
              _traceFinalUi(
                'viewport-policy-finished-schedule-final-reveal',
                details:
                    'latestRevealableAssistantMessageId=$latestRevealableAssistantMessageId',
              );
              _scheduleFinalAssistantReveal();
            } else {
              _traceFinalUi(
                'viewport-policy-finished-without-final-reveal-not-following',
                details:
                    'latestRevealableAssistantMessageId=$latestRevealableAssistantMessageId',
              );
              _pendingFinalAssistantRevealMessageId = null;
            }
          }
        } else if (latestRevealableAssistantMessageId == null) {
          _shouldRevealFinalAssistantOnCompletion = false;
          _pendingFinalAssistantRevealMessageId = null;
          if (_scrollFollowMode == _ScrollFollowMode.following) {
            _traceFinalUi('viewport-policy-finished-no-revealable-keep-bottom');
            _scrollToBottom(force: false);
          }
        }
      }
    }
  }

  GlobalKey _messageRevealAnchorKey(String messageId) {
    return _messageRevealAnchorKeysByMessageId.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'message_reveal_anchor_$messageId'),
    );
  }

  GlobalKey _messageRevealMeasurementKey(String messageId) {
    return _messageRevealMeasurementKeysByMessageId.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'message_reveal_measurement_$messageId'),
    );
  }

  void _pruneMessageRevealAnchorKeys(List<ChatMessage> messages) {
    if (_messageRevealAnchorKeysByMessageId.isEmpty &&
        _messageRevealMeasurementKeysByMessageId.isEmpty) {
      return;
    }
    final visibleMessageIds = messages.map((message) => message.id).toSet();
    _messageRevealAnchorKeysByMessageId.removeWhere(
      (messageId, _) => !visibleMessageIds.contains(messageId),
    );
    _messageRevealMeasurementKeysByMessageId.removeWhere(
      (messageId, _) => !visibleMessageIds.contains(messageId),
    );
  }

  void _revealLatestMessageForCachedRestore(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    final sessionId = chatProvider.currentSession?.id;
    if (sessionId == null ||
        sessionId.isEmpty ||
        chatProvider.messages.isEmpty) {
      return;
    }

    final latestAssistantMessageId = _resolveLatestRevealableAssistantMessageId(
      chatProvider.messages,
    );
    if (latestAssistantMessageId == null || latestAssistantMessageId.isEmpty) {
      return;
    }
    _scrollToBottomRequestToken += 1;
    _scheduleLatestMessageReturnReveal(
      sessionId: sessionId,
      messageId: latestAssistantMessageId,
      reason: reason,
    );
  }

  void _scheduleLatestMessageReturnReveal({
    required String sessionId,
    required String messageId,
    required String reason,
    int attempt = 0,
    int? generation,
  }) {
    final effectiveGeneration = generation ?? _returnRevealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _runLatestMessageReturnReveal(
          sessionId: sessionId,
          messageId: messageId,
          reason: reason,
          attempt: attempt,
          generation: effectiveGeneration,
        ),
      );
    });
  }

  Future<void> _runLatestMessageReturnReveal({
    required String sessionId,
    required String messageId,
    required String reason,
    required int attempt,
    required int generation,
  }) async {
    void releaseReturnRevealOwner() {
      if (_currentScrollOwner == _ScrollOwner.returnReveal) {
        _setScrollOwner(_ScrollOwner.none);
      }
    }

    void fallbackToBottom(String fallbackReason) {
      _traceFinalUi(
        'return-reveal-fallback-to-bottom',
        details:
            'reason=$reason fallback=$fallbackReason session=$sessionId messageId=$messageId attempt=$attempt',
      );
      _setScrollOwner(_ScrollOwner.returnReveal);
      _scrollToBottom(force: true, animate: false);
    }

    if (!mounted) {
      return;
    }
    if (generation != _returnRevealGeneration) {
      releaseReturnRevealOwner();
      return;
    }

    if (_hasUserScrollPriority()) {
      releaseReturnRevealOwner();
      return;
    }

    final chatProvider = _chatProvider;
    if (chatProvider == null || chatProvider.currentSession?.id != sessionId) {
      releaseReturnRevealOwner();
      return;
    }

    if (chatProvider.isCurrentSessionActivelyResponding) {
      releaseReturnRevealOwner();
      _scrollToBottom(force: false);
      return;
    }

    if (chatProvider.messages.isEmpty) {
      releaseReturnRevealOwner();
      return;
    }

    final latestRevealableAssistantMessageId =
        _resolveLatestRevealableAssistantMessageId(chatProvider.messages);
    if (latestRevealableAssistantMessageId == null ||
        latestRevealableAssistantMessageId.isEmpty) {
      releaseReturnRevealOwner();
      return;
    }
    if (latestRevealableAssistantMessageId != messageId) {
      _setScrollOwner(_ScrollOwner.returnReveal);
      _scheduleLatestMessageReturnReveal(
        sessionId: sessionId,
        messageId: latestRevealableAssistantMessageId,
        reason: reason,
        generation: generation,
      );
      return;
    }

    if (!_scrollController.hasClients) {
      if (attempt + 1 < _ChatPageState._maxReturnLatestRevealAttempts) {
        _setScrollOwner(_ScrollOwner.returnReveal);
        _scheduleLatestMessageReturnReveal(
          sessionId: sessionId,
          messageId: messageId,
          reason: reason,
          attempt: attempt + 1,
          generation: generation,
        );
      } else {
        fallbackToBottom('no-scroll-clients');
      }
      return;
    }

    var anchorContext =
        _messageRevealAnchorKeysByMessageId[messageId]?.currentContext;
    if (anchorContext == null) {
      _setScrollOwner(_ScrollOwner.returnReveal);
      final distanceFromTail =
          _scrollController.position.maxScrollExtent -
          _scrollController.position.pixels;
      final isTailLikelyUnmaterialized =
          chatProvider.messages.length >= 80 &&
          distanceFromTail > _scrollController.position.viewportDimension * 2;
      final shouldMaterializeTail =
          isTailLikelyUnmaterialized &&
          attempt == (_ChatPageState._maxReturnLatestRevealAttempts ~/ 2) - 1;
      if (shouldMaterializeTail) {
        if (_hasUserScrollPriority()) {
          releaseReturnRevealOwner();
          return;
        }
        _traceFinalUi(
          'return-reveal-midway-tail-jump',
          details:
              'reason=$reason session=$sessionId messageId=$messageId attempt=$attempt max=${_scrollController.position.maxScrollExtent}',
        );
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!mounted ||
            generation != _returnRevealGeneration ||
            _chatProvider?.currentSession?.id != sessionId) {
          releaseReturnRevealOwner();
          return;
        }
        anchorContext =
            _messageRevealAnchorKeysByMessageId[messageId]?.currentContext;
        if (anchorContext != null) {
          // Continue below so the normal ensureVisible path preserves reading
          // alignment after the tail has been forced into the render tree.
        }
      }
      if (anchorContext == null &&
          attempt + 1 < _ChatPageState._maxReturnLatestRevealAttempts) {
        _scheduleLatestMessageReturnReveal(
          sessionId: sessionId,
          messageId: messageId,
          reason: reason,
          attempt: attempt + 1,
          generation: generation,
        );
        return;
      }
      if (anchorContext == null) {
        if (isTailLikelyUnmaterialized) {
          fallbackToBottom('missing-anchor-context');
        } else {
          releaseReturnRevealOwner();
        }
        return;
      }
    }

    if (generation != _returnRevealGeneration) {
      releaseReturnRevealOwner();
      return;
    }
    if (_hasUserScrollPriority()) {
      releaseReturnRevealOwner();
      return;
    }
    _setScrollOwner(_ScrollOwner.returnReveal);
    try {
      await Scrollable.ensureVisible(
        anchorContext,
        alignment: _ChatPageState._returnLatestRevealAlignment,
        duration: Duration.zero,
      );
    } catch (error, stackTrace) {
      AppLogger.debug(
        'Failed to reveal latest message after $reason for session=$sessionId message=$messageId',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        _setScrollOwner(_ScrollOwner.none);
      }
    }

    if (!mounted || _chatProvider?.currentSession?.id != sessionId) {
      return;
    }

    final shouldAutoFollow = _isNearBottom();
    final targetMode = shouldAutoFollow
        ? _ScrollFollowMode.following
        : _ScrollFollowMode.reading;
    const shouldShowFirstFab = false;
    if (_scrollFollowMode == targetMode &&
        !_hasUnreadMessagesBelow &&
        _showScrollToFirstFab == shouldShowFirstFab &&
        _finalAssistantRevealSettledMessageId == messageId) {
      return;
    }

    _setState(() {
      _scrollFollowMode = targetMode;
      _hasUnreadMessagesBelow = false;
      _showScrollToFirstFab = shouldShowFirstFab;
      _finalAssistantRevealSettledMessageId = messageId;
      _lastRevealedAssistantMessageId = messageId;
    });
  }

  void _scheduleFinalAssistantReveal() {
    final messageId = _pendingFinalAssistantRevealMessageId;
    if (_finalAssistantRevealScheduled) {
      _traceFinalUi('final-reveal-skip-already-scheduled');
      return;
    }
    if (messageId == null || messageId.isEmpty) {
      _traceFinalUi('final-reveal-skip-missing-message-id');
      return;
    }

    _finalAssistantRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finalAssistantRevealScheduled = false;
      if (!mounted ||
          !_shouldRevealFinalAssistantOnCompletion ||
          _pendingFinalAssistantRevealMessageId != messageId) {
        _traceFinalUi(
          'final-reveal-cancelled-before-run',
          details: 'messageId=$messageId',
        );
        return;
      }
      _traceFinalUi('final-reveal-run', details: 'messageId=$messageId');
      unawaited(_revealFinalAssistantMessageStart(messageId));
    });
  }

  Future<void> _revealFinalAssistantMessageStart(String messageId) async {
    if (!mounted ||
        !_shouldRevealFinalAssistantOnCompletion ||
        _pendingFinalAssistantRevealMessageId != messageId) {
      _traceFinalUi(
        'final-reveal-ignored-gate',
        details: 'messageId=$messageId',
      );
      return;
    }

    if (_scrollFollowMode == _ScrollFollowMode.pausedByUser) {
      _traceFinalUi(
        'final-reveal-cancelled-reader-owned',
        details: 'messageId=$messageId mode=${_scrollFollowMode.name}',
      );
      _shouldRevealFinalAssistantOnCompletion = false;
      _pendingFinalAssistantRevealMessageId = null;
      _markUnreadMessagesBelow();
      return;
    }

    if (_hasUserScrollPriority()) {
      _traceFinalUi(
        'final-reveal-cancelled-user-scroll',
        details: 'messageId=$messageId mode=${_scrollFollowMode.name}',
      );
      _shouldRevealFinalAssistantOnCompletion = false;
      _pendingFinalAssistantRevealMessageId = null;
      _markUnreadMessagesBelow();
      return;
    }

    if (!_scrollController.hasClients) {
      _traceFinalUi(
        'final-reveal-no-scroll-clients',
        details:
            'messageId=$messageId attempt=$_pendingFinalAssistantRevealAttempts',
      );
      _pendingFinalAssistantRevealAttempts += 1;
      if (_pendingFinalAssistantRevealAttempts <
          _ChatPageState._maxFinalAssistantRevealAttempts) {
        _scheduleFinalAssistantReveal();
      } else {
        _finalizeFinalAssistantReveal(messageId);
      }
      return;
    }

    final anchorContext =
        _messageRevealAnchorKeysByMessageId[messageId]?.currentContext;
    final measurementContext =
        _messageRevealMeasurementKeysByMessageId[messageId]?.currentContext;
    final anchorRenderObject = anchorContext?.findRenderObject();
    final measurementRenderObject = measurementContext?.findRenderObject();
    if (anchorContext == null ||
        measurementContext == null ||
        !anchorContext.mounted ||
        !measurementContext.mounted ||
        anchorRenderObject is! RenderBox ||
        measurementRenderObject is! RenderBox ||
        !anchorRenderObject.attached ||
        !measurementRenderObject.attached ||
        !anchorRenderObject.hasSize ||
        !measurementRenderObject.hasSize) {
      _traceFinalUi(
        'final-reveal-no-anchor',
        details:
            'messageId=$messageId attempt=$_pendingFinalAssistantRevealAttempts',
      );
      _pendingFinalAssistantRevealAttempts += 1;
      if (_pendingFinalAssistantRevealAttempts <
          _ChatPageState._maxFinalAssistantRevealAttempts) {
        _scheduleFinalAssistantReveal();
      } else {
        _finalizeFinalAssistantReveal(messageId);
      }
      return;
    }

    _isProgrammaticScrollInFlight = true;
    try {
      if (_messageAnchorFullyFitsInViewport(measurementContext)) {
        _traceFinalUi(
          'final-reveal-skipped-fits-viewport',
          details: 'messageId=$messageId',
        );
      } else {
        await Scrollable.ensureVisible(
          anchorContext,
          alignment: _ChatPageState._finalAssistantRevealAlignment,
          duration: _ChatPageState._finalAssistantRevealDuration,
          curve: Curves.easeOutCubic,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.debug(
        'Failed to reveal final assistant message id=$messageId',
        error: error,
        stackTrace: stackTrace,
      );
      _traceFinalUi(
        'final-reveal-scroll-error',
        details: 'messageId=$messageId error=${error.runtimeType}',
      );
    } finally {
      if (mounted) {
        _isProgrammaticScrollInFlight = false;
      }
    }

    if (!mounted || _pendingFinalAssistantRevealMessageId != messageId) {
      _traceFinalUi(
        'final-reveal-cancelled-after-scroll',
        details: 'messageId=$messageId',
      );
      return;
    }

    if (_hasUserScrollPriority()) {
      _traceFinalUi(
        'final-reveal-cancelled-after-user-scroll',
        details: 'messageId=$messageId mode=${_scrollFollowMode.name}',
      );
      _shouldRevealFinalAssistantOnCompletion = false;
      _pendingFinalAssistantRevealMessageId = null;
      _markUnreadMessagesBelow();
      return;
    }

    _finalizeFinalAssistantReveal(messageId);
  }

  void _finalizeFinalAssistantReveal(String messageId) {
    _traceFinalUi('final-reveal-finalize', details: 'messageId=$messageId');
    final nearBottom = _isNearBottom();
    _setState(() {
      _scrollFollowMode = nearBottom
          ? _ScrollFollowMode.following
          : _ScrollFollowMode.reading;
      _shouldRevealFinalAssistantOnCompletion = false;
      _hasUnreadMessagesBelow = false;
      _showScrollToFirstFab = false;
      _deferAssistantWorkCollapse = false;
      _pendingFinalAssistantRevealMessageId = null;
      _finalAssistantRevealSettledMessageId = messageId;
    });
  }

  bool _messageAnchorFullyFitsInViewport(BuildContext anchorContext) {
    if (!_scrollController.hasClients) {
      return false;
    }
    final anchorRenderObject = anchorContext.findRenderObject();
    final viewportRenderObject = _scrollController
        .position
        .context
        .storageContext
        .findRenderObject();
    if (anchorRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox) {
      return false;
    }
    if (!anchorRenderObject.attached ||
        !viewportRenderObject.attached ||
        !anchorRenderObject.hasSize ||
        !viewportRenderObject.hasSize) {
      return false;
    }
    final viewportHeight = _scrollController.position.viewportDimension;
    final top =
        anchorRenderObject.localToGlobal(Offset.zero).dy -
        viewportRenderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + anchorRenderObject.size.height;
    final tolerance = max(
      _ChatPageState._scrollToBottomEpsilon,
      viewportHeight * 0.05,
    );
    final startsInComfortableReadingArea = top <= viewportHeight * 0.6;
    return anchorRenderObject.size.height <= viewportHeight &&
        startsInComfortableReadingArea &&
        top >= -tolerance &&
        bottom <= viewportHeight + tolerance;
  }

  void _prepareForOutgoingUserMessage() {
    _deferAssistantWorkCollapse = true;
    _pendingInitialScrollSessionId = null;
    _pendingCachedViewportRestoreTarget = _CachedViewportRestoreTarget.none;
    _scrollToBottomRequestToken += 1;
    _returnRevealGeneration += 1;
    if (_currentScrollOwner == _ScrollOwner.returnReveal) {
      _setScrollOwner(_ScrollOwner.none);
    }
    _shouldRevealFinalAssistantOnCompletion = false;
    _pendingFinalAssistantRevealMessageId = null;
    _finalAssistantRevealSettledMessageId = null;
    _settledLatestAssistantWorkGroupId = null;
    _pendingFinalAssistantRevealAttempts = 0;
    if (_scrollFollowMode == _ScrollFollowMode.following &&
        !_hasUnreadMessagesBelow &&
        !_showScrollToFirstFab) {
      return;
    }
    _setState(() {
      _scrollFollowMode = _ScrollFollowMode.following;
      _hasUnreadMessagesBelow = false;
      _showScrollToFirstFab = false;
    });
  }

  void _jumpToLatestAndResumeAutoFollow() {
    _shouldRevealFinalAssistantOnCompletion = false;
    _pendingFinalAssistantRevealMessageId = null;
    _deferAssistantWorkCollapse = false;
    _scrollFollowMode = _ScrollFollowMode.following;
    _scrollToBottom(force: true);
  }

  void _markUnreadMessagesBelow() {
    if (_isLatestAssistantMessageVisibleInViewport()) {
      if (_scrollFollowMode == _ScrollFollowMode.reading &&
          !_hasUnreadMessagesBelow &&
          _showScrollToFirstFab == _shouldShowJumpToFirstFab()) {
        return;
      }
      _setState(() {
        _scrollFollowMode = _ScrollFollowMode.reading;
        _hasUnreadMessagesBelow = false;
        _showScrollToFirstFab = _shouldShowJumpToFirstFab();
      });
      return;
    }
    if (_scrollFollowMode == _ScrollFollowMode.pausedByUser &&
        _hasUnreadMessagesBelow &&
        _showScrollToFirstFab == _shouldShowJumpToFirstFab()) {
      return;
    }
    _setState(() {
      _scrollFollowMode = _ScrollFollowMode.pausedByUser;
      _hasUnreadMessagesBelow = true;
      _showScrollToFirstFab = _shouldShowJumpToFirstFab();
    });
  }

  void _scrollToFirstMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _setScrollOwner(_ScrollOwner.newMessage);
      final minExtent = _scrollController.position.minScrollExtent;
      _scrollController
          .animateTo(
            minExtent,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            if (!mounted) {
              return;
            }
            _setScrollOwner(_ScrollOwner.none);
            if (_showScrollToFirstFab) {
              _setState(() {
                _showScrollToFirstFab = false;
              });
            }
            // Issue #160: landing on the oldest resident message is not the
            // real first message when older history is still archived; pull
            // exactly one chunk so the jump reaches a stable top without
            // recursively paging through the whole session.
            final chatProvider = _chatProvider;
            if (chatProvider != null &&
                chatProvider.currentSession != null &&
                chatProvider.hasMoreOldMessages &&
                !chatProvider.isLoadingOlderMessages &&
                !_olderMessagesAnchorRestoreInFlight) {
              final maxExtentBefore = _scrollController.hasClients
                  ? _scrollController.position.maxScrollExtent
                  : 0.0;
              unawaited(
                _loadOlderMessagesAndRestoreAnchor(
                  provider: chatProvider,
                  maxExtentBefore: maxExtentBefore,
                  restoreAnchor: false,
                ),
              );
            }
          });
    });
  }

  void _scrollToBottom({bool force = false, bool animate = true}) {
    if (!force && _hasUserScrollPriority()) {
      _traceFinalUi(
        'scroll-to-bottom-skipped-user-scroll-priority',
        details: 'owner=${_currentScrollOwner.name}',
      );
      _markUnreadMessagesBelow();
      return;
    }
    if (!force &&
        (_currentScrollOwner == _ScrollOwner.newMessage ||
            _currentScrollOwner == _ScrollOwner.streaming)) {
      _traceFinalUi(
        'scroll-to-bottom-skipped-owner-already-following',
        details: 'owner=${_currentScrollOwner.name}',
      );
      return;
    }
    final requestToken = ++_scrollToBottomRequestToken;
    _traceFinalUi(
      'scroll-to-bottom-request',
      details:
          'requestToken=$requestToken force=$force animate=$animate owner=${_currentScrollOwner.name}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _runScrollToBottom(
          requestToken: requestToken,
          force: force,
          animate: animate,
        ),
      );
    });
  }

  Future<void> _refreshData() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSessions(userInitiated: true);
    await chatProvider.refresh();
  }

  bool _supportsInputModality(Model? model, String modality) {
    if (model == null || !model.attachment) {
      return false;
    }
    final normalizedModality = modality.toLowerCase();
    final modalities = model.modalities;
    final input = modalities?['input'];
    if (input is List) {
      final normalized = input
          .whereType<Object>()
          .map((item) => item.toString().toLowerCase())
          .toSet();
      return normalized.contains(normalizedModality);
    }
    if (input is Map) {
      return input[normalizedModality] == true;
    }
    // Backward compatibility for servers that only expose `attachment=true`.
    return true;
  }

  bool _supportsImageAttachments(Model? model) {
    return _supportsInputModality(model, 'image');
  }

  bool _supportsPdfAttachments(Model? model) {
    return _supportsInputModality(model, 'pdf');
  }
}
