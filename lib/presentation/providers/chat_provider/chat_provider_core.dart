part of '../chat_provider.dart';

extension _ChatProviderCorePart on ChatProvider {
  void _applyProviderCatalogSnapshot(
    _ProviderCatalogSnapshot snapshot, {
    bool notify = true,
  }) {
    _providers = snapshot.providers;
    _defaultModels = snapshot.defaultModels;
    _connectedProviderIds = snapshot.connected;
    _agents = snapshot.agents;
    _providerCatalogFetchedAtEpochMs = snapshot.providerFetchedAtEpochMs;
    _agentCatalogFetchedAtEpochMs = snapshot.agentFetchedAtEpochMs;
    _providerCatalogAuthority = snapshot.providerFetchedAtEpochMs == null
        ? _CatalogAuthority.unknown
        : _CatalogAuthority.stale;
    _agentCatalogAuthority = snapshot.agentFetchedAtEpochMs == null
        ? _CatalogAuthority.unknown
        : _CatalogAuthority.stale;
    if (notify) {
      _notifyListeners();
    }
  }

  String _encodeProviderCatalogSnapshotJson(_ProviderCatalogSnapshot snapshot) {
    final payload = <String, dynamic>{
      'providers': snapshot.providers
          .map(_providerCatalogProviderToJson)
          .toList(),
      'default': snapshot.defaultModels,
      'connected': snapshot.connected,
      'agents': snapshot.agents
          .map(
            (agent) => <String, dynamic>{
              'name': agent.name,
              'mode': agent.mode,
              'hidden': agent.hidden,
              'native': agent.native,
              'color': agent.color,
            },
          )
          .toList(growable: false),
      'providerFetchedAt': snapshot.providerFetchedAtEpochMs,
      'agentFetchedAt': snapshot.agentFetchedAtEpochMs,
    };
    return json.encode(payload);
  }

  Map<String, dynamic> _providerCatalogProviderToJson(Provider provider) {
    return <String, dynamic>{
      'id': provider.id,
      'name': provider.name,
      'env': provider.env,
      'api': provider.api,
      'npm': provider.npm,
      'models': provider.models.map(
        (key, value) => MapEntry(key, _providerCatalogModelToJson(value)),
      ),
    };
  }

  Map<String, dynamic> _providerCatalogModelToJson(Model model) {
    return <String, dynamic>{
      'id': model.id,
      'name': model.name,
      'release_date': model.releaseDate,
      'attachment': model.attachment,
      'reasoning': model.reasoning,
      'temperature': model.temperature,
      'tool_call': model.toolCall,
      'cost': <String, dynamic>{
        'input': model.cost.input,
        'output': model.cost.output,
        'cache_read': model.cost.cacheRead,
        'cache_write': model.cost.cacheWrite,
      },
      'limit': <String, dynamic>{
        'context': model.limit.context,
        'output': model.limit.output,
      },
      'options': model.options,
      'variants': model.variants.map(
        (key, value) => MapEntry(key, <String, dynamic>{
          'name': value.name,
          'description': value.description,
          'metadata': value.metadata,
        }),
      ),
      'knowledge': model.knowledge,
      'last_updated': model.lastUpdated,
      'modalities': model.modalities,
      'open_weights': model.openWeights,
      'hidden': model.hidden,
      'status': model.status,
    };
  }

  _ProviderCatalogSnapshot? _decodeProviderCatalogSnapshot(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final response = ProvidersResponseModel.fromJson(decoded).toDomain();
    final agents = (decoded['agents'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map(
          (raw) => Agent(
            name: raw['name']?.toString() ?? '',
            mode: raw['mode']?.toString() ?? '',
            hidden: raw['hidden'] == true,
            native: raw['native'] == true,
            color: raw['color']?.toString(),
          ),
        )
        .where((agent) => agent.name.trim().isNotEmpty)
        .toList(growable: false);
    return _ProviderCatalogSnapshot(
      providers: response.providers,
      defaultModels: response.defaultModels,
      connected: response.connected,
      agents: agents,
      providerFetchedAtEpochMs: (decoded['providerFetchedAt'] as num?)?.toInt(),
      agentFetchedAtEpochMs: (decoded['agentFetchedAt'] as num?)?.toInt(),
    );
  }

  Future<bool> _restoreProviderCatalogSnapshot({
    required String serverId,
    required String scopeId,
    bool notify = true,
    int? fetchId,
    String? contextKey,
  }) async {
    final raw = await localDataSource.getProviderCatalogCacheJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (raw == null || raw.trim().isEmpty) {
      return false;
    }
    if (fetchId != null &&
        contextKey != null &&
        !_isProviderInitializationCurrent(
          fetchId: fetchId,
          contextKey: contextKey,
        )) {
      return false;
    }
    try {
      final snapshot = _decodeProviderCatalogSnapshot(raw);
      if (snapshot == null || snapshot.isEmpty) {
        return false;
      }
      _applyProviderCatalogSnapshot(snapshot, notify: notify);
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to restore cached provider catalog',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool _isProviderInitializationCurrent({
    required int fetchId,
    required String contextKey,
  }) {
    return fetchId == _providersFetchId && _activeContextKey == contextKey;
  }

  Future<void> _persistProviderCatalogSnapshot({
    required String serverId,
    required String scopeId,
    required _ProviderCatalogSnapshot snapshot,
  }) async {
    if (serverId.trim().isEmpty || snapshot.isEmpty) {
      return;
    }
    await localDataSource.saveProviderCatalogCacheJson(
      _encodeProviderCatalogSnapshotJson(snapshot),
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Future<void> _initializeProvidersInternal() async {
    if (!_featureFlagLogged) {
      _featureFlagLogged = true;
      AppLogger.info(
        'refreshless_feature_enabled=$_refreshlessRealtimeEnabled',
      );
    }
    final fetchId = ++_providersFetchId;
    final storedServerId = await localDataSource.getActiveServerId();
    if (fetchId != _providersFetchId) {
      return;
    }
    final serverId = storedServerId == null || storedServerId.isEmpty
        ? 'legacy'
        : storedServerId;
    _activeServerId = serverId;
    final scopeId = _resolveContextScopeId();
    final directory = projectProvider.currentDirectory;
    final contextKey = _composeContextKey(serverId, scopeId);
    _activeContextKey = contextKey;
    final hadVisibleCatalog =
        _providers.isNotEmpty ||
        _agents.isNotEmpty ||
        await _restoreProviderCatalogSnapshot(
          serverId: serverId,
          scopeId: scopeId,
          fetchId: fetchId,
          contextKey: contextKey,
        );
    if (!_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      return;
    }
    if (_providerCatalogAuthority != _CatalogAuthority.unknown) {
      _providerCatalogAuthority = _CatalogAuthority.stale;
    }
    if (_agentCatalogAuthority != _CatalogAuthority.unknown) {
      _agentCatalogAuthority = _CatalogAuthority.stale;
    }
    _setProvidersRefreshState(
      ChatProvidersRefreshState.loading,
      errorMessage: null,
      notify: !hadVisibleCatalog,
    );
    try {
      var failed = false;
      var providersRefreshed = false;
      var connected = List<String>.from(_connectedProviderIds);
      final result = await getProviders(directory: directory);
      if (!_isProviderInitializationCurrent(
        fetchId: fetchId,
        contextKey: contextKey,
      )) {
        return;
      }
      result.fold(
        (failure) {
          AppLogger.warn('Failed to load providers: ${failure.toString()}');
          final message = failure.message.trim();
          if (_providers.isEmpty) {
            failed = true;
            _setProvidersRefreshState(
              ChatProvidersRefreshState.failed,
              errorMessage: message.isEmpty
                  ? (L10nBridge.current?.chatFailedToRefreshProviders ??
                        'Failed to refresh providers and models')
                  : message,
            );
          }
        },
        (providersResponse) {
          providersRefreshed = true;
          _providers = providersResponse.providers;
          _defaultModels = providersResponse.defaultModels;
          _connectedProviderIds = List<String>.from(
            providersResponse.connected,
          );
          connected = providersResponse.connected;
          _providerCatalogAuthority = _CatalogAuthority.authoritative;
          _providerCatalogFetchedAtEpochMs =
              DateTime.now().millisecondsSinceEpoch;
        },
      );

      if (failed) {
        return;
      }

      await _refreshAgents(
        serverId: serverId,
        scopeId: scopeId,
        directory: directory,
        fetchId: fetchId,
        contextKey: contextKey,
      );
      if (!_isProviderInitializationCurrent(
        fetchId: fetchId,
        contextKey: contextKey,
      )) {
        return;
      }
      final agentsRefreshed =
          _agentCatalogAuthority == _CatalogAuthority.authoritative;
      await _loadModelPreferenceState(
        serverId: serverId,
        scopeId: scopeId,
        fetchId: fetchId,
        contextKey: contextKey,
      );
      if (!_isProviderInitializationCurrent(
        fetchId: fetchId,
        contextKey: contextKey,
      )) {
        return;
      }
      await _loadSessionSelectionOverridesState(
        serverId: serverId,
        scopeId: scopeId,
        fetchId: fetchId,
        contextKey: contextKey,
      );
      if (!_isProviderInitializationCurrent(
        fetchId: fetchId,
        contextKey: contextKey,
      )) {
        return;
      }

      if (_providers.isNotEmpty) {
        _RemoteChatSelection? remoteSelection;
        if (_isExperimentalMultiDeviceSyncEnabled) {
          remoteSelection = await _loadRemoteChatSelection(
            directory: directory,
          );
          if (!_isProviderInitializationCurrent(
            fetchId: fetchId,
            contextKey: contextKey,
          )) {
            return;
          }
          if (remoteSelection != null) {
            _mergeRemoteSessionSelectionOverrides(
              remoteSelection.sessionOverridesBySessionId,
            );
          }
        }

        final persistedProvider = await localDataSource.getSelectedProvider(
          serverId: serverId,
          scopeId: scopeId,
        );
        final persistedModel = await localDataSource.getSelectedModel(
          serverId: serverId,
          scopeId: scopeId,
        );
        final persistedAgent = agentsRefreshed
            ? null
            : await localDataSource.getSelectedAgent(
                serverId: serverId,
                scopeId: scopeId,
              );
        if (!_isProviderInitializationCurrent(
          fetchId: fetchId,
          contextKey: contextKey,
        )) {
          return;
        }
        if (!agentsRefreshed) {
          final storedAgent = persistedAgent?.trim();
          if (storedAgent != null && storedAgent.isNotEmpty) {
            _selectedAgentName = storedAgent;
          }
        }

        if (!providersRefreshed) {
          if (remoteSelection != null && remoteSelection.hasModel) {
            _selectedProviderId = remoteSelection.providerId;
            _selectedModelId = remoteSelection.modelId;
          } else {
            final storedProvider = persistedProvider?.trim();
            final storedModel = persistedModel?.trim();
            if (storedProvider != null && storedProvider.isNotEmpty) {
              _selectedProviderId = storedProvider;
            }
            if (storedModel != null && storedModel.isNotEmpty) {
              _selectedModelId = storedModel;
            }
          }
          final remoteAgent = remoteSelection?.agentName?.trim();
          final storedAgent = persistedAgent?.trim();
          if (remoteAgent != null && remoteAgent.isNotEmpty) {
            _selectedAgentName = remoteAgent;
          } else if (storedAgent != null && storedAgent.isNotEmpty) {
            _selectedAgentName = storedAgent;
          }
          final modelKey = _currentModelKey();
          final storedVariant = modelKey == null
              ? null
              : _selectedVariantByModel[modelKey];
          if (storedVariant != null && storedVariant.isNotEmpty) {
            _selectedVariantId = storedVariant;
          }
          _applySelectionPriorityForCurrentSession();
          _storeCurrentContextSnapshot();
          _notifyListeners();
          if (agentsRefreshed) {
            final catalogSnapshot = _ProviderCatalogSnapshot(
              providers: List<Provider>.from(_providers),
              defaultModels: Map<String, String>.from(_defaultModels),
              connected: List<String>.from(_connectedProviderIds),
              agents: List<Agent>.from(_agents),
              providerFetchedAtEpochMs: _providerCatalogFetchedAtEpochMs,
              agentFetchedAtEpochMs: _agentCatalogFetchedAtEpochMs,
            );
            unawaited(
              _persistProviderCatalogSnapshot(
                serverId: serverId,
                scopeId: scopeId,
                snapshot: catalogSnapshot,
              ).catchError((Object error, StackTrace stackTrace) {
                AppLogger.warn(
                  'Failed to persist composer catalog snapshot',
                  error: error,
                  stackTrace: stackTrace,
                );
              }),
            );
          }
        } else {
          Provider? selectedProvider;

          if (remoteSelection != null && remoteSelection.hasModel) {
            final remote = remoteSelection;
            final candidateProvider = _userSelectableProviderById(
              remote.providerId,
            );
            if (candidateProvider != null &&
                _isUserSelectableModelId(candidateProvider, remote.modelId!)) {
              selectedProvider = candidateProvider;
            }
          }

          selectedProvider ??= _userSelectableProviderById(persistedProvider);

          // Try connected providers first
          if (selectedProvider == null) {
            for (final connectedId in connected) {
              selectedProvider = _userSelectableProviderById(connectedId);
              if (selectedProvider != null) break;
            }
          }

          // Then try providers from recent usage.
          if (selectedProvider == null) {
            for (final recentModelKey in _recentModelKeys) {
              final providerId = _providerFromModelKey(recentModelKey);
              if (providerId == null) {
                continue;
              }
              final modelId = _modelFromModelKey(recentModelKey);
              final candidateProvider = _userSelectableProviderById(providerId);
              if (candidateProvider != null &&
                  modelId != null &&
                  _isUserSelectableModelId(candidateProvider, modelId)) {
                selectedProvider = candidateProvider;
                break;
              }
            }
          }

          // Fall back to first available provider
          selectedProvider ??= _providers
              .where(_hasUserSelectableModels)
              .firstOrNull;

          if (selectedProvider == null) {
            _selectedProviderId = null;
            _selectedModelId = null;
          } else {
            _selectedProviderId = selectedProvider.id;
            _selectedModelId = null;

            if (remoteSelection != null &&
                remoteSelection.hasModel &&
                remoteSelection.providerId == selectedProvider.id &&
                _isUserSelectableModelId(
                  selectedProvider,
                  remoteSelection.modelId!,
                )) {
              _selectedModelId = remoteSelection.modelId;
            } else if (persistedModel != null &&
                _isUserSelectableModelId(selectedProvider, persistedModel)) {
              _selectedModelId = persistedModel;
            } else {
              for (final recentModelKey in _recentModelKeys) {
                final providerId = _providerFromModelKey(recentModelKey);
                final modelId = _modelFromModelKey(recentModelKey);
                if (providerId != selectedProvider.id || modelId == null) {
                  continue;
                }
                if (_isUserSelectableModelId(selectedProvider, modelId)) {
                  _selectedModelId = modelId;
                  break;
                }
              }
            }

            if (_selectedModelId == null && _modelUsageCounts.isNotEmpty) {
              String? mostUsedModelId;
              var mostUsedCount = -1;
              for (final entry in selectedProvider.models.entries) {
                if (!_isUserSelectableModel(selectedProvider, entry.value)) {
                  continue;
                }
                final modelId = entry.key;
                final usage =
                    _modelUsageCounts[_modelKey(
                      selectedProvider.id,
                      modelId,
                    )] ??
                    0;
                if (usage > mostUsedCount) {
                  mostUsedCount = usage;
                  mostUsedModelId = modelId;
                }
              }
              if (mostUsedModelId != null && mostUsedCount > 0) {
                _selectedModelId = mostUsedModelId;
              }
            }

            if (_selectedModelId == null &&
                selectedProvider.id == openCodeZenProviderId &&
                _isUserSelectableModelId(selectedProvider, 'big-pickle')) {
              _selectedModelId = 'big-pickle';
            }

            if (_selectedModelId == null &&
                _defaultModels.containsKey(selectedProvider.id)) {
              final defaultModelId = _defaultModels[selectedProvider.id];
              if (defaultModelId != null &&
                  _isUserSelectableModelId(selectedProvider, defaultModelId)) {
                _selectedModelId = defaultModelId;
              }
            }

            _selectedModelId ??= _firstUserSelectableModelId(selectedProvider);
          }

          final remoteAgentName = remoteSelection?.agentName;
          if (remoteAgentName != null && remoteAgentName.isNotEmpty) {
            final resolvedAgent = _resolvePreferredAgentName(
              _agents,
              remoteAgentName,
            );
            if (resolvedAgent != null) {
              _selectedAgentName = resolvedAgent;
            }
          }

          _selectedVariantId = _resolveStoredVariantForSelection();
          if (remoteSelection != null) {
            _applyRemoteVariantSelection(remoteSelection);
          }
          _applySelectionPriorityForCurrentSession();

          _storeCurrentContextSnapshot();
          _notifyListeners();

          if (providersRefreshed || agentsRefreshed) {
            final catalogSnapshot = _ProviderCatalogSnapshot(
              providers: List<Provider>.from(_providers),
              defaultModels: Map<String, String>.from(_defaultModels),
              connected: List<String>.from(_connectedProviderIds),
              agents: List<Agent>.from(_agents),
              providerFetchedAtEpochMs: _providerCatalogFetchedAtEpochMs,
              agentFetchedAtEpochMs: _agentCatalogFetchedAtEpochMs,
            );
            unawaited(
              _persistProviderCatalogSnapshot(
                serverId: serverId,
                scopeId: scopeId,
                snapshot: catalogSnapshot,
              ).catchError((Object error, StackTrace stackTrace) {
                AppLogger.warn(
                  'Failed to persist composer catalog snapshot',
                  error: error,
                  stackTrace: stackTrace,
                );
              }),
            );
          }

          final selectedProviderId = _selectedProviderId;
          final selectedModelId = _selectedModelId;
          final selectedAgentName = _selectedAgentName;

          if (selectedProviderId != null) {
            await localDataSource.saveSelectedProvider(
              selectedProviderId,
              serverId: serverId,
              scopeId: scopeId,
            );
          }
          if (selectedModelId != null) {
            await localDataSource.saveSelectedModel(
              selectedModelId,
              serverId: serverId,
              scopeId: scopeId,
            );
          }
          await localDataSource.saveSelectedAgent(
            selectedAgentName,
            serverId: serverId,
            scopeId: scopeId,
          );
          if (!_isProviderInitializationCurrent(
            fetchId: fetchId,
            contextKey: contextKey,
          )) {
            return;
          }

          if (selectedProviderId != null && selectedModelId != null) {
            _lastSyncedRemoteModelKey = _modelKey(
              selectedProviderId,
              selectedModelId,
            );
          } else {
            _lastSyncedRemoteModelKey = null;
          }
          _lastSyncedRemoteAgentName = selectedAgentName;
          if (_lastSyncedRemoteVariantKey == null) {
            final modelKey = _currentModelKey();
            final agentName = _selectedAgentName;
            if (modelKey != null && agentName != null && agentName.isNotEmpty) {
              final variantValue =
                  (_selectedVariantId == null || _selectedVariantId!.isEmpty)
                  ? ChatProvider._remoteAutoVariantValue
                  : _selectedVariantId!;
              _lastSyncedRemoteVariantKey = _remoteVariantSyncKey(
                agentName: agentName,
                modelKey: modelKey,
                variantValue: variantValue,
              );
            }
          }
          _lastSyncedRemoteSessionOverridesSignature =
              _sessionOverridesSignature(
                _sessionOverridesForContext(_activeContextKey),
              );

          AppLogger.debug(
            'Selected agent=$_selectedAgentName provider=$_selectedProviderId model=$_selectedModelId variant=$_selectedVariantId server=$serverId',
          );
        }
      } else {
        _selectedProviderId = null;
        _selectedModelId = null;
        _selectedVariantId = null;
        _connectedProviderIds = <String>[];
        _recentModelKeys = <String>[];
        _recentAgentNames = <String>[];
        _recentVariantValuesByModel = <String, List<String>>{};
        _modelUsageCounts = <String, int>{};
        _selectedVariantByModel = <String, String>{};
        _shortcutCycleStateByDomain.clear();
        _lastSyncedRemoteModelKey = null;
        _lastSyncedRemoteAgentName = null;
        _lastSyncedRemoteVariantKey = null;
        _lastSyncedRemoteSessionOverridesSignature = null;
        _pendingRemoteSelectionSync = false;
        _pendingRemoteSelectionSyncSince = null;
        _selectionSyncTransactionPhase = _SelectionSyncTransactionPhase.idle;
        _storeCurrentContextSnapshot();
        _notifyListeners();
      }
    } catch (e, stackTrace) {
      if (!_isProviderInitializationCurrent(
        fetchId: fetchId,
        contextKey: contextKey,
      )) {
        return;
      }
      AppLogger.error(
        'Exception while initializing providers',
        error: e,
        stackTrace: stackTrace,
      );
      _setProvidersRefreshState(
        ChatProvidersRefreshState.failed,
        errorMessage:
            L10nBridge.current?.chatFailedToRefreshProviders ??
            'Failed to refresh providers and models',
      );
    }
    if (_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      if (_refreshlessRealtimeEnabled && !_isForegroundActive) {
        _setSyncState(ChatSyncState.reconnecting, reason: 'background-init');
      } else if (_isInResumeGrace) {
        _setSyncState(ChatSyncState.connected, reason: 'resume-grace-init');
      } else if (_cellularDataSaverService.isDataSaverActive &&
          !_shouldKeepRealtimeActiveForDataSaver) {
        _idleRealtimePausedForDataSaver = true;
        _setSyncState(ChatSyncState.connected, reason: 'data-saver-init');
      } else {
        await _startRealtimeEventSubscription();
        if (!_isProviderInitializationCurrent(
          fetchId: fetchId,
          contextKey: contextKey,
        )) {
          return;
        }
      }
      if (!_cellularDataSaverService.shouldSuppressBackgroundWork) {
        await _loadPendingInteractions();
        if (!_isProviderInitializationCurrent(
          fetchId: fetchId,
          contextKey: contextKey,
        )) {
          return;
        }
      }
      if (!_cellularDataSaverService.shouldSuppressBackgroundWork) {
        await refreshSessionStatusSnapshot();
        if (!_isProviderInitializationCurrent(
          fetchId: fetchId,
          contextKey: contextKey,
        )) {
          return;
        }
      }
      _setProvidersRefreshState(
        ChatProvidersRefreshState.ready,
        errorMessage: null,
        notify: false,
      );
      _notifyListeners();
    }
  }
}
