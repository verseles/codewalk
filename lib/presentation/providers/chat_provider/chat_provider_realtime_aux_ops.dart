part of '../chat_provider.dart';

extension _ChatProviderRealtimeAuxOps on ChatProvider {
  Duration get _effectiveSyncHealthCheckInterval {
    if (_cellularDataSaverService.isAggressiveDataSaverActive) {
      return CellularDataSaverService.aggressiveSyncHealthCheckInterval;
    }
    if (_cellularDataSaverService.shouldThrottleAutomaticForegroundSync) {
      return _cellularDataSaverService.automaticSyncInterval;
    }
    return _syncHealthCheckInterval;
  }

  void _startResumeGrace({required String reason}) {
    final duration = clampSyncResumeGracePeriod(
      settingsProvider?.settings.syncResumeGracePeriod ??
          _foregroundResumeGracePeriod,
    );
    _resumeGraceTimer?.cancel();
    if (duration == Duration.zero) {
      _isInResumeGrace = false;
      return;
    }
    _isInResumeGrace = true;
    AppLogger.info(
      'sync_resume_grace_started reason=$reason duration_s=${duration.inSeconds}',
    );
    _resumeGraceTimer = Timer(duration, () {
      _resumeGraceTimer = null;
      if (!_isInResumeGrace) {
        return;
      }
      _isInResumeGrace = false;
      AppLogger.info('sync_resume_grace_elapsed reason=$reason');
      _startSyncHealthMonitor();
      if (_wasDegradedModeBeforeBackground) {
        _wasDegradedModeBeforeBackground = false;
        _enterDegradedMode(reason: 'resume-grace-elapsed');
      } else {
        _evaluateSyncHealth();
      }
      _notifyListeners();
    });
  }

  void _cancelResumeGrace({required String reason}) {
    final wasInGrace = _isInResumeGrace;
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _isInResumeGrace = false;
    if (wasInGrace) {
      AppLogger.info('sync_resume_grace_canceled reason=$reason');
      _notifyListeners();
    }
  }

  Future<void> _stopRealtimeEventSubscriptions({required String reason}) async {
    _eventStreamGeneration += 1;
    final previousSubscription = _eventSubscription;
    final previousGlobalSubscription = _globalEventSubscription;
    _eventSubscription = null;
    _globalEventSubscription = null;
    await _cancelSubscriptionSafely(
      previousSubscription,
      label: 'realtime event ($reason)',
    );
    await _cancelSubscriptionSafely(
      previousGlobalSubscription,
      label: 'global event ($reason)',
    );
  }

  Future<void> _syncCellularDataSaverRealtimePolicy({
    required String reason,
    bool forceBurst = false,
  }) async {
    if (!_refreshlessRealtimeEnabled) {
      return;
    }
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      _idleRealtimePausedForDataSaver = true;
      _setSyncState(ChatSyncState.connected, reason: 'data-saver-background');
      await _stopRealtimeEventSubscriptions(reason: 'background-data-saver');
      return;
    }
    if (!_cellularDataSaverService.isDataSaverActive) {
      if (!_isForegroundActive) {
        return;
      }
      _idleRealtimePausedForDataSaver = false;
      if (_eventSubscription == null) {
        await _startRealtimeEventSubscription();
      } else if (_globalEventSubscription == null) {
        await _startGlobalRealtimeEventSubscription();
      } else {
        _startSyncHealthMonitor();
      }
      return;
    }
    if (!_isForegroundActive) {
      _idleRealtimePausedForDataSaver = true;
      _setSyncState(ChatSyncState.connected, reason: 'data-saver-background');
      await _stopRealtimeEventSubscriptions(reason: 'background-data-saver');
      return;
    }

    final shouldKeepActive =
        _cellularDataSaverService.isAggressiveDataSaverActive
        ? _hasVisibleAggressiveDataSaverSession &&
              (forceBurst ||
                  _cellularDataSaverService.hasInteractiveBurst ||
                  _state == ChatState.sending ||
                  isCurrentSessionActivelyResponding ||
                  _hasPendingVisibleAggressiveThreadInteractions)
        : (forceBurst || _shouldKeepRealtimeActiveForDataSaver);
    if (!shouldKeepActive) {
      if (_idleRealtimePausedForDataSaver &&
          _eventSubscription == null &&
          _globalEventSubscription == null) {
        return;
      }
      _idleRealtimePausedForDataSaver = true;
      _setSyncState(ChatSyncState.connected, reason: 'data-saver-idle:$reason');
      await _stopRealtimeEventSubscriptions(reason: reason);
      return;
    }

    if (!_idleRealtimePausedForDataSaver) {
      final hasExpectedSubscriptions =
          _cellularDataSaverService.isAggressiveDataSaverActive
          ? _eventSubscription != null && _globalEventSubscription == null
          : _eventSubscription != null && _globalEventSubscription != null;
      if (hasExpectedSubscriptions) {
        return;
      }
    }
    _idleRealtimePausedForDataSaver = false;
    if (!_cellularDataSaverService.isAggressiveDataSaverActive &&
        _eventSubscription != null &&
        _globalEventSubscription == null) {
      await _startGlobalRealtimeEventSubscription();
      return;
    }
    await _startRealtimeEventSubscription();
  }

  Future<void> _startGlobalRealtimeEventSubscription() async {
    if (_globalEventSubscription != null ||
        _cellularDataSaverService.isAggressiveDataSaverActive ||
        _cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final generation = _eventStreamGeneration;
    final globalSubscription = watchGlobalChatEvents().listen(
      (result) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        result.fold(
          (failure) {
            _handleRealtimeStreamFailure(
              source: 'global-stream-failure',
              error: failure,
            );
          },
          (event) {
            _markRealtimeSignal(
              source: 'global-stream',
              directory:
                  _extractDirectoryFromEvent(event) ??
                  projectProvider.currentDirectory ??
                  '',
            );
            _handleGlobalEvent(event);
          },
        );
      },
      onError: (error) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(
          source: 'global-stream-exception',
          error: error,
        );
      },
      onDone: () {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(source: 'global-stream-done');
      },
    );

    if (generation != _eventStreamGeneration) {
      await _cancelSubscriptionSafely(
        globalSubscription,
        label: 'global event (stale generation)',
      );
      return;
    }

    _globalEventSubscription = globalSubscription;
    _startSyncHealthMonitor();
  }

  Future<void> _runAutomaticForegroundSyncForDataSaver({
    required String reason,
    bool force = false,
  }) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      await _stopRealtimeEventSubscriptions(reason: 'background-data-saver');
      return;
    }
    if (!force &&
        !_cellularDataSaverService.allowAutomaticForegroundSync(
          reason: reason,
        )) {
      return;
    }
    if (_cellularDataSaverService.isAggressiveDataSaverActive) {
      if (!_hasVisibleAggressiveDataSaverSession) {
        await _syncCellularDataSaverRealtimePolicy(
          reason: '$reason:not-visible',
        );
        return;
      }
      await refreshActiveSessionView(
        reason: 'data-saver:$reason',
        includeStatus: false,
      );
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      await _loadPendingInteractions(visibleSessionOnly: true);
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      await _syncCellularDataSaverRealtimePolicy(
        reason: '$reason:post-sync',
        forceBurst: force,
      );
      return;
    }
    await loadSessions(preserveVisibleState: true);
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await refreshActiveSessionView(
      reason: 'data-saver:$reason',
      includeStatus: true,
    );
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await _loadPendingInteractions();
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await _syncSelectionFromRemote(reason: 'data-saver:$reason', force: true);
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await _syncCellularDataSaverRealtimePolicy(reason: '$reason:post-sync');
  }

  void _startForegroundResumeSyncIndicator({required String reason}) {
    if (!_refreshlessRealtimeEnabled) {
      return;
    }
    final shouldNotify = !_isForegroundResumeSyncing;
    _isForegroundResumeSyncing = true;
    if (shouldNotify) {
      _foregroundResumeSyncCycleCount = 0;
      _recoverableSyncAlertEscalated = false;
    }
    _foregroundResumeSyncTimer?.cancel();
    _foregroundResumeSyncTimer = Timer(
      _foregroundResumeSyncIndicatorDuration,
      () {
        _foregroundResumeSyncTimer = null;
        if (!_isForegroundResumeSyncing) {
          return;
        }
        final recoverableSyncPending =
            _syncState == ChatSyncState.reconnecting ||
            _syncState == ChatSyncState.delayed ||
            _degradedMode;
        if (_isForegroundActive && recoverableSyncPending) {
          _foregroundResumeSyncCycleCount += 1;
          if (_foregroundResumeSyncCycleCount <
              _foregroundResumeSyncIndicatorMaxCycles) {
            _startForegroundResumeSyncIndicator(
              reason: 'foreground-resume-pending',
            );
            return;
          }
          _recoverableSyncAlertEscalated = true;
        }
        _foregroundResumeSyncCycleCount = 0;
        _isForegroundResumeSyncing = false;
        _notifyListeners();
      },
    );
    if (shouldNotify) {
      AppLogger.debug('sync_resume_indicator_started reason=$reason');
      _notifyListeners();
    }
  }

  void _stopForegroundResumeSyncIndicator({required String reason}) {
    _foregroundResumeSyncTimer?.cancel();
    _foregroundResumeSyncTimer = null;
    _foregroundResumeSyncCycleCount = 0;
    final wasSyncing = _isForegroundResumeSyncing;
    final wasEscalated = _recoverableSyncAlertEscalated;
    _isForegroundResumeSyncing = false;
    _recoverableSyncAlertEscalated = false;
    if (!wasSyncing && !wasEscalated) {
      return;
    }
    AppLogger.debug('sync_resume_indicator_stopped reason=$reason');
    _notifyListeners();
  }

  Future<void> _cancelSubscriptionSafely(
    StreamSubscription<dynamic>? subscription, {
    required String label,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel().timeout(timeout);
    } on TimeoutException {
      AppLogger.info(
        'Cancel $label subscription timed out; continuing with generation guard',
      );
    } catch (error) {
      AppLogger.warn('Failed to cancel $label subscription', error: error);
    }
  }

  void _markRealtimeSignal({
    required String source,
    required String directory,
  }) {
    _lastRealtimeSignalAt = DateTime.now();
    // Capture whether we were previously disconnected before resetting
    // the counter. When SSE reconnects after a gap, the OpenCode server
    // does NOT support Last-Event-ID replay (upstream issue #25657),
    // so any events emitted during the gap are permanently lost. We
    // must refresh state to recover missed permission requests, session
    // status changes, and completion notifications.
    final needsRecovery = _consecutiveRealtimeFailures > 0;
    _consecutiveRealtimeFailures = 0;
    _cancelResumeGrace(reason: 'signal:$source');
    _stopForegroundResumeSyncIndicator(reason: 'signal:$source');
    if (_degradedMode) {
      _exitDegradedMode(reason: 'signal-restored:$source');
    }
    _setSyncState(ChatSyncState.connected, reason: 'signal:$source');
    _sessionAttentionCoordinator.markMonitoringReconciled(directory: directory);
    if (needsRecovery) {
      _schedulePostReconnectRecovery();
    }
  }

  void _handleRealtimeStreamFailure({required String source, Object? error}) {
    _consecutiveRealtimeFailures += 1;
    _sessionAttentionCoordinator.pauseMonitoring(
      SessionAttentionPauseReason.offline,
    );
    AppLogger.warn(
      'event_stream_reconnecting source=$source attempts=$_consecutiveRealtimeFailures',
      error: error,
    );
    if (_isInResumeGrace) {
      AppLogger.info(
        'sync_resume_grace_suppressed reason=stream-failure:$source',
      );
      return;
    }
    _setSyncState(ChatSyncState.reconnecting, reason: 'stream-failure:$source');
    if (_refreshlessRealtimeEnabled &&
        _consecutiveRealtimeFailures >= _degradedFailureThreshold) {
      _enterDegradedMode(reason: 'stream-failure:$source');
    }
  }

  /// Schedule a post-reconnect recovery pass. Guards against duplicate
  /// recovery when both session and global event streams fire
  /// near-simultaneously after reconnection.
  void _schedulePostReconnectRecovery() {
    if (!_isForegroundActive ||
        _cellularDataSaverService.shouldSuppressBackgroundWork ||
        _postReconnectRecoveryInFlight) {
      return;
    }
    _postReconnectRecoveryInFlight = true;
    unawaited(_runPostReconnectRecovery());
  }

  /// Refresh pending interactions, active session view, and session list
  /// after SSE reconnection to recover events lost during the gap.
  /// The OpenCode server does NOT support Last-Event-ID replay.
  Future<void> _runPostReconnectRecovery() async {
    try {
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      if (_cellularDataSaverService.isAggressiveDataSaverActive) {
        AppLogger.info(
          'post_reconnect_recovery_start mode=aggressive-data-saver',
        );
        if (!_hasVisibleAggressiveDataSaverSession) {
          await _syncCellularDataSaverRealtimePolicy(
            reason: 'post-reconnect-aggressive-data-saver:not-visible',
          );
          AppLogger.info(
            'post_reconnect_recovery_complete mode=aggressive-data-saver visible=false',
          );
          return;
        }
        await _loadPendingInteractions(visibleSessionOnly: true);
        if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        await refreshActiveSessionView(
          reason: 'post-reconnect-aggressive-data-saver',
          includeStatus: false,
        );
        await _syncCellularDataSaverRealtimePolicy(
          reason: 'post-reconnect-aggressive-data-saver',
        );
        AppLogger.info(
          'post_reconnect_recovery_complete mode=aggressive-data-saver',
        );
        return;
      }
      AppLogger.info('post_reconnect_recovery_start');
      await _loadPendingInteractions();
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      await refreshActiveSessionView(includeStatus: true);
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      await loadSessions(preserveVisibleState: true);
      AppLogger.info('post_reconnect_recovery_complete');
    } finally {
      _postReconnectRecoveryInFlight = false;
    }
  }

  void _enterDegradedMode({required String reason}) {
    if (!_refreshlessRealtimeEnabled ||
        !_isForegroundActive ||
        _degradedMode ||
        _isInResumeGrace) {
      return;
    }
    _degradedMode = true;
    _sessionAttentionCoordinator.pauseMonitoring(
      SessionAttentionPauseReason.offline,
    );
    _degradedModeStartedAt = DateTime.now();
    _setSyncState(ChatSyncState.delayed, reason: 'degraded-enter:$reason');
    AppLogger.warn(
      'sync_degraded_entered reason=$reason interval=${_effectiveDegradedPollingInterval.inSeconds}s',
    );
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = Timer.periodic(_effectiveDegradedPollingInterval, (
      _,
    ) {
      unawaited(_runDegradedScopedSync(reason: 'degraded-periodic'));
    });
    unawaited(_runDegradedScopedSync(reason: 'degraded-enter'));
  }

  void _exitDegradedMode({required String reason}) {
    if (!_degradedMode) {
      return;
    }
    _degradedMode = false;
    final startedAt = _degradedModeStartedAt;
    _degradedModeStartedAt = null;
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = null;
    final durationSeconds = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inSeconds;
    AppLogger.info(
      'sync_degraded_recovered reason=$reason duration_s=${durationSeconds ?? 0}',
    );
  }

  Future<void> _loadPendingInteractions({
    bool visibleSessionOnly = false,
  }) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final restrictToVisible =
        visibleSessionOnly ||
        _cellularDataSaverService.isAggressiveDataSaverActive;
    if (restrictToVisible && !_hasVisibleAggressiveDataSaverSession) {
      _pendingPermissionsBySession = <String, List<ChatPermissionRequest>>{};
      _pendingQuestionsBySession = <String, List<ChatQuestionRequest>>{};
      _threadPermissionsVersion++;
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
      _notifyListeners();
      await _syncCellularDataSaverRealtimePolicy(
        reason: 'pending-interactions:not-visible',
      );
      return;
    }
    final directory = projectProvider.currentDirectory;

    final permissionsResult = await listPendingPermissions(
      directory: directory,
    );
    if (directory != projectProvider.currentDirectory) {
      return;
    }
    permissionsResult.fold(
      (failure) {
        AppLogger.warn('Failed to load pending permissions: $failure');
      },
      (permissions) {
        final grouped = <String, List<ChatPermissionRequest>>{};
        for (final item in permissions) {
          if (restrictToVisible &&
              !_isVisibleAggressiveSessionId(item.sessionId)) {
            continue;
          }
          if (_dismissedInteractionTombstones.contains(
            _permissionInteractionKey(item.id),
          )) {
            continue;
          }
          grouped
              .putIfAbsent(item.sessionId, () => <ChatPermissionRequest>[])
              .add(item);
        }
        _pendingPermissionsBySession = restrictToVisible
            ? grouped
            : _mergePendingPermissionsBySession(grouped);
        _threadPermissionsVersion++;
      },
    );

    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final questionsResult = await listPendingQuestions(directory: directory);
    if (directory != projectProvider.currentDirectory) {
      return;
    }
    questionsResult.fold(
      (failure) {
        AppLogger.warn('Failed to load pending questions: $failure');
      },
      (questions) {
        final grouped = <String, List<ChatQuestionRequest>>{};
        for (final item in questions) {
          if (restrictToVisible &&
              !_isVisibleAggressiveSessionId(item.sessionId)) {
            continue;
          }
          if (_dismissedInteractionTombstones.contains(
            _questionInteractionKey(item.id),
          )) {
            continue;
          }
          grouped
              .putIfAbsent(item.sessionId, () => <ChatQuestionRequest>[])
              .add(item);
        }
        // Prune submit-failure markers whose request IDs are no longer
        // present in the server's pending list, preventing the local
        // failure set from growing unbounded over a long-lived session.
        // Note: this uses the *server-provided* list, not the merged
        // snapshot, so locally-orphaned markers get reaped even if the
        // local merge retained them.
        final serverPendingIds = <String>{
          for (final list in grouped.values) ...list.map((q) => q.id),
        };
        _questionSubmitFailedRequestIds.removeWhere(
          (id) => !serverPendingIds.contains(id),
        );
        _pendingQuestionsBySession = restrictToVisible
            ? grouped
            : _mergePendingQuestionsBySession(grouped);
        _threadPermissionsVersion++;
      },
    );

    _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
    _notifyListeners();
    await _syncCellularDataSaverRealtimePolicy(reason: 'pending-interactions');
  }

  void _upsertSession(ChatSession session) {
    if (_isEphemeralTitleSession(session)) {
      _removeSessionById(session.id);
      return;
    }
    final existingIndex = _sessions.indexWhere((item) => item.id == session.id);
    if (existingIndex == -1) {
      _sessions.add(session);
      _threadPermissionsVersion++;
      _sortSessionsInPlace();
      return;
    }
    _sessions[existingIndex] = session;
    _threadPermissionsVersion++;
    _sortSessionsInPlace();
  }

  void _removeSessionById(String sessionId, {bool removePin = true}) {
    _dismissNotificationsForSession(sessionId);
    _sessions.removeWhere((item) => item.id == sessionId);
    final wasPinned =
        removePin &&
        _hasLoadedSessionsAuthoritatively &&
        _pinnedSessionIds.remove(sessionId);
    if (wasPinned) {
      final scopeId = _activePinnedSessionScopeId() ?? _resolveContextScopeId();
      _writeThroughPinnedSessionScope(
        serverId: _activeServerId,
        scopeId: scopeId,
        ids: _pinnedSessionIds,
      );
      unawaited(
        _persistPinnedSessionScope(
          serverId: _activeServerId,
          scopeId: scopeId,
          ids: _pinnedSessionIds,
        ),
      );
    }
    _removeSessionMessagesCache(sessionId);
    unawaited(_clearSessionMessagesSnapshotBestEffort(sessionId));
    _removeSessionSelectionOverride(sessionId);
    _pendingRenameTitleBySessionId.remove(sessionId);
    _autoTitleConsolidatedSessionIds.remove(sessionId);
    _autoTitleLastSignatureBySessionId.remove(sessionId);
    _autoTitleInFlightSessionIds.remove(sessionId);
    _autoTitleQueuedSessionIds.remove(sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.firstOrNull;
      _dismissNotificationsForSession(_currentSession?.id);
      _messages = <ChatMessage>[];
      _isLoadingOlderMessages = false;
      _hasMoreOldMessages = false;
      _messagesVersion++;
      _pendingLocalUserMessageIds.clear();
      _applySelectionPriorityForCurrentSession();
    }
    _sessionStatusById.remove(sessionId);
    _pendingPermissionsBySession.remove(sessionId);
    _pendingQuestionsBySession.remove(sessionId);
    _clearSessionUnreadCompletion(sessionId);
    _sessionErrorAttentionIds.remove(sessionId);
    _sessionChildrenById.remove(sessionId);
    _sessionTodoById.remove(sessionId);
    _sessionDiffById.remove(sessionId);
    _sessionDiffLoadedById.remove(sessionId);
    _sessionDiffErrorById.remove(sessionId);
    _threadPermissionsVersion++;
  }

  String _permissionInteractionKey(String requestId) {
    return 'permission:$requestId';
  }

  String _questionInteractionKey(String requestId) {
    return 'question:$requestId';
  }

  void _rememberDismissedInteractionTombstone(String key) {
    if (_dismissedInteractionTombstones.length >= 256) {
      _dismissedInteractionTombstones.remove(
        _dismissedInteractionTombstones.first,
      );
    }
    _dismissedInteractionTombstones.add(key);
  }

  Map<String, List<ChatPermissionRequest>> _mergePendingPermissionsBySession(
    Map<String, List<ChatPermissionRequest>> grouped,
  ) {
    final merged = <String, List<ChatPermissionRequest>>{};
    for (final entry in _pendingPermissionsBySession.entries) {
      final filtered = entry.value
          .where(
            (item) => !_dismissedInteractionTombstones.contains(
              _permissionInteractionKey(item.id),
            ),
          )
          .toList(growable: false);
      if (filtered.isNotEmpty) {
        merged[entry.key] = filtered;
      }
    }
    for (final entry in grouped.entries) {
      final byId = <String, ChatPermissionRequest>{
        for (final item in merged[entry.key] ?? const <ChatPermissionRequest>[])
          item.id: item,
      };
      for (final item in entry.value) {
        byId[item.id] = item;
      }
      if (byId.isEmpty) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = byId.values.toList(growable: false);
      }
    }
    return merged;
  }

  Map<String, List<ChatQuestionRequest>> _mergePendingQuestionsBySession(
    Map<String, List<ChatQuestionRequest>> grouped,
  ) {
    final merged = <String, List<ChatQuestionRequest>>{};
    for (final entry in _pendingQuestionsBySession.entries) {
      final filtered = entry.value
          .where(
            (item) => !_dismissedInteractionTombstones.contains(
              _questionInteractionKey(item.id),
            ),
          )
          .toList(growable: false);
      if (filtered.isNotEmpty) {
        merged[entry.key] = filtered;
      }
    }
    for (final entry in grouped.entries) {
      final byId = <String, ChatQuestionRequest>{
        for (final item in merged[entry.key] ?? const <ChatQuestionRequest>[])
          item.id: item,
      };
      for (final item in entry.value) {
        byId[item.id] = item;
      }
      if (byId.isEmpty) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = byId.values.toList(growable: false);
      }
    }
    return merged;
  }

  bool _isEphemeralTitleEvent(ChatEvent event) {
    final props = event.properties;
    final sessionId = _extractEventSessionId(props);
    if (sessionId != null &&
        ChatTitleGenerator.ephemeralSessionIds.contains(sessionId)) {
      return true;
    }
    // Fallback: check session title in event payload (covers race condition).
    final info = props['info'];
    if (info is Map<String, dynamic>) {
      final title = info['title'] as String?;
      if (title == ChatTitleGenerator.ephemeralSessionTitle) {
        return true;
      }
    }
    return false;
  }

  String? _extractEventSessionId(Map<String, dynamic> properties) {
    return extractEventSessionId(properties);
  }

  String? _sessionTitleForNotification(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final session = _sessionById(sessionId);
    if (session == null) {
      return null;
    }
    return SessionTitleFormatter.displayTitle(
      time: session.time,
      title: session.title,
    );
  }

  bool _isRootSessionId(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      return true;
    }
    final session = _sessionById(sessionId);
    final parentId = session?.parentId?.trim();
    return parentId == null || parentId.isEmpty;
  }

  String? _extractDirectoryFromEvent(ChatEvent event) {
    return extractEventDirectory(event.properties);
  }

  Future<void> _clearPersistedContextCache(String contextKey) async {
    final serverId = _serverIdFromContextKey(contextKey);
    final scopeId = _scopeIdFromContextKey(contextKey);
    if (serverId == null || scopeId == null) {
      return;
    }
    await localDataSource.clearChatContextCache(
      serverId: serverId,
      scopeId: scopeId,
    );
  }
}
