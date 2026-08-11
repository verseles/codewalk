part of '../chat_provider.dart';

extension _ChatProviderContextStateOps on ChatProvider {
  String _composeContextKey(String serverId, String scopeId) {
    return '$serverId::$scopeId';
  }

  Map<String, _SessionSelectionOverride> _sessionOverridesForContext(
    String contextKey,
  ) {
    final prefix = '$contextKey::';
    final result = <String, _SessionSelectionOverride>{};
    for (final entry in _sessionSelectionOverridesByKey.entries) {
      if (!entry.key.startsWith(prefix)) {
        continue;
      }
      final sessionId = entry.key.substring(prefix.length);
      if (sessionId.isEmpty) {
        continue;
      }
      result[sessionId] = entry.value;
    }
    return result;
  }

  Map<String, _SessionSelectionOverride> _parseRemoteSessionSelectionOverrides(
    Map<String, dynamic> config,
  ) {
    final agentsRaw = config['agent'] ?? config['mode'];
    if (agentsRaw is! Map) {
      return const <String, _SessionSelectionOverride>{};
    }
    final agents = Map<String, dynamic>.from(agentsRaw);
    final syncAgentRaw = agents[ChatProvider._configSyncAgentName];
    if (syncAgentRaw is! Map) {
      return const <String, _SessionSelectionOverride>{};
    }
    final syncAgent = Map<String, dynamic>.from(syncAgentRaw);
    final optionsRaw = syncAgent['options'];
    if (optionsRaw is! Map) {
      return const <String, _SessionSelectionOverride>{};
    }
    final options = Map<String, dynamic>.from(optionsRaw);
    final codewalkRaw = options[ChatProvider._configCodewalkNamespace];
    if (codewalkRaw is! Map) {
      return const <String, _SessionSelectionOverride>{};
    }
    final codewalk = Map<String, dynamic>.from(codewalkRaw);
    final sessionSelectionsRaw =
        codewalk[ChatProvider._configSessionSelectionsKey];
    if (sessionSelectionsRaw is! Map) {
      return const <String, _SessionSelectionOverride>{};
    }

    final parsed = <String, _SessionSelectionOverride>{};
    for (final entry in sessionSelectionsRaw.entries) {
      final sessionId = entry.key.toString().trim();
      if (sessionId.isEmpty) {
        continue;
      }
      final override = _sessionOverrideFromJson(entry.value);
      if (override != null) {
        parsed[sessionId] = override;
      }
    }
    return parsed;
  }

  Future<void> _persistSessionSelectionOverridesState({
    required String serverId,
    required String scopeId,
  }) async {
    final overrides = _sessionOverridesForContext(_activeContextKey);
    final serialized = <String, dynamic>{};
    for (final entry in overrides.entries) {
      serialized[entry.key] = _sessionOverrideToJson(entry.value);
    }
    await localDataSource.saveSessionSelectionOverridesJson(
      json.encode(serialized),
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  bool _applySessionSelectionOverride(String? sessionId) {
    if (sessionId == null || sessionId.trim().isEmpty) {
      return false;
    }
    final override =
        _sessionSelectionOverridesByKey[_sessionSelectionKey(sessionId)];

    if (override == null) {
      // No explicit override — fall back to scanning cached messages for the
      // last AssistantMessage with model/agent metadata (Feature 7).
      return _restoreSelectionFromMessages(sessionId);
    }

    final provider = _providers
        .where((p) => p.id == override.providerId)
        .firstOrNull;
    if (provider == null ||
        !_isUserSelectableModelId(provider, override.modelId)) {
      if (_providerCatalogAuthority != _CatalogAuthority.authoritative) {
        return false;
      }
      _removeSessionSelectionOverride(sessionId);
      // Override is stale — try the message fallback as a recovery path.
      return _restoreSelectionFromMessages(sessionId);
    }

    final resolvedAgent = _resolvePreferredAgentName(
      _agents,
      override.agentName,
    );
    if (resolvedAgent == null) {
      if (_agentCatalogAuthority != _CatalogAuthority.authoritative) {
        return false;
      }
      _removeSessionSelectionOverride(sessionId);
      return _restoreSelectionFromMessages(sessionId);
    }

    final model = provider.models[override.modelId];
    var nextVariantId = override.variantId;
    if (nextVariantId != null &&
        (model == null || !model.variants.containsKey(nextVariantId)) &&
        _providerCatalogAuthority == _CatalogAuthority.authoritative) {
      nextVariantId = null;
    }

    var changed = false;
    if (_selectedProviderId != provider.id) {
      _selectedProviderId = provider.id;
      changed = true;
    }
    if (_selectedModelId != override.modelId) {
      _selectedModelId = override.modelId;
      changed = true;
    }
    if (_selectedAgentName != resolvedAgent) {
      _selectedAgentName = resolvedAgent;
      changed = true;
    }
    if (_selectedVariantId != nextVariantId) {
      _selectedVariantId = nextVariantId;
      changed = true;
    }

    final modelKey = _modelKey(provider.id, override.modelId);
    if (nextVariantId == null) {
      _selectedVariantByModel.remove(modelKey);
    } else {
      _selectedVariantByModel[modelKey] = nextVariantId;
    }

    // When the override was not set by an explicit user action (e.g. it was
    // derived from session-switch continuity or config sync), the
    // message-derived fallback may produce a more accurate selection based
    // on the actual last-used metadata for this session. The fallback takes
    // precedence over non-explicit overrides but not over explicit ones
    // (Feature 7).
    if (!override.isExplicit) {
      final messageFallbackChanged = _restoreSelectionFromMessages(sessionId);
      if (messageFallbackChanged) {
        return true;
      }
    }

    return changed;
  }
}
