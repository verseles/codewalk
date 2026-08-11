part of '../chat_provider.dart';

extension ChatProviderLifecycleOps on ChatProvider {
  // Foreground/background lifecycle.
  Future<void> setForegroundActive(bool isActive) async {
    final wasActive = _isForegroundActive;
    _isForegroundActive = isActive;
    if (isActive && !wasActive) {
      _markCurrentSessionTabViewed();
    }
    if (!isActive) {
      _cancelResumeGrace(reason: 'background');
      _stopForegroundResumeSyncIndicator(reason: 'background');
    }

    if (isActive && _hasPendingRenderFlush) {
      // Flush accumulated state changes suppressed while in background.
      _hasPendingRenderFlush = false;
      _notifyListeners(reason: 'foreground_flush');
    }

    if (!_refreshlessRealtimeEnabled) {
      return;
    }

    if (!isActive) {
      // Pause automatic network work in background. When cellular data saver is
      // active we also close idle realtime streams so no background downloads continue.
      // Preserve degraded mode state so we can re-enter it immediately on
      // foreground return instead of requiring 3 new SSE failures.
      _wasDegradedModeBeforeBackground = _degradedMode;
      _syncHealthTimer?.cancel();
      _syncHealthTimer = null;
      _degradedPollingTimer?.cancel();
      _degradedPollingTimer = null;
      _degradedMode = false;
      _degradedModeStartedAt = null;
      if (_cellularDataSaverService.shouldDisableBackgroundNetworkTasks) {
        _idleRealtimePausedForDataSaver = true;
        await _stopRealtimeEventSubscriptions(reason: 'background-data-saver');
      }
      return;
    }

    if (!wasActive) {
      _startResumeGrace(reason: 'foreground');
      _startForegroundResumeSyncIndicator(reason: 'foreground');
    }

    _startSyncHealthMonitor();
    // If degraded mode was active when the app went to background, re-enter
    // it immediately for UI continuity (polling starts right away). Do NOT
    // return early — the realtime subscription must still be started so
    // that _markRealtimeSignal can eventually exit degraded mode when the
    // SSE connection succeeds.
    if (_wasDegradedModeBeforeBackground) {
      if (_isInResumeGrace) {
        AppLogger.info('sync_resume_grace_deferred reason=degraded-resume');
      } else {
        _wasDegradedModeBeforeBackground = false;
        _enterDegradedMode(reason: 'foreground-resume-degraded');
      }
    }
    await _syncCellularDataSaverRealtimePolicy(reason: 'foreground-return');
    await _resumeRealtimeAfterForeground();
  }

  // Foreground state setter.
  void setAppInForeground(
    bool isForeground, {
    bool? isVisibleForSessionAttention,
  }) {
    _isAppInForeground = isForeground;
    _cellularDataSaverService.setAppForeground(isForeground);
    final attentionForeground = isVisibleForSessionAttention;
    if (attentionForeground == null) {
      return;
    }
    if (_isSessionAttentionAppInForeground == attentionForeground) {
      return;
    }
    _isSessionAttentionAppInForeground = attentionForeground;
    final publisher = _sessionAttentionAppForegroundPublisher;
    if (publisher != null) {
      unawaited(
        publisher(attentionForeground).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          AppLogger.warn(
            'Failed to publish app foreground state for session attention',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
  }

  // Chat route state setter.
  void setChatRouteActive(bool isActive) {
    if (_isChatRouteActive == isActive) {
      return;
    }
    _isChatRouteActive = isActive;
    if (isActive) {
      _markCurrentSessionTabViewed();
    }
    if (!_cellularDataSaverService.isAggressiveDataSaverActive) {
      return;
    }
    final reason = isActive ? 'chat-route-active' : 'chat-route-inactive';
    if (isActive) {
      _cellularDataSaverService.noteExplicitUserAction(reason: reason);
    }
    unawaited(
      _syncCellularDataSaverRealtimePolicy(
        reason: reason,
        forceBurst: isActive,
      ),
    );
    if (isActive) {
      unawaited(
        _runAutomaticForegroundSyncForDataSaver(reason: reason, force: true),
      );
    }
  }

  // Refresh the active session view (messages, status, todo).
  Future<void> refreshActiveSessionView({
    String reason = 'manual',
    bool includeStatus = true,
    bool allowDuringAbortSuppression = false,
    bool preferDelta = true,
    bool refreshAfterJoiningInFlight = false,
  }) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final session = _currentSession;
    if (session == null) {
      return;
    }

    while (true) {
      final activeTask = _activeSessionRefreshTask;
      if (activeTask == null) {
        break;
      }
      final activeSessionId = _activeSessionRefreshSessionId;
      _traceFinal(
        'refresh-active-join-inflight',
        sessionId: session.id,
        details: 'reason=$reason activeSession=${activeSessionId ?? '-'}',
      );
      await activeTask;
      if (_currentSession?.id != session.id) {
        return;
      }
      if (activeSessionId == session.id) {
        if (!refreshAfterJoiningInFlight) {
          if (includeStatus &&
              !_cellularDataSaverService.shouldSuppressBackgroundWork) {
            await refreshSessionStatusSnapshot();
          }
          return;
        }
        break;
      }
    }

    // During abort suppression, polling already delivered fresh data.
    // Loading from server risks showing stale abort content that the
    // suppression window is designed to hide.
    if (!allowDuringAbortSuppression &&
        _isAbortSuppressionActiveForSession(session.id)) {
      _traceFinal(
        'refresh-active-skip-abort-suppression',
        sessionId: session.id,
        details:
            'reason=$reason includeStatus=$includeStatus allowDuringAbortSuppression=$allowDuringAbortSuppression',
      );
      AppLogger.info(
        'Skipping active session refresh during abort suppression session=${session.id} reason=$reason',
      );
      return;
    }

    late final Future<bool> refreshTask;
    refreshTask = _runActiveSessionViewRefresh(
      session: session,
      reason: reason,
      includeStatus: includeStatus,
      allowDuringAbortSuppression: allowDuringAbortSuppression,
      preferDelta: preferDelta,
    );
    _activeSessionRefreshTask = refreshTask;
    _activeSessionRefreshSessionId = session.id;
    var fallbackToFullFetch = false;
    try {
      fallbackToFullFetch = await refreshTask;
    } finally {
      if (identical(_activeSessionRefreshTask, refreshTask)) {
        _activeSessionRefreshTask = null;
        _activeSessionRefreshSessionId = null;
      }
    }

    if (fallbackToFullFetch && _currentSession?.id == session.id) {
      unawaited(
        refreshActiveSessionView(
          reason: '$reason:delta-fallback',
          includeStatus: false,
          allowDuringAbortSuppression: allowDuringAbortSuppression,
          preferDelta: false,
        ),
      );
    }
  }

  Future<bool> _runActiveSessionViewRefresh({
    required ChatSession session,
    required String reason,
    required bool includeStatus,
    required bool allowDuringAbortSuppression,
    required bool preferDelta,
  }) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return false;
    }
    _traceFinal(
      'refresh-active-start',
      sessionId: session.id,
      details:
          'reason=$reason includeStatus=$includeStatus allowDuringAbortSuppression=$allowDuringAbortSuppression',
    );
    AppLogger.debug(
      'Refreshing active session view reason=$reason session=${session.id}',
    );

    final refreshStartVersion = _messagesVersion;
    var fallbackToFullFetch = false;

    try {
      final cachedMessages = List<ChatMessage>.from(
        _messages.where((message) => message.sessionId == session.id),
      );
      final canUseDelta = preferDelta && cachedMessages.isNotEmpty;
      final messagesResult = await getChatMessages(
        GetChatMessagesParams(
          projectId: projectProvider.currentProjectId,
          sessionId: session.id,
          directory: projectProvider.currentDirectory,
          limit: canUseDelta
              ? ChatProvider._defaultOlderMessagesChunkSize
              : null,
        ),
      );

      messagesResult.fold(
        (failure) {
          _traceFinal(
            'refresh-active-failure',
            sessionId: session.id,
            details: 'reason=$reason failure=${failure.runtimeType}',
          );
          AppLogger.warn(
            'Failed to refresh active session messages for ${session.id}: $failure',
          );
        },
        (messages) {
          if (_currentSession?.id != session.id) {
            return;
          }
          if (_messagesVersion != refreshStartVersion) {
            return;
          }
          var serverMessagesForMerge = messages;
          var requiresFullFetch = false;
          var usedGapRecovery = false;
          if (canUseDelta) {
            final deltaResult = _mergeServerTailWithCachedMessages(
              serverMessages: messages,
              cachedMessages: cachedMessages,
              sessionId: session.id,
            );
            serverMessagesForMerge = deltaResult.messages;
            requiresFullFetch = deltaResult.requiresFullFetch;
            usedGapRecovery = deltaResult.usedGapRecovery;
          }
          serverMessagesForMerge = _filterMessagesForPendingReplacementBranch(
            serverMessagesForMerge,
            sessionId: session.id,
          );
          final mergedMessages = _mergeServerMessagesWithActiveLocalTail(
            serverMessagesForMerge,
            sessionId: session.id,
          );
          final nextHasMoreOldMessages =
              usedGapRecovery ||
              serverMessagesForMerge.length >=
                  ChatProvider._defaultOlderMessagesChunkSize;
          final messagesChanged = !_areMessageListsSemanticallyEqual(
            cachedMessages,
            mergedMessages,
          );
          final hasMoreOldMessagesChanged =
              _hasMoreOldMessages != nextHasMoreOldMessages;
          if (!messagesChanged) {
            if (!hasMoreOldMessagesChanged) {
              _traceFinal(
                'refresh-active-noop',
                sessionId: session.id,
                details: 'reason=$reason',
              );
              return;
            }
            _hasMoreOldMessages = nextHasMoreOldMessages;
            notifyListeners();
            return;
          }

          final messagesApplied = _applyMessages(
            mergedMessages,
            origin: MessageUpdateOrigin.sessionRefresh,
            kind: MessageUpdateKind.fullSnapshot,
            sessionId: session.id,
            reason: 'active-session-refresh',
          );
          _cacheSessionMessages(session.id, _messages);
          if (messagesApplied) {
            _messagesVersion++;
          }
          _hasMoreOldMessages = nextHasMoreOldMessages;
          _prunePendingLocalUserMessageIdsToVisibleUsers();
          if (messagesApplied || hasMoreOldMessagesChanged) {
            _notifyListeners();
          }
          _traceFinal(
            'refresh-active-merged',
            sessionId: session.id,
            details: 'reason=$reason mergedMessages=${_messages.length}',
          );
          if (!_cellularDataSaverService.shouldSuppressBackgroundWork) {
            _scheduleAutoTitleRefresh(session.id);
          }
          if (!usedGapRecovery) {
            unawaited(
              _persistSessionMessagesSnapshotBestEffort(session.id, _messages),
            );
          }
          if (requiresFullFetch && _currentSession?.id == session.id) {
            fallbackToFullFetch = true;
          }
        },
      );

      if (includeStatus &&
          !_cellularDataSaverService.shouldSuppressBackgroundWork) {
        await refreshSessionStatusSnapshot();
      }
    } finally {
      _traceFinal(
        'refresh-active-finished',
        sessionId: session.id,
        details: 'reason=$reason includeStatus=$includeStatus',
      );
    }

    return fallbackToFullFetch;
  }

  // Warmup providers refresh.
  void warmupProvidersRefresh({String reason = 'startup'}) {
    AppLogger.info('providers_refresh_warmup reason=$reason');
    unawaited(initializeProviders());
  }

  // Config mutation deferral gate.
  bool get shouldDeferConfigMutations =>
      _hasLocalActiveSelectionSyncWork ||
      _hasAnyActiveAbortSuppression ||
      _hasAnyBusySessionStatus;

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == ChatState.error) {
      _setState(ChatState.loaded);
    }
  }

  /// Delete session
  Future<void> deleteSession(String sessionId) async {
    _currentProjectId = projectProvider.currentProjectId;
    final previousSessions = List<ChatSession>.from(_sessions);
    final previousCurrent = _currentSession;
    final previousMessages = List<ChatMessage>.from(_messages);
    final wasCurrent = previousCurrent?.id == sessionId;
    final deletedSession = previousSessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    final tabIdentity = deletedSession == null
        ? null
        : _sessionTabIdentityForSession(
            deletedSession,
            contextKey: _activeContextKey,
          );
    final attentionIdentity = _sessionAttentionIdentityFor(
      contextKey: _activeContextKey,
      sessionId: sessionId,
    );

    _removeSessionMessagesCache(sessionId);
    unawaited(_clearSessionMessagesSnapshotBestEffort(sessionId));

    _removeSessionById(sessionId, removePin: false);
    _sortSessionsInPlace();

    if (wasCurrent) {
      _currentSession = _sessions.firstOrNull;
      _dismissNotificationsForSession(_currentSession?.id);
      _threadPermissionsVersion++;
      _messages = <ChatMessage>[];
      _isLoadingOlderMessages = false;
      _hasMoreOldMessages = false;
      _messagesVersion++;
    }
    notifyListeners();

    final result = await deleteChatSession(
      DeleteChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
        directory: projectProvider.currentDirectory,
      ),
    );

    result.fold(
      (failure) {
        _sessions = previousSessions;
        _currentSession = previousCurrent;
        _dismissNotificationsForSession(_currentSession?.id);
        _threadPermissionsVersion++;
        _messages = List<ChatMessage>.from(previousMessages);
        if (previousCurrent != null) {
          _cacheSessionMessages(previousCurrent.id, previousMessages);
          unawaited(
            _persistSessionMessagesSnapshotBestEffort(
              previousCurrent.id,
              previousMessages,
            ),
          );
        }
        _messagesVersion++;
        _sortSessionsInPlace();
        unawaited(_persistLastSessionSnapshotBestEffort());
        _handleFailure(failure);
      },
      (_) async {
        if (tabIdentity != null) {
          _removeSessionTabAuthoritatively(tabIdentity, activeContext: true);
        }
        if (attentionIdentity != null) {
          _deleteSessionAttentionSnapshotIdentity(attentionIdentity);
        }
        if (wasCurrent && _currentSession != null) {
          await loadMessages(_currentSession!.id);
          await loadSessionInsights(_currentSession!.id, silent: true);
        }
        if (_currentSession == null) {
          unawaited(_clearLastSessionSnapshotBestEffort());
        } else {
          unawaited(_persistLastSessionSnapshotBestEffort());
        }
        notifyListeners();
      },
    );
  }

  /// Refresh current session
  Future<void> refresh() async {
    _cellularDataSaverService.noteExplicitUserAction(reason: 'manual-refresh');
    await _syncCellularDataSaverRealtimePolicy(
      reason: 'manual-refresh-user',
      forceBurst: true,
    );
    if (_currentSession != null) {
      await refreshActiveSessionView(reason: 'manual-refresh');
    } else {
      // If there is no current session, reload sessions
      if (_sessions.isNotEmpty) {
        // Assume workspaceId exists; in practice it should come from app state
        // Adjust based on actual app behavior
        _setState(ChatState.loaded);
      }
    }
  }

  @visibleForTesting
  void clearSseSettledTimestamps() {
    _sseSettledAtBySessionId.clear();
  }

  @visibleForTesting
  Future<void> reloadPendingInteractionsForTest() async {
    await _loadPendingInteractions();
  }
}
