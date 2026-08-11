part of '../chat_provider.dart';

extension _ChatProviderSelectionHelpers on ChatProvider {
  String _modelKey(String providerId, String modelId) {
    return '$providerId/$modelId';
  }

  String? _providerFromModelKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0) {
      return null;
    }
    return modelKey.substring(0, separatorIndex);
  }

  String? _modelFromModelKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0 || separatorIndex == modelKey.length - 1) {
      return null;
    }
    return modelKey.substring(separatorIndex + 1);
  }

  bool _isUserSelectableModel(Provider provider, Model model) {
    return isUserSelectableModel(
      provider: provider,
      model: model,
      connectedProviderIds: _connectedProviderIds,
    );
  }

  bool _isUserSelectableModelId(Provider provider, String modelId) {
    final model = provider.models[modelId];
    return model != null && _isUserSelectableModel(provider, model);
  }

  bool _hasUserSelectableModels(Provider provider) {
    return provider.models.values.any(
      (model) => _isUserSelectableModel(provider, model),
    );
  }

  String? _firstUserSelectableModelId(Provider provider) {
    for (final entry in provider.models.entries) {
      if (_isUserSelectableModel(provider, entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  Provider? _userSelectableProviderById(String? providerId) {
    final normalized = providerId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final provider = _providers.where((p) => p.id == normalized).firstOrNull;
    if (provider == null || !_hasUserSelectableModels(provider)) {
      return null;
    }
    return provider;
  }

  Map<String, dynamic>? _configQueryParameters({String? directory}) {
    final resolvedDirectory = (directory ?? projectProvider.currentDirectory)
        ?.trim();
    if (resolvedDirectory == null || resolvedDirectory.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'directory': resolvedDirectory,
      'workspace': resolvedDirectory,
    };
  }

  Map<String, dynamic>? _codewalkSyncConfig(Map<String, dynamic> config) {
    final rawAgentConfig = config['agent'] ?? config['mode'];
    if (rawAgentConfig is! Map) {
      return null;
    }

    final agents = Map<String, dynamic>.from(rawAgentConfig);
    final syncAgentRaw = agents[ChatProvider._configSyncAgentName];
    if (syncAgentRaw is! Map) {
      return null;
    }

    final syncAgent = Map<String, dynamic>.from(syncAgentRaw);
    final optionsRaw = syncAgent['options'];
    if (optionsRaw is! Map) {
      return null;
    }

    final options = Map<String, dynamic>.from(optionsRaw);
    final codewalkRaw = options[ChatProvider._configCodewalkNamespace];
    if (codewalkRaw is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(codewalkRaw);
  }

  Map<String, Map<String, String>> _parseRemoteVariantByAgent(
    Map<String, dynamic> config,
  ) {
    final namespacedConfig = _codewalkSyncConfig(config);
    if (namespacedConfig != null) {
      final namespacedRaw =
          namespacedConfig[ChatProvider._configVariantByAgentAndModelKey];
      if (namespacedRaw is Map) {
        final parsedFromNamespace = <String, Map<String, String>>{};
        for (final agentEntry in namespacedRaw.entries) {
          final agentName = agentEntry.key.toString().trim();
          if (agentName.isEmpty || agentEntry.value is! Map) {
            continue;
          }
          final byModelRaw = Map<String, dynamic>.from(agentEntry.value as Map);
          final byModel = <String, String>{};
          for (final modelEntry in byModelRaw.entries) {
            final modelKey = modelEntry.key.toString().trim();
            final value = modelEntry.value?.toString().trim();
            if (modelKey.isEmpty || value == null || value.isEmpty) {
              continue;
            }
            byModel[modelKey] = value;
          }
          if (byModel.isNotEmpty) {
            parsedFromNamespace[agentName] = byModel;
          }
        }
        if (parsedFromNamespace.isNotEmpty) {
          return parsedFromNamespace;
        }
      }
    }

    final rawAgentConfig = config['agent'] ?? config['mode'];
    if (rawAgentConfig is! Map) {
      return const <String, Map<String, String>>{};
    }

    final parsed = <String, Map<String, String>>{};
    for (final entry in rawAgentConfig.entries) {
      final agentName = entry.key.toString().trim();
      if (agentName.isEmpty || entry.value is! Map) {
        continue;
      }
      final agentConfig = Map<String, dynamic>.from(entry.value as Map);
      final optionsRaw = agentConfig['options'];
      if (optionsRaw is! Map) {
        continue;
      }
      final options = Map<String, dynamic>.from(optionsRaw);

      dynamic variantByModelRaw;
      final codewalkRaw = options[ChatProvider._configCodewalkNamespace];
      if (codewalkRaw is Map) {
        final codewalk = Map<String, dynamic>.from(codewalkRaw);
        variantByModelRaw = codewalk[ChatProvider._configVariantByModelKey];
      }
      variantByModelRaw ??= options['codewalkVariantByModel'];

      if (variantByModelRaw is! Map) {
        continue;
      }

      final byModel = <String, String>{};
      for (final variantEntry in variantByModelRaw.entries) {
        final modelKey = variantEntry.key.toString().trim();
        final value = variantEntry.value?.toString().trim();
        if (modelKey.isEmpty || value == null || value.isEmpty) {
          continue;
        }
        byModel[modelKey] = value;
      }
      if (byModel.isNotEmpty) {
        parsed[agentName] = byModel;
      }
    }
    return parsed;
  }

  String? _currentModelKey() {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      return null;
    }
    return _modelKey(providerId, modelId);
  }

  String _remoteVariantSyncKey({
    required String agentName,
    required String modelKey,
    required String variantValue,
  }) {
    return '$agentName|$modelKey|$variantValue';
  }

  bool _applyRemoteVariantSelection(_RemoteChatSelection remoteSelection) {
    final agentName = _selectedAgentName?.trim();
    final modelKey = _currentModelKey();
    final model = selectedModel;
    if (agentName == null ||
        agentName.isEmpty ||
        modelKey == null ||
        model == null) {
      return false;
    }

    final remoteVariantValue = remoteSelection.variantForModel(
      agentName: agentName,
      modelKey: modelKey,
    );
    if (remoteVariantValue == null || remoteVariantValue.trim().isEmpty) {
      return false;
    }

    final normalizedRemoteValue = remoteVariantValue.trim();
    String? nextVariantId;
    final normalizedForCompare = normalizedRemoteValue.toLowerCase();
    if (normalizedForCompare == ChatProvider._remoteAutoVariantValue) {
      nextVariantId = null;
    } else {
      if (model.variants.containsKey(normalizedRemoteValue)) {
        nextVariantId = normalizedRemoteValue;
      } else {
        final caseInsensitiveMatches = model.variants.entries
            .where((entry) => entry.key.toLowerCase() == normalizedForCompare)
            .toList(growable: false);
        if (caseInsensitiveMatches.length != 1) {
          return false;
        }
        nextVariantId = caseInsensitiveMatches.first.key;
      }
    }

    if (_selectedVariantId == nextVariantId) {
      _lastSyncedRemoteVariantKey = _remoteVariantSyncKey(
        agentName: agentName,
        modelKey: modelKey,
        variantValue: normalizedRemoteValue,
      );
      return false;
    }

    _selectedVariantId = nextVariantId;
    if (nextVariantId == null) {
      _selectedVariantByModel.remove(modelKey);
    } else {
      _selectedVariantByModel[modelKey] = nextVariantId;
    }
    _lastSyncedRemoteVariantKey = _remoteVariantSyncKey(
      agentName: agentName,
      modelKey: modelKey,
      variantValue: normalizedRemoteValue,
    );
    return true;
  }

  Future<void> _applyRemoteSelection(
    _RemoteChatSelection remoteSelection, {
    required String reason,
    required bool persistLocal,
  }) async {
    var changed = false;

    final mergedSessionOverrides = _mergeRemoteSessionSelectionOverrides(
      remoteSelection.sessionOverridesBySessionId,
    );
    changed = changed || mergedSessionOverrides;

    if (remoteSelection.hasModel) {
      final remoteProviderId = remoteSelection.providerId!;
      final remoteModelId = remoteSelection.modelId!;
      final provider = _providers
          .where((p) => p.id == remoteProviderId)
          .firstOrNull;
      if (provider != null &&
          _isUserSelectableModelId(provider, remoteModelId)) {
        if (_selectedProviderId != remoteProviderId ||
            _selectedModelId != remoteModelId) {
          _selectedProviderId = remoteProviderId;
          _selectedModelId = remoteModelId;
          _selectedVariantId = _resolveStoredVariantForSelection();
          changed = true;
        }
        _lastSyncedRemoteModelKey = _modelKey(remoteProviderId, remoteModelId);
      }
    }

    final remoteAgentName = remoteSelection.agentName;
    if (remoteAgentName != null && remoteAgentName.isNotEmpty) {
      final resolvedAgent = _resolvePreferredAgentName(
        _agents,
        remoteAgentName,
      );
      if (resolvedAgent != null) {
        _lastSyncedRemoteAgentName = resolvedAgent;
        if (_selectedAgentName != resolvedAgent) {
          _selectedAgentName = resolvedAgent;
          changed = true;
        }
      }
    }

    final variantChanged = _applyRemoteVariantSelection(remoteSelection);
    changed = changed || variantChanged;

    final sessionPriorityChanged = _applySelectionPriorityForCurrentSession();
    changed = changed || sessionPriorityChanged;

    if (!changed) {
      return;
    }

    AppLogger.info(
      'Applied remote chat selection reason=$reason agent=${_selectedAgentName ?? "-"} provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"}',
    );

    if (persistLocal) {
      await _persistSelection(syncRemote: false);
    }
    _notifyListeners();
  }

  Future<bool> _syncSelectionToRemoteConfig({
    required String contextKey,
    required String? directory,
    required int generation,
  }) async {
    final client = dioClient;
    if (client == null) {
      return true;
    }

    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    final modelKey = (providerId == null || modelId == null)
        ? null
        : _modelKey(providerId, modelId);
    final agentNameRaw = _selectedAgentName?.trim();
    final agentName = (agentNameRaw == null || agentNameRaw.isEmpty)
        ? null
        : agentNameRaw;
    final variantValue =
        (_selectedVariantId == null || _selectedVariantId!.trim().isEmpty)
        ? ChatProvider._remoteAutoVariantValue
        : _selectedVariantId!.trim();
    final variantSyncKey = (agentName == null || modelKey == null)
        ? null
        : _remoteVariantSyncKey(
            agentName: agentName,
            modelKey: modelKey,
            variantValue: variantValue,
          );
    final overridesSignature = _sessionOverridesSignature(
      _sessionOverridesForContext(_activeContextKey),
    );

    final hasSelectionChanges =
        _lastSyncedRemoteModelKey != modelKey ||
        _lastSyncedRemoteAgentName != agentName ||
        _lastSyncedRemoteVariantKey != variantSyncKey ||
        _lastSyncedRemoteSessionOverridesSignature != overridesSignature;
    if (!hasSelectionChanges) {
      return true;
    }

    try {
      final updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
      await client.patch<void>(
        '/config',
        data: <String, dynamic>{
          'agent': <String, dynamic>{
            ChatProvider._configSyncAgentName: <String, dynamic>{
              'options': <String, dynamic>{
                ChatProvider._configCodewalkNamespace:
                    _buildSelectionSyncPayload(
                      updatedAtEpochMs: updatedAtEpochMs,
                      includeVariantSnapshot: true,
                      includeSessionSelections: true,
                    ),
              },
            },
          },
        },
        queryParameters: _configQueryParameters(directory: directory),
      );
      if (contextKey != _activeContextKey ||
          generation != _remoteSelectionSyncGeneration) {
        return true;
      }
      _lastSyncedRemoteModelKey = modelKey;
      _lastSyncedRemoteAgentName = agentName;
      _lastSyncedRemoteVariantKey = variantSyncKey;
      _lastSyncedRemoteSessionOverridesSignature = overridesSignature;
      return true;
    } catch (_) {
      // Remote sync is best-effort; local state remains source of truth.
      return false;
    }
  }

  void _setSelectionSyncTransactionPhase(
    _SelectionSyncTransactionPhase phase, {
    required String reason,
  }) {
    if (_selectionSyncTransactionPhase == phase) {
      return;
    }
    _selectionSyncTransactionPhase = phase;
    AppLogger.info('Selection sync phase=$phase reason=$reason');
  }

  void _markPendingRemoteSelectionSync({required String reason}) {
    if (_pendingRemoteSelectionSync) {
      return;
    }
    _pendingRemoteSelectionSync = true;
    _pendingRemoteSelectionSyncSince = DateTime.now();
    _setSelectionSyncTransactionPhase(
      _SelectionSyncTransactionPhase.pendingRemote,
      reason: reason,
    );
    AppLogger.info('Deferring remote selection sync reason=$reason');
  }

  void _attemptPendingRemoteSelectionSync({required String reason}) {
    if (!_isExperimentalMultiDeviceSyncEnabled) {
      if (_pendingRemoteSelectionSync) {
        _pendingRemoteSelectionSync = false;
        _pendingRemoteSelectionSyncSince = null;
        _setSelectionSyncTransactionPhase(
          _SelectionSyncTransactionPhase.idle,
          reason: 'sync-disabled',
        );
      }
      return;
    }
    if (!_pendingRemoteSelectionSync) {
      return;
    }
    if (!_canFlushPendingRemoteSelectionSync) {
      return;
    }
    final pendingSince = _pendingRemoteSelectionSyncSince;
    final waitMs = pendingSince == null
        ? 0
        : DateTime.now().difference(pendingSince).inMilliseconds;
    _pendingRemoteSelectionSync = false;
    _pendingRemoteSelectionSyncSince = null;
    AppLogger.info(
      'Flushing deferred remote selection sync reason=$reason wait_ms=$waitMs',
    );
    unawaited(_runSelectionSyncTransaction(reason: reason));
  }

  bool _isSelectableAgent(Agent agent) {
    if (agent.hidden) {
      return false;
    }
    final mode = agent.mode.trim().toLowerCase();
    return mode.isEmpty || mode == 'primary' || mode == 'all';
  }

  int _agentNamePriority(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized == 'build') {
      return 0;
    }
    if (normalized == 'plan') {
      return 1;
    }
    return 2;
  }

  int _agentModePriority(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'primary':
        return 0;
      case 'all':
        return 1;
      default:
        return 2;
    }
  }

  List<Agent> _sortedSelectableAgents(List<Agent> agents) {
    final selectable = agents.where(_isSelectableAgent).toList(growable: false)
      ..sort((a, b) {
        final byPinned = _agentNamePriority(
          a.name,
        ).compareTo(_agentNamePriority(b.name));
        if (byPinned != 0) {
          return byPinned;
        }
        final byMode = _agentModePriority(
          a.mode,
        ).compareTo(_agentModePriority(b.mode));
        if (byMode != 0) {
          return byMode;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return selectable;
  }

  String? _resolvePreferredAgentName(List<Agent> available, String? persisted) {
    final selectable = _sortedSelectableAgents(available);
    if (selectable.isEmpty) {
      return null;
    }
    final persistedName = persisted?.trim();
    if (persistedName != null && persistedName.isNotEmpty) {
      final exact = selectable
          .where((agent) => agent.name == persistedName)
          .firstOrNull;
      if (exact != null) {
        return exact.name;
      }
      final normalized = persistedName.toLowerCase();
      final caseInsensitive = selectable
          .where((agent) => agent.name.toLowerCase() == normalized)
          .firstOrNull;
      if (caseInsensitive != null) {
        return caseInsensitive.name;
      }
    }
    return selectable.first.name;
  }

  String? _scopeIdFromContextKey(String contextKey) {
    final separatorIndex = contextKey.indexOf('::');
    if (separatorIndex <= 0 || separatorIndex == contextKey.length - 2) {
      return null;
    }
    return contextKey.substring(separatorIndex + 2);
  }

  String? _serverIdFromContextKey(String contextKey) {
    final separatorIndex = contextKey.indexOf('::');
    if (separatorIndex <= 0) {
      return null;
    }
    return contextKey.substring(0, separatorIndex);
  }

  String _sessionSelectionKeyForContext(String contextKey, String sessionId) {
    return '$contextKey::$sessionId';
  }

  String _sessionSelectionKey(String sessionId) {
    return _sessionSelectionKeyForContext(_activeContextKey, sessionId);
  }

  void _replaceSessionOverridesForContext(
    String contextKey,
    Map<String, _SessionSelectionOverride> overrides,
  ) {
    final prefix = '$contextKey::';
    final keysToRemove = _sessionSelectionOverridesByKey.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in keysToRemove) {
      _sessionSelectionOverridesByKey.remove(key);
    }
    for (final entry in overrides.entries) {
      final sessionId = entry.key.trim();
      if (sessionId.isEmpty) {
        continue;
      }
      _sessionSelectionOverridesByKey[_sessionSelectionKeyForContext(
            contextKey,
            sessionId,
          )] =
          entry.value;
    }
  }

  String _sessionOverridesSignature(
    Map<String, _SessionSelectionOverride> overrides,
  ) {
    final sessionIds = overrides.keys.toList(growable: false)..sort();
    final buffer = StringBuffer();
    for (final sessionId in sessionIds) {
      final override = overrides[sessionId];
      if (override == null) {
        continue;
      }
      buffer
        ..write(sessionId)
        ..write('|')
        ..write(override.providerId)
        ..write('|')
        ..write(override.modelId)
        ..write('|')
        ..write(override.agentName)
        ..write('|')
        ..write(override.variantId ?? ChatProvider._remoteAutoVariantValue)
        ..write('|')
        ..write(override.updatedAtEpochMs)
        ..write('|')
        ..write(override.isExplicit)
        ..write(';');
    }
    return buffer.toString();
  }

  Map<String, dynamic> _sessionOverrideToJson(_SessionSelectionOverride value) {
    return <String, dynamic>{
      'providerId': value.providerId,
      'modelId': value.modelId,
      'agentName': value.agentName,
      'variantId': value.variantId ?? ChatProvider._remoteAutoVariantValue,
      'updatedAt': value.updatedAtEpochMs,
      'isExplicit': value.isExplicit,
    };
  }

  _SessionSelectionOverride? _sessionOverrideFromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(raw);
    final providerId =
        (json['providerId'] ?? json['providerID'] ?? json['provider'])
            as String?;
    final modelId =
        (json['modelId'] ?? json['modelID'] ?? json['id']) as String?;
    final agentName = (json['agentName'] ?? json['agent']) as String?;
    if (providerId == null ||
        providerId.trim().isEmpty ||
        modelId == null ||
        modelId.trim().isEmpty ||
        agentName == null ||
        agentName.trim().isEmpty) {
      return null;
    }

    final rawVariant = json['variantId'] as String?;
    final normalizedVariant = rawVariant?.trim();
    final variantId =
        (normalizedVariant == null ||
            normalizedVariant.isEmpty ||
            normalizedVariant == ChatProvider._remoteAutoVariantValue)
        ? null
        : normalizedVariant;
    final updatedAt = json['updatedAt'];
    final updatedAtEpochMs = updatedAt is int
        ? updatedAt
        : int.tryParse(updatedAt?.toString() ?? '') ?? 0;

    return _SessionSelectionOverride(
      providerId: providerId.trim(),
      modelId: modelId.trim(),
      agentName: agentName.trim(),
      variantId: variantId,
      updatedAtEpochMs: updatedAtEpochMs,
      isExplicit: json['isExplicit'] == true,
    );
  }

  Future<void> _loadSessionSelectionOverridesState({
    required String serverId,
    required String scopeId,
    required int fetchId,
    required String contextKey,
  }) async {
    final raw = await localDataSource.getSessionSelectionOverridesJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    var parsed = <String, _SessionSelectionOverride>{};
    try {
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final sessionId = entry.key.toString().trim();
            if (sessionId.isEmpty) {
              continue;
            }
            final override = _sessionOverrideFromJson(entry.value);
            if (override != null) {
              parsed[sessionId] = override;
            }
          }
        }
      }
    } catch (_) {
      parsed = <String, _SessionSelectionOverride>{};
    }
    if (!_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      return;
    }
    _replaceSessionOverridesForContext(contextKey, parsed);
  }

  bool _mergeRemoteSessionSelectionOverrides(
    Map<String, _SessionSelectionOverride> remoteOverrides,
  ) {
    if (remoteOverrides.isEmpty) {
      return false;
    }
    final current = _sessionOverridesForContext(_activeContextKey);
    final merged = Map<String, _SessionSelectionOverride>.from(current);
    var changed = false;

    for (final entry in remoteOverrides.entries) {
      final sessionId = entry.key;
      final remote = entry.value;
      final local = merged[sessionId];
      if (local == null || remote.updatedAtEpochMs >= local.updatedAtEpochMs) {
        final shouldReplace =
            local == null ||
            local.providerId != remote.providerId ||
            local.modelId != remote.modelId ||
            local.agentName != remote.agentName ||
            local.variantId != remote.variantId ||
            local.updatedAtEpochMs != remote.updatedAtEpochMs ||
            local.isExplicit != remote.isExplicit;
        if (shouldReplace) {
          merged[sessionId] = remote;
          changed = true;
        }
      }
    }

    if (changed) {
      _replaceSessionOverridesForContext(_activeContextKey, merged);
    }
    return changed;
  }

  /// Scan cached messages backwards for the last AssistantMessage with valid
  /// providerId/modelId/mode metadata and apply that selection. Returns true
  /// if any selection field changed. This is a best-effort fallback — if no
  /// messages are cached or no metadata is found, returns false silently.
  bool _restoreSelectionFromMessages(String sessionId) {
    // Use the LRU session cache — not _messages directly, because during
    // selectSession() the _messages list may still hold the previous
    // session's data even though _currentSession has already switched.
    final cached = _cachedSessionMessages(sessionId);
    if (cached == null || cached.isEmpty) {
      return false;
    }

    // Walk backwards to find the last non-neutral assistant message with
    // model/agent metadata — matching the same semantics as
    // _adoptSelectionFromAssistantMessage.
    AssistantMessage? lastMetadataMessage;
    for (var i = cached.length - 1; i >= 0; i--) {
      final message = cached[i];
      if (message is! AssistantMessage) {
        continue;
      }
      if (_isSelectionNeutralAssistantMessage(message)) {
        continue;
      }
      final pid = message.providerId?.trim();
      final mid = message.modelId?.trim();
      if (pid == null || pid.isEmpty || mid == null || mid.isEmpty) {
        continue;
      }
      lastMetadataMessage = message;
      break;
    }
    if (lastMetadataMessage == null) {
      return false;
    }

    final providerId = lastMetadataMessage.providerId!.trim();
    final modelId = lastMetadataMessage.modelId!.trim();

    // Validate that the provider and model still exist in the catalog.
    final provider = _providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null || !_isUserSelectableModelId(provider, modelId)) {
      return false;
    }

    var changed = false;

    if (_selectedProviderId != providerId) {
      _selectedProviderId = providerId;
      changed = true;
    }
    if (_selectedModelId != modelId) {
      _selectedModelId = modelId;
      changed = true;
    }

    // Resolve variant from the message variant if available, otherwise from the persisted per-model map.
    final messageVariant = lastMetadataMessage.variant?.trim();
    final resolvedVariant =
        (messageVariant != null && messageVariant.isNotEmpty)
        ? messageVariant
        : _resolveStoredVariantForSelection();
    if (_selectedVariantId != resolvedVariant) {
      _selectedVariantId = resolvedVariant;
      changed = true;
    }

    // Resolve agent from the message mode field.
    final mode = lastMetadataMessage.mode?.trim();
    if (mode != null && mode.isNotEmpty && mode.toLowerCase() != 'shell') {
      final resolved = _resolvePreferredAgentName(_agents, mode);
      if (resolved != null && _selectedAgentName != resolved) {
        _selectedAgentName = resolved;
        changed = true;
      }
    }

    if (changed) {
      AppLogger.info(
        'Restored selection from messages session=$sessionId '
        'agent=${_selectedAgentName ?? "-"} '
        'provider=$_selectedProviderId model=$_selectedModelId',
      );
      // Persist as an explicit override so subsequent opens are fast
      // (cache-first, no message scan needed).
      _storeCurrentSessionSelectionOverride(isExplicit: true);
      unawaited(_persistSelection(syncRemote: false));
    }

    return changed;
  }

  void _storeCurrentSessionSelectionOverride({bool isExplicit = false}) {
    final sessionId = _currentSession?.id;
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    final agentName = _selectedAgentName;
    if (sessionId == null ||
        providerId == null ||
        modelId == null ||
        agentName == null ||
        agentName.trim().isEmpty) {
      return;
    }

    // Preserve explicit flag if the existing override was already explicit —
    // a non-explicit store should never downgrade an explicit override.
    final key = _sessionSelectionKey(sessionId);
    final existing = _sessionSelectionOverridesByKey[key];
    final effectiveExplicit = isExplicit || (existing?.isExplicit ?? false);

    _sessionSelectionOverridesByKey[key] = _SessionSelectionOverride(
      providerId: providerId,
      modelId: modelId,
      agentName: agentName,
      variantId: _selectedVariantId,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      isExplicit: effectiveExplicit,
    );
  }

  void _removeSessionSelectionOverride(String sessionId) {
    _sessionSelectionOverridesByKey.remove(_sessionSelectionKey(sessionId));
  }

  bool _applySelectionPriorityForCurrentSession() {
    return _applySessionSelectionOverride(_currentSession?.id);
  }

  List<ChatSession> _filterSessionsForCurrentContext(
    List<ChatSession> sessions,
  ) {
    final currentDirectory = normalizeOptionalFilePath(
      projectProvider.currentDirectory,
    );
    if (currentDirectory == null) {
      return sessions
          .where((session) => !_isEphemeralTitleSession(session))
          .toList();
    }

    final hasDirectoryMetadata = sessions.any((session) {
      return _sessionDirectory(session) != null;
    });
    if (!hasDirectoryMetadata) {
      return sessions
          .where((session) => !_isEphemeralTitleSession(session))
          .toList();
    }

    return sessions.where((session) {
      final sessionDirectory = _sessionDirectory(session);
      return sessionDirectory == currentDirectory &&
          !_isEphemeralTitleSession(session);
    }).toList();
  }

  bool _isEphemeralTitleSession(ChatSession session) {
    if (ChatTitleGenerator.ephemeralSessionIds.contains(session.id)) {
      return true;
    }
    return session.title?.trim() == ChatTitleGenerator.ephemeralSessionTitle;
  }

  String? _sessionDirectory(ChatSession session) {
    final direct = normalizeOptionalFilePath(session.directory);
    if (direct != null) {
      return direct;
    }
    final workspace = normalizeOptionalFilePath(session.path?.workspace);
    if (workspace != null) {
      return workspace;
    }
    return normalizeOptionalFilePath(session.path?.root);
  }

  Future<void> _refreshAgents({
    required String serverId,
    required String scopeId,
    required String? directory,
    required int fetchId,
    required String contextKey,
  }) async {
    final result = await getAgents(directory: directory);
    if (!_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      return;
    }
    if (result.isLeft()) {
      final failure = result.fold((value) => value, (_) => null);
      AppLogger.warn('Failed to load agents: ${failure.toString()}');
      return;
    }
    final agents = result.fold((_) => const <Agent>[], (value) => value);
    final persisted = await localDataSource.getSelectedAgent(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (!_isProviderInitializationCurrent(
      fetchId: fetchId,
      contextKey: contextKey,
    )) {
      return;
    }
    _agents = List<Agent>.from(agents);
    _agentCatalogAuthority = _CatalogAuthority.authoritative;
    _agentCatalogFetchedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
    _selectedAgentName = _resolvePreferredAgentName(_agents, persisted);
  }

  String? _resolveStoredVariantForSelection() {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      return null;
    }
    final model = selectedModel;
    if (model == null || model.variants.isEmpty) {
      return null;
    }
    final modelKey = _modelKey(providerId, modelId);
    final persistedVariant = _selectedVariantByModel[modelKey];
    if (persistedVariant == null ||
        !model.variants.containsKey(persistedVariant)) {
      return null;
    }
    return persistedVariant;
  }
}
