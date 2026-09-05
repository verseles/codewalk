part of '../chat_provider.dart';

extension _ChatProviderEventReducerSessionOps on ChatProvider {
  void _applyChatEvent(ChatEvent event) {
    final eventSessionId = _effectiveEventSessionIdForEvent(event);
    final task = AppLogger.beginTask(
      'realtime_event',
      tags: const <String>{'chat:realtime'},
      context: <String, Object?>{
        'eventType': event.type,
        if (eventSessionId != null)
          'sessionId': AppLogger.safeContextId(eventSessionId),
      },
    );
    try {
      _applyChatEventInner(event);
      _updateSessionTabSignalsForEvent(event, contextKey: _activeContextKey);
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
      task.end();
    } catch (error, stackTrace) {
      task.end(status: 'error', error: error, stackTrace: stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _applyChatEventInner(ChatEvent event) {
    if (event.type == 'session.idle') {
      final sessionId = _effectiveEventSessionIdForEvent(event);
      if (sessionId != null) {
        titleGenerator?.notifySessionIdle(
          sessionId: sessionId,
          directory: projectProvider.currentDirectory,
        );
      }
    }
    if (_isEphemeralTitleEvent(event)) return;
    // Claim the event in the shared dedup buffer so the paired session/global
    // stream skips exact duplicates regardless of which stream arrives first.
    if (_claimRecentlyProcessedEvent(event)) {
      return;
    }
    final eventSessionId = _effectiveEventSessionIdForEvent(event);
    if (_shouldSuppressAggressiveDataSaverEvent(event, eventSessionId)) {
      _dirtyContextKeys.add(_activeContextKey);
      AppLogger.info(
        'data_saver_aggressive_event_suppressed type=${event.type} session=${eventSessionId ?? "-"}',
      );
      return;
    }
    final feedbackEvent = _feedbackEventForCurrentContext(event);
    final feedbackSessionId = feedbackEvent == null
        ? null
        : _extractEventSessionId(feedbackEvent.properties);
    final visibleCurrentSessionId = _isChatRouteActive
        ? _currentSession?.id
        : null;
    final suppressCurrentIdleFeedback =
        feedbackEvent != null &&
        feedbackEvent.type == 'session.idle' &&
        event.type == 'session.idle' &&
        feedbackSessionId != null &&
        _isChatRouteActive &&
        _hasInFlightSendTurnForSession(feedbackSessionId);
    final suppressCurrentErrorFeedback =
        feedbackEvent != null &&
        feedbackEvent.type == 'session.error' &&
        feedbackSessionId != null &&
        (() {
          final payload = _extractSessionErrorMessageAndCode(
            feedbackEvent.properties,
          );
          if (_shouldSuppressAbortError(
            sessionId: feedbackSessionId,
            message: payload.message,
            code: payload.code,
          )) {
            return true;
          }
          return _isChatRouteActive &&
              _hasInFlightSendTurnForSession(feedbackSessionId) &&
              _isRemoteAbortError(message: payload.message, code: payload.code);
        })();
    if (feedbackEvent != null) {
      if (suppressCurrentIdleFeedback) {
        _traceFinal(
          'event-session-idle-feedback-suppressed-active-send',
          sessionId: feedbackSessionId,
        );
      } else if (suppressCurrentErrorFeedback) {
        _traceFinal(
          'event-session-error-feedback-suppressed-expected-abort',
          sessionId: feedbackSessionId,
        );
      } else {
        final sessionTitleHint = _sessionTitleForNotification(
          feedbackSessionId,
        );
        unawaited(
          eventFeedbackDispatcher?.handle(
            feedbackEvent,
            sessionTitleHint: sessionTitleHint,
            isRootSession: _isRootSessionId(feedbackSessionId),
            isAppInForeground: _isAppInForeground,
            currentSessionId: visibleCurrentSessionId,
            serverId: _activeServerId,
          ),
        );
      }
    }
    final properties = event.properties;
    final currentSessionId = _currentSession?.id;
    final eventTargetsCurrentSession =
        eventSessionId != null &&
        (currentSessionId == null || eventSessionId == currentSessionId);
    if (event.type != 'server.connected' &&
        eventTargetsCurrentSession &&
        !_cellularDataSaverService.isAggressiveDataSaverActive &&
        (event.type == 'session.status' ||
            event.type == 'message.created' ||
            event.type == 'message.updated' ||
            event.type == 'session.updated' ||
            event.type == 'session.created')) {
      unawaited(_syncSelectionFromRemote(reason: 'event-${event.type}'));
    }
    switch (event.type) {
      case 'server.heartbeat':
        break;
      case 'server.connected':
        if (_cellularDataSaverService.isAggressiveDataSaverActive) {
          if (_hasVisibleAggressiveDataSaverSession) {
            unawaited(
              refreshActiveSessionView(
                reason: 'realtime-server-connected',
                includeStatus: false,
              ),
            );
          }
        } else {
          unawaited(
            refreshActiveSessionView(reason: 'realtime-server-connected'),
          );
          unawaited(
            _syncSelectionFromRemote(
              reason: 'event-server-connected',
              force: true,
            ),
          );
        }
        break;
      case 'session.created':
      case 'session.updated':
        final info = properties['info'];
        if (info is Map<String, dynamic>) {
          final incomingSession = ChatSessionModel.fromJson(info).toDomain();
          if (incomingSession.id.isEmpty) {
            break;
          }
          final existing = _sessionById(incomingSession.id);
          final hasIncomingTime = info.containsKey('time');
          if (existing != null &&
              hasIncomingTime &&
              incomingSession.time.isBefore(existing.time)) {
            AppLogger.debug(
              'Ignoring stale session event for ${incomingSession.id}: incoming=${incomingSession.time.toIso8601String()} existing=${existing.time.toIso8601String()}',
            );
            break;
          }
          final nextSession = _mergeSessionFromEventInfo(
            incoming: incomingSession,
            existing: existing,
            info: info,
          );
          if (existing == nextSession) {
            break;
          }
          final pendingRename = _pendingRenameTitleBySessionId[nextSession.id];
          if (pendingRename != null) {
            final incomingTitle = nextSession.title?.trim();
            if (incomingTitle == pendingRename) {
              _pendingRenameTitleBySessionId.remove(nextSession.id);
            } else {
              AppLogger.debug(
                'Ignoring conflicting session.updated while rename is pending for ${nextSession.id}',
              );
              break;
            }
          }
          _upsertSession(nextSession);
          if (nextSession.archived) {
            _deleteSessionAttentionSnapshot(
              contextKey: _activeContextKey,
              sessionId: nextSession.id,
            );
          }
          if (_currentSession?.id == nextSession.id) {
            final previousRevert = _currentSession?.revert;
            _currentSession = nextSession;
            _dismissNotificationsForSession(nextSession.id);
            _threadPermissionsVersion++;
            if (previousRevert != nextSession.revert) {
              _messagesVersion++;
            }
          }
          _scheduleRealtimeNotification(reason: 'event-session.updated');
        }
        break;
      case 'session.deleted':
        final info = properties['info'];
        final sessionId =
            (info is Map<String, dynamic> ? info['id'] as String? : null) ??
            properties['sessionID'] as String? ??
            properties['id'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          _deleteSessionAttentionSnapshot(
            contextKey: _activeContextKey,
            sessionId: sessionId,
          );
          final deletedCurrent = _currentSession?.id == sessionId;
          _removeSessionById(sessionId);
          if (deletedCurrent && _currentSession != null) {
            unawaited(loadMessages(_currentSession!.id));
            unawaited(loadSessionInsights(_currentSession!.id, silent: true));
          }
          _notifyListeners();
        }
        break;
      case 'session.status':
        final sessionId = properties['sessionID'] as String?;
        final statusMap = properties['status'];
        if (sessionId != null && statusMap is Map<String, dynamic>) {
          final status = SessionStatusModel.fromJson(statusMap).toDomain();
          final previousStatus = _sessionStatusById[sessionId];
          final previousStatusType = previousStatus?.type;
          final isNonCurrent = _isNonCurrentSessionEvent(sessionId);
          final isCurrentSession = sessionId == _currentSession?.id;
          final isVisibleCurrentSession =
              isCurrentSession && _isChatRouteActive;
          final changed = isNonCurrent
              ? previousStatusType != status.type
              : previousStatus != status;
          if (!changed) {
            break;
          }
          _sessionStatusById[sessionId] = status;
          if (status.type == SessionStatusType.busy ||
              status.type == SessionStatusType.retry) {
            _sessionUnreadCompletionIds.remove(sessionId);
          } else if (status.type == SessionStatusType.idle &&
              !isVisibleCurrentSession &&
              (previousStatusType == SessionStatusType.busy ||
                  previousStatusType == SessionStatusType.retry)) {
            _markSessionUnreadCompletion(sessionId);
            _resolveSessionAttentionCompletion(
              contextKey: _activeContextKey,
              sessionId: sessionId,
              completedAt: DateTime.now(),
            );
          }
          if (isVisibleCurrentSession) {
            _clearSessionAttentionForSession(sessionId);
          }
          _scheduleRealtimeNotification(reason: 'event-session.status');
          if (!isNonCurrent || _pendingRemoteSelectionSync) {
            _attemptPendingRemoteSelectionSync(reason: 'event-session.status');
          }
        }
        break;
      case 'session.diff':
        final sessionId = properties['sessionID'] as String?;
        final diffRaw = properties['diff'];
        if (sessionId != null && diffRaw is List) {
          if (_isNonCurrentSessionEvent(sessionId)) {
            break;
          }
          final parsed = diffRaw
              .whereType<Map>()
              .map(
                (item) => SessionDiffModel.fromJson(
                  Map<String, dynamic>.from(item),
                ).toDomain(),
              )
              .toList(growable: false);

          final existing = _sessionDiffById[sessionId];
          // Preserve a known-good diff when the SSE event carries an empty
          // list. The authoritative source for the file list is the
          // turn-by-turn summary in the server, and a transient empty
          // payload from another client must not erase the local view.
          if (parsed.isEmpty && existing != null && existing.isNotEmpty) {
            break;
          }
          // Merge guard: if incoming SSE item has no content (empty before/after
          // AND no patch), preserve existing non-empty stored content for same file
          if (existing != null && existing.isNotEmpty) {
            final merged = <SessionDiff>[];
            final existingByFile = {for (final e in existing) e.file: e};

            for (final incoming in parsed) {
              final prev = existingByFile[incoming.file];
              final incomingHasContent =
                  incoming.patch != null && incoming.patch!.isNotEmpty ||
                  incoming.before.isNotEmpty ||
                  incoming.after.isNotEmpty;
              final prevHasContent =
                  (prev?.patch != null && prev!.patch!.isNotEmpty) ||
                  (prev?.before.isNotEmpty ?? false) ||
                  (prev?.after.isNotEmpty ?? false);
              if (prev != null && !incomingHasContent && prevHasContent) {
                // Keep existing content — incoming SSE has no snapshot or patch
                merged.add(prev);
              } else {
                merged.add(incoming);
              }
            }
            _sessionDiffById[sessionId] = merged;
          } else {
            _sessionDiffById[sessionId] = parsed;
          }
          _scheduleRealtimeNotification(reason: 'event-session.diff');
        }
        break;
      case 'todo.updated':
        final sessionId = properties['sessionID'] as String?;
        final todosRaw = properties['todos'];
        if (sessionId != null && todosRaw is List) {
          if (_isNonCurrentSessionEvent(sessionId)) {
            break;
          }
          final parsed = todosRaw
              .whereType<Map>()
              .map(
                (item) => SessionTodo(
                  id: item['id'] as String? ?? '',
                  content: item['content'] as String? ?? '',
                  status: item['status'] as String? ?? 'pending',
                  priority: item['priority'] as String? ?? 'medium',
                ),
              )
              .toList(growable: false);
          _sessionTodoById[sessionId] = parsed;
          _scheduleRealtimeNotification(reason: 'event-todo.updated');
        }
        break;
      case 'session.idle':
        final sessionId = properties['sessionID'] as String?;
        if (sessionId != null) {
          _flushDeltaNotification(reason: 'event-session.idle');
          final isCurrentSession = sessionId == _currentSession?.id;
          final isVisibleCurrentSession =
              isCurrentSession && _isChatRouteActive;
          final hasActiveCurrentSendTurn = _hasInFlightSendTurnForSession(
            sessionId,
          );
          final previousStatusType = _sessionStatusById[sessionId]?.type;
          final wasBusyBeforeIdle =
              previousStatusType == SessionStatusType.busy ||
              previousStatusType == SessionStatusType.retry;
          final hadErrorAttention = _sessionErrorAttentionIds.contains(
            sessionId,
          );
          final shouldPersistCompletion =
              !isVisibleCurrentSession &&
              (wasBusyBeforeIdle || previousStatusType == null);
          if (shouldPersistCompletion) {
            _resolveSessionAttentionCompletion(
              contextKey: _activeContextKey,
              sessionId: sessionId,
              completedAt: DateTime.now(),
            );
          }
          if (!isCurrentSession &&
              previousStatusType == SessionStatusType.idle &&
              !hadErrorAttention) {
            break;
          }
          _sessionStatusById[sessionId] = const SessionStatusInfo(
            type: SessionStatusType.idle,
          );
          _traceFinal(
            'event-session-idle',
            sessionId: sessionId,
            details:
                'isCurrent=$isCurrentSession activeSend=$hasActiveCurrentSendTurn',
          );
          AppLogger.info(
            'session.idle session=$sessionId isCurrent=$isCurrentSession activeSend=$hasActiveCurrentSendTurn',
          );
          if (!hasActiveCurrentSendTurn) {
            _markIncompleteAssistantMessagesAsCompleted(sessionId: sessionId);
          }
          _sessionErrorAttentionIds.remove(sessionId);
          if (isCurrentSession) {
            if (isVisibleCurrentSession) {
              _clearSessionAttentionForSession(sessionId);
              // Reactive dismiss: the user is already viewing this session, so
              // any lingering notification (completion, error, permission) is
              // stale and should be removed immediately.
              unawaited(eventFeedbackDispatcher?.dismissForSession(sessionId));
            } else if (wasBusyBeforeIdle || previousStatusType == null) {
              _markSessionUnreadCompletion(sessionId);
            }
            _clearActiveSendDraft();
            // OpenCode's session.idle is the terminal lifecycle signal for a
            // turn. End the active-send UI immediately even if CodeWalk's
            // fallback stream is still draining in the background; otherwise
            // the composer status can keep showing stale progress after the
            // final assistant response is already visible.
            _activeMessageStreamSessionId = null;
            _markIncompleteAssistantMessagesAsCompleted(sessionId: sessionId);
            // Cancel pending debounced message fallback timers — session.idle is
            // the terminal signal; no further remote resolution is needed. This
            // prevents unnecessary HTTP GETs that the monotonic guard would
            // discard.
            for (final entry in _messageFallbackDebounceById.entries.toList()) {
              final messageId = entry.key;
              final msgIndex = _messages.indexWhere((m) => m.id == messageId);
              if (msgIndex != -1 &&
                  _messages[msgIndex].sessionId == sessionId) {
                entry.value.cancel();
                _messageFallbackDebounceById.remove(messageId);
              }
            }
            if (_state == ChatState.sending) {
              _setState(ChatState.loaded);
            } else {
              _notifyListeners();
            }
          } else {
            if (wasBusyBeforeIdle || previousStatusType == null) {
              _markSessionUnreadCompletion(sessionId);
            }
            _notifyListeners();
          }
          if (isCurrentSession || _pendingRemoteSelectionSync) {
            _attemptPendingRemoteSelectionSync(reason: 'event-session.idle');
          }
        }
        break;
      case 'session.error':
        final sessionId = properties['sessionID'] as String?;
        if (sessionId == null) {
          break;
        }
        // Review R1: terminal signal — flush any pending realtime batch
        // first so the error UI isn't followed by a redundant delayed
        // rebuild (mirrors session.idle above).
        _flushDeltaNotification(reason: 'event-session.error');
        _traceFinal('event-session-error', sessionId: sessionId);

        if (sessionId != _currentSession?.id) {
          _sessionStatusById[sessionId] = const SessionStatusInfo(
            type: SessionStatusType.idle,
          );
          AppLogger.info('session.error non-current session=$sessionId');
          _markIncompleteAssistantMessagesAsCompleted(sessionId: sessionId);
          _sessionUnreadCompletionIds.remove(sessionId);
          // Subagents finish silently: a failing child must not raise an
          // attention surface on the session the user is actually reading.
          if (!_isChildSessionId(sessionId)) {
            _sessionErrorAttentionIds.add(sessionId);
          }
          _notifyListeners();
          break;
        }

        final payload = _extractSessionErrorMessageAndCode(properties);
        final message = payload.message;
        final code = payload.code;
        final rawError = properties['error'];
        final error = rawError is Map
            ? Map<String, dynamic>.from(rawError)
            : null;
        final dataRaw = error?['data'];
        final data = dataRaw is Map
            ? Map<String, dynamic>.from(dataRaw)
            : const <String, dynamic>{};
        final statusCodeRaw =
            data['statusCode'] ??
            data['status'] ??
            error?['statusCode'] ??
            error?['status'];
        final statusCode = statusCodeRaw is num
            ? statusCodeRaw.toInt()
            : int.tryParse(statusCodeRaw?.toString() ?? '');
        _traceFinal(
          'event-session-error-current-session-payload',
          sessionId: sessionId,
          details: 'code=${code ?? "-"} message=$message',
        );
        AppLogger.info(
          'session.error current session=$sessionId message=$message code=$code',
        );
        final hasActiveCurrentSendTurn = _hasInFlightSendTurnForSession(
          sessionId,
        );
        if (_shouldSuppressAbortError(
          sessionId: sessionId,
          message: message,
          code: code,
        )) {
          if (!hasActiveCurrentSendTurn) {
            _sessionStatusById[sessionId] = const SessionStatusInfo(
              type: SessionStatusType.idle,
            );
          }
          _clearSessionAttentionForSession(sessionId);
          _errorMessage = null;
          if (!hasActiveCurrentSendTurn) {
            _setState(ChatState.loaded);
          }
          break;
        }
        if (_isRemoteAbortError(message: message, code: code)) {
          if (!hasActiveCurrentSendTurn) {
            _sessionStatusById[sessionId] = const SessionStatusInfo(
              type: SessionStatusType.idle,
            );
          }
          _clearSessionAttentionForSession(sessionId);
          _errorMessage = null;
          if (!hasActiveCurrentSendTurn) {
            _markIncompleteAssistantMessagesAsCompleted(sessionId: sessionId);
            _appendInlineAbortMessage(sessionId: sessionId);
            _setState(ChatState.loaded);
          }
          break;
        }
        _presentServerErrorForCurrentSession(
          sessionId: sessionId,
          rawMessage: message,
          code: code,
          statusCode: statusCode,
        );
        break;
      case 'message.updated':
      case 'message.created':
        final info = properties['info'] as Map<String, dynamic>?;
        final sessionId = info == null
            ? null
            : _readTrimmedEventString(info, 'sessionID') ??
                  _readTrimmedEventString(info, 'sessionId') ??
                  eventSessionId;
        final messageId = info == null
            ? null
            : _readTrimmedEventString(info, 'id') ??
                  _readTrimmedEventString(info, 'messageID') ??
                  _readTrimmedEventString(info, 'messageId');
        if (sessionId != null && messageId != null) {
          final isCurrentSession = _currentSession?.id == sessionId;
          if (!isCurrentSession) {
            break;
          }
          final existingIndex = _messages.indexWhere(
            (message) => message.id == messageId,
          );
          if (event.type == 'message.created' && existingIndex != -1) {
            final existing = _messages[existingIndex];
            if (existing is AssistantMessage && existing.isCompleted) {
              _traceFinal(
                'event-${event.type}-fallback-skip-completed-local',
                sessionId: sessionId,
                details: 'messageId=$messageId',
              );
              break;
            }
          }
          _traceFinal(
            'event-${event.type}-fallback-fetch',
            sessionId: sessionId,
            details:
                'messageId=$messageId applyToCurrentSession=$isCurrentSession',
          );
          unawaited(_fetchMessageFallback(sessionId, messageId));
        }
        break;
      case 'message.part.updated':
      case 'message.part.delta':
        final partMap = properties['part'] as Map<String, dynamic>?;
        final part = partMap == null
            ? null
            : MessagePartModel.fromJson(partMap).toDomain();
        final partSessionId = part?.sessionId.trim();
        final partMessageId = part?.messageId.trim();
        final sessionId =
            (partSessionId == null || partSessionId.isEmpty
                ? null
                : partSessionId) ??
            _readTrimmedEventString(properties, 'sessionID') ??
            _readTrimmedEventString(properties, 'sessionId') ??
            eventSessionId;
        final messageId =
            (partMessageId == null || partMessageId.isEmpty
                ? null
                : partMessageId) ??
            _readTrimmedEventString(properties, 'messageID') ??
            _readTrimmedEventString(properties, 'messageId');
        if (sessionId == null ||
            messageId == null ||
            _currentSession?.id != sessionId) {
          break;
        }

        final partIndex = _messages.indexWhere((item) => item.id == messageId);
        final delta = properties['delta'] as String?;
        if (part == null) {
          if (partIndex == -1) {
            unawaited(_fetchMessageFallback(sessionId, messageId));
            break;
          }
          final partId = properties['partID'] as String?;
          final field = properties['field'] as String?;
          if (event.type == 'message.part.delta' &&
              partId != null &&
              field != null &&
              delta != null) {
            final message = _messages[partIndex];
            final nextParts = List<MessagePart>.from(message.parts);
            final existingPartIndex = nextParts.indexWhere(
              (item) => item.id == partId,
            );
            if (existingPartIndex == -1) {
              unawaited(_fetchMessageFallback(sessionId, messageId));
              break;
            }
            final existingPart = nextParts[existingPartIndex];
            final partFieldKey = _deltaDedupeFieldKey(existingPart);
            final preferOverlapDedupe =
                partFieldKey != null &&
                _dedupeNextDeltaFieldKeys.remove(partFieldKey);
            final resolvedPart = _mergeFieldDeltaPart(
              existingPart: existingPart,
              field: field,
              delta: delta,
              preferOverlapDedupe: preferOverlapDedupe,
            );
            if (resolvedPart == null) {
              unawaited(_fetchMessageFallback(sessionId, messageId));
              break;
            }
            if (nextParts[existingPartIndex] == resolvedPart) {
              break;
            }
            nextParts[existingPartIndex] = resolvedPart;
            _messages[partIndex] = _copyMessageWithParts(message, nextParts);
            _markLocalMessageDeltaAdvanced(messageId);
            _messagesVersion++;
            _scheduleDeltaNotification(reason: 'event-message-part-delta');
            if (message is AssistantMessage) {
              _scheduleDebouncedMessageFallback(
                sessionId,
                messageId,
                expectedLocalDeltaVersion: _messageLocalDeltaVersion(messageId),
              );
            }
            final updatedMessage = _messages[partIndex];
            if (isSessionActivelyResponding(sessionId) &&
                _shouldSchedulePassiveAutoScrollForSession(
                  sessionId,
                  latestMessage: updatedMessage,
                )) {
              _scheduleScrollToBottom(
                reason: 'event-reducer-message-part-delta',
              );
            }
            break;
          }
          unawaited(_fetchMessageFallback(sessionId, messageId));
          break;
        }
        if (partIndex == -1) {
          unawaited(_fetchMessageFallback(sessionId, messageId));
          break;
        }
        final incomingPart = part;
        var resolvedPart = incomingPart;
        final message = _messages[partIndex];
        final nextParts = List<MessagePart>.from(message.parts);
        final existingPartIndex = nextParts.indexWhere(
          (item) => item.id == incomingPart.id,
        );
        if (existingPartIndex == -1) {
          if (delta != null && delta.isNotEmpty) {
            unawaited(_fetchMessageFallback(sessionId, messageId));
            break;
          }
          nextParts.add(incomingPart);
        } else {
          final partFieldKey = _deltaDedupeFieldKey(incomingPart);
          if (delta != null && delta.isNotEmpty) {
            final preferOverlapDedupe =
                partFieldKey != null &&
                _dedupeNextDeltaFieldKeys.remove(partFieldKey);
            final mergedPart = _mergeIncrementalPartUpdate(
              existingPart: nextParts[existingPartIndex],
              incomingPart: incomingPart,
              delta: delta,
              preferOverlapDedupe: preferOverlapDedupe,
            );
            if (mergedPart == null) {
              unawaited(_fetchMessageFallback(sessionId, messageId));
              break;
            }
            resolvedPart = mergedPart;
          }
          if (partFieldKey != null) {
            if (_shouldMarkNextDeltaDedupe(
              existingPart: nextParts[existingPartIndex],
              incomingPart: incomingPart,
              delta: delta ?? '',
            )) {
              _rememberNextDeltaDedupeField(partFieldKey);
            } else if (delta != null && delta.isNotEmpty) {
              _dedupeNextDeltaFieldKeys.remove(partFieldKey);
            }
          }
          resolvedPart = _preserveNonRegressivePartUpdate(
            existingPart: nextParts[existingPartIndex],
            incomingPart: resolvedPart,
          );
          if (nextParts[existingPartIndex] == resolvedPart) {
            break;
          }
          nextParts[existingPartIndex] = resolvedPart;
        }
        _messages[partIndex] = _copyMessageWithParts(message, nextParts);
        _markLocalMessageDeltaAdvanced(messageId);
        _messagesVersion++;
        if (event.type == 'message.part.delta' &&
            delta != null &&
            delta.isNotEmpty) {
          _scheduleDeltaNotification(reason: 'event-message-part-delta');
        } else {
          _scheduleRealtimeNotification(reason: 'event-message-part-updated');
        }
        final shouldAutoScroll =
            existingPartIndex == -1 ||
            resolvedPart is TextPart ||
            resolvedPart is ReasoningPart;
        if (delta != null && delta.isNotEmpty && message is AssistantMessage) {
          _scheduleDebouncedMessageFallback(
            sessionId,
            messageId,
            expectedLocalDeltaVersion: _messageLocalDeltaVersion(messageId),
          );
        }
        final updatedMessage = _messages[partIndex];
        if (shouldAutoScroll &&
            isSessionActivelyResponding(sessionId) &&
            _shouldSchedulePassiveAutoScrollForSession(
              sessionId,
              latestMessage: updatedMessage,
            )) {
          _scheduleScrollToBottom(reason: 'event-reducer-message-part-updated');
        }
        break;
      case 'message.part.removed':
        final sessionId = properties['sessionID'] as String?;
        final messageId = properties['messageID'] as String?;
        final partId = properties['partID'] as String?;
        if (sessionId == null ||
            messageId == null ||
            partId == null ||
            _currentSession?.id != sessionId) {
          break;
        }
        _rememberRemovedPart(sessionId, messageId, partId);
        final messageIndex = _messages.indexWhere(
          (item) => item.id == messageId,
        );
        if (messageIndex == -1) {
          break;
        }
        final message = _messages[messageIndex];
        final nextParts = message.parts
            .where((part) => part.id != partId)
            .toList(growable: false);
        if (nextParts.length == message.parts.length) {
          break;
        }
        _messages[messageIndex] = _copyMessageWithParts(message, nextParts);
        _messagesVersion++;
        _scheduleRealtimeNotification(reason: 'event-message-part-removed');
        break;
      case 'message.removed':
        final sessionId = properties['sessionID'] as String?;
        final messageId = properties['messageID'] as String?;
        if (sessionId == null ||
            messageId == null ||
            _currentSession?.id != sessionId) {
          break;
        }
        _rememberRemovedMessage(sessionId, messageId);
        final removedIndex = _messages.indexWhere(
          (item) => item.id == messageId,
        );
        if (removedIndex == -1) {
          break;
        }
        _messages.removeAt(removedIndex);
        _messagesVersion++;
        _scheduleRealtimeNotification(reason: 'event-message-removed');
        break;
      case 'permission.asked':
      case 'permission.updated':
      case 'permission.v2.asked':
      case 'permission.v2.updated':
        ChatPermissionRequest permission;
        try {
          permission = ChatPermissionRequestModel.fromJson(
            _eventPayloadOrNested(properties, const <String>[
              'permission',
              'request',
              'info',
            ]),
          ).toDomain();
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to parse permission event; falling back to pending list',
            error: error,
            stackTrace: stackTrace,
          );
          _refreshPendingInteractionsForEvent(event.type);
          break;
        }
        if (permission.id.trim().isEmpty ||
            permission.sessionId.trim().isEmpty) {
          _refreshPendingInteractionsForEvent(event.type);
          break;
        }
        final sessionPermissions = List<ChatPermissionRequest>.from(
          _pendingPermissionsBySession[permission.sessionId] ??
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
        _pendingPermissionsBySession[permission.sessionId] = sessionPermissions;
        _threadPermissionsVersion++;
        _notifyListeners();
        break;
      case 'permission.replied':
      case 'permission.v2.replied':
        final replyPayload = _eventPayloadOrNested(properties, const <String>[
          'permission',
          'request',
          'info',
        ]);
        final sessionId =
            _extractEventSessionId(replyPayload) ??
            _extractEventSessionId(properties);
        final requestId =
            replyPayload['requestID'] as String? ??
            replyPayload['id'] as String?;
        if (sessionId == null || requestId == null) {
          break;
        }
        final existing = _pendingPermissionsBySession[sessionId];
        if (existing == null) {
          break;
        }
        final filtered = existing
            .where((item) => item.id != requestId)
            .toList(growable: false);
        if (filtered.isEmpty) {
          _pendingPermissionsBySession.remove(sessionId);
        } else {
          _pendingPermissionsBySession[sessionId] = filtered;
        }
        _threadPermissionsVersion++;
        // Reactive dismiss: when no pending permissions AND no pending
        // questions remain for this session, clear its notifications so
        // stale permission/question alerts do not linger.
        final hasRemainingPermissions =
            _pendingPermissionsBySession[sessionId]?.isNotEmpty ?? false;
        final hasRemainingQuestions =
            _pendingQuestionsBySession[sessionId]?.isNotEmpty ?? false;
        if (!hasRemainingPermissions && !hasRemainingQuestions) {
          unawaited(eventFeedbackDispatcher?.dismissForSession(sessionId));
        }
        // Sync background alert snapshot so the background worker does not
        // re-notify about this already-handled permission request.
        unawaited(
          AndroidBackgroundAlertWorker.removeNotifiedRequestIds(
            serverId: _activeServerId,
            permissionRequestIds: [requestId],
          ),
        );
        _notifyListeners();
        break;
      case 'question.asked':
      case 'question.updated':
      case 'question.v2.asked':
      case 'question.v2.updated':
        ChatQuestionRequest question;
        try {
          question = ChatQuestionRequestModel.fromJson(
            _eventPayloadOrNested(properties, const <String>[
              'question',
              'request',
              'info',
            ]),
          ).toDomain();
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to parse question event; falling back to pending list',
            error: error,
            stackTrace: stackTrace,
          );
          _refreshPendingInteractionsForEvent(event.type);
          break;
        }
        if (question.id.trim().isEmpty || question.sessionId.trim().isEmpty) {
          _refreshPendingInteractionsForEvent(event.type);
          break;
        }
        final sessionQuestions = List<ChatQuestionRequest>.from(
          _pendingQuestionsBySession[question.sessionId] ??
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
        _pendingQuestionsBySession[question.sessionId] = sessionQuestions;
        _questionFirstSeenAtById.putIfAbsent(question.id, DateTime.now);
        _threadPermissionsVersion++;
        _notifyListeners();
        break;
      case 'question.replied':
      case 'question.rejected':
      case 'question.v2.replied':
      case 'question.v2.rejected':
        final replyPayload = _eventPayloadOrNested(properties, const <String>[
          'question',
          'request',
          'info',
        ]);
        final sessionId =
            _extractEventSessionId(replyPayload) ??
            _extractEventSessionId(properties);
        final requestId =
            replyPayload['requestID'] as String? ??
            replyPayload['id'] as String?;
        if (sessionId == null || requestId == null) {
          break;
        }
        final existing = _pendingQuestionsBySession[sessionId];
        if (existing == null) {
          break;
        }
        final filtered = existing
            .where((item) => item.id != requestId)
            .toList(growable: false);
        if (filtered.isEmpty) {
          _pendingQuestionsBySession.remove(sessionId);
        } else {
          _pendingQuestionsBySession[sessionId] = filtered;
        }
        _recentlyResolvedQuestionIds[requestId] = DateTime.now();
        _questionFirstSeenAtById.remove(requestId);
        _threadPermissionsVersion++;
        // Reactive dismiss: when no pending permissions AND no pending
        // questions remain for this session, clear its notifications so
        // stale permission/question alerts do not linger.
        final hasRemainingPermissions =
            _pendingPermissionsBySession[sessionId]?.isNotEmpty ?? false;
        final hasRemainingQuestions =
            _pendingQuestionsBySession[sessionId]?.isNotEmpty ?? false;
        if (!hasRemainingPermissions && !hasRemainingQuestions) {
          unawaited(eventFeedbackDispatcher?.dismissForSession(sessionId));
        }
        // Sync background alert snapshot so the background worker does not
        // re-notify about this already-handled question request.
        unawaited(
          AndroidBackgroundAlertWorker.removeNotifiedRequestIds(
            serverId: _activeServerId,
            questionRequestIds: [requestId],
          ),
        );
        _notifyListeners();
        break;
      case 'session.next.moved':
        _dirtyContextKeys.add(_activeContextKey);
        _scheduleCurrentContextRefresh(
          reason: 'event-session.next.moved',
          refreshSessions: true,
          refreshStatus: true,
          refreshActiveSession: true,
        );
        break;
      case 'session.next.revert.staged':
      case 'session.next.revert.cleared':
      case 'session.next.revert.committed':
        final normalizedSessionId = eventSessionId?.trim();
        final currentSessionId = _currentSession?.id.trim();
        final refreshActiveSession =
            normalizedSessionId == null ||
            normalizedSessionId.isEmpty ||
            (currentSessionId != null &&
                currentSessionId.isNotEmpty &&
                normalizedSessionId == currentSessionId);
        _dirtyContextKeys.add(_activeContextKey);
        _scheduleCurrentContextRefresh(
          reason: 'event-${event.type}',
          refreshSessions: true,
          refreshStatus: true,
          refreshActiveSession: refreshActiveSession,
        );
        break;
      default:
        break;
    }
  }
}
