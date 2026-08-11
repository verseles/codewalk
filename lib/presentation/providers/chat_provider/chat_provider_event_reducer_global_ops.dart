part of '../chat_provider.dart';

extension _ChatProviderEventReducerGlobalOps on ChatProvider {
  void _handleGlobalEvent(ChatEvent event) {
    if (_isEphemeralTitleEvent(event)) return;

    if (event.type == 'catalog.updated') {
      unawaited(initializeProviders());
      return;
    }

    if (event.type == 'server.heartbeat') {
      return;
    }

    final type = event.type;
    final affectsContext =
        type.startsWith('session.') ||
        type.startsWith('message.') ||
        type.startsWith('project.') ||
        type.startsWith('worktree.') ||
        type.startsWith('todo.') ||
        type.startsWith('permission.') ||
        type.startsWith('question.');
    if (!affectsContext) {
      return;
    }

    final directory = _extractDirectoryFromEvent(event);
    if (directory == null || directory.trim().isEmpty) {
      _dirtyContextKeys.add(_activeContextKey);
      if (_cellularDataSaverService.isAggressiveDataSaverActive) {
        final eventSessionId = _effectiveEventSessionIdForEvent(event);
        if (_hasVisibleAggressiveDataSaverSession &&
            _isVisibleAggressiveSessionId(eventSessionId) &&
            _tryApplyGlobalEventIncremental(event)) {
          return;
        }
        AppLogger.debug(
          'Suppressed aggressive data saver global event without directory type=$type',
        );
        return;
      }
      if (_tryApplyGlobalEventIncremental(event)) {
        return;
      }
      final currentSessionId = _currentSession?.id.trim();
      final eventSessionId = _effectiveEventSessionIdForEvent(event)?.trim();
      final refreshVisibleSession =
          event.type.startsWith('message.') &&
          currentSessionId != null &&
          currentSessionId.isNotEmpty &&
          eventSessionId == currentSessionId;
      _scheduleCurrentContextRefresh(
        reason: 'global:$type:no-directory',
        refreshSessions: true,
        refreshStatus: true,
        refreshActiveSession: refreshVisibleSession,
      );
      return;
    }

    final targetContextKey = _composeContextKey(_activeServerId, directory);
    _dirtyContextKeys.add(targetContextKey);

    if (_cellularDataSaverService.isAggressiveDataSaverActive) {
      final eventSessionId = _effectiveEventSessionIdForEvent(event);
      if (targetContextKey == _activeContextKey &&
          _hasVisibleAggressiveDataSaverSession &&
          _isVisibleAggressiveSessionId(eventSessionId) &&
          _tryApplyGlobalEventIncremental(event)) {
        return;
      }
      AppLogger.debug(
        'Marked aggressive data saver context dirty without global reconcile context=$targetContextKey event=$type',
      );
      return;
    }

    if (targetContextKey == _activeContextKey) {
      if (_tryApplyGlobalEventIncremental(event)) {
        return;
      }
      _scheduleGlobalFallbackReconcile(event);
      return;
    }

    if (_tryApplyGlobalEventToInactiveSnapshot(targetContextKey, event)) {
      return;
    }

    AppLogger.debug(
      'Marked inactive context dirty and kept cache for SWR restore context=$targetContextKey event=$type',
    );
    _updateSessionTabSignalsForEvent(event, contextKey: targetContextKey);
    _reconcileSessionTabs();
  }

  bool _tryApplyGlobalEventIncremental(ChatEvent event) {
    // Skip events already processed by the session stream to avoid
    // redundant notifyListeners() calls and duplicate state mutations.
    if (_isRecentlyProcessedEvent(event)) return true;

    const supportedTypes = <String>{
      'server.connected',
      'session.created',
      'session.updated',
      'session.deleted',
      'session.status',
      'session.diff',
      'session.idle',
      'session.error',
      'session.next.moved',
      'session.next.revert.staged',
      'session.next.revert.cleared',
      'session.next.revert.committed',
      'todo.updated',
      'message.created',
      'message.updated',
      'message.part.updated',
      'message.part.delta',
      'message.part.removed',
      'message.removed',
      'permission.asked',
      'permission.updated',
      'permission.replied',
      'permission.v2.asked',
      'permission.v2.updated',
      'permission.v2.replied',
      'question.asked',
      'question.updated',
      'question.replied',
      'question.rejected',
      'question.v2.asked',
      'question.v2.updated',
      'question.v2.replied',
      'question.v2.rejected',
    };
    if (!supportedTypes.contains(event.type)) {
      return false;
    }
    _applyChatEvent(event);
    return true;
  }

  void _scheduleGlobalFallbackReconcile(ChatEvent event) {
    final type = event.type;
    final currentSessionId = _currentSession?.id.trim();
    final eventSessionId = _effectiveEventSessionIdForEvent(event)?.trim();
    final refreshSessions =
        type.startsWith('session.') ||
        type.startsWith('project.') ||
        type.startsWith('worktree.');
    final refreshActiveSession =
        type.startsWith('message.') &&
        !_isCompactingContext &&
        _activeMessageStreamSessionId == null &&
        currentSessionId != null &&
        currentSessionId.isNotEmpty &&
        eventSessionId == currentSessionId;
    _scheduleCurrentContextRefresh(
      reason: 'global:$type:fallback',
      refreshSessions: refreshSessions,
      refreshStatus: refreshSessions || refreshActiveSession,
      refreshActiveSession: refreshActiveSession,
    );
  }

  bool _tryApplyGlobalEventToInactiveSnapshot(
    String contextKey,
    ChatEvent event,
  ) {
    final snapshot = _contextSnapshots[contextKey];
    if (snapshot == null) {
      return false;
    }

    List<ChatSession>? nextSessions;
    Map<String, SessionStatusInfo>? nextSessionStatusById;
    Set<String>? nextUnreadCompletionIds;
    Map<String, DateTime>? nextUnreadCompletionTimestamps;
    Set<String>? nextErrorAttentionIds;
    Map<String, List<ChatPermissionRequest>>? nextPendingPermissionsBySession;
    Map<String, List<ChatQuestionRequest>>? nextPendingQuestionsBySession;
    switch (event.type) {
      case 'session.created':
      case 'session.updated':
        final info = event.properties['info'];
        if (info is! Map<String, dynamic>) {
          return false;
        }
        final incomingSession = ChatSessionModel.fromJson(info).toDomain();
        if (incomingSession.id.isEmpty ||
            _isEphemeralTitleSession(incomingSession)) {
          return false;
        }
        nextSessions = List<ChatSession>.from(snapshot.sessions);
        final existingIndex = nextSessions.indexWhere(
          (session) => session.id == incomingSession.id,
        );
        if (existingIndex == -1) {
          nextSessions.add(incomingSession);
        } else {
          nextSessions[existingIndex] = _mergeSessionFromEventInfo(
            incoming: incomingSession,
            existing: nextSessions[existingIndex],
            info: info,
          );
        }
        break;
      case 'session.deleted':
        final sessionId =
            (event.properties['info'] is Map<String, dynamic>
                ? (event.properties['info'] as Map<String, dynamic>)['id']
                      as String?
                : null) ??
            event.properties['sessionID'] as String? ??
            event.properties['id'] as String?;
        if (sessionId == null || sessionId.trim().isEmpty) {
          return false;
        }
        _deleteSessionAttentionSnapshot(
          contextKey: contextKey,
          sessionId: sessionId,
        );
        nextSessions = snapshot.sessions
            .where((session) => session.id != sessionId)
            .toList(growable: false);
        if (nextSessions.length == snapshot.sessions.length) {
          return false;
        }
        break;
      case 'session.status':
        final sessionId = event.properties['sessionID'] as String?;
        final statusMap = event.properties['status'];
        if (sessionId == null || statusMap is! Map<String, dynamic>) {
          return false;
        }
        final nextStatus = SessionStatusModel.fromJson(statusMap).toDomain();
        final previousStatus = snapshot.sessionStatusById[sessionId];
        if (previousStatus?.type == nextStatus.type) {
          return false;
        }
        nextSessionStatusById = Map<String, SessionStatusInfo>.from(
          snapshot.sessionStatusById,
        )..[sessionId] = nextStatus;
        if (nextStatus.type == SessionStatusType.busy ||
            nextStatus.type == SessionStatusType.retry) {
          nextUnreadCompletionIds = Set<String>.from(
            snapshot.sessionUnreadCompletionIds,
          )..remove(sessionId);
          nextUnreadCompletionTimestamps = Map<String, DateTime>.from(
            snapshot.sessionUnreadCompletionTimestamps,
          )..remove(sessionId);
        } else if (nextStatus.type == SessionStatusType.idle &&
            _isRootSessionInList(sessionId, snapshot.sessions) &&
            (previousStatus?.type == SessionStatusType.busy ||
                previousStatus?.type == SessionStatusType.retry)) {
          nextUnreadCompletionIds = Set<String>.from(
            snapshot.sessionUnreadCompletionIds,
          )..add(sessionId);
          nextUnreadCompletionTimestamps = Map<String, DateTime>.from(
            snapshot.sessionUnreadCompletionTimestamps,
          )..[sessionId] = DateTime.now();
          _resolveSessionAttentionCompletion(
            contextKey: contextKey,
            sessionId: sessionId,
            completedAt: DateTime.now(),
          );
        }
        break;
      case 'session.idle':
        final sessionId = event.properties['sessionID'] as String?;
        if (sessionId == null || sessionId.trim().isEmpty) {
          return false;
        }
        final previousStatusType = snapshot.sessionStatusById[sessionId]?.type;
        final hadErrorAttention = snapshot.sessionErrorAttentionIds.contains(
          sessionId,
        );
        if (previousStatusType == SessionStatusType.idle &&
            !hadErrorAttention) {
          return false;
        }
        const nextIdleStatus = SessionStatusInfo(type: SessionStatusType.idle);
        nextSessionStatusById = Map<String, SessionStatusInfo>.from(
          snapshot.sessionStatusById,
        )..[sessionId] = nextIdleStatus;
        nextErrorAttentionIds = Set<String>.from(
          snapshot.sessionErrorAttentionIds,
        )..remove(sessionId);
        final wasBusyBeforeIdle =
            previousStatusType == SessionStatusType.busy ||
            previousStatusType == SessionStatusType.retry;
        if ((wasBusyBeforeIdle || previousStatusType == null) &&
            _isRootSessionInList(sessionId, snapshot.sessions)) {
          nextUnreadCompletionIds = Set<String>.from(
            snapshot.sessionUnreadCompletionIds,
          )..add(sessionId);
          nextUnreadCompletionTimestamps = Map<String, DateTime>.from(
            snapshot.sessionUnreadCompletionTimestamps,
          )..[sessionId] = DateTime.now();
          _resolveSessionAttentionCompletion(
            contextKey: contextKey,
            sessionId: sessionId,
            completedAt: DateTime.now(),
          );
        }
        break;
      case 'session.error':
        final sessionId = event.properties['sessionID'] as String?;
        if (sessionId == null || sessionId.trim().isEmpty) {
          return false;
        }
        nextSessionStatusById = Map<String, SessionStatusInfo>.from(
          snapshot.sessionStatusById,
        )..[sessionId] = const SessionStatusInfo(type: SessionStatusType.idle);
        nextUnreadCompletionIds = Set<String>.from(
          snapshot.sessionUnreadCompletionIds,
        )..remove(sessionId);
        nextUnreadCompletionTimestamps = Map<String, DateTime>.from(
          snapshot.sessionUnreadCompletionTimestamps,
        )..remove(sessionId);
        nextErrorAttentionIds = Set<String>.from(
          snapshot.sessionErrorAttentionIds,
        )..add(sessionId);
        break;
      case 'permission.asked':
      case 'permission.updated':
      case 'permission.v2.asked':
      case 'permission.v2.updated':
        ChatPermissionRequest permission;
        try {
          permission = ChatPermissionRequestModel.fromJson(
            _eventPayloadOrNested(event.properties, const <String>[
              'permission',
              'request',
              'info',
            ]),
          ).toDomain();
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to parse inactive snapshot permission event',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
        if (permission.id.trim().isEmpty ||
            permission.sessionId.trim().isEmpty) {
          return false;
        }
        nextPendingPermissionsBySession =
            Map<String, List<ChatPermissionRequest>>.from(
              snapshot.pendingPermissionsBySession,
            );
        final sessionPermissions = List<ChatPermissionRequest>.from(
          nextPendingPermissionsBySession[permission.sessionId] ??
              const <ChatPermissionRequest>[],
        );
        final existingIndex = sessionPermissions.indexWhere(
          (item) => item.id == permission.id,
        );
        if (existingIndex == -1) {
          sessionPermissions.add(permission);
        } else {
          sessionPermissions[existingIndex] = permission;
        }
        nextPendingPermissionsBySession[permission.sessionId] =
            sessionPermissions;
        break;
      case 'permission.replied':
      case 'permission.v2.replied':
        final replyPayload = _eventPayloadOrNested(
          event.properties,
          const <String>['permission', 'request', 'info'],
        );
        final sessionId =
            _extractEventSessionId(replyPayload) ??
            _extractEventSessionId(event.properties);
        final requestId =
            replyPayload['requestID'] as String? ??
            replyPayload['id'] as String?;
        if (sessionId == null || requestId == null) {
          return false;
        }
        final existing = snapshot.pendingPermissionsBySession[sessionId];
        if (existing == null) {
          return false;
        }
        final filtered = existing
            .where((item) => item.id != requestId)
            .toList(growable: false);
        if (filtered.length == existing.length) {
          return false;
        }
        nextPendingPermissionsBySession =
            Map<String, List<ChatPermissionRequest>>.from(
              snapshot.pendingPermissionsBySession,
            );
        if (filtered.isEmpty) {
          nextPendingPermissionsBySession.remove(sessionId);
        } else {
          nextPendingPermissionsBySession[sessionId] = filtered;
        }
        break;
      case 'question.asked':
      case 'question.updated':
      case 'question.v2.asked':
      case 'question.v2.updated':
        ChatQuestionRequest question;
        try {
          question = ChatQuestionRequestModel.fromJson(
            _eventPayloadOrNested(event.properties, const <String>[
              'question',
              'request',
              'info',
            ]),
          ).toDomain();
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to parse inactive snapshot question event',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }
        if (question.id.trim().isEmpty || question.sessionId.trim().isEmpty) {
          return false;
        }
        nextPendingQuestionsBySession =
            Map<String, List<ChatQuestionRequest>>.from(
              snapshot.pendingQuestionsBySession,
            );
        final sessionQuestions = List<ChatQuestionRequest>.from(
          nextPendingQuestionsBySession[question.sessionId] ??
              const <ChatQuestionRequest>[],
        );
        final existingIndex = sessionQuestions.indexWhere(
          (item) => item.id == question.id,
        );
        if (existingIndex == -1) {
          sessionQuestions.add(question);
        } else {
          sessionQuestions[existingIndex] = question;
        }
        nextPendingQuestionsBySession[question.sessionId] = sessionQuestions;
        break;
      case 'question.replied':
      case 'question.rejected':
      case 'question.v2.replied':
      case 'question.v2.rejected':
        final replyPayload = _eventPayloadOrNested(
          event.properties,
          const <String>['question', 'request', 'info'],
        );
        final sessionId =
            _extractEventSessionId(replyPayload) ??
            _extractEventSessionId(event.properties);
        final requestId =
            replyPayload['requestID'] as String? ??
            replyPayload['id'] as String?;
        if (sessionId == null || requestId == null) {
          return false;
        }
        final existing = snapshot.pendingQuestionsBySession[sessionId];
        if (existing == null) {
          return false;
        }
        final filtered = existing
            .where((item) => item.id != requestId)
            .toList(growable: false);
        if (filtered.length == existing.length) {
          return false;
        }
        nextPendingQuestionsBySession =
            Map<String, List<ChatQuestionRequest>>.from(
              snapshot.pendingQuestionsBySession,
            );
        if (filtered.isEmpty) {
          nextPendingQuestionsBySession.remove(sessionId);
        } else {
          nextPendingQuestionsBySession[sessionId] = filtered;
        }
        break;
      default:
        return false;
    }

    final effectiveSessions = nextSessions ?? snapshot.sessions;
    final effectiveSessionStatusById =
        nextSessionStatusById ?? snapshot.sessionStatusById;
    final effectiveUnreadCompletionIds =
        nextUnreadCompletionIds ?? snapshot.sessionUnreadCompletionIds;
    final effectiveUnreadCompletionTimestamps =
        nextUnreadCompletionTimestamps ??
        snapshot.sessionUnreadCompletionTimestamps;
    final effectiveErrorAttentionIds =
        nextErrorAttentionIds ?? snapshot.sessionErrorAttentionIds;
    final effectivePendingPermissionsBySession =
        nextPendingPermissionsBySession ?? snapshot.pendingPermissionsBySession;
    final effectivePendingQuestionsBySession =
        nextPendingQuestionsBySession ?? snapshot.pendingQuestionsBySession;

    final changed =
        !listEquals(snapshot.sessions, effectiveSessions) ||
        !mapEquals(snapshot.sessionStatusById, effectiveSessionStatusById) ||
        !mapEquals(
          snapshot.pendingPermissionsBySession,
          effectivePendingPermissionsBySession,
        ) ||
        !mapEquals(
          snapshot.pendingQuestionsBySession,
          effectivePendingQuestionsBySession,
        ) ||
        !setEquals(
          snapshot.sessionUnreadCompletionIds,
          effectiveUnreadCompletionIds,
        ) ||
        !mapEquals(
          snapshot.sessionUnreadCompletionTimestamps,
          effectiveUnreadCompletionTimestamps,
        ) ||
        !setEquals(
          snapshot.sessionErrorAttentionIds,
          effectiveErrorAttentionIds,
        );
    if (!changed) {
      return false;
    }

    final nextSnapshot = _ChatContextSnapshot(
      sessions: effectiveSessions,
      currentSession: snapshot.currentSession,
      messages: snapshot.messages,
      sessionStatusById: effectiveSessionStatusById,
      pendingPermissionsBySession: effectivePendingPermissionsBySession,
      pendingQuestionsBySession: effectivePendingQuestionsBySession,
      sessionUnreadCompletionIds: effectiveUnreadCompletionIds,
      sessionUnreadCompletionTimestamps: effectiveUnreadCompletionTimestamps,
      sessionErrorAttentionIds: effectiveErrorAttentionIds,
      sessionChildrenById: snapshot.sessionChildrenById,
      sessionTodoById: snapshot.sessionTodoById,
      sessionDiffById: snapshot.sessionDiffById,
      sessionSearchQuery: snapshot.sessionSearchQuery,
      sessionListFilter: snapshot.sessionListFilter,
      sessionListSort: snapshot.sessionListSort,
      pinnedSessionIds: snapshot.pinnedSessionIds,
      sessionVisibleLimit: snapshot.sessionVisibleLimit,
      isNewChatDraftActive: snapshot.isNewChatDraftActive,
      activeSendDraft: snapshot.activeSendDraft,
      rejectedDraft: snapshot.rejectedDraft,
      questionSubmitFailedRequestIds: snapshot.questionSubmitFailedRequestIds,
      providers: snapshot.providers,
      defaultModels: snapshot.defaultModels,
      connectedProviderIds: snapshot.connectedProviderIds,
      agents: snapshot.agents,
      selectedProviderId: snapshot.selectedProviderId,
      selectedModelId: snapshot.selectedModelId,
      selectedAgentName: snapshot.selectedAgentName,
      selectedVariantId: snapshot.selectedVariantId,
      recentModelKeys: snapshot.recentModelKeys,
      recentAgentNames: snapshot.recentAgentNames,
      recentVariantValuesByModel: snapshot.recentVariantValuesByModel,
      modelUsageCounts: snapshot.modelUsageCounts,
      selectedVariantByModel: snapshot.selectedVariantByModel,
      agentSelectionMemoryByAgent: snapshot.agentSelectionMemoryByAgent,
      providerCatalogFetchedAtEpochMs: snapshot.providerCatalogFetchedAtEpochMs,
      agentCatalogFetchedAtEpochMs: snapshot.agentCatalogFetchedAtEpochMs,
    );
    _contextSnapshots[contextKey] = nextSnapshot;
    final feedbackEvent = _feedbackEventForInactiveContext(
      event,
      previousSnapshot: snapshot,
    );
    if (feedbackEvent != null) {
      _dispatchFeedbackForInactiveContextEvent(
        feedbackEvent,
        snapshot: nextSnapshot,
      );
    }
    _dismissResolvedInactiveInteractionFeedback(event, snapshot: nextSnapshot);
    _scheduleSessionUnreadHighlightTimer();
    _updateSessionTabSignalsForEvent(event, contextKey: contextKey);
    _reconcileSessionTabs();
    _notifyListeners();
    return true;
  }

  ChatEvent? _feedbackEventForInactiveContext(
    ChatEvent event, {
    required _ChatContextSnapshot previousSnapshot,
  }) {
    if (_shouldHandleFeedbackForEvent(event)) {
      return event;
    }
    if (event.type != 'session.status') {
      return null;
    }
    final sessionId = event.properties['sessionID'] as String?;
    final statusMap = event.properties['status'];
    if (sessionId == null || statusMap is! Map<String, dynamic>) {
      return null;
    }
    final status = _parseStatusForFeedback(statusMap);
    if (status?.type != SessionStatusType.idle) {
      return null;
    }
    final previousStatusType =
        previousSnapshot.sessionStatusById[sessionId]?.type;
    final completedFromActiveTurn =
        previousStatusType == null ||
        previousStatusType == SessionStatusType.busy ||
        previousStatusType == SessionStatusType.retry;
    if (!completedFromActiveTurn) {
      return null;
    }
    return _sessionIdleFeedbackEventFromStatus(event);
  }

  void _dispatchFeedbackForInactiveContextEvent(
    ChatEvent event, {
    required _ChatContextSnapshot snapshot,
  }) {
    if (!_shouldHandleFeedbackForEvent(event)) {
      return;
    }
    final eventSessionId = _effectiveEventSessionIdForEvent(event);
    unawaited(
      eventFeedbackDispatcher?.handle(
        event,
        sessionTitleHint: _sessionTitleForNotificationInList(
          eventSessionId,
          snapshot.sessions,
        ),
        isRootSession:
            eventSessionId == null ||
            _isRootSessionInList(eventSessionId, snapshot.sessions),
        isAppInForeground: _isAppInForeground,
        currentSessionId: _isChatRouteActive ? _currentSession?.id : null,
      ),
    );
  }

  String? _sessionTitleForNotificationInList(
    String? sessionId,
    List<ChatSession> sessions,
  ) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return null;
    }
    for (final session in sessions) {
      if (session.id != normalizedSessionId) {
        continue;
      }
      return SessionTitleFormatter.displayTitle(
        time: session.time,
        title: session.title,
      );
    }
    return null;
  }

  void _dismissResolvedInactiveInteractionFeedback(
    ChatEvent event, {
    required _ChatContextSnapshot snapshot,
  }) {
    switch (event.type) {
      case 'permission.replied':
      case 'permission.v2.replied':
      case 'question.replied':
      case 'question.rejected':
      case 'question.v2.replied':
      case 'question.v2.rejected':
        final replyPayload = _eventPayloadOrNested(
          event.properties,
          const <String>['permission', 'question', 'request', 'info'],
        );
        final sessionId =
            _extractEventSessionId(replyPayload) ??
            _extractEventSessionId(event.properties);
        final normalizedSessionId = sessionId?.trim();
        if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
          return;
        }
        final hasRemainingPermissions =
            snapshot
                .pendingPermissionsBySession[normalizedSessionId]
                ?.isNotEmpty ??
            false;
        final hasRemainingQuestions =
            snapshot
                .pendingQuestionsBySession[normalizedSessionId]
                ?.isNotEmpty ??
            false;
        if (!hasRemainingPermissions && !hasRemainingQuestions) {
          unawaited(
            eventFeedbackDispatcher?.dismissForSession(normalizedSessionId),
          );
        }
    }
  }

  void _scheduleCurrentContextRefresh({
    required String reason,
    bool refreshSessions = false,
    bool refreshStatus = false,
    bool refreshActiveSession = false,
  }) {
    _pendingRefreshSessions = _pendingRefreshSessions || refreshSessions;
    _pendingRefreshStatus = _pendingRefreshStatus || refreshStatus;
    _pendingRefreshActiveSession =
        _pendingRefreshActiveSession || refreshActiveSession;
    _pendingCurrentContextRefreshReason = reason;
    _globalRefreshDebounce?.cancel();
    _globalRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      _globalRefreshDebounce = null;
      _startCurrentContextRefreshDrain();
    });
  }

  bool get _hasPendingCurrentContextRefresh =>
      _pendingRefreshSessions ||
      _pendingRefreshStatus ||
      _pendingRefreshActiveSession;

  void _startCurrentContextRefreshDrain() {
    if (_currentContextRefreshTask != null) {
      return;
    }
    final task = _drainCurrentContextRefreshes();
    _currentContextRefreshTask = task;
    unawaited(
      task.whenComplete(() {
        if (!identical(_currentContextRefreshTask, task)) {
          return;
        }
        _currentContextRefreshTask = null;
        if (_hasPendingCurrentContextRefresh &&
            _globalRefreshDebounce == null) {
          _startCurrentContextRefreshDrain();
        }
      }),
    );
  }

  Future<void> _drainCurrentContextRefreshes() async {
    while (_hasPendingCurrentContextRefresh) {
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        _pendingRefreshSessions = false;
        _pendingRefreshStatus = false;
        _pendingRefreshActiveSession = false;
        return;
      }
      final shouldRefreshSessions = _pendingRefreshSessions;
      final shouldRefreshStatus = _pendingRefreshStatus;
      final shouldRefreshActiveSession = _pendingRefreshActiveSession;
      final reason = _pendingCurrentContextRefreshReason;
      _pendingRefreshSessions = false;
      _pendingRefreshStatus = false;
      _pendingRefreshActiveSession = false;

      AppLogger.info(
        'scoped_reconcile_triggered reason=$reason sessions=$shouldRefreshSessions active=$shouldRefreshActiveSession status=$shouldRefreshStatus',
      );

      final isAggressiveDataSaver =
          _cellularDataSaverService.isAggressiveDataSaverActive;
      final shouldRefreshSessionMetadata =
          shouldRefreshSessions &&
          (!isAggressiveDataSaver || shouldRefreshActiveSession);

      try {
        if (shouldRefreshSessionMetadata) {
          await loadSessions(
            refreshSelectedSessionMessages: false,
            refreshSessionStatus: !isAggressiveDataSaver,
          );
        }

        if (shouldRefreshActiveSession) {
          await refreshActiveSessionView(
            reason: 'scoped-reconcile:$reason',
            includeStatus:
                !isAggressiveDataSaver &&
                !shouldRefreshSessions &&
                shouldRefreshStatus,
            refreshAfterJoiningInFlight: shouldRefreshSessionMetadata,
          );
        } else if (!shouldRefreshSessions &&
            shouldRefreshStatus &&
            !isAggressiveDataSaver) {
          await refreshSessionStatusSnapshot();
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Scoped reconciliation failed reason=$reason',
          error: error,
          stackTrace: stackTrace,
        );
      }

      if (_globalRefreshDebounce != null) {
        return;
      }
    }
  }
}
