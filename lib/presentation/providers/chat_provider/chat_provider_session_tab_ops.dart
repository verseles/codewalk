part of '../chat_provider.dart';

class SessionTabReconciler {
  const SessionTabReconciler._();

  static const Duration recentWindow = Duration(hours: 3);

  static SessionTabReconciliationResult reconcile({
    required String serverId,
    required PersistedSessionTabsState persistedState,
    required Iterable<SessionTabCandidate> candidates,
    required int nowMs,
    Set<SessionTabIdentity> pinnedIdentities = const <SessionTabIdentity>{},
    SessionTabIdentity? explicitlyOpened,
    String? bootstrapDirectory,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedBootstrapDirectory = normalizeOptionalFilePath(
      bootstrapDirectory,
    );
    final cutoffMs = nowMs - recentWindow.inMilliseconds;
    final candidateByIdentity = <SessionTabIdentity, SessionTabCandidate>{};
    final candidateOrder = <SessionTabIdentity>[];
    for (final candidate in candidates) {
      final identity = candidate.identity;
      if (!identity.isValid || identity.serverId != normalizedServerId) {
        continue;
      }
      final previous = candidateByIdentity[identity];
      if (previous == null) {
        candidateOrder.add(identity);
        candidateByIdentity[identity] = candidate;
      } else {
        candidateByIdentity[identity] = _mergeCandidates(previous, candidate);
      }
    }

    final closedByIdentity = <SessionTabIdentity, PersistedClosedSessionTab>{};
    final closedOrder = <SessionTabIdentity>[];
    for (final closed in persistedState.closed) {
      final identity = SessionTabIdentity(
        serverId: normalizedServerId,
        directory: closed.directory,
        sessionId: closed.sessionId,
      );
      if (!identity.isValid) continue;
      final candidate = candidateByIdentity[identity];
      if (candidate != null && (!candidate.isRoot || candidate.isArchived)) {
        continue;
      }
      final previous = closedByIdentity[identity];
      if (previous == null) {
        closedOrder.add(identity);
        closedByIdentity[identity] = _normalizedClosed(closed, identity);
      } else if (closed.closedAtMs >= previous.closedAtMs) {
        closedByIdentity[identity] = _normalizedClosed(
          closed,
          identity,
          observedServerUpdatedAtMs: math.max(
            previous.observedServerUpdatedAtMs,
            closed.observedServerUpdatedAtMs,
          ),
        );
      }
    }

    final openByIdentity = <SessionTabIdentity, PersistedSessionTab>{};
    final openOrder = <SessionTabIdentity>[];
    for (final persisted in persistedState.open) {
      final identity = SessionTabIdentity(
        serverId: normalizedServerId,
        directory: persisted.directory,
        sessionId: persisted.sessionId,
      );
      if (!identity.isValid) continue;
      final previous = openByIdentity[identity];
      if (previous == null) {
        openOrder.add(identity);
        openByIdentity[identity] = persisted;
      } else {
        openByIdentity[identity] = _mergePersistedTabs(
          previous,
          persisted,
          identity,
        );
      }
    }

    final tabs = <SessionTabRecord>[];
    final handled = <SessionTabIdentity>{};
    for (final identity in openOrder) {
      final persisted = openByIdentity[identity]!;
      handled.add(identity);
      final candidate = candidateByIdentity[identity];
      final isPinned = pinnedIdentities.contains(identity);
      if (candidate != null && (!candidate.isRoot || candidate.isArchived)) {
        continue;
      }
      if (_isSuppressedByClosedTab(
        identity: identity,
        candidate: candidate,
        closedByIdentity: closedByIdentity,
        explicitlyOpened: explicitlyOpened,
        isPinned: isPinned,
      )) {
        continue;
      }
      final serverUpdatedAtMs = math.max(
        persisted.serverUpdatedAtMs,
        candidate?.serverUpdatedAtMs ?? 0,
      );
      final lastOpenedAtMs = explicitlyOpened == identity
          ? nowMs
          : persisted.lastOpenedAtMs;
      final isSelected = candidate?.isSelected ?? false;
      final isBusy = candidate?.isBusy ?? false;
      if (!isSelected &&
          !isBusy &&
          !isPinned &&
          math.max(lastOpenedAtMs, serverUpdatedAtMs) < cutoffMs) {
        continue;
      }
      tabs.add(
        SessionTabRecord(
          identity: identity,
          projectId: candidate?.projectId ?? persisted.projectId,
          title: _tabTitle(
            candidate?.title,
            persisted.title,
            identity.sessionId,
          ),
          lastOpenedAtMs: lastOpenedAtMs,
          serverUpdatedAtMs: serverUpdatedAtMs,
          status: candidate?.status ?? SessionStatusType.idle,
          pendingQuestionIds: candidate?.pendingQuestionIds ?? const <String>[],
          seenQuestionIds: persisted.seenQuestionIds,
          completionToken: candidate?.completionToken,
          seenCompletionToken: persisted.seenCompletionToken,
          errorToken: candidate?.errorToken,
          seenErrorToken: persisted.seenErrorToken,
          isSelected: isSelected,
          isPinned: isPinned,
        ),
      );
    }

    final candidateIndex = <SessionTabIdentity, int>{
      for (var index = 0; index < candidateOrder.length; index += 1)
        candidateOrder[index]: index,
    };
    final newCandidates =
        candidateOrder
            .where((identity) => !handled.contains(identity))
            .map((identity) => candidateByIdentity[identity]!)
            .where((candidate) {
              if (!candidate.isRoot || candidate.isArchived) return false;
              final isPinned = pinnedIdentities.contains(candidate.identity);
              if (_isSuppressedByClosedTab(
                identity: candidate.identity,
                candidate: candidate,
                closedByIdentity: closedByIdentity,
                explicitlyOpened: explicitlyOpened,
                isPinned: isPinned,
              )) {
                return false;
              }
              return isPinned ||
                  explicitlyOpened == candidate.identity ||
                  candidate.isSelected ||
                  candidate.isBusy ||
                  candidate.serverUpdatedAtMs >= cutoffMs;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final leftRecentAt = explicitlyOpened == left.identity
                ? nowMs
                : left.serverUpdatedAtMs;
            final rightRecentAt = explicitlyOpened == right.identity
                ? nowMs
                : right.serverUpdatedAtMs;
            final recentComparison = leftRecentAt.compareTo(rightRecentAt);
            if (recentComparison != 0) return recentComparison;
            return candidateIndex[left.identity]!.compareTo(
              candidateIndex[right.identity]!,
            );
          });
    for (final candidate in newCandidates) {
      tabs.add(
        SessionTabRecord(
          identity: candidate.identity,
          projectId: candidate.projectId,
          title: _tabTitle(candidate.title, '', candidate.identity.sessionId),
          lastOpenedAtMs: explicitlyOpened == candidate.identity ? nowMs : 0,
          serverUpdatedAtMs: candidate.serverUpdatedAtMs,
          status: candidate.status,
          pendingQuestionIds: candidate.pendingQuestionIds,
          completionToken: candidate.completionToken,
          errorToken: candidate.errorToken,
          isSelected: candidate.isSelected,
          isPinned: pinnedIdentities.contains(candidate.identity),
        ),
      );
    }

    if (normalizedBootstrapDirectory != null &&
        !tabs.any(
          (tab) => tab.identity.directory == normalizedBootstrapDirectory,
        )) {
      final fallback = _mostRecentBootstrapTab(
        directory: normalizedBootstrapDirectory,
        openOrder: openOrder,
        openByIdentity: openByIdentity,
        candidateOrder: candidateOrder,
        candidateByIdentity: candidateByIdentity,
        closedByIdentity: closedByIdentity,
        explicitlyOpened: explicitlyOpened,
        pinnedIdentities: pinnedIdentities,
        nowMs: nowMs,
      );
      if (fallback != null) {
        tabs.add(fallback);
      }
    }

    final partitionedTabs = <SessionTabRecord>[
      ...tabs.where((tab) => tab.isPinned),
      ...tabs.where((tab) => !tab.isPinned),
    ];
    final retainedClosed = <PersistedClosedSessionTab>[];
    for (final identity in closedOrder) {
      final closed = closedByIdentity[identity];
      if (closed == null) continue;
      retainedClosed.add(closed);
    }

    return SessionTabReconciliationResult(
      tabs: List<SessionTabRecord>.unmodifiable(partitionedTabs),
      persistedState: PersistedSessionTabsState(
        open: partitionedTabs
            .map((tab) => tab.toPersisted())
            .toList(growable: false),
        closed: List<PersistedClosedSessionTab>.unmodifiable(retainedClosed),
      ),
    );
  }

  static PersistedSessionTabsState close({
    required PersistedSessionTabsState state,
    required SessionTabIdentity identity,
    required int nowMs,
  }) {
    if (!identity.isValid) return state;
    var observedServerUpdatedAtMs = 0;
    String? projectId;
    final open = <PersistedSessionTab>[];
    for (final tab in state.open) {
      if (_matchesPersisted(tab, identity)) {
        observedServerUpdatedAtMs = math.max(
          observedServerUpdatedAtMs,
          tab.serverUpdatedAtMs,
        );
        projectId ??= tab.projectId;
      } else {
        open.add(tab);
      }
    }
    final closed =
        state.closed
            .where((tab) => !_matchesClosed(tab, identity))
            .toList(growable: true)
          ..add(
            PersistedClosedSessionTab(
              directory: identity.directory,
              projectId: projectId,
              sessionId: identity.sessionId,
              closedAtMs: nowMs,
              observedServerUpdatedAtMs: observedServerUpdatedAtMs,
            ),
          );
    return PersistedSessionTabsState(open: open, closed: closed);
  }

  static PersistedSessionTabsState removeAuthoritatively({
    required PersistedSessionTabsState state,
    required SessionTabIdentity identity,
  }) {
    return PersistedSessionTabsState(
      open: state.open
          .where((tab) => !_matchesPersisted(tab, identity))
          .toList(growable: false),
      closed: state.closed
          .where((tab) => !_matchesClosed(tab, identity))
          .toList(growable: false),
    );
  }

  static bool _isSuppressedByClosedTab({
    required SessionTabIdentity identity,
    required SessionTabCandidate? candidate,
    required Map<SessionTabIdentity, PersistedClosedSessionTab>
    closedByIdentity,
    required SessionTabIdentity? explicitlyOpened,
    required bool isPinned,
  }) {
    final closed = closedByIdentity[identity];
    if (closed == null) return false;
    final shouldReopen =
        isPinned ||
        explicitlyOpened == identity ||
        (candidate != null &&
            candidate.serverUpdatedAtMs > closed.observedServerUpdatedAtMs);
    if (shouldReopen) {
      closedByIdentity.remove(identity);
      return false;
    }
    return true;
  }

  static SessionTabRecord? _mostRecentBootstrapTab({
    required String directory,
    required List<SessionTabIdentity> openOrder,
    required Map<SessionTabIdentity, PersistedSessionTab> openByIdentity,
    required List<SessionTabIdentity> candidateOrder,
    required Map<SessionTabIdentity, SessionTabCandidate> candidateByIdentity,
    required Map<SessionTabIdentity, PersistedClosedSessionTab>
    closedByIdentity,
    required SessionTabIdentity? explicitlyOpened,
    required Set<SessionTabIdentity> pinnedIdentities,
    required int nowMs,
  }) {
    final identities = <SessionTabIdentity>[
      ...openOrder,
      ...candidateOrder.where(
        (identity) => !openByIdentity.containsKey(identity),
      ),
    ];
    SessionTabRecord? latest;
    var latestAtMs = -1;
    for (final identity in identities) {
      if (identity.directory != directory) continue;
      final persisted = openByIdentity[identity];
      final candidate = candidateByIdentity[identity];
      final isPinned = pinnedIdentities.contains(identity);
      if (candidate != null && (!candidate.isRoot || candidate.isArchived)) {
        continue;
      }
      if (_isSuppressedByClosedTab(
        identity: identity,
        candidate: candidate,
        closedByIdentity: closedByIdentity,
        explicitlyOpened: explicitlyOpened,
        isPinned: isPinned,
      )) {
        continue;
      }
      final serverUpdatedAtMs = math.max(
        persisted?.serverUpdatedAtMs ?? 0,
        candidate?.serverUpdatedAtMs ?? 0,
      );
      final lastOpenedAtMs = explicitlyOpened == identity
          ? nowMs
          : persisted?.lastOpenedAtMs ?? 0;
      final recentAtMs = math.max(lastOpenedAtMs, serverUpdatedAtMs);
      if (latest != null && recentAtMs <= latestAtMs) continue;
      latestAtMs = recentAtMs;
      latest = SessionTabRecord(
        identity: identity,
        projectId: candidate?.projectId ?? persisted?.projectId,
        title: _tabTitle(
          candidate?.title,
          persisted?.title ?? '',
          identity.sessionId,
        ),
        lastOpenedAtMs: lastOpenedAtMs,
        serverUpdatedAtMs: serverUpdatedAtMs,
        status: candidate?.status ?? SessionStatusType.idle,
        pendingQuestionIds: candidate?.pendingQuestionIds ?? const <String>[],
        seenQuestionIds: persisted?.seenQuestionIds ?? const <String>[],
        completionToken: candidate?.completionToken,
        seenCompletionToken: persisted?.seenCompletionToken,
        errorToken: candidate?.errorToken,
        seenErrorToken: persisted?.seenErrorToken,
        isSelected: candidate?.isSelected ?? false,
        isPinned: isPinned,
      );
    }
    return latest;
  }

  static SessionTabCandidate _mergeCandidates(
    SessionTabCandidate previous,
    SessionTabCandidate next,
  ) {
    final latest = next.serverUpdatedAtMs >= previous.serverUpdatedAtMs
        ? next
        : previous;
    final status = next.isBusy
        ? next.status
        : previous.isBusy
        ? previous.status
        : latest.status;
    return SessionTabCandidate(
      identity: previous.identity,
      projectId: latest.projectId ?? previous.projectId ?? next.projectId,
      title: latest.title.trim().isNotEmpty
          ? latest.title
          : previous.title.trim().isNotEmpty
          ? previous.title
          : next.title,
      serverUpdatedAtMs: math.max(
        previous.serverUpdatedAtMs,
        next.serverUpdatedAtMs,
      ),
      status: status,
      isSelected: previous.isSelected || next.isSelected,
      isArchived: latest.isArchived,
      isRoot: latest.isRoot,
      pendingQuestionIds: <String>{
        ...previous.pendingQuestionIds,
        ...next.pendingQuestionIds,
      },
      completionToken:
          latest.completionToken ??
          previous.completionToken ??
          next.completionToken,
      errorToken: latest.errorToken ?? previous.errorToken ?? next.errorToken,
    );
  }

  static PersistedSessionTab _mergePersistedTabs(
    PersistedSessionTab previous,
    PersistedSessionTab next,
    SessionTabIdentity identity,
  ) {
    final previousRecentAt = math.max(
      previous.lastOpenedAtMs,
      previous.serverUpdatedAtMs,
    );
    final nextRecentAt = math.max(next.lastOpenedAtMs, next.serverUpdatedAtMs);
    final latest = nextRecentAt >= previousRecentAt ? next : previous;
    return PersistedSessionTab(
      directory: identity.directory,
      projectId: latest.projectId ?? previous.projectId ?? next.projectId,
      sessionId: identity.sessionId,
      title: _tabTitle(latest.title, previous.title, identity.sessionId),
      lastOpenedAtMs: math.max(previous.lastOpenedAtMs, next.lastOpenedAtMs),
      serverUpdatedAtMs: math.max(
        previous.serverUpdatedAtMs,
        next.serverUpdatedAtMs,
      ),
      seenQuestionIds: <String>{
        ...previous.seenQuestionIds,
        ...next.seenQuestionIds,
      }.toList(growable: false),
      seenCompletionToken:
          latest.seenCompletionToken ?? previous.seenCompletionToken,
      seenErrorToken: latest.seenErrorToken ?? previous.seenErrorToken,
    );
  }

  static PersistedClosedSessionTab _normalizedClosed(
    PersistedClosedSessionTab closed,
    SessionTabIdentity identity, {
    int? observedServerUpdatedAtMs,
  }) {
    return PersistedClosedSessionTab(
      directory: identity.directory,
      projectId: closed.projectId,
      sessionId: identity.sessionId,
      closedAtMs: closed.closedAtMs,
      observedServerUpdatedAtMs:
          observedServerUpdatedAtMs ?? closed.observedServerUpdatedAtMs,
    );
  }

  static bool _matchesPersisted(
    PersistedSessionTab tab,
    SessionTabIdentity identity,
  ) {
    return normalizeFilePath(tab.directory) == identity.directory &&
        tab.sessionId.trim() == identity.sessionId;
  }

  static bool _matchesClosed(
    PersistedClosedSessionTab tab,
    SessionTabIdentity identity,
  ) {
    return normalizeFilePath(tab.directory) == identity.directory &&
        tab.sessionId.trim() == identity.sessionId;
  }

  static String _tabTitle(
    String? candidateTitle,
    String persistedTitle,
    String sessionId,
  ) {
    final normalizedCandidate = candidateTitle?.trim();
    if (normalizedCandidate != null && normalizedCandidate.isNotEmpty) {
      return normalizedCandidate;
    }
    final normalizedPersisted = persistedTitle.trim();
    if (normalizedPersisted.isNotEmpty) return normalizedPersisted;
    return sessionId;
  }
}

extension ChatProviderSessionTabOps on ChatProvider {
  bool get _isSessionTabRouteVisible =>
      _isForegroundActive && _isChatRouteActive;

  String? _activePinnedSessionScopeId() {
    return normalizeOptionalFilePath(
          _scopeIdFromContextKey(_activeContextKey),
        ) ??
        normalizeOptionalFilePath(_resolveContextScopeId());
  }

  void _hydrateActivePinnedSessionIds({
    required String serverId,
    required String scopeId,
  }) {
    if (_loadedPinnedSessionContextKey == _activeContextKey) return;
    final normalizedScopeId = normalizeOptionalFilePath(scopeId);
    _pinnedSessionIds = Set<String>.from(
      normalizedScopeId == null
          ? const <String>{}
          : _pinnedSessionIdsByServerScope[serverId]?[normalizedScopeId] ??
                const <String>{},
    );
    _loadedPinnedSessionContextKey = _activeContextKey;
  }

  void _recordPinnedSessionMutation() {
    _pinnedSessionMutationRevisionByContext[_activeContextKey] =
        (_pinnedSessionMutationRevisionByContext[_activeContextKey] ?? 0) + 1;
  }

  Map<String, Set<String>> _effectivePinnedSessionScopes(String serverId) {
    final result = <String, Set<String>>{
      for (final entry
          in _pinnedSessionIdsByServerScope[serverId]?.entries ??
              const Iterable<MapEntry<String, Set<String>>>.empty())
        entry.key: Set<String>.from(entry.value),
    };
    for (final entry in _contextSnapshots.entries) {
      if (entry.key == _activeContextKey ||
          _serverIdFromContextKey(entry.key) != serverId) {
        continue;
      }
      final scopeId = normalizeOptionalFilePath(
        _scopeIdFromContextKey(entry.key),
      );
      if (scopeId != null) {
        result[scopeId] = Set<String>.from(entry.value.pinnedSessionIds);
      }
    }
    if (_serverIdFromContextKey(_activeContextKey) == serverId &&
        _loadedPinnedSessionContextKey == _activeContextKey) {
      final scopeId = _activePinnedSessionScopeId();
      if (scopeId != null) {
        result[scopeId] = Set<String>.from(_pinnedSessionIds);
      }
    }
    return result;
  }

  Map<SessionTabIdentity, Set<String>> _pinnedSessionTabScopes(
    String serverId,
    List<SessionTabCandidate> candidates,
  ) {
    final result = <SessionTabIdentity, Set<String>>{};
    final effectiveScopes = _effectivePinnedSessionScopes(serverId);
    for (final scopeEntry in effectiveScopes.entries) {
      final scopeId = scopeEntry.key;
      for (final sessionId in scopeEntry.value) {
        SessionTabIdentity? identity;
        if (_serverIdFromContextKey(_activeContextKey) == serverId &&
            _activePinnedSessionScopeId() == scopeId) {
          final session = _sessions
              .where((candidate) => candidate.id == sessionId)
              .firstOrNull;
          if (session != null) {
            identity = _sessionTabIdentityForSession(
              session,
              contextKey: _activeContextKey,
            );
          }
        }
        if (identity == null) {
          for (final entry in _contextSnapshots.entries) {
            if (entry.key == _activeContextKey ||
                _serverIdFromContextKey(entry.key) != serverId ||
                normalizeOptionalFilePath(_scopeIdFromContextKey(entry.key)) !=
                    scopeId) {
              continue;
            }
            final session = entry.value.sessions
                .where((candidate) => candidate.id == sessionId)
                .firstOrNull;
            if (session != null) {
              identity = _sessionTabIdentityForSession(
                session,
                contextKey: entry.key,
              );
              break;
            }
          }
        }
        identity ??= _resolvePinnedTabIdentityFromKnownTabs(
          serverId: serverId,
          scopeId: scopeId,
          sessionId: sessionId,
          candidates: candidates,
        );
        if (identity != null && identity.isValid) {
          result.putIfAbsent(identity, () => <String>{}).add(scopeId);
        }
      }
    }
    return result;
  }

  SessionTabIdentity? _resolvePinnedTabIdentityFromKnownTabs({
    required String serverId,
    required String scopeId,
    required String sessionId,
    required List<SessionTabCandidate> candidates,
  }) {
    final candidateMatches = candidates
        .where((candidate) => candidate.identity.sessionId == sessionId)
        .map((candidate) => candidate.identity)
        .toSet();
    final exactCandidate = candidateMatches
        .where((identity) => identity.directory == scopeId)
        .firstOrNull;
    if (exactCandidate != null) return exactCandidate;
    if (candidateMatches.length == 1) return candidateMatches.single;

    final persistedMatches = _sessionTabsPersistedState.open
        .where((tab) => tab.sessionId.trim() == sessionId)
        .map(
          (tab) => SessionTabIdentity(
            serverId: serverId,
            directory: tab.directory,
            sessionId: sessionId,
          ),
        )
        .where((identity) => identity.isValid)
        .toSet();
    final exactPersisted = persistedMatches
        .where((identity) => identity.directory == scopeId)
        .firstOrNull;
    if (exactPersisted != null) return exactPersisted;
    if (persistedMatches.length == 1) return persistedMatches.single;
    return null;
  }

  void _writeThroughPinnedSessionScope({
    required String serverId,
    required String scopeId,
    required Iterable<String> ids,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedScopeId = normalizeOptionalFilePath(scopeId);
    if (normalizedServerId.isEmpty || normalizedScopeId == null) return;
    _pinnedSessionIdsByServerScope.putIfAbsent(
      normalizedServerId,
      () => <String, Set<String>>{},
    )[normalizedScopeId] = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  bool _setActiveSessionPin({
    required String serverId,
    required String scopeId,
    required String sessionId,
    required bool pinned,
  }) {
    _hydrateActivePinnedSessionIds(serverId: serverId, scopeId: scopeId);
    final changed = pinned
        ? _pinnedSessionIds.add(sessionId)
        : _pinnedSessionIds.remove(sessionId);
    if (changed) {
      _invalidateSessionTabReconcileCache();
      _recordPinnedSessionMutation();
      _loadedPinnedSessionContextKey = _activeContextKey;
      _writeThroughPinnedSessionScope(
        serverId: serverId,
        scopeId: scopeId,
        ids: _pinnedSessionIds,
      );
    }
    return changed;
  }

  bool _setSessionTabPin(
    SessionTabIdentity identity, {
    required bool pinned,
    String? pinScopeId,
    Iterable<String>? pinScopeIds,
    bool persist = false,
  }) {
    if (!identity.isValid) return false;
    final explicitScopes = pinScopeIds
        ?.map(normalizeFilePath)
        .where((scopeId) => scopeId.isNotEmpty)
        .toSet();
    if (!pinned && explicitScopes != null && explicitScopes.isNotEmpty) {
      var changed = false;
      for (final scopeId in explicitScopes) {
        changed =
            _setSessionTabPin(
              identity,
              pinned: false,
              pinScopeId: scopeId,
              persist: persist,
            ) ||
            changed;
      }
      return changed;
    }
    var targetScopeId = normalizeOptionalFilePath(pinScopeId);
    final activeScopeId = _activePinnedSessionScopeId();
    final activeSessionMatches =
        identity.serverId == _activeServerId &&
        _sessions.any(
          (session) =>
              _sessionTabIdentityForSession(
                session,
                contextKey: _activeContextKey,
              ) ==
              identity,
        );
    if (targetScopeId == null && activeSessionMatches) {
      targetScopeId = activeScopeId;
    }
    MapEntry<String, _ChatContextSnapshot>? snapshotEntry;
    if (targetScopeId == null) {
      snapshotEntry = _contextSnapshots.entries
          .where(
            (entry) =>
                entry.key != _activeContextKey &&
                _serverIdFromContextKey(entry.key) == identity.serverId &&
                entry.value.sessions.any(
                  (session) =>
                      _sessionTabIdentityForSession(
                        session,
                        contextKey: entry.key,
                      ) ==
                      identity,
                ),
          )
          .firstOrNull;
      targetScopeId = normalizeOptionalFilePath(
        snapshotEntry == null
            ? null
            : _scopeIdFromContextKey(snapshotEntry.key),
      );
    }
    if (targetScopeId == null) {
      final matchingScopes = _effectivePinnedSessionScopes(identity.serverId)
          .entries
          .where((entry) => entry.value.contains(identity.sessionId))
          .map((entry) => entry.key)
          .toList(growable: false);
      if (matchingScopes.contains(identity.directory)) {
        targetScopeId = identity.directory;
      } else if (matchingScopes.length == 1) {
        targetScopeId = matchingScopes.single;
      }
    }
    if (targetScopeId == null) return false;

    Set<String> ids;
    if (identity.serverId == _activeServerId &&
        targetScopeId == activeScopeId) {
      _hydrateActivePinnedSessionIds(
        serverId: identity.serverId,
        scopeId: targetScopeId,
      );
      ids = _pinnedSessionIds;
    } else {
      snapshotEntry ??= _contextSnapshots.entries
          .where(
            (entry) =>
                entry.key != _activeContextKey &&
                _serverIdFromContextKey(entry.key) == identity.serverId &&
                normalizeOptionalFilePath(_scopeIdFromContextKey(entry.key)) ==
                    targetScopeId,
          )
          .firstOrNull;
      ids =
          snapshotEntry?.value.pinnedSessionIds ??
          _pinnedSessionIdsByServerScope
              .putIfAbsent(identity.serverId, () => <String, Set<String>>{})
              .putIfAbsent(targetScopeId, () => <String>{});
    }
    final changed = pinned
        ? ids.add(identity.sessionId)
        : ids.remove(identity.sessionId);
    if (!changed) return false;
    _invalidateSessionTabReconcileCache();
    if (identical(ids, _pinnedSessionIds)) {
      _recordPinnedSessionMutation();
    }
    _writeThroughPinnedSessionScope(
      serverId: identity.serverId,
      scopeId: targetScopeId,
      ids: ids,
    );
    if (persist) {
      unawaited(
        _persistPinnedSessionScope(
          serverId: identity.serverId,
          scopeId: targetScopeId,
          ids: ids,
        ),
      );
    }
    return true;
  }

  Future<void> _persistPinnedSessionScope({
    required String serverId,
    required String scopeId,
    required Iterable<String> ids,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedScopeId = normalizeOptionalFilePath(scopeId);
    if (normalizedServerId.isEmpty || normalizedScopeId == null) {
      return Future<void>.value();
    }
    final payload = json.encode(
      ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toList(),
    );
    final queueKey = '$normalizedServerId\u0000$normalizedScopeId';
    final previous =
        _pinnedSessionWriteQueueByScope[queueKey] ?? Future<void>.value();
    Future<void> persist() => localDataSource.savePinnedSessionsJson(
      payload,
      serverId: normalizedServerId,
      scopeId: normalizedScopeId,
    );
    final operation = previous.then(
      (_) => persist(),
      onError: (Object _, StackTrace _) => persist(),
    );
    final next = operation.catchError((error, stackTrace) {
      AppLogger.error(
        'Failed to persist pinned sessions for server=$normalizedServerId',
        error: error,
        stackTrace: stackTrace,
      );
    });
    _pinnedSessionWriteQueueByScope[queueKey] = next;
    return next.whenComplete(() {
      if (identical(_pinnedSessionWriteQueueByScope[queueKey], next)) {
        _pinnedSessionWriteQueueByScope.remove(queueKey);
      }
    });
  }

  ChatSession? sessionForSessionTab(SessionTabIdentity identity) {
    if (!identity.isValid || identity.serverId != _activeServerId) {
      return null;
    }

    ChatSession? findIn(Iterable<ChatSession> sessions, {String? contextKey}) {
      for (final session in sessions) {
        if (session.id != identity.sessionId) continue;
        final resolvedIdentity = _sessionTabIdentityForSession(
          session,
          contextKey: contextKey ?? _activeContextKey,
        );
        if (resolvedIdentity == identity) return session;
        final directory = normalizeOptionalFilePath(_sessionDirectory(session));
        if (directory == null) return session;
      }
      return null;
    }

    final active = findIn(_sessions);
    if (active != null) return active;

    for (final entry in _contextSnapshots.entries) {
      if (_serverIdFromContextKey(entry.key) != identity.serverId ||
          normalizeOptionalFilePath(_scopeIdFromContextKey(entry.key)) !=
              identity.directory) {
        continue;
      }
      final cached = findIn(entry.value.sessions, contextKey: entry.key);
      if (cached != null) return cached;
    }
    return null;
  }

  Future<bool?> waitForSessionTabAuthority(
    SessionTabIdentity identity, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!identity.isValid) return false;

    bool? resolve() {
      if (_activeServerId != identity.serverId) return false;
      if (!_hasLoadedSessionsAuthoritatively) return null;
      final target = _sessions.where((session) {
        if (session.id != identity.sessionId) return false;
        final resolvedIdentity = _sessionTabIdentityForSession(
          session,
          contextKey: _activeContextKey,
        );
        return resolvedIdentity == identity ||
            normalizeOptionalFilePath(_sessionDirectory(session)) == null;
      }).firstOrNull;
      return target != null;
    }

    final initial = resolve();
    if (initial != null) return initial;

    final completer = Completer<bool?>();
    void onChanged() {
      final result = resolve();
      if (result != null && !completer.isCompleted) {
        completer.complete(result);
      }
    }

    addListener(onChanged);
    _sessionTabAuthorityWaiters.add(completer);
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      _sessionTabAuthorityWaiters.remove(completer);
      if (!_sessionTabsDisposed) {
        removeListener(onChanged);
      }
    }
  }

  Future<void> _ensureSessionTabsLoaded({String? serverId}) async {
    final targetServerId = (serverId ?? _activeServerId).trim();
    if (targetServerId.isEmpty) return;
    if (_sessionTabsLoadedServerId == targetServerId) {
      _reconcileSessionTabs();
      return;
    }
    final generation = ++_sessionTabsGeneration;
    String? raw;
    SessionTabIconOverridesState? iconOverridesState;
    var scopedPins = const <String, Set<String>>{};
    var scopedPinEnumerationSucceeded = false;
    try {
      scopedPins = await localDataSource.getPinnedSessionsByScope(
        serverId: targetServerId,
      );
      scopedPinEnumerationSucceeded = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to enumerate pinned session scopes for server=$targetServerId',
        error: error,
        stackTrace: stackTrace,
      );
      final activeScopeId = _activePinnedSessionScopeId();
      if (activeScopeId != null) {
        try {
          final activePinsRaw = await localDataSource.getPinnedSessionsJson(
            serverId: targetServerId,
            scopeId: activeScopeId,
          );
          scopedPins = <String, Set<String>>{
            activeScopeId: _decodeStoredModelKeys(activePinsRaw).toSet(),
          };
          scopedPinEnumerationSucceeded = true;
        } catch (fallbackError, fallbackStackTrace) {
          AppLogger.warn(
            'Failed to load active pinned sessions for server=$targetServerId',
            error: fallbackError,
            stackTrace: fallbackStackTrace,
          );
        }
      }
    }
    try {
      raw = await _enqueueSessionTabsPersistenceOperation<String?>(
        serverId: targetServerId,
        operation: () =>
            localDataSource.getSessionTabsStateJson(serverId: targetServerId),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load session tabs for server=$targetServerId',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_sessionTabsDisposed &&
          generation == _sessionTabsGeneration &&
          targetServerId == _activeServerId) {
        final hadVisibleTabs = _sessionTabs.isNotEmpty;
        _invalidateSessionTabReconcileCache();
        _sessionTabs = const <SessionTabRecord>[];
        _sessionTabsPersistedState = const PersistedSessionTabsState();
        _sessionTabsLoadedServerId = null;
        if (hadVisibleTabs) _notifyListeners();
      }
      return;
    }
    try {
      iconOverridesState = await _sessionTabIconOverrideStore.load(
        targetServerId,
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to load session tab icon overrides for server=$targetServerId',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_sessionTabsDisposed ||
        generation != _sessionTabsGeneration ||
        targetServerId != _activeServerId) {
      return;
    }
    _sessionTabsLoadedServerId = targetServerId;
    final normalizedScopedPins = <String, Set<String>>{};
    for (final entry in scopedPins.entries) {
      final scopeId = normalizeOptionalFilePath(entry.key);
      if (scopeId != null) {
        normalizedScopedPins
            .putIfAbsent(scopeId, () => <String>{})
            .addAll(entry.value);
      }
    }
    final liveScopedPins = _pinnedSessionIdsByServerScope[targetServerId];
    if (liveScopedPins != null) {
      for (final entry in liveScopedPins.entries) {
        normalizedScopedPins[entry.key] = Set<String>.from(entry.value);
      }
    }
    if (scopedPinEnumerationSucceeded || liveScopedPins != null) {
      _pinnedSessionIdsByServerScope[targetServerId] = normalizedScopedPins;
    }
    final activeScopeId = _activePinnedSessionScopeId();
    final canHydrateActiveScope =
        scopedPinEnumerationSucceeded ||
        (activeScopeId != null &&
            liveScopedPins?.containsKey(activeScopeId) == true);
    if (canHydrateActiveScope &&
        _serverIdFromContextKey(_activeContextKey) == targetServerId &&
        activeScopeId != null) {
      _hydrateActivePinnedSessionIds(
        serverId: targetServerId,
        scopeId: activeScopeId,
      );
    }
    if (iconOverridesState != null) {
      _applySessionTabIconOverrideState(targetServerId, iconOverridesState);
    }
    _invalidateSessionTabReconcileCache();
    _sessionTabsPersistedState = PersistedSessionTabsState.decode(raw);
    _reconcileSessionTabs();
  }

  void _invalidateSessionTabReconcileCache() {
    _sessionTabsPersistedStateEncoded = null;
    _lastSessionTabReconcileCandidates = null;
    _sessionTabReconcilePresentationDirty = true;
  }

  bool _isCurrentSessionTabViewed() {
    final currentSession = _currentSession;
    if (currentSession == null) return true;
    final identity = _sessionTabIdentityForSession(
      currentSession,
      contextKey: _activeContextKey,
    );
    if (identity == null) return true;
    final tab = _sessionTabs
        .where((candidate) => candidate.identity == identity)
        .firstOrNull;
    if (tab == null) return false;
    return tab.pendingQuestionIds.every(tab.seenQuestionIds.contains) &&
        tab.seenCompletionToken == tab.completionToken &&
        tab.seenErrorToken == tab.errorToken;
  }

  void _reconcileSessionTabs({
    SessionTabIdentity? explicitlyOpened,
    bool markCurrentViewed = false,
    bool forcePersistence = false,
    bool notify = true,
  }) {
    final serverId = _activeServerId.trim();
    if (serverId.isEmpty || _sessionTabsLoadedServerId != serverId) return;
    final candidates = _collectSessionTabCandidates(serverId).toList();
    final shouldMarkCurrentViewed =
        markCurrentViewed && !_isCurrentSessionTabViewed();
    if (explicitlyOpened == null &&
        !forcePersistence &&
        !_sessionTabReconcilePresentationDirty &&
        !shouldMarkCurrentViewed &&
        _lastSessionTabReconcileCandidates != null &&
        listEquals(_lastSessionTabReconcileCandidates, candidates)) {
      return;
    }
    final previousStateJson =
        _sessionTabsPersistedStateEncoded ??
        _sessionTabsPersistedState.encode();
    final pinnedScopes = _pinnedSessionTabScopes(serverId, candidates);
    final result = SessionTabReconciler.reconcile(
      serverId: serverId,
      persistedState: _sessionTabsPersistedState,
      candidates: candidates,
      nowMs: _sessionTabsNow().millisecondsSinceEpoch,
      pinnedIdentities: pinnedScopes.keys.toSet(),
      explicitlyOpened: explicitlyOpened,
      bootstrapDirectory: _sessionTabBootstrapDirectory,
    );
    final activePinScopeId = _activePinnedSessionScopeId();
    var nextTabs = result.tabs
        .map((tab) {
          final iconPresetId =
              _sessionTabIconOverridesByServer[serverId]?[tab.identity]
                  ?.presetId;
          if (!tab.isPinned) {
            return tab.copyWith(iconPresetId: iconPresetId);
          }
          final scopes = pinnedScopes[tab.identity] ?? const <String>{};
          final primaryScope =
              activePinScopeId != null && scopes.contains(activePinScopeId)
              ? activePinScopeId
              : scopes.contains(tab.identity.directory)
              ? tab.identity.directory
              : scopes.firstOrNull;
          return tab.copyWith(
            pinScopeId: primaryScope,
            pinScopeIds: scopes,
            iconPresetId: iconPresetId,
          );
        })
        .toList(growable: false);
    var nextPersistedState = result.persistedState;
    if (markCurrentViewed) {
      final viewed = _markCurrentSessionTabViewedIn(nextTabs);
      nextTabs = viewed.tabs;
      nextPersistedState = PersistedSessionTabsState(
        open: nextTabs.map((tab) => tab.toPersisted()).toList(growable: false),
        closed: result.persistedState.closed,
      );
    }
    final runtimeChanged = !listEquals(_sessionTabs, nextTabs);
    final nextStateJson = nextPersistedState.encode();
    final persistedChanged = previousStateJson != nextStateJson;
    _sessionTabs = List<SessionTabRecord>.unmodifiable(nextTabs);
    _sessionTabsPersistedState = nextPersistedState;
    _sessionTabsPersistedStateEncoded = nextStateJson;
    _lastSessionTabReconcileCandidates = List<SessionTabCandidate>.unmodifiable(
      candidates,
    );
    _sessionTabReconcilePresentationDirty = false;
    _pruneSessionTabEventState(serverId);
    if (persistedChanged || forcePersistence) {
      _scheduleSessionTabsPersistence(
        payload: nextStateJson,
        force: forcePersistence,
      );
    }
    if (runtimeChanged && notify) _notifyListeners();
  }

  void _markAuthoritativeSessionTabBootstrapOpened(String? directory) {
    final normalizedDirectory = normalizeOptionalFilePath(directory);
    if (normalizedDirectory == null ||
        _sessionTabBootstrapDirectory != normalizedDirectory) {
      return;
    }
    final targetTabs = _sessionTabs
        .where((tab) => tab.identity.directory == normalizedDirectory)
        .toList(growable: false);
    if (targetTabs.length != 1) return;
    final tab = targetTabs.single;
    final cutoffMs =
        _sessionTabsNow().millisecondsSinceEpoch -
        SessionTabReconciler.recentWindow.inMilliseconds;
    if (math.max(tab.lastOpenedAtMs, tab.serverUpdatedAtMs) >= cutoffMs) {
      return;
    }
    _reconcileSessionTabs(
      explicitlyOpened: tab.identity,
      markCurrentViewed: _isSessionTabRouteVisible,
    );
  }

  ({List<SessionTabRecord> tabs, bool changed}) _markCurrentSessionTabViewedIn(
    List<SessionTabRecord> tabs,
  ) {
    final currentSession = _currentSession;
    if (currentSession == null) return (tabs: tabs, changed: false);
    final identity = _sessionTabIdentityForSession(
      currentSession,
      contextKey: _activeContextKey,
    );
    if (identity == null) return (tabs: tabs, changed: false);
    var changed = false;
    final next = tabs
        .map((tab) {
          if (tab.identity != identity) return tab;
          final viewedQuestions = _normalizedSessionTabIds(<String>{
            ...tab.seenQuestionIds,
            ...tab.pendingQuestionIds,
          });
          final updated = tab.copyWith(
            seenQuestionIds: viewedQuestions,
            seenCompletionToken: tab.completionToken,
            seenErrorToken: tab.errorToken,
          );
          changed = changed || updated != tab;
          return updated;
        })
        .toList(growable: false);
    return (tabs: changed ? next : tabs, changed: changed);
  }

  void _recordVisibleSessionTab(ChatSession session) {
    if (session.parentId?.trim().isNotEmpty ?? false) return;
    if (session.archived) return;
    final identity = _sessionTabIdentityForSession(
      session,
      contextKey: _activeContextKey,
    );
    if (identity == null) return;
    _reconcileSessionTabs(
      explicitlyOpened: identity,
      markCurrentViewed: _isSessionTabRouteVisible,
    );
  }

  void _markCurrentSessionTabViewed() {
    if (!_isSessionTabRouteVisible) return;
    _reconcileSessionTabs(markCurrentViewed: true);
  }

  Iterable<SessionTabCandidate> _collectSessionTabCandidates(String serverId) {
    final candidates = <SessionTabCandidate>[];
    candidates.addAll(
      _sessionTabCandidatesForContext(
        serverId: serverId,
        contextKey: _activeContextKey,
        sessions: _sessions,
        currentSession: _currentSession,
        statusById: _sessionStatusById,
        pendingQuestionsBySession: _pendingQuestionsBySession,
        unreadCompletionIds: _sessionUnreadCompletionIds,
        unreadCompletionTimestamps: _sessionUnreadCompletionTimestamps,
        errorAttentionIds: _sessionErrorAttentionIds,
      ),
    );
    for (final entry in _contextSnapshots.entries) {
      if (entry.key == _activeContextKey ||
          _serverIdFromContextKey(entry.key) != serverId) {
        continue;
      }
      final snapshot = entry.value;
      candidates.addAll(
        _sessionTabCandidatesForContext(
          serverId: serverId,
          contextKey: entry.key,
          sessions: snapshot.sessions,
          currentSession: snapshot.currentSession,
          statusById: snapshot.sessionStatusById,
          pendingQuestionsBySession: snapshot.pendingQuestionsBySession,
          unreadCompletionIds: snapshot.sessionUnreadCompletionIds,
          unreadCompletionTimestamps:
              snapshot.sessionUnreadCompletionTimestamps,
          errorAttentionIds: snapshot.sessionErrorAttentionIds,
        ),
      );
    }
    final contextIdentities = candidates
        .map((candidate) => candidate.identity)
        .toSet();
    candidates.addAll(
      _sessionTabEventCandidates.values.where(
        (candidate) =>
            candidate.identity.serverId == serverId &&
            !contextIdentities.contains(candidate.identity),
      ),
    );
    return candidates;
  }

  Iterable<SessionTabCandidate> _sessionTabCandidatesForContext({
    required String serverId,
    required String contextKey,
    required List<ChatSession> sessions,
    required ChatSession? currentSession,
    required Map<String, SessionStatusInfo> statusById,
    required Map<String, List<ChatQuestionRequest>> pendingQuestionsBySession,
    required Set<String> unreadCompletionIds,
    required Map<String, DateTime> unreadCompletionTimestamps,
    required Set<String> errorAttentionIds,
  }) sync* {
    final scopeId = _scopeIdFromContextKey(contextKey);
    if (scopeId == null) return;
    final hasCurrentSession = currentSession == null
        ? true
        : sessions.any((session) => session.id == currentSession.id);
    final sourceSessions = List<ChatSession>.from(sessions);
    if (!hasCurrentSession) {
      sourceSessions.add(currentSession);
    }
    for (final session in sourceSessions) {
      final identity = _sessionTabIdentityForSession(
        session,
        contextKey: contextKey,
      );
      if (identity == null || identity.serverId != serverId) continue;
      final completionAt = unreadCompletionTimestamps[session.id];
      final completionToken = unreadCompletionIds.contains(session.id)
          ? _sessionTabCompletionTokens[identity] ??
                'completion:${completionAt?.millisecondsSinceEpoch ?? session.time.millisecondsSinceEpoch}'
          : null;
      final errorToken = errorAttentionIds.contains(session.id)
          ? _sessionTabErrorTokens[identity] ??
                'error:${session.time.millisecondsSinceEpoch}'
          : null;
      yield SessionTabCandidate(
        identity: identity,
        projectId: _sessionTabProjectId(session, contextKey: contextKey),
        title: session.title ?? '',
        serverUpdatedAtMs: session.time.millisecondsSinceEpoch,
        status: statusById[session.id]?.type ?? SessionStatusType.idle,
        isSelected:
            contextKey == _activeContextKey && currentSession?.id == session.id,
        isArchived: session.archived,
        isRoot: session.parentId?.trim().isEmpty ?? true,
        pendingQuestionIds:
            pendingQuestionsBySession[session.id]?.map(
              (request) => request.id,
            ) ??
            const <String>[],
        completionToken: completionToken,
        errorToken: errorToken,
      );
    }
  }

  SessionTabIdentity? _sessionTabIdentityForSession(
    ChatSession session, {
    required String contextKey,
  }) {
    final serverId = _serverIdFromContextKey(contextKey)?.trim();
    final directory =
        normalizeOptionalFilePath(_sessionDirectory(session)) ??
        normalizeOptionalFilePath(_scopeIdFromContextKey(contextKey));
    if (serverId == null || serverId.isEmpty || directory == null) return null;
    final identity = SessionTabIdentity(
      serverId: serverId,
      directory: directory,
      sessionId: session.id,
    );
    return identity.isValid ? identity : null;
  }

  String? _sessionTabProjectId(
    ChatSession session, {
    required String contextKey,
  }) {
    final workspaceId = session.workspaceId.trim();
    if (workspaceId.isNotEmpty && workspaceId != 'default') return workspaceId;
    if (contextKey == _activeContextKey) {
      final projectId = projectProvider.currentProjectId.trim();
      return projectId.isEmpty || projectId == 'default' ? null : projectId;
    }
    return null;
  }

  /// Debounces session-tab persistence so a burst of SSE events coalesces
  /// into a single whole-prefs-file write on desktop (issue #152). Each
  /// reconcile replaces the pending payload (latest-wins); awaited callers
  /// must call [flushSessionTabsPersistence] before waiting on the queue.
  void _scheduleSessionTabsPersistence({String? payload, bool force = false}) {
    final serverId = _sessionTabsLoadedServerId;
    if (serverId == null || serverId.isEmpty) return;
    final encoded = payload ?? _sessionTabsPersistedState.encode();
    _sessionTabsPendingPayloadByServer[serverId] = encoded;
    final debounce = _sessionTabsPersistenceDebounceByServer.remove(serverId);
    debounce?.cancel();
    if (force) {
      unawaited(
        _enqueueSessionTabsPersistence(
          serverId: serverId,
          payload: _sessionTabsPendingPayloadByServer.remove(serverId) ??
              encoded,
        ),
      );
      return;
    }
    if (_sessionTabsPersistenceDebounceDuration == Duration.zero) {
      unawaited(
        _enqueueSessionTabsPersistence(
          serverId: serverId,
          payload: _sessionTabsPendingPayloadByServer.remove(serverId) ??
              encoded,
        ),
      );
      return;
    }
    _sessionTabsPersistenceDebounceByServer[serverId] = Timer(
      _sessionTabsPersistenceDebounceDuration,
      () {
        _sessionTabsPersistenceDebounceByServer.remove(serverId);
        unawaited(
          _enqueueSessionTabsPersistence(
            serverId: serverId,
            payload: _sessionTabsPendingPayloadByServer.remove(serverId) ??
                encoded,
          ),
        );
      },
    );
  }

  /// Flushes any pending debounced session-tab persistence for [serverId] and
  /// returns a future that completes when the write has been enqueued.
  /// Callers that must observe the persisted state (e.g. cleanup paths) await
  /// this before waiting on [_sessionTabsWriteQueueByServer].
  Future<void> flushSessionTabsPersistence(String serverId) async {
    final debounce = _sessionTabsPersistenceDebounceByServer.remove(serverId);
    debounce?.cancel();
    final pending = _sessionTabsPendingPayloadByServer.remove(serverId);
    if (pending != null) {
      await _enqueueSessionTabsPersistence(serverId: serverId, payload: pending);
    }
  }

  Future<void> _enqueueSessionTabsPersistence({
    required String serverId,
    required String payload,
  }) async {
    try {
      await _enqueueSessionTabsPersistenceOperation<void>(
        serverId: serverId,
        operation: () => localDataSource.saveSessionTabsStateJson(
          payload,
          serverId: serverId,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist session tabs for server=$serverId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<T> _enqueueSessionTabsPersistenceOperation<T>({
    required String serverId,
    required Future<T> Function() operation,
  }) {
    final previous =
        _sessionTabsWriteQueueByServer[serverId] ?? Future<void>.value();
    final result = Completer<T>();
    final next = previous.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _sessionTabsWriteQueueByServer[serverId] = next;
    return result.future;
  }

  void _applySessionTabIconOverrideState(
    String serverId,
    SessionTabIconOverridesState state,
  ) {
    _invalidateSessionTabReconcileCache();
    _sessionTabIconOverridesByServer[serverId] = {
      for (final entry in state.entries)
        if (entry.serverId == serverId)
          SessionTabIdentity(
            serverId: entry.serverId,
            directory: entry.directory,
            sessionId: entry.sessionId,
          ): entry,
    };
  }

  Future<bool> _setSessionTabIconPreset(
    SessionTabIdentity identity,
    String? presetId,
  ) async {
    final normalizedPresetId = presetId?.trim();
    if (!identity.isValid ||
        identity.serverId != _sessionTabsLoadedServerId ||
        !_sessionTabs.any((tab) => tab.identity == identity) ||
        (normalizedPresetId != null &&
            normalizedPresetId.isNotEmpty &&
            SessionTabIconPreset.fromId(normalizedPresetId) == null)) {
      return false;
    }
    try {
      final state = await _sessionTabIconOverrideStore.setPreset(
        serverId: identity.serverId,
        directory: identity.directory,
        sessionId: identity.sessionId,
        presetId: normalizedPresetId,
        updatedAtMs: _sessionTabsNow().millisecondsSinceEpoch,
      );
      if (_sessionTabsDisposed ||
          identity.serverId != _sessionTabsLoadedServerId) {
        return true;
      }
      _applySessionTabIconOverrideState(identity.serverId, state);
      _reconcileSessionTabs(forcePersistence: false);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to set session tab icon for ${identity.sessionId}',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _removeSessionTabIconOverride(SessionTabIdentity identity) {
    unawaited(() async {
      try {
        final state = await _sessionTabIconOverrideStore.removeIdentity(
          serverId: identity.serverId,
          directory: identity.directory,
          sessionId: identity.sessionId,
        );
        if (_sessionTabsDisposed ||
            identity.serverId != _sessionTabsLoadedServerId) {
          return;
        }
        _applySessionTabIconOverrideState(identity.serverId, state);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Failed to remove session tab icon for ${identity.sessionId}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }());
  }

  Future<void> _removeSessionTabIconOverridesForDirectory({
    required String serverId,
    required String directory,
  }) async {
    try {
      final state = await _sessionTabIconOverrideStore.removeDirectory(
        serverId: serverId,
        directory: directory,
      );
      if (!_sessionTabsDisposed && serverId == _sessionTabsLoadedServerId) {
        _applySessionTabIconOverrideState(serverId, state);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to remove session tab icon overrides for directory=$directory',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _pruneSessionTabEventState(String serverId) {
    final retained = <SessionTabIdentity>{
      ..._sessionTabs.map((tab) => tab.identity),
      ..._sessionTabsPersistedState.closed.map(
        (tab) => SessionTabIdentity(
          serverId: serverId,
          directory: tab.directory,
          sessionId: tab.sessionId,
        ),
      ),
    };
    _sessionTabEventCandidates.removeWhere(
      (identity, _) =>
          identity.serverId == serverId && !retained.contains(identity),
    );
    _sessionTabErrorTokens.removeWhere(
      (identity, _) =>
          identity.serverId == serverId && !retained.contains(identity),
    );
    _sessionTabCompletionTokens.removeWhere(
      (identity, _) =>
          identity.serverId == serverId && !retained.contains(identity),
    );
  }

  void _updateSessionTabSignalsForEvent(
    ChatEvent event, {
    required String contextKey,
  }) {
    final sessionId = _effectiveEventSessionIdForEvent(event)?.trim();
    if (sessionId == null || sessionId.isEmpty) return;
    if (event.type == 'session.deleted') {
      final identity = _sessionTabIdentityForEventSession(
        sessionId,
        contextKey: contextKey,
      );
      if (identity != null) {
        _removeSessionTabAuthoritatively(identity, removeIconOverride: true);
      }
      return;
    }

    SessionTabIdentity? identity;
    if (event.type == 'session.created' || event.type == 'session.updated') {
      final rawInfo = event.properties['info'];
      if (rawInfo is Map) {
        try {
          final session = ChatSessionModel.fromJson(
            Map<String, dynamic>.from(rawInfo),
          ).toDomain();
          identity = _sessionTabIdentityForSession(
            session,
            contextKey: contextKey,
          );
          if (identity != null && !_isEphemeralTitleSession(session)) {
            final existing =
                _sessionTabEventCandidates[identity] ??
                _sessionTabOpenCandidate(identity);
            final title = session.title?.trim() ?? '';
            _sessionTabEventCandidates[identity] = existing == null
                ? SessionTabCandidate(
                    identity: identity,
                    projectId: _sessionTabProjectId(
                      session,
                      contextKey: contextKey,
                    ),
                    title: title,
                    serverUpdatedAtMs: session.time.millisecondsSinceEpoch,
                    isArchived: session.archived,
                    isRoot: session.parentId?.trim().isEmpty ?? true,
                  )
                : existing.copyWith(
                    projectId: _sessionTabProjectId(
                      session,
                      contextKey: contextKey,
                    ),
                    title: title.isEmpty ? existing.title : title,
                    serverUpdatedAtMs: session.time.millisecondsSinceEpoch,
                    isArchived: session.archived,
                    isRoot: session.parentId?.trim().isEmpty ?? true,
                  );
            if (session.archived &&
                contextKey == _activeContextKey &&
                _hasLoadedSessionsAuthoritatively) {
              _setSessionTabPin(
                identity,
                pinned: false,
                pinScopeId:
                    _activePinnedSessionScopeId() ?? _resolveContextScopeId(),
                persist: true,
              );
            }
          }
        } catch (error, stackTrace) {
          AppLogger.warn(
            'Failed to parse session tab event type=${event.type}',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
    identity ??= _sessionTabIdentityForEventSession(
      sessionId,
      contextKey: contextKey,
    );
    if (identity == null) return;

    final sessionUpdatedAtMs = _sessionTabServerUpdatedAtMs(
      identity,
      contextKey: contextKey,
    );
    final eventToken = _stableEventValueHash(event.properties);
    String? completionToken;
    String? errorToken;
    SessionStatusType? eventStatus;
    if (event.type == 'session.error') {
      errorToken = 'error:$sessionUpdatedAtMs:$eventToken';
      _sessionTabErrorTokens[identity] = errorToken;
    } else if (event.type == 'session.idle') {
      completionToken = 'completion:$sessionUpdatedAtMs:$eventToken';
      _sessionTabCompletionTokens[identity] = completionToken;
      eventStatus = SessionStatusType.idle;
    } else if (event.type == 'session.status') {
      final rawStatus = event.properties['status'];
      if (rawStatus is Map) {
        try {
          eventStatus = SessionStatusModel.fromJson(
            Map<String, dynamic>.from(rawStatus),
          ).toDomain().type;
          if (eventStatus == SessionStatusType.idle) {
            completionToken = 'completion:$sessionUpdatedAtMs:$eventToken';
            _sessionTabCompletionTokens[identity] = completionToken;
          }
        } catch (_) {
          // The event reducer owns malformed status recovery.
        }
      }
    }

    final existingCandidate =
        _sessionTabEventCandidates[identity] ??
        _sessionTabOpenCandidate(identity);
    if (existingCandidate == null) return;
    var nextCandidate = existingCandidate;
    if (event.type == 'session.error') {
      nextCandidate = nextCandidate.copyWith(errorToken: errorToken);
    } else if (event.type == 'session.idle') {
      nextCandidate = nextCandidate.copyWith(
        status: SessionStatusType.idle,
        completionToken: completionToken,
        errorToken: null,
      );
    } else if (event.type == 'session.status' && eventStatus != null) {
      nextCandidate = nextCandidate.copyWith(
        status: eventStatus,
        completionToken: eventStatus == SessionStatusType.idle
            ? completionToken
            : null,
        errorToken:
            eventStatus == SessionStatusType.idle ||
                eventStatus == SessionStatusType.busy ||
                eventStatus == SessionStatusType.retry
            ? null
            : nextCandidate.errorToken,
      );
    } else if (_isSessionTabQuestionOpenEvent(event.type)) {
      final questionId = _sessionTabQuestionIdForEvent(event);
      if (questionId != null) {
        nextCandidate = nextCandidate.copyWith(
          pendingQuestionIds: <String>{
            ...nextCandidate.pendingQuestionIds,
            questionId,
          },
        );
      }
    } else if (_isSessionTabQuestionResolvedEvent(event.type)) {
      final questionId = _sessionTabQuestionIdForEvent(event);
      if (questionId != null) {
        nextCandidate = nextCandidate.copyWith(
          pendingQuestionIds: nextCandidate.pendingQuestionIds.where(
            (candidate) => candidate != questionId,
          ),
        );
      }
    }
    _sessionTabEventCandidates[identity] = nextCandidate;
  }

  SessionTabCandidate? _sessionTabOpenCandidate(SessionTabIdentity identity) {
    final runtime = _sessionTabs
        .where((tab) => tab.identity == identity)
        .firstOrNull;
    if (runtime != null) {
      return SessionTabCandidate(
        identity: identity,
        projectId: runtime.projectId,
        title: runtime.title,
        serverUpdatedAtMs: runtime.serverUpdatedAtMs,
        status: runtime.status,
        isSelected: runtime.isSelected,
        pendingQuestionIds: runtime.pendingQuestionIds,
        completionToken: runtime.completionToken,
        errorToken: runtime.errorToken,
      );
    }
    final persisted = _sessionTabsPersistedState.open
        .where(
          (tab) =>
              normalizeFilePath(tab.directory) == identity.directory &&
              tab.sessionId.trim() == identity.sessionId,
        )
        .firstOrNull;
    if (persisted == null) return null;
    return SessionTabCandidate(
      identity: identity,
      projectId: persisted.projectId,
      title: persisted.title,
      serverUpdatedAtMs: persisted.serverUpdatedAtMs,
    );
  }

  bool _isSessionTabQuestionOpenEvent(String type) {
    return type == 'question.asked' ||
        type == 'question.updated' ||
        type == 'question.v2.asked' ||
        type == 'question.v2.updated';
  }

  bool _isSessionTabQuestionResolvedEvent(String type) {
    return type == 'question.replied' ||
        type == 'question.rejected' ||
        type == 'question.v2.replied' ||
        type == 'question.v2.rejected';
  }

  String? _sessionTabQuestionIdForEvent(ChatEvent event) {
    final payload = _eventPayloadOrNested(event.properties, const <String>[
      'question',
      'request',
      'info',
    ]);
    final rawId = payload['requestID'] ?? payload['id'];
    if (rawId is! String) return null;
    final normalized = rawId.trim();
    return normalized.isEmpty ? null : normalized;
  }

  SessionTabIdentity? _sessionTabIdentityForEventSession(
    String sessionId, {
    required String contextKey,
  }) {
    final sessions = contextKey == _activeContextKey
        ? _sessions
        : _contextSnapshots[contextKey]?.sessions ?? const <ChatSession>[];
    final session = sessions
        .where((candidate) => candidate.id == sessionId)
        .firstOrNull;
    if (session != null) {
      return _sessionTabIdentityForSession(session, contextKey: contextKey);
    }
    final serverId = _serverIdFromContextKey(contextKey);
    final directory = normalizeOptionalFilePath(
      _scopeIdFromContextKey(contextKey),
    );
    if (serverId == null || directory == null) return null;
    final identity = SessionTabIdentity(
      serverId: serverId,
      directory: directory,
      sessionId: sessionId,
    );
    return identity.isValid ? identity : null;
  }

  int _sessionTabServerUpdatedAtMs(
    SessionTabIdentity identity, {
    required String contextKey,
  }) {
    final sessions = contextKey == _activeContextKey
        ? _sessions
        : _contextSnapshots[contextKey]?.sessions ?? const <ChatSession>[];
    final session = sessions
        .where((candidate) => candidate.id == identity.sessionId)
        .firstOrNull;
    if (session != null) return session.time.millisecondsSinceEpoch;
    final eventCandidate = _sessionTabEventCandidates[identity];
    if (eventCandidate != null) return eventCandidate.serverUpdatedAtMs;
    final tab = _sessionTabs
        .where((candidate) => candidate.identity == identity)
        .firstOrNull;
    return tab?.serverUpdatedAtMs ?? 0;
  }

  void _removeSessionTabAuthoritatively(
    SessionTabIdentity identity, {
    bool activeContext = false,
    bool removeIconOverride = false,
  }) {
    if (!identity.isValid) return;
    if (removeIconOverride) _removeSessionTabIconOverride(identity);
    final runtimeTab = _sessionTabs
        .where((candidate) => candidate.identity == identity)
        .firstOrNull;
    if (activeContext) {
      if (runtimeTab != null && runtimeTab.pinScopeIds.isNotEmpty) {
        _setSessionTabPin(
          identity,
          pinned: false,
          pinScopeIds: runtimeTab.pinScopeIds,
          persist: true,
        );
      } else {
        final scopeId =
            _activePinnedSessionScopeId() ?? _resolveContextScopeId();
        final changed = _setActiveSessionPin(
          serverId: identity.serverId,
          scopeId: scopeId,
          sessionId: identity.sessionId,
          pinned: false,
        );
        if (changed) {
          unawaited(
            _persistPinnedSessionScope(
              serverId: identity.serverId,
              scopeId: scopeId,
              ids: _pinnedSessionIds,
            ),
          );
        }
      }
    } else if (_hasLoadedSessionsAuthoritatively) {
      _setSessionTabPin(
        identity,
        pinned: false,
        pinScopeId: runtimeTab?.pinScopeId,
        pinScopeIds: runtimeTab?.pinScopeIds,
        persist: true,
      );
    }
    if (_sessionTabsLoadedServerId != identity.serverId) return;
    final previous =
        _sessionTabsPersistedStateEncoded ??
        _sessionTabsPersistedState.encode();
    _invalidateSessionTabReconcileCache();
    _sessionTabsPersistedState = PersistedSessionTabsState(
      open: _sessionTabsPersistedState.open
          .where(
            (tab) => !SessionTabReconciler._matchesPersisted(tab, identity),
          )
          .toList(growable: false),
      closed: _sessionTabsPersistedState.closed
          .where((tab) => !SessionTabReconciler._matchesClosed(tab, identity))
          .toList(growable: false),
    );
    final nextTabs = _sessionTabs
        .where((tab) => tab.identity != identity)
        .toList(growable: false);
    final runtimeChanged = nextTabs.length != _sessionTabs.length;
    _sessionTabs = List<SessionTabRecord>.unmodifiable(nextTabs);
    _sessionTabEventCandidates.removeWhere(
      (candidateIdentity, _) => candidateIdentity == identity,
    );
    _sessionTabErrorTokens.removeWhere(
      (candidateIdentity, _) => candidateIdentity == identity,
    );
    _sessionTabCompletionTokens.removeWhere(
      (candidateIdentity, _) => candidateIdentity == identity,
    );
    final nextStateJson = _sessionTabsPersistedState.encode();
    _sessionTabsPersistedStateEncoded = nextStateJson;
    if (previous != nextStateJson) {
      _scheduleSessionTabsPersistence();
    }
    if (runtimeChanged) _notifyListeners();
  }

  void _closeSessionTab(SessionTabIdentity identity) {
    final serverId = _activeServerId.trim();
    if (!identity.isValid ||
        identity.serverId != serverId ||
        _sessionTabsLoadedServerId != serverId ||
        !_sessionTabs.any((tab) => tab.identity == identity)) {
      return;
    }
    final tab = _sessionTabs
        .where((candidate) => candidate.identity == identity)
        .first;
    if (tab.isPinned) {
      _setSessionTabPin(
        identity,
        pinned: false,
        pinScopeId: tab.pinScopeId,
        pinScopeIds: tab.pinScopeIds,
        persist: true,
      );
    }
    final nextState = SessionTabReconciler.close(
      state: _sessionTabsPersistedState,
      identity: identity,
      nowMs: _sessionTabsNow().millisecondsSinceEpoch,
    );
    if (nextState.encode() == _sessionTabsPersistedState.encode()) return;
    _invalidateSessionTabReconcileCache();
    _sessionTabsPersistedState = nextState;
    if (_sessionTabBootstrapDirectory == identity.directory) {
      _sessionTabBootstrapDirectory = null;
      _sessionTabBootstrapGeneration += 1;
    }
    _reconcileSessionTabs(forcePersistence: true);
  }

  bool _restoreClosedSessionTab(SessionTabRecord tab, {required int index}) {
    final identity = tab.identity;
    final serverId = _activeServerId.trim();
    if (!identity.isValid ||
        identity.serverId != serverId ||
        _sessionTabsLoadedServerId != serverId) {
      return false;
    }
    if (_sessionTabs.any((candidate) => candidate.identity == identity)) {
      return true;
    }
    if (!_sessionTabsPersistedState.closed.any(
      (closed) => SessionTabReconciler._matchesClosed(closed, identity),
    )) {
      return false;
    }
    final candidate = _collectSessionTabCandidates(
      serverId,
    ).where((candidate) => candidate.identity == identity).firstOrNull;
    if (candidate != null && (!candidate.isRoot || candidate.isArchived)) {
      return false;
    }
    final repinned =
        tab.isPinned &&
        _setSessionTabPin(
          identity,
          pinned: true,
          pinScopeId: tab.pinScopeId,
          persist: true,
        );

    final open = _sessionTabsPersistedState.open
        .where(
          (persisted) =>
              !SessionTabReconciler._matchesPersisted(persisted, identity),
        )
        .toList(growable: true);
    final insertionIndex = math.min(math.max(index, 0), open.length);
    open.insert(insertionIndex, tab.toPersisted());
    _invalidateSessionTabReconcileCache();
    _sessionTabsPersistedState = PersistedSessionTabsState(
      open: open,
      closed: _sessionTabsPersistedState.closed
          .where(
            (closed) => !SessionTabReconciler._matchesClosed(closed, identity),
          )
          .toList(growable: false),
    );
    _reconcileSessionTabs(explicitlyOpened: identity, forcePersistence: true);
    final restored = _sessionTabs.any(
      (candidate) => candidate.identity == identity,
    );
    if (!restored && repinned) {
      _setSessionTabPin(
        identity,
        pinned: false,
        pinScopeId: tab.pinScopeId,
        persist: true,
      );
    }
    return restored;
  }

  Future<void> _removeSessionTabsForProjectHistory({
    required String serverId,
    required String directory,
  }) async {
    final normalizedServerId = serverId.trim();
    final normalizedDirectory = normalizeOptionalFilePath(directory);
    if (normalizedServerId.isEmpty || normalizedDirectory == null) return;

    await _removeSessionTabIconOverridesForDirectory(
      serverId: normalizedServerId,
      directory: normalizedDirectory,
    );

    _removeSessionTabsForDirectory(
      serverId: normalizedServerId,
      directory: normalizedDirectory,
    );
    if (_sessionTabsLoadedServerId == normalizedServerId) {
      await flushSessionTabsPersistence(normalizedServerId);
      final pendingWrite = _sessionTabsWriteQueueByServer[normalizedServerId];
      if (pendingWrite != null) await pendingWrite;
      return;
    }

    try {
      await _enqueueSessionTabsPersistenceOperation<void>(
        serverId: normalizedServerId,
        operation: () async {
          final raw = await localDataSource.getSessionTabsStateJson(
            serverId: normalizedServerId,
          );
          final state = PersistedSessionTabsState.decode(raw);
          final nextState = PersistedSessionTabsState(
            open: state.open
                .where(
                  (tab) =>
                      normalizeFilePath(tab.directory) != normalizedDirectory,
                )
                .toList(growable: false),
            closed: state.closed
                .where(
                  (tab) =>
                      normalizeFilePath(tab.directory) != normalizedDirectory,
                )
                .toList(growable: false),
          );
          final payload = nextState.encode();
          if (payload == state.encode()) return;
          await localDataSource.saveSessionTabsStateJson(
            payload,
            serverId: normalizedServerId,
          );
        },
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to update session tabs for project-history cleanup '
        'server=$normalizedServerId',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _removeSessionTabsForDirectory(
      serverId: normalizedServerId,
      directory: normalizedDirectory,
    );
    if (_sessionTabsLoadedServerId == normalizedServerId) {
      await flushSessionTabsPersistence(normalizedServerId);
      final activeWrite = _sessionTabsWriteQueueByServer[normalizedServerId];
      if (activeWrite != null) await activeWrite;
    }
  }

  void _removeSessionTabsForDirectory({
    required String serverId,
    required String directory,
  }) {
    final normalizedServerId = serverId.trim();
    final normalizedDirectory = normalizeOptionalFilePath(directory);
    if (normalizedServerId.isEmpty || normalizedDirectory == null) {
      return;
    }
    final previous =
        _sessionTabsPersistedStateEncoded ??
        _sessionTabsPersistedState.encode();
    if (_sessionTabsLoadedServerId == normalizedServerId) {
      _invalidateSessionTabReconcileCache();
      _sessionTabsPersistedState = PersistedSessionTabsState(
        open: _sessionTabsPersistedState.open
            .where(
              (tab) => normalizeFilePath(tab.directory) != normalizedDirectory,
            )
            .toList(growable: false),
        closed: _sessionTabsPersistedState.closed
            .where(
              (tab) => normalizeFilePath(tab.directory) != normalizedDirectory,
            )
            .toList(growable: false),
      );
    }
    final nextTabs = _sessionTabs
        .where(
          (tab) =>
              tab.identity.serverId != normalizedServerId ||
              tab.identity.directory != normalizedDirectory,
        )
        .toList(growable: false);
    final runtimeChanged = nextTabs.length != _sessionTabs.length;
    _sessionTabs = List<SessionTabRecord>.unmodifiable(nextTabs);
    _contextSnapshots.removeWhere(
      (contextKey, _) =>
          _serverIdFromContextKey(contextKey) == normalizedServerId &&
          normalizeOptionalFilePath(_scopeIdFromContextKey(contextKey)) ==
              normalizedDirectory,
    );
    _dirtyContextKeys.removeWhere(
      (contextKey) =>
          _serverIdFromContextKey(contextKey) == normalizedServerId &&
          normalizeOptionalFilePath(_scopeIdFromContextKey(contextKey)) ==
              normalizedDirectory,
    );
    _sessionTabEventCandidates.removeWhere(
      (identity, _) =>
          identity.serverId == normalizedServerId &&
          identity.directory == normalizedDirectory,
    );
    _sessionTabErrorTokens.removeWhere(
      (identity, _) =>
          identity.serverId == normalizedServerId &&
          identity.directory == normalizedDirectory,
    );
    _sessionTabCompletionTokens.removeWhere(
      (identity, _) =>
          identity.serverId == normalizedServerId &&
          identity.directory == normalizedDirectory,
    );
    final nextStateJson = _sessionTabsPersistedState.encode();
    _sessionTabsPersistedStateEncoded = nextStateJson;
    if (_sessionTabsLoadedServerId == normalizedServerId &&
        previous != nextStateJson) {
      _scheduleSessionTabsPersistence();
    }
    if (runtimeChanged) _notifyListeners();
  }
}
