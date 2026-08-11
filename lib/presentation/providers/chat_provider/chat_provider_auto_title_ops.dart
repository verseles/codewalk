part of '../chat_provider.dart';

extension _ChatProviderAutoTitleOps on ChatProvider {
  _AutoTitleSnapshot? _buildAutoTitleSnapshot(String sessionId) {
    final ordered =
        _messages
            .where((message) => message.sessionId == sessionId)
            .toList(growable: false)
          ..sort((a, b) {
            final byTime = a.time.compareTo(b.time);
            if (byTime != 0) {
              return byTime;
            }
            return a.id.compareTo(b.id);
          });

    final selected = <_AutoTitleCandidateMessage>[];
    var userCount = 0;
    var assistantCount = 0;

    for (final message in ordered) {
      if (message is AssistantMessage && !message.isCompleted) {
        continue;
      }
      final text = _extractAutoTitleText(message);
      if (text.isEmpty) {
        continue;
      }

      if (message.role == MessageRole.user) {
        if (userCount >= 3) {
          continue;
        }
        userCount += 1;
      } else {
        if (assistantCount >= 3) {
          continue;
        }
        assistantCount += 1;
      }

      selected.add(
        _AutoTitleCandidateMessage(
          id: message.id,
          role: message.role,
          text: text,
        ),
      );

      if (userCount >= 3 && assistantCount >= 3) {
        break;
      }
    }

    if (selected.isEmpty) {
      return null;
    }

    final signature = selected
        .map((message) => '${message.role.name}:${message.id}:${message.text}')
        .join('|');
    return _AutoTitleSnapshot(
      messages: selected,
      signature: signature,
      userCount: userCount,
      assistantCount: assistantCount,
    );
  }

  Future<bool> _isAutoTitleEnabledForActiveServer() async {
    final activeServerId = await localDataSource.getActiveServerId();
    if (activeServerId == null || activeServerId.trim().isEmpty) {
      return false;
    }

    final rawProfiles = await localDataSource.getServerProfilesJson();
    if (rawProfiles == null || rawProfiles.trim().isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(rawProfiles);
      if (decoded is! List) {
        return false;
      }

      for (final entry in decoded) {
        if (entry is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(entry);
        final id = map['id'] as String?;
        if (id != activeServerId) {
          continue;
        }
        return map['aiGeneratedTitlesEnabled'] as bool? ?? true;
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to read AI title toggle from server profile',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return false;
  }

  Future<void> _processAutoTitleQueue(String sessionId) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      _autoTitleQueuedSessionIds.remove(sessionId);
      return;
    }
    if (_autoTitleInFlightSessionIds.contains(sessionId)) {
      _autoTitleQueuedSessionIds.add(sessionId);
      return;
    }

    _autoTitleInFlightSessionIds.add(sessionId);
    try {
      var keepProcessing = true;
      while (keepProcessing) {
        if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        _autoTitleQueuedSessionIds.remove(sessionId);
        await _runAutoTitlePass(sessionId);
        keepProcessing = _autoTitleQueuedSessionIds.contains(sessionId);
      }
    } finally {
      _autoTitleQueuedSessionIds.remove(sessionId);
      _autoTitleInFlightSessionIds.remove(sessionId);
    }
  }

  Future<void> _runAutoTitlePass(String sessionId) async {
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final generator = titleGenerator;
    if (generator == null ||
        _autoTitleConsolidatedSessionIds.contains(sessionId)) {
      return;
    }

    final runContextKey = _activeContextKey;
    final runProjectId = projectProvider.currentProjectId;
    final runDirectory = projectProvider.currentDirectory;

    final session = _sessionById(sessionId);
    if (session == null || _currentSession?.id != sessionId) {
      return;
    }

    final parentId = session.parentId?.trim();
    if (parentId != null && parentId.isNotEmpty) {
      return;
    }

    if (!await _isAutoTitleEnabledForActiveServer()) {
      return;
    }
    if (_cellularDataSaverService.shouldSuppressBackgroundWork ||
        _activeContextKey != runContextKey ||
        projectProvider.currentProjectId != runProjectId ||
        projectProvider.currentDirectory != runDirectory ||
        _currentSession?.id != sessionId) {
      return;
    }

    final snapshot = _buildAutoTitleSnapshot(sessionId);
    if (snapshot == null) {
      return;
    }

    final lastSignature = _autoTitleLastSignatureBySessionId[sessionId];
    if (lastSignature == snapshot.signature) {
      if (snapshot.isConsolidated) {
        _autoTitleConsolidatedSessionIds.add(sessionId);
      }
      return;
    }

    if (snapshot.isConsolidated && lastSignature == null) {
      _autoTitleLastSignatureBySessionId[sessionId] = snapshot.signature;
      _autoTitleConsolidatedSessionIds.add(sessionId);
      return;
    }

    _autoTitleLastSignatureBySessionId[sessionId] = snapshot.signature;

    final promptMessages = snapshot.messages
        .map(
          (message) => ChatTitleGeneratorMessage(
            role: message.role == MessageRole.user ? 'user' : 'assistant',
            text: message.text,
          ),
        )
        .toList(growable: false);

    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final generatedTitle = await generator.generateTitle(
      promptMessages,
      maxWords: _resolveAutoTitleMaxWords(),
      directory: runDirectory,
    );
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final normalized = generatedTitle?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }

    final liveSession = _sessionById(sessionId);
    if (liveSession == null ||
        _currentSession?.id != sessionId ||
        _activeContextKey != runContextKey ||
        projectProvider.currentProjectId != runProjectId ||
        projectProvider.currentDirectory != runDirectory) {
      return;
    }

    final currentTitle = liveSession.title?.trim();
    if (currentTitle == normalized) {
      if (snapshot.isConsolidated) {
        _autoTitleConsolidatedSessionIds.add(sessionId);
      }
      return;
    }

    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    final result = await updateChatSession(
      UpdateChatSessionParams(
        projectId: runProjectId,
        sessionId: sessionId,
        input: SessionUpdateInput(title: normalized),
        directory: runDirectory,
      ),
    );

    result.fold(
      (failure) {
        AppLogger.warn(
          'Auto title update failed for session=$sessionId: ${failure.message}',
        );
      },
      (updated) {
        _applySessionLocally(updated);
        _notifyListeners();
        unawaited(_persistSessionCacheBestEffort());
        unawaited(_persistLastSessionSnapshotBestEffort());
      },
    );

    if (snapshot.isConsolidated) {
      _autoTitleConsolidatedSessionIds.add(sessionId);
    }
  }
}
