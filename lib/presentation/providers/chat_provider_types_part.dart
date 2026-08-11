part of 'chat_provider.dart';

class ChatUiNotice {
  const ChatUiNotice({
    required this.id,
    required this.type,
    required this.message,
    this.actionLabel,
  });

  final int id;
  final ChatUiNoticeType type;
  final String message;
  final String? actionLabel;

  bool get hasAction => actionLabel != null && actionLabel!.trim().isNotEmpty;
}

enum SessionAttentionKind {
  none,
  active,
  unreadCompletion,
  pendingInteraction,
  error,
}

@immutable
class SessionAttentionState {
  const SessionAttentionState({
    this.isActive = false,
    this.hasPendingInteraction = false,
    this.hasError = false,
    this.hasUnreadCompletion = false,
    this.unreadCompletionAt,
  });

  final bool isActive;
  final bool hasPendingInteraction;
  final bool hasError;
  final bool hasUnreadCompletion;
  final DateTime? unreadCompletionAt;

  bool get hasRecentUnreadCompletion {
    final unreadAt = unreadCompletionAt;
    if (!hasUnreadCompletion || unreadAt == null) {
      return false;
    }
    return DateTime.now().difference(unreadAt) < const Duration(hours: 1);
  }

  bool get requiresAttention =>
      hasPendingInteraction || hasError || hasUnreadCompletion;

  SessionAttentionKind get primaryKind {
    if (hasError) {
      return SessionAttentionKind.error;
    }
    if (hasPendingInteraction) {
      return SessionAttentionKind.pendingInteraction;
    }
    if (hasUnreadCompletion) {
      return SessionAttentionKind.unreadCompletion;
    }
    if (isActive) {
      return SessionAttentionKind.active;
    }
    return SessionAttentionKind.none;
  }
}

@immutable
class SessionTabIdentity {
  SessionTabIdentity({
    required String serverId,
    required String directory,
    required String sessionId,
  }) : serverId = serverId.trim(),
       directory = normalizeFilePath(directory),
       sessionId = sessionId.trim();

  final String serverId;
  final String directory;
  final String sessionId;

  bool get isValid =>
      serverId.isNotEmpty && directory.isNotEmpty && sessionId.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is SessionTabIdentity &&
        other.serverId == serverId &&
        other.directory == directory &&
        other.sessionId == sessionId;
  }

  @override
  int get hashCode => Object.hash(serverId, directory, sessionId);
}

@immutable
class SessionTabRecord {
  SessionTabRecord({
    required this.identity,
    required this.title,
    required this.lastOpenedAtMs,
    required this.serverUpdatedAtMs,
    required this.status,
    this.projectId,
    Iterable<String> pendingQuestionIds = const <String>[],
    Iterable<String> seenQuestionIds = const <String>[],
    this.completionToken,
    this.seenCompletionToken,
    this.errorToken,
    this.seenErrorToken,
    this.isSelected = false,
  }) : pendingQuestionIds = _normalizedSessionTabIds(pendingQuestionIds),
       seenQuestionIds = _normalizedSessionTabIds(seenQuestionIds);

  final SessionTabIdentity identity;
  final String? projectId;
  final String title;
  final int lastOpenedAtMs;
  final int serverUpdatedAtMs;
  final SessionStatusType status;
  final List<String> pendingQuestionIds;
  final List<String> seenQuestionIds;
  final String? completionToken;
  final String? seenCompletionToken;
  final String? errorToken;
  final String? seenErrorToken;
  final bool isSelected;

  bool get isBusy =>
      status == SessionStatusType.busy || status == SessionStatusType.retry;
  bool get hasUnseenQuestion => pendingQuestionIds.any(
    (questionId) => !seenQuestionIds.contains(questionId),
  );
  bool get hasUnseenCompletion =>
      completionToken != null && completionToken != seenCompletionToken;
  bool get hasUnseenError => errorToken != null && errorToken != seenErrorToken;
  bool get requiresAttention =>
      hasUnseenQuestion || hasUnseenCompletion || hasUnseenError;

  SessionAttentionKind get attentionKind {
    if (hasUnseenError) return SessionAttentionKind.error;
    if (hasUnseenQuestion) return SessionAttentionKind.pendingInteraction;
    if (hasUnseenCompletion) return SessionAttentionKind.unreadCompletion;
    if (isBusy) return SessionAttentionKind.active;
    return SessionAttentionKind.none;
  }

  PersistedSessionTab toPersisted() {
    return PersistedSessionTab(
      directory: identity.directory,
      projectId: projectId,
      sessionId: identity.sessionId,
      title: title,
      lastOpenedAtMs: lastOpenedAtMs,
      serverUpdatedAtMs: serverUpdatedAtMs,
      seenQuestionIds: seenQuestionIds,
      seenCompletionToken: seenCompletionToken,
      seenErrorToken: seenErrorToken,
    );
  }

  SessionTabRecord copyWith({
    String? projectId,
    String? title,
    int? lastOpenedAtMs,
    int? serverUpdatedAtMs,
    SessionStatusType? status,
    Iterable<String>? pendingQuestionIds,
    Iterable<String>? seenQuestionIds,
    Object? completionToken = _sessionTabUnset,
    Object? seenCompletionToken = _sessionTabUnset,
    Object? errorToken = _sessionTabUnset,
    Object? seenErrorToken = _sessionTabUnset,
    bool? isSelected,
  }) {
    return SessionTabRecord(
      identity: identity,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      lastOpenedAtMs: lastOpenedAtMs ?? this.lastOpenedAtMs,
      serverUpdatedAtMs: serverUpdatedAtMs ?? this.serverUpdatedAtMs,
      status: status ?? this.status,
      pendingQuestionIds: pendingQuestionIds ?? this.pendingQuestionIds,
      seenQuestionIds: seenQuestionIds ?? this.seenQuestionIds,
      completionToken: identical(completionToken, _sessionTabUnset)
          ? this.completionToken
          : completionToken as String?,
      seenCompletionToken: identical(seenCompletionToken, _sessionTabUnset)
          ? this.seenCompletionToken
          : seenCompletionToken as String?,
      errorToken: identical(errorToken, _sessionTabUnset)
          ? this.errorToken
          : errorToken as String?,
      seenErrorToken: identical(seenErrorToken, _sessionTabUnset)
          ? this.seenErrorToken
          : seenErrorToken as String?,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTabRecord &&
        other.identity == identity &&
        other.projectId == projectId &&
        other.title == title &&
        other.lastOpenedAtMs == lastOpenedAtMs &&
        other.serverUpdatedAtMs == serverUpdatedAtMs &&
        other.status == status &&
        listEquals(other.pendingQuestionIds, pendingQuestionIds) &&
        listEquals(other.seenQuestionIds, seenQuestionIds) &&
        other.completionToken == completionToken &&
        other.seenCompletionToken == seenCompletionToken &&
        other.errorToken == errorToken &&
        other.seenErrorToken == seenErrorToken &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode => Object.hash(
    identity,
    projectId,
    title,
    lastOpenedAtMs,
    serverUpdatedAtMs,
    status,
    Object.hashAll(pendingQuestionIds),
    Object.hashAll(seenQuestionIds),
    completionToken,
    seenCompletionToken,
    errorToken,
    seenErrorToken,
    isSelected,
  );
}

SessionTabRecord? sessionTabCloseFallback(
  List<SessionTabRecord> tabs,
  SessionTabIdentity identity,
) {
  final index = tabs.indexWhere((tab) => tab.identity == identity);
  if (index < 0) return null;
  if (index + 1 < tabs.length) return tabs[index + 1];
  if (index > 0) return tabs[index - 1];
  return null;
}

@immutable
class SessionTabCandidate {
  SessionTabCandidate({
    required this.identity,
    required this.title,
    required this.serverUpdatedAtMs,
    this.projectId,
    this.status = SessionStatusType.idle,
    this.isSelected = false,
    this.isArchived = false,
    this.isRoot = true,
    Iterable<String> pendingQuestionIds = const <String>[],
    this.completionToken,
    this.errorToken,
  }) : pendingQuestionIds = _normalizedSessionTabIds(pendingQuestionIds);

  final SessionTabIdentity identity;
  final String? projectId;
  final String title;
  final int serverUpdatedAtMs;
  final SessionStatusType status;
  final bool isSelected;
  final bool isArchived;
  final bool isRoot;
  final List<String> pendingQuestionIds;
  final String? completionToken;
  final String? errorToken;

  bool get isBusy =>
      status == SessionStatusType.busy || status == SessionStatusType.retry;

  SessionTabCandidate copyWith({
    String? projectId,
    String? title,
    int? serverUpdatedAtMs,
    SessionStatusType? status,
    bool? isSelected,
    bool? isArchived,
    bool? isRoot,
    Iterable<String>? pendingQuestionIds,
    Object? completionToken = _sessionTabUnset,
    Object? errorToken = _sessionTabUnset,
  }) {
    return SessionTabCandidate(
      identity: identity,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      serverUpdatedAtMs: serverUpdatedAtMs ?? this.serverUpdatedAtMs,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
      isArchived: isArchived ?? this.isArchived,
      isRoot: isRoot ?? this.isRoot,
      pendingQuestionIds: pendingQuestionIds ?? this.pendingQuestionIds,
      completionToken: identical(completionToken, _sessionTabUnset)
          ? this.completionToken
          : completionToken as String?,
      errorToken: identical(errorToken, _sessionTabUnset)
          ? this.errorToken
          : errorToken as String?,
    );
  }
}

@immutable
class SessionTabReconciliationResult {
  const SessionTabReconciliationResult({
    required this.tabs,
    required this.persistedState,
  });

  final List<SessionTabRecord> tabs;
  final PersistedSessionTabsState persistedState;
}

const Object _sessionTabUnset = Object();

List<String> _normalizedSessionTabIds(Iterable<String> values) {
  final normalized = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  normalized.sort();
  return normalized;
}

class _AgentSelectionMemory {
  const _AgentSelectionMemory({
    required this.providerId,
    required this.modelId,
    this.variantId,
  });

  final String providerId;
  final String modelId;
  final String? variantId;
}

class _RejectedDraftEnvelope {
  const _RejectedDraftEnvelope({required this.sessionId, required this.draft});

  final String sessionId;
  final ChatComposerDraft draft;
}

class _HistoryComposerSync {
  const _HistoryComposerSync({
    required this.token,
    required this.sessionId,
    this.draft,
    this.clear = false,
  });

  final int token;
  final String sessionId;
  final ChatComposerDraft? draft;
  final bool clear;
}

class _PendingReplacementBranch {
  const _PendingReplacementBranch({
    required this.sessionId,
    required this.revertMessageId,
    this.replacementRootMessageId,
  });

  final String sessionId;
  final String revertMessageId;
  final String? replacementRootMessageId;

  String get cacheKey =>
      '$sessionId::$revertMessageId::${replacementRootMessageId ?? ''}';

  _PendingReplacementBranch copyWith({String? replacementRootMessageId}) {
    return _PendingReplacementBranch(
      sessionId: sessionId,
      revertMessageId: revertMessageId,
      replacementRootMessageId:
          replacementRootMessageId ?? this.replacementRootMessageId,
    );
  }
}

class _ChatContextSnapshot {
  const _ChatContextSnapshot({
    required this.sessions,
    required this.currentSession,
    required this.messages,
    required this.sessionStatusById,
    required this.pendingPermissionsBySession,
    required this.pendingQuestionsBySession,
    required this.sessionUnreadCompletionIds,
    required this.sessionUnreadCompletionTimestamps,
    required this.sessionErrorAttentionIds,
    required this.sessionChildrenById,
    required this.sessionTodoById,
    required this.sessionDiffById,
    required this.sessionSearchQuery,
    required this.sessionListFilter,
    required this.sessionListSort,
    required this.pinnedSessionIds,
    required this.sessionVisibleLimit,
    required this.isNewChatDraftActive,
    required this.activeSendDraft,
    required this.rejectedDraft,
    required this.questionSubmitFailedRequestIds,
    required this.providers,
    required this.defaultModels,
    required this.connectedProviderIds,
    required this.agents,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.selectedAgentName,
    required this.selectedVariantId,
    required this.recentModelKeys,
    required this.recentAgentNames,
    required this.recentVariantValuesByModel,
    required this.modelUsageCounts,
    required this.selectedVariantByModel,
    required this.agentSelectionMemoryByAgent,
    required this.providerCatalogFetchedAtEpochMs,
    required this.agentCatalogFetchedAtEpochMs,
  });

  final List<ChatSession> sessions;
  final ChatSession? currentSession;
  final List<ChatMessage> messages;
  final Map<String, SessionStatusInfo> sessionStatusById;
  final Map<String, List<ChatPermissionRequest>> pendingPermissionsBySession;
  final Map<String, List<ChatQuestionRequest>> pendingQuestionsBySession;
  final Set<String> sessionUnreadCompletionIds;
  final Map<String, DateTime> sessionUnreadCompletionTimestamps;
  final Set<String> sessionErrorAttentionIds;
  final Map<String, List<ChatSession>> sessionChildrenById;
  final Map<String, List<SessionTodo>> sessionTodoById;
  final Map<String, List<SessionDiff>> sessionDiffById;
  final String sessionSearchQuery;
  final SessionListFilter sessionListFilter;
  final SessionListSort sessionListSort;
  final Set<String> pinnedSessionIds;
  final int sessionVisibleLimit;
  final bool isNewChatDraftActive;
  final ChatComposerDraft? activeSendDraft;
  final _RejectedDraftEnvelope? rejectedDraft;
  final Set<String> questionSubmitFailedRequestIds;
  final List<Provider> providers;
  final Map<String, String> defaultModels;
  final List<String> connectedProviderIds;
  final List<Agent> agents;
  final String? selectedProviderId;
  final String? selectedModelId;
  final String? selectedAgentName;
  final String? selectedVariantId;
  final List<String> recentModelKeys;
  final List<String> recentAgentNames;
  final Map<String, List<String>> recentVariantValuesByModel;
  final Map<String, int> modelUsageCounts;
  final Map<String, String> selectedVariantByModel;
  final Map<String, _AgentSelectionMemory> agentSelectionMemoryByAgent;
  final int? providerCatalogFetchedAtEpochMs;
  final int? agentCatalogFetchedAtEpochMs;
}

class _AutoTitleCandidateMessage {
  const _AutoTitleCandidateMessage({
    required this.id,
    required this.role,
    required this.text,
  });

  final String id;
  final MessageRole role;
  final String text;
}

class _AutoTitleSnapshot {
  const _AutoTitleSnapshot({
    required this.messages,
    required this.signature,
    required this.userCount,
    required this.assistantCount,
  });

  final List<_AutoTitleCandidateMessage> messages;
  final String signature;
  final int userCount;
  final int assistantCount;

  bool get isConsolidated => userCount >= 3 && assistantCount >= 3;
}

class _RemoteChatSelection {
  const _RemoteChatSelection({
    this.providerId,
    this.modelId,
    this.agentName,
    this.variantByAgentAndModel = const <String, Map<String, String>>{},
    this.sessionOverridesBySessionId =
        const <String, _SessionSelectionOverride>{},
  });

  final String? providerId;
  final String? modelId;
  final String? agentName;
  final Map<String, Map<String, String>> variantByAgentAndModel;
  final Map<String, _SessionSelectionOverride> sessionOverridesBySessionId;

  bool get hasModel =>
      providerId != null &&
      providerId!.trim().isNotEmpty &&
      modelId != null &&
      modelId!.trim().isNotEmpty;

  String? variantForModel({
    required String agentName,
    required String modelKey,
  }) {
    final byModel = variantByAgentAndModel[agentName];
    if (byModel == null) {
      return null;
    }
    return byModel[modelKey];
  }
}

class _ProviderCatalogSnapshot {
  const _ProviderCatalogSnapshot({
    required this.providers,
    required this.defaultModels,
    required this.connected,
    required this.agents,
    this.providerFetchedAtEpochMs,
    this.agentFetchedAtEpochMs,
  });

  final List<Provider> providers;
  final Map<String, String> defaultModels;
  final List<String> connected;
  final List<Agent> agents;
  final int? providerFetchedAtEpochMs;
  final int? agentFetchedAtEpochMs;

  bool get isEmpty => providers.isEmpty && agents.isEmpty;
}

enum _CatalogAuthority { unknown, stale, authoritative }

class _SessionSelectionOverride {
  const _SessionSelectionOverride({
    required this.providerId,
    required this.modelId,
    required this.agentName,
    required this.variantId,
    required this.updatedAtEpochMs,
    this.isExplicit = false,
  });

  final String providerId;
  final String modelId;
  final String agentName;
  final String? variantId;
  final int updatedAtEpochMs;

  // Whether this override was set by an explicit user action (manual
  // provider/model/agent change) as opposed to session-switch continuity
  // or config-sync defaults. Message-derived fallback (Feature 7) can
  // override a non-explicit override but not an explicit one.
  final bool isExplicit;
}

enum _ShortcutCycleDomain { model, agent, variant }

class _ShortcutCycleState {
  const _ShortcutCycleState({
    required this.snapshot,
    required this.currentIndex,
    required this.lastActivatedAt,
    required this.reverse,
  });

  final List<String> snapshot;
  final int currentIndex;
  final DateTime lastActivatedAt;
  final bool reverse;
}

// Moved from chat_provider.dart — top-level enums and selection persistence snapshot.
enum ChatState { initial, loading, loaded, error, sending }

enum ChatSyncState { connected, reconnecting, delayed }

enum ChatProvidersRefreshState { idle, loading, ready, failed }

enum _SelectionSyncTransactionPhase {
  idle,
  pendingRemote,
  appliedRemote,
  failed,
}

class _SelectionPersistenceSnapshot {
  const _SelectionPersistenceSnapshot({
    required this.serverId,
    required this.scopeId,
    required this.contextKey,
    required this.remoteSyncGeneration,
    required this.selectedProviderId,
    required this.selectedModelId,
    required this.selectedAgentName,
    required this.recentModelsJson,
    required this.modelUsageCountsJson,
    required this.selectedVariantMapJson,
    required this.agentSelectionMemoryJson,
    required this.sessionSelectionOverridesJson,
    required this.syncRemote,
  });

  final String serverId;
  final String scopeId;
  final String contextKey;
  final int remoteSyncGeneration;
  final String? selectedProviderId;
  final String? selectedModelId;
  final String? selectedAgentName;
  final String recentModelsJson;
  final String modelUsageCountsJson;
  final String selectedVariantMapJson;
  final String agentSelectionMemoryJson;
  final String sessionSelectionOverridesJson;
  final bool syncRemote;

  _SelectionPersistenceSnapshot copyWith({bool? syncRemote}) {
    return _SelectionPersistenceSnapshot(
      serverId: serverId,
      scopeId: scopeId,
      contextKey: contextKey,
      remoteSyncGeneration: remoteSyncGeneration,
      selectedProviderId: selectedProviderId,
      selectedModelId: selectedModelId,
      selectedAgentName: selectedAgentName,
      recentModelsJson: recentModelsJson,
      modelUsageCountsJson: modelUsageCountsJson,
      selectedVariantMapJson: selectedVariantMapJson,
      agentSelectionMemoryJson: agentSelectionMemoryJson,
      sessionSelectionOverridesJson: sessionSelectionOverridesJson,
      syncRemote: syncRemote ?? this.syncRemote,
    );
  }
}

enum SessionListFilter { active, archived, all }

enum SessionListSort { recent, oldest, title }

enum ChatUiNoticeType { remoteAbort, serverError }
