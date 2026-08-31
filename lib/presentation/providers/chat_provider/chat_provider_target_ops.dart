part of '../chat_provider.dart';

extension ChatProviderTargetOps on ChatProvider {
  ChatSession? _sessionForTarget(SessionActionTarget target) {
    if (!target.isValid) return null;
    return sessionForSessionTab(target.identity);
  }

  String _projectIdForTarget(SessionActionTarget target) {
    final trimmed = target.projectId?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return projectProvider.currentProjectId;
  }

  String? _directoryForTarget(SessionActionTarget target) {
    return target.directory;
  }

  bool _isActiveTarget(SessionActionTarget target) {
    final contextKey = _composeContextKey(target.serverId, target.directory);
    return contextKey == _activeContextKey;
  }

  void _applySessionForTarget(SessionActionTarget target, ChatSession session) {
    if (_isActiveTarget(target)) {
      _applySessionLocally(session);
      return;
    }
    final contextKey = _composeContextKey(target.serverId, target.directory);
    final existing = _contextSnapshots[contextKey];
    if (existing == null) {
      // No snapshot: update the tab directly so title changes are visible.
      final tabIndex = _sessionTabs.indexWhere((t) => t.identity == target.identity);
      if (tabIndex != -1) {
        final oldTab = _sessionTabs[tabIndex];
        final newTab = oldTab.copyWith(title: session.title ?? oldTab.title);
        final newTabs = List<SessionTabRecord>.from(_sessionTabs);
        newTabs[tabIndex] = newTab;
        _sessionTabs = List<SessionTabRecord>.unmodifiable(newTabs);
        if (_sessionTabsLoadedServerId == target.serverId) {
          final persistedIndex = _sessionTabsPersistedState.open.indexWhere(
            (p) => p.sessionId == target.sessionId && normalizeFilePath(p.directory) == target.directory,
          );
          if (persistedIndex != -1) {
            final oldPersisted = _sessionTabsPersistedState.open[persistedIndex];
            final newPersisted = PersistedSessionTab(
              directory: oldPersisted.directory,
              projectId: oldPersisted.projectId,
              sessionId: oldPersisted.sessionId,
              title: session.title ?? oldPersisted.title,
              lastOpenedAtMs: oldPersisted.lastOpenedAtMs,
              serverUpdatedAtMs: oldPersisted.serverUpdatedAtMs,
              seenQuestionIds: oldPersisted.seenQuestionIds,
              seenCompletionToken: oldPersisted.seenCompletionToken,
              seenErrorToken: oldPersisted.seenErrorToken,
            );
            final newOpen = List<PersistedSessionTab>.from(_sessionTabsPersistedState.open);
            newOpen[persistedIndex] = newPersisted;
            _sessionTabsPersistedState = PersistedSessionTabsState(
              open: newOpen,
              closed: _sessionTabsPersistedState.closed,
            );
            _sessionTabsPersistedStateEncoded = _sessionTabsPersistedState.encode();
            _scheduleSessionTabsPersistence();
          }
        }
      }
      return;
    }
    final newSessions = List<ChatSession>.from(existing.sessions);
    final idx = newSessions.indexWhere((s) => s.id == session.id);
    if (idx == -1) {
      newSessions.add(session);
    } else {
      newSessions[idx] = session;
    }
    // Keep sorted by time descending as active list does.
    newSessions.sort((a, b) => b.time.compareTo(a.time));
    final newCurrent =
        existing.currentSession?.id == session.id ? session : existing.currentSession;
    _contextSnapshots[contextKey] = _ChatContextSnapshot(
      sessions: newSessions,
      currentSession: newCurrent,
      messages: existing.messages,
      sessionStatusById: existing.sessionStatusById,
      pendingPermissionsBySession: existing.pendingPermissionsBySession,
      pendingQuestionsBySession: existing.pendingQuestionsBySession,
      sessionUnreadCompletionIds: existing.sessionUnreadCompletionIds,
      sessionUnreadCompletionTimestamps: existing.sessionUnreadCompletionTimestamps,
      sessionErrorAttentionIds: existing.sessionErrorAttentionIds,
      sessionChildrenById: existing.sessionChildrenById,
      sessionTodoById: existing.sessionTodoById,
      sessionDiffById: existing.sessionDiffById,
      sessionSearchQuery: existing.sessionSearchQuery,
      sessionListFilter: existing.sessionListFilter,
      sessionListSort: existing.sessionListSort,
      pinnedSessionIds: existing.pinnedSessionIds,
      sessionVisibleLimit: existing.sessionVisibleLimit,
      isNewChatDraftActive: existing.isNewChatDraftActive,
      activeSendDraft: existing.activeSendDraft,
      rejectedDraft: existing.rejectedDraft,
      questionSubmitFailedRequestIds: existing.questionSubmitFailedRequestIds,
      questionSubmitFailedAtById: existing.questionSubmitFailedAtById,
      providers: existing.providers,
      defaultModels: existing.defaultModels,
      connectedProviderIds: existing.connectedProviderIds,
      agents: existing.agents,
      selectedProviderId: existing.selectedProviderId,
      selectedModelId: existing.selectedModelId,
      selectedAgentName: existing.selectedAgentName,
      selectedVariantId: existing.selectedVariantId,
      recentModelKeys: existing.recentModelKeys,
      recentAgentNames: existing.recentAgentNames,
      recentVariantValuesByModel: existing.recentVariantValuesByModel,
      modelUsageCounts: existing.modelUsageCounts,
      selectedVariantByModel: existing.selectedVariantByModel,
      agentSelectionMemoryByAgent: existing.agentSelectionMemoryByAgent,
      providerCatalogFetchedAtEpochMs: existing.providerCatalogFetchedAtEpochMs,
      agentCatalogFetchedAtEpochMs: existing.agentCatalogFetchedAtEpochMs,
    );
  }

  void _removeSessionForTarget(SessionActionTarget target, String sessionId) {
    if (_isActiveTarget(target)) {
      _removeSessionById(sessionId, removePin: false);
      _sortSessionsInPlace();
      return;
    }
    final contextKey = _composeContextKey(target.serverId, target.directory);
    final existing = _contextSnapshots[contextKey];
    if (existing == null) return;
    final newSessions = existing.sessions.where((s) => s.id != sessionId).toList();
    if (newSessions.length == existing.sessions.length) return;
    final newCurrent = existing.currentSession?.id == sessionId ? newSessions.firstOrNull : existing.currentSession;
    _contextSnapshots[contextKey] = _ChatContextSnapshot(
      sessions: newSessions,
      currentSession: newCurrent,
      messages: existing.messages,
      sessionStatusById: existing.sessionStatusById,
      pendingPermissionsBySession: existing.pendingPermissionsBySession,
      pendingQuestionsBySession: existing.pendingQuestionsBySession,
      sessionUnreadCompletionIds: existing.sessionUnreadCompletionIds,
      sessionUnreadCompletionTimestamps: existing.sessionUnreadCompletionTimestamps,
      sessionErrorAttentionIds: existing.sessionErrorAttentionIds,
      sessionChildrenById: existing.sessionChildrenById,
      sessionTodoById: existing.sessionTodoById,
      sessionDiffById: existing.sessionDiffById,
      sessionSearchQuery: existing.sessionSearchQuery,
      sessionListFilter: existing.sessionListFilter,
      sessionListSort: existing.sessionListSort,
      pinnedSessionIds: existing.pinnedSessionIds,
      sessionVisibleLimit: existing.sessionVisibleLimit,
      isNewChatDraftActive: existing.isNewChatDraftActive,
      activeSendDraft: existing.activeSendDraft,
      rejectedDraft: existing.rejectedDraft,
      questionSubmitFailedRequestIds: existing.questionSubmitFailedRequestIds,
      questionSubmitFailedAtById: existing.questionSubmitFailedAtById,
      providers: existing.providers,
      defaultModels: existing.defaultModels,
      connectedProviderIds: existing.connectedProviderIds,
      agents: existing.agents,
      selectedProviderId: existing.selectedProviderId,
      selectedModelId: existing.selectedModelId,
      selectedAgentName: existing.selectedAgentName,
      selectedVariantId: existing.selectedVariantId,
      recentModelKeys: existing.recentModelKeys,
      recentAgentNames: existing.recentAgentNames,
      recentVariantValuesByModel: existing.recentVariantValuesByModel,
      modelUsageCounts: existing.modelUsageCounts,
      selectedVariantByModel: existing.selectedVariantByModel,
      agentSelectionMemoryByAgent: existing.agentSelectionMemoryByAgent,
      providerCatalogFetchedAtEpochMs: existing.providerCatalogFetchedAtEpochMs,
      agentCatalogFetchedAtEpochMs: existing.agentCatalogFetchedAtEpochMs,
    );
  }

  Future<bool> _togglePinnedForTarget(SessionActionTarget target, String sessionId) async {
    final serverId = target.serverId;
    final directory = target.directory;
    if (serverId.isEmpty || directory.isEmpty || sessionId.trim().isEmpty) return false;
    final normalizedDirectory = normalizeFilePath(directory);
    final normalizedSessionId = sessionId.trim();
    // Determine current pinned state for that scope.
    final effectiveScopes = _effectivePinnedSessionScopes(serverId);
    final currentlyPinned = effectiveScopes[normalizedDirectory]?.contains(normalizedSessionId) ?? false;
    final nextPinned = !currentlyPinned;
    // Use tab pin helpers.
    final identity = target.identity;
    final changed = _setSessionTabPin(
      identity,
      pinned: nextPinned,
      pinScopeId: normalizedDirectory,
      persist: true,
    );
    // Also update active pin set if target is active scope.
    if (_isActiveTarget(target)) {
      _setActiveSessionPin(
        serverId: serverId,
        scopeId: normalizedDirectory,
        sessionId: normalizedSessionId,
        pinned: nextPinned,
      );
      _sortSessionsInPlace();
      await _persistPinnedSessionScope(
        serverId: serverId,
        scopeId: normalizedDirectory,
        ids: _pinnedSessionIds,
      );
      await Future.wait(_pinnedSessionWriteQueueByScope.values.toList());
      _reconcileSessionTabs(forcePersistence: true, notify: false);
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      notifyListeners();
      return changed;
    } else {
      // For inactive scope, ensure snapshot and by-scope maps are updated.
      // _setSessionTabPin already updated the per-scope map via _writeThrough...
      // Need to update snapshot's pinned ids if snapshot exists.
      final contextKey = _composeContextKey(serverId, normalizedDirectory);
      final snapshot = _contextSnapshots[contextKey];
      if (snapshot != null) {
        final newPinned = Set<String>.from(snapshot.pinnedSessionIds);
        if (nextPinned) {
          newPinned.add(normalizedSessionId);
        } else {
          newPinned.remove(normalizedSessionId);
        }
        _contextSnapshots[contextKey] = _ChatContextSnapshot(
          sessions: snapshot.sessions,
          currentSession: snapshot.currentSession,
          messages: snapshot.messages,
          sessionStatusById: snapshot.sessionStatusById,
          pendingPermissionsBySession: snapshot.pendingPermissionsBySession,
          pendingQuestionsBySession: snapshot.pendingQuestionsBySession,
          sessionUnreadCompletionIds: snapshot.sessionUnreadCompletionIds,
          sessionUnreadCompletionTimestamps: snapshot.sessionUnreadCompletionTimestamps,
          sessionErrorAttentionIds: snapshot.sessionErrorAttentionIds,
          sessionChildrenById: snapshot.sessionChildrenById,
          sessionTodoById: snapshot.sessionTodoById,
          sessionDiffById: snapshot.sessionDiffById,
          sessionSearchQuery: snapshot.sessionSearchQuery,
          sessionListFilter: snapshot.sessionListFilter,
          sessionListSort: snapshot.sessionListSort,
          pinnedSessionIds: newPinned,
          sessionVisibleLimit: snapshot.sessionVisibleLimit,
          isNewChatDraftActive: snapshot.isNewChatDraftActive,
          activeSendDraft: snapshot.activeSendDraft,
          rejectedDraft: snapshot.rejectedDraft,
          questionSubmitFailedRequestIds: snapshot.questionSubmitFailedRequestIds,
          questionSubmitFailedAtById: snapshot.questionSubmitFailedAtById,
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
        // Also ensure by-scope map is correct.
        _writeThroughPinnedSessionScope(
          serverId: serverId,
          scopeId: normalizedDirectory,
          ids: newPinned,
        );
        unawaited(
          _persistPinnedSessionScope(
            serverId: serverId,
            scopeId: normalizedDirectory,
            ids: newPinned,
          ),
        );
      }
      _reconcileSessionTabs(forcePersistence: false, notify: true);
      return changed;
    }
  }
}
