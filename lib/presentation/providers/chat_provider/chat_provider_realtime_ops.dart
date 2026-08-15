part of '../chat_provider.dart';

extension _ChatProviderRealtimeOps on ChatProvider {
  Future<void> _cancelActiveMessageSubscription({
    required String reason,
    bool invalidateGeneration = false,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final active = _messageSubscription;
    if (invalidateGeneration) {
      _messageStreamGeneration += 1;
    }
    _messageSubscription = null;
    _activeMessageStreamSessionId = null;
    await _cancelSubscriptionSafely(
      active,
      label: 'message stream ($reason)',
      timeout: timeout,
    );
  }

  void _setSyncState(ChatSyncState nextState, {String? reason}) {
    if (_syncState == nextState) {
      return;
    }
    _syncState = nextState;
    AppLogger.info(
      'sync_state_changed state=${nextState.name} reason=${reason ?? "-"}',
    );
    _notifyListeners();
  }

  bool _guardTransportForAction({required String actionLabel}) {
    final shouldBlock =
        _syncState == ChatSyncState.reconnecting &&
        _consecutiveRealtimeFailures > 0;
    if (!shouldBlock) {
      return true;
    }
    final message =
        L10nBridge.current?.chatRealtimeReconnectingServerTry ??
        'Reconnecting to the server. Try again in a moment.';
    AppLogger.warn('Blocked $actionLabel while realtime transport reconnects');
    _enqueueUiNotice(type: ChatUiNoticeType.serverError, message: message);
    _notifyListeners();
    return false;
  }

  void _startSyncHealthMonitor() {
    _syncHealthTimer?.cancel();
    _syncHealthTimer = Timer.periodic(_effectiveSyncHealthCheckInterval, (_) {
      _evaluateSyncHealth();
    });
  }

  void _evaluateSyncHealth() {
    if (!_isForegroundActive) {
      return;
    }
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    if (_cellularDataSaverService.isDataSaverActive &&
        _idleRealtimePausedForDataSaver) {
      unawaited(
        _runAutomaticForegroundSyncForDataSaver(reason: 'sync-health-tick'),
      );
      return;
    }
    if (!_cellularDataSaverService.isAggressiveDataSaverActive) {
      unawaited(_syncSelectionFromRemote(reason: 'sync-health-tick'));
      _attemptPendingRemoteSelectionSync(reason: 'sync-health-tick');
    }
    if (!_refreshlessRealtimeEnabled) {
      return;
    }
    final signalAt = _lastRealtimeSignalAt;
    if (signalAt == null) {
      return;
    }
    final stale =
        DateTime.now().difference(signalAt) >
        _effectiveSyncSignalStaleThreshold;
    if (!stale) {
      return;
    }
    if (_isInResumeGrace) {
      AppLogger.info('sync_resume_grace_suppressed reason=stale-signal');
      return;
    }
    _setSyncState(ChatSyncState.delayed, reason: 'stale-signal');
    _enterDegradedMode(reason: 'stale-signal');
  }

  Future<void> _runDegradedScopedSync({required String reason}) async {
    if (!_degradedMode || !_isForegroundActive) {
      return;
    }
    if (_cellularDataSaverService.isDataSaverActive) {
      await _runAutomaticForegroundSyncForDataSaver(reason: 'degraded-$reason');
      return;
    }
    AppLogger.info('sync_degraded_poll_tick reason=$reason');
    await loadSessions();
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await refreshActiveSessionView(reason: 'degraded-sync:$reason');
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    // Degraded polling re-fetches messages/sessions but used to skip pending
    // interactions: a question asked while the SSE stream was silently dead
    // stayed hidden forever (issue #143).
    await _loadPendingInteractions();
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    await _syncSelectionFromRemote(
      reason: 'degraded-sync:$reason',
      force: true,
    );
  }

  Future<void> _resumeRealtimeAfterForeground() async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      await _stopRealtimeEventSubscriptions(reason: 'background-data-saver');
      return;
    }
    if (_cellularDataSaverService.isDataSaverActive) {
      await _syncCellularDataSaverRealtimePolicy(reason: 'foreground-resume');
      await _runAutomaticForegroundSyncForDataSaver(
        reason: 'foreground-resume',
        force: true,
      );
      return;
    }
    if (_foregroundResumeReconcileInFlight) {
      AppLogger.info('sync_resume_reconcile_skip reason=in-flight');
      return;
    }
    _foregroundResumeReconcileInFlight = true;

    AppLogger.info('sync_resume_reconcile_start');
    try {
      await _startRealtimeEventSubscription();
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) return;
      await _loadPendingInteractions();
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) return;
      await loadSessions();
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) return;
      await refreshActiveSessionView(reason: 'foreground-resume');
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) return;
      final currentSessionId = _currentSession?.id;
      if (currentSessionId != null) {
        await loadSessionInsights(currentSessionId, silent: true);
      }
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) return;
      await _syncSelectionFromRemote(reason: 'foreground-resume', force: true);
      AppLogger.info('sync_resume_reconcile_complete');
    } finally {
      _foregroundResumeReconcileInFlight = false;
    }
  }

  Future<void> _startRealtimeEventSubscription() async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    if (_realtimeSubscriptionRestartInFlight) {
      _realtimeSubscriptionRestartQueued = true;
      AppLogger.info('sync_subscription_restart_queued');
      return;
    }

    _realtimeSubscriptionRestartInFlight = true;
    try {
      do {
        _realtimeSubscriptionRestartQueued = false;

        final generation = ++_eventStreamGeneration;
        final previousSubscription = _eventSubscription;
        final previousGlobalSubscription = _globalEventSubscription;
        _eventSubscription = null;
        _globalEventSubscription = null;
        await _cancelSubscriptionSafely(
          previousSubscription,
          label: 'realtime event',
        );
        await _cancelSubscriptionSafely(
          previousGlobalSubscription,
          label: 'global event',
        );
        if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        if (!_isForegroundActive) {
          AppLogger.info('sync_subscription_start_skip reason=background');
          return;
        }
        if (!_isInResumeGrace) {
          _setSyncState(
            ChatSyncState.reconnecting,
            reason: 'subscription-start',
          );
        }
        _startSyncHealthMonitor();

        final directory = projectProvider.currentDirectory;
        final newSubscription = watchChatEvents(directory: directory).listen(
          (result) {
            if (generation != _eventStreamGeneration) {
              return;
            }
            result.fold(
              (failure) {
                _handleRealtimeStreamFailure(
                  source: 'session-stream-failure',
                  error: failure,
                );
              },
              (event) {
                _markRealtimeSignal(
                  source: 'session-stream',
                  directory: directory ?? '',
                );
                _applyChatEvent(event);
              },
            );
          },
          onError: (error) {
            if (generation != _eventStreamGeneration) {
              return;
            }
            _handleRealtimeStreamFailure(
              source: 'session-stream-exception',
              error: error,
            );
          },
          onDone: () {
            if (generation != _eventStreamGeneration) {
              return;
            }
            _handleRealtimeStreamFailure(source: 'session-stream-done');
          },
        );

        if (generation != _eventStreamGeneration) {
          await _cancelSubscriptionSafely(
            newSubscription,
            label: 'realtime event (stale generation)',
          );
          continue;
        }

        _eventSubscription = newSubscription;

        if (_cellularDataSaverService.isAggressiveDataSaverActive) {
          AppLogger.info('data_saver_aggressive_global_stream_paused');
          continue;
        }

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
                      extractEventDirectory(event.properties) ??
                      directory ??
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
          continue;
        }
        _globalEventSubscription = globalSubscription;
      } while (_realtimeSubscriptionRestartQueued);
    } finally {
      _realtimeSubscriptionRestartInFlight = false;
    }
  }
}
