part of '../chat_provider.dart';

extension _ChatProviderEventReducerHelpers on ChatProvider {
  bool _eventInfoContainsAny(Map<String, dynamic> info, Iterable<String> keys) {
    for (final key in keys) {
      if (info.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  ChatSession _mergeSessionFromEventInfo({
    required ChatSession incoming,
    required ChatSession? existing,
    required Map<String, dynamic> info,
  }) {
    if (existing == null) {
      return incoming;
    }

    var merged = existing;
    if (info.containsKey('workspaceId')) {
      merged = merged.copyWith(workspaceId: incoming.workspaceId);
    }
    if (info.containsKey('time')) {
      merged = merged.copyWith(
        time: incoming.time,
        createdAt: incoming.createdAt ?? merged.createdAt,
        archivedAt: incoming.archivedAt,
      );
    }
    if (_eventInfoContainsAny(info, const <String>[
      'title',
      'name',
      'sessionTitle',
    ])) {
      merged = merged.copyWith(title: incoming.title);
    }
    if (_eventInfoContainsAny(info, const <String>['parentID', 'parentId'])) {
      merged = merged.copyWith(parentId: incoming.parentId);
    }
    if (info.containsKey('directory')) {
      merged = merged.copyWith(directory: incoming.directory);
    }
    if (info.containsKey('summary')) {
      merged = merged.copyWith(summary: incoming.summary);
    }
    if (info.containsKey('path')) {
      merged = merged.copyWith(path: incoming.path);
    }
    if (_eventInfoContainsAny(info, const <String>['share', 'shared'])) {
      merged = merged.copyWith(
        shared: incoming.shared,
        shareUrl: incoming.shareUrl,
      );
    }
    if (info.containsKey('revert')) {
      final pendingBranch = _pendingReplacementBranch;
      final incomingRevertId = incoming.revert?.messageId.trim();
      if (pendingBranch == null ||
          pendingBranch.sessionId != merged.id ||
          incomingRevertId != pendingBranch.revertMessageId) {
        merged = merged.copyWith(revert: incoming.revert);
      }
    }
    return merged;
  }

  Map<String, dynamic> _eventPayloadOrNested(
    Map<String, dynamic> properties,
    Iterable<String> nestedKeys,
  ) {
    for (final key in nestedKeys) {
      final nested = properties[key];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }
    return properties;
  }

  String? _effectiveEventSessionIdForEvent(ChatEvent event) {
    if (event.type.startsWith('message.')) {
      final inferred = _inferSessionIdFromKnownMessageEvent(event.properties);
      if (inferred != null) {
        return inferred;
      }
    }
    return _extractEventSessionId(event.properties);
  }

  String? _inferSessionIdFromKnownMessageEvent(
    Map<String, dynamic> properties,
  ) {
    final messageId = _messageIdFromEventProperties(properties);
    if (messageId == null) {
      return null;
    }
    for (final message in _messages) {
      if (message.id == messageId && message.sessionId.trim().isNotEmpty) {
        return message.sessionId;
      }
    }
    return null;
  }

  String? _messageIdFromEventProperties(Map<String, dynamic> properties) {
    final direct = _readTrimmedEventString(properties, 'messageID');
    if (direct != null) {
      return direct;
    }
    final directCamel = _readTrimmedEventString(properties, 'messageId');
    if (directCamel != null) {
      return directCamel;
    }
    final info = properties['info'];
    if (info is Map) {
      final id = _readTrimmedEventString(info, 'id');
      if (id != null) {
        return id;
      }
      final infoMessageId = _readTrimmedEventString(info, 'messageID');
      if (infoMessageId != null) {
        return infoMessageId;
      }
      final infoCamelMessageId = _readTrimmedEventString(info, 'messageId');
      if (infoCamelMessageId != null) {
        return infoCamelMessageId;
      }
    }
    final part = properties['part'];
    if (part is Map) {
      final partMessageId = _readTrimmedEventString(part, 'messageID');
      if (partMessageId != null) {
        return partMessageId;
      }
      final partCamelMessageId = _readTrimmedEventString(part, 'messageId');
      if (partCamelMessageId != null) {
        return partCamelMessageId;
      }
    }
    return null;
  }

  String? _readTrimmedEventString(Map<dynamic, dynamic> source, String key) {
    final value = source[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  void _refreshPendingInteractionsForEvent(String type) {
    AppLogger.warn(
      'Refreshing pending interactions after unparseable OpenCode event type=$type',
    );
    unawaited(_loadPendingInteractions());
  }

  /// Compose a dedup key from event type + identifying properties.
  /// Returns null for events that cannot be meaningfully deduplicated.
  String? _composeEventDeduplicationKey(ChatEvent event) {
    final props = event.properties;
    final info = props['info'];
    final infoMap = info is Map ? Map<String, dynamic>.from(info) : null;
    final sessionId =
        _extractEventSessionId(props) ??
        (infoMap == null ? null : _extractEventSessionId(infoMap));
    final messageId = _messageIdFromEventProperties(props);
    final partId = _partIdFromEventProperties(props);
    final requestId =
        _readTrimmedEventString(props, 'requestID') ??
        _readTrimmedEventString(props, 'requestId') ??
        (infoMap == null
            ? null
            : _readTrimmedEventString(infoMap, 'requestID') ??
                  _readTrimmedEventString(infoMap, 'requestId') ??
                  _readTrimmedEventString(infoMap, 'id'));
    final mutationSignature = _messageMutationDedupSignature(event);
    // Build composite key from available identifiers
    final segments = <String>[event.type];
    if (sessionId != null) segments.add(sessionId);
    if (messageId != null) segments.add(messageId);
    if (partId != null) segments.add(partId);
    if (requestId != null) segments.add(requestId);
    if (mutationSignature != null) segments.add(mutationSignature);
    // Events with only type+session (e.g. session.status) change over time,
    // so skip dedup for events without a fine-grained identifier.
    if (messageId == null &&
        partId == null &&
        requestId == null &&
        mutationSignature == null) {
      return null;
    }
    return segments.join(':');
  }

  String? _partIdFromEventProperties(Map<String, dynamic> properties) {
    final direct = _readTrimmedEventString(properties, 'partID');
    if (direct != null) {
      return direct;
    }
    final directCamel = _readTrimmedEventString(properties, 'partId');
    if (directCamel != null) {
      return directCamel;
    }
    final part = properties['part'];
    if (part is Map) {
      final id = _readTrimmedEventString(part, 'id');
      if (id != null) {
        return id;
      }
      final partId = _readTrimmedEventString(part, 'partID');
      if (partId != null) {
        return partId;
      }
      final partCamelId = _readTrimmedEventString(part, 'partId');
      if (partCamelId != null) {
        return partCamelId;
      }
    }
    return null;
  }

  String? _messageMutationDedupSignature(ChatEvent event) {
    final props = event.properties;
    switch (event.type) {
      case 'message.created':
      case 'message.updated':
        final info = props['info'];
        if (info == null) {
          return null;
        }
        return 'payload=${_stableEventValueHash(info)}';
      case 'message.part.updated':
        final part = props['part'];
        final delta = props['delta'];
        if (part == null && delta == null) {
          return null;
        }
        final signaturePayload = <String, dynamic>{};
        if (part != null) {
          signaturePayload['part'] = part;
        }
        if (delta != null) {
          signaturePayload['delta'] = delta;
        }
        return 'payload=${_stableEventValueHash(signaturePayload)}';
      case 'message.part.delta':
        final field = props['field'];
        final delta = props['delta'];
        final part = props['part'];
        if (field == null && delta == null && part == null) {
          return null;
        }
        final signaturePayload = <String, dynamic>{};
        if (field != null) {
          signaturePayload['field'] = field;
        }
        if (delta != null) {
          signaturePayload['delta'] = delta;
        }
        if (part != null) {
          signaturePayload['part'] = part;
        }
        return 'payload=${_stableEventValueHash(signaturePayload)}';
      case 'session.next.revert.staged':
      case 'session.next.revert.cleared':
      case 'session.next.revert.committed':
        final mutation = Map<String, dynamic>.from(props)
          ..remove('directory')
          ..remove('project')
          ..remove('workspace');
        return 'payload=${_stableEventValueHash(mutation)}';
      default:
        return null;
    }
  }

  String _stableEventValueHash(Object? value) {
    final canonical = jsonEncode(_canonicalEventValue(value));
    var hash = 0x811c9dc5;
    for (final codeUnit in canonical.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${canonical.length}:${hash.toRadixString(16).padLeft(8, '0')}';
  }

  Object? _canonicalEventValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonicalEventValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalEventValue).toList(growable: false);
    }
    return value.toString();
  }

  /// Returns true if this event was recently processed (duplicate).
  bool _isRecentlyProcessedEvent(ChatEvent event) {
    final key = _composeEventDeduplicationKey(event);
    if (key == null) return false;
    return _recentEventIds.contains(key);
  }

  /// Claims this event for processing and returns true when it was already
  /// claimed by the paired session/global stream.
  bool _claimRecentlyProcessedEvent(ChatEvent event) {
    final key = _composeEventDeduplicationKey(event);
    if (key == null) return false;
    if (_recentEventIds.contains(key)) return true;
    _recentEventIds.addLast(key);
    if (_recentEventIds.length > ChatProvider._maxRecentEventIds) {
      _recentEventIds.removeFirst();
    }
    return false;
  }

  bool _hasInFlightSendTurnForSession(String sessionId) {
    return _currentSession?.id == sessionId &&
        _activeMessageStreamSessionId == sessionId &&
        (_state == ChatState.sending || _messageSubscription != null);
  }

  bool _isNonCurrentSessionEvent(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    final currentSessionId = _currentSession?.id.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    return currentSessionId == null ||
        currentSessionId.isEmpty ||
        normalizedSessionId != currentSessionId;
  }

  bool _shouldHandleFeedbackForEvent(ChatEvent event) {
    switch (event.type) {
      case 'permission.asked':
      case 'permission.updated':
      case 'permission.v2.asked':
      case 'permission.v2.updated':
      case 'question.asked':
      case 'question.updated':
      case 'question.v2.asked':
      case 'question.v2.updated':
      case 'session.error':
      case 'session.idle':
        return true;
      default:
        return false;
    }
  }

  bool _shouldSuppressAggressiveDataSaverEvent(
    ChatEvent event,
    String? sessionId,
  ) {
    if (!_cellularDataSaverService.isAggressiveDataSaverActive) {
      return false;
    }
    if (event.type == 'server.connected' || event.type == 'server.heartbeat') {
      return false;
    }
    final affectsSession =
        event.type.startsWith('session.') ||
        event.type.startsWith('message.') ||
        event.type.startsWith('todo.') ||
        event.type.startsWith('permission.') ||
        event.type.startsWith('question.');
    if (!affectsSession) {
      return false;
    }
    if (!_hasVisibleAggressiveDataSaverSession) {
      return true;
    }
    if (sessionId == null || sessionId.trim().isEmpty) {
      return false;
    }
    return !_isVisibleAggressiveSessionId(sessionId);
  }

  bool _isRootSessionInList(String sessionId, List<ChatSession> sessions) {
    for (final session in sessions) {
      if (session.id != sessionId) {
        continue;
      }
      final parentId = session.parentId?.trim();
      return parentId == null || parentId.isEmpty;
    }
    return false;
  }

  ChatEvent? _feedbackEventForCurrentContext(ChatEvent event) {
    if (event.type == 'session.status') {
      final sessionId = event.properties['sessionID'] as String?;
      final statusMap = event.properties['status'];
      if (sessionId == null || statusMap is! Map<String, dynamic>) {
        return null;
      }
      final status = _parseStatusForFeedback(statusMap);
      if (status?.type != SessionStatusType.idle) {
        return null;
      }
      final isVisibleCurrentSession =
          sessionId == _currentSession?.id && _isChatRouteActive;
      if (isVisibleCurrentSession) {
        return null;
      }
      final previousStatusType = _sessionStatusById[sessionId]?.type;
      final completedFromActiveTurn =
          previousStatusType == null ||
          previousStatusType == SessionStatusType.busy ||
          previousStatusType == SessionStatusType.retry;
      if (!completedFromActiveTurn) {
        return null;
      }
      return _sessionIdleFeedbackEventFromStatus(event);
    }

    if (event.type == 'session.idle') {
      final sessionId = event.properties['sessionID'] as String?;
      if (sessionId != null &&
          _sessionStatusById[sessionId]?.type == SessionStatusType.idle &&
          !_sessionErrorAttentionIds.contains(sessionId)) {
        return null;
      }
    }

    return _shouldHandleFeedbackForEvent(event) ? event : null;
  }

  SessionStatusInfo? _parseStatusForFeedback(Map<String, dynamic> statusMap) {
    try {
      return SessionStatusModel.fromJson(statusMap).toDomain();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to parse session.status feedback event',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  ChatEvent _sessionIdleFeedbackEventFromStatus(ChatEvent event) {
    final properties = Map<String, dynamic>.from(event.properties)
      ..remove('status');
    return ChatEvent(type: 'session.idle', properties: properties);
  }

  ({String message, String? code}) _extractSessionErrorMessageAndCode(
    Map<String, dynamic> properties,
  ) {
    final rawError = properties['error'];
    final error = rawError is Map ? Map<String, dynamic>.from(rawError) : null;
    final dataRaw = error?['data'];
    final data = dataRaw is Map
        ? Map<String, dynamic>.from(dataRaw)
        : const <String, dynamic>{};
    final messageFromData = data['message']?.toString().trim();
    final messageFromError = error?['message']?.toString().trim();
    final messageFromRawError = rawError is String ? rawError.trim() : null;
    final message = (messageFromData != null && messageFromData.isNotEmpty)
        ? messageFromData
        : (messageFromError != null && messageFromError.isNotEmpty)
        ? messageFromError
        : (messageFromRawError != null && messageFromRawError.isNotEmpty)
        ? messageFromRawError
        : (L10nBridge.current?.chatProviderErrorSessionFallback ??
              'Session error');
    final code = data['code']?.toString() ?? error?['code']?.toString();
    return (message: message, code: code);
  }
}
