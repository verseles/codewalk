part of '../chat_provider.dart';

extension _ChatProviderPreferenceOps on ChatProvider {
  List<String> _decodeStoredModelKeys(String? raw, {int? maxItems}) {
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! List<dynamic>) {
        return <String>[];
      }
      final values = decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      return maxItems == null ? values : values.take(maxItems).toList();
    } catch (_) {
      return <String>[];
    }
  }

  void _storeCurrentContextSnapshot() {
    _contextSnapshots[_activeContextKey] = _ChatContextSnapshot(
      sessions: _sessions,
      currentSession: _currentSession,
      messages: _messages,
      sessionStatusById: _sessionStatusById,
      pendingPermissionsBySession: _pendingPermissionsBySession,
      pendingQuestionsBySession: _pendingQuestionsBySession,
      sessionUnreadCompletionIds: Set<String>.from(_sessionUnreadCompletionIds),
      sessionUnreadCompletionTimestamps: Map<String, DateTime>.from(
        _sessionUnreadCompletionTimestamps,
      ),
      sessionErrorAttentionIds: Set<String>.from(_sessionErrorAttentionIds),
      sessionChildrenById: _sessionChildrenById,
      sessionTodoById: _sessionTodoById,
      sessionDiffById: _sessionDiffById,
      sessionSearchQuery: _sessionSearchQuery,
      sessionListFilter: _sessionListFilter,
      sessionListSort: _sessionListSort,
      pinnedSessionIds: Set<String>.from(_pinnedSessionIds),
      sessionVisibleLimit: _sessionVisibleLimit,
      isNewChatDraftActive: _isNewChatDraftActive,
      activeSendDraft: _activeSendDraft,
      rejectedDraft: _rejectedDraft,
      questionSubmitFailedRequestIds: Set<String>.from(
        _questionSubmitFailedRequestIds,
      ),
      questionSubmitFailedAtById: Map<String, DateTime>.from(
        _questionSubmitFailedAtById,
      ),
      providers: List<Provider>.from(_providers),
      defaultModels: Map<String, String>.from(_defaultModels),
      connectedProviderIds: List<String>.from(_connectedProviderIds),
      agents: List<Agent>.from(_agents),
      selectedProviderId: _selectedProviderId,
      selectedModelId: _selectedModelId,
      selectedAgentName: _selectedAgentName,
      selectedVariantId: _selectedVariantId,
      recentModelKeys: List<String>.from(_recentModelKeys),
      recentAgentNames: List<String>.from(_recentAgentNames),
      recentVariantValuesByModel: _recentVariantValuesByModel.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      ),
      modelUsageCounts: Map<String, int>.from(_modelUsageCounts),
      selectedVariantByModel: Map<String, String>.from(_selectedVariantByModel),
      agentSelectionMemoryByAgent: Map<String, _AgentSelectionMemory>.from(
        _agentSelectionMemoryByAgent,
      ),
      providerCatalogFetchedAtEpochMs: _providerCatalogFetchedAtEpochMs,
      agentCatalogFetchedAtEpochMs: _agentCatalogFetchedAtEpochMs,
    );
    final serverId = _serverIdFromContextKey(_activeContextKey);
    final scopeId = _scopeIdFromContextKey(_activeContextKey);
    if (serverId != null && scopeId != null) {
      _writeThroughPinnedSessionScope(
        serverId: serverId,
        scopeId: scopeId,
        ids: _pinnedSessionIds,
      );
    }
  }

  void _restoreContextSnapshot(String contextKey) {
    final snapshot = _contextSnapshots[contextKey];
    if (snapshot == null) {
      _sessions = <ChatSession>[];
      _currentSession = null;
      _hasLoadedSessionsAuthoritatively = false;
      _pendingCurrentSessionHydrationId = null;
      _messages = <ChatMessage>[];
      _messagesVersion++;
      _sessionStatusById = <String, SessionStatusInfo>{};
      _pendingPermissionsBySession = <String, List<ChatPermissionRequest>>{};
      _pendingQuestionsBySession = <String, List<ChatQuestionRequest>>{};
      _sessionUnreadCompletionIds.clear();
      _sessionUnreadCompletionTimestamps.clear();
      _sessionErrorAttentionIds.clear();
      _sessionChildrenById = <String, List<ChatSession>>{};
      _sessionTodoById = <String, List<SessionTodo>>{};
      _sessionDiffById = <String, List<SessionDiff>>{};
      _sessionDiffLoadedById.clear();
      _sessionDiffErrorById.clear();
      _sessionSearchQuery = '';
      _sessionListFilter = SessionListFilter.active;
      _sessionListSort = SessionListSort.recent;
      _pinnedSessionIds = <String>{};
      _loadedPinnedSessionContextKey = null;
      _sessionVisibleLimit = 40;
      _isNewChatDraftActive = false;
      _clearActiveSendDraft();
      _clearRejectedDraft();
      _questionSubmitFailedRequestIds.clear();
      _questionSubmitFailedAtById.clear();
      _providers = <Provider>[];
      _defaultModels = <String, String>{};
      _connectedProviderIds = <String>[];
      _agents = <Agent>[];
      _providerCatalogAuthority = _CatalogAuthority.unknown;
      _agentCatalogAuthority = _CatalogAuthority.unknown;
      _providerCatalogFetchedAtEpochMs = null;
      _agentCatalogFetchedAtEpochMs = null;
      _selectedProviderId = null;
      _selectedModelId = null;
      _selectedAgentName = null;
      _selectedVariantId = null;
      _recentModelKeys = <String>[];
      _recentAgentNames = <String>[];
      _recentVariantValuesByModel = <String, List<String>>{};
      _modelUsageCounts = <String, int>{};
      _selectedVariantByModel = <String, String>{};
      _agentSelectionMemoryByAgent = <String, _AgentSelectionMemory>{};
      _threadPermissionsVersion++;
      return;
    }

    _sessions = _filterSessionsForCurrentContext(snapshot.sessions);
    _hasLoadedSessionsAuthoritatively = false;
    _currentSession = snapshot.currentSession;
    _dismissNotificationsForSession(_currentSession?.id);
    _messages = List<ChatMessage>.from(snapshot.messages);
    final restoredSessionId = _currentSession?.id;
    if (restoredSessionId != null && restoredSessionId.trim().isNotEmpty) {
      _cacheSessionMessages(restoredSessionId, _messages);
    }
    _messagesVersion++;
    _pendingLocalUserMessageIds.clear();
    _sessionStatusById = snapshot.sessionStatusById;
    _pendingPermissionsBySession = snapshot.pendingPermissionsBySession;
    _pendingQuestionsBySession = snapshot.pendingQuestionsBySession;
    _sessionUnreadCompletionIds
      ..clear()
      ..addAll(snapshot.sessionUnreadCompletionIds);
    _sessionUnreadCompletionTimestamps
      ..clear()
      ..addAll(snapshot.sessionUnreadCompletionTimestamps);
    _sessionErrorAttentionIds
      ..clear()
      ..addAll(snapshot.sessionErrorAttentionIds);
    _sessionChildrenById = snapshot.sessionChildrenById;
    _sessionTodoById = snapshot.sessionTodoById;
    _sessionDiffById = snapshot.sessionDiffById;
    // The diff loaded/error UI state is per-session, but the snapshot only
    // carries the diff list. Clear the bookkeeping so the restored context
    // does not advertise "loaded" for data that is not yet in the visible
    // timeline. The next loadSessionInsights call repopulates it.
    _sessionDiffLoadedById.clear();
    _sessionDiffErrorById.clear();
    _sessionSearchQuery = snapshot.sessionSearchQuery;
    _sessionListFilter = snapshot.sessionListFilter;
    _sessionListSort = snapshot.sessionListSort;
    _pinnedSessionIds = Set<String>.from(snapshot.pinnedSessionIds);
    _loadedPinnedSessionContextKey = contextKey;
    final serverId = _serverIdFromContextKey(contextKey);
    final scopeId = _scopeIdFromContextKey(contextKey);
    if (serverId != null && scopeId != null) {
      _writeThroughPinnedSessionScope(
        serverId: serverId,
        scopeId: scopeId,
        ids: _pinnedSessionIds,
      );
    }
    _sessionVisibleLimit = snapshot.sessionVisibleLimit;
    _isNewChatDraftActive = snapshot.isNewChatDraftActive;
    _activeSendDraft = snapshot.activeSendDraft;
    _rejectedDraft = snapshot.rejectedDraft;
    _questionSubmitFailedRequestIds
      ..clear()
      ..addAll(snapshot.questionSubmitFailedRequestIds);
    _questionSubmitFailedAtById
      ..clear()
      ..addAll(snapshot.questionSubmitFailedAtById);
    _providers = List<Provider>.from(snapshot.providers);
    _defaultModels = Map<String, String>.from(snapshot.defaultModels);
    _connectedProviderIds = List<String>.from(snapshot.connectedProviderIds);
    _agents = List<Agent>.from(snapshot.agents);
    _providerCatalogFetchedAtEpochMs = snapshot.providerCatalogFetchedAtEpochMs;
    _agentCatalogFetchedAtEpochMs = snapshot.agentCatalogFetchedAtEpochMs;
    _providerCatalogAuthority = _providerCatalogFetchedAtEpochMs == null
        ? _CatalogAuthority.unknown
        : _CatalogAuthority.stale;
    _agentCatalogAuthority = _agentCatalogFetchedAtEpochMs == null
        ? _CatalogAuthority.unknown
        : _CatalogAuthority.stale;
    _selectedProviderId = snapshot.selectedProviderId;
    _selectedModelId = snapshot.selectedModelId;
    _selectedAgentName = snapshot.selectedAgentName;
    _selectedVariantId = snapshot.selectedVariantId;
    _recentModelKeys = List<String>.from(snapshot.recentModelKeys);
    _recentAgentNames = List<String>.from(snapshot.recentAgentNames);
    _recentVariantValuesByModel = snapshot.recentVariantValuesByModel.map(
      (key, value) => MapEntry(key, List<String>.from(value)),
    );
    _modelUsageCounts = Map<String, int>.from(snapshot.modelUsageCounts);
    _selectedVariantByModel = Map<String, String>.from(
      snapshot.selectedVariantByModel,
    );
    _agentSelectionMemoryByAgent = Map<String, _AgentSelectionMemory>.from(
      snapshot.agentSelectionMemoryByAgent,
    );
    _pendingCurrentSessionHydrationId =
        !_isNewChatDraftActive && _currentSession != null && _messages.isEmpty
        ? _currentSession!.id
        : null;
    _pruneSessionAttentionStateToKnownSessions();
    _threadPermissionsVersion++;
  }

  Future<void> _loadModelPreferenceState({
    required String serverId,
    required String scopeId,
    required int fetchId,
    required String contextKey,
  }) async {
    final pinnedMutationRevision =
        _pinnedSessionMutationRevisionByContext[contextKey] ?? 0;
    final pinsAlreadyLoaded = _loadedPinnedSessionContextKey == contextKey;
    // Load every preference field into a local variable first, then swap
    // the instance fields atomically at the end. The previous clear-then-load
    // pattern opened an empty window for _favoriteModelKeys,
    // _pinnedSessionIds, _modelUsageCounts, and _selectedVariantByModel
    // between the clear and the awaited reload — during that window a
    // concurrent _persistSelection (e.g. from the Feature 7 late re-apply
    // hook in loadMessages) could capture the empty values via
    // _SelectionPersistenceSnapshot and overwrite the stored favorites and
    // pinned sessions.
    final recentJson = await localDataSource.getRecentModelsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    final loadedRecentModelKeys = _decodeStoredModelKeys(
      recentJson,
      maxItems: ChatProvider._maxRecentModels,
    );

    final favoritesJson = await localDataSource.getFavoriteModelsJson(
      serverId: serverId,
    );
    var loadedFavoriteModelKeys = _decodeStoredModelKeys(favoritesJson);
    if (loadedFavoriteModelKeys.isEmpty) {
      final legacyFavorites = await localDataSource
          .getLegacyFavoriteModelsJsonForServer(serverId);
      if (legacyFavorites.isNotEmpty) {
        final mergedFavorites = <String>{};
        for (final legacyRaw in legacyFavorites) {
          mergedFavorites.addAll(_decodeStoredModelKeys(legacyRaw));
        }
        loadedFavoriteModelKeys = mergedFavorites.toList(growable: false);
        if (loadedFavoriteModelKeys.isNotEmpty) {
          await localDataSource.saveFavoriteModelsJson(
            json.encode(loadedFavoriteModelKeys),
            serverId: serverId,
          );
          await localDataSource.deleteLegacyFavoriteModelsJsonForServer(
            serverId,
          );
        }
      }
    }

    final pinnedJson = await localDataSource.getPinnedSessionsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    var loadedPinnedSessionIds = <String>{};
    if (pinnedJson != null && pinnedJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(pinnedJson);
        if (decoded is List<dynamic>) {
          loadedPinnedSessionIds = decoded
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toSet();
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to restore pinned sessions preferences',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final usageJson = await localDataSource.getModelUsageCountsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    var loadedModelUsageCounts = <String, int>{};
    if (usageJson != null && usageJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(usageJson);
        if (decoded is Map<String, dynamic>) {
          loadedModelUsageCounts = decoded.map(
            (key, value) => MapEntry(
              key,
              value is num ? value.toInt() : int.tryParse('$value') ?? 0,
            ),
          );
          loadedModelUsageCounts.removeWhere((_, value) => value <= 0);
        }
      } catch (_) {
        // Keep the default empty map; corruption is non-fatal.
      }
    }

    final variantsJson = await localDataSource.getSelectedVariantMap(
      serverId: serverId,
      scopeId: scopeId,
    );
    var loadedSelectedVariantByModel = <String, String>{};
    if (variantsJson != null && variantsJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(variantsJson);
        if (decoded is Map<String, dynamic>) {
          loadedSelectedVariantByModel = decoded.map(
            (key, value) => MapEntry(key, '$value'),
          );
          loadedSelectedVariantByModel.removeWhere(
            (_, value) => value.trim().isEmpty,
          );
        }
      } catch (_) {
        // Keep the default empty map; corruption is non-fatal.
      }
    }

    final agentSelectionMemoryJson = await localDataSource
        .getAgentSelectionMemoryJson(serverId: serverId, scopeId: scopeId);
    final loadedAgentSelectionMemoryByAgent = _decodeAgentSelectionMemory(
      agentSelectionMemoryJson,
    );

    if (!_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      return;
    }

    // Atomic swap — no field is cleared until its replacement is ready.
    _recentModelKeys = loadedRecentModelKeys;
    _favoriteModelKeys = loadedFavoriteModelKeys;
    final pinsChangedWhileLoading =
        (_pinnedSessionMutationRevisionByContext[contextKey] ?? 0) !=
        pinnedMutationRevision;
    if (!pinsAlreadyLoaded && !pinsChangedWhileLoading) {
      _pinnedSessionIds = loadedPinnedSessionIds;
      _writeThroughPinnedSessionScope(
        serverId: serverId,
        scopeId: scopeId,
        ids: loadedPinnedSessionIds,
      );
    }
    _loadedPinnedSessionContextKey = contextKey;
    _modelUsageCounts = loadedModelUsageCounts;
    _selectedVariantByModel = loadedSelectedVariantByModel;
    _agentSelectionMemoryByAgent = loadedAgentSelectionMemoryByAgent;
    if (_hasLoadedSessionsAuthoritatively && contextKey == _activeContextKey) {
      _prunePinnedSessionIdsToKnownSessions();
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
    }
  }

  Future<void> _persistModelPreferenceState({
    required String serverId,
    required String scopeId,
  }) async {
    await localDataSource.saveRecentModelsJson(
      json.encode(_recentModelKeys),
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveFavoriteModelsJson(
      json.encode(_favoriteModelKeys),
      serverId: serverId,
    );
    final pinnedSessionIds = Set<String>.from(_pinnedSessionIds);
    await _persistPinnedSessionScope(
      serverId: serverId,
      scopeId: scopeId,
      ids: pinnedSessionIds,
    );
    await localDataSource.saveModelUsageCountsJson(
      json.encode(_modelUsageCounts),
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveSelectedVariantMap(
      json.encode(_selectedVariantByModel),
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveAgentSelectionMemoryJson(
      json.encode(_encodeAgentSelectionMemory()),
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Map<String, _AgentSelectionMemory> _decodeAgentSelectionMemory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, _AgentSelectionMemory>{};
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, _AgentSelectionMemory>{};
      }
      final result = <String, _AgentSelectionMemory>{};
      decoded.forEach((key, value) {
        if (value is! Map) {
          return;
        }
        final agentName = key.trim();
        final providerId = value['providerId']?.toString().trim() ?? '';
        final modelId = value['modelId']?.toString().trim() ?? '';
        final variantId = value['variantId']?.toString().trim();
        if (agentName.isEmpty || providerId.isEmpty || modelId.isEmpty) {
          return;
        }
        result[agentName] = _AgentSelectionMemory(
          providerId: providerId,
          modelId: modelId,
          variantId: variantId == null || variantId.isEmpty ? null : variantId,
        );
      });
      return result;
    } catch (_) {
      return <String, _AgentSelectionMemory>{};
    }
  }

  Map<String, Map<String, String?>> _encodeAgentSelectionMemory() {
    return _agentSelectionMemoryByAgent.map(
      (key, value) => MapEntry(key, <String, String?>{
        'providerId': value.providerId,
        'modelId': value.modelId,
        'variantId': value.variantId,
      }),
    );
  }

  void _rememberCurrentSelectionForAgent({String? agentName}) {
    final normalizedAgent = agentName?.trim();
    final providerId = _selectedProviderId?.trim();
    final modelId = _selectedModelId?.trim();
    if (normalizedAgent == null ||
        normalizedAgent.isEmpty ||
        providerId == null ||
        providerId.isEmpty ||
        modelId == null ||
        modelId.isEmpty) {
      return;
    }
    final variantId = _selectedVariantId?.trim();
    _agentSelectionMemoryByAgent[normalizedAgent] = _AgentSelectionMemory(
      providerId: providerId,
      modelId: modelId,
      variantId: variantId == null || variantId.isEmpty ? null : variantId,
    );
  }

  bool _restoreSelectionForAgent(String agentName) {
    final normalizedAgent = agentName.trim();
    if (normalizedAgent.isEmpty) {
      return false;
    }
    final memory = _agentSelectionMemoryByAgent[normalizedAgent];
    if (memory == null) {
      return false;
    }
    final provider = _providers
        .where((item) => item.id == memory.providerId)
        .firstOrNull;
    if (provider == null ||
        !_isUserSelectableModelId(provider, memory.modelId)) {
      return false;
    }
    _selectedProviderId = provider.id;
    _selectedModelId = memory.modelId;
    final model = provider.models[memory.modelId];
    final variantId = memory.variantId;
    if (variantId != null &&
        model != null &&
        model.variants.containsKey(variantId)) {
      _selectedVariantId = variantId;
    } else {
      _selectedVariantId = _resolveStoredVariantForSelection();
    }
    return true;
  }

  void _recordModelUsage() {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      return;
    }
    _recentModelKeys = List<String>.from(_recentModelKeys);
    final key = _modelKey(providerId, modelId);
    _recentModelKeys.remove(key);
    _recentModelKeys.insert(0, key);
    if (_recentModelKeys.length > ChatProvider._maxRecentModels) {
      _recentModelKeys = _recentModelKeys
          .take(ChatProvider._maxRecentModels)
          .toList();
    }
    _modelUsageCounts[key] = (_modelUsageCounts[key] ?? 0) + 1;
  }
}
