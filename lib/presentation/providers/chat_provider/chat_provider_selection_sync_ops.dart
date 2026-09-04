part of '../chat_provider.dart';

extension _ChatProviderSelectionSyncOps on ChatProvider {
  _RemoteChatSelection _parseRemoteChatSelection(dynamic rawConfig) {
    if (rawConfig is! Map) {
      return const _RemoteChatSelection();
    }

    final config = Map<String, dynamic>.from(rawConfig);
    String? providerId;
    String? modelId;
    String? remoteAgent;

    final namespacedConfig = _codewalkSyncConfig(config);
    if (namespacedConfig != null) {
      final selectionRaw = namespacedConfig[ChatProvider._configSelectionKey];
      if (selectionRaw is Map) {
        final selection = Map<String, dynamic>.from(selectionRaw);
        final namespacedModel = selection['model'];
        if (namespacedModel is String) {
          providerId = _providerFromModelKey(namespacedModel.trim());
          modelId = _modelFromModelKey(namespacedModel.trim());
        } else if (namespacedModel is Map) {
          providerId =
              (namespacedModel['providerID'] ??
                      namespacedModel['providerId'] ??
                      namespacedModel['provider'])
                  as String?;
          modelId =
              (namespacedModel['modelID'] ??
                      namespacedModel['modelId'] ??
                      namespacedModel['id'])
                  as String?;
        }

        providerId ??=
            (selection['providerID'] ??
                    selection['providerId'] ??
                    selection['provider'])
                as String?;
        modelId ??=
            (selection['modelID'] ?? selection['modelId'] ?? selection['id'])
                as String?;
        remoteAgent = (selection['agentName'] ?? selection['agent']) as String?;
      }
    }

    if (providerId == null || modelId == null) {
      final model = config['model'];
      if (model is String) {
        providerId ??= _providerFromModelKey(model.trim());
        modelId ??= _modelFromModelKey(model.trim());
      } else if (model is Map) {
        providerId ??=
            (model['providerID'] ?? model['providerId'] ?? model['provider'])
                as String?;
        modelId ??=
            (model['modelID'] ?? model['modelId'] ?? model['id']) as String?;
      }
    }

    providerId = providerId?.trim();
    modelId = modelId?.trim();
    if (providerId != null && providerId.isEmpty) {
      providerId = null;
    }
    if (modelId != null && modelId.isEmpty) {
      modelId = null;
    }

    remoteAgent ??=
        (config['default_agent'] ?? config['defaultAgent']) as String?;
    final normalizedAgent = remoteAgent?.trim();
    final variantByAgentAndModel = _parseRemoteVariantByAgent(config);
    final sessionOverridesBySessionId = _parseRemoteSessionSelectionOverrides(
      config,
    );

    return _RemoteChatSelection(
      providerId: providerId,
      modelId: modelId,
      agentName: (normalizedAgent == null || normalizedAgent.isEmpty)
          ? null
          : normalizedAgent,
      variantByAgentAndModel: variantByAgentAndModel,
      sessionOverridesBySessionId: sessionOverridesBySessionId,
    );
  }

  Future<_RemoteChatSelection?> _loadRemoteChatSelection({
    String? directory,
  }) async {
    final client = dioClient;
    if (client == null) {
      return null;
    }
    try {
      final response = await client.get<Map<String, dynamic>>(
        '/config',
        queryParameters: _configQueryParameters(directory: directory),
      );
      return _parseRemoteChatSelection(response.data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncSelectionFromRemote({
    required String reason,
    bool force = false,
  }) async {
    if (!_isExperimentalMultiDeviceSyncEnabled) {
      return;
    }
    final client = dioClient;
    if (client == null || (_providers.isEmpty && _agents.isEmpty)) {
      return;
    }
    if (_pendingRemoteSelectionSync && !_canFlushPendingRemoteSelectionSync) {
      return;
    }
    if (_remoteSelectionSyncInFlight) {
      return;
    }
    final contextKey = _activeContextKey;
    final directory = projectProvider.currentDirectory;
    final generation = _remoteSelectionSyncGeneration;
    final lastSyncAt = _lastRemoteSelectionSyncAt;
    if (!force &&
        lastSyncAt != null &&
        DateTime.now().difference(lastSyncAt) <
            ChatProvider._remoteSelectionSyncThrottle) {
      return;
    }

    _remoteSelectionSyncInFlight = true;
    try {
      final remoteSelection = await _loadRemoteChatSelection(
        directory: directory,
      );
      if (contextKey != _activeContextKey ||
          generation != _remoteSelectionSyncGeneration) {
        return;
      }
      _lastRemoteSelectionSyncAt = DateTime.now();
      if (remoteSelection == null) {
        return;
      }
      await _applyRemoteSelection(
        remoteSelection,
        reason: reason,
        persistLocal: true,
      );
    } finally {
      if (contextKey == _activeContextKey &&
          generation == _remoteSelectionSyncGeneration) {
        _remoteSelectionSyncInFlight = false;
      }
    }
  }

  Map<String, dynamic> _buildSelectionSyncPayload({
    required int updatedAtEpochMs,
    bool includeVariantSnapshot = false,
    bool includeSessionSelections = false,
  }) {
    final payload = <String, dynamic>{};

    final selection = <String, dynamic>{'updatedAt': updatedAtEpochMs};
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId != null && modelId != null) {
      selection['providerId'] = providerId;
      selection['modelId'] = modelId;
      selection['model'] = _modelKey(providerId, modelId);
    }
    final agentName = _selectedAgentName?.trim();
    if (agentName != null && agentName.isNotEmpty) {
      selection['agentName'] = agentName;
    }
    if (selection.length > 1) {
      payload[ChatProvider._configSelectionKey] = selection;
    }

    if (includeVariantSnapshot) {
      final normalizedAgent = _selectedAgentName?.trim();
      final modelKey = _currentModelKey();
      if (normalizedAgent != null &&
          normalizedAgent.isNotEmpty &&
          modelKey != null) {
        final variantByModelPayload = <String, String>{};
        for (final entry in _selectedVariantByModel.entries) {
          final key = entry.key.trim();
          final value = entry.value.trim();
          if (key.isEmpty || value.isEmpty) {
            continue;
          }
          variantByModelPayload[key] = value;
        }
        final selectedVariant = _selectedVariantId?.trim();
        variantByModelPayload[modelKey] =
            (selectedVariant == null || selectedVariant.isEmpty)
            ? ChatProvider._remoteAutoVariantValue
            : selectedVariant;

        payload[ChatProvider._configVariantByAgentAndModelKey] =
            <String, dynamic>{normalizedAgent: variantByModelPayload};
      }
    }

    if (includeSessionSelections) {
      final sessionSelections = <String, dynamic>{};
      final overrides = _sessionOverridesForContext(_activeContextKey);
      for (final entry in overrides.entries) {
        sessionSelections[entry.key] = _sessionOverrideToJson(entry.value);
      }
      payload[ChatProvider._configSessionSelectionsKey] = sessionSelections;
    }

    payload['updatedAt'] = updatedAtEpochMs;
    return payload;
  }

  Future<void> _runSelectionSyncTransaction({
    required String reason,
    String? directory,
    // True when [directory] was captured in the originating snapshot: a null
    // then means "unscoped" and must NOT fall back to the live directory
    // (which may already point at the next project). False keeps the live
    // read for the snapshot-less deferred path targeting the current context.
    bool directoryExplicit = false,
  }) async {
    final contextKey = _activeContextKey;
    final generation = _remoteSelectionSyncGeneration;
    // Prefer the snapshot-owned directory: the live current directory may
    // already point at the next project when a slow flush finishes mid-switch.
    // Callers without a snapshot (deferred flush for the current context) pass
    // nothing and keep the live read.
    final targetDirectory = directoryExplicit
        ? directory
        : (directory ?? projectProvider.currentDirectory);
    final targetDirectoryExplicit = directoryExplicit;
    final previous = _selectionSyncTransactionQueue;
    final task = previous
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger.warn(
            'Previous selection sync transaction failed',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .then(
          (_) => _runSelectionSyncTransactionBody(
            reason: reason,
            contextKey: contextKey,
            directory: targetDirectory,
            directoryExplicit: targetDirectoryExplicit,
            generation: generation,
          ),
        );
    _selectionSyncTransactionQueue = task.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.warn(
        'Selection sync transaction failed',
        error: error,
        stackTrace: stackTrace,
      );
    });
    await task;
  }

  Future<void> _runSelectionSyncTransactionBody({
    required String reason,
    required String contextKey,
    required String? directory,
    required bool directoryExplicit,
    required int generation,
  }) async {
    if (contextKey != _activeContextKey ||
        generation != _remoteSelectionSyncGeneration) {
      return;
    }
    _setSelectionSyncTransactionPhase(
      _SelectionSyncTransactionPhase.pendingRemote,
      reason: '$reason-start',
    );
    final success = await _syncSelectionToRemoteConfig(
      contextKey: contextKey,
      directory: directory,
      directoryExplicit: directoryExplicit,
      generation: generation,
    );
    if (contextKey != _activeContextKey ||
        generation != _remoteSelectionSyncGeneration) {
      return;
    }
    if (success) {
      _setSelectionSyncTransactionPhase(
        _SelectionSyncTransactionPhase.appliedRemote,
        reason: reason,
      );
      _setSelectionSyncTransactionPhase(
        _SelectionSyncTransactionPhase.idle,
        reason: '$reason-applied',
      );
      return;
    }

    _setSelectionSyncTransactionPhase(
      _SelectionSyncTransactionPhase.failed,
      reason: reason,
    );
  }
}
