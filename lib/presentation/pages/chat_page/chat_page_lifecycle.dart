part of '../chat_page.dart';

extension _ChatPageLifecycle on _ChatPageState {
  String _foregroundPolicySettingsSignature(ExperienceSettings settings) {
    return '${shouldRunAndroidBackgroundAlerts(settings)}|'
        '${settings.desktopCloseBehavior.name}|'
        '${settings.keepMobileRealtimeForShortPeriod}';
  }

  void _handleSettingsChanged() {
    final settings =
        _settingsProvider?.settings ?? ExperienceSettings.defaults();
    final pendingPostOnboardingTour = settings.pendingPostOnboardingChatTour;
    if (_lastEditorAutosaveEnabled != settings.editorAutosaveEnabled) {
      _lastEditorAutosaveEnabled = settings.editorAutosaveEnabled;
      _syncEditorAutosaveForActiveContext(
        enabled: settings.editorAutosaveEnabled,
      );
    }
    if (pendingPostOnboardingTour != _lastPendingPostOnboardingChatTour) {
      _lastPendingPostOnboardingChatTour = pendingPostOnboardingTour;
      _queuedPendingPostOnboardingTourAutoStart = pendingPostOnboardingTour;
    }
    final nextForegroundPolicySignature = _foregroundPolicySettingsSignature(
      settings,
    );
    if (_lastForegroundPolicySettingsSignature !=
        nextForegroundPolicySignature) {
      unawaited(_applyForegroundPolicy(reason: 'settings-changed'));
      _lastForegroundPolicySettingsSignature = nextForegroundPolicySignature;
    }
    _autoApprovePermissionCooldownIds.clear();
    _pendingFinalAssistantRevealMessageId = null;
    _finalAssistantRevealScheduled = false;
    _pendingFinalAssistantRevealAttempts = 0;
    final chatProvider = _chatProvider;
    if (chatProvider != null &&
        !chatProvider.isCurrentSessionActivelyResponding) {
      _shouldRevealFinalAssistantOnCompletion = false;
    }
    _scheduleAutoApprovePermissionDrain(reason: 'settings-changed');
    unawaited(
      _syncBackgroundPermissionAutoApproveContext(reason: 'settings-changed'),
    );
    _flushPendingPostOnboardingTourAutoStart();
    if (chatProvider != null) {
      _syncSessionTabsGestureHint(chatProvider);
    }
  }

  void _handleChatProviderChanged() {
    if (AppLogger.performanceLoggingEnabled) {
      AppLogger.measurePerformance<void>(
        'chat_provider_changed',
        _handleChatProviderChangedBody,
        tags: const <String>{'chat:settlement', 'ui:provider'},
        context: <String, Object?>{
          'messageCount': _chatProvider?.messages.length ?? 0,
          'sessionHash': AppLogger.safeContextId(
            _chatProvider?.currentSession?.id,
          ),
        },
      );
      return;
    }
    _handleChatProviderChangedBody();
  }

  void _handleChatProviderChangedBody() {
    final provider = _chatProvider;
    if (provider != null) {
      _syncSessionTabsGestureHint(provider);
      _syncSessionScrollState(provider);
      _syncPassiveProviderMessageIndicator(provider);
      _syncResponseViewportPolicy(provider);
      _syncChatRouteActivity(provider);
      _consumePendingUiNotice(provider);
      _consumePendingHistoryComposerSync(provider);
      _consumeRejectedDraft(provider);
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          _sessionAttentionOverlayController != null) {
        _sessionAttentionOverlayRefreshTimer?.cancel();
        _sessionAttentionOverlayRefreshTimer = Timer(
          const Duration(milliseconds: 600),
          () => unawaited(
            _sessionAttentionOverlayController!.refresh(
              activeServerId: _appProvider?.activeServerId,
            ),
          ),
        );
      }
    }
    _reconcileTimelineSearchForProviderChanged();
    _scheduleAutoApprovePermissionDrain(reason: 'chat-provider-changed');
    unawaited(
      _syncBackgroundPermissionAutoApproveContext(
        reason: 'chat-provider-changed',
      ),
    );
  }

  Future<void> _clearBackgroundPermissionAutoApproveContext({
    required String reason,
    String? serverId,
  }) async {
    if (!_isMobileRuntime) {
      return;
    }

    final normalizedServerId =
        (serverId ??
                _chatProvider?.activeServerId ??
                _appProvider?.activeServerId)
            ?.trim() ??
        '';
    if (normalizedServerId.isEmpty) {
      _backgroundPermissionAutoApproveContextSignature = 'clear:-';
      return;
    }

    final clearSignature = 'clear:$normalizedServerId';
    if (_backgroundPermissionAutoApproveContextSignature == clearSignature &&
        !_backgroundPermissionAutoApproveContextMayBeEnabled) {
      return;
    }
    AppLogger.debug(
      'background_permission_auto_approve_context reason=$reason action=clear server=$normalizedServerId',
    );
    try {
      await AndroidBackgroundAlertWorker.clearPermissionAutoApproveContext(
        serverId: normalizedServerId,
      );
      _backgroundPermissionAutoApproveContextSignature = clearSignature;
      _backgroundPermissionAutoApproveContextMayBeEnabled = false;
    } catch (_) {
      if (_backgroundPermissionAutoApproveContextSignature == clearSignature) {
        _backgroundPermissionAutoApproveContextSignature = null;
      }
      rethrow;
    }
  }

  void _clearBackgroundPermissionAutoApproveContextBestEffort({
    required String reason,
    String? serverId,
  }) {
    final mutationGeneration = ++_backgroundPermissionContextMutationGeneration;
    unawaited(
      _enqueueBackgroundPermissionContextClear(
        reason: reason,
        serverId: serverId,
        expectedMutationGeneration: mutationGeneration,
      ).catchError((Object error, StackTrace stackTrace) {
        AppLogger.warn(
          'Failed to clear background permission auto-approve context',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<void> _enqueueBackgroundPermissionContextClear({
    required String reason,
    String? serverId,
    int? expectedGeneration,
    int? expectedMutationGeneration,
  }) {
    return _enqueueBackgroundPermissionContextMutation(
      reason: reason,
      expectedGeneration: expectedGeneration,
      expectedMutationGeneration: expectedMutationGeneration,
      mutation: () => _clearBackgroundPermissionAutoApproveContext(
        reason: reason,
        serverId: serverId,
      ),
    );
  }

  Future<void> _enqueueBackgroundPermissionContextMutation({
    required String reason,
    required Future<void> Function() mutation,
    int? expectedGeneration,
    int? expectedMutationGeneration,
  }) {
    final previous = _backgroundPermissionContextMutationQueue;
    final task = previous
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.warn(
            'Previous background permission context mutation failed',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .then((_) async {
          if (expectedGeneration != null &&
              expectedGeneration != _backgroundPermissionContextGeneration) {
            return;
          }
          if (expectedMutationGeneration != null &&
              expectedMutationGeneration !=
                  _backgroundPermissionContextMutationGeneration) {
            return;
          }
          await mutation();
        });
    _backgroundPermissionContextMutationQueue = task.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.warn(
        'Failed background permission context mutation reason=$reason',
        error: error,
        stackTrace: stackTrace,
      );
    });
    return task;
  }

  Future<void> _disableBackgroundPermissionAutoApproveContext({
    required String reason,
    required int generation,
    required int mutationGeneration,
  }) async {
    if (!_isMobileRuntime) {
      return;
    }
    if (_isAppInForeground) {
      return;
    }
    final settingsProvider = _settingsProvider;
    if (settingsProvider != null &&
        settingsProvider.initialized &&
        (!settingsProvider.composerAutoApprovePermissions ||
            !shouldRunAndroidBackgroundAlerts(settingsProvider.settings))) {
      return;
    }
    final serverId =
        (_chatProvider?.activeServerId ?? _appProvider?.activeServerId)
            ?.trim() ??
        '';
    if (serverId.isEmpty) {
      return;
    }
    if (!_backgroundPermissionAutoApproveContextMayBeEnabled) {
      return;
    }
    await _enqueueBackgroundPermissionContextMutation(
      reason: reason,
      expectedGeneration: generation,
      expectedMutationGeneration: mutationGeneration,
      mutation: () =>
          AndroidBackgroundAlertWorker.disablePermissionAutoApproveContext(
            serverId: serverId,
          ),
    );
    if (generation == _backgroundPermissionContextGeneration &&
        mutationGeneration == _backgroundPermissionContextMutationGeneration) {
      _backgroundPermissionAutoApproveContextMayBeEnabled = false;
    }
  }

  Future<void> _refreshBackgroundPermissionAutoApproveContextState() async {
    if (!_isMobileRuntime) {
      _backgroundPermissionAutoApproveContextMayBeEnabled = false;
      return;
    }
    final generation = _backgroundPermissionContextGeneration;
    final mutationGeneration = _backgroundPermissionContextMutationGeneration;
    final signature = _backgroundPermissionAutoApproveContextSignature;
    final serverId =
        (_chatProvider?.activeServerId ?? _appProvider?.activeServerId)
            ?.trim() ??
        '';
    final enabled =
        serverId.isNotEmpty &&
        await AndroidBackgroundAlertWorker.hasEnabledPermissionAutoApproveContext(
          serverId: serverId,
        );
    if (!mounted ||
        generation != _backgroundPermissionContextGeneration ||
        mutationGeneration != _backgroundPermissionContextMutationGeneration ||
        signature != _backgroundPermissionAutoApproveContextSignature) {
      return;
    }
    _backgroundPermissionAutoApproveContextMayBeEnabled = enabled;
  }

  String _autoApprovePermissionReply(ChatPermissionRequest request) {
    return permissionAutoApproveReplyForRequest(request);
  }

  Future<void> _syncBackgroundPermissionAutoApproveContext({
    required String reason,
  }) async {
    if (!_isMobileRuntime) {
      return;
    }
    if (_isProjectScopeTransitioning ||
        _backgroundPermissionContextClearPendingGeneration != null) {
      return;
    }
    final generation = _backgroundPermissionContextGeneration;
    final mutationGeneration = ++_backgroundPermissionContextMutationGeneration;

    final chatProvider = _chatProvider;
    final settingsProvider = _settingsProvider;
    final serverId = chatProvider?.activeServerId.trim() ?? '';
    Future<void> clearContext() async {
      await _enqueueBackgroundPermissionContextClear(
        reason: reason,
        serverId: serverId,
        expectedGeneration: generation,
        expectedMutationGeneration: mutationGeneration,
      );
    }

    if (!mounted || chatProvider == null || settingsProvider == null) {
      await clearContext();
      return;
    }
    if (!settingsProvider.initialized) {
      await clearContext();
      return;
    }
    if (!_isChatScreenActive()) {
      await clearContext();
      return;
    }
    if (!settingsProvider.composerAutoApprovePermissions) {
      await clearContext();
      return;
    }
    if (!shouldRunAndroidBackgroundAlerts(settingsProvider.settings)) {
      await clearContext();
      return;
    }
    if (_isAppInForeground) {
      await clearContext();
      return;
    }

    final currentSessionId = chatProvider.currentSession?.id.trim() ?? '';
    final projectProvider = context.read<ProjectProvider>();
    final scopeId = projectProvider.currentScopeId.trim();
    final threadSessionIds = chatProvider.currentThreadSessionIds;
    if (serverId.isEmpty ||
        scopeId.isEmpty ||
        currentSessionId.isEmpty ||
        threadSessionIds.isEmpty) {
      await clearContext();
      return;
    }

    final contextData = PermissionAutoApproveBackgroundContext(
      serverId: serverId,
      scopeId: scopeId,
      currentSessionId: currentSessionId,
      threadSessionIds: threadSessionIds,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      directory: projectProvider.currentDirectory,
    );
    if (!contextData.isValid) {
      await clearContext();
      return;
    }
    if (_backgroundPermissionAutoApproveContextSignature ==
        contextData.signature) {
      return;
    }
    AppLogger.debug(
      'background_permission_auto_approve_context reason=$reason action=prime server=$serverId session=$currentSessionId scope=$scopeId sessions=${threadSessionIds.length}',
    );
    try {
      await _enqueueBackgroundPermissionContextMutation(
        reason: reason,
        expectedGeneration: generation,
        expectedMutationGeneration: mutationGeneration,
        mutation: () =>
            AndroidBackgroundAlertWorker.primePermissionAutoApproveContext(
              context: contextData,
              isCurrent: () =>
                  generation == _backgroundPermissionContextGeneration &&
                  mutationGeneration ==
                      _backgroundPermissionContextMutationGeneration,
            ),
      );
      if (generation == _backgroundPermissionContextGeneration &&
          mutationGeneration ==
              _backgroundPermissionContextMutationGeneration) {
        _backgroundPermissionAutoApproveContextSignature =
            contextData.signature;
        _backgroundPermissionAutoApproveContextMayBeEnabled = true;
      }
    } catch (_) {
      if (_backgroundPermissionAutoApproveContextSignature ==
          contextData.signature) {
        _backgroundPermissionAutoApproveContextSignature = null;
      }
      rethrow;
    }
  }

  void _scheduleAutoApprovePermissionDrain({required String reason}) {
    final chatProvider = _chatProvider;
    final settingsProvider = _settingsProvider;
    if (!mounted || chatProvider == null || settingsProvider == null) {
      return;
    }

    final visibleRequestIds = chatProvider.currentThreadPermissionRequests
        .map((request) => request.id)
        .toSet();
    _autoApprovePermissionCooldownIds.removeWhere(
      (requestId) => !visibleRequestIds.contains(requestId),
    );
    if (visibleRequestIds.isEmpty) {
      return;
    }
    if (!settingsProvider.initialized) {
      return;
    }
    if (!settingsProvider.composerAutoApprovePermissions) {
      return;
    }
    if (_autoApprovePermissionDrainScheduled) {
      return;
    }
    _autoApprovePermissionDrainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoApprovePermissionDrainScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_drainAutoApprovePermissions(reason: reason));
    });
  }

  Future<void> _drainAutoApprovePermissions({required String reason}) async {
    if (_autoApprovePermissionDrainRunning) {
      _autoApprovePermissionDrainQueued = true;
      return;
    }

    _autoApprovePermissionDrainRunning = true;
    try {
      do {
        _autoApprovePermissionDrainQueued = false;
        final chatProvider = _chatProvider;
        final settingsProvider = _settingsProvider;
        if (!mounted || chatProvider == null || settingsProvider == null) {
          return;
        }
        if (!settingsProvider.initialized) {
          return;
        }
        if (!settingsProvider.composerAutoApprovePermissions) {
          return;
        }

        while (mounted) {
          if (chatProvider.isRespondingInteraction) {
            break;
          }

          final nextRequest = chatProvider.currentThreadPermissionRequests
              .where(
                (request) =>
                    !_autoApprovePermissionCooldownIds.contains(request.id),
              )
              .firstOrNull;
          if (nextRequest == null) {
            break;
          }

          final autoReply = _autoApprovePermissionReply(nextRequest);
          AppLogger.info(
            'Auto-approving permission request=${nextRequest.id} session=${nextRequest.sessionId} reply=$autoReply reason=$reason',
          );
          try {
            await chatProvider.respondPermissionRequest(
              sessionId: nextRequest.sessionId,
              requestId: nextRequest.id,
              reply: autoReply,
            );
          } catch (error, stackTrace) {
            AppLogger.error(
              'Failed to auto-approve permission request=${nextRequest.id}',
              error: error,
              stackTrace: stackTrace,
            );
            _autoApprovePermissionCooldownIds.add(nextRequest.id);
            break;
          }
          if (!mounted) {
            return;
          }

          final stillPending = chatProvider.currentThreadPermissionRequests.any(
            (request) => request.id == nextRequest.id,
          );
          if (stillPending) {
            _autoApprovePermissionCooldownIds.add(nextRequest.id);
            break;
          }
          _autoApprovePermissionCooldownIds.remove(nextRequest.id);
        }
      } while (_autoApprovePermissionDrainQueued);
    } finally {
      _autoApprovePermissionDrainRunning = false;
    }
  }

  Future<void> _applyForegroundPolicy({
    required String reason,
    bool forceResume = false,
  }) async {
    final provider = _chatProvider;
    if (provider == null) {
      return;
    }

    final settingsProvider = _settingsProvider;

    void scheduleAndroidProbe(Duration delay) {
      if (!_isMobileRuntime) {
        return;
      }
      unawaited(
        AndroidBackgroundAlertWorker.scheduleProbe(initialDelay: delay),
      );
    }

    void syncAndroidForegroundMonitor({
      required bool enabled,
      required int activeSessionCount,
    }) {
      if (!_isMobileRuntime) {
        return;
      }
      unawaited(
        AndroidForegroundMonitorService.sync(
          enabled: enabled,
          activeSessionCount: activeSessionCount,
        ),
      );
    }

    final statusById = <String, String>{};
    for (final entry in provider.sessionStatusById.entries) {
      final sessionId = entry.key.trim();
      if (sessionId.isEmpty) {
        continue;
      }
      statusById[sessionId] = entry.value.type.name;
    }
    final activeSessionCount = countActiveBackgroundSessions(statusById);
    final hasActiveSession = activeSessionCount > 0;
    final backgroundAlertsEnabled =
        _isMobileRuntime &&
        shouldRunAndroidBackgroundAlerts(
          settingsProvider?.settings ?? ExperienceSettings.defaults(),
        );

    void primeAndroidBackgroundSnapshot() {
      if (!_isMobileRuntime) {
        return;
      }

      final serverId = provider.activeServerId.trim();
      if (serverId.isEmpty) {
        return;
      }
      if (!hasActiveSession) {
        return;
      }

      final sessionUpdatedAtById = <String, int>{};
      final sessionTitleById = <String, String>{};
      for (final session in provider.sessions) {
        final sessionId = session.id.trim();
        if (sessionId.isEmpty) {
          continue;
        }

        final title = session.title?.trim();
        if (title != null && title.isNotEmpty) {
          sessionTitleById[sessionId] = title;
        }

        final updatedAt = session.time.millisecondsSinceEpoch;
        if (updatedAt > 0) {
          sessionUpdatedAtById[sessionId] = updatedAt;
        }
      }

      unawaited(
        AndroidBackgroundAlertWorker.primeSnapshot(
          serverId: serverId,
          sessionStatusById: statusById,
          sessionUpdatedAtById: sessionUpdatedAtById,
          sessionTitleById: sessionTitleById,
        ),
      );
    }

    _backgroundRealtimeHoldTimer?.cancel();
    _backgroundRealtimeHoldTimer = null;

    if (_isAppInForeground) {
      AppLogger.debug('foreground_policy reason=$reason mode=active');
      syncAndroidForegroundMonitor(enabled: false, activeSessionCount: 0);
      await provider.setForegroundActive(true, forceResume: forceResume);
      return;
    }

    if (!backgroundAlertsEnabled) {
      AppLogger.debug(
        'foreground_policy reason=$reason mode=background-disabled',
      );
      syncAndroidForegroundMonitor(enabled: false, activeSessionCount: 0);
      await provider.setForegroundActive(false);
      return;
    }

    primeAndroidBackgroundSnapshot();

    final keepDesktopRealtime =
        _isDesktopRuntime &&
        (settingsProvider?.desktopCloseBehavior != DesktopCloseBehavior.close);
    if (keepDesktopRealtime) {
      AppLogger.debug('foreground_policy reason=$reason mode=desktop-tray');
      await provider.setForegroundActive(true, forceResume: forceResume);
      return;
    }

    final keepMobileRealtimeTemporarily =
        _isMobileRuntime &&
        (settingsProvider?.keepMobileRealtimeForShortPeriod ?? true) &&
        provider.isCurrentSessionActivelyResponding;
    if (keepMobileRealtimeTemporarily) {
      AppLogger.debug('foreground_policy reason=$reason mode=mobile-hold');
      syncAndroidForegroundMonitor(
        enabled: hasActiveSession,
        activeSessionCount: activeSessionCount,
      );
      await provider.setForegroundActive(true, forceResume: forceResume);
      if (hasActiveSession) {
        scheduleAndroidProbe(
          AndroidBackgroundAlertWorker.activeSessionProbeInterval,
        );
      }
      _backgroundRealtimeHoldTimer = Timer(
        _ChatPageState._mobileBackgroundRealtimeHoldDuration,
        () {
          if (!mounted || _isAppInForeground) {
            return;
          }
          AppLogger.debug('foreground_policy mode=mobile-hold-expired');
          syncAndroidForegroundMonitor(enabled: false, activeSessionCount: 0);
          unawaited(provider.setForegroundActive(false));
        },
      );
      return;
    }

    AppLogger.debug('foreground_policy reason=$reason mode=paused');
    syncAndroidForegroundMonitor(enabled: false, activeSessionCount: 0);
    await provider.setForegroundActive(false);
    if (hasActiveSession) {
      scheduleAndroidProbe(
        AndroidBackgroundAlertWorker.activeSessionProbeInterval,
      );
    }
  }

  Future<void> _handleServerScopeChange({String? previousServerId}) async {
    if (!mounted) {
      return;
    }
    if (previousServerId != null && previousServerId.trim().isNotEmpty) {
      try {
        final mutationGeneration =
            ++_backgroundPermissionContextMutationGeneration;
        await _enqueueBackgroundPermissionContextClear(
          reason: 'server-changed',
          serverId: previousServerId,
          expectedMutationGeneration: mutationGeneration,
        );
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to clear background permission auto-approve context before server switch',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (!mounted) return;
    final projectProvider = context.read<ProjectProvider>();
    await projectProvider.onServerScopeChanged();
    await _chatProvider?.onServerScopeChanged();
  }

  void _syncChatRouteActivity(ChatProvider chatProvider) {
    final isCurrent = _isChatScreenActive();
    if (_wasChatRouteCurrent == isCurrent) {
      return;
    }
    _wasChatRouteCurrent = isCurrent;
    chatProvider.setChatRouteActive(isCurrent);
    unawaited(
      _syncBackgroundPermissionAutoApproveContext(reason: 'route-sync'),
    );
    if (isCurrent) {
      _handleReturnToChat(chatProvider, reason: 'route-return');
    }
  }

  void _handleReturnToChat(
    ChatProvider chatProvider, {
    required String reason,
  }) {
    final signature = [
      reason,
      chatProvider.currentSession?.id ?? '-',
      chatProvider.messages.lastOrNull?.id ?? '-',
      chatProvider.messages.length,
      chatProvider.isCurrentSessionActivelyResponding,
      _scrollFollowMode.name,
    ].join('|');
    final now = DateTime.now();
    if (_lastReturnToChatAt != null &&
        _lastReturnToChatSignature == signature &&
        now.difference(_lastReturnToChatAt!) <
            const Duration(milliseconds: 400)) {
      _traceFinalUi(
        'return-to-chat-skip-debounced',
        details: 'reason=$reason signature=$signature',
      );
      return;
    }
    _lastReturnToChatAt = now;
    _lastReturnToChatSignature = signature;
    _flushPendingPostOnboardingTourAutoStart();
    _scheduleSessionTabsGestureHint();
    _scheduleAutoApprovePermissionDrain(reason: reason);
    unawaited(_syncBackgroundPermissionAutoApproveContext(reason: reason));
    if (_scrollFollowMode != _ScrollFollowMode.following ||
        chatProvider.currentSession == null) {
      return;
    }
    if (_resumeRefreshViewportRestorePending &&
        reason != 'app-resumed-refresh-complete') {
      _traceFinalUi(
        'return-to-chat-deferred-resume-refresh-pending',
        details: 'reason=$reason',
      );
      return;
    }
    if (chatProvider.messages.isEmpty ||
        chatProvider.state == ChatState.loading) {
      return;
    }
    AppLogger.debug(
      'Auto-following latest messages after $reason for session=${chatProvider.currentSession!.id}',
    );
    _queueCachedViewportRestore(chatProvider, reason: reason);
  }
}
