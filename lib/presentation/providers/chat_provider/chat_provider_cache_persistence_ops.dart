part of '../chat_provider.dart';

extension _ChatProviderCachePersistenceOps on ChatProvider {
  List<ChatMessage> _restoreableCachedMessages(List<ChatMessage> messages) {
    final canonicalUserMessages = messages
        .whereType<UserMessage>()
        .where((message) => !_isOptimisticLocalUserMessageId(message.id))
        .cast<ChatMessage>()
        .toList(growable: false);
    final restored = messages
        .where(
          (message) =>
              message is! UserMessage ||
              !_isOptimisticLocalUserMessageId(message.id) ||
              !_shouldSkipLocalUserAppendAsDuplicateEcho(
                localMessage: message,
                mergedMessages: canonicalUserMessages,
              ),
        )
        .toList(growable: false);
    _pendingLocalUserMessageIds.addAll(
      restored
          .whereType<UserMessage>()
          .where((message) => _isOptimisticLocalUserMessageId(message.id))
          .map((message) => message.id),
    );
    return restored;
  }

  List<ChatMessage> _cacheableSessionMessages(
    String sessionId,
    List<ChatMessage> messages,
  ) {
    final filtered = messages
        .where(
          (message) =>
              message.sessionId == sessionId &&
              (!_isOptimisticLocalUserMessageId(message.id) ||
                  _pendingLocalUserMessageIds.contains(message.id)),
        )
        .toList(growable: false);
    // Issue #160: cache entries and persisted snapshots only keep the newest
    // initial window; deeper history stays server-side behind pagination.
    if (filtered.length > ChatProvider._initialMessagesWindowSize) {
      return filtered.sublist(
        filtered.length - ChatProvider._initialMessagesWindowSize,
      );
    }
    return filtered;
  }

  /// Legacy snapshots may predate the bounded-window policy; bound them on
  /// read so restoring cannot re-inflate the resident list.
  List<ChatMessage> _boundRestoredSessionMessages(List<ChatMessage> messages) {
    if (messages.length <= ChatProvider._initialMessagesWindowSize) {
      return messages;
    }
    return messages.sublist(
      messages.length - ChatProvider._initialMessagesWindowSize,
    );
  }

  void _cacheSessionMessages(String sessionId, List<ChatMessage> messages) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    final filtered = _cacheableSessionMessages(normalizedSessionId, messages);
    if (filtered.isEmpty) {
      _sessionMessagesLruCache.remove(normalizedSessionId);
      return;
    }

    _sessionMessagesLruCache.remove(normalizedSessionId);
    _sessionMessagesLruCache[normalizedSessionId] = filtered;
    while (_sessionMessagesLruCache.length >
        ChatProvider._maxSessionMessageCacheEntries) {
      _sessionMessagesLruCache.remove(_sessionMessagesLruCache.keys.first);
    }
  }

  List<ChatMessage>? _cachedSessionMessages(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return null;
    }
    final cached = _sessionMessagesLruCache.remove(normalizedSessionId);
    if (cached == null) {
      return null;
    }
    _sessionMessagesLruCache[normalizedSessionId] = cached;
    return List<ChatMessage>.from(cached);
  }

  void _removeSessionMessagesCache(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    _sessionMessagesLruCache.remove(normalizedSessionId);
  }

  Future<void> _persistSessionMessagesSnapshotBestEffort(
    String sessionId,
    List<ChatMessage> messages, {
    String? serverId,
    String? scopeId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    final filteredMessages = _cacheableSessionMessages(
      normalizedSessionId,
      messages,
    );
    if (filteredMessages.isEmpty) {
      return;
    }

    _pendingSessionMessagesSnapshotWrites[normalizedSessionId] =
        _SessionMessagesSnapshotWriteRequest(
          messages: List<ChatMessage>.unmodifiable(filteredMessages),
          serverId: serverId,
          scopeId: scopeId,
        );
    final existingTask =
        _sessionMessagesSnapshotWriteTasks[normalizedSessionId];
    if (existingTask != null) {
      await existingTask;
      return;
    }

    await _startSessionMessagesSnapshotWriteDrain(normalizedSessionId);
  }

  Future<void> _startSessionMessagesSnapshotWriteDrain(String sessionId) {
    late final Future<void> writeTask;
    writeTask = _drainSessionMessagesSnapshotWrites(sessionId);
    _sessionMessagesSnapshotWriteTasks[sessionId] = writeTask;
    unawaited(
      writeTask.whenComplete(() {
        if (!identical(
          _sessionMessagesSnapshotWriteTasks[sessionId],
          writeTask,
        )) {
          return;
        }
        _sessionMessagesSnapshotWriteTasks.remove(sessionId);
        if (_pendingSessionMessagesSnapshotWrites.containsKey(sessionId)) {
          unawaited(_startSessionMessagesSnapshotWriteDrain(sessionId));
        }
      }),
    );
    return writeTask;
  }

  Future<void> _drainSessionMessagesSnapshotWrites(String sessionId) async {
    // Yield once so synchronous bursts share the same latest request without
    // delaying the first persistence beyond the current event turn.
    await Future<void>.value();
    while (true) {
      final request = _pendingSessionMessagesSnapshotWrites.remove(sessionId);
      if (request == null) return;
      await _writeSessionMessagesSnapshotBestEffort(
        sessionId,
        request.messages,
        serverId: request.serverId,
        scopeId: request.scopeId,
      );
      if (!_pendingSessionMessagesSnapshotWrites.containsKey(sessionId)) {
        return;
      }
    }
  }

  Future<void> _writeSessionMessagesSnapshotBestEffort(
    String normalizedSessionId,
    List<ChatMessage> filteredMessages, {
    String? serverId,
    String? scopeId,
  }) async {
    try {
      await AppLogger.runPerformanceTask<void>(
        'session_snapshot_write',
        () async {
          final resolvedServerId =
              serverId ?? await _resolveServerIdForStorage();
          final resolvedScopeId = scopeId ?? _resolveContextScopeId();
          final payload = <String, dynamic>{
            'sessionId': normalizedSessionId,
            'messages': filteredMessages
                .map((message) => ChatMessageModel.fromDomain(message).toJson())
                .toList(growable: false),
          };
          final encodeStopwatch = Stopwatch()..start();
          final encodedPayload = json.encode(payload);
          encodeStopwatch.stop();
          AppLogger.recordPerformanceTask(
            operation: 'session_snapshot_encode',
            elapsed: encodeStopwatch.elapsed,
            status: 'ok',
            tags: const <String>{'chat:snapshot', 'cache:encode'},
            context: <String, Object?>{
              'sessionHash': AppLogger.safeContextId(normalizedSessionId),
              'messageCount': filteredMessages.length,
            },
          );
          final wrotePayload = await localDataSource
              .saveSessionMessagesSnapshot(
                encodedPayload,
                sessionId: normalizedSessionId,
                serverId: resolvedServerId,
                scopeId: resolvedScopeId,
              );
          // Skip the updatedAt metadata write when the payload is unchanged:
          // on desktop each setInt rewrites the whole prefs file on the UI
          // isolate (issue #152), and freshness has a multi-day TTL anyway.
          if (wrotePayload) {
            await localDataSource.saveSessionMessagesSnapshotUpdatedAt(
              DateTime.now().millisecondsSinceEpoch,
              sessionId: normalizedSessionId,
              serverId: resolvedServerId,
              scopeId: resolvedScopeId,
            );
          }

          await _touchPersistedSessionMessagesSnapshotId(
            normalizedSessionId,
            serverId: resolvedServerId,
            scopeId: resolvedScopeId,
          );
        },
        tags: const <String>{'chat:snapshot', 'cache:write'},
        context: AppLogger.performanceLoggingEnabled
            ? <String, Object?>{
                'sessionHash': AppLogger.safeContextId(normalizedSessionId),
                'messageCount': filteredMessages.length,
              }
            : null,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to persist per-session message snapshot session=$normalizedSessionId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _touchPersistedSessionMessagesSnapshotId(
    String sessionId, {
    required String serverId,
    required String scopeId,
  }) async {
    final existingRaw = await localDataSource.getSessionMessagesSnapshotIds(
      serverId: serverId,
      scopeId: scopeId,
    );
    var existing = <String>[];
    if (existingRaw != null && existingRaw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(existingRaw);
        if (decoded is List) {
          existing = decoded
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList(growable: true);
        }
      } catch (_) {
        existing = <String>[];
      }
    }

    existing.remove(sessionId);
    existing.add(sessionId);
    while (existing.length >
        ChatProvider._maxPersistedSessionMessageSnapshots) {
      final removed = existing.removeAt(0);
      await localDataSource.clearSessionMessagesSnapshot(
        sessionId: removed,
        serverId: serverId,
        scopeId: scopeId,
      );
    }

    await localDataSource.saveSessionMessagesSnapshotIds(
      json.encode(existing),
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Future<List<ChatMessage>?> _restoreSessionMessagesSnapshot(
    String sessionId, {
    required String serverId,
    required String scopeId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return null;
    }

    try {
      return await AppLogger.runPerformanceTask<List<ChatMessage>?>(
        'session_snapshot_restore',
        () async {
          final snapshotJson = await localDataSource.getSessionMessagesSnapshot(
            sessionId: normalizedSessionId,
            serverId: serverId,
            scopeId: scopeId,
          );
          if (snapshotJson == null || snapshotJson.trim().isEmpty) {
            return null;
          }

          final updatedAtMs = await localDataSource
              .getSessionMessagesSnapshotUpdatedAt(
                sessionId: normalizedSessionId,
                serverId: serverId,
                scopeId: scopeId,
              );
          final isFresh =
              updatedAtMs != null &&
              DateTime.now().difference(
                    DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
                  ) <=
                  ChatProvider._sessionMessagesSnapshotTtl;

          final decoded = json.decode(snapshotJson);
          if (decoded is! Map<String, dynamic>) {
            return null;
          }
          final messagesJson = decoded['messages'];
          if (messagesJson is! List) {
            return null;
          }
          final messages = _restoreableCachedMessages(
            messagesJson
                .whereType<Map<String, dynamic>>()
                .map((item) => ChatMessageModel.fromJson(item).toDomain())
                .where((message) => message.sessionId == normalizedSessionId)
                .toList(growable: false),
          );
          if (messages.isEmpty) {
            return null;
          }

          if (!isFresh) {
            AppLogger.info(
              'Per-session message snapshot is stale (> ${ChatProvider._sessionMessagesSnapshotTtl.inDays} days) session=$normalizedSessionId',
            );
          }
          return messages;
        },
        tags: const <String>{'chat:snapshot', 'cache:read'},
        context: AppLogger.performanceLoggingEnabled
            ? <String, Object?>{
                'sessionHash': AppLogger.safeContextId(normalizedSessionId),
              }
            : null,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to restore per-session message snapshot session=$normalizedSessionId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<List<ChatMessage>?> _restoreSessionMessagesFromCache(
    String sessionId, {
    required String serverId,
    required String scopeId,
  }) async {
    final inMemory = _cachedSessionMessages(sessionId);
    if (inMemory != null && inMemory.isNotEmpty) {
      return _boundRestoredSessionMessages(inMemory);
    }
    final fromDisk = await _restoreSessionMessagesSnapshot(
      sessionId,
      serverId: serverId,
      scopeId: scopeId,
    );
    if (fromDisk == null || fromDisk.isEmpty) {
      return null;
    }
    final boundedFromDisk = _boundRestoredSessionMessages(fromDisk);
    _cacheSessionMessages(sessionId, boundedFromDisk);
    return boundedFromDisk;
  }

  void _sortSessionsInPlace() {
    _sessions.sort((a, b) => _compareSessionsForSidebarOrder(a, b));
  }

  Future<void> _loadCachedSessions({
    required String serverId,
    required String scopeId,
  }) async {
    try {
      final cachedData = await localDataSource.getCachedSessions(
        serverId: serverId,
        scopeId: scopeId,
      );
      final cachedAtMs = await localDataSource.getCachedSessionsUpdatedAt(
        serverId: serverId,
        scopeId: scopeId,
      );
      final isFresh =
          cachedAtMs != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(cachedAtMs),
              ) <=
              ChatProvider._sessionsCacheTtl;
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        final cachedSessions = _filterSessionsForCurrentContext(
          jsonList
              .map((json) => ChatSessionModel.fromJson(json).toDomain())
              .toList(),
        );

        if (cachedSessions.isNotEmpty) {
          _sessions = cachedSessions;
          _threadPermissionsVersion++;
          _sortSessionsInPlace();
          _setState(ChatState.loaded);
          if (!isFresh) {
            AppLogger.info(
              'Session cache is stale (> ${ChatProvider._sessionsCacheTtl.inDays} days). Refreshing from server.',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to load cached sessions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveCachedSessions(
    List<ChatSession> sessions, {
    required String serverId,
    required String scopeId,
  }) async {
    try {
      final jsonList = sessions
          .map((session) => ChatSessionModel.fromDomain(session).toJson())
          .toList();
      final jsonString = json.encode(jsonList);
      await localDataSource.saveCachedSessions(
        jsonString,
        serverId: serverId,
        scopeId: scopeId,
      );
      await localDataSource.saveCachedSessionsUpdatedAt(
        DateTime.now().millisecondsSinceEpoch,
        serverId: serverId,
        scopeId: scopeId,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to save session cache',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _restoreLastSessionSnapshotFromCache({
    required String serverId,
    required String scopeId,
    required String? preferredSessionId,
  }) async {
    try {
      final snapshotJson = await localDataSource.getLastSessionSnapshot(
        serverId: serverId,
        scopeId: scopeId,
      );
      if (snapshotJson == null || snapshotJson.trim().isEmpty) {
        return;
      }

      final updatedAtMs = await localDataSource.getLastSessionSnapshotUpdatedAt(
        serverId: serverId,
        scopeId: scopeId,
      );
      final isFresh =
          updatedAtMs != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
              ) <=
              ChatProvider._lastSessionSnapshotTtl;

      final decoded = json.decode(snapshotJson);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final sessionJson = decoded['session'];
      final messagesJson = decoded['messages'];
      if (sessionJson is! Map<String, dynamic> || messagesJson is! List) {
        return;
      }

      final session = ChatSessionModel.fromJson(sessionJson).toDomain();
      if (_filterSessionsForCurrentContext(<ChatSession>[session]).isEmpty) {
        return;
      }

      if (preferredSessionId != null &&
          preferredSessionId.trim().isNotEmpty &&
          preferredSessionId != session.id) {
        return;
      }

      if (_isNewChatDraftActive) {
        return;
      }

      // Guard against overwriting a session that was already switched
      // in memory by selectSession() during the async cache read above.
      final inMemoryId = _currentSession?.id;
      if (inMemoryId != null &&
          inMemoryId.trim().isNotEmpty &&
          inMemoryId != session.id) {
        return;
      }

      final selectedSession =
          _sessions.where((item) => item.id == session.id).firstOrNull ??
          session;
      final cachedMessages = _boundRestoredSessionMessages(
        _restoreableCachedMessages(
          messagesJson
              .whereType<Map<String, dynamic>>()
              .map((item) => ChatMessageModel.fromJson(item).toDomain())
              .where((message) => message.sessionId == selectedSession.id)
              .toList(growable: false),
        ),
      );
      if (cachedMessages.isEmpty) {
        return;
      }

      _currentSession = selectedSession;
      _dismissNotificationsForSession(selectedSession.id);
      _threadPermissionsVersion++;
      // The current session just changed, so replacing wholesale is intended.
      _applyMessages(
        cachedMessages,
        origin: MessageUpdateOrigin.cacheHydration,
        kind: MessageUpdateKind.reset,
        sessionId: selectedSession.id,
        reason: 'cache-hydration-on-session-switch',
      );
      _cacheSessionMessages(selectedSession.id, cachedMessages);
      _messagesVersion++;
      _hasMoreOldMessages =
          cachedMessages.length >= ChatProvider._initialMessagesWindowSize;
      _pendingLocalUserMessageIds.clear();
      _setState(ChatState.loaded);

      if (!isFresh) {
        AppLogger.info(
          'Last session snapshot is stale (> ${ChatProvider._lastSessionSnapshotTtl.inDays} days). Revalidating in background.',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to restore last session snapshot',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveLastSessionSnapshot(
    ChatSession session,
    List<ChatMessage> messages, {
    required String serverId,
    required String scopeId,
  }) async {
    final cacheableMessages = _cacheableSessionMessages(session.id, messages);
    final payload = <String, dynamic>{
      'session': ChatSessionModel.fromDomain(session).toJson(),
      'messages': cacheableMessages
          .map((message) => ChatMessageModel.fromDomain(message).toJson())
          .toList(growable: false),
    };
    final encodeStopwatch = Stopwatch()..start();
    final encodedPayload = json.encode(payload);
    encodeStopwatch.stop();
    AppLogger.recordPerformanceTask(
      operation: 'session_snapshot_encode',
      elapsed: encodeStopwatch.elapsed,
      status: 'ok',
      tags: const <String>{'chat:snapshot', 'cache:encode'},
      context: <String, Object?>{
        'sessionHash': AppLogger.safeContextId(session.id),
        'messageCount': cacheableMessages.length,
        'lastSession': true,
      },
    );
    await localDataSource.saveLastSessionSnapshot(
      encodedPayload,
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveLastSessionSnapshotUpdatedAt(
      DateTime.now().millisecondsSinceEpoch,
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Future<void> _persistLastSessionSnapshotBestEffort({
    String? serverId,
    String? scopeId,
  }) async {
    final current = _currentSession;
    if (current == null) {
      return;
    }
    _pendingLastSessionSnapshotWrite = _LastSessionSnapshotWriteRequest(
      session: current,
      messages: List<ChatMessage>.unmodifiable(_messages),
      serverId: serverId,
      scopeId: scopeId,
    );
    final existingTask = _lastSessionSnapshotWriteTask;
    if (existingTask != null) {
      await existingTask;
      return;
    }

    await _startLastSessionSnapshotWriteDrain();
  }

  Future<void> _startLastSessionSnapshotWriteDrain() {
    late final Future<void> writeTask;
    writeTask = _drainLastSessionSnapshotWrites();
    _lastSessionSnapshotWriteTask = writeTask;
    unawaited(
      writeTask.whenComplete(() {
        if (!identical(_lastSessionSnapshotWriteTask, writeTask)) {
          return;
        }
        _lastSessionSnapshotWriteTask = null;
        if (_pendingLastSessionSnapshotWrite != null) {
          unawaited(_startLastSessionSnapshotWriteDrain());
        }
      }),
    );
    return writeTask;
  }

  Future<void> _drainLastSessionSnapshotWrites() async {
    await Future<void>.value();
    while (_pendingLastSessionSnapshotWrite != null) {
      final request = _pendingLastSessionSnapshotWrite;
      _pendingLastSessionSnapshotWrite = null;
      if (request == null) return;
      await _writeLastSessionSnapshotBestEffort(request);
    }
  }

  Future<void> _writeLastSessionSnapshotBestEffort(
    _LastSessionSnapshotWriteRequest request,
  ) async {
    try {
      final resolvedServerId =
          request.serverId ?? await _resolveServerIdForStorage();
      final resolvedScopeId = request.scopeId ?? _resolveContextScopeId();
      await _saveLastSessionSnapshot(
        request.session,
        request.messages,
        serverId: resolvedServerId,
        scopeId: resolvedScopeId,
      );
      final current = _currentSession;
      final currentScopeId = normalizeOptionalFilePath(
        _resolveContextScopeId(),
      );
      final writeScopeId = normalizeOptionalFilePath(resolvedScopeId);
      // Keep the per-session cache at least as fresh as a newer live write.
      if (current != null &&
          current.id == request.session.id &&
          currentScopeId == writeScopeId) {
        final currentMessages = List<ChatMessage>.unmodifiable(_messages);
        _cacheSessionMessages(current.id, currentMessages);
        await _persistSessionMessagesSnapshotBestEffort(
          current.id,
          currentMessages,
          serverId: resolvedServerId,
          scopeId: resolvedScopeId,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to persist last session snapshot',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearLastSessionSnapshotBestEffort({
    String? serverId,
    String? scopeId,
  }) async {
    try {
      final resolvedServerId = serverId ?? await _resolveServerIdForStorage();
      final resolvedScopeId = scopeId ?? _resolveContextScopeId();
      await localDataSource.clearLastSessionSnapshot(
        serverId: resolvedServerId,
        scopeId: resolvedScopeId,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to clear last session snapshot',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _clearSessionMessagesSnapshotBestEffort(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }
    try {
      final resolvedServerId = serverId ?? await _resolveServerIdForStorage();
      final resolvedScopeId = scopeId ?? _resolveContextScopeId();
      await localDataSource.clearSessionMessagesSnapshot(
        sessionId: normalizedSessionId,
        serverId: resolvedServerId,
        scopeId: resolvedScopeId,
      );

      final snapshotIdsRaw = await localDataSource
          .getSessionMessagesSnapshotIds(
            serverId: resolvedServerId,
            scopeId: resolvedScopeId,
          );
      if (snapshotIdsRaw != null && snapshotIdsRaw.trim().isNotEmpty) {
        try {
          final decoded = json.decode(snapshotIdsRaw);
          if (decoded is List) {
            final nextIds = decoded
                .whereType<String>()
                .map((id) => id.trim())
                .where((id) => id.isNotEmpty && id != normalizedSessionId)
                .toList(growable: false);
            await localDataSource.saveSessionMessagesSnapshotIds(
              json.encode(nextIds),
              serverId: resolvedServerId,
              scopeId: resolvedScopeId,
            );
          }
        } catch (_) {
          // Ignore malformed snapshot ID payloads during cleanup.
        }
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to clear per-session message snapshot session=$normalizedSessionId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _persistSessionCacheBestEffort({
    String? serverId,
    String? scopeId,
  }) async {
    try {
      final resolvedServerId = serverId ?? await _resolveServerIdForStorage();
      final resolvedScopeId = scopeId ?? _resolveContextScopeId();
      await _saveCachedSessions(
        _sessions,
        serverId: resolvedServerId,
        scopeId: resolvedScopeId,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to persist sessions cache',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String> _resolveServerIdForStorage() async {
    final stored = await localDataSource.getActiveServerId();
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final current = _activeServerId.trim();
    if (current.isNotEmpty) {
      return current;
    }
    return 'legacy';
  }

  Future<void> _saveCurrentSessionId(
    String sessionId, {
    required String serverId,
    required String scopeId,
  }) async {
    final queueKey = '$serverId::$scopeId';
    final previous =
        _currentSessionIdWriteQueueByScope[queueKey] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        await localDataSource.saveCurrentSessionId(
          sessionId,
          serverId: serverId,
          scopeId: scopeId,
        );
      } catch (e, stackTrace) {
        AppLogger.warn(
          'Failed to save current session ID',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
    _currentSessionIdWriteQueueByScope[queueKey] = next;
    try {
      await next;
    } finally {
      if (identical(_currentSessionIdWriteQueueByScope[queueKey], next)) {
        _currentSessionIdWriteQueueByScope.remove(queueKey);
      }
    }
  }
}
