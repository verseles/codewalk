part of '../chat_provider.dart';

extension _ChatProviderSessionOps on ChatProvider {
  Future<void> _switchContext({
    required String reason,
    bool waitForRevalidation = true,
    String? newlyOpenedDirectory,
  }) async {
    titleGenerator?.cancelPendingWaiters();
    // Flush any pending debounced selection persistence for the old
    // context before switching, otherwise the timer could capture the
    // new context's server/scope and persist stale data under the
    // wrong key (issue #161).
    await flushSelectionPersistence();
    final useFastProjectTransition =
        reason == 'project' && !waitForRevalidation;
    _storeCurrentContextSnapshot();

    final contextSwitchFetchId = ++_providersFetchId;
    _sessionsFetchId += 1;
    final contextSwitchSelectionGeneration = _sessionSelectionGeneration;
    _messagesFetchId += 1;
    _eventStreamGeneration += 1;
    Future<void>? fastRealtimeCancellation;
    if (useFastProjectTransition) {
      final eventSubscription = _eventSubscription;
      final globalEventSubscription = _globalEventSubscription;
      _eventSubscription = null;
      _globalEventSubscription = null;
      fastRealtimeCancellation = Future.wait<void>(<Future<void>>[
        _cancelActiveMessageSubscription(
          reason: 'context-switch',
          invalidateGeneration: true,
          timeout: const Duration(milliseconds: 100),
        ),
        _cancelSubscriptionSafely(
          eventSubscription,
          label: 'realtime event',
          timeout: const Duration(milliseconds: 100),
        ),
        _cancelSubscriptionSafely(
          globalEventSubscription,
          label: 'global event',
          timeout: const Duration(milliseconds: 100),
        ),
      ], eagerError: false);
    } else {
      await _cancelActiveMessageSubscription(
        reason: 'context-switch',
        invalidateGeneration: true,
      );
      final eventSubscription = _eventSubscription;
      final globalEventSubscription = _globalEventSubscription;
      _eventSubscription = null;
      _globalEventSubscription = null;
      await _cancelSubscriptionSafely(
        eventSubscription,
        label: 'realtime event',
      );
      await _cancelSubscriptionSafely(
        globalEventSubscription,
        label: 'global event',
      );
    }
    _consecutiveRealtimeFailures = 0;
    _dismissedInteractionTombstones.clear();
    _dedupeNextDeltaFieldKeys.clear();
    _recentRemovedMessageKeys.clear();
    _recentRemovedMessageKeySet.clear();
    _recentRemovedPartKeys.clear();
    _recentRemovedPartKeySet.clear();
    _hasLoadedSessionsAuthoritatively = false;
    _lastRealtimeSignalAt = null;
    _degradedMode = false;
    _degradedModeStartedAt = null;
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _isInResumeGrace = false;
    _foregroundResumeSyncTimer?.cancel();
    _foregroundResumeSyncTimer = null;
    _foregroundResumeSyncCycleCount = 0;
    _isForegroundResumeSyncing = false;
    _recoverableSyncAlertEscalated = false;
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = null;
    _pendingQuestionsRetryTimer?.cancel();
    _pendingQuestionsRetryAttempts = 0;
    if (_refreshlessRealtimeEnabled) {
      _setSyncState(ChatSyncState.reconnecting, reason: 'context-switch');
    }

    final storedServerId = await localDataSource.getActiveServerId();
    if (contextSwitchFetchId != _providersFetchId) {
      return;
    }
    final serverId = storedServerId == null || storedServerId.isEmpty
        ? 'legacy'
        : storedServerId;
    _activeServerId = serverId;
    final nextScope = _resolveContextScopeId();
    final nextContextKey = _composeContextKey(serverId, nextScope);
    final hadContextSnapshot = _contextSnapshots.containsKey(nextContextKey);
    _sessionTabBootstrapDirectory = reason == 'project'
        ? normalizeOptionalFilePath(newlyOpenedDirectory)
        : null;
    _invalidateSessionTabReconcileCache();
    _sessionTabBootstrapGeneration += 1;
    _newChatDraftGeneration += 1;
    _lazySessionBootstrapTask = null;
    _activeContextKey = nextContextKey;
    _currentProjectId = projectProvider.currentProjectId;
    _restoreContextSnapshot(nextContextKey);
    if (!useFastProjectTransition) {
      await _ensureSessionTabsLoaded(serverId: serverId);
      if (!_isProviderInitializationCurrent(
        fetchId: contextSwitchFetchId,
        contextKey: nextContextKey,
      )) {
        return;
      }
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
    }

    _errorMessage = null;
    _isLoadingSessionInsights = false;
    _sessionInsightsError = null;
    _isRespondingInteraction = false;
    _providersRefreshTask = null;
    _providersRefreshState = ChatProvidersRefreshState.idle;
    _providersRefreshErrorMessage = null;
    _shortcutCycleStateByDomain.clear();
    _lastSyncedRemoteModelKey = null;
    _lastSyncedRemoteAgentName = null;
    _lastSyncedRemoteVariantKey = null;
    _lastSyncedRemoteSessionOverridesSignature = null;
    _pendingRemoteSelectionSync = false;
    _pendingRemoteSelectionSyncSince = null;
    _lastRemoteSelectionSyncAt = null;
    _remoteSelectionSyncInFlight = false;
    _remoteSelectionSyncGeneration += 1;
    _selectionSyncTransactionPhase = _SelectionSyncTransactionPhase.idle;
    _autoTitleConsolidatedSessionIds.clear();
    _autoTitleLastSignatureBySessionId.clear();
    _autoTitleInFlightSessionIds.clear();
    _autoTitleQueuedSessionIds.clear();
    if (useFastProjectTransition) {
      _applySelectionPriorityForCurrentSession();
      _state = _sessions.isEmpty ? ChatState.initial : ChatState.loaded;
      _notifyListeners();
      unawaited(
        fastRealtimeCancellation?.catchError((Object error, StackTrace stack) {
              AppLogger.warn(
                'Background realtime cancellation failed during context switch',
                error: error,
                stackTrace: stack,
              );
            }) ??
            Future<void>.value(),
      );
      unawaited(
        _finishFastProjectScopeChanged(
          fetchId: contextSwitchFetchId,
          serverId: serverId,
          scopeId: nextScope,
          contextKey: nextContextKey,
          hadContextSnapshot: hadContextSnapshot,
          selectionGeneration: contextSwitchSelectionGeneration,
        ),
      );
      return;
    }
    if (!hadContextSnapshot || (_providers.isEmpty && _agents.isEmpty)) {
      await _restoreProviderCatalogSnapshot(
        serverId: serverId,
        scopeId: nextScope,
        notify: false,
        fetchId: contextSwitchFetchId,
        contextKey: nextContextKey,
      );
      if (!_isProviderInitializationCurrent(
        fetchId: contextSwitchFetchId,
        contextKey: nextContextKey,
      )) {
        return;
      }
    }
    _applySelectionPriorityForCurrentSession();
    _state = _sessions.isEmpty ? ChatState.initial : ChatState.loaded;
    _notifyListeners();
    AppLogger.info(
      'Switching chat context reason=$reason context=$_activeContextKey',
    );
    final providersRefresh = initializeProviders().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.warn(
        'Background providers refresh failed during context switch',
        error: error,
        stackTrace: stackTrace,
      );
    });
    if (reason == 'server') {
      await providersRefresh;
    } else {
      unawaited(providersRefresh);
    }

    final contextMarkedDirty = _dirtyContextKeys.remove(nextContextKey);
    if (contextMarkedDirty || _sessions.isEmpty) {
      await loadSessions();
      return;
    }

    await loadLastSession(serverId: serverId, scopeId: nextScope);
  }

  Future<void> _finishFastProjectScopeChanged({
    required int fetchId,
    required String serverId,
    required String scopeId,
    required String contextKey,
    required bool hadContextSnapshot,
    required int selectionGeneration,
  }) async {
    try {
      await _ensureSessionTabsLoaded(serverId: serverId);
      if (_sessionTabsDisposed || _activeContextKey != contextKey) {
        return;
      }
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);

      if (!hadContextSnapshot || (_providers.isEmpty && _agents.isEmpty)) {
        await _restoreProviderCatalogSnapshot(
          serverId: serverId,
          scopeId: scopeId,
          notify: false,
          fetchId: fetchId,
          contextKey: contextKey,
        );
        if (_sessionTabsDisposed || _activeContextKey != contextKey) {
          return;
        }
      }
      if (_sessionTabsDisposed || _activeContextKey != contextKey) {
        return;
      }
      _applySelectionPriorityForCurrentSession();
      if (_currentSession == null) {
        _state = _sessions.isEmpty ? ChatState.initial : ChatState.loaded;
      }
      _notifyListeners();

      AppLogger.info(
        'Switching chat context reason=project context=$_activeContextKey',
      );
      final providersRefresh = initializeProviders().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.warn(
          'Background providers refresh failed during context switch',
          error: error,
          stackTrace: stackTrace,
        );
      });
      unawaited(providersRefresh);

      if (_activeContextKey != contextKey) {
        return;
      }
      final contextMarkedDirty = _dirtyContextKeys.remove(contextKey);
      if (contextMarkedDirty || _sessions.isEmpty) {
        unawaited(loadSessions(preserveVisibleState: true));
        return;
      }
      unawaited(
        loadLastSession(
          serverId: serverId,
          scopeId: scopeId,
          expectedSelectionGeneration: selectionGeneration,
          expectedContextKey: contextKey,
        ),
      );
      unawaited(loadSessions(preserveVisibleState: true));
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Fast project context completion failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
