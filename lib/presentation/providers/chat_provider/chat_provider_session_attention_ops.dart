part of '../chat_provider.dart';

extension ChatProviderSessionAttentionOps on ChatProvider {
  void _resolveSessionAttentionCompletion({
    required String contextKey,
    required String sessionId,
    required DateTime completedAt,
  }) {
    final resolver = _sessionAttentionCompletionResolver;
    if (resolver == null) {
      return;
    }
    final snapshot = contextKey == _activeContextKey
        ? null
        : _contextSnapshots[contextKey];
    final sessions = snapshot?.sessions ?? _sessions;
    final messages = snapshot?.messages ?? _messages;
    final session = sessions
        .where((candidate) => candidate.id == sessionId)
        .firstOrNull;
    final parentId = session?.parentId?.trim();
    if (session == null ||
        session.archived ||
        (parentId != null && parentId.isNotEmpty)) {
      return;
    }
    final activePrefix = '$_activeServerId::';
    final contextDirectory = contextKey.startsWith(activePrefix)
        ? contextKey.substring(activePrefix.length).trim()
        : '';
    final directory = session.directory?.trim().isNotEmpty == true
        ? session.directory!.trim()
        : contextDirectory;
    if (directory.isEmpty) {
      return;
    }
    DateTime? latestUserAt;
    for (final message in messages.whereType<UserMessage>()) {
      if (message.sessionId == sessionId &&
          (latestUserAt == null || message.time.isAfter(latestUserAt))) {
        latestUserAt = message.time;
      }
    }
    String? baselineAssistantMessageId;
    DateTime? baselineAssistantCompletedAt;
    for (final message in messages.whereType<AssistantMessage>()) {
      final messageCompletedAt = message.completedTime ?? message.time;
      if (message.sessionId == sessionId &&
          message.isCompleted &&
          latestUserAt != null &&
          messageCompletedAt.isBefore(latestUserAt) &&
          (baselineAssistantCompletedAt == null ||
              messageCompletedAt.isAfter(baselineAssistantCompletedAt))) {
        baselineAssistantMessageId = message.id;
        baselineAssistantCompletedAt = messageCompletedAt;
      }
    }
    unawaited(
      resolver
          .resolve(
            identity: SessionAttentionIdentity(
              serverId: _activeServerId,
              directory: directory,
              rootSessionId: sessionId,
            ),
            title: session.title?.trim().isNotEmpty == true
                ? session.title!.trim()
                : sessionId,
            projectLabel: session.workspaceId.trim().isNotEmpty
                ? session.workspaceId.trim()
                : directory,
            completedAt: completedAt,
            baselineAssistantMessageId: baselineAssistantMessageId,
          )
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              AppLogger.warn(
                'Failed to resolve encrypted session completion snapshot',
                error: error,
                stackTrace: stackTrace,
              );
            },
          ),
    );
  }

  void _deleteSessionAttentionSnapshot({
    required String contextKey,
    required String sessionId,
  }) {
    final identity = _sessionAttentionIdentityFor(
      contextKey: contextKey,
      sessionId: sessionId,
    );
    if (identity == null) {
      return;
    }
    _deleteSessionAttentionSnapshotIdentity(identity);
  }

  SessionAttentionIdentity? _sessionAttentionIdentityFor({
    required String contextKey,
    required String sessionId,
  }) {
    final activePrefix = '$_activeServerId::';
    if (!contextKey.startsWith(activePrefix)) {
      return null;
    }
    final snapshot = contextKey == _activeContextKey
        ? null
        : _contextSnapshots[contextKey];
    final session = (snapshot?.sessions ?? _sessions)
        .where((candidate) => candidate.id == sessionId)
        .firstOrNull;
    final contextDirectory = contextKey.substring(activePrefix.length).trim();
    final directory = session?.directory?.trim().isNotEmpty == true
        ? session!.directory!.trim()
        : contextDirectory;
    if (directory.isEmpty) {
      return null;
    }
    return SessionAttentionIdentity(
      serverId: _activeServerId,
      directory: directory,
      rootSessionId: sessionId,
    ).normalized();
  }

  void _deleteSessionAttentionSnapshotIdentity(
    SessionAttentionIdentity identity,
  ) {
    final resolver = _sessionAttentionCompletionResolver;
    if (resolver != null) {
      unawaited(
        resolver
            .removeIdentity(identity)
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                AppLogger.warn(
                  'Failed to delete encrypted session completion snapshot',
                  error: error,
                  stackTrace: stackTrace,
                );
              },
            ),
      );
    }
    unawaited(
      CarMessagingRuntime.removeIdentity(identity).then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.warn(
            'Failed to delete car messaging state for session',
            error: error,
            stackTrace: stackTrace,
          );
        },
      ),
    );
  }

  SessionAttentionAggregate rootSessionAttentionAggregate({
    bool fullResynchronization = false,
  }) {
    final candidates = <RootSessionAttentionCandidate>[];
    final knownIdentities = <SessionAttentionIdentity>{};
    final activePrefix = '$_activeServerId::';

    void addContextCandidates({
      required String contextKey,
      required List<ChatSession> sessions,
      required ChatSession? currentSession,
      required List<ChatMessage> messages,
      required Map<String, SessionStatusInfo> statusById,
      required Map<String, List<ChatPermissionRequest>> permissionsBySession,
      required Map<String, List<ChatQuestionRequest>> questionsBySession,
      required Set<String> unreadCompletionIds,
      required Map<String, DateTime> unreadCompletionTimestamps,
      required Set<String> errorIds,
      required bool isActiveContext,
    }) {
      if (!contextKey.startsWith(activePrefix)) {
        return;
      }
      final contextDirectory = contextKey.substring(activePrefix.length).trim();
      final parentBySessionId = <String, String>{
        for (final session in sessions)
          if (session.parentId?.trim().isNotEmpty == true)
            session.id: session.parentId!.trim(),
      };
      String rootSessionIdFor(String sessionId) {
        var current = sessionId;
        final visited = <String>{};
        while (visited.add(current)) {
          final parent = parentBySessionId[current];
          if (parent == null || parent.isEmpty) return current;
          current = parent;
        }
        return sessionId;
      }

      for (final session in sessions) {
        final parentId = session.parentId?.trim();
        final sessionId = session.id.trim();
        if (sessionId.isEmpty) {
          continue;
        }
        final directory = (session.directory?.trim().isNotEmpty ?? false)
            ? session.directory!.trim()
            : contextDirectory;
        if (session.archived) {
          if ((parentId == null || parentId.isEmpty) && directory.isNotEmpty) {
            _deleteSessionAttentionSnapshotIdentity(
              SessionAttentionIdentity(
                serverId: _activeServerId,
                directory: directory,
                rootSessionId: sessionId,
              ),
            );
          }
          continue;
        }
        if (parentId != null && parentId.isNotEmpty) {
          continue;
        }
        final hasPending =
            permissionsBySession.entries.any(
              (entry) =>
                  entry.value.isNotEmpty &&
                  rootSessionIdFor(entry.key) == sessionId,
            ) ||
            questionsBySession.entries.any(
              (entry) =>
                  entry.value.isNotEmpty &&
                  rootSessionIdFor(entry.key) == sessionId,
            );
        final hasError = errorIds.contains(sessionId);
        final hasCompletion = unreadCompletionIds.contains(sessionId);
        final status = statusById[sessionId]?.type;
        final working =
            status == SessionStatusType.busy ||
            status == SessionStatusType.retry;
        if (directory.isEmpty) {
          continue;
        }
        final identity = SessionAttentionIdentity(
          serverId: _activeServerId,
          directory: directory,
          rootSessionId: sessionId,
        );
        knownIdentities.add(identity);
        final sessionMessages = messages
            .where((message) => message.sessionId == sessionId)
            .toList(growable: false);
        final latestMessage = sessionMessages.isEmpty
            ? null
            : sessionMessages.last;
        final fingerprint = <Object?>[
          status?.name,
          statusById[sessionId]?.attempt,
          statusById[sessionId]?.message,
          statusById[sessionId]?.nextEpochMs,
          latestMessage?.id,
          latestMessage?.hashCode,
          latestMessage == null
              ? 0
              : _messageLocalDeltaVersion(latestMessage.id),
          latestMessage is AssistantMessage ? latestMessage.parts.length : 0,
          permissionsBySession.entries
              .where((entry) => rootSessionIdFor(entry.key) == sessionId)
              .expand((entry) => entry.value)
              .map((request) => request.id)
              .join(','),
          questionsBySession.entries
              .where((entry) => rootSessionIdFor(entry.key) == sessionId)
              .expand((entry) => entry.value)
              .map((request) => request.id)
              .join(','),
          hasCompletion,
          hasError,
        ].join('|');
        final progressObserved =
            _sessionAttentionObservationFingerprintByIdentity[identity] !=
            fingerprint;
        _sessionAttentionObservationFingerprintByIdentity[identity] =
            fingerprint;
        final timing = _sessionAttentionCoordinator.observe(
          identity: identity,
          busy: working,
          progressObserved: progressObserved,
        );
        if (isActiveContext &&
            currentSession?.id == sessionId &&
            !hasPending &&
            !hasError) {
          continue;
        }

        final kind = hasError
            ? RootSessionAttentionKind.error
            : hasPending
            ? RootSessionAttentionKind.pendingInteraction
            : hasCompletion
            ? RootSessionAttentionKind.completed
            : working
            ? timing.delayed
                  ? RootSessionAttentionKind.delayed
                  : latestMessage is AssistantMessage &&
                        !latestMessage.isCompleted
                  ? RootSessionAttentionKind.receiving
                  : RootSessionAttentionKind.active
            : null;
        if (kind == null) {
          continue;
        }
        String? completionMessageId;
        if (hasCompletion) {
          for (var index = messages.length - 1; index >= 0; index -= 1) {
            final message = messages[index];
            if (message.sessionId == sessionId &&
                message is AssistantMessage &&
                message.isCompleted) {
              completionMessageId = message.id;
              break;
            }
          }
        }
        candidates.add(
          RootSessionAttentionCandidate(
            identity: identity,
            kind: kind,
            title: session.title?.trim().isNotEmpty == true
                ? session.title!.trim()
                : sessionId,
            projectLabel: session.workspaceId.trim().isNotEmpty
                ? session.workspaceId.trim()
                : directory,
            observedAt: unreadCompletionTimestamps[sessionId] ?? session.time,
            observableBusyElapsed: timing.observableBusyElapsed,
            monitoringPaused: timing.monitoringPaused,
            pauseReason: timing.pauseReason,
            completionMessageId: completionMessageId,
          ),
        );
      }
    }

    addContextCandidates(
      contextKey: _activeContextKey,
      sessions: _sessions,
      currentSession: _currentSession,
      messages: _messages,
      statusById: _sessionStatusById,
      permissionsBySession: _pendingPermissionsBySession,
      questionsBySession: _pendingQuestionsBySession,
      unreadCompletionIds: _sessionUnreadCompletionIds,
      unreadCompletionTimestamps: _sessionUnreadCompletionTimestamps,
      errorIds: _sessionErrorAttentionIds,
      isActiveContext: true,
    );
    for (final entry in _contextSnapshots.entries) {
      if (entry.key == _activeContextKey) {
        continue;
      }
      final snapshot = entry.value;
      addContextCandidates(
        contextKey: entry.key,
        sessions: snapshot.sessions,
        currentSession: snapshot.currentSession,
        messages: snapshot.messages,
        statusById: snapshot.sessionStatusById,
        permissionsBySession: snapshot.pendingPermissionsBySession,
        questionsBySession: snapshot.pendingQuestionsBySession,
        unreadCompletionIds: snapshot.sessionUnreadCompletionIds,
        unreadCompletionTimestamps: snapshot.sessionUnreadCompletionTimestamps,
        errorIds: snapshot.sessionErrorAttentionIds,
        isActiveContext: false,
      );
    }
    _sessionAttentionCoordinator.retainIdentities(knownIdentities);
    _sessionAttentionObservationFingerprintByIdentity.removeWhere(
      (identity, _) => !knownIdentities.contains(identity),
    );
    candidates.sort((left, right) {
      final priority = right.priority.compareTo(left.priority);
      if (priority != 0) {
        return priority;
      }
      final observed = right.observedAt.compareTo(left.observedAt);
      if (observed != 0) {
        return observed;
      }
      return left.identity.key.compareTo(right.identity.key);
    });
    _sessionAttentionRevision += 1;
    return SessionAttentionAggregate(
      generation: _sessionAttentionGeneration,
      revision: _sessionAttentionRevision,
      candidates: List<RootSessionAttentionCandidate>.unmodifiable(candidates),
      isFullResynchronization: fullResynchronization,
    );
  }

  bool isSessionActivelyResponding(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return false;
    }
    final isCurrentSession = _currentSession?.id == normalizedSessionId;
    final hasInProgressAssistant = _messages.whereType<AssistantMessage>().any(
      (message) =>
          message.sessionId == normalizedSessionId && !message.isCompleted,
    );
    final status = _sessionStatusById[normalizedSessionId]?.type;
    final hasBusyStatus =
        status == SessionStatusType.busy || status == SessionStatusType.retry;
    final hasActiveStream =
        _activeMessageStreamSessionId == normalizedSessionId &&
        _messageSubscription != null;

    if (!isCurrentSession) {
      return hasBusyStatus;
    }

    if (hasActiveStream) {
      return true;
    }

    if (_state == ChatState.sending) {
      return true;
    }

    if (hasInProgressAssistant) {
      return true;
    }

    if (!hasBusyStatus) {
      return false;
    }

    ChatMessage? latestSessionMessage;
    for (var index = _messages.length - 1; index >= 0; index -= 1) {
      final candidate = _messages[index];
      if (candidate.sessionId == normalizedSessionId) {
        latestSessionMessage = candidate;
        break;
      }
    }

    if (latestSessionMessage == null) {
      return false;
    }

    if (latestSessionMessage is UserMessage) {
      return true;
    }

    if (latestSessionMessage is! AssistantMessage) {
      return true;
    }

    final hasToolSurfacePart = latestSessionMessage.parts.any(
      (part) => part is ToolPart || part is PatchPart,
    );

    // Keep the active session in responding mode for busy tool-only turns
    // where step chunks can be emitted as completed assistant messages.
    return hasToolSurfacePart;
  }

  bool get isCurrentSessionActivelyResponding {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return false;
    }
    return isSessionActivelyResponding(sessionId);
  }

  SessionAttentionState sessionAttentionForScope(
    String sessionId, {
    required String scopeId,
  }) {
    final normalizedScopeId = scopeId.trim();
    if (normalizedScopeId.isEmpty) {
      return sessionAttentionFor(sessionId);
    }
    final contextKey = _composeContextKey(_activeServerId, normalizedScopeId);
    if (contextKey == _activeContextKey) {
      return sessionAttentionFor(sessionId);
    }

    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return const SessionAttentionState();
    }

    final snapshot = _contextSnapshots[contextKey];
    if (snapshot == null) {
      return const SessionAttentionState();
    }

    final statusType = snapshot.sessionStatusById[normalizedSessionId]?.type;
    final hasPendingPermission =
        (snapshot
            .pendingPermissionsBySession[normalizedSessionId]
            ?.isNotEmpty ??
        false);
    final hasPendingQuestion =
        (snapshot.pendingQuestionsBySession[normalizedSessionId]?.isNotEmpty ??
        false);

    return SessionAttentionState(
      isActive:
          statusType == SessionStatusType.busy ||
          statusType == SessionStatusType.retry,
      hasPendingInteraction: hasPendingPermission || hasPendingQuestion,
      hasError: snapshot.sessionErrorAttentionIds.contains(normalizedSessionId),
      hasUnreadCompletion: snapshot.sessionUnreadCompletionIds.contains(
        normalizedSessionId,
      ),
      unreadCompletionAt:
          snapshot.sessionUnreadCompletionTimestamps[normalizedSessionId],
    );
  }

  SessionAttentionState sessionAttentionFor(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return const SessionAttentionState();
    }

    final hasPendingPermission =
        (_pendingPermissionsBySession[normalizedSessionId]?.isNotEmpty ??
        false);
    final hasPendingQuestion =
        (_pendingQuestionsBySession[normalizedSessionId]?.isNotEmpty ?? false);

    return SessionAttentionState(
      isActive: isSessionActivelyResponding(normalizedSessionId),
      hasPendingInteraction: hasPendingPermission || hasPendingQuestion,
      hasError: _sessionErrorAttentionIds.contains(normalizedSessionId),
      hasUnreadCompletion: _sessionUnreadCompletionIds.contains(
        normalizedSessionId,
      ),
      unreadCompletionAt:
          _sessionUnreadCompletionTimestamps[normalizedSessionId],
    );
  }

  bool get hasOutOfFocusAttention => outOfFocusAttentionCount > 0;

  int get outOfFocusAttentionCount {
    final currentSessionId = _currentSession?.id;
    var total = 0;
    for (final session in visibleSessions) {
      if (session.id == currentSessionId) {
        continue;
      }
      final attention = sessionAttentionFor(session.id);
      if (attention.requiresAttention) {
        total += 1;
      }
    }
    return total;
  }

  SessionAttentionKind get outOfFocusAttentionKind {
    final currentSessionId = _currentSession?.id;
    var hasPendingInteraction = false;
    var hasUnreadCompletion = false;

    for (final session in visibleSessions) {
      if (session.id == currentSessionId) {
        continue;
      }
      final attention = sessionAttentionFor(session.id);
      if (!attention.requiresAttention) {
        continue;
      }
      if (attention.hasError) {
        return SessionAttentionKind.error;
      }
      hasPendingInteraction =
          hasPendingInteraction || attention.hasPendingInteraction;
      hasUnreadCompletion =
          hasUnreadCompletion || attention.hasUnreadCompletion;
    }

    if (hasPendingInteraction) {
      return SessionAttentionKind.pendingInteraction;
    }
    if (hasUnreadCompletion) {
      return SessionAttentionKind.unreadCompletion;
    }
    return SessionAttentionKind.none;
  }

  void _clearSessionAttentionForSession(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    _clearSessionUnreadCompletion(normalizedSessionId);
    _sessionErrorAttentionIds.remove(normalizedSessionId);
  }

  void _pruneSessionAttentionStateToKnownSessions() {
    final knownSessionIds = _sessions.map((session) => session.id).toSet();
    _sessionUnreadCompletionIds.removeWhere(
      (sessionId) => !knownSessionIds.contains(sessionId),
    );
    _sessionErrorAttentionIds.removeWhere(
      (sessionId) => !knownSessionIds.contains(sessionId),
    );
    _sessionUnreadCompletionTimestamps.removeWhere(
      (sessionId, _) => !knownSessionIds.contains(sessionId),
    );

    final currentSessionId = _currentSession?.id;
    if (currentSessionId != null) {
      _clearSessionAttentionForSession(currentSessionId);
    }
    _scheduleSessionUnreadHighlightTimer();
  }

  void _syncAttentionFromStatusMap(Map<String, SessionStatusInfo> statusMap) {
    for (final entry in statusMap.entries) {
      final sessionId = entry.key;
      final statusType = entry.value.type;
      switch (statusType) {
        case SessionStatusType.retry:
          _clearSessionUnreadCompletion(sessionId);
          break;
        case SessionStatusType.busy:
          _clearSessionUnreadCompletion(sessionId);
          break;
        case SessionStatusType.idle:
          // Keep sticky error attention on idle until the user focuses the
          // session or an explicit event clears it, avoiding silent dismissal
          // on snapshot refresh races.
          break;
      }
    }
    _pruneSessionAttentionStateToKnownSessions();
  }

  List<ChatSession> _sessionsForScopeId(String scopeId) {
    final normalizedScopeId = scopeId.trim();
    if (normalizedScopeId.isEmpty) {
      return const <ChatSession>[];
    }
    final contextKey = _composeContextKey(_activeServerId, normalizedScopeId);
    if (contextKey == _activeContextKey) {
      return _sessions;
    }
    return _contextSnapshots[contextKey]?.sessions ?? const <ChatSession>[];
  }

  Map<String, bool> _hiddenByArchivedAncestor(
    Map<String, ChatSession> sessionById,
  ) {
    final memo = <String, bool>{};

    bool resolve(String sessionId, Set<String> stack) {
      final cached = memo[sessionId];
      if (cached != null) {
        return cached;
      }
      if (!stack.add(sessionId)) {
        return false;
      }
      final session = sessionById[sessionId];
      final parentId = session?.parentId?.trim();
      if (session == null || parentId == null || parentId.isEmpty) {
        memo[sessionId] = false;
        stack.remove(sessionId);
        return false;
      }
      final parent = sessionById[parentId];
      final hidden =
          parent != null && (parent.archived || resolve(parentId, stack));
      memo[sessionId] = hidden;
      stack.remove(sessionId);
      return hidden;
    }

    for (final sessionId in sessionById.keys) {
      resolve(sessionId, <String>{});
    }
    return memo;
  }

  void _markSessionUnreadCompletion(String sessionId, {DateTime? timestamp}) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    // Child/task sessions should finish silently; only root sessions own
    // completion attention surfaces such as unread highlights and menu badges.
    final session = _sessionById(normalizedSessionId);
    final parentId = session?.parentId?.trim();
    if (session == null || (parentId != null && parentId.isNotEmpty)) {
      _clearSessionUnreadCompletion(normalizedSessionId);
      return;
    }
    _sessionUnreadCompletionIds.add(normalizedSessionId);
    _sessionUnreadCompletionTimestamps[normalizedSessionId] =
        timestamp ??
        _sessionUnreadCompletionTimestamps[normalizedSessionId] ??
        DateTime.now();
    _scheduleSessionUnreadHighlightTimer();
  }

  void _clearSessionUnreadCompletion(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    _sessionUnreadCompletionIds.remove(normalizedSessionId);
    _sessionUnreadCompletionTimestamps.remove(normalizedSessionId);
    _scheduleSessionUnreadHighlightTimer();
  }

  void _scheduleSessionUnreadHighlightTimer() {
    _sessionUnreadHighlightTimer?.cancel();
    _sessionUnreadHighlightTimer = null;

    final now = DateTime.now();
    DateTime? nextExpiry;
    for (final entry in _sessionUnreadCompletionTimestamps.entries) {
      final expiresAt = entry.value.add(const Duration(hours: 1));
      if (!expiresAt.isAfter(now)) {
        continue;
      }
      if (nextExpiry == null || expiresAt.isBefore(nextExpiry)) {
        nextExpiry = expiresAt;
      }
    }
    for (final snapshot in _contextSnapshots.values) {
      for (final entry in snapshot.sessionUnreadCompletionTimestamps.entries) {
        final expiresAt = entry.value.add(const Duration(hours: 1));
        if (!expiresAt.isAfter(now)) {
          continue;
        }
        if (nextExpiry == null || expiresAt.isBefore(nextExpiry)) {
          nextExpiry = expiresAt;
        }
      }
    }
    if (nextExpiry == null) {
      return;
    }

    _sessionUnreadHighlightTimer = Timer(nextExpiry.difference(now), () {
      _pruneExpiredUnreadHighlights();
      _notifyListeners();
    });
  }

  void _pruneExpiredUnreadHighlights() {
    final now = DateTime.now();
    _sessionUnreadCompletionTimestamps.removeWhere((sessionId, timestamp) {
      final expired = now.difference(timestamp) >= const Duration(hours: 1);
      if (expired) {
        _sessionUnreadCompletionIds.remove(sessionId);
      }
      return expired;
    });

    final updatedSnapshots = <String, _ChatContextSnapshot>{};
    for (final entry in _contextSnapshots.entries) {
      final snapshot = entry.value;
      final nextTimestamps = Map<String, DateTime>.from(
        snapshot.sessionUnreadCompletionTimestamps,
      );
      final nextIds = Set<String>.from(snapshot.sessionUnreadCompletionIds);
      var changed = false;
      nextTimestamps.removeWhere((sessionId, timestamp) {
        final expired = now.difference(timestamp) >= const Duration(hours: 1);
        if (expired) {
          nextIds.remove(sessionId);
          changed = true;
        }
        return expired;
      });
      if (!changed) {
        continue;
      }
      updatedSnapshots[entry.key] = _ChatContextSnapshot(
        sessions: snapshot.sessions,
        currentSession: snapshot.currentSession,
        messages: snapshot.messages,
        sessionStatusById: snapshot.sessionStatusById,
        pendingPermissionsBySession: snapshot.pendingPermissionsBySession,
        pendingQuestionsBySession: snapshot.pendingQuestionsBySession,
        sessionUnreadCompletionIds: nextIds,
        sessionUnreadCompletionTimestamps: nextTimestamps,
        sessionErrorAttentionIds: snapshot.sessionErrorAttentionIds,
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
        providerCatalogFetchedAtEpochMs:
            snapshot.providerCatalogFetchedAtEpochMs,
        agentCatalogFetchedAtEpochMs: snapshot.agentCatalogFetchedAtEpochMs,
      );
    }
    if (updatedSnapshots.isNotEmpty) {
      _contextSnapshots.addAll(updatedSnapshots);
    }
    _scheduleSessionUnreadHighlightTimer();
  }
}
