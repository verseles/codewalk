part of '../chat_provider.dart';

extension ChatProviderHistoryOps on ChatProvider {
  _PendingReplacementBranch? get _visiblePendingReplacementBranch {
    final branch = _pendingReplacementBranch;
    final sessionId = _currentSession?.id;
    if (branch == null || sessionId == null || branch.sessionId != sessionId) {
      return null;
    }
    return branch;
  }

  List<ChatMessage> _applyPendingReplacementBranchToMessages(
    List<ChatMessage> messages, {
    required _PendingReplacementBranch branch,
  }) {
    final next = <ChatMessage>[];
    final rootMessageId = branch.replacementRootMessageId?.trim();
    var droppingRevertedTail = false;
    for (final message in messages) {
      if (message.sessionId != branch.sessionId) {
        next.add(message);
        continue;
      }
      if (!droppingRevertedTail) {
        if (message.id == branch.revertMessageId) {
          droppingRevertedTail = true;
          continue;
        }
        next.add(message);
        continue;
      }
      if (rootMessageId != null &&
          rootMessageId.isNotEmpty &&
          message.id == rootMessageId) {
        droppingRevertedTail = false;
        next.add(message);
      }
    }
    return next;
  }

  void _startPendingReplacementBranch({
    required String sessionId,
    required String revertMessageId,
  }) {
    final normalizedRevertMessageId = revertMessageId.trim();
    if (normalizedRevertMessageId.isEmpty) {
      return;
    }
    final branch = _PendingReplacementBranch(
      sessionId: sessionId,
      revertMessageId: normalizedRevertMessageId,
    );
    _pendingReplacementBranch = branch;
    final nextMessages = _applyPendingReplacementBranchToMessages(
      _messages,
      branch: branch,
    );
    final messagesChanged = nextMessages.length != _messages.length;
    if (messagesChanged) {
      // Reverting a branch legitimately drops messages, so it is authoritative.
      _applyMessages(
        nextMessages,
        origin: MessageUpdateOrigin.localMutation,
        kind: MessageUpdateKind.authoritativeRemoval,
        sessionId: sessionId,
        reason: 'pending-replacement-branch',
      );
      _cacheSessionMessages(sessionId, _messages);
      _prunePendingLocalUserMessageIdsToVisibleUsers();
    }

    final currentSession = _currentSession;
    final revertChanged =
        currentSession?.id == sessionId && currentSession?.revert != null;
    if (revertChanged) {
      final updatedSession = currentSession!.copyWith(revert: null);
      _currentSession = updatedSession;
      _dismissNotificationsForSession(updatedSession.id);
      final sessionIndex = _sessions.indexWhere((item) => item.id == sessionId);
      if (sessionIndex != -1) {
        _sessions[sessionIndex] = updatedSession;
      }
      unawaited(_persistSessionCacheBestEffort());
    }

    if (messagesChanged || revertChanged) {
      _messagesVersion++;
    }
  }

  void _setPendingReplacementBranchRootMessage({
    required String sessionId,
    required String messageId,
  }) {
    final branch = _pendingReplacementBranch;
    final normalizedMessageId = messageId.trim();
    if (branch == null ||
        branch.sessionId != sessionId ||
        normalizedMessageId.isEmpty ||
        branch.replacementRootMessageId == normalizedMessageId) {
      return;
    }
    _pendingReplacementBranch = branch.copyWith(
      replacementRootMessageId: normalizedMessageId,
    );
    _messagesVersion++;
  }

  void _clearPendingReplacementBranch({String? sessionId}) {
    final branch = _pendingReplacementBranch;
    if (branch == null) {
      return;
    }
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId != null &&
        normalizedSessionId.isNotEmpty &&
        branch.sessionId != normalizedSessionId) {
      return;
    }
    _pendingReplacementBranch = null;
    _messagesVersion++;
  }

  List<ChatMessage> _filterMessagesForPendingReplacementBranch(
    List<ChatMessage> messages, {
    required String sessionId,
  }) {
    final branch = _pendingReplacementBranch;
    if (branch == null || branch.sessionId != sessionId) {
      return messages;
    }
    return _applyPendingReplacementBranchToMessages(messages, branch: branch);
  }

  void _queueHistoryComposerSync({
    required String sessionId,
    ChatComposerDraft? draft,
    bool clear = false,
  }) {
    _pendingHistoryComposerSync = _HistoryComposerSync(
      token: ++_historyComposerSyncToken,
      sessionId: sessionId,
      draft: draft,
      clear: clear,
    );
  }

  _HistoryComposerSync? consumePendingHistoryComposerSync({String? sessionId}) {
    final pending = _pendingHistoryComposerSync;
    if (pending == null) {
      return null;
    }
    final expectedSessionId = sessionId?.trim();
    if (expectedSessionId != null &&
        expectedSessionId.isNotEmpty &&
        pending.sessionId != expectedSessionId) {
      return null;
    }
    _pendingHistoryComposerSync = null;
    return pending;
  }

  void _applyCurrentSessionRevert(SessionRevert? revert) {
    final session = _currentSession;
    if (session == null) {
      return;
    }
    final updatedSession = session.copyWith(revert: revert);
    _currentSession = updatedSession;
    _dismissNotificationsForSession(updatedSession.id);
    final sessionIndex = _sessions.indexWhere((item) => item.id == session.id);
    if (sessionIndex != -1) {
      _sessions[sessionIndex] = updatedSession;
    }
    _messagesVersion++;
    unawaited(_persistSessionCacheBestEffort());
  }

  ChatComposerDraft? _buildComposerDraftFromUserMessage(UserMessage message) {
    final textParts = message.parts.whereType<TextPart>().toList(
      growable: false,
    );
    final fileParts = message.parts.whereType<FilePart>().toList(
      growable: false,
    );
    final joinedText = textParts.map((part) => part.text).join('\n').trim();
    final shellMode = joinedText.startsWith('!');
    final normalizedText = shellMode
        ? joinedText.substring(1).trimLeft()
        : joinedText;
    final attachments = shellMode
        ? const <FileInputPart>[]
        : List<FileInputPart>.unmodifiable(
            fileParts.map(
              (part) => FileInputPart(
                mime: part.mime,
                url: part.url,
                filename: part.filename,
                source: part.fileSource == null
                    ? null
                    : FileInputSource(
                        path: part.fileSource!.path,
                        text: FileInputSourceText(
                          value: part.fileSource!.text.value,
                          start: part.fileSource!.text.start,
                          end: part.fileSource!.text.end,
                        ),
                        type: part.fileSource!.type,
                      ),
              ),
            ),
          );
    final draft = ChatComposerDraft(
      text: normalizedText,
      attachments: attachments,
      shellMode: shellMode,
    );
    return draft.hasContent ? draft : null;
  }

  UserMessage? _findUserMessageById(String messageId) {
    for (var index = _messages.length - 1; index >= 0; index -= 1) {
      final message = _messages[index];
      if (message.id == messageId && message is UserMessage) {
        return message;
      }
    }
    return null;
  }

  String? _nextRedoBoundaryMessageId() {
    final session = _currentSession;
    final revertMessageId = session?.revert?.messageId.trim();
    if (session == null || revertMessageId == null || revertMessageId.isEmpty) {
      return null;
    }
    final boundaryIndex = _messages.indexWhere(
      (message) =>
          message.sessionId == session.id && message.id == revertMessageId,
    );
    if (boundaryIndex == -1) {
      return null;
    }
    for (var index = boundaryIndex + 1; index < _messages.length; index += 1) {
      final candidate = _messages[index];
      if (candidate.sessionId != session.id || candidate is! UserMessage) {
        continue;
      }
      if (_isOptimisticLocalUserMessageId(candidate.id)) {
        continue;
      }
      return candidate.id;
    }
    return null;
  }

  String? get latestRevertibleMessageId {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return null;
    }
    final visibleMessages = messages;
    for (var index = visibleMessages.length - 1; index >= 0; index -= 1) {
      final message = visibleMessages[index];
      if (message.sessionId != sessionId || message is! UserMessage) {
        continue;
      }
      if (_isOptimisticLocalUserMessageId(message.id)) {
        continue;
      }
      return message.id;
    }
    return null;
  }

  /// Server-confirmed user message IDs eligible as a diff target, newest first.
  /// Mirrors the visibility rules used by [latestRevertibleMessageId]:
  /// only the active session, only [UserMessage]s, and skipping optimistic
  /// `local_user_*` bubbles whose server echo has not been merged yet.
  List<String> visibleServerConfirmedUserMessageIds({int? limit}) {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <String>[];
    }
    final visibleMessages = messages;
    final result = <String>[];
    for (var index = visibleMessages.length - 1; index >= 0; index -= 1) {
      final message = visibleMessages[index];
      if (message.sessionId != sessionId || message is! UserMessage) {
        continue;
      }
      if (_isOptimisticLocalUserMessageId(message.id)) {
        continue;
      }
      result.add(message.id);
      if (limit != null && result.length >= limit) {
        break;
      }
    }
    return result;
  }

  bool get canUndoCurrentSession => latestRevertibleMessageId != null;

  bool get canRedoCurrentSession => currentSessionRevert != null;

  Future<bool> undoLastTurn() async {
    final messageId = latestRevertibleMessageId;
    if (messageId == null) {
      return false;
    }

    return revertToTurn(messageId);
  }

  Future<bool> revertToTurn(String messageId) async {
    if (_isOptimisticLocalUserMessageId(messageId) || _historyRevertInFlight) {
      return false;
    }

    final session = _currentSession;
    final useCase = revertChatMessage;
    if (session == null || useCase == null) {
      return false;
    }

    _historyRevertInFlight = true;
    try {
      return await _performRevertToTurn(session: session, messageId: messageId);
    } finally {
      _historyRevertInFlight = false;
    }
  }

  Future<bool> _performRevertToTurn({
    required ChatSession session,
    required String messageId,
  }) async {
    final useCase = revertChatMessage!;
    _clearPendingReplacementBranch(sessionId: session.id);

    final revertedMessage = _findUserMessageById(messageId);
    final restoredDraft = revertedMessage == null
        ? null
        : _buildComposerDraftFromUserMessage(revertedMessage);

    final result = await useCase(
      RevertChatMessageParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        messageId: messageId,
        directory: projectProvider.currentDirectory,
      ),
    );

    return result.fold<Future<bool>>(
      (failure) async {
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (_) async {
        _applyCurrentSessionRevert(SessionRevert(messageId: messageId));
        _queueHistoryComposerSync(sessionId: session.id, draft: restoredDraft);
        await refreshActiveSessionView(reason: 'undo-success');
        await loadSessionInsights(session.id, silent: true);
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> redoLastTurn() async {
    final session = _currentSession;
    if (session == null || currentSessionRevert == null) {
      return false;
    }

    _clearPendingReplacementBranch(sessionId: session.id);

    final nextRevertMessageId = _nextRedoBoundaryMessageId();
    if (nextRevertMessageId != null) {
      final useCase = revertChatMessage;
      if (useCase == null) {
        return false;
      }
      final result = await useCase(
        RevertChatMessageParams(
          projectId: projectProvider.currentProjectId,
          sessionId: session.id,
          messageId: nextRevertMessageId,
          directory: projectProvider.currentDirectory,
        ),
      );

      return result.fold(
        (failure) {
          _handleFailure(failure);
          notifyListeners();
          return false;
        },
        (_) async {
          _applyCurrentSessionRevert(
            SessionRevert(messageId: nextRevertMessageId),
          );
          await refreshActiveSessionView(reason: 'redo-success');
          await loadSessionInsights(session.id, silent: true);
          notifyListeners();
          return true;
        },
      );
    }

    final useCase = unrevertChatMessages;
    if (useCase == null) {
      return false;
    }

    final result = await useCase(
      UnrevertChatMessagesParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        directory: projectProvider.currentDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (_) async {
        _applyCurrentSessionRevert(null);
        _queueHistoryComposerSync(sessionId: session.id, clear: true);
        await refreshActiveSessionView(reason: 'redo-success');
        await loadSessionInsights(session.id, silent: true);
        notifyListeners();
        return true;
      },
    );
  }

  Future<ChatSession?> forkSession(
    ChatSession session, {
    String? messageId,
    bool selectForked = true,
    SessionActionTarget? target,
  }) async {
    if (target != null && !target.isValid) return null;
    final isTargetActive = target == null || _isActiveTarget(target);
    final effectiveProjectId = target != null ? _projectIdForTarget(target) : projectProvider.currentProjectId;
    final effectiveDirectory = target != null ? _directoryForTarget(target) : projectProvider.currentDirectory;
    final result = await forkChatSession(
      ForkChatSessionParams(
        projectId: effectiveProjectId,
        sessionId: session.id,
        messageId: messageId,
        directory: effectiveDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _handleFailure(failure);
        return null;
      },
      (forked) async {
        if (target == null || isTargetActive) {
          _applySessionLocally(forked);
          unawaited(_persistSessionCacheBestEffort());
          notifyListeners();
          if (selectForked) {
            await selectSession(forked);
          }
        } else {
          _applySessionForTarget(target!, forked);
          notifyListeners();
          // Never auto-select when forking from inactive context menu.
        }
        return forked;
      },
    );
  }
}
