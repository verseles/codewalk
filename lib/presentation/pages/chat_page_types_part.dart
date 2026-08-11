part of 'chat_page.dart';

class _NewSessionIntent extends Intent {
  const _NewSessionIntent();
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _FocusInputIntent extends Intent {
  const _FocusInputIntent();
}

class _ToggleVoiceInputIntent extends Intent {
  const _ToggleVoiceInputIntent();
}

class _QuickOpenIntent extends Intent {
  const _QuickOpenIntent();
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class _CycleRecentModelsIntent extends Intent {
  const _CycleRecentModelsIntent();
}

class _CycleVariantIntent extends Intent {
  const _CycleVariantIntent();
}

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

class _QuitAppIntent extends Intent {
  const _QuitAppIntent();
}

class _ModelSelectorEntry {
  const _ModelSelectorEntry({
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.modelName,
    required this.isOpenCodeZenFree,
  });

  final String providerId;
  final String providerName;
  final String modelId;
  final String modelName;
  final bool isOpenCodeZenFree;
}

class _SessionContextUsageSnapshot {
  const _SessionContextUsageSnapshot({
    required this.usagePercent,
    required this.totalTokens,
    required this.totalCost,
    required this.modelLimit,
  });

  final int usagePercent;
  final int totalTokens;
  final double totalCost;
  final int? modelLimit;
}

class _SessionTimelineEntriesCacheEntry {
  const _SessionTimelineEntriesCacheEntry({
    required this.sourceMessages,
    required this.entries,
    required this.messagesVersion,
    required this.isCompacting,
    required this.isResponding,
    required this.showRetry,
    required this.permissionPromptSignature,
    required this.assistantWorkCompactionDecision,
    required this.expandedHistoryGroupId,
    required this.expandedAssistantWorkGroupId,
    required this.wasCompactingContext,
    required this.frozenCompactionBoundaryId,
    required this.showThinkingBubbles,
    required this.showToolCallBubbles,
    required this.chatRenderMode,
  });

  final List<ChatMessage> sourceMessages;
  final List<_TimelineEntry> entries;
  final int messagesVersion;
  final bool isCompacting;
  final bool isResponding;
  final bool showRetry;
  final String permissionPromptSignature;
  final _AssistantWorkCompactionDecision assistantWorkCompactionDecision;
  final String? expandedHistoryGroupId;
  final String? expandedAssistantWorkGroupId;
  final bool wasCompactingContext;
  final String? frozenCompactionBoundaryId;
  final bool showThinkingBubbles;
  final bool showToolCallBubbles;
  final ChatRenderMode chatRenderMode;
}

class _AssistantWorkCompactionDecision {
  const _AssistantWorkCompactionDecision({
    required this.shouldDeferLatestCollapse,
    required this.latestRevealableAssistantMessageId,
    required this.settledLatestAssistantWorkGroupId,
  });

  final bool shouldDeferLatestCollapse;
  final String? latestRevealableAssistantMessageId;
  final String? settledLatestAssistantWorkGroupId;

  bool get hasSettledLatestWorkGroup =>
      settledLatestAssistantWorkGroupId != null &&
      latestRevealableAssistantMessageId != null &&
      latestRevealableAssistantMessageId!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _AssistantWorkCompactionDecision) return false;
    return other.shouldDeferLatestCollapse == shouldDeferLatestCollapse &&
        other.latestRevealableAssistantMessageId ==
            latestRevealableAssistantMessageId &&
        other.settledLatestAssistantWorkGroupId ==
            settledLatestAssistantWorkGroupId;
  }

  @override
  int get hashCode => Object.hash(
    shouldDeferLatestCollapse,
    latestRevealableAssistantMessageId,
    settledLatestAssistantWorkGroupId,
  );
}

enum _HamburgerBadgeReasonKind {
  none,
  serverAlert,
  sessionError,
  sessionPendingInteraction,
  sessionUnreadCompletion,
  syncLoading,
  dataSaver,
}

class _HamburgerBadgeReasonState {
  const _HamburgerBadgeReasonState({
    required this.kind,
    this.sessionId,
    this.sessionTitle,
  });

  const _HamburgerBadgeReasonState.none()
    : kind = _HamburgerBadgeReasonKind.none,
      sessionId = null,
      sessionTitle = null;

  final _HamburgerBadgeReasonKind kind;
  final String? sessionId;
  final String? sessionTitle;

  bool get hasBadge => kind != _HamburgerBadgeReasonKind.none;
}

class _ViewportBuildKey {
  const _ViewportBuildKey({
    required this.sessionId,
    required this.messagesVersion,
    required this.isActivelyResponding,
  });

  final String? sessionId;
  final int messagesVersion;
  final bool isActivelyResponding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ViewportBuildKey) return false;
    return other.sessionId == sessionId &&
        other.messagesVersion == messagesVersion &&
        other.isActivelyResponding == isActivelyResponding;
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, messagesVersion, isActivelyResponding);
}

typedef _ChatContentBuildKey = ({
  bool canAbortActiveResponse,
  bool canRedoCurrentSession,
  bool canUndoCurrentSession,
  String? errorMessage,
  bool isActivelyResponding,
  bool isCompactingContext,
  bool isCurrentSessionDiffLoaded,
  bool isDraftingNewChat,
  int messagesVersion,
  int modelAttachmentSignature,
  int pendingHistoryComposerSyncToken,
  int quickReplySelectionSignature,
  int sessionDiffSignature,
  int sessionSignature,
  int sessionStatusSignature,
  int sessionTodoSignature,
  ChatState state,
  int threadInteractionSignature,
});

typedef _ComposerSelectionBuildKey = ({
  int agentSignature,
  int favoriteModelCount,
  int messagesVersion,
  String? parentSessionId,
  int permissionRequestCount,
  int providerCatalogSignature,
  String? providersRefreshErrorMessage,
  ChatProvidersRefreshState providersRefreshState,
  int recentModelCount,
  String? selectedAgentName,
  String? selectedModelId,
  String? selectedModelName,
  String? selectedProviderId,
  String? selectedVariantId,
  String selectedVariantLabel,
  String? sessionId,
  int variantSignature,
});

typedef _SessionPanelBuildKey = ({
  bool canLoadMoreSessions,
  String? currentSessionId,
  String projectContextKey,
  int projectSignature,
  bool recoverableSyncAlertEscalated,
  SessionListFilter sessionListFilter,
  SessionListSort sessionListSort,
  String sessionSearchQuery,
  int sessionSignature,
  int sidebarSessionSignature,
  int statusSignature,
  int pinnedSignature,
});

typedef _DesktopUtilityPaneBuildKey = ({
  int childrenSignature,
  int diffSignature,
  bool isCurrentSessionDiffLoaded,
  bool isLoadingSessionInsights,
  String? sessionInsightsError,
  int sessionSignature,
  int sessionStatusSignature,
  int settingsSignature,
  int todoSignature,
});

typedef _FilePaneBuildKey = ({String? sessionId, int diffSignature});

int _foldSignature(int seed, Object? value) => Object.hash(seed, value);

int _chatSessionSignature(ChatSession? session) => session?.hashCode ?? 0;

int _chatSessionListSignature(Iterable<ChatSession> sessions) {
  var signature = 0;
  var count = 0;
  for (final session in sessions) {
    count += 1;
    signature = _foldSignature(signature, session.hashCode);
  }
  return Object.hash(count, signature);
}

int _projectListSignature(Iterable<Project> projects) {
  var signature = 0;
  var count = 0;
  for (final project in projects) {
    count += 1;
    signature = _foldSignature(signature, project.hashCode);
  }
  return Object.hash(count, signature);
}

int _pinnedSessionSignature(Set<String> pinnedSessionIds) {
  final ids = pinnedSessionIds.toList(growable: false)..sort();
  var signature = ids.length;
  for (final id in ids) {
    signature = _foldSignature(signature, id);
  }
  return signature;
}

int _sessionStatusMapSignature(Map<String, SessionStatusInfo> statuses) {
  final ids = statuses.keys.toList(growable: false)..sort();
  var signature = ids.length;
  for (final id in ids) {
    signature = Object.hash(signature, id, statuses[id].hashCode);
  }
  return signature;
}

int _sessionTodoSignature(Iterable<SessionTodo> todos) {
  var signature = 0;
  var count = 0;
  for (final todo in todos) {
    count += 1;
    signature = _foldSignature(signature, todo.hashCode);
  }
  return Object.hash(count, signature);
}

int _sessionDiffSignature(Iterable<SessionDiff> diffs) {
  var signature = 0;
  var count = 0;
  for (final diff in diffs) {
    count += 1;
    signature = _foldSignature(signature, diff.hashCode);
  }
  return Object.hash(count, signature);
}

int _composerProviderCatalogSignature(ChatProvider chatProvider) {
  final selectedProvider = chatProvider.selectedProvider;
  return Object.hash(
    chatProvider.providers.length,
    chatProvider.connectedProviderIds.length,
    selectedProvider?.id,
    selectedProvider?.name,
    selectedProvider?.models.length,
  );
}

int _agentListSignature(Iterable<Agent> agents) {
  var signature = 0;
  var count = 0;
  for (final agent in agents) {
    count += 1;
    signature = _foldSignature(signature, agent.hashCode);
  }
  return Object.hash(count, signature);
}

int _variantListSignature(Iterable<ModelVariant> variants) {
  var signature = 0;
  var count = 0;
  for (final variant in variants) {
    count += 1;
    signature = _foldSignature(signature, variant.hashCode);
  }
  return Object.hash(count, signature);
}

int _quickReplyModelListSignature(ChatProvider chatProvider) {
  var signature = 0;
  var count = 0;
  for (final provider in chatProvider.providers) {
    for (final model in provider.models.values) {
      if (!isUserSelectableModel(
        provider: provider,
        model: model,
        connectedProviderIds: chatProvider.connectedProviderIds,
      )) {
        continue;
      }
      count += 1;
      signature = _foldSignature(
        signature,
        Object.hash(provider.id, provider.name, model.hashCode),
      );
    }
  }
  return Object.hash(count, signature);
}

int _modelAttachmentSignature(Model? model) {
  if (model == null) {
    return 0;
  }
  return Object.hash(model.attachment, model.modalities);
}

int _quickReplySelectionSignature(ChatProvider chatProvider) {
  return Object.hash(
    chatProvider.selectedAgentName,
    chatProvider.selectedProviderId,
    chatProvider.selectedModelId,
    chatProvider.selectedVariantId,
    _agentListSignature(chatProvider.selectableAgents),
    _quickReplyModelListSignature(chatProvider),
    _variantListSignature(chatProvider.availableVariants),
  );
}

int _threadInteractionSignature(ChatProvider chatProvider) {
  var signature = Object.hash(
    chatProvider.isRespondingInteraction,
    chatProvider.currentThreadPermissionRequests.length,
    chatProvider.currentThreadQuestionRequests.length,
  );
  for (final request in chatProvider.currentThreadPermissionRequests) {
    signature = _foldSignature(signature, request.hashCode);
  }
  for (final request in chatProvider.currentThreadQuestionRequests) {
    signature = _foldSignature(signature, request.hashCode);
  }
  return signature;
}

_ChatContentBuildKey _chatContentBuildKey(ChatProvider chatProvider) {
  final currentStatus = chatProvider.currentSessionStatus;
  return (
    sessionSignature: _chatSessionSignature(chatProvider.currentSession),
    messagesVersion: chatProvider.messagesVersion,
    state: chatProvider.state,
    errorMessage: chatProvider.errorMessage,
    isDraftingNewChat: chatProvider.isDraftingNewChat,
    isActivelyResponding: chatProvider.isCurrentSessionActivelyResponding,
    canAbortActiveResponse: chatProvider.canAbortActiveResponse,
    canUndoCurrentSession: chatProvider.canUndoCurrentSession,
    canRedoCurrentSession: chatProvider.canRedoCurrentSession,
    isCompactingContext: chatProvider.isCompactingContext,
    pendingHistoryComposerSyncToken:
        chatProvider.pendingHistoryComposerSyncToken,
    quickReplySelectionSignature: _quickReplySelectionSignature(chatProvider),
    threadInteractionSignature: _threadInteractionSignature(chatProvider),
    sessionStatusSignature: currentStatus.hashCode,
    sessionTodoSignature: _sessionTodoSignature(
      chatProvider.currentSessionTodo,
    ),
    sessionDiffSignature: _sessionDiffSignature(
      chatProvider.currentSessionDiff,
    ),
    isCurrentSessionDiffLoaded: chatProvider.isCurrentSessionDiffLoaded,
    modelAttachmentSignature: _modelAttachmentSignature(
      chatProvider.selectedModel,
    ),
  );
}

_ComposerSelectionBuildKey _composerSelectionBuildKey(
  ChatProvider chatProvider,
) {
  final currentSession = chatProvider.currentSession;
  final selectedModel = chatProvider.selectedModel;
  final isSubConversation = currentSession?.parentId?.trim().isNotEmpty == true;
  return (
    sessionId: currentSession?.id,
    parentSessionId: currentSession?.parentId,
    messagesVersion: isSubConversation ? chatProvider.messagesVersion : 0,
    selectedProviderId: chatProvider.selectedProviderId,
    selectedModelId: chatProvider.selectedModelId,
    selectedModelName: selectedModel?.name,
    selectedVariantId: chatProvider.selectedVariantId,
    selectedVariantLabel: chatProvider.selectedVariantLabel,
    selectedAgentName: chatProvider.selectedAgentName,
    providerCatalogSignature: _composerProviderCatalogSignature(chatProvider),
    agentSignature: _agentListSignature(chatProvider.selectableAgents),
    variantSignature: _variantListSignature(chatProvider.availableVariants),
    recentModelCount: chatProvider.recentModelKeys.length,
    favoriteModelCount: chatProvider.favoriteModelKeys.length,
    permissionRequestCount: chatProvider.currentThreadPermissionRequests.length,
    providersRefreshState: chatProvider.providersRefreshState,
    providersRefreshErrorMessage: chatProvider.providersRefreshErrorMessage,
  );
}

String _scopeIdForProjectSignature(Project project) {
  final path = project.path.trim();
  if (path.isEmpty || path == '/' || path == '-') {
    return project.id;
  }
  return path;
}

int _sessionAttentionSignature(
  ChatProvider chatProvider,
  Iterable<ChatSession> sessions, {
  String? scopeId,
}) {
  var signature = 0;
  var count = 0;
  for (final session in sessions) {
    count += 1;
    final attention = scopeId == null
        ? chatProvider.sessionAttentionFor(session.id)
        : chatProvider.sessionAttentionForScope(session.id, scopeId: scopeId);
    signature = Object.hash(signature, session.id, attention.hashCode);
  }
  return Object.hash(count, signature);
}

_SessionPanelBuildKey _sessionPanelBuildKey(
  ChatProvider chatProvider,
  ProjectProvider projectProvider,
) {
  final openProjects = projectProvider.openProjects;
  final visibleSessions = chatProvider.visibleSessions;
  var sidebarSignature = Object.hash(
    _chatSessionListSignature(visibleSessions),
    _sessionAttentionSignature(chatProvider, visibleSessions),
  );
  for (final project in openProjects) {
    final scopeId = _scopeIdForProjectSignature(project);
    final scopeSessions = chatProvider.visibleSessionsForScopeId(scopeId);
    final recentSessions = chatProvider.recentRootSessionsForScopeId(scopeId);
    sidebarSignature = Object.hash(
      sidebarSignature,
      scopeId,
      chatProvider.hasSnapshotForScopeId(scopeId),
      _chatSessionListSignature(scopeSessions),
      _chatSessionListSignature(recentSessions),
      _sessionAttentionSignature(chatProvider, scopeSessions, scopeId: scopeId),
      _sessionAttentionSignature(
        chatProvider,
        recentSessions,
        scopeId: scopeId,
      ),
    );
  }

  return (
    projectContextKey: projectProvider.contextKey,
    projectSignature: _projectListSignature(openProjects),
    sessionSignature: _chatSessionListSignature(chatProvider.sessions),
    sidebarSessionSignature: sidebarSignature,
    statusSignature: _sessionStatusMapSignature(chatProvider.sessionStatusById),
    pinnedSignature: _pinnedSessionSignature(chatProvider.pinnedSessionIds),
    sessionSearchQuery: chatProvider.sessionSearchQuery,
    sessionListFilter: chatProvider.sessionListFilter,
    sessionListSort: chatProvider.sessionListSort,
    currentSessionId: chatProvider.currentSession?.id,
    canLoadMoreSessions: chatProvider.canLoadMoreSessions,
    recoverableSyncAlertEscalated: chatProvider.isRecoverableSyncAlertEscalated,
  );
}

_DesktopUtilityPaneBuildKey _desktopUtilityPaneBuildKey(
  ChatProvider chatProvider,
  SettingsProvider settingsProvider,
) {
  return (
    sessionSignature: _chatSessionSignature(chatProvider.currentSession),
    sessionStatusSignature: chatProvider.currentSessionStatus.hashCode,
    childrenSignature: _chatSessionListSignature(
      chatProvider.currentSessionChildren,
    ),
    todoSignature: _sessionTodoSignature(chatProvider.currentSessionTodo),
    diffSignature: _sessionDiffSignature(chatProvider.currentSessionDiff),
    isCurrentSessionDiffLoaded: chatProvider.isCurrentSessionDiffLoaded,
    isLoadingSessionInsights: chatProvider.isLoadingSessionInsights,
    sessionInsightsError: chatProvider.sessionInsightsError,
    settingsSignature: settingsProvider.settings.hashCode,
  );
}

_FilePaneBuildKey _filePaneBuildKey(ChatProvider chatProvider) {
  return (
    sessionId: chatProvider.currentSession?.id,
    diffSignature: _sessionDiffSignature(chatProvider.currentSessionDiff),
  );
}

// Moved from chat_page.dart — top-level enums and tour copy helper.
enum _DisplayToggleAction {
  thinkingBubbles,
  toolCallBubbles,
  taskList,
  reviewChanges,
  recentSessions,
  sessionTabs,
  composerTips,
  replayTour,
}

enum _SessionHeaderMenuAction {
  filterActive,
  filterArchived,
  filterAll,
  sortRecent,
  sortOldest,
  sortTitle,
}

enum _HistoryToolbarAction { undo, redo }

enum _CurrentSessionAction {
  rename,
  pinToggle,
  shareToggle,
  copyLink,
  exportMarkdown,
  exportJson,
  viewTasks,
  reviewChanges,
  undo,
  redo,
  compactContext,
}

enum _SessionExportFormat { markdown, json }

enum _PostOnboardingTourPhase { idle, intro, composer }

enum _ScrollOwner {
  none,
  userDrag,
  paginationRestore,
  newMessage,
  streaming,
  returnReveal,
  contentShrinkSnap,
  searchResult,
}

enum _CachedViewportRestoreTarget { none, bottom, latestResponse }

@visibleForTesting
({String title, String description}) postOnboardingSidebarTourCopy({
  required BuildContext context,
  required bool isMobile,
  required bool showConversationPane,
}) {
  if (isMobile) {
    return (
      title: context.l10n.chatOpenSidebar,
      description: context.l10n.chatTourProjectsConversations,
    );
  }
  if (showConversationPane) {
    return (
      title: context.l10n.chatOpenProject,
      description: context.l10n.chatTourSwitchFolders,
    );
  }
  return (
    title: context.l10n.chatSidebarAccess,
    description: context.l10n.chatTourSidebarProjectTools,
  );
}

// _ScrollFollowMode (was at the end of chat_page.dart, line 2646).
enum _ScrollFollowMode { following, pausedByUser, reading }
