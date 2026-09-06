import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/feature_flags.dart';
import '../../core/di/injection_container.dart' as di;
import '../../core/errors/failures.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/path_utils.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/chat_realtime_model.dart';
import '../../data/models/chat_session_model.dart';
import '../../data/models/provider_model.dart';
import '../../data/models/session_lifecycle_model.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/chat_composer_draft.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/experience_settings.dart';
import '../../domain/entities/persisted_session_tabs_state.dart';
import '../../domain/entities/provider.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../domain/entities/session_tab_icon_overrides.dart';
import '../../domain/usecases/abort_chat_session.dart';
import '../../domain/usecases/create_chat_session.dart';
import '../../domain/usecases/delete_chat_session.dart';
import '../../domain/usecases/fork_chat_session.dart';
import '../../domain/usecases/get_agents.dart';
import '../../domain/usecases/get_chat_message.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_chat_sessions.dart';
import '../../domain/usecases/get_providers.dart';
import '../../domain/usecases/get_session_children.dart';
import '../../domain/usecases/get_session_diff.dart';
import '../../domain/usecases/get_session_status.dart';
import '../../domain/usecases/get_session_todo.dart';
import '../../domain/usecases/list_pending_permissions.dart';
import '../../domain/usecases/list_pending_questions.dart';
import '../../domain/usecases/reject_question.dart';
import '../../domain/usecases/reply_permission.dart';
import '../../domain/usecases/reply_question.dart';
import '../../domain/usecases/revert_chat_message.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/share_chat_session.dart';
import '../../domain/usecases/summarize_chat_session.dart';
import '../../domain/usecases/unrevert_chat_messages.dart';
import '../../domain/usecases/unshare_chat_session.dart';
import '../../domain/usecases/update_chat_session.dart';
import '../../domain/usecases/watch_chat_events.dart';
import '../../domain/usecases/watch_global_chat_events.dart';
import '../services/android_background_alert_worker.dart';
import '../services/car_messaging/car_messaging_runtime.dart';
import '../services/cellular_data_saver_service.dart';
import '../services/chat_title_generator.dart';
import '../services/event_feedback_dispatcher.dart';
import '../services/read_aloud_service.dart';
import '../services/session_attention/session_attention_completion_resolver.dart';
import '../services/session_attention/session_attention_coordinator.dart';
import '../services/session_tab_icon_override_store.dart';
import '../services/session_tab_icon_presets.dart';
import '../utils/chat_abort_message.dart';
import '../utils/chat_assistant_settlement.dart';
import '../utils/chat_event_property_extractors.dart';
import '../utils/chat_server_error_formatter.dart';
import '../utils/session_title_formatter.dart';
import 'chat_provider/message_reconciliation.dart';
import 'project_provider.dart';
import 'settings_provider.dart';

part 'chat_provider_draft_part.dart';
part 'chat_provider_types_part.dart';
part 'chat_provider/chat_provider_error_policy.dart';
part 'chat_provider/chat_provider_selection_sync_ops.dart';
part 'chat_provider/chat_provider_context_state_ops.dart';
part 'chat_provider/chat_provider_preference_ops.dart';
part 'chat_provider/chat_provider_realtime_ops.dart';
part 'chat_provider/chat_provider_event_reducer_helpers.dart';
part 'chat_provider/chat_provider_event_reducer_session_ops.dart';
part 'chat_provider/chat_provider_event_reducer_global_ops.dart';
part 'chat_provider/chat_provider_auto_title_ops.dart';
part 'chat_provider/chat_provider_message_merge_ops.dart';
part 'chat_provider/chat_provider_reconciliation_guard.dart';
part 'chat_provider/chat_provider_session_ops.dart';
part 'chat_provider/chat_provider_core.dart';
part 'chat_provider/chat_provider_abort_policy_ops.dart';
part 'chat_provider/chat_provider_selection_helpers.dart';
part 'chat_provider/chat_provider_realtime_aux_ops.dart';
part 'chat_provider/chat_provider_cache_persistence_ops.dart';
part 'chat_provider/chat_provider_message_state_ops.dart';
part 'chat_provider/chat_provider_shortcut_cycle_ops.dart';
part 'chat_provider/chat_provider_history_ops.dart';
part 'chat_provider/chat_provider_session_attention_ops.dart';
part 'chat_provider/chat_provider_session_tab_ops.dart';
part 'chat_provider/chat_provider_target_ops.dart';
part 'chat_provider/chat_provider_lifecycle_ops.dart';

/// What a diff refresh attempt should do to the loaded/error bookkeeping
/// for its target session.
enum _SessionDiffLoadState {
  /// No change to loaded/error state.
  unchanged,

  /// Diff is now confirmed empty for this session.
  loadedEmpty,

  /// Diff is now populated for this session.
  loaded,
}

class _SessionDiffResolution {
  const _SessionDiffResolution({
    required this.diffs,
    required this.applied,
    required this.updatedState,
    required this.error,
    this.appliedIfStillEquals,
  });

  final List<SessionDiff> diffs;
  final bool applied;

  /// When non-null, the caller should only write [diffs] to the store if
  /// the currently stored diff for the session still equals this snapshot.
  /// Used to avoid clobbering a newer concurrent write with a stale empty
  /// result from a long-running exhaustive scan.
  final List<SessionDiff>? appliedIfStillEquals;
  final _SessionDiffLoadState updatedState;
  final String? error;
}

/// Chat provider
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.sendChatMessage,
    this.abortChatSession,
    this.summarizeChatSession,
    required this.getChatSessions,
    required this.createChatSession,
    required this.getChatMessages,
    required this.getChatMessage,
    required this.getAgents,
    required this.getProviders,
    required this.deleteChatSession,
    required this.updateChatSession,
    required this.shareChatSession,
    required this.unshareChatSession,
    required this.forkChatSession,
    required this.getSessionStatus,
    required this.getSessionChildren,
    required this.getSessionTodo,
    required this.getSessionDiff,
    required this.watchChatEvents,
    required this.watchGlobalChatEvents,
    required this.listPendingPermissions,
    required this.replyPermission,
    required this.listPendingQuestions,
    required this.replyQuestion,
    required this.rejectQuestion,
    this.revertChatMessage,
    this.unrevertChatMessages,
    required this.projectProvider,
    required this.localDataSource,
    this.settingsProvider,
    this.dioClient,
    CellularDataSaverService? cellularDataSaverService,
    SessionAttentionCoordinator? sessionAttentionCoordinator,
    SessionAttentionCompletionResolver? sessionAttentionCompletionResolver,
    Future<void> Function(SessionAttentionAggregate aggregate)?
    sessionAttentionAggregatePublisher,
    Future<void> Function(bool isForeground)?
    sessionAttentionAppForegroundPublisher,
    this.eventFeedbackDispatcher,
    this.titleGenerator,
    Duration syncSignalStaleThreshold = const Duration(seconds: 20),
    Duration syncHealthCheckInterval = const Duration(seconds: 5),
    Duration degradedPollingInterval = const Duration(seconds: 30),
    Duration foregroundResumeGracePeriod = kDefaultSyncResumeGracePeriod,
    Duration foregroundResumeSyncIndicatorDuration = const Duration(
      seconds: 12,
    ),
    int foregroundResumeSyncIndicatorMaxCycles = 5,
    int degradedFailureThreshold = 3,
    bool refreshlessRealtimeEnabled = FeatureFlags.refreshlessRealtime,
    Duration abortSuppressionWindow = const Duration(seconds: 8),
    Duration shortcutCycleWindow = const Duration(seconds: 3),
    DateTime Function()? sessionTabsNow,
    SessionTabIconOverrideStore? sessionTabIconOverrideStore,
    Duration sessionTabsPersistenceDebounce = const Duration(milliseconds: 750),
  }) : _sessionTabsPersistenceDebounceDuration =
           sessionTabsPersistenceDebounce {
    _cellularDataSaverService =
        cellularDataSaverService ?? CellularDataSaverService.disabled();
    _ownsSessionAttentionCoordinator = sessionAttentionCoordinator == null;
    _sessionAttentionCoordinator =
        sessionAttentionCoordinator ??
        SessionAttentionCoordinator(
          cellularDataSaverService: _cellularDataSaverService,
        );
    _sessionAttentionCompletionResolver = sessionAttentionCompletionResolver;
    _sessionAttentionAggregatePublisher = sessionAttentionAggregatePublisher;
    _sessionAttentionAppForegroundPublisher =
        sessionAttentionAppForegroundPublisher;
    _syncSignalStaleThreshold = syncSignalStaleThreshold;
    _syncHealthCheckInterval = syncHealthCheckInterval;
    _degradedPollingInterval = degradedPollingInterval;
    _foregroundResumeGracePeriod = clampSyncResumeGracePeriod(
      foregroundResumeGracePeriod,
    );
    _foregroundResumeSyncIndicatorDuration =
        foregroundResumeSyncIndicatorDuration;
    _foregroundResumeSyncIndicatorMaxCycles =
        foregroundResumeSyncIndicatorMaxCycles;
    _degradedFailureThreshold = degradedFailureThreshold;
    _refreshlessRealtimeEnabled = refreshlessRealtimeEnabled;
    _abortSuppressionWindow = abortSuppressionWindow;
    _shortcutCycleWindow = shortcutCycleWindow;
    _sessionTabsNow = sessionTabsNow ?? DateTime.now;
    _sessionTabIconOverrideStore =
        sessionTabIconOverrideStore ??
        SessionTabIconOverrideStore(localDataSource: localDataSource);
    _activeContextKey = _composeContextKey(
      _activeServerId,
      _resolveContextScopeId(),
    );
    _cellularDataSaverService.addListener(_handleCellularDataSaverChanged);
  }

  @visibleForTesting
  bool debugIsOptimisticLocalUserMessageId(String messageId) =>
      _isOptimisticLocalUserMessageId(messageId);

  @visibleForTesting
  bool get debugHasRealtimeEventSubscription => _eventSubscription != null;

  @visibleForTesting
  bool get debugHasGlobalEventSubscription => _globalEventSubscription != null;

  @visibleForTesting
  set debugPendingQuestionsRetryBaseDelay(Duration value) {
    _pendingQuestionsRetryBaseDelay = value;
  }

  @visibleForTesting
  set debugQuestionServerAuthorityGrace(Duration value) {
    _questionServerAuthorityGrace = value;
  }

  @visibleForTesting
  set debugQuestionSubmitFailedRetention(Duration value) {
    _questionSubmitFailedRetention = value;
  }

  @visibleForTesting
  bool debugShouldSkipLocalUserAppendAsDuplicateEcho({
    required UserMessage localMessage,
    required List<ChatMessage> mergedMessages,
  }) {
    return _shouldSkipLocalUserAppendAsDuplicateEcho(
      localMessage: localMessage,
      mergedMessages: mergedMessages,
    );
  }

  void _dismissNotificationsForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return;
    }
    unawaited(eventFeedbackDispatcher?.dismissForSession(normalizedSessionId));
  }

  // Scroll callback
  void Function({required String reason})? _scrollToBottomCallback;

  final SendChatMessage sendChatMessage;
  final AbortChatSession? abortChatSession;
  final SummarizeChatSession? summarizeChatSession;
  final GetChatSessions getChatSessions;
  final CreateChatSession createChatSession;
  final GetChatMessages getChatMessages;
  final GetChatMessage getChatMessage;
  final GetAgents getAgents;
  final GetProviders getProviders;
  final DeleteChatSession deleteChatSession;
  final UpdateChatSession updateChatSession;
  final ShareChatSession shareChatSession;
  final UnshareChatSession unshareChatSession;
  final ForkChatSession forkChatSession;
  final GetSessionStatus getSessionStatus;
  final GetSessionChildren getSessionChildren;
  final GetSessionTodo getSessionTodo;
  final GetSessionDiff getSessionDiff;
  final WatchChatEvents watchChatEvents;
  final WatchGlobalChatEvents watchGlobalChatEvents;
  final ListPendingPermissions listPendingPermissions;
  final ReplyPermission replyPermission;
  final ListPendingQuestions listPendingQuestions;
  final ReplyQuestion replyQuestion;
  final RejectQuestion rejectQuestion;
  final RevertChatMessage? revertChatMessage;
  final UnrevertChatMessages? unrevertChatMessages;
  final ProjectProvider projectProvider;
  final AppLocalDataSource localDataSource;
  final SettingsProvider? settingsProvider;
  final DioClient? dioClient;
  late final CellularDataSaverService _cellularDataSaverService;
  late final SessionAttentionCoordinator _sessionAttentionCoordinator;
  late final SessionAttentionCompletionResolver?
  _sessionAttentionCompletionResolver;
  late final Future<void> Function(SessionAttentionAggregate aggregate)?
  _sessionAttentionAggregatePublisher;
  late final Future<void> Function(bool isForeground)?
  _sessionAttentionAppForegroundPublisher;
  late final bool _ownsSessionAttentionCoordinator;
  final EventFeedbackDispatcher? eventFeedbackDispatcher;
  final ChatTitleGenerator? titleGenerator;

  ChatState _state = ChatState.initial;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  // Monotonic counter bumped on every _messages mutation so the timeline
  // builder can short-circuit its cache check in O(1) instead of computing
  // Object.hashAll over all messages+parts (O(N*M)) on every build.
  int _messagesVersion = 0;
  int _cachedVisibleMessagesVersion = -1;
  String? _cachedVisibleMessagesSessionId;
  String? _cachedVisibleMessagesRevertId;
  String? _cachedVisibleMessagesBranchKey;
  List<ChatMessage> _cachedVisibleMessages = const <ChatMessage>[];
  // Monotonic counter bumped on every mutation that affects the visible
  // current-session permission list so the getter can reuse the same immutable
  // snapshot between rebuilds.
  int _threadPermissionsVersion = 0;
  int _cachedThreadPermissionsAtVersion = -1;
  List<ChatPermissionRequest> _cachedThreadPermissionRequests = const [];
  int _cachedThreadQuestionsAtVersion = -1;
  List<ChatQuestionRequest> _cachedThreadQuestionRequests = const [];
  String? _errorMessage;
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _globalEventSubscription;
  int _eventStreamGeneration = 0;
  Timer? _globalRefreshDebounce;
  final Map<String, Timer> _messageFallbackDebounceById = <String, Timer>{};
  bool _isRespondingInteraction = false;
  final Set<String> _dismissedInteractionTombstones = <String>{};
  Map<String, SessionStatusInfo> _sessionStatusById =
      <String, SessionStatusInfo>{};
  Map<String, List<ChatPermissionRequest>> _pendingPermissionsBySession =
      <String, List<ChatPermissionRequest>>{};
  Map<String, List<ChatQuestionRequest>> _pendingQuestionsBySession =
      <String, List<ChatQuestionRequest>>{};
  // Tracks question submit/dismiss calls that returned an error so the UI can
  // surface a transient "submit failed" state instead of silently dropping the
  // request. Cleared on the next successful reply/reject, a fresh ask event,
  // or an explicit `dismissQuestionSubmitError` call.
  final Set<String> _questionSubmitFailedRequestIds = <String>{};
  // When each failed submit/reject was recorded, so the retry retention in the
  // pending-questions merge stays bounded.
  final Map<String, DateTime> _questionSubmitFailedAtById =
      <String, DateTime>{};
  Duration _questionSubmitFailedRetention = const Duration(seconds: 30);
  // Request IDs the user (or the server via SSE) resolved locally. Kept for a
  // short window so a stale GET /question response that still lists them does
  // not resurrect the card while the server propagates the resolution.
  final Map<String, DateTime> _recentlyResolvedQuestionIds =
      <String, DateTime>{};
  // First time each question request ID was seen locally (SSE or REST). Used
  // by the pending-questions merge to keep questions that just arrived via SSE
  // visible even when the server list has not caught up, while still treating
  // GET /question as authoritative for removal (issue #143).
  final Map<String, DateTime> _questionFirstSeenAtById = <String, DateTime>{};
  Duration _questionServerAuthorityGrace = const Duration(seconds: 15);
  // Monotonic generation so overlapping _loadPendingInteractions calls (rapid
  // session switches, retry timers, degraded polls) cannot apply stale results
  // or results from a previous server/project context.
  int _pendingInteractionsFetchId = 0;
  // Bounded retry for a failed pending-questions fetch: transient failures
  // must not leave pending questions invisible for the rest of the session.
  int _pendingQuestionsRetryAttempts = 0;
  Timer? _pendingQuestionsRetryTimer;
  Duration _pendingQuestionsRetryBaseDelay = const Duration(seconds: 5);
  // Coalesces overlapping pending-interaction loads (same effective scope).
  Future<void>? _pendingInteractionsLoadInFlight;
  bool? _pendingInteractionsLoadVisibleOnly;
  String? _pendingInteractionsLoadContextKey;
  String? _pendingInteractionsLoadSessionId;
  final Set<String> _sessionUnreadCompletionIds = <String>{};
  final Map<String, DateTime> _sessionUnreadCompletionTimestamps =
      <String, DateTime>{};
  final Set<String> _sessionErrorAttentionIds = <String>{};
  final Map<String, DateTime> _sseSettledAtBySessionId = <String, DateTime>{};
  Map<String, List<ChatSession>> _sessionChildrenById =
      <String, List<ChatSession>>{};
  Map<String, List<SessionTodo>> _sessionTodoById =
      <String, List<SessionTodo>>{};
  Map<String, List<SessionDiff>> _sessionDiffById =
      <String, List<SessionDiff>>{};
  // Tracks whether the diff for a given session has been loaded at least once
  // since the last context switch. Used by the Review Changes UI to distinguish
  // "no data yet" from "loaded with zero changed files" so the user no longer
  // sees a misleading empty state while the REST refresh is in flight.
  final Set<String> _sessionDiffLoadedById = <String>{};
  // Last error message emitted by the diff request, or null on success.
  // Latched per session; cleared on next successful diff load.
  final Map<String, String> _sessionDiffErrorById = <String, String>{};
  String _sessionSearchQuery = '';
  SessionListFilter _sessionListFilter = SessionListFilter.active;
  SessionListSort _sessionListSort = SessionListSort.recent;
  int _sessionVisibleLimit = 40;
  bool _isLoadingSessionInsights = false;
  String? _sessionInsightsError;
  final Set<String> _pendingLocalUserMessageIds = <String>{};
  int _localMessageIdSequence = 0;
  Future<void>? _activeSessionRefreshTask;
  String? _activeSessionRefreshSessionId;
  Future<void>? _foregroundResumeTask;
  bool _isLoadingOlderMessages = false;
  bool _hasMoreOldMessages = false;
  // Tracks an existing selected session whose timeline is still hydrating.
  String? _pendingCurrentSessionHydrationId;
  bool _isAbortingResponse = false;
  bool _isCompactingContext = false;
  bool _isAppInForeground = true;
  bool _isSessionAttentionAppInForeground = true;
  bool _isChatRouteActive = true;
  String? _abortSuppressionSessionId;
  DateTime? _abortSuppressionStartedAt;
  ChatUiNotice? _pendingUiNotice;
  int _messageStreamGeneration = 0;
  String? _activeMessageStreamSessionId;
  String? _preserveBusyStatusOnNextStreamDoneSessionId;
  ChatComposerDraft? _activeSendDraft;
  bool _isNewChatDraftActive = false;
  int _newChatDraftGeneration = 0;
  Future<void>? _lazySessionBootstrapTask;
  final Map<String, Future<void>> _currentSessionIdWriteQueueByScope =
      <String, Future<void>>{};
  _RejectedDraftEnvelope? _rejectedDraft;
  _HistoryComposerSync? _pendingHistoryComposerSync;
  _PendingReplacementBranch? _pendingReplacementBranch;
  int _historyComposerSyncToken = 0;
  bool _historyRevertInFlight = false;
  final LinkedHashMap<String, List<ChatMessage>> _sessionMessagesLruCache =
      LinkedHashMap<String, List<ChatMessage>>();
  // Issue #177: in-memory mirror of the persisted per-scope snapshot-ids
  // LRU, so the touch path below doesn't re-read/rewrite the ids JSON on
  // every snapshot write. Keyed by `serverId::scopeId`.
  final Map<String, List<String>> _persistedSnapshotIdsByScope =
      <String, List<String>>{};
  final Map<String, _SessionMessagesSnapshotWriteRequest>
  _pendingSessionMessagesSnapshotWrites =
      <String, _SessionMessagesSnapshotWriteRequest>{};
  final Map<String, Future<void>> _sessionMessagesSnapshotWriteTasks =
      <String, Future<void>>{};
  Future<void>? _lastSessionSnapshotWriteTask;
  _LastSessionSnapshotWriteRequest? _pendingLastSessionSnapshotWrite;
  List<SessionTabRecord> _sessionTabs = const <SessionTabRecord>[];
  PersistedSessionTabsState _sessionTabsPersistedState =
      const PersistedSessionTabsState();
  String? _sessionTabsPersistedStateEncoded;
  List<SessionTabCandidate>? _lastSessionTabReconcileCandidates;
  bool _sessionTabReconcilePresentationDirty = true;
  final Set<Completer<bool?>> _sessionTabAuthorityWaiters =
      <Completer<bool?>>{};
  final Map<String, Future<void>> _sessionTabsWriteQueueByServer =
      <String, Future<void>>{};
  final Duration _sessionTabsPersistenceDebounceDuration;
  final Map<String, String> _sessionTabsPendingPayloadByServer =
      <String, String>{};
  final Map<String, Timer> _sessionTabsPersistenceDebounceByServer =
      <String, Timer>{};
  final Map<String, int> _sessionTabsPersistenceGenerationByServer =
      <String, int>{};
  late final SessionTabIconOverrideStore _sessionTabIconOverrideStore;
  final Map<String, Map<SessionTabIdentity, SessionTabIconOverride>>
  _sessionTabIconOverridesByServer =
      <String, Map<SessionTabIdentity, SessionTabIconOverride>>{};
  final Set<String> _recentlyClosedProjectScopes = <String>{};
  final Map<String, Future<void>> _pinnedSessionWriteQueueByScope =
      <String, Future<void>>{};
  final Map<String, Map<String, Set<String>>> _pinnedSessionIdsByServerScope =
      <String, Map<String, Set<String>>>{};
  final Map<SessionTabIdentity, SessionTabCandidate>
  _sessionTabEventCandidates = <SessionTabIdentity, SessionTabCandidate>{};
  final Map<SessionTabIdentity, String> _sessionTabErrorTokens =
      <SessionTabIdentity, String>{};
  final Map<SessionTabIdentity, String> _sessionTabCompletionTokens =
      <SessionTabIdentity, String>{};
  String? _sessionTabBootstrapDirectory;
  int _sessionTabBootstrapGeneration = 0;
  String? _sessionTabsLoadedServerId;
  int _sessionTabsGeneration = 0;
  bool _sessionTabsDisposed = false;

  // Project and provider-related state
  String? _currentProjectId;
  List<Provider> _providers = [];
  Map<String, String> _defaultModels = {};
  List<String> _connectedProviderIds = <String>[];
  List<Agent> _agents = <Agent>[];
  _CatalogAuthority _providerCatalogAuthority = _CatalogAuthority.unknown;
  _CatalogAuthority _agentCatalogAuthority = _CatalogAuthority.unknown;
  int? _providerCatalogFetchedAtEpochMs;
  int? _agentCatalogFetchedAtEpochMs;
  ChatProvidersRefreshState _providersRefreshState =
      ChatProvidersRefreshState.idle;
  String? _providersRefreshErrorMessage;
  Future<void>? _providersRefreshTask;
  String? _selectedProviderId;
  String? _selectedModelId;
  String? _selectedAgentName;
  String? _selectedVariantId;
  List<String> _recentModelKeys = <String>[];
  List<String> _recentAgentNames = <String>[];
  Map<String, List<String>> _recentVariantValuesByModel =
      <String, List<String>>{};
  List<String> _favoriteModelKeys = <String>[];
  Set<String> _pinnedSessionIds = <String>{};
  String? _loadedPinnedSessionContextKey;
  final Map<String, int> _pinnedSessionMutationRevisionByContext =
      <String, int>{};
  bool _hasLoadedSessionsAuthoritatively = false;
  Map<String, int> _modelUsageCounts = <String, int>{};
  Map<String, String> _selectedVariantByModel = <String, String>{};
  Map<String, _AgentSelectionMemory> _agentSelectionMemoryByAgent =
      <String, _AgentSelectionMemory>{};
  String _activeServerId = 'legacy';
  int _providersFetchId = 0;
  int _sessionsFetchId = 0;
  int _sessionSelectionGeneration = 0;
  int _messagesFetchId = 0;
  String? _lastSyncedRemoteModelKey;
  String? _lastSyncedRemoteAgentName;
  String? _lastSyncedRemoteVariantKey;
  String? _lastSyncedRemoteSessionOverridesSignature;
  bool _pendingRemoteSelectionSync = false;
  DateTime? _pendingRemoteSelectionSyncSince;
  DateTime? _lastRemoteSelectionSyncAt;
  bool _remoteSelectionSyncInFlight = false;
  int _remoteSelectionSyncGeneration = 0;
  _SelectionSyncTransactionPhase _selectionSyncTransactionPhase =
      _SelectionSyncTransactionPhase.idle;
  Future<void> _selectionSyncTransactionQueue = Future<void>.value();
  Future<void>? _selectionPersistenceTask;
  bool _selectionPersistenceDirty = false;
  bool _selectionPersistenceSyncRemote = false;

  /// Origin captured at schedule time. The debounced/mid-switch flush must
  /// persist under the scheduling scope: capturing at flush time would pick
  /// up the next project's scope/directory when the 300ms debounce (or a
  /// slow write) straddles a project switch. Selection VALUES are re-read
  /// fresh at flush (see applyingOrigin) so newer direct mutations are never
  /// overwritten by older scheduled state.
  _SelectionPersistenceOrigin? _scheduledSelectionOrigin;
  Timer? _selectionPersistenceDebounce;
  int _selectionPersistenceGeneration = 0;
  String _activeContextKey = 'legacy::default';
  final Map<String, _ChatContextSnapshot> _contextSnapshots =
      <String, _ChatContextSnapshot>{};
  final String _sessionAttentionGeneration = DateTime.now()
      .microsecondsSinceEpoch
      .toString();
  int _sessionAttentionRevision = 0;
  final Map<SessionAttentionIdentity, String>
  _sessionAttentionObservationFingerprintByIdentity =
      <SessionAttentionIdentity, String>{};
  final Map<String, _SessionSelectionOverride> _sessionSelectionOverridesByKey =
      <String, _SessionSelectionOverride>{};
  final Set<String> _dirtyContextKeys = <String>{};
  Timer? _syncHealthTimer;
  Timer? _degradedPollingTimer;
  Timer? _resumeGraceTimer;
  Timer? _foregroundResumeSyncTimer;
  Timer? _sessionUnreadHighlightTimer;
  bool _idleRealtimePausedForDataSaver = false;
  int _foregroundResumeSyncCycleCount = 0;
  DateTime? _lastRealtimeSignalAt;
  ChatSyncState _syncState = ChatSyncState.reconnecting;
  bool _isForegroundActive = true;

  /// Whether the provider is treating the app as foreground-active
  /// (render gate open, sync monitors running). Used by window-event
  /// throttles that must never suppress the background→foreground
  /// transition (issue #176).
  bool get isForegroundActive => _isForegroundActive;

  bool _degradedMode = false;
  bool _isInResumeGrace = false;
  bool _isForegroundResumeSyncing = false;
  bool _foregroundResumeReconcileInFlight = false;
  final Map<String, DateTime> _lastAutomaticSessionInsightsAtBySessionId =
      <String, DateTime>{};
  bool _realtimeSubscriptionRestartInFlight = false;
  bool _realtimeSubscriptionRestartQueued = false;
  bool _recoverableSyncAlertEscalated = false;
  DateTime? _degradedModeStartedAt;
  int _consecutiveRealtimeFailures = 0;
  bool _postReconnectRecoveryInFlight = false;
  bool _wasDegradedModeBeforeBackground = false;
  bool _pendingRefreshSessions = false;
  bool _pendingRefreshStatus = false;
  bool _pendingRefreshActiveSession = false;
  Future<void>? _currentContextRefreshTask;
  String _pendingCurrentContextRefreshReason = 'unspecified';
  bool _featureFlagLogged = false;
  final Map<String, String> _pendingRenameTitleBySessionId = <String, String>{};
  final Set<String> _autoTitleConsolidatedSessionIds = <String>{};
  final Map<String, String> _autoTitleLastSignatureBySessionId =
      <String, String>{};
  final Set<String> _autoTitleInFlightSessionIds = <String>{};
  final Set<String> _autoTitleQueuedSessionIds = <String>{};
  late final Duration _syncSignalStaleThreshold;
  late final Duration _syncHealthCheckInterval;
  late final Duration _degradedPollingInterval;
  late final Duration _foregroundResumeGracePeriod;
  late final Duration _foregroundResumeSyncIndicatorDuration;
  late final int _foregroundResumeSyncIndicatorMaxCycles;
  late final int _degradedFailureThreshold;
  late final bool _refreshlessRealtimeEnabled;
  late final Duration _shortcutCycleWindow;
  late final DateTime Function() _sessionTabsNow;
  final Map<_ShortcutCycleDomain, _ShortcutCycleState>
  _shortcutCycleStateByDomain = <_ShortcutCycleDomain, _ShortcutCycleState>{};

  // Circular buffer of recent event dedup keys to prevent the global stream
  // from re-processing events already handled by the session stream.
  final Queue<String> _recentEventIds = Queue<String>();
  static const int _maxRecentEventIds = 256;
  final Queue<String> _recentRemovedMessageKeys = Queue<String>();
  final Set<String> _recentRemovedMessageKeySet = <String>{};
  final Queue<String> _recentRemovedPartKeys = Queue<String>();
  final Set<String> _recentRemovedPartKeySet = <String>{};
  static const int _maxRecentRemovalKeys = 256;
  final Set<String> _dedupeNextDeltaFieldKeys = <String>{};
  final Map<String, int> _messageLocalDeltaVersionById = <String, int>{};
  static const int _maxMessageLocalDeltaVersions = 200;

  static const Duration _sessionsCacheTtl = Duration(days: 3);
  static const Duration _lastSessionSnapshotTtl = Duration(days: 7);
  static const Duration _sessionMessagesSnapshotTtl = Duration(days: 7);

  /// Issue #177: cap retained per-context snapshots. Each entry holds a
  /// full message list; without a bound, opening many projects retains
  /// them all. Evicted contexts restore from the server through the
  /// existing snapshot-miss path; contexts holding unsent drafts or an
  /// actively-responding session are never evicted.
  static const int _maxRetainedContextSnapshots = 8;
  static const int _maxSessionMessageCacheEntries = 20;
  static const int _maxPersistedSessionMessageSnapshots = 8;
  // Issue #160: cold open loads only the newest window of messages; older
  // history is pulled in fixed chunks when the user scrolls toward the top.
  static const int _initialMessagesWindowSize = 50;
  // Sentinel probe asks for one extra message so an exact-fit response proves
  // no older history exists without a second roundtrip.
  static const int _initialMessagesWindowProbeSize =
      _initialMessagesWindowSize + 1;
  // Delta-like SWR revalidation keeps a wider reconciliation tail than the
  // pagination chunk (BEHAVIOR.md "Active session SWR prefers delta-like
  // refresh"); shrinking it would change overlap/fallback semantics.
  static const int _swrMessageTailLimit = 200;
  static const int _defaultOlderMessagesChunkSize = 50;
  // Safety valve applied after unbounded correctness-recovery fetches so a
  // full-history fallback cannot inflate the resident list indefinitely.
  static const int _maxResidentLoadedMessages = 500;
  static const int _maxRecentModels = 8;
  static const int _maxRecentAgents = 8;
  static const int _maxRecentVariantsPerModel = 8;
  late final Duration _abortSuppressionWindow;
  static const Duration _remoteSelectionSyncThrottle = Duration(seconds: 2);
  static const String _configCodewalkNamespace = 'codewalk';
  static const String _configSelectionKey = 'selection';
  static const String _configVariantByAgentAndModelKey =
      'variantByAgentAndModel';
  static const String _configVariantByModelKey = 'variantByModel';
  static const String _configSessionSelectionsKey = 'sessionSelections';
  static const String _configSyncAgentName = '__codewalk';
  static const String _remoteAutoVariantValue = '__auto__';
  static const String _remoteAbortNoticeMessage = kChatAbortNoticeMessage;
  static const String _remoteAbortInlineErrorName = 'MessageAborted';
  static const String _optimisticLocalUserMessageIdPrefix = 'local_user_';
  static const String _traceFinalPrefix = 'CW_TRACE_FINAL';
  // ADR-023: upstream SessionSummary.diff returns [] when messageID is omitted,
  // so any unscoped /session/{id}/diff call reports an empty list. Cap the
  // user-initiated exhaustive scan to this many recent user turns.
  static const int _reviewChangesExhaustiveScanCap = 25;

  // Microtask coalescing: multiple calls within the same microtask frame
  // result in a single notifyListeners() invocation, reducing rebuild storms
  // during streaming (where 5+ event types fire per tick).
  bool _notifyScheduled = false;
  final Set<String> _pendingNotifyReasons = <String>{};
  Timer? _deltaNotifyDebounce;
  Timer? _sessionAttentionPublishDebounce;
  Timer? _sessionAttentionThresholdTimer;
  bool _deltaNotifyPending = false;

  /// Issue #176: desktop rasterizes wider viewports with more panes, so the
  /// streaming batch window is longer there (mobile keeps 16ms ≈ 1 frame).
  Duration get _realtimeNotifyBatchDuration {
    if (kIsWeb) {
      return const Duration(milliseconds: 16);
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => const Duration(milliseconds: 64),
      _ => const Duration(milliseconds: 16),
    };
  }

  // Render gate: suppress UI rebuilds while app is in background.
  // SSE data keeps accumulating in internal fields, but widgets won't rebuild
  // until the app returns to foreground and flushes the pending notification.
  bool _hasPendingRenderFlush = false;

  void _notifyListeners({String reason = 'chat_provider'}) {
    if (_sessionTabsDisposed) {
      return;
    }
    _scheduleSessionAttentionPublish();
    if (!_isForegroundActive) {
      if (AppLogger.performanceLoggingEnabled) {
        _pendingNotifyReasons.add(reason);
      }
      _hasPendingRenderFlush = true;
      return;
    }
    if (AppLogger.performanceLoggingEnabled) {
      _pendingNotifyReasons.add(reason);
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_sessionTabsDisposed) {
        _pendingNotifyReasons.clear();
        return;
      }
      if (!AppLogger.performanceLoggingEnabled) {
        _pendingNotifyReasons.clear();
        notifyListeners();
        return;
      }
      final notifyReasons = _pendingNotifyReasons.toList(growable: false)
        ..sort();
      _pendingNotifyReasons.clear();
      final stopwatch = Stopwatch()..start();
      try {
        notifyListeners();
        stopwatch.stop();
        AppLogger.recordPerformanceTask(
          operation: 'chat_notify_listeners',
          elapsed: stopwatch.elapsed,
          status: 'ok',
          tags: const <String>{'chat:notify', 'ui:rebuild'},
          context: <String, Object?>{
            'reasons': notifyReasons,
            'sessionCount': _sessions.length,
            'messageCount': _messages.length,
          },
        );
      } catch (error, stackTrace) {
        stopwatch.stop();
        AppLogger.recordPerformanceTask(
          operation: 'chat_notify_listeners',
          elapsed: stopwatch.elapsed,
          status: 'error',
          tags: const <String>{'chat:notify', 'ui:rebuild'},
          context: <String, Object?>{
            'reasons': notifyReasons,
            'sessionCount': _sessions.length,
            'messageCount': _messages.length,
          },
          error: error,
          stackTrace: stackTrace,
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  void _scheduleSessionAttentionPublish() {
    final publisher = _sessionAttentionAggregatePublisher;
    if (publisher == null) return;
    _sessionAttentionPublishDebounce?.cancel();
    _sessionAttentionPublishDebounce = Timer(
      const Duration(milliseconds: 100),
      () {
        final aggregate = rootSessionAttentionAggregate();
        _scheduleSessionAttentionThreshold(aggregate);
        unawaited(
          publisher(aggregate).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            AppLogger.warn(
              'Failed to publish live session attention aggregate',
              error: error,
              stackTrace: stackTrace,
            );
          }),
        );
      },
    );
  }

  void _scheduleSessionAttentionThreshold(SessionAttentionAggregate aggregate) {
    _sessionAttentionThresholdTimer?.cancel();
    Duration? shortestRemaining;
    for (final candidate in aggregate.candidates) {
      if (candidate.monitoringPaused ||
          (candidate.kind != RootSessionAttentionKind.active &&
              candidate.kind != RootSessionAttentionKind.receiving)) {
        continue;
      }
      final remaining =
          _sessionAttentionCoordinator.delayedThreshold -
          candidate.observableBusyElapsed;
      if (remaining <= Duration.zero) continue;
      if (shortestRemaining == null || remaining < shortestRemaining) {
        shortestRemaining = remaining;
      }
    }
    if (shortestRemaining != null) {
      _sessionAttentionThresholdTimer = Timer(
        shortestRemaining,
        _scheduleSessionAttentionPublish,
      );
    }
  }

  void _scheduleDeltaNotification({String reason = 'message.part.delta'}) {
    _scheduleRealtimeNotification(reason: reason);
  }

  /// Coalesces high-frequency realtime notifications (streaming deltas,
  /// session/tool/todo updates) into at most one [notifyListeners] per
  /// batch window. Terminal signals (idle/error/permission/session switch)
  /// must bypass this via [_notifyListeners] + [_flushDeltaNotification].
  void _scheduleRealtimeNotification({
    String reason = 'message.part.delta',
  }) {
    if (!_isForegroundActive) {
      _notifyListeners(reason: reason);
      return;
    }
    if (AppLogger.performanceLoggingEnabled) {
      _pendingNotifyReasons.add(reason);
    }
    _deltaNotifyPending = true;
    if (_deltaNotifyDebounce?.isActive == true) {
      return;
    }
    _deltaNotifyDebounce = Timer(_realtimeNotifyBatchDuration, () {
      _deltaNotifyDebounce = null;
      if (!_deltaNotifyPending) {
        return;
      }
      _deltaNotifyPending = false;
      _notifyListeners(reason: 'message.part.delta.batch');
    });
  }

  void _flushDeltaNotification({String reason = 'message.part.delta.flush'}) {
    final hadPending = _deltaNotifyPending;
    _deltaNotifyDebounce?.cancel();
    _deltaNotifyDebounce = null;
    _deltaNotifyPending = false;
    if (hadPending) {
      _notifyListeners(reason: reason);
    }
  }

  bool get _hasPendingThreadInteractions {
    for (final items in _pendingPermissionsBySession.values) {
      if (items.isNotEmpty) {
        return true;
      }
    }
    for (final items in _pendingQuestionsBySession.values) {
      if (items.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get _hasVisibleAggressiveDataSaverSession {
    final sessionId = _currentSession?.id.trim();
    return _cellularDataSaverService.isAggressiveDataSaverActive &&
        _isForegroundActive &&
        _isChatRouteActive &&
        sessionId != null &&
        sessionId.isNotEmpty;
  }

  bool _isVisibleAggressiveSessionId(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    final currentSessionId = _currentSession?.id.trim();
    if (normalizedSessionId == null ||
        normalizedSessionId.isEmpty ||
        currentSessionId == null ||
        currentSessionId.isEmpty) {
      return false;
    }
    if (normalizedSessionId == currentSessionId) {
      return true;
    }
    final parentId = _sessionById(normalizedSessionId)?.parentId?.trim();
    return parentId != null &&
        parentId.isNotEmpty &&
        parentId == currentSessionId;
  }

  bool get _hasPendingVisibleAggressiveThreadInteractions {
    for (final entry in _pendingPermissionsBySession.entries) {
      if (_isVisibleAggressiveSessionId(entry.key) && entry.value.isNotEmpty) {
        return true;
      }
    }
    for (final entry in _pendingQuestionsBySession.entries) {
      if (_isVisibleAggressiveSessionId(entry.key) && entry.value.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get _shouldKeepRealtimeActiveForDataSaver {
    if (!_refreshlessRealtimeEnabled ||
        !_cellularDataSaverService.isDataSaverActive) {
      return true;
    }
    if (!_isForegroundActive) {
      return false;
    }
    if (_cellularDataSaverService.isAggressiveDataSaverActive) {
      if (!_hasVisibleAggressiveDataSaverSession) {
        return false;
      }
      if (_cellularDataSaverService.hasInteractiveBurst) {
        return true;
      }
      if (_state == ChatState.sending || isCurrentSessionActivelyResponding) {
        return true;
      }
      return _hasPendingVisibleAggressiveThreadInteractions;
    }
    if (_cellularDataSaverService.hasInteractiveBurst) {
      return true;
    }
    if (_state == ChatState.sending || isCurrentSessionActivelyResponding) {
      return true;
    }
    return _hasPendingThreadInteractions;
  }

  bool get _isAggressiveDataSaverActive =>
      _cellularDataSaverService.isAggressiveDataSaverActive;

  Duration get _effectiveSyncSignalStaleThreshold =>
      _isAggressiveDataSaverActive
      ? CellularDataSaverService.aggressiveSyncSignalStaleThreshold
      : _syncSignalStaleThreshold;

  Duration get _effectiveDegradedPollingInterval => _isAggressiveDataSaverActive
      ? CellularDataSaverService.aggressiveDegradedPollingInterval
      : _degradedPollingInterval;

  void _handleCellularDataSaverChanged() {
    if (!_refreshlessRealtimeEnabled) {
      return;
    }
    // Invalidate any pending-interactions load in flight: the effective
    // interaction scope changed with the data saver level, so applying the
    // older result could populate all-session state right after aggressive
    // mode activated.
    _invalidatePendingInteractionsLoads();
    if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
      _globalRefreshDebounce?.cancel();
      _globalRefreshDebounce = null;
      _pendingRefreshSessions = false;
      _pendingRefreshStatus = false;
      _pendingRefreshActiveSession = false;
      _syncHealthTimer?.cancel();
      _syncHealthTimer = null;
      _degradedPollingTimer?.cancel();
      _degradedPollingTimer = null;
      _degradedMode = false;
      _degradedModeStartedAt = null;
    } else if (_isForegroundActive) {
      _startSyncHealthMonitor();
    }
    unawaited(_syncCellularDataSaverRealtimePolicy(reason: 'runtime-change'));
    _notifyListeners();
  }

  // Microtask coalescing for scroll-to-bottom: prevents multiple scroll jumps
  // per frame when several events trigger scroll simultaneously.
  bool _scrollScheduled = false;

  void _scheduleScrollToBottom({String reason = 'provider'}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    scheduleMicrotask(() {
      _scrollScheduled = false;
      _scrollToBottomCallback?.call(reason: reason);
    });
  }

  /// True when [sessionId] belongs to a subagent, i.e. it has a parent.
  bool _isChildSessionId(String? sessionId) {
    final normalized = sessionId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    final parentId = _sessionById(normalized)?.parentId?.trim();
    return parentId != null && parentId.isNotEmpty;
  }

  bool _shouldSchedulePassiveAutoScrollForSession(
    String sessionId, {
    ChatMessage? latestMessage,
  }) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty || _isCompactingContext) {
      return false;
    }
    // Subagent traffic must never take ownership of the main timeline's
    // scroll: only the session actually on screen may move the anchor.
    if (normalizedSessionId != _currentSession?.id.trim()) {
      return false;
    }
    final status = _sessionStatusById[normalizedSessionId]?.type;
    if (status != SessionStatusType.busy && status != SessionStatusType.retry) {
      return true;
    }

    var candidate = latestMessage;
    if (candidate == null) {
      for (var index = _messages.length - 1; index >= 0; index -= 1) {
        final message = _messages[index];
        if (message.sessionId == normalizedSessionId) {
          candidate = message;
          break;
        }
      }
    }
    if (candidate is! AssistantMessage) {
      return false;
    }

    final hasTextPart = candidate.parts.any(
      (part) => part is TextPart && part.text.trim().isNotEmpty,
    );
    return hasTextPart;
  }

  void _traceFinal(String event, {String? sessionId, String? details}) {
    final currentSessionId = _currentSession?.id;
    final normalizedSessionId = (sessionId ?? currentSessionId ?? '-').trim();
    final effectiveSessionId = normalizedSessionId.isEmpty
        ? '-'
        : normalizedSessionId;
    final statusLabel =
        _sessionStatusById[effectiveSessionId]?.type.name ?? '-';
    final abortSuppressed =
        effectiveSessionId == '-' ||
            _abortSuppressionSessionId != effectiveSessionId ||
            _abortSuppressionStartedAt == null
        ? false
        : DateTime.now().difference(_abortSuppressionStartedAt!) <=
              _abortSuppressionWindow;
    final lastMessage = _messages.isEmpty ? '-' : _messages.last.id;
    final suffix = details == null || details.trim().isEmpty
        ? ''
        : ' details=${details.trim()}';

    AppLogger.info(
      '$_traceFinalPrefix provider event=$event session=$effectiveSessionId current=${currentSessionId ?? "-"} state=${_state.name} status=$statusLabel activeStream=${_activeMessageStreamSessionId ?? "-"} hasSub=${_messageSubscription != null} abortSuppressed=$abortSuppressed messages=${_messages.length} last=$lastMessage$suffix',
    );
  }

  // Getters
  ChatState get state => _state;
  List<ChatSession> get sessions => _sessions;
  bool get hasLoadedSessionsAuthoritatively =>
      _hasLoadedSessionsAuthoritatively;
  String get sessionSearchQuery => _sessionSearchQuery;
  SessionListFilter get sessionListFilter => _sessionListFilter;
  SessionListSort get sessionListSort => _sessionListSort;
  bool get isLoadingSessionInsights => _isLoadingSessionInsights;
  String? get sessionInsightsError => _sessionInsightsError;
  ChatSession? get currentSession => _currentSession;
  List<SessionTabRecord> get sessionTabs {
    if (_sessionTabsLoadedServerId != _activeServerId) {
      return const <SessionTabRecord>[];
    }
    return _sessionTabs;
  }

  List<ChatMessage> get messages => _visibleMessagesForCurrentSession();
  List<ChatMessage> get rawMessages =>
      List<ChatMessage>.unmodifiable(_messages);
  List<ChatMessage>? cachedMessagesForSession(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return null;
    }
    if (_currentSession?.id == normalizedSessionId) {
      return List<ChatMessage>.unmodifiable(rawMessages);
    }
    return _cachedSessionMessages(normalizedSessionId);
  }

  int get messagesVersion => _messagesVersion;
  String? get errorMessage => _errorMessage;
  ChatUiNotice? get pendingUiNotice => _pendingUiNotice;
  String? get currentProjectId => _currentProjectId;
  List<Provider> get providers => _providers;
  List<String> get connectedProviderIds =>
      List<String>.unmodifiable(_connectedProviderIds);
  Map<String, String> get defaultModels => _defaultModels;
  List<Agent> get agents => List<Agent>.unmodifiable(_agents);
  List<Agent> get selectableAgents =>
      List<Agent>.unmodifiable(_sortedSelectableAgents(_agents));
  String? get selectedAgentName => _selectedAgentName;
  String get selectedAgentLabel => _selectedAgentName == null
      ? (L10nBridge.current?.chatChooseAgent ?? 'Select agent')
      : _selectedAgentName!;
  String? get selectedProviderId => _selectedProviderId;
  String? get selectedModelId => _selectedModelId;
  String? get selectedVariantId => _selectedVariantId;
  List<String> get recentModelKeys =>
      List<String>.unmodifiable(_recentModelKeys);
  List<String> get favoriteModelKeys =>
      List<String>.unmodifiable(_favoriteModelKeys);
  Set<String> get pinnedSessionIds => UnmodifiableSetView(_pinnedSessionIds);
  Map<String, int> get modelUsageCounts =>
      Map<String, int>.unmodifiable(_modelUsageCounts);
  String get activeServerId => _activeServerId;
  bool get isRespondingInteraction => _isRespondingInteraction;

  Future<void> loadSessionTabs() async {
    final serverId = await _resolveServerScopeId();
    await _ensureSessionTabsLoaded(serverId: serverId);
  }

  void closeSessionTab(SessionTabIdentity identity) {
    _closeSessionTab(identity);
  }

  String? sessionTabIconPresetId(SessionTabIdentity identity) {
    return _sessionTabIconOverridesByServer[identity.serverId]?[identity]
        ?.presetId;
  }

  Future<bool> setSessionTabIconPreset(
    SessionTabIdentity identity,
    String? presetId,
  ) {
    return _setSessionTabIconPreset(identity, presetId);
  }

  bool restoreClosedSessionTab(SessionTabRecord tab, {required int index}) {
    return _restoreClosedSessionTab(tab, index: index);
  }

  Future<void> removeSessionTabsForDirectory(
    String directory, {
    String? serverId,
  }) async {
    final normalizedDirectory = normalizeOptionalFilePath(directory);
    if (normalizedDirectory == null) return;
    final targetServerId = serverId?.trim().isNotEmpty ?? false
        ? serverId!.trim()
        : await _resolveServerScopeId();
    await _removeSessionTabsForDirectoryAsync(
      serverId: targetServerId,
      directory: normalizedDirectory,
    );
  }

  @Deprecated('Use removeSessionTabsForDirectory')
  Future<void> removeSessionTabsForProjectHistory(
    String directory, {
    String? serverId,
  }) =>
      removeSessionTabsForDirectory(directory, serverId: serverId);

  @visibleForTesting
  Future<void> debugWaitForSessionTabPersistence() async {
    for (final serverId in _sessionTabsPendingPayloadByServer.keys.toList(
      growable: false,
    )) {
      await flushSessionTabsPersistence(serverId);
    }
    await Future.wait(<Future<void>>[
      ..._sessionTabsWriteQueueByServer.values,
      ..._pinnedSessionWriteQueueByScope.values,
    ]);
    await _sessionTabIconOverrideStore.drain();
  }

  @visibleForTesting
  void debugStoreCurrentContextSnapshot() {
    _storeCurrentContextSnapshot();
  }

  /// Request IDs whose last submit/dismiss attempt returned an error.
  /// The UI can show a transient retry affordance for these requests.
  Set<String> get questionSubmitFailedRequestIds =>
      Set<String>.unmodifiable(_questionSubmitFailedRequestIds);

  void dismissQuestionSubmitError(String requestId) {
    if (_questionSubmitFailedRequestIds.remove(requestId)) {
      _questionSubmitFailedAtById.remove(requestId);
      _threadPermissionsVersion++;
      notifyListeners();
    }
  }

  ChatProvidersRefreshState get providersRefreshState => _providersRefreshState;
  String? get providersRefreshErrorMessage => _providersRefreshErrorMessage;
  bool get isProvidersRefreshInProgress =>
      _providersRefreshState == ChatProvidersRefreshState.loading;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  bool get hasMoreOldMessages => _hasMoreOldMessages;
  bool get isDraftingNewChat => _isNewChatDraftActive;
  bool get isCurrentSessionHydrating =>
      _pendingCurrentSessionHydrationId != null &&
      _pendingCurrentSessionHydrationId == _currentSession?.id;
  SessionRevert? get currentSessionRevert => _currentSession?.revert;
  int get pendingHistoryComposerSyncToken =>
      _pendingHistoryComposerSync?.token ?? 0;

  @visibleForTesting
  ChatComposerDraft? get debugPendingHistoryComposerDraft =>
      _pendingHistoryComposerSync?.draft;

  List<ChatMessage> _visibleMessagesForCurrentSession() {
    final session = _currentSession;
    final revertMessageId = session?.revert?.messageId.trim();
    final sessionId = session?.id;
    final pendingBranch = _visiblePendingReplacementBranch;
    final pendingBranchKey = pendingBranch?.cacheKey;
    if (_cachedVisibleMessagesVersion == _messagesVersion &&
        _cachedVisibleMessagesSessionId == sessionId &&
        _cachedVisibleMessagesRevertId == revertMessageId &&
        _cachedVisibleMessagesBranchKey == pendingBranchKey) {
      return _cachedVisibleMessages;
    }
    if (pendingBranch != null) {
      return _cacheVisibleMessages(
        sessionId: sessionId,
        revertMessageId: revertMessageId,
        pendingBranchKey: pendingBranchKey,
        messages: List<ChatMessage>.unmodifiable(
          _applyPendingReplacementBranchToMessages(
            _messages,
            branch: pendingBranch,
          ),
        ),
      );
    }
    if (session == null || revertMessageId == null || revertMessageId.isEmpty) {
      return _cacheVisibleMessages(
        sessionId: sessionId,
        revertMessageId: revertMessageId,
        pendingBranchKey: pendingBranchKey,
        messages: List<ChatMessage>.unmodifiable(_messages),
      );
    }
    final boundaryIndex = _messages.indexWhere(
      (message) =>
          message.sessionId == session.id && message.id == revertMessageId,
    );
    if (boundaryIndex <= 0) {
      return _cacheVisibleMessages(
        sessionId: sessionId,
        revertMessageId: revertMessageId,
        pendingBranchKey: pendingBranchKey,
        messages: const <ChatMessage>[],
      );
    }
    return _cacheVisibleMessages(
      sessionId: sessionId,
      revertMessageId: revertMessageId,
      pendingBranchKey: pendingBranchKey,
      messages: List<ChatMessage>.unmodifiable(
        _messages.sublist(0, boundaryIndex),
      ),
    );
  }

  List<ChatMessage> _cacheVisibleMessages({
    required String? sessionId,
    required String? revertMessageId,
    required String? pendingBranchKey,
    required List<ChatMessage> messages,
  }) {
    _cachedVisibleMessagesVersion = _messagesVersion;
    _cachedVisibleMessagesSessionId = sessionId;
    _cachedVisibleMessagesRevertId = revertMessageId;
    _cachedVisibleMessagesBranchKey = pendingBranchKey;
    _cachedVisibleMessages = messages;
    return _cachedVisibleMessages;
  }

  ChatSyncState get syncState => _syncState;
  bool get isInDegradedMode => _degradedMode;
  bool get isInResumeGrace => _isInResumeGrace;
  bool get isForegroundResumeSyncing => _isForegroundResumeSyncing;
  bool get isRecoverableSyncAlertEscalated => _recoverableSyncAlertEscalated;
  bool get refreshlessRealtimeEnabled => _refreshlessRealtimeEnabled;
  bool get isAbortingResponse => _isAbortingResponse;
  bool get isCompactingContext => _isCompactingContext;
  Map<String, SessionStatusInfo> get sessionStatusById =>
      Map<String, SessionStatusInfo>.unmodifiable(_sessionStatusById);

  bool get canAbortActiveResponse {
    if (_isAbortingResponse || _currentSession == null) {
      return false;
    }
    final sessionId = _currentSession!.id;
    // Active stream or sending state always allows abort. The
    // server connection is live and the user may need to stop it.
    if (_activeMessageStreamSessionId == sessionId &&
        _messageSubscription != null) {
      return true;
    }
    if (_state == ChatState.sending) {
      return true;
    }
    if (!isCurrentSessionActivelyResponding) {
      return false;
    }
    final latestMessage = _latestMessageForSession(sessionId);
    if (latestMessage is! AssistantMessage) {
      return true;
    }
    // A completed assistant with revealable content (text, reasoning,
    // etc.) means the turn has settled. There is nothing locally
    // abortable even if the server still reports busy/retry. This
    // prevents the composer from showing a stuck Stop button after
    // the final response is already visible.
    if (latestMessage.isCompleted &&
        hasRevealableAssistantContent(latestMessage)) {
      return false;
    }
    return true;
  }

  /// Returns the latest message for the given session by searching
  /// backwards through [_messages], or null if none exists.
  ChatMessage? _latestMessageForSession(String sessionId) {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final candidate = _messages[i];
      if (candidate.sessionId == sessionId) {
        return candidate;
      }
    }
    return null;
  }

  // Generates a unique ID for optimistic (locally-appended) user messages.
  //
  // INVARIANT — do NOT change the prefix or format (see ADR-023 Pitfall P-001):
  // The `local_user_*` prefix is load-bearing. The SSE merge logic uses it to
  // identify optimistic bubbles eligible for duplicate-echo suppression
  // (`_shouldSkipLocalUserAppendAsDuplicateEcho`). If the prefix is changed to
  // any server-format value (e.g. `msg_*`), the prefix check short-circuits and
  // the bubble is treated as a confirmed server message. This silently breaks
  // reconciliation for all conversation turns after the first — the UI stays
  // stuck even though the assistant response arrives. (Regression: b0660a2)
  bool _isOptimisticLocalUserMessageId(String messageId) {
    return messageId.trim().startsWith(_optimisticLocalUserMessageIdPrefix);
  }

  String _nextLocalUserMessageId() {
    _localMessageIdSequence += 1;
    return '${_optimisticLocalUserMessageIdPrefix}${DateTime.now().microsecondsSinceEpoch}_${_localMessageIdSequence}';
  }

  bool get _isExperimentalMultiDeviceSyncEnabled {
    return settingsProvider?.enableExperimentalMultiDeviceSync ?? false;
  }

  bool get _hasLocalActiveSelectionSyncWork {
    final hasInProgressAssistant = _messages.whereType<AssistantMessage>().any(
      (message) => !message.isCompleted,
    );
    return _state == ChatState.sending ||
        _isAbortingResponse ||
        _messageSubscription != null ||
        hasInProgressAssistant;
  }

  bool get _hasAnyBusySessionStatus {
    for (final status in _sessionStatusById.values) {
      if (status.type == SessionStatusType.busy ||
          status.type == SessionStatusType.retry) {
        return true;
      }
    }
    return false;
  }

  bool get _hasAnyActiveAbortSuppression {
    final sessionId = _abortSuppressionSessionId;
    if (sessionId == null || sessionId.trim().isEmpty) {
      return false;
    }
    return _isAbortSuppressionActiveForSession(sessionId);
  }

  bool get _shouldDeferRemoteSelectionSync {
    if (!_isExperimentalMultiDeviceSyncEnabled) {
      return false;
    }
    if (_hasLocalActiveSelectionSyncWork) {
      return true;
    }
    if (_hasAnyActiveAbortSuppression) {
      return true;
    }
    return _hasAnyBusySessionStatus;
  }

  bool get _canFlushPendingRemoteSelectionSync {
    return !_shouldDeferRemoteSelectionSync;
  }

  List<ChatSession> get visibleSessions {
    return _buildVisibleSessionsFrom(_sessions);
  }

  List<ChatSession> recentRootSessionsForScopeId(String scopeId) {
    final sessions = _sessionsForScopeId(scopeId);
    if (sessions.isEmpty) {
      return const <ChatSession>[];
    }
    final recent =
        sessions
            .where(
              (session) =>
                  !session.archived &&
                  (session.parentId == null ||
                      session.parentId!.trim().isEmpty),
            )
            .toList(growable: false)
          ..sort((a, b) => b.time.compareTo(a.time));
    return recent;
  }

  List<ChatSession> visibleSessionsForScopeId(String scopeId) {
    final normalizedScopeId = scopeId.trim();
    if (normalizedScopeId.isEmpty) {
      return const <ChatSession>[];
    }
    final contextKey = _composeContextKey(_activeServerId, normalizedScopeId);
    if (contextKey == _activeContextKey) {
      return visibleSessions;
    }
    final snapshot = _contextSnapshots[contextKey];
    if (snapshot == null) {
      return const <ChatSession>[];
    }
    return _buildVisibleSessionsFrom(
      snapshot.sessions,
      pinnedSessionIds: snapshot.pinnedSessionIds,
    );
  }

  bool hasSnapshotForScopeId(String scopeId) {
    final normalizedScopeId = scopeId.trim();
    if (normalizedScopeId.isEmpty) {
      return false;
    }
    final contextKey = _composeContextKey(_activeServerId, normalizedScopeId);
    if (contextKey == _activeContextKey) {
      return true;
    }
    return _contextSnapshots.containsKey(contextKey);
  }

  List<ChatSession> _buildVisibleSessionsFrom(
    List<ChatSession> sourceSessions, {
    Set<String>? pinnedSessionIds,
  }) {
    final effectivePinnedSessionIds = pinnedSessionIds ?? _pinnedSessionIds;
    final query = _sessionSearchQuery.trim().toLowerCase();
    final sessionById = <String, ChatSession>{
      for (final session in sourceSessions) session.id: session,
    };
    final hiddenByArchivedAncestor = _hiddenByArchivedAncestor(sessionById);
    final filtered = sourceSessions
        .where((session) {
          final archived = session.archived;
          final hiddenByAncestor =
              hiddenByArchivedAncestor[session.id] ?? false;
          switch (_sessionListFilter) {
            case SessionListFilter.active:
              if (archived || hiddenByAncestor) {
                return false;
              }
            case SessionListFilter.archived:
              if (!archived) {
                return false;
              }
            case SessionListFilter.all:
              break;
          }

          if (query.isEmpty) {
            return true;
          }

          final title = (session.title ?? '').toLowerCase();
          final summary = (session.summary ?? '').toLowerCase();
          return title.contains(query) || summary.contains(query);
        })
        .toList(growable: false);

    final sorted = List<ChatSession>.from(filtered)
      ..sort(
        (a, b) => _compareSessionsForSidebarOrder(
          a,
          b,
          pinnedSessionIds: effectivePinnedSessionIds,
        ),
      );

    final limited = sorted.length <= _sessionVisibleLimit
        ? sorted
        : sorted.take(_sessionVisibleLimit).toList(growable: false);

    return _includeVisibleSessionAncestors(
      visibleSessions: limited,
      sortedFilteredSessions: sorted,
    );
  }

  int _compareSessionsForSidebarOrder(
    ChatSession a,
    ChatSession b, {
    Set<String>? pinnedSessionIds,
  }) {
    final effectivePinnedSessionIds = pinnedSessionIds ?? _pinnedSessionIds;
    final aPinned = effectivePinnedSessionIds.contains(a.id);
    final bPinned = effectivePinnedSessionIds.contains(b.id);
    if (aPinned != bPinned) {
      return aPinned ? -1 : 1;
    }

    switch (_sessionListSort) {
      case SessionListSort.oldest:
        return a.time.compareTo(b.time);
      case SessionListSort.title:
        return (a.title ?? '').toLowerCase().compareTo(
          (b.title ?? '').toLowerCase(),
        );
      case SessionListSort.recent:
        return b.time.compareTo(a.time);
    }
  }

  void _prunePinnedSessionIdsToKnownSessions() {
    if (!_hasLoadedSessionsAuthoritatively || _pinnedSessionIds.isEmpty) {
      return;
    }
    final knownSessionIds = _sessions
        .where((session) => !session.archived)
        .map((session) => session.id)
        .toSet();
    final previousPinnedSessionIds = Set<String>.from(_pinnedSessionIds);
    final nextPinnedSessionIds = _pinnedSessionIds
        .where((id) => knownSessionIds.contains(id))
        .toSet();
    if (setEquals(nextPinnedSessionIds, _pinnedSessionIds)) return;
    _pinnedSessionIds = nextPinnedSessionIds;
    _recordPinnedSessionMutation();
    final scopeId = _activePinnedSessionScopeId() ?? _resolveContextScopeId();
    _writeThroughPinnedSessionScope(
      serverId: _activeServerId,
      scopeId: scopeId,
      ids: _pinnedSessionIds,
    );
    unawaited(
      _persistPinnedSessionScope(
        serverId: _activeServerId,
        scopeId: scopeId,
        ids: _pinnedSessionIds,
      ),
    );
    final removedSessionIds = previousPinnedSessionIds.difference(
      nextPinnedSessionIds,
    );
    final removedTabs = _sessionTabs
        .where(
          (tab) =>
              tab.pinScopeId == normalizeOptionalFilePath(scopeId) &&
              removedSessionIds.contains(tab.identity.sessionId),
        )
        .map((tab) => tab.identity)
        .toList(growable: false);
    for (final identity in removedTabs) {
      _removeSessionTabAuthoritatively(identity, activeContext: true);
    }
  }

  List<ChatSession> _includeVisibleSessionAncestors({
    required List<ChatSession> visibleSessions,
    required List<ChatSession> sortedFilteredSessions,
  }) {
    if (visibleSessions.isEmpty ||
        visibleSessions.length == sortedFilteredSessions.length) {
      return visibleSessions;
    }

    final sessionById = <String, ChatSession>{
      for (final session in sortedFilteredSessions) session.id: session,
    };
    final visibleIds = visibleSessions.map((session) => session.id).toSet();

    for (final session in visibleSessions) {
      var parentId = session.parentId;
      final visited = <String>{session.id};
      while (parentId != null && parentId.isNotEmpty) {
        if (!visited.add(parentId)) {
          break;
        }
        final parent = sessionById[parentId];
        if (parent == null) {
          break;
        }
        visibleIds.add(parent.id);
        parentId = parent.parentId;
      }
    }

    if (visibleIds.length == visibleSessions.length) {
      return visibleSessions;
    }

    return sortedFilteredSessions
        .where((session) => visibleIds.contains(session.id))
        .toList(growable: false);
  }

  bool get canLoadMoreSessions {
    final query = _sessionSearchQuery.trim().toLowerCase();
    final sessionById = <String, ChatSession>{
      for (final session in _sessions) session.id: session,
    };
    final hiddenByArchivedAncestor = _hiddenByArchivedAncestor(sessionById);
    final total = _sessions.where((session) {
      final archived = session.archived;
      final hiddenByAncestor = hiddenByArchivedAncestor[session.id] ?? false;
      switch (_sessionListFilter) {
        case SessionListFilter.active:
          if (archived || hiddenByAncestor) {
            return false;
          }
        case SessionListFilter.archived:
          if (!archived) {
            return false;
          }
        case SessionListFilter.all:
          break;
      }
      if (query.isEmpty) {
        return true;
      }
      final title = (session.title ?? '').toLowerCase();
      final summary = (session.summary ?? '').toLowerCase();
      return title.contains(query) || summary.contains(query);
    }).length;
    return total > visibleSessions.length;
  }

  SessionStatusInfo? get currentSessionStatus {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return null;
    }
    return _sessionStatusById[sessionId];
  }

  List<ChatPermissionRequest> get currentSessionPermissions {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <ChatPermissionRequest>[];
    }
    return List<ChatPermissionRequest>.unmodifiable(
      _pendingPermissionsBySession[sessionId] ??
          const <ChatPermissionRequest>[],
    );
  }

  List<ChatQuestionRequest> get currentSessionQuestions {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <ChatQuestionRequest>[];
    }
    return List<ChatQuestionRequest>.unmodifiable(
      _pendingQuestionsBySession[sessionId] ?? const <ChatQuestionRequest>[],
    );
  }

  ChatPermissionRequest? get currentPermissionRequest =>
      currentSessionPermissions.firstOrNull;
  ChatQuestionRequest? get currentQuestionRequest =>
      currentSessionQuestions.firstOrNull;

  List<ChatPermissionRequest> get currentThreadPermissionRequests {
    if (_cachedThreadPermissionsAtVersion == _threadPermissionsVersion) {
      return _cachedThreadPermissionRequests;
    }

    final currentSessionId = _currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      _cachedThreadPermissionsAtVersion = _threadPermissionsVersion;
      _cachedThreadPermissionRequests = const <ChatPermissionRequest>[];
      return _cachedThreadPermissionRequests;
    }

    final orderedSessionIds = <String>[
      currentSessionId,
      ..._orderedCurrentSessionDescendantIds(),
    ];
    final seenRequestIds = <String>{};
    final collected = <ChatPermissionRequest>[];

    for (final sessionId in orderedSessionIds) {
      final sessionRequests = _pendingPermissionsBySession[sessionId];
      if (sessionRequests == null || sessionRequests.isEmpty) {
        continue;
      }
      for (final request in sessionRequests) {
        if (seenRequestIds.add(request.id)) {
          collected.add(request);
        }
      }
    }

    _cachedThreadPermissionsAtVersion = _threadPermissionsVersion;
    _cachedThreadPermissionRequests = List<ChatPermissionRequest>.unmodifiable(
      collected,
    );
    return _cachedThreadPermissionRequests;
  }

  List<ChatQuestionRequest> get currentThreadQuestionRequests {
    if (_cachedThreadQuestionsAtVersion == _threadPermissionsVersion) {
      return _cachedThreadQuestionRequests;
    }

    final currentSessionId = _currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      _cachedThreadQuestionsAtVersion = _threadPermissionsVersion;
      _cachedThreadQuestionRequests = const <ChatQuestionRequest>[];
      return _cachedThreadQuestionRequests;
    }

    final orderedSessionIds = <String>[
      currentSessionId,
      ..._orderedCurrentSessionDescendantIds(),
    ];
    final seenRequestIds = <String>{};
    final collected = <ChatQuestionRequest>[];

    for (final sessionId in orderedSessionIds) {
      final sessionRequests = _pendingQuestionsBySession[sessionId];
      if (sessionRequests == null || sessionRequests.isEmpty) {
        continue;
      }
      for (final request in sessionRequests) {
        if (seenRequestIds.add(request.id)) {
          collected.add(request);
        }
      }
    }

    _cachedThreadQuestionsAtVersion = _threadPermissionsVersion;
    _cachedThreadQuestionRequests = List<ChatQuestionRequest>.unmodifiable(
      collected,
    );
    return _cachedThreadQuestionRequests;
  }

  List<String> get currentThreadSessionIds {
    final currentSessionId = _currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      return const <String>[];
    }

    return List<String>.unmodifiable(<String>[
      currentSessionId,
      ..._orderedCurrentSessionDescendantIds(),
    ]);
  }

  List<String> _orderedCurrentSessionDescendantIds() {
    final currentSessionId = _currentSession?.id;
    if (currentSessionId == null || currentSessionId.isEmpty) {
      return const <String>[];
    }

    final childIdsByParent = _childSessionIdsByParent();
    if (childIdsByParent.isEmpty) {
      return const <String>[];
    }

    final visited = <String>{currentSessionId};
    final orderedDescendants = <String>[];
    final queue = ListQueue<String>()..add(currentSessionId);

    while (queue.isNotEmpty) {
      final parentId = queue.removeFirst();
      final childIds = childIdsByParent[parentId] ?? const <String>[];
      for (final childId in childIds) {
        if (!visited.add(childId)) {
          continue;
        }
        orderedDescendants.add(childId);
        queue.add(childId);
      }
    }

    return orderedDescendants;
  }

  Map<String, List<String>> _childSessionIdsByParent() {
    final output = <String, List<String>>{};

    void appendChild({required String parentId, required String childId}) {
      if (parentId.isEmpty || childId.isEmpty || parentId == childId) {
        return;
      }
      final children = output.putIfAbsent(parentId, () => <String>[]);
      if (!children.contains(childId)) {
        children.add(childId);
      }
    }

    for (final session in _sessions) {
      final parentId = session.parentId?.trim();
      if (parentId == null || parentId.isEmpty) {
        continue;
      }
      appendChild(parentId: parentId, childId: session.id);
    }

    for (final entry in _sessionChildrenById.entries) {
      final parentId = entry.key.trim();
      if (parentId.isEmpty) {
        continue;
      }
      for (final child in entry.value) {
        appendChild(parentId: parentId, childId: child.id);
      }
    }

    return output;
  }

  List<ChatSession> get currentSessionChildren {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <ChatSession>[];
    }
    return List<ChatSession>.unmodifiable(
      _sessionChildrenById[sessionId] ?? const <ChatSession>[],
    );
  }

  ChatSession? knownSessionById(String sessionId) {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) {
      return null;
    }
    if (_currentSession?.id == normalizedId) {
      return _currentSession;
    }
    final listedSession = _sessions
        .where((session) => session.id == normalizedId)
        .firstOrNull;
    if (listedSession != null) {
      return listedSession;
    }
    for (final children in _sessionChildrenById.values) {
      final cachedSession = children
          .where((session) => session.id == normalizedId)
          .firstOrNull;
      if (cachedSession != null) {
        return cachedSession;
      }
    }
    return null;
  }

  List<SessionTodo> get currentSessionTodo {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <SessionTodo>[];
    }
    return List<SessionTodo>.unmodifiable(
      _sessionTodoById[sessionId] ?? const <SessionTodo>[],
    );
  }

  List<SessionDiff> get currentSessionDiff {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <SessionDiff>[];
    }
    return List<SessionDiff>.unmodifiable(
      _sessionDiffById[sessionId] ?? const <SessionDiff>[],
    );
  }

  /// True when the diff for the active session has been loaded at least once
  /// since the last context switch. Lets the Review Changes UI suppress the
  /// "no changed files" empty state until the first refresh resolves.
  bool get isCurrentSessionDiffLoaded {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return false;
    }
    return _sessionDiffLoadedById.contains(sessionId);
  }

  /// Last error message for the active session diff request, or null on success.
  String? get currentSessionDiffError {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return null;
    }
    return _sessionDiffErrorById[sessionId];
  }

  Provider? get selectedProvider {
    final selectedId = _selectedProviderId;
    if (selectedId == null) {
      return null;
    }
    return _providers
        .where((provider) => provider.id == selectedId)
        .firstOrNull;
  }

  Model? get selectedModel {
    final provider = selectedProvider;
    final modelId = _selectedModelId;
    if (provider == null || modelId == null) {
      return null;
    }
    return provider.models[modelId];
  }

  List<ModelVariant> get availableVariants =>
      selectedModel?.variants.values.toList(growable: false) ??
      const <ModelVariant>[];

  String get selectedVariantLabel {
    final selected = _selectedVariantId;
    if (selected == null) {
      return L10nBridge.current?.modelAuto ?? 'Auto';
    }
    final variant = selectedModel?.variants[selected];
    return variant?.name ?? selected;
  }

  /// Set scroll-to-bottom callback
  void setScrollToBottomCallback(
    void Function({required String reason})? callback,
  ) {
    _scrollToBottomCallback = callback;
  }

  /// Set state

  /// Set error

  ChatUiNotice? consumePendingUiNotice() {
    final notice = _pendingUiNotice;
    _pendingUiNotice = null;
    return notice;
  }

  ChatComposerDraft? consumeRejectedDraft({String? sessionId}) {
    final rejectedDraft = _rejectedDraft;
    if (rejectedDraft == null || !rejectedDraft.draft.hasContent) {
      _clearRejectedDraft();
      return null;
    }

    final expectedSessionId = sessionId?.trim();
    final draftSessionId = rejectedDraft.sessionId.trim();
    if (expectedSessionId != null &&
        expectedSessionId.isNotEmpty &&
        expectedSessionId != draftSessionId) {
      return null;
    }

    _clearRejectedDraft();
    return rejectedDraft.draft;
  }

  void setSessionSearchQuery(String query) {
    final normalized = query.trim();
    if (_sessionSearchQuery == normalized) {
      return;
    }
    _sessionSearchQuery = normalized;
    _sessionVisibleLimit = 40;
    notifyListeners();
  }

  void setSessionListFilter(SessionListFilter filter) {
    if (_sessionListFilter == filter) {
      return;
    }
    _sessionListFilter = filter;
    _sessionVisibleLimit = 40;
    notifyListeners();
  }

  void setSessionListSort(SessionListSort sort) {
    if (_sessionListSort == sort) {
      return;
    }
    _sessionListSort = sort;
    _sortSessionsInPlace();
    _sessionVisibleLimit = 40;
    notifyListeners();
  }

  void loadMoreSessions() {
    _sessionVisibleLimit += 40;
    notifyListeners();
  }

  List<ChatMessage> _messagesForSettledStatusGuard(String sessionId) {
    if (!AppLogger.performanceLoggingEnabled) {
      if (_currentSession?.id == sessionId) {
        return _messages;
      }
      return _cachedSessionMessages(sessionId) ?? const <ChatMessage>[];
    }

    final stopwatch = Stopwatch()..start();
    var source = 'memory';
    try {
      final messages = _currentSession?.id == sessionId
          ? _messages
          : () {
              source = 'lru_cache';
              return _cachedSessionMessages(sessionId) ?? const <ChatMessage>[];
            }();
      stopwatch.stop();
      AppLogger.recordPerformanceTask(
        operation: 'settlement_status_guard_messages',
        elapsed: stopwatch.elapsed,
        status: 'ok',
        tags: const <String>{'chat:settlement', 'chat:messages'},
        context: <String, Object?>{
          'sessionHash': AppLogger.safeContextId(sessionId),
          'source': source,
          'messageCount': messages.length,
        },
      );
      return messages;
    } catch (error, stackTrace) {
      stopwatch.stop();
      AppLogger.recordPerformanceTask(
        operation: 'settlement_status_guard_messages',
        elapsed: stopwatch.elapsed,
        status: 'error',
        tags: const <String>{'chat:settlement', 'chat:messages'},
        context: <String, Object?>{
          'sessionHash': AppLogger.safeContextId(sessionId),
          'source': source,
        },
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Returns true if [event] belongs to an ephemeral title-generation session.
  /// Checks both the session ID set and the session title as fallback
  /// (the title is known before the POST /session response arrives,
  /// but SSE events may arrive before the ID is added to the set).
  Future<void> refreshSessionStatusSnapshot({bool silent = true}) async {
    final currentIdAtCall = _currentSession?.id;
    final result = await getSessionStatus(
      GetSessionStatusParams(directory: projectProvider.currentDirectory),
    );
    result.fold(
      (failure) {
        if (!silent) {
          _sessionInsightsError =
              L10nBridge.current?.chatProviderErrorLoadSessionStatus ??
              'Failed to load session status';
          notifyListeners();
        }
        AppLogger.warn('Failed to load session status snapshot: $failure');
      },
      (statusMap) {
        // Remove ephemeral title-generation sessions from the status map.
        statusMap.removeWhere(
          (id, _) => ChatTitleGenerator.ephemeralSessionIds.contains(id),
        );
        // Guard: prevent stale REST busy/retry (from the onDone-triggered
        // loadSessionInsights) from re-enabling Stop after the SSE
        // send-stream has settled with a final revealable response.
        // The SSE-settled timestamp is time-bounded: only status refreshes
        // immediately after onDone are protected. Later refreshes accept REST
        // status normally, avoiding turn-unscoped suppression of legitimate
        // busy/retry states (e.g. resumed work or another client).
        // currentIdAtCall is captured before the await above so the guard
        // applies to the session that was current when the request was
        // made, not the session current when the response arrives
        // (the user may have switched sessions during the in-flight await).
        if (currentIdAtCall != null) {
          final currentStatus = _sessionStatusById[currentIdAtCall]?.type;
          final settledAt = _sseSettledAtBySessionId[currentIdAtCall];
          final sseSettledToIdle =
              settledAt != null &&
              DateTime.now().difference(settledAt) < const Duration(seconds: 4);
          const idle = SessionStatusType.idle;
          if (sseSettledToIdle &&
              (currentStatus == null || currentStatus == idle) &&
              (statusMap[currentIdAtCall]?.type == SessionStatusType.busy ||
                  statusMap[currentIdAtCall]?.type ==
                      SessionStatusType.retry) &&
              hasCompletedRevealableAssistantMessage(
                _messagesForSettledStatusGuard(currentIdAtCall),
                currentIdAtCall,
              )) {
            statusMap[currentIdAtCall] = const SessionStatusInfo(type: idle);
          }
        }
        _sessionStatusById = statusMap;
        _syncAttentionFromStatusMap(statusMap);
        _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
        if (!silent) {
          _sessionInsightsError = null;
        }
        notifyListeners();
      },
    );
  }

  Future<Either<Failure, T>> _runSessionInsightRequest<T>({
    required String requestName,
    required Future<Either<Failure, T>> Function() request,
  }) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected exception while loading session $requestName',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(
        UnknownFailure('Unexpected error while loading session $requestName'),
      );
    }
  }

  bool _sessionDiffListEquals(List<SessionDiff> a, List<SessionDiff> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  /// Resolves the [SessionDiff] for [sessionId] using official
  /// `GET /session/{id}/diff` semantics.
  ///
  /// When [exhaustiveDiffScan] is true (user-initiated Review Changes), the
  /// helper walks recent user turns newest-first and stops at the first
  /// turn whose summary contains a non-empty diff. The walk is bounded by
  /// [_reviewChangesExhaustiveScanCap] to avoid runaway cost.
  ///
  /// ADR-023: current upstream `SessionSummary.diff` returns `[]` when
  /// `messageID` is omitted. The helper therefore:
  /// - uses the explicit [messageId] when provided;
  /// - otherwise picks the latest visible server-confirmed user message;
  /// - on user-initiated calls with [exhaustiveDiffScan] true, walks back
  ///   up to the recent-user-turn cap so a turn that produced no file changes
  ///   does not hide earlier changes;
  /// - on automatic refresh, only overwrites an existing non-empty diff when
  ///   the targeted turn actually has changes; transient fetch failures and
  ///   empty automatic results preserve the last-known good diff (matches
  ///   the BEHAVIOR.md rule that hiding the display toggle must not clear
  ///   session diff data).
  Future<_SessionDiffResolution> _resolveSessionDiff({
    required String sessionId,
    required String projectId,
    required String? directory,
    required String? messageId,
    required bool userInitiated,
    required bool exhaustiveDiffScan,
  }) async {
    final existingDiff = List<SessionDiff>.unmodifiable(
      _sessionDiffById[sessionId] ?? const <SessionDiff>[],
    );
    final hadPreviousDiff = existingDiff.isNotEmpty;

    String? targetMessageId = messageId?.trim();
    List<String>? walkCandidates;
    if ((targetMessageId == null || targetMessageId.isEmpty) &&
        _currentSession?.id == sessionId) {
      walkCandidates = visibleServerConfirmedUserMessageIds(
        limit: exhaustiveDiffScan ? _reviewChangesExhaustiveScanCap : 1,
      );
      targetMessageId = walkCandidates.isEmpty ? null : walkCandidates.first;
    }
    if (targetMessageId == null || targetMessageId.isEmpty) {
      // No eligible server-confirmed user message yet. We still want to mark
      // the session as "loaded empty" so the UI doesn't show a perpetual
      // spinner, but only when this was an explicit user request. Automatic
      // refresh defers loaded-state to the next concrete attempt so we don't
      // lose the chance to retry on the next send.
      return _SessionDiffResolution(
        diffs: const <SessionDiff>[],
        applied: false,
        updatedState: userInitiated
            ? _SessionDiffLoadState.loadedEmpty
            : _SessionDiffLoadState.unchanged,
        error: null,
      );
    }

    // For the user-initiated Review Changes action, walk the recent user
    // turns newest-first and stop at the first non-empty result. For any
    // other call, only the latest turn is queried.
    final candidates = exhaustiveDiffScan
        ? (walkCandidates ?? <String>[targetMessageId])
        : <String>[targetMessageId];

    String? lastError;
    for (final candidateMessageId in candidates) {
      final result = await getSessionDiff(
        GetSessionDiffParams(
          projectId: projectId,
          sessionId: sessionId,
          messageId: candidateMessageId,
          directory: directory,
        ),
      );
      final next = result.fold<_SessionDiffResolution>(
        (failure) {
          lastError = failure.message;
          return _SessionDiffResolution(
            diffs: existingDiff,
            applied: false,
            updatedState: _SessionDiffLoadState.unchanged,
            error: failure.message,
          );
        },
        (diff) {
          if (diff.isNotEmpty) {
            return _SessionDiffResolution(
              diffs: diff,
              applied: true,
              updatedState: _SessionDiffLoadState.loaded,
              error: null,
            );
          }
          // Empty result: continue walking for the Review Changes
          // exhaustive scan, or preserve the previous diff for the
          // automatic refresh path. The final "every turn is empty"
          // state is committed only after the loop completes.
          return _SessionDiffResolution(
            diffs: existingDiff,
            applied: false,
            updatedState: _SessionDiffLoadState.unchanged,
            error: null,
          );
        },
      );
      // Stop walking only on a non-empty diff or a fetch error. An empty
      // diff during the exhaustive walk simply moves on to the next older
      // turn; only when every candidate has been tried do we commit to the
      // "session is empty" state.
      if (next.applied || next.error != null) {
        return next;
      }
      // Otherwise keep walking to the next older turn.
    }

    if (exhaustiveDiffScan) {
      // Every candidate returned empty. The user explicitly asked for the
      // exhaustive Review Changes view, so honor the honest outcome and
      // commit to a loaded-empty result. The caller is responsible for
      // not clobbering a newer concurrent write (it compares the stored
      // diff to the snapshot we captured at the start of this call).
      return _SessionDiffResolution(
        diffs: const <SessionDiff>[],
        applied: hadPreviousDiff,
        appliedIfStillEquals: hadPreviousDiff ? existingDiff : null,
        updatedState: _SessionDiffLoadState.loadedEmpty,
        error: null,
      );
    }
    return _SessionDiffResolution(
      diffs: existingDiff,
      applied: false,
      updatedState: _SessionDiffLoadState.unchanged,
      error: lastError,
    );
  }

  Future<void> loadSessionInsights(
    String sessionId, {
    String? messageId,
    bool silent = false,
    bool userInitiated = false,
    bool exhaustiveDiffScan = false,
  }) async {
    if (!userInitiated &&
        _cellularDataSaverService.shouldSuppressBackgroundWork) {
      return;
    }
    if (userInitiated) {
      _cellularDataSaverService.noteExplicitUserAction(
        reason: 'session-insights',
      );
      await _syncCellularDataSaverRealtimePolicy(
        reason: 'session-insights-user',
        forceBurst: true,
      );
    }

    final automaticDataSaverMode =
        _cellularDataSaverService.isDataSaverActive && !userInitiated;
    if (automaticDataSaverMode) {
      final lastAutomaticLoadAt =
          _lastAutomaticSessionInsightsAtBySessionId[sessionId];
      final now = DateTime.now();
      if (lastAutomaticLoadAt != null &&
          now.difference(lastAutomaticLoadAt) <
              _cellularDataSaverService.automaticSyncInterval) {
        return;
      }
      _lastAutomaticSessionInsightsAtBySessionId[sessionId] = now;
    }

    if (!silent) {
      _isLoadingSessionInsights = true;
      _sessionInsightsError = null;
      notifyListeners();
    }

    try {
      if (!userInitiated &&
          _cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }
      // Capture current session ID at the same time so the guard applies to
      // the session that was current when the request was made, not the one
      // current when the response arrives (user may switch during await).
      final currentIdAtCall = _currentSession?.id;

      final directory = projectProvider.currentDirectory;
      final projectId = projectProvider.currentProjectId;

      Future<Either<Failure, List<ChatSession>>>? childrenFuture;
      Future<Either<Failure, List<SessionTodo>>>? todoFuture;
      Future<_SessionDiffResolution>? diffFuture;
      if (!automaticDataSaverMode) {
        // Full insights are useful after explicit actions, but expensive to pull
        // automatically on cellular data.
        childrenFuture = _runSessionInsightRequest(
          requestName: 'children',
          request: () => getSessionChildren(
            GetSessionChildrenParams(
              projectId: projectId,
              sessionId: sessionId,
              directory: directory,
            ),
          ),
        );
        todoFuture = _runSessionInsightRequest(
          requestName: 'todo',
          request: () => getSessionTodo(
            GetSessionTodoParams(
              projectId: projectId,
              sessionId: sessionId,
              directory: directory,
            ),
          ),
        );
        // ADR-023: the official /session/{id}/diff endpoint requires a
        // messageID; route the request through _resolveSessionDiff so we
        // pick the right user message and apply non-empty guards before
        // overwriting the existing diff.
        diffFuture = _resolveSessionDiff(
          sessionId: sessionId,
          projectId: projectId,
          directory: directory,
          messageId: messageId,
          userInitiated: userInitiated,
          exhaustiveDiffScan: exhaustiveDiffScan,
        );
      }
      final statusFuture = _runSessionInsightRequest(
        requestName: 'status',
        request: () =>
            getSessionStatus(GetSessionStatusParams(directory: directory)),
      );

      final statusResult = await statusFuture;
      if (childrenFuture != null) {
        final childrenResult = await childrenFuture;
        childrenResult.fold(
          (failure) {
            AppLogger.warn(
              'Failed to load session children for $sessionId: $failure',
            );
          },
          (children) {
            _sessionChildrenById[sessionId] = children;
            _threadPermissionsVersion++;
          },
        );
      }

      if (todoFuture != null) {
        final todoResult = await todoFuture;
        todoResult.fold(
          (failure) {
            AppLogger.warn(
              'Failed to load session todo for $sessionId: $failure',
            );
          },
          (todos) {
            _sessionTodoById[sessionId] = todos;
          },
        );
      }

      if (diffFuture != null) {
        final diffResolution = await diffFuture;
        if (diffResolution.applied) {
          // Guard against a stale result clobbering a newer concurrent
          // write: only apply the new value when the stored diff still
          // matches the snapshot we captured at the start of the call.
          // We compare by reference identity first, then by element-wise
          // equality of the Equatable SessionDiff entries.
          final snapshot = diffResolution.appliedIfStillEquals;
          if (snapshot != null) {
            final current = _sessionDiffById[sessionId];
            final stillMatches =
                identical(current, snapshot) ||
                (current != null &&
                    current.length == snapshot.length &&
                    _sessionDiffListEquals(current, snapshot));
            if (!stillMatches) {
              return;
            }
          }
          _sessionDiffById[sessionId] = diffResolution.diffs;
        }
        switch (diffResolution.updatedState) {
          case _SessionDiffLoadState.unchanged:
            // Leave the loaded/error bookkeeping as-is.
            break;
          case _SessionDiffLoadState.loaded:
            _sessionDiffLoadedById.add(sessionId);
            _sessionDiffErrorById.remove(sessionId);
            break;
          case _SessionDiffLoadState.loadedEmpty:
            _sessionDiffLoadedById.add(sessionId);
            _sessionDiffErrorById.remove(sessionId);
            if (!diffResolution.applied) {
              // First successful empty result for this session — clear the
              // stale list so the UI can show the honest empty state. Only
              // clobber the stored list when it is currently empty so that
              // an older in-flight call cannot erase a newer write that
              // arrived from a more recent successful refresh.
              if ((_sessionDiffById[sessionId] ?? const <SessionDiff>[])
                  .isEmpty) {
                _sessionDiffById[sessionId] = const <SessionDiff>[];
              }
            }
            break;
        }
        if (diffResolution.error != null) {
          // Latch the error only when we have no usable cached diff data
          // (mirrors the failure case in _resolveSessionDiff).
          final hasUsableCached =
              (_sessionDiffById[sessionId] ?? const <SessionDiff>[]).isNotEmpty;
          if (!hasUsableCached) {
            _sessionDiffErrorById[sessionId] = diffResolution.error!;
          }
        }
      }

      statusResult.fold(
        (failure) {
          AppLogger.warn('Failed to refresh status for $sessionId: $failure');
          if (!silent) {
            _sessionInsightsError =
                L10nBridge.current?.chatProviderErrorLoadSessionDetails ??
                'Some session details could not be loaded';
          }
        },
        (statusMap) {
          statusMap.removeWhere(
            (id, _) => ChatTitleGenerator.ephemeralSessionIds.contains(id),
          );
          // Guard: prevent stale REST busy/retry (from the onDone-triggered
          // loadSessionInsights) from re-enabling Stop after the SSE
          // send-stream has settled with a final revealable response.
          // The SSE-settled timestamp is time-bounded: only status refreshes
          // immediately after onDone are protected. Later refreshes accept REST
          // status normally, avoiding turn-unscoped suppression of legitimate
          // busy/retry states (e.g. resumed work or another client).
          // currentIdAtCall was captured before any await so the guard uses
          // the session that was current when the request was made, not the
          // one current now (user may have switched during the in-flight
          // await above).
          if (currentIdAtCall != null) {
            final currentStatus = _sessionStatusById[currentIdAtCall]?.type;
            final settledAt = _sseSettledAtBySessionId[currentIdAtCall];
            final sseSettledToIdle =
                settledAt != null &&
                DateTime.now().difference(settledAt) <
                    const Duration(seconds: 4);
            const idle = SessionStatusType.idle;
            if (sseSettledToIdle &&
                (currentStatus == null || currentStatus == idle) &&
                (statusMap[currentIdAtCall]?.type == SessionStatusType.busy ||
                    statusMap[currentIdAtCall]?.type ==
                        SessionStatusType.retry) &&
                hasCompletedRevealableAssistantMessage(
                  _messagesForSettledStatusGuard(currentIdAtCall),
                  currentIdAtCall,
                )) {
              statusMap[currentIdAtCall] = const SessionStatusInfo(type: idle);
            }
          }
          _sessionStatusById = statusMap;
          _syncAttentionFromStatusMap(statusMap);
        },
      );
    } finally {
      if (!silent) {
        _isLoadingSessionInsights = false;
      }
      notifyListeners();
    }
  }

  Future<void> respondPermissionRequest({
    required String sessionId,
    required String requestId,
    required String reply,
    String? message,
  }) async {
    if (_isRespondingInteraction ||
        !_guardTransportForAction(actionLabel: 'reply to permission')) {
      return;
    }
    _cellularDataSaverService.noteExplicitUserAction(
      reason: 'reply-permission',
    );
    final tombstoneKey = _permissionInteractionKey(requestId);
    _rememberDismissedInteractionTombstone(tombstoneKey);
    _isRespondingInteraction = true;
    notifyListeners();
    try {
      final result = await replyPermission(
        ReplyPermissionParams(
          sessionId: sessionId,
          requestId: requestId,
          reply: reply,
          message: message,
          directory: projectProvider.currentDirectory,
        ),
      );
      result.fold(
        (failure) {
          _dismissedInteractionTombstones.remove(tombstoneKey);
          _handleFailure(failure);
        },
        (_) {
          for (final sessionId in _pendingPermissionsBySession.keys.toList()) {
            final filtered = _pendingPermissionsBySession[sessionId]!
                .where((item) => item.id != requestId)
                .toList(growable: false);
            if (filtered.isEmpty) {
              _pendingPermissionsBySession.remove(sessionId);
            } else {
              _pendingPermissionsBySession[sessionId] = filtered;
            }
          }
          _threadPermissionsVersion++;
        },
      );
    } finally {
      _isRespondingInteraction = false;
      notifyListeners();
    }
  }

  Future<void> submitQuestionAnswers({
    required String requestId,
    required List<List<String>> answers,
  }) async {
    if (_isRespondingInteraction ||
        !_guardTransportForAction(actionLabel: 'reply to question')) {
      return;
    }
    _cellularDataSaverService.noteExplicitUserAction(reason: 'reply-question');
    _isRespondingInteraction = true;
    notifyListeners();
    try {
      final result = await replyQuestion(
        ReplyQuestionParams(
          requestId: requestId,
          answers: answers,
          directory: projectProvider.currentDirectory,
        ),
      );
      result.fold(
        (failure) {
          // Mirror OpenChamber 1.12.1: when submit/dismiss fails, keep the
          // request visible with an error indicator so the user can retry.
          _questionSubmitFailedRequestIds.add(requestId);
          _questionSubmitFailedAtById[requestId] = DateTime.now();
          _handleFailure(failure);
        },
        (_) {
          _questionSubmitFailedRequestIds.remove(requestId);
          _questionSubmitFailedAtById.remove(requestId);
          _recentlyResolvedQuestionIds[requestId] = DateTime.now();
          _questionFirstSeenAtById.remove(requestId);
          for (final sessionId in _pendingQuestionsBySession.keys.toList()) {
            final filtered = _pendingQuestionsBySession[sessionId]!
                .where((item) => item.id != requestId)
                .toList(growable: false);
            if (filtered.isEmpty) {
              _pendingQuestionsBySession.remove(sessionId);
            } else {
              _pendingQuestionsBySession[sessionId] = filtered;
            }
          }
          _threadPermissionsVersion++;
        },
      );
    } finally {
      _isRespondingInteraction = false;
      notifyListeners();
    }
  }

  Future<void> rejectQuestionRequest({required String requestId}) async {
    if (_isRespondingInteraction ||
        !_guardTransportForAction(actionLabel: 'reject question')) {
      return;
    }
    _cellularDataSaverService.noteExplicitUserAction(reason: 'reject-question');
    _isRespondingInteraction = true;
    notifyListeners();
    try {
      final result = await rejectQuestion(
        RejectQuestionParams(
          requestId: requestId,
          directory: projectProvider.currentDirectory,
        ),
      );
      result.fold(
        (failure) {
          _questionSubmitFailedRequestIds.add(requestId);
          _questionSubmitFailedAtById[requestId] = DateTime.now();
          _handleFailure(failure);
        },
        (_) {
          _questionSubmitFailedRequestIds.remove(requestId);
          _questionSubmitFailedAtById.remove(requestId);
          _recentlyResolvedQuestionIds[requestId] = DateTime.now();
          _questionFirstSeenAtById.remove(requestId);
          for (final sessionId in _pendingQuestionsBySession.keys.toList()) {
            final filtered = _pendingQuestionsBySession[sessionId]!
                .where((item) => item.id != requestId)
                .toList(growable: false);
            if (filtered.isEmpty) {
              _pendingQuestionsBySession.remove(sessionId);
            } else {
              _pendingQuestionsBySession[sessionId] = filtered;
            }
          }
          _threadPermissionsVersion++;
        },
      );
    } finally {
      _isRespondingInteraction = false;
      notifyListeners();
    }
  }

  Future<void> retryProvidersRefresh() async {
    AppLogger.info('providers_refresh_retry');
    await initializeProviders();
  }

  /// Initialize providers
  Future<void> initializeProviders() async {
    final inFlight = _providersRefreshTask;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final task = _initializeProvidersInternal();
    _providersRefreshTask = task;
    try {
      await task;
    } finally {
      if (identical(_providersRefreshTask, task)) {
        _providersRefreshTask = null;
      }
    }
  }

  String _resolveContextScopeId() {
    return projectProvider.currentDirectory ?? projectProvider.currentProjectId;
  }

  Future<String> _resolveServerScopeId() async {
    final stored = await localDataSource.getActiveServerId();
    if (stored != null && stored.isNotEmpty) {
      _activeServerId = stored;
      _activeContextKey = _composeContextKey(
        _activeServerId,
        _resolveContextScopeId(),
      );
      return stored;
    }
    _activeServerId = 'legacy';
    _activeContextKey = _composeContextKey(
      _activeServerId,
      _resolveContextScopeId(),
    );
    return 'legacy';
  }

  _SelectionPersistenceSnapshot _captureSelectionPersistenceSnapshot({
    bool syncRemote = true,
  }) {
    final serverId = _activeServerId.trim().isEmpty
        ? 'legacy'
        : _activeServerId;
    final scopeId = _resolveContextScopeId();
    final overrides = _sessionOverridesForContext(_activeContextKey);
    final serializedOverrides = <String, dynamic>{};
    for (final entry in overrides.entries) {
      serializedOverrides[entry.key] = _sessionOverrideToJson(entry.value);
    }
    return _SelectionPersistenceSnapshot(
      serverId: serverId,
      scopeId: scopeId,
      contextKey: _activeContextKey,
      directory: projectProvider.currentDirectory,
      remoteSyncGeneration: _remoteSelectionSyncGeneration,
      selectedProviderId: _selectedProviderId,
      selectedModelId: _selectedModelId,
      selectedAgentName: _selectedAgentName,
      recentModelsJson: json.encode(_recentModelKeys),
      modelUsageCountsJson: json.encode(_modelUsageCounts),
      selectedVariantMapJson: json.encode(_selectedVariantByModel),
      agentSelectionMemoryJson: json.encode(_encodeAgentSelectionMemory()),
      sessionSelectionOverridesJson: json.encode(serializedOverrides),
      syncRemote: syncRemote,
    );
  }

  Future<void> _persistSelectionStep(
    String field,
    Future<void> Function() action, {
    Object? value,
    int? sizeBytes,
  }) {
    return AppLogger.runPerformanceTask<void>(
      'selection_persist_$field',
      action,
      tags: const <String>{'chat:selection', 'persistence'},
      context: AppLogger.performanceLoggingEnabled
          ? <String, Object?>{
              'field': field,
              if (value != null) 'valueHash': AppLogger.safeContextId(value),
              if (sizeBytes != null) 'sizeBytes': sizeBytes,
            }
          : null,
    );
  }

  Future<void> _persistSelectionSnapshot(
    _SelectionPersistenceSnapshot snapshot, {
    required bool syncRemote,
  }) async {
    if (snapshot.selectedProviderId != null) {
      await _persistSelectionStep(
        'selected_provider',
        () => localDataSource.saveSelectedProvider(
          snapshot.selectedProviderId!,
          serverId: snapshot.serverId,
          scopeId: snapshot.scopeId,
        ),
        value: snapshot.selectedProviderId,
      );
    }
    if (snapshot.selectedModelId != null) {
      await _persistSelectionStep(
        'selected_model',
        () => localDataSource.saveSelectedModel(
          snapshot.selectedModelId!,
          serverId: snapshot.serverId,
          scopeId: snapshot.scopeId,
        ),
        value: snapshot.selectedModelId,
      );
    }
    await _persistSelectionStep(
      'selected_agent',
      () => localDataSource.saveSelectedAgent(
        snapshot.selectedAgentName,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      value: snapshot.selectedAgentName,
    );
    await _persistSelectionStep(
      'recent_models',
      () => localDataSource.saveRecentModelsJson(
        snapshot.recentModelsJson,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      sizeBytes: snapshot.recentModelsJson.length,
    );
    await _persistSelectionStep(
      'model_usage_counts',
      () => localDataSource.saveModelUsageCountsJson(
        snapshot.modelUsageCountsJson,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      sizeBytes: snapshot.modelUsageCountsJson.length,
    );
    await _persistSelectionStep(
      'selected_variant_map',
      () => localDataSource.saveSelectedVariantMap(
        snapshot.selectedVariantMapJson,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      sizeBytes: snapshot.selectedVariantMapJson.length,
    );
    await _persistSelectionStep(
      'agent_selection_memory',
      () => localDataSource.saveAgentSelectionMemoryJson(
        snapshot.agentSelectionMemoryJson,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      sizeBytes: snapshot.agentSelectionMemoryJson.length,
    );
    await _persistSelectionStep(
      'session_selection_overrides',
      () => localDataSource.saveSessionSelectionOverridesJson(
        snapshot.sessionSelectionOverridesJson,
        serverId: snapshot.serverId,
        scopeId: snapshot.scopeId,
      ),
      sizeBytes: snapshot.sessionSelectionOverridesJson.length,
    );
    if (syncRemote) {
      if (snapshot.contextKey != _activeContextKey ||
          snapshot.remoteSyncGeneration != _remoteSelectionSyncGeneration) {
        return;
      }
      if (!_isExperimentalMultiDeviceSyncEnabled) {
        _pendingRemoteSelectionSync = false;
        _pendingRemoteSelectionSyncSince = null;
        _setSelectionSyncTransactionPhase(
          _SelectionSyncTransactionPhase.idle,
          reason: 'sync-disabled',
        );
        return;
      }
      if (_shouldDeferRemoteSelectionSync) {
        _markPendingRemoteSelectionSync(reason: 'active-response');
      } else {
        _pendingRemoteSelectionSync = false;
        _pendingRemoteSelectionSyncSince = null;
        _setSelectionSyncTransactionPhase(
          _SelectionSyncTransactionPhase.pendingRemote,
          reason: 'immediate-sync',
        );
        await _runSelectionSyncTransaction(
          reason: 'immediate-sync',
          directory: snapshot.directory,
          directoryExplicit: true,
        );
      }
    }
  }

  void _scheduleSelectionPersistence({bool syncRemote = true}) {
    _selectionPersistenceDirty = true;
    _selectionPersistenceSyncRemote =
        syncRemote || _selectionPersistenceSyncRemote;
    // Capture the originating scope now (see field docs): the flush may run
    // after a project switch. Values stay live and are re-read at flush.
    final serverId = _activeServerId.trim().isEmpty
        ? 'legacy'
        : _activeServerId;
    _scheduledSelectionOrigin = _SelectionPersistenceOrigin(
      serverId: serverId,
      scopeId: _resolveContextScopeId(),
      contextKey: _activeContextKey,
      directory: projectProvider.currentDirectory,
      remoteSyncGeneration: _remoteSelectionSyncGeneration,
      syncRemote: _selectionPersistenceSyncRemote,
    );
    if (localDataSource is! AppLocalDataSourceImpl) {
      if (_selectionPersistenceTask != null) return;
      final task = _flushScheduledSelectionPersistence();
      _selectionPersistenceTask = task;
      unawaited(task);
      return;
    }
    _selectionPersistenceGeneration++;
    final generation = _selectionPersistenceGeneration;
    _selectionPersistenceDebounce?.cancel();
    _selectionPersistenceDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        _selectionPersistenceDebounce = null;
        if (generation != _selectionPersistenceGeneration) return;
        if (_selectionPersistenceTask != null) return;
        final task = _flushScheduledSelectionPersistence();
        _selectionPersistenceTask = task;
        unawaited(task);
      },
    );
  }

  Future<void> flushSelectionPersistence() async {
    _selectionPersistenceDebounce?.cancel();
    _selectionPersistenceDebounce = null;
    if (!_selectionPersistenceDirty && _selectionPersistenceTask == null) return;
    if (_selectionPersistenceTask != null) {
      await _selectionPersistenceTask;
    }
    if (_selectionPersistenceDirty) {
      final task = _flushScheduledSelectionPersistence();
      _selectionPersistenceTask = task;
      await task;
    }
  }

  @visibleForTesting
  Future<void> debugWaitForSelectionPersistence() =>
      flushSelectionPersistence();

  Future<void> _flushScheduledSelectionPersistence() {
    return AppLogger.runPerformanceTask<void>(
      'selection_persistence_flush',
      _flushScheduledSelectionPersistenceBody,
      tags: const <String>{'chat:selection', 'persistence'},
      context: <String, Object?>{'syncRemote': _selectionPersistenceSyncRemote},
    );
  }

  Future<void> _flushScheduledSelectionPersistenceBody() async {
    try {
      while (true) {
        if (!_selectionPersistenceDirty) {
          break;
        }
        _selectionPersistenceDirty = false;
        final syncRemote = _selectionPersistenceSyncRemote;
        _selectionPersistenceSyncRemote = false;
        // Rebase fresh values onto the scheduling origin: scope identity is
        // pinned at schedule time, values are always current.
        final origin = _scheduledSelectionOrigin;
        _scheduledSelectionOrigin = null;
        final fresh = _captureSelectionPersistenceSnapshot(
          syncRemote: origin?.syncRemote ?? syncRemote,
        );
        final snapshot = origin == null ? fresh : fresh.applyingOrigin(origin);
        await _persistSelectionSnapshot(snapshot, syncRemote: snapshot.syncRemote);
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Selection persistence flush failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _selectionPersistenceTask = null;
    }
    if (_selectionPersistenceDirty) {
      final retryTask = _flushScheduledSelectionPersistence();
      _selectionPersistenceTask = retryTask;
      unawaited(retryTask);
      return;
    }
    _selectionPersistenceTask = null;
  }

  Future<void> onProjectScopeChanged({
    bool waitForRevalidation = true,
    String? newlyOpenedDirectory,
  }) async {
    await _switchContext(
      reason: 'project',
      waitForRevalidation: waitForRevalidation,
      newlyOpenedDirectory: newlyOpenedDirectory,
    );
  }

  /// Reset provider state and reload server-scoped data.
  Future<void> onServerScopeChanged() async {
    await _switchContext(reason: 'server');
  }

  Future<void> _persistSelection({bool syncRemote = true}) async {
    final snapshot = _captureSelectionPersistenceSnapshot(
      syncRemote: syncRemote,
    );
    await _persistSelectionSnapshot(snapshot, syncRemote: syncRemote);
  }

  Future<void> setSelectedProvider(String providerId) {
    return AppLogger.runPerformanceTask<void>(
      'selection_set_provider',
      () => _setSelectedProvider(providerId),
      tags: const <String>{'chat:selection', 'desktop:menu'},
      context: AppLogger.performanceLoggingEnabled
          ? <String, Object?>{
              'providerHash': AppLogger.safeContextId(providerId),
            }
          : null,
    );
  }

  Future<void> _setSelectedProvider(String providerId) async {
    final provider = _providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null || !_hasUserSelectableModels(provider)) {
      return;
    }
    final previousModelKey = _currentModelKey();
    _selectedProviderId = provider.id;

    String? nextModelId;
    if (_selectedModelId != null &&
        _isUserSelectableModelId(provider, _selectedModelId!)) {
      nextModelId = _selectedModelId;
    }

    if (nextModelId == null) {
      for (final recentModelKey in _recentModelKeys) {
        final recentProviderId = _providerFromModelKey(recentModelKey);
        final recentModelId = _modelFromModelKey(recentModelKey);
        if (recentProviderId == provider.id &&
            recentModelId != null &&
            _isUserSelectableModelId(provider, recentModelId)) {
          nextModelId = recentModelId;
          break;
        }
      }
    }

    if (nextModelId == null) {
      final defaultModelId = _defaultModels[provider.id];
      if (defaultModelId != null &&
          _isUserSelectableModelId(provider, defaultModelId)) {
        nextModelId = defaultModelId;
      }
    }

    nextModelId ??= _firstUserSelectableModelId(provider);
    _selectedModelId = nextModelId;
    _selectedVariantId = _resolveStoredVariantForSelection();
    _rememberCurrentSelectionForAgent(agentName: _selectedAgentName);
    _recordModelSelectionRecency(previousModelKey: previousModelKey);
    _recordVariantSelectionRecencyForCurrentModel();
    _storeCurrentSessionSelectionOverride(isExplicit: true);
    _notifyListeners(reason: 'selection_set_provider');
    _scheduleSelectionPersistence();
  }

  Future<void> setSelectedModelByProvider({
    required String providerId,
    required String modelId,
  }) {
    return AppLogger.runPerformanceTask<void>(
      'selection_set_model',
      () =>
          _setSelectedModelByProvider(providerId: providerId, modelId: modelId),
      tags: const <String>{'chat:selection', 'desktop:menu'},
      context: AppLogger.performanceLoggingEnabled
          ? <String, Object?>{
              'providerHash': AppLogger.safeContextId(providerId),
              'modelHash': AppLogger.safeContextId(modelId),
            }
          : null,
    );
  }

  Future<void> _setSelectedModelByProvider({
    required String providerId,
    required String modelId,
  }) async {
    final provider = _providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null || !_isUserSelectableModelId(provider, modelId)) {
      return;
    }
    final previousModelKey = _currentModelKey();
    _selectedProviderId = providerId;
    _selectedModelId = modelId;
    _selectedVariantId = _resolveStoredVariantForSelection();
    _rememberCurrentSelectionForAgent(agentName: _selectedAgentName);
    _recordModelSelectionRecency(previousModelKey: previousModelKey);
    _recordVariantSelectionRecencyForCurrentModel();
    _storeCurrentSessionSelectionOverride(isExplicit: true);
    _notifyListeners(reason: 'selection_set_model');
    _scheduleSelectionPersistence();
  }

  Future<void> setSelectedModel(String modelId) async {
    final provider = selectedProvider;
    if (provider == null || !_isUserSelectableModelId(provider, modelId)) {
      return;
    }
    await setSelectedModelByProvider(providerId: provider.id, modelId: modelId);
  }

  Future<void> cycleRecentModelShortcut() {
    return AppLogger.runPerformanceTask<void>(
      'selection_cycle_model_shortcut',
      _cycleRecentModelShortcut,
      tags: const <String>{'chat:selection', 'keyboard:shortcut'},
      context: const <String, Object?>{'source': 'shortcut'},
    );
  }

  Future<void> _cycleRecentModelShortcut() async {
    final candidates = _availableModelCycleKeys();
    if (candidates.isEmpty) {
      return;
    }

    final currentModelKey = _currentModelKey();
    final nextModelKey = _nextShortcutCycleTarget(
      domain: _ShortcutCycleDomain.model,
      currentKey: currentModelKey,
      candidateKeys: candidates,
      historyKeys: _recentModelKeys,
    );
    if (nextModelKey == null || nextModelKey == currentModelKey) {
      return;
    }

    final providerId = _providerFromModelKey(nextModelKey);
    final modelId = _modelFromModelKey(nextModelKey);
    if (providerId == null || modelId == null) {
      return;
    }

    await setSelectedModelByProvider(providerId: providerId, modelId: modelId);
  }

  Future<void> setSelectedAgent(String agentName) {
    return AppLogger.runPerformanceTask<void>(
      'selection_set_agent',
      () => _setSelectedAgent(agentName),
      tags: const <String>{'chat:selection', 'desktop:menu'},
      context: AppLogger.performanceLoggingEnabled
          ? <String, Object?>{'agentHash': AppLogger.safeContextId(agentName)}
          : null,
    );
  }

  Future<void> _setSelectedAgent(String agentName) async {
    final candidate = agentName.trim();
    if (candidate.isEmpty) {
      return;
    }
    final next = _resolvePreferredAgentName(_agents, candidate);
    if (next == null) {
      return;
    }
    if (_selectedAgentName == next) {
      return;
    }
    final previousAgentName = _selectedAgentName;
    _rememberCurrentSelectionForAgent(agentName: previousAgentName);
    _selectedAgentName = next;
    _restoreSelectionForAgent(next);
    _recordAgentSelectionRecency(previousAgentName: previousAgentName);
    _storeCurrentSessionSelectionOverride(isExplicit: true);
    _notifyListeners(reason: 'selection_set_agent');
    _scheduleSelectionPersistence();
  }

  Future<void> setSelectedVariant(String? variantId) {
    return AppLogger.runPerformanceTask<void>(
      'selection_set_variant',
      () => _setSelectedVariant(variantId),
      tags: const <String>{'chat:selection', 'desktop:menu'},
      context: AppLogger.performanceLoggingEnabled
          ? <String, Object?>{'variantHash': AppLogger.safeContextId(variantId)}
          : null,
    );
  }

  Future<void> _setSelectedVariant(String? variantId) async {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    final model = selectedModel;
    if (providerId == null || modelId == null || model == null) {
      return;
    }

    final modelKey = _modelKey(providerId, modelId);
    final previousVariantId = _selectedVariantId;
    if (variantId == null || variantId.trim().isEmpty) {
      _selectedVariantId = null;
      _selectedVariantByModel.remove(modelKey);
    } else if (model.variants.containsKey(variantId)) {
      _selectedVariantId = variantId;
      _selectedVariantByModel[modelKey] = variantId;
    } else {
      _selectedVariantId = null;
      _selectedVariantByModel.remove(modelKey);
    }

    _recordVariantSelectionRecencyForCurrentModel(
      previousVariantId: previousVariantId,
    );
    _rememberCurrentSelectionForAgent(agentName: _selectedAgentName);

    _storeCurrentSessionSelectionOverride(isExplicit: true);
    _notifyListeners(reason: 'selection_set_variant');
    _scheduleSelectionPersistence();
  }

  Future<void> cycleVariant() {
    return AppLogger.runPerformanceTask<void>(
      'selection_cycle_variant_shortcut',
      _cycleVariant,
      tags: const <String>{'chat:selection', 'keyboard:shortcut'},
      context: const <String, Object?>{'source': 'shortcut'},
    );
  }

  Future<void> _cycleVariant() async {
    final model = selectedModel;
    if (model == null || model.variants.isEmpty) {
      return;
    }
    final currentModelKey = _currentModelKey();
    if (currentModelKey == null) {
      return;
    }
    final nextVariantValue = _nextShortcutCycleTarget(
      domain: _ShortcutCycleDomain.variant,
      currentKey: _variantHistoryValue(_selectedVariantId),
      candidateKeys: _availableVariantCycleValues(model),
      historyKeys:
          _recentVariantValuesByModel[currentModelKey] ?? const <String>[],
    );
    if (nextVariantValue == null) {
      return;
    }
    final nextVariantId = _variantIdFromHistoryValue(nextVariantValue);
    if (nextVariantId == _selectedVariantId) {
      return;
    }
    await setSelectedVariant(nextVariantId);
  }

  /// Cycle to the next (or previous) selectable agent.
  /// Returns the name of the newly selected agent, or null when the list
  /// is empty and no cycling was performed.
  Future<String?> cycleAgent({bool reverse = false}) {
    return AppLogger.runPerformanceTask<String?>(
      'selection_cycle_agent_shortcut',
      () => _cycleAgent(reverse: reverse),
      tags: const <String>{'chat:selection', 'keyboard:shortcut'},
      context: <String, Object?>{'reverse': reverse},
    );
  }

  Future<String?> _cycleAgent({bool reverse = false}) async {
    final candidates = selectableAgents
        .map((agent) => agent.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }

    final nextAgentName = _nextShortcutCycleTarget(
      domain: _ShortcutCycleDomain.agent,
      currentKey: _selectedAgentName,
      candidateKeys: candidates,
      historyKeys: _recentAgentNames,
      reverse: reverse,
    );
    if (nextAgentName == null) {
      return null;
    }
    if (nextAgentName == _selectedAgentName) {
      return nextAgentName;
    }

    await setSelectedAgent(nextAgentName);
    return nextAgentName;
  }

  bool isModelFavorite({required String providerId, required String modelId}) {
    return _favoriteModelKeys.contains(_modelKey(providerId, modelId));
  }

  bool isSessionPinned(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return false;
    }
    return _pinnedSessionIds.contains(normalizedSessionId);
  }

  /// Toggle a model as favorite (local-only, no remote sync).
  Future<void> toggleModelFavorite({
    required String providerId,
    required String modelId,
  }) async {
    final key = _modelKey(providerId, modelId);
    _favoriteModelKeys = List<String>.from(_favoriteModelKeys);
    if (_favoriteModelKeys.contains(key)) {
      _favoriteModelKeys.remove(key);
    } else {
      _favoriteModelKeys.add(key);
    }
    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    await _persistModelPreferenceState(serverId: serverId, scopeId: scopeId);
    notifyListeners();
  }

  Future<void> toggleSessionPinned(
    ChatSession session, {
    SessionActionTarget? target,
  }) async {
    final sessionId = session.id.trim();
    if (sessionId.isEmpty) {
      return;
    }
    if (target != null) {
      if (!target.isValid) return;
      await _togglePinnedForTarget(target, sessionId);
      return;
    }

    final serverId = await _resolveServerScopeId();
    final identity = _sessionTabIdentityForSession(
      session,
      contextKey: _activeContextKey,
    );
    final scopeId = _activePinnedSessionScopeId() ?? _resolveContextScopeId();
    final nextPinned = !_pinnedSessionIds.contains(sessionId);
    final existingTab = identity == null
        ? null
        : _sessionTabs.where((tab) => tab.identity == identity).firstOrNull;
    final changed = _setActiveSessionPin(
      serverId: serverId,
      scopeId: scopeId,
      sessionId: sessionId,
      pinned: nextPinned,
    );
    if (!changed) return;
    if (!nextPinned && identity != null && existingTab != null) {
      _setSessionTabPin(
        identity,
        pinned: false,
        pinScopeIds: existingTab.pinScopeIds,
        persist: true,
      );
    }
    _sortSessionsInPlace();
    await _persistPinnedSessionScope(
      serverId: serverId,
      scopeId: scopeId,
      ids: _pinnedSessionIds,
    );
    await Future.wait(_pinnedSessionWriteQueueByScope.values.toList());
    _reconcileSessionTabs(forcePersistence: true, notify: false);
    notifyListeners();
  }

  /// Load session list
  Future<void> loadSessions({
    bool preserveVisibleState = false,
    bool userInitiated = false,
    bool refreshSelectedSessionMessages = true,
    bool refreshSessionStatus = true,
    bool restoreLastSessionSnapshot = true,
  }) async {
    return AppLogger.runPerformanceTask<void>(
      'load_sessions',
      () async {
        if (_sessionTabsDisposed) return;
        if (_state == ChatState.loading && !preserveVisibleState) return;
        if (userInitiated) {
          _cellularDataSaverService.noteExplicitUserAction(
            reason: 'load-sessions',
          );
          await _syncCellularDataSaverRealtimePolicy(
            reason: 'load-sessions-user',
            forceBurst: true,
          );
        }
        final fetchId = ++_sessionsFetchId;

        final canKeepVisibleState =
            preserveVisibleState && _sessions.isNotEmpty;
        if (!canKeepVisibleState) {
          _setState(ChatState.loading);
        }
        clearError();

        final serverId = await _resolveServerScopeId();
        final scopeId = _resolveContextScopeId();
        final bootstrapDirectory = _sessionTabBootstrapDirectory;
        final bootstrapGeneration = _sessionTabBootstrapGeneration;
        await _ensureSessionTabsLoaded(serverId: serverId);
        unawaited(
          Future<void>(() async {
            try {
              await localDataSource.migrateLegacyLargeCachePayloads();
            } catch (_) {
              // Cache migration must never block the server-authoritative path.
            }
          }),
        );
        final storedSessionId = await localDataSource.getCurrentSessionId(
          serverId: serverId,
          scopeId: scopeId,
        );

        try {
          // First try loading from cache
          await _loadCachedSessions(serverId: serverId, scopeId: scopeId);
          if (restoreLastSessionSnapshot) {
            await _restoreLastSessionSnapshotFromCache(
              serverId: serverId,
              scopeId: scopeId,
              preferredSessionId: storedSessionId,
            );
          }
          _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);

          Future<void> revalidateFromServer({
            required bool preserveVisibleDataOnFailure,
          }) async {
            if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
              return;
            }
            final result = await getChatSessions(
              GetChatSessionsParams(
                directory: projectProvider.currentDirectory,
              ),
            );

            if (fetchId != _sessionsFetchId ||
                _cellularDataSaverService.shouldSuppressBackgroundWork) {
              return;
            }

            if (result.isLeft()) {
              if (fetchId != _sessionsFetchId) {
                return;
              }
              final failure = result.fold((f) => f, (_) => null);
              if (failure != null) {
                if (preserveVisibleDataOnFailure) {
                  AppLogger.warn(
                    'Background session revalidation failed for scope=$scopeId',
                    error: failure,
                  );
                  _setState(ChatState.loaded);
                } else {
                  _handleFailure(failure);
                }
              }
              return;
            }

            final sessions = result.fold(
              (_) => <ChatSession>[],
              (value) => value,
            );
            final filteredSessions = _filterSessionsForCurrentContext(sessions);
            if (fetchId != _sessionsFetchId ||
                _cellularDataSaverService.shouldSuppressBackgroundWork) {
              return;
            }
            _sessions = filteredSessions;
            _hasLoadedSessionsAuthoritatively = true;
            _threadPermissionsVersion++;
            _sessionVisibleLimit = 40;
            _prunePinnedSessionIdsToKnownSessions();
            _sortSessionsInPlace();
            _pruneSessionAttentionStateToKnownSessions();
            _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
            _markAuthoritativeSessionTabBootstrapOpened(bootstrapDirectory);
            _setState(ChatState.loaded);

            // #134: a project with no sessions has exactly one useful next
            // state — an empty conversation ready for input — so the redundant
            // "New chat" gate is skipped. Only reached after an authoritative
            // load, never during loading, an error or an unresolved context,
            // and it never overrides a session or a draft already in place.
            // No remote session is created here; that still happens lazily on
            // the first send.
            if (filteredSessions.isEmpty &&
                _currentSession == null &&
                !_isNewChatDraftActive) {
              await beginNewChatDraft();
              if (fetchId != _sessionsFetchId) {
                return;
              }
            }

            await _saveCachedSessions(
              filteredSessions,
              serverId: serverId,
              scopeId: scopeId,
            );

            if (fetchId != _sessionsFetchId ||
                _cellularDataSaverService.shouldSuppressBackgroundWork) {
              return;
            }

            await loadLastSession(
              serverId: serverId,
              scopeId: scopeId,
              storedSessionId: storedSessionId,
              refreshMessages: refreshSelectedSessionMessages,
            );
            if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
              return;
            }
            if (refreshSessionStatus) {
              await refreshSessionStatusSnapshot();
            }
            if (bootstrapDirectory != null &&
                _sessionTabBootstrapGeneration == bootstrapGeneration &&
                _sessionTabBootstrapDirectory == bootstrapDirectory &&
                areEquivalentFilePaths(
                  projectProvider.currentDirectory,
                  bootstrapDirectory,
                )) {
              _sessionTabBootstrapDirectory = null;
              _sessionTabBootstrapGeneration += 1;
            }
          }

          final canRevalidateInBackground =
              preserveVisibleState && _sessions.isNotEmpty;
          if (canRevalidateInBackground) {
            unawaited(
              revalidateFromServer(
                preserveVisibleDataOnFailure: true,
              ).catchError((Object error, StackTrace stackTrace) {
                if (fetchId != _sessionsFetchId) {
                  return;
                }
                AppLogger.warn(
                  'Background session revalidation threw unexpectedly',
                  error: error,
                  stackTrace: stackTrace,
                );
              }),
            );
            return;
          }

          await revalidateFromServer(preserveVisibleDataOnFailure: false);
        } catch (e, stackTrace) {
          if (fetchId != _sessionsFetchId) {
            return;
          }
          if (preserveVisibleState && _sessions.isNotEmpty) {
            AppLogger.warn(
              'Failed to load session list during background refresh',
              error: e,
              stackTrace: stackTrace,
            );
            _setState(ChatState.loaded);
            return;
          }
          AppLogger.error(
            'Failed to load session list',
            error: e,
            stackTrace: stackTrace,
          );
          _setError(
            L10nBridge.current?.chatProviderErrorLoadSessionList('$e') ??
                'Failed to load session list: $e',
          );
        }
      },
      tags: const <String>{'chat:sessions'},
      contextBuilder: () => <String, Object?>{
        'preserveVisibleState': preserveVisibleState,
        'userInitiated': userInitiated,
        'projectHash': AppLogger.safeContextId(
          projectProvider.currentProjectId,
        ),
        'scopeHash': AppLogger.safeContextId(_resolveContextScopeId()),
      },
    );
  }

  /// Load sessions from cache

  /// Save sessions to cache

  /// Save current session ID

  /// Load last selected session
  Future<void> loadLastSession({
    required String serverId,
    required String scopeId,
    String? storedSessionId,
    bool refreshMessages = true,
    int? expectedSelectionGeneration,
    String? expectedContextKey,
  }) async {
    bool isExpectedSelectionCurrent() {
      return (expectedSelectionGeneration == null ||
              expectedSelectionGeneration == _sessionSelectionGeneration) &&
          (expectedContextKey == null ||
              expectedContextKey == _activeContextKey);
    }

    try {
      if (!isExpectedSelectionCurrent()) return;
      if (_sessions.isEmpty) {
        _currentSession = null;
        _pendingCurrentSessionHydrationId = null;
        _threadPermissionsVersion++;
        _messages = <ChatMessage>[];
        _isLoadingOlderMessages = false;
        _hasMoreOldMessages = messages.length >= _initialMessagesWindowSize;
        _messagesVersion++;
        _clearPendingReplacementBranch();
        await _clearLastSessionSnapshotBestEffort(
          serverId: serverId,
          scopeId: scopeId,
        );
        _reconcileSessionTabs();
        return;
      }

      final resolvedStoredSessionId =
          storedSessionId ??
          await localDataSource.getCurrentSessionId(
            serverId: serverId,
            scopeId: scopeId,
          );
      if (!isExpectedSelectionCurrent()) return;
      if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
        return;
      }

      if (_isNewChatDraftActive) {
        _currentSession = null;
        _pendingCurrentSessionHydrationId = null;
        _threadPermissionsVersion++;
        _messages = <ChatMessage>[];
        _isLoadingOlderMessages = false;
        _hasMoreOldMessages = false;
        _messagesVersion++;
        _clearPendingReplacementBranch();
        _reconcileSessionTabs();
        _setState(ChatState.loaded);
        return;
      }

      // Prefer the in-memory session over the persisted ID to avoid reverting
      // a session switch that already updated _currentSession but whose
      // persistence write is still in flight.
      ChatSession? targetSession;
      final inMemorySessionId = _currentSession?.id;
      if (inMemorySessionId != null) {
        targetSession = _sessions
            .where((session) => session.id == inMemorySessionId)
            .firstOrNull;
      }
      if (targetSession == null &&
          resolvedStoredSessionId != null &&
          resolvedStoredSessionId.trim().isNotEmpty) {
        targetSession = _sessions
            .where((session) => session.id == resolvedStoredSessionId)
            .firstOrNull;
      }
      targetSession ??= _sessions.reduce((left, right) {
        return left.time.isAfter(right.time) ? left : right;
      });

      if (_currentSession?.id != targetSession.id) {
        await selectSession(targetSession, userInitiated: false);
        return;
      }

      final currentSessionChanged = _currentSession != targetSession;
      final previousRevert = _currentSession?.revert;
      _currentSession = targetSession;
      _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
      if (previousRevert != targetSession.revert) {
        _messagesVersion++;
      }
      final appliedSessionOverride = _applySelectionPriorityForCurrentSession();
      if (currentSessionChanged || appliedSessionOverride) {
        notifyListeners();
      }

      if (!refreshMessages) {
        if (resolvedStoredSessionId != targetSession.id) {
          await _saveCurrentSessionId(
            targetSession.id,
            serverId: serverId,
            scopeId: scopeId,
          );
        }
        return;
      }

      if (_messages.isEmpty) {
        final restoredCachedMessages = await _restoreSessionMessagesFromCache(
          targetSession.id,
          serverId: serverId,
          scopeId: scopeId,
        );
        if (!isExpectedSelectionCurrent()) return;
        if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        if (restoredCachedMessages != null &&
            restoredCachedMessages.isNotEmpty) {
          _pendingCurrentSessionHydrationId = null;
          _messages = List<ChatMessage>.from(restoredCachedMessages);
          _cacheSessionMessages(targetSession.id, _messages);
          _hasMoreOldMessages =
              restoredCachedMessages.length >= _initialMessagesWindowSize;
          _messagesVersion++;
          _setState(ChatState.loaded);
          // Re-apply selection priority now that messages are available — the
          // initial call above may not have found cached messages for the
          // message-derived fallback (Feature 7).
          final lateSelectionChanged =
              _applySelectionPriorityForCurrentSession();
          if (lateSelectionChanged) {
            _notifyListeners();
          }
          unawaited(
            loadMessages(
              targetSession.id,
              preserveVisibleState: true,
              automatic: true,
            ),
          );
        } else {
          await loadMessages(targetSession.id, automatic: true);
          if (!isExpectedSelectionCurrent()) return;
        }
      } else {
        if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        unawaited(
          loadMessages(
            targetSession.id,
            preserveVisibleState: true,
            automatic: true,
          ),
        );
      }

      if (!isExpectedSelectionCurrent()) return;
      if (!_cellularDataSaverService.isAggressiveDataSaverActive) {
        // Cold start / project-switch restore keeps the persisted session but
        // must also revalidate pending interactions; questions are not part of
        // the persisted snapshot (issue #143). Aggressive mode keeps its
        // visible-only semantics (a full load here would run the wipe when no
        // visible session exists yet and pause realtime).
        unawaited(_loadPendingInteractions());
      }
      if (resolvedStoredSessionId != targetSession.id) {
        await _saveCurrentSessionId(
          targetSession.id,
          serverId: serverId,
          scopeId: scopeId,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to load last session',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create new session
  Future<void> beginNewChatDraft() async {
    final outgoingSessionId = _currentSession?.id;
    if (outgoingSessionId != null && _messages.isNotEmpty) {
      _cacheSessionMessages(outgoingSessionId, _messages);
      unawaited(
        _persistSessionMessagesSnapshotBestEffort(outgoingSessionId, _messages),
      );
    }

    _newChatDraftGeneration++;
    _lazySessionBootstrapTask = null;
    _currentSession = null;
    _isNewChatDraftActive = true;
    _threadPermissionsVersion++;
    _messages = <ChatMessage>[];
    _isLoadingOlderMessages = false;
    _hasMoreOldMessages = false;
    _messagesVersion++;
    _clearPendingReplacementBranch();
    _pendingLocalUserMessageIds.clear();
    _clearRejectedDraft();
    _sessionInsightsError = null;

    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    await _ensureSessionTabsLoaded(serverId: serverId);
    await _saveCurrentSessionId('', serverId: serverId, scopeId: scopeId);

    _setState(ChatState.loaded);
  }

  /// Create new session
  Future<void> createNewSession({String? parentId, String? title}) async {
    final contextKeyAtStart = _activeContextKey;
    final draftGenerationAtStart = _newChatDraftGeneration;
    final selectionGenerationAtStart = _sessionSelectionGeneration;
    final wasDraftActive = _isNewChatDraftActive;
    final projectId = projectProvider.currentProjectId;
    final directory = projectProvider.currentDirectory;
    final serverIdAtStart =
        _serverIdFromContextKey(contextKeyAtStart) ?? _activeServerId;
    final scopeIdAtStart =
        _scopeIdFromContextKey(contextKeyAtStart) ?? _resolveContextScopeId();

    bool isCurrentCreation() {
      return contextKeyAtStart == _activeContextKey &&
          draftGenerationAtStart == _newChatDraftGeneration &&
          selectionGenerationAtStart == _sessionSelectionGeneration;
    }

    _setState(ChatState.loading);

    // Generate time-based title
    final now = DateTime.now();
    final defaultTitle = title ?? _generateSessionTitle(now);

    final result = await createChatSession(
      CreateChatSessionParams(
        projectId: projectId,
        input: SessionCreateInput(parentId: parentId, title: defaultTitle),
        directory: directory,
      ),
    );

    if (!isCurrentCreation()) {
      AppLogger.info(
        'Ignoring stale createNewSession result context=$contextKeyAtStart current=$_activeContextKey draftGeneration=$draftGenerationAtStart currentDraftGeneration=$_newChatDraftGeneration selectionGeneration=$selectionGenerationAtStart currentSelectionGeneration=$_sessionSelectionGeneration',
      );
      return;
    }

    if (result.isLeft()) {
      final failure = result.fold((value) => value, (_) => null);
      if (failure != null) {
        _handleFailure(failure);
      }
      return;
    }

    final session = result.fold((_) => null, (value) => value);
    if (session == null) {
      _setError(
        L10nBridge.current?.chatProviderErrorCreateSession ??
            'Failed to create session',
      );
      return;
    }

    await _ensureSessionTabsLoaded(serverId: serverIdAtStart);
    if (!isCurrentCreation()) {
      AppLogger.info(
        'Ignoring stale createNewSession commit context=$contextKeyAtStart current=$_activeContextKey draftGeneration=$draftGenerationAtStart currentDraftGeneration=$_newChatDraftGeneration selectionGeneration=$selectionGenerationAtStart currentSelectionGeneration=$_sessionSelectionGeneration',
      );
      return;
    }

    _sessions = List<ChatSession>.from(_sessions);
    _removeSessionById(session.id, removePin: false);
    _sessions.add(session);
    _sortSessionsInPlace();
    _currentSession = session;
    _dismissNotificationsForSession(session.id);
    _threadPermissionsVersion++;
    _messages = <ChatMessage>[];
    _isLoadingOlderMessages = false;
    _hasMoreOldMessages = false;
    _messagesVersion++;
    _clearPendingReplacementBranch();
    _pendingLocalUserMessageIds.clear();
    _clearRejectedDraft();
    _sessionInsightsError = null;

    _storeCurrentSessionSelectionOverride();
    _recordVisibleSessionTab(session);
    if (wasDraftActive) {
      _isNewChatDraftActive = false;
    }
    _setState(ChatState.loaded);

    await _saveCurrentSessionId(
      session.id,
      serverId: serverIdAtStart,
      scopeId: scopeIdAtStart,
    );
    unawaited(
      _persistLastSessionSnapshotBestEffort(
        serverId: serverIdAtStart,
        scopeId: scopeIdAtStart,
      ),
    );
    unawaited(
      _persistSessionCacheBestEffort(
        serverId: serverIdAtStart,
        scopeId: scopeIdAtStart,
      ),
    );
    unawaited(loadSessionInsights(session.id, silent: true));
  }

  /// Generate time-based session title

  /// Select session
  Future<void> selectSession(
    ChatSession session, {
    bool userInitiated = true,
    bool awaitNetwork = true,
  }) async {
    _sessionSelectionGeneration += 1;
    if (userInitiated && _isNewChatDraftActive) {
      _newChatDraftGeneration++;
    }
    final previousSessionId = _currentSession?.id;
    return AppLogger.runPerformanceTask<void>(
      'select_session',
      () async {
        if (userInitiated) {
          _cellularDataSaverService.noteExplicitUserAction(
            reason: 'select-session',
          );
          final realtimePolicySync = _syncCellularDataSaverRealtimePolicy(
            reason: 'select-session-user',
            forceBurst: true,
          );
          if (awaitNetwork) {
            await realtimePolicySync;
          } else {
            unawaited(realtimePolicySync);
          }
        } else {
          if (_cellularDataSaverService.shouldSuppressBackgroundWork) {
            return;
          }
          final realtimePolicySync = _syncCellularDataSaverRealtimePolicy(
            reason: 'select-session-automatic',
          );
          if (awaitNetwork) {
            await realtimePolicySync;
          } else {
            unawaited(realtimePolicySync);
          }
        }
        _isNewChatDraftActive = false;
        if (_currentSession?.id == session.id) {
          _dismissNotificationsForSession(session.id);
          _recordVisibleSessionTab(session);
          if (userInitiated) {
            // Re-selecting the already-current session must still revalidate
            // pending interactions: the server does not replay SSE events
            // after a gap (background/stream loss), so GET /question is the
            // only way to recover a question that arrived while away.
            if (!_cellularDataSaverService.isAggressiveDataSaverActive) {
              // Revalidation also covers standard data saver; aggressive mode
              // relies on its visible-session-only reload path (a full load
              // here would run the aggressive wipe when no visible session
              // exists and pause realtime).
              unawaited(_loadPendingInteractions());
            }
            unawaited(
              loadSessionInsights(
                session.id,
                silent: true,
                userInitiated: userInitiated,
              ),
            );
          }
          return;
        }

        final outgoingSessionId = _currentSession?.id;
        if (outgoingSessionId != null && _messages.isNotEmpty) {
          _cacheSessionMessages(outgoingSessionId, _messages);
          unawaited(
            _persistSessionMessagesSnapshotBestEffort(
              outgoingSessionId,
              _messages,
            ),
          );
        }

        // Invalidate any concurrent loadSessions() that captured a stale
        // persisted session ID before this switch updated memory/disk.
        _sessionsFetchId += 1;

        _pendingLocalUserMessageIds.clear();
        _clearPendingReplacementBranch();
        _clearRejectedDraft();

        // Move selection ownership to the tapped session before awaiting stream
        // teardown so the UI can render session-scoped hydration feedback
        // immediately during cacheless switches.
        _messageStreamGeneration += 1;
        _currentSession = session;
        _isLoadingOlderMessages = false;
        _hasMoreOldMessages = false;
        _dismissNotificationsForSession(session.id);
        _clearSessionAttentionForSession(session.id);
        _threadPermissionsVersion++;
        _applySelectionPriorityForCurrentSession();
        if (_cellularDataSaverService.isDataSaverActive) {
          unawaited(
            _syncCellularDataSaverRealtimePolicy(
              reason: 'select-session-visible',
              forceBurst: true,
            ),
          );
        }
        if (_cellularDataSaverService.isAggressiveDataSaverActive) {
          unawaited(_loadPendingInteractions(visibleSessionOnly: true));
        } else {
          // Session re-entry must actively revalidate pending interactions
          // (ADR-020/ADR-003). The server does not replay question events
          // after a gap, so GET /question is the only authoritative recovery
          // source (issue #143). Aggressive data saver self-restricts above.
          unawaited(_loadPendingInteractions());
        }

        final warmCachedMessages = _cachedSessionMessages(session.id);
        final hasWarmCachedMessages =
            warmCachedMessages != null && warmCachedMessages.isNotEmpty;

        // Show the session-scoped hydration state immediately while cache lookup
        // and network hydration run, so cacheless switches never fall back to the
        // generic empty placeholder for a frame.
        if (hasWarmCachedMessages) {
          _pendingCurrentSessionHydrationId = null;
          _messages = List<ChatMessage>.from(warmCachedMessages);
          _cacheSessionMessages(session.id, _messages);
            _hasMoreOldMessages =
                _messages.length >= _initialMessagesWindowSize;
          _messagesVersion++;
          _setState(ChatState.loaded);
        } else {
          _pendingCurrentSessionHydrationId = session.id;
          _messages = <ChatMessage>[];
          _messagesVersion++;
          _setState(ChatState.loading);
        }

        final messageSubscriptionCancellation =
            _cancelActiveMessageSubscription(
              reason: 'session-switch',
              invalidateGeneration: false,
              timeout: awaitNetwork
                  ? const Duration(seconds: 2)
                  : const Duration(milliseconds: 100),
            );
        if (awaitNetwork) {
          await messageSubscriptionCancellation;
        } else {
          unawaited(messageSubscriptionCancellation);
        }
        AppLogger.info(
          'selectSession generation=$_messageStreamGeneration target=${session.id}',
        );

        // Save current session ID and try cache-first restore (SWR).
        final serverId = await _resolveServerScopeId();
        final scopeId = _resolveContextScopeId();
        await _ensureSessionTabsLoaded(serverId: serverId);
        if (_currentSession?.id == session.id) {
          _recordVisibleSessionTab(session);
        }
        final restoredComposerDraft = await _loadPersistedComposerDraft(
          session.id,
          serverId: serverId,
        );
        if (!userInitiated &&
            _cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        _queueHistoryComposerSync(
          sessionId: session.id,
          draft: restoredComposerDraft,
          clear: true,
        );

        final restoredCachedMessages = hasWarmCachedMessages
            ? warmCachedMessages
            : await _restoreSessionMessagesFromCache(
                session.id,
                serverId: serverId,
                scopeId: scopeId,
              );
        if (!userInitiated &&
            _cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }

        if (restoredCachedMessages != null &&
            restoredCachedMessages.isNotEmpty) {
          _pendingCurrentSessionHydrationId = null;
          final restoredMessages = List<ChatMessage>.from(
            restoredCachedMessages,
          );
          _hasMoreOldMessages =
              restoredCachedMessages.length >= _initialMessagesWindowSize;
          if (!_areMessageListsSemanticallyEqual(_messages, restoredMessages)) {
            _messages = restoredMessages;
            _cacheSessionMessages(session.id, _messages);
            _messagesVersion++;
            _setState(ChatState.loaded);
          }
          // Re-apply selection priority now that messages are available — the
          // initial call at the top of selectSession() may not have found cached
          // messages for the message-derived fallback (Feature 7).
          final selectionChanged = _applySelectionPriorityForCurrentSession();
          if (selectionChanged) {
            _notifyListeners();
          }
        } else {
          _pendingCurrentSessionHydrationId = session.id;
        }

        await _saveCurrentSessionId(
          session.id,
          serverId: serverId,
          scopeId: scopeId,
        );

        // SWR behavior: if cache exists, keep visible data and revalidate silently.
        if (restoredCachedMessages != null &&
            restoredCachedMessages.isNotEmpty) {
          unawaited(
            loadMessages(
              session.id,
              preserveVisibleState: true,
              automatic: !userInitiated,
            ),
          );
        } else if (!awaitNetwork) {
          unawaited(loadMessages(session.id, automatic: !userInitiated));
        } else {
          await loadMessages(session.id, automatic: !userInitiated);
        }

        // Insights are non-critical and run fire-and-forget.
        if (userInitiated) {
          unawaited(
            loadSessionInsights(
              session.id,
              silent: true,
              userInitiated: userInitiated,
            ),
          );
        }
      },
      tags: const <String>{'chat:session'},
      contextBuilder: () => <String, Object?>{
        'sessionHash': AppLogger.safeContextId(session.id),
        'previousSessionHash': AppLogger.safeContextId(previousSessionId),
      },
    );
  }

  /// Load message list
  Future<void> loadMessages(
    String sessionId, {
    bool preserveVisibleState = false,
    bool preferDelta = true,
    bool automatic = false,
  }) async {
    return AppLogger.runPerformanceTask<void>(
      'load_messages',
      () async {
        if (automatic &&
            _cellularDataSaverService.shouldSuppressBackgroundWork) {
          return;
        }
        final fetchId = ++_messagesFetchId;
        // Sync project ID from ProjectProvider; projectId is optional for the new API
        _currentProjectId = projectProvider.currentProjectId;

        final canKeepVisibleState =
            preserveVisibleState &&
            _currentSession?.id == sessionId &&
            _messages.isNotEmpty;
        final cachedMessages = canKeepVisibleState
            ? List<ChatMessage>.from(
                _messages.where((message) => message.sessionId == sessionId),
              )
            : const <ChatMessage>[];
        if (!canKeepVisibleState) {
          _setState(ChatState.loading);
        }

        final result = await getChatMessages(
          GetChatMessagesParams(
            projectId: projectProvider.currentProjectId,
            sessionId: sessionId,
            directory: projectProvider.currentDirectory,
            limit: canKeepVisibleState && preferDelta
                ? _swrMessageTailLimit
                : preferDelta
                    ? _initialMessagesWindowProbeSize
                    : null,
          ),
        );

        if (fetchId != _messagesFetchId ||
            (automatic &&
                _cellularDataSaverService.shouldSuppressBackgroundWork)) {
          return;
        }

        result.fold(
          (failure) {
            if (fetchId != _messagesFetchId) {
              return;
            }
            if (_currentSession?.id == sessionId) {
              _pendingCurrentSessionHydrationId = null;
            }
            if (canKeepVisibleState) {
              AppLogger.warn(
                'Background session revalidation failed session=$sessionId',
                error: failure,
              );
              _setState(ChatState.loaded);
              return;
            }
            _handleFailure(failure);
          },
          (messages) {
            if (fetchId != _messagesFetchId ||
                _currentSession?.id != sessionId) {
              return;
            }
            _pendingCurrentSessionHydrationId = null;
            final previousVisibleMessages = List<ChatMessage>.from(
              _messages.where((message) => message.sessionId == sessionId),
              growable: false,
            );
            var serverMessagesForMerge = messages;
            var requiresFullFetch = false;
            var usedGapRecovery = false;
            // Cold open probes one message beyond the initial window so the
            // sentinel response proves whether older history exists at all.
            final coldWindowProbe = !canKeepVisibleState && preferDelta;
            final unboundedRecoveryFetch = !preferDelta;
            if (coldWindowProbe &&
                serverMessagesForMerge.length > _initialMessagesWindowSize) {
              serverMessagesForMerge = serverMessagesForMerge.sublist(
                serverMessagesForMerge.length - _initialMessagesWindowSize,
              );
            }
            if (canKeepVisibleState &&
                preferDelta &&
                cachedMessages.isNotEmpty) {
              final deltaResult = _mergeServerTailWithCachedMessages(
                serverMessages: messages,
                cachedMessages: cachedMessages,
                sessionId: sessionId,
              );
              serverMessagesForMerge = deltaResult.messages;
              requiresFullFetch = deltaResult.requiresFullFetch;
              usedGapRecovery = deltaResult.usedGapRecovery;
            }
            serverMessagesForMerge = _filterMessagesForPendingReplacementBranch(
              serverMessagesForMerge,
              sessionId: sessionId,
            );
            final mergedMessages = _mergeServerMessagesWithActiveLocalTail(
              serverMessagesForMerge,
              sessionId: sessionId,
            );
            // Unbounded correctness-recovery fetches still commit a bounded
            // resident window; dropped older history remains server-side and
            // reachable through top-reach pagination.
            var residentMessages = mergedMessages;
            if (unboundedRecoveryFetch &&
                mergedMessages.length > _maxResidentLoadedMessages) {
              residentMessages = mergedMessages.sublist(
                mergedMessages.length - _maxResidentLoadedMessages,
              );
            }
            final nextHasMoreOldMessages =
                usedGapRecovery ||
                (coldWindowProbe
                    ? messages.length >= _initialMessagesWindowProbeSize
                    : unboundedRecoveryFetch
                        ? mergedMessages.length > _maxResidentLoadedMessages
                        : serverMessagesForMerge.length >=
                            _swrMessageTailLimit);
            final messagesChanged = !_areMessageListsSemanticallyEqual(
              previousVisibleMessages,
              residentMessages,
            );
            final hasMoreOldMessagesChanged =
                _hasMoreOldMessages != nextHasMoreOldMessages;
            if (!messagesChanged) {
              if (!hasMoreOldMessagesChanged) {
                if (_state != ChatState.loaded) {
                  _setState(ChatState.loaded);
                }
                return;
              }
              _hasMoreOldMessages = nextHasMoreOldMessages;
              if (_state != ChatState.loaded) {
                _setState(ChatState.loaded);
              } else {
                _notifyListeners();
              }
              return;
            }

            final messagesApplied = _applyMessages(
              residentMessages,
              origin: MessageUpdateOrigin.sessionRefresh,
              kind: MessageUpdateKind.fullSnapshot,
              sessionId: sessionId,
              reason: 'session-refresh-merge',
            );
            _cacheSessionMessages(sessionId, _messages);
            if (messagesApplied) {
              _messagesVersion++;
            }
            _hasMoreOldMessages = nextHasMoreOldMessages;
            _prunePendingLocalUserMessageIdsToVisibleUsers();
            if (!automatic ||
                !_cellularDataSaverService.shouldSuppressBackgroundWork) {
              _scheduleAutoTitleRefresh(sessionId);
            }
            // Re-apply selection priority now that messages are available — the
            // initial call in selectSession() may not have found cached messages
            // for the message-derived fallback (Feature 7). This also covers the
            // case where loadMessages() is called directly (e.g. from
            // loadLastSession()).
            if (_currentSession?.id == sessionId) {
              final lateSelectionChanged =
                  _applySelectionPriorityForCurrentSession();
              if (lateSelectionChanged) {
                _notifyListeners();
              }
            }
            if (_state != ChatState.loaded ||
                messagesApplied ||
                hasMoreOldMessagesChanged) {
              _setState(ChatState.loaded);
            }
            if (!usedGapRecovery) {
              unawaited(_persistLastSessionSnapshotBestEffort());
              unawaited(
                _persistSessionMessagesSnapshotBestEffort(sessionId, _messages),
              );
            }
            if (requiresFullFetch && _currentSession?.id == sessionId) {
              unawaited(
                loadMessages(
                  sessionId,
                  preserveVisibleState: true,
                  preferDelta: false,
                  automatic: automatic,
                ),
              );
            }
          },
        );
      },
      tags: const <String>{'chat:messages'},
      contextBuilder: () => <String, Object?>{
        'sessionHash': AppLogger.safeContextId(sessionId),
        'preserveVisibleState': preserveVisibleState,
        'preferDelta': preferDelta,
        'automatic': automatic,
      },
    );
  }

  /// Prepends the next fixed chunk of older history when the user reaches the
  /// top of the timeline.
  ///
  /// Issue #160: the request carries a one-message sentinel so an exact-fit
  /// response proves no older history exists, and only the slice strictly
  /// older than the oldest resident message is applied — the overlapping tail
  /// already on screen is never re-processed.
  Future<void> loadOlderMessages({
    int chunkSize = _defaultOlderMessagesChunkSize,
  }) async {
    final sessionId = _currentSession?.id;
    if (sessionId == null || sessionId.trim().isEmpty) {
      return;
    }
    if (_isLoadingOlderMessages || chunkSize <= 0) {
      return;
    }

    // The resident list is contiguous from the newest message backwards, so
    // its length is the server-tail depth already covered; matching the
    // oldest resident id absorbs realtime additions that shift positions
    // between consecutive page requests.
    final oldestAnchorId = _messages.isEmpty ? null : _messages.first.id;
    final requestedLimit = _messages.length + chunkSize + 1;

    _isLoadingOlderMessages = true;
    _notifyListeners();

    try {
      final result = await getChatMessages(
        GetChatMessagesParams(
          projectId: projectProvider.currentProjectId,
          sessionId: sessionId,
          directory: projectProvider.currentDirectory,
          limit: requestedLimit,
        ),
      );

      result.fold(
        (failure) {
          AppLogger.warn(
            'Failed to load older messages for session=$sessionId: $failure',
          );
        },
        (messages) {
          if (_currentSession?.id != sessionId) {
            return;
          }
          final exactFit = messages.length >= requestedLimit;
          final filteredMessages = _filterMessagesForPendingReplacementBranch(
            messages,
            sessionId: sessionId,
          );

          var olderSlice = filteredMessages;
          var anchorFound = oldestAnchorId == null;
          if (oldestAnchorId != null) {
            final matchIndex = filteredMessages.indexWhere(
              (message) => message.id == oldestAnchorId,
            );
            if (matchIndex > 0) {
              olderSlice = filteredMessages.sublist(0, matchIndex);
            } else if (matchIndex == 0) {
              olderSlice = const <ChatMessage>[];
            } else {
              anchorFound = false;
            }
          }

          bool messagesApplied;
          if (anchorFound && olderSlice.isNotEmpty) {
            // partialDelta keeps newer resident content authoritative while
            // the strictly-older slice is inserted in front of it.
            messagesApplied = _applyMessages(
              [...olderSlice, ..._messages],
              origin: MessageUpdateOrigin.httpFallback,
              kind: MessageUpdateKind.partialDelta,
              sessionId: sessionId,
              reason: 'older-history-prepend',
            );
          } else if (!anchorFound) {
            // The anchor vanished (server-side deletion/reorder): fall back
            // to the reconciliation merge instead of prepending unanchored
            // data.
            messagesApplied = _applyMessages(
              _mergeServerMessagesWithActiveLocalTail(
                filteredMessages,
                sessionId: sessionId,
              ),
              origin: MessageUpdateOrigin.httpFallback,
              kind: MessageUpdateKind.fullSnapshot,
              sessionId: sessionId,
              reason: 'server-messages-merge',
            );
          } else {
            messagesApplied = false;
          }
          _cacheSessionMessages(sessionId, _messages);
          if (messagesApplied) {
            _messagesVersion++;
          }
          final hasMoreOldMessagesChanged = _hasMoreOldMessages != exactFit;
          _hasMoreOldMessages = exactFit;
          if (messagesApplied || hasMoreOldMessagesChanged) {
            _notifyListeners();
          }
          if (messagesApplied) {
            unawaited(_persistLastSessionSnapshotBestEffort());
            unawaited(
              _persistSessionMessagesSnapshotBestEffort(sessionId, _messages),
            );
          }
        },
      );
    } finally {
      _isLoadingOlderMessages = false;
      _notifyListeners();
    }
  }

  Future<bool> submitMessage(
    String text, {
    List<FileInputPart> attachments = const <FileInputPart>[],
    bool shellMode = false,
    bool commandMode = false,
  }) async {
    final trimmedText = text.trim();
    final effectiveAttachments = shellMode || commandMode
        ? const <FileInputPart>[]
        : attachments;
    if (trimmedText.isEmpty && effectiveAttachments.isEmpty) {
      return false;
    }
    _traceFinal(
      'submit-message',
      sessionId: _currentSession?.id,
      details:
          'textLen=${trimmedText.length} attachments=${effectiveAttachments.length} shellMode=$shellMode commandMode=$commandMode',
    );
    return sendMessage(
      trimmedText,
      attachments: effectiveAttachments,
      shellMode: shellMode,
      commandMode: commandMode,
    );
  }

  /// Send message
  Future<bool> sendMessage(
    String text, {
    List<FileInputPart> attachments = const <FileInputPart>[],
    bool shellMode = false,
    bool commandMode = false,
    String? localMessageId,
    bool appendOptimisticMessage = true,
    String? sessionIdOverride,
  }) async {
    // Stop any active read-aloud before sending a new message.
    if (di.sl.isRegistered<ReadAloudService>()) {
      unawaited(di.sl<ReadAloudService>().stop());
    }
    final trimmedText = text.trim();
    final effectiveAttachments = shellMode || commandMode
        ? const <FileInputPart>[]
        : attachments;
    final normalizedSessionOverride = sessionIdOverride;
    final hasSessionOverride =
        normalizedSessionOverride != null &&
        normalizedSessionOverride.isNotEmpty;
    if (trimmedText.isEmpty && effectiveAttachments.isEmpty) {
      return false;
    }
    if (!_guardTransportForAction(actionLabel: 'send message')) {
      // Preserve the user's draft so it is restored to the composer
      // instead of being silently discarded. This upholds the
      // BEHAVIOR.md invariant that user text is never lost on send
      // failure. The same _setActiveSendDraft + _stashRejectedDraftForRetry
      // pair is used by existing stream-failure recovery paths.
      _setActiveSendDraft(
        trimmedText,
        attachments: effectiveAttachments,
        shellMode: shellMode,
      );
      _stashRejectedDraftForRetry(sessionId: _currentSession?.id);
      return false;
    }

    final bootstrapContextKey = !hasSessionOverride && _currentSession == null
        ? _activeContextKey
        : null;
    final bootstrapDraftGeneration = bootstrapContextKey == null
        ? null
        : _newChatDraftGeneration;
    final bootstrapSelectionGeneration = bootstrapContextKey == null
        ? null
        : _sessionSelectionGeneration;

    _cellularDataSaverService.noteExplicitUserAction(reason: 'send-message');
    await _syncCellularDataSaverRealtimePolicy(
      reason: 'send-message-user',
      forceBurst: true,
    );

    if (bootstrapContextKey != null) {
      if (bootstrapContextKey != _activeContextKey ||
          bootstrapDraftGeneration != _newChatDraftGeneration ||
          bootstrapSelectionGeneration != _sessionSelectionGeneration) {
        return false;
      }
      final inFlight = _lazySessionBootstrapTask;
      if (inFlight != null) {
        await inFlight;
      } else if (_currentSession == null) {
        final bootstrapTask = createNewSession();
        _lazySessionBootstrapTask = bootstrapTask;
        try {
          await bootstrapTask;
        } finally {
          if (identical(_lazySessionBootstrapTask, bootstrapTask)) {
            _lazySessionBootstrapTask = null;
          }
        }
      }
      // A lazy create may finish after the user has changed sessions or
      // context. Never send the original draft into the newly current session.
      if (bootstrapContextKey != _activeContextKey ||
          bootstrapDraftGeneration != _newChatDraftGeneration ||
          bootstrapSelectionGeneration != _sessionSelectionGeneration) {
        return false;
      }
      if (_currentSession == null) {
        return false;
      }
    }

    final sendSessionId = hasSessionOverride
        ? normalizedSessionOverride
        : _currentSession!.id;
    final currentReplacementBranch = _pendingReplacementBranch;
    if (currentReplacementBranch != null &&
        currentReplacementBranch.sessionId != sendSessionId) {
      _clearPendingReplacementBranch(
        sessionId: currentReplacementBranch.sessionId,
      );
    }
    final activeRevert = _currentSession?.id == sendSessionId
        ? _currentSession?.revert
        : null;
    if (activeRevert != null) {
      _startPendingReplacementBranch(
        sessionId: sendSessionId,
        revertMessageId: activeRevert.messageId,
      );
    }
    AppLogger.info(
      'Provider send start session=$sendSessionId agent=${_selectedAgentName ?? "-"} provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"} variant=${_selectedVariantId ?? "auto"}',
    );
    _traceFinal(
      'send-start',
      sessionId: sendSessionId,
      details:
          'textLen=${trimmedText.length} attachments=${effectiveAttachments.length} shell=$shellMode command=$commandMode sessionOverride=$hasSessionOverride',
    );
    _setActiveSendDraft(
      trimmedText,
      attachments: effectiveAttachments,
      shellMode: shellMode,
    );
    _preserveBusyStatusOnNextStreamDoneSessionId = null;
    _setState(ChatState.sending);
    _traceFinal('send-state-sending', sessionId: sendSessionId);
    if (_cellularDataSaverService.isAggressiveDataSaverActive) {
      unawaited(
        _syncCellularDataSaverRealtimePolicy(
          reason: 'send-message-visible',
          forceBurst: true,
        ),
      );
    }

    try {
      // Sync project ID from ProjectProvider
      _currentProjectId = projectProvider.currentProjectId;

      final resolvedLocalMessageId = localMessageId?.trim().isNotEmpty == true
          ? localMessageId!.trim()
          : null;
      final hasExistingLocalMessage =
          resolvedLocalMessageId != null &&
          _messages.whereType<UserMessage>().any(
            (message) => message.id == resolvedLocalMessageId,
          );
      final activeLocalMessageId =
          appendOptimisticMessage ||
              resolvedLocalMessageId == null ||
              !hasExistingLocalMessage
          ? _appendLocalUserMessage(
              sessionId: sendSessionId,
              text: trimmedText,
              attachments: effectiveAttachments,
              shellMode: shellMode,
            )
          : resolvedLocalMessageId;

      _setPendingReplacementBranchRootMessage(
        sessionId: sendSessionId,
        messageId: activeLocalMessageId,
      );

      _pendingLocalUserMessageIds.add(activeLocalMessageId);
      notifyListeners();
      _traceFinal(
        'send-local-user-appended',
        sessionId: sendSessionId,
        details:
            'localMessageId=$activeLocalMessageId appendOptimistic=$appendOptimisticMessage',
      );
      _scheduleAutoTitleRefresh(sendSessionId);
      unawaited(_persistLastSessionSnapshotBestEffort());

      // Ensure providers are initialized
      if (_selectedProviderId == null || _selectedModelId == null) {
        AppLogger.info('Provider send initializing provider/model selection');
        await initializeProviders();
        AppLogger.info(
          'Provider send initialized provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"}',
        );
      }

      final providerIdForSend = _selectedProviderId;
      final modelIdForSend = _selectedModelId;
      if (providerIdForSend == null || modelIdForSend == null) {
        _stashRejectedDraftForRetry(sessionId: sendSessionId);
        _setError(
          L10nBridge.current?.chatProviderErrorSelectProviderModelBeforeSend ??
              'Select a connected provider or free OpenCode model before sending',
          sessionId: sendSessionId,
        );
        return false;
      }

      _recordModelUsage();
      final selectedAgentForSend = _resolvePreferredAgentName(
        _agents,
        _selectedAgentName,
      );
      if (selectedAgentForSend != null &&
          selectedAgentForSend != _selectedAgentName) {
        _selectedAgentName = selectedAgentForSend;
      }
      // Persisting selection is best-effort; it must not block message sending.
      unawaited(
        _persistSelection().catchError(
          (error, stackTrace) => AppLogger.warn(
            'Provider send selection persistence failed',
            error: error,
            stackTrace: stackTrace is StackTrace ? stackTrace : null,
          ),
        ),
      );

      // Create chat input.
      //
      // INVARIANT — do NOT add a `messageId` field here (see ADR-023 Pitfall P-001):
      // The server must assign its own canonical ID for the user message. Forwarding
      // the local optimistic ID as `messageId` in the payload causes the SSE event
      // stream to fail reconciliation for all turns after the first — assistant
      // responses are received but silently discarded. (Regression: b0660a2)
      final inputParts = <ChatInputPart>[
        if (trimmedText.isNotEmpty) TextInputPart(text: trimmedText),
        ...effectiveAttachments,
      ];
      final input = ChatInput(
        providerId: providerIdForSend,
        modelId: modelIdForSend,
        variant: _selectedVariantId,
        mode: commandMode
            ? 'command'
            : (shellMode ? 'shell' : selectedAgentForSend),
        parts: inputParts,
      );

      // Cancel previous subscription and invalidate stale callbacks.
      _traceFinal(
        'send-cancel-previous-subscription',
        sessionId: sendSessionId,
        details: 'previousActive=${_activeMessageStreamSessionId ?? "-"}',
      );
      await _cancelActiveMessageSubscription(
        reason: 'start-send',
        invalidateGeneration: true,
      );
      final streamGeneration = _messageStreamGeneration;
      final streamSessionId = sendSessionId;
      _activeMessageStreamSessionId = streamSessionId;
      _traceFinal(
        'send-stream-ready',
        sessionId: streamSessionId,
        details: 'generation=$streamGeneration',
      );

      AppLogger.info(
        'Provider send subscribing stream session=$streamSessionId directory=${projectProvider.currentDirectory ?? "-"}',
      );

      // Send message and listen for streaming response
      late final StreamSubscription<dynamic> sendSubscription;
      sendSubscription =
          sendChatMessage(
            SendChatMessageParams(
              projectId: projectProvider.currentProjectId,
              sessionId: streamSessionId,
              input: input,
              directory: projectProvider.currentDirectory,
            ),
          ).listen(
            (result) {
              if (streamGeneration != _messageStreamGeneration) {
                AppLogger.debug(
                  'Ignoring stale send stream event generation=$streamGeneration active=$_messageStreamGeneration',
                );
                _traceFinal(
                  'send-stream-event-ignored-stale-generation',
                  sessionId: streamSessionId,
                  details:
                      'eventGeneration=$streamGeneration active=$_messageStreamGeneration',
                );
                return;
              }
              result.fold(
                (failure) {
                  _traceFinal(
                    'send-stream-failure-event',
                    sessionId: streamSessionId,
                    details:
                        'failure=${failure.runtimeType} message=${failure.message}',
                  );
                  if (_shouldSuppressAbortError(
                    sessionId: streamSessionId,
                    message: failure.message,
                  )) {
                    AppLogger.info(
                      'Suppressing expected abort failure session=$streamSessionId',
                    );
                    _traceFinal(
                      'send-stream-failure-suppressed',
                      sessionId: streamSessionId,
                    );
                    _clearActiveSendDraft();
                    _errorMessage = null;
                    if (_currentSession?.id == streamSessionId) {
                      _setState(ChatState.loaded);
                    } else {
                      _notifyListeners();
                    }
                    return;
                  }
                  _stashRejectedDraftForRetry(sessionId: streamSessionId);
                  if (_currentSession?.id != streamSessionId) {
                    AppLogger.warn(
                      'Background send stream failure session=$streamSessionId message=${failure.message}',
                    );
                    _traceFinal(
                      'send-stream-failure-background-session',
                      sessionId: streamSessionId,
                    );
                    _sessionStatusById[streamSessionId] =
                        const SessionStatusInfo(type: SessionStatusType.idle);
                    _clearSessionUnreadCompletion(streamSessionId);
                    if (!_isChildSessionId(streamSessionId)) {
                      _sessionErrorAttentionIds.add(streamSessionId);
                    }
                    _notifyListeners();
                    return;
                  }
                  _handleSendFailure(failure, sessionId: streamSessionId);
                },
                (message) {
                  final completed = message is AssistantMessage
                      ? message.isCompleted
                      : false;
                  _traceFinal(
                    'send-stream-message-event',
                    sessionId: streamSessionId,
                    details:
                        'messageId=${message.id} role=${message.role} completed=$completed parts=${message.parts.length}',
                  );
                  _updateOrAddMessage(message);
                },
              );
            },
            onError: (error) {
              _traceFinal(
                'send-stream-onerror',
                sessionId: streamSessionId,
                details: 'error=$error',
              );
              if (streamGeneration != _messageStreamGeneration) {
                if (identical(_messageSubscription, sendSubscription)) {
                  _messageSubscription = null;
                  if (_activeMessageStreamSessionId == streamSessionId) {
                    _activeMessageStreamSessionId = null;
                  }
                }
                // Stream errored while stale — finalize any incomplete messages
                // that were deferred by the event reducer preserved-stream guard.
                _markIncompleteAssistantMessagesAsCompleted(
                  sessionId: streamSessionId,
                );
                AppLogger.info(
                  'Stale send stream error — finalized session=$streamSessionId generation=$streamGeneration active=$_messageStreamGeneration',
                );
                _traceFinal(
                  'send-stream-onerror-stale-generation-finalized',
                  sessionId: streamSessionId,
                  details:
                      'eventGeneration=$streamGeneration active=$_messageStreamGeneration',
                );
                return;
              }
              if (identical(_messageSubscription, sendSubscription)) {
                _messageSubscription = null;
                if (_activeMessageStreamSessionId == streamSessionId) {
                  _activeMessageStreamSessionId = null;
                }
              }
              _stashRejectedDraftForRetry(sessionId: streamSessionId);
              AppLogger.error('Provider send stream error', error: error);
              if (_currentSession?.id != streamSessionId) {
                _sessionStatusById[streamSessionId] = const SessionStatusInfo(
                  type: SessionStatusType.idle,
                );
                _clearSessionUnreadCompletion(streamSessionId);
                if (!_isChildSessionId(streamSessionId)) {
                  _sessionErrorAttentionIds.add(streamSessionId);
                }
                _notifyListeners();
                return;
              }
              _presentServerErrorForCurrentSession(
                sessionId: streamSessionId,
                rawMessage: error.toString(),
              );
            },
            onDone: () {
              _traceFinal(
                'send-stream-ondone',
                sessionId: streamSessionId,
                details:
                    'eventGeneration=$streamGeneration active=$_messageStreamGeneration',
              );
              if (streamGeneration != _messageStreamGeneration) {
                if (identical(_messageSubscription, sendSubscription)) {
                  _messageSubscription = null;
                  if (_activeMessageStreamSessionId == streamSessionId) {
                    _activeMessageStreamSessionId = null;
                  }
                }
                // Stream finished draining — finalize any incomplete messages
                // that were deferred by the event reducer preserved-stream guard.
                _markIncompleteAssistantMessagesAsCompleted(
                  sessionId: streamSessionId,
                );
                AppLogger.info(
                  'Stale send stream done — finalized session=$streamSessionId generation=$streamGeneration active=$_messageStreamGeneration',
                );
                _traceFinal(
                  'send-stream-ondone-stale-generation-finalized',
                  sessionId: streamSessionId,
                );
                return;
              }
              if (identical(_messageSubscription, sendSubscription)) {
                _messageSubscription = null;
                if (_activeMessageStreamSessionId == streamSessionId) {
                  _activeMessageStreamSessionId = null;
                }
              }
              _clearActiveSendDraft();
              unawaited(
                _persistComposerDraftForSessionInternal(
                  sessionId: streamSessionId,
                  draft: null,
                ),
              );
              // Activate abort suppression so that any session.error arriving
              // on the provider-level SSE shortly after this stream closes
              // (e.g. due to half-open TCP after background resume) is
              // suppressed while the datasource polling fallback completes.
              _startAbortSuppression(streamSessionId);
              _traceFinal(
                'send-stream-ondone-start-abort-suppression',
                sessionId: streamSessionId,
              );
              AppLogger.info(
                'Provider send stream finished session=$streamSessionId',
              );
              final previousStatusType =
                  _sessionStatusById[streamSessionId]?.type;
              final preserveBusyStatusOnDone =
                  _preserveBusyStatusOnNextStreamDoneSessionId ==
                  streamSessionId;
              if (preserveBusyStatusOnDone) {
                _preserveBusyStatusOnNextStreamDoneSessionId = null;
                if (_currentSession?.id == streamSessionId) {
                  _setState(ChatState.loaded);
                } else {
                  _notifyListeners();
                }
                return;
              }
              _sessionStatusById[streamSessionId] = const SessionStatusInfo(
                type: SessionStatusType.idle,
              );
              _sseSettledAtBySessionId[streamSessionId] = DateTime.now();
              if (_currentSession?.id == streamSessionId) {
                _markIncompleteAssistantMessagesAsCompleted(
                  sessionId: streamSessionId,
                );
                _setState(ChatState.loaded);
                unawaited(_persistLastSessionSnapshotBestEffort());
                unawaited(loadSessionInsights(streamSessionId, silent: true));
              } else {
                final clearedError = _sessionErrorAttentionIds.remove(
                  streamSessionId,
                );
                final addedUnread = !_sessionUnreadCompletionIds.contains(
                  streamSessionId,
                );
                _markSessionUnreadCompletion(streamSessionId);
                final statusChanged =
                    previousStatusType != SessionStatusType.idle;
                if (statusChanged || clearedError || addedUnread) {
                  _notifyListeners();
                }
              }
            },
          );
      _messageSubscription = sendSubscription;
      AppLogger.info('Provider send stream subscription attached');
      _traceFinal(
        'send-stream-subscription-attached',
        sessionId: streamSessionId,
      );
      return true;
    } catch (error, stackTrace) {
      final streamSessionId = _activeMessageStreamSessionId ?? sendSessionId;
      _activeMessageStreamSessionId = null;
      _stashRejectedDraftForRetry(sessionId: streamSessionId);
      AppLogger.error(
        'Provider send setup failed',
        error: error,
        stackTrace: stackTrace,
      );
      _traceFinal(
        'send-setup-failed',
        sessionId: streamSessionId,
        details: 'error=$error',
      );
      if (_shouldSuppressAbortError(
        sessionId: streamSessionId,
        message: error.toString(),
      )) {
        _clearActiveSendDraft();
        _errorMessage = null;
        _setState(ChatState.loaded);
        return false;
      }
      _setError(
        L10nBridge.current?.chatProviderErrorStartMessageSend ??
            'Failed to start message send',
        sessionId: streamSessionId,
      );
      return false;
    }
  }

  Future<bool> abortActiveResponse({bool suppressFailureUi = false}) async {
    if (!canAbortActiveResponse) {
      return false;
    }
    final session = _currentSession;
    final usecase = abortChatSession;
    if (session == null || usecase == null) {
      if (!suppressFailureUi) {
        _setError(
          L10nBridge.current?.chatProviderErrorStopUnavailable ??
              'Stop is unavailable for the current session',
        );
      }
      return false;
    }

    _startAbortSuppression(session.id);
    _isAbortingResponse = true;
    notifyListeners();
    final previousError = _errorMessage;
    _errorMessage = null;

    final result = await usecase(
      AbortChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        directory: projectProvider.currentDirectory,
      ),
    );

    late final bool success;
    if (result.isLeft()) {
      final failure = result.fold((value) => value, (_) => null);
      if (!suppressFailureUi) {
        _clearAbortSuppression();
      }
      if (failure != null) {
        if (suppressFailureUi) {
          AppLogger.info(
            'Suppressing abort failure during interrupt-and-send session=${session.id} message=${failure.message}',
          );
          _errorMessage = null;
        } else {
          _handleFailure(failure);
        }
      }
      success = false;
    } else {
      await _cancelActiveMessageSubscription(
        reason: 'abort-success',
        invalidateGeneration: true,
      );
      _setState(ChatState.loaded);
      _markIncompleteAssistantMessagesAsCompleted();
      if (!suppressFailureUi) {
        _sessionStatusById[session.id] = const SessionStatusInfo(
          type: SessionStatusType.idle,
        );
      }
      _clearSessionAttentionForSession(session.id);
      _clearActiveSendDraft();
      unawaited(
        _persistComposerDraftForSessionInternal(
          sessionId: session.id,
          draft: null,
        ),
      );
      _errorMessage = null;
      success = true;
    }

    _isAbortingResponse = false;
    if (!success && !suppressFailureUi && _errorMessage == null) {
      _errorMessage =
          previousError ??
          (L10nBridge.current?.chatFailedToStopResponse ??
              'Failed to stop current response');
    }
    notifyListeners();
    if (success) {
      unawaited(_persistLastSessionSnapshotBestEffort());
    }
    return success;
  }

  Future<bool> compactCurrentSession() async {
    if (_isCompactingContext) {
      return false;
    }
    if (!_guardTransportForAction(actionLabel: 'compact session')) {
      return false;
    }
    if (canAbortActiveResponse) {
      _errorMessage =
          L10nBridge.current?.chatProviderErrorWaitForResponseFinish ??
          'Wait for the current response to finish before compacting';
      notifyListeners();
      return false;
    }

    final session = _currentSession;
    final usecase = summarizeChatSession;
    if (session == null || usecase == null) {
      _errorMessage =
          L10nBridge.current?.chatProviderErrorCompactUnavailable ??
          'Compact context is unavailable for the current session';
      notifyListeners();
      return false;
    }

    if (_selectedProviderId == null || _selectedModelId == null) {
      await initializeProviders();
    }

    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      _errorMessage =
          L10nBridge.current?.chatProviderErrorSelectModelBeforeCompact ??
          'Select a model before compacting context';
      notifyListeners();
      return false;
    }

    _isCompactingContext = true;
    final previousError = _errorMessage;
    _errorMessage = null;
    notifyListeners();

    final result = await usecase(
      SummarizeChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        providerId: providerId,
        modelId: modelId,
        directory: projectProvider.currentDirectory,
      ),
    );

    var success = false;
    result.fold(
      (failure) {
        _errorMessage = failure.message.isEmpty
            ? (L10nBridge.current?.chatProviderErrorCompactSessionContext ??
                  'Failed to compact session context')
            : failure.message;
      },
      (_) {
        success = true;
      },
    );

    _isCompactingContext = false;
    if (success) {
      _errorMessage = null;
      // Reset state to loaded in case SSE events set it to error during the
      // async compaction window.
      if (_state == ChatState.error) {
        _state = ChatState.loaded;
      }
      _markIncompleteAssistantMessagesAsCompleted();
      unawaited(loadSessionInsights(session.id, silent: true));
      unawaited(_persistLastSessionSnapshotBestEffort());
    } else {
      _errorMessage ??=
          previousError ??
          (L10nBridge.current?.chatProviderErrorCompactSessionContext ??
              'Failed to compact session context');
    }
    notifyListeners();
    return success;
  }

  /// Update or add message

  /// Handle failure

  Future<bool> renameSession(
    ChatSession session,
    String title, {
    SessionActionTarget? target,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (target != null && !target.isValid) return false;

    ChatSession? previous;
    bool isTargetActive = true;
    if (target != null) {
      previous = _sessionForTarget(target);
      isTargetActive = _isActiveTarget(target);
      if (previous == null) {
        previous = session;
      }
    } else {
      previous = _sessionById(session.id);
    }
    if (previous == null) {
      return false;
    }
    final previousTitle = previous.title?.trim();
    if (trimmed == previousTitle) {
      return true;
    }

    final optimistic = previous.copyWith(title: trimmed);
    if (target == null || isTargetActive) {
      _pendingRenameTitleBySessionId[session.id] = trimmed;
      _applySessionLocally(optimistic);
      notifyListeners();
    } else {
      _applySessionForTarget(target, optimistic);
      notifyListeners();
    }

    final effectiveProjectId = target != null ? _projectIdForTarget(target) : projectProvider.currentProjectId;
    final effectiveDirectory = target != null ? _directoryForTarget(target) : projectProvider.currentDirectory;
    final result = await updateChatSession(
      UpdateChatSessionParams(
        projectId: effectiveProjectId,
        sessionId: session.id,
        input: SessionUpdateInput(title: trimmed),
        directory: effectiveDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _pendingRenameTitleBySessionId.remove(session.id);
        if (target == null || isTargetActive) {
          _applySessionLocally(previous!);
        } else {
          _applySessionForTarget(target!, previous!);
        }
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        _pendingRenameTitleBySessionId.remove(session.id);
        if (target == null || isTargetActive) {
          _applySessionLocally(updated);
          _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
          unawaited(_persistSessionCacheBestEffort());
        } else {
          _applySessionForTarget(target!, updated);
          _reconcileSessionTabs(forcePersistence: false, notify: true);
        }
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> setSessionArchived(
    ChatSession session,
    bool archived, {
    SessionActionTarget? target,
  }) async {
    if (target != null && !target.isValid) return false;
    ChatSession? previous;
    bool isTargetActive = true;
    if (target != null) {
      previous = _sessionForTarget(target);
      isTargetActive = _isActiveTarget(target);
      if (previous == null) previous = session;
    } else {
      previous = _sessionById(session.id);
    }
    if (previous == null) {
      return false;
    }
    final previousCurrentSession = _currentSession;

    final archivedAt = archived ? DateTime.now() : null;
    final optimistic = previous.copyWith(
      archivedAt: archivedAt,
      title: previous.title,
    );
    if (target == null || isTargetActive) {
      _applySessionLocally(optimistic);
      if (archived && _sessionListFilter == SessionListFilter.active) {
        final visibleSessionIds = _buildVisibleSessionsFrom(
          _sessions,
        ).map((item) => item.id).toSet();
        final currentSessionId = _currentSession?.id;
        if (currentSessionId != null &&
            !visibleSessionIds.contains(currentSessionId)) {
          _currentSession = _buildVisibleSessionsFrom(
            _sessions,
          ).where((item) => item.id != currentSessionId).firstOrNull;
          _dismissNotificationsForSession(_currentSession?.id);
          _threadPermissionsVersion++;
        }
      }
    } else {
      _applySessionForTarget(target!, optimistic);
      _reconcileSessionTabs(forcePersistence: false, notify: true);
    }
    notifyListeners();

    final effectiveProjectId = target != null ? _projectIdForTarget(target) : projectProvider.currentProjectId;
    final effectiveDirectory = target != null ? _directoryForTarget(target) : projectProvider.currentDirectory;
    final result = await updateChatSession(
      UpdateChatSessionParams(
        projectId: effectiveProjectId,
        sessionId: session.id,
        input: SessionUpdateInput(
          archivedAtEpochMs: archived ? archivedAt!.millisecondsSinceEpoch : 0,
        ),
        directory: effectiveDirectory,
      ),
    );

    final succeeded = result.fold(
      (failure) {
        if (target == null || isTargetActive) {
          _applySessionLocally(previous!);
          if (previousCurrentSession != null) {
            _currentSession =
                _sessionById(previousCurrentSession.id) ?? previousCurrentSession;
            _dismissNotificationsForSession(_currentSession?.id);
            _threadPermissionsVersion++;
          }
        } else {
          _applySessionForTarget(target!, previous!);
          _reconcileSessionTabs(forcePersistence: false, notify: true);
          if (previousCurrentSession != null) {
            _currentSession = previousCurrentSession;
          }
        }
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        if (target == null || isTargetActive) {
          _applySessionLocally(updated);
          if (_currentSession?.id == updated.id) {
            _currentSession = updated;
            _dismissNotificationsForSession(updated.id);
          }
          if (archived) {
            final identity = _sessionTabIdentityForSession(
              updated,
              contextKey: _activeContextKey,
            );
            if (identity != null) {
              _setSessionTabPin(
                identity,
                pinned: false,
                pinScopeId:
                    _activePinnedSessionScopeId() ?? _resolveContextScopeId(),
                persist: true,
              );
            }
          }
          _reconcileSessionTabs(markCurrentViewed: _isSessionTabRouteVisible);
          unawaited(_persistSessionCacheBestEffort());
        } else {
          _applySessionForTarget(target!, updated);
          if (archived) {
            _setSessionTabPin(
              target!.identity,
              pinned: false,
              pinScopeId: target!.identity.directory,
              persist: true,
            );
          }
          _reconcileSessionTabs(forcePersistence: false, notify: true);
        }
        notifyListeners();
        return true;
      },
    );
    if (succeeded && archived) {
      final updated = target != null ? updatedOrPrevious(target, session) : (_sessionById(session.id) ?? session);
      final sessionDirectory = (updated.directory ?? '').trim();
      final effectiveServerId = target?.serverId ?? _activeServerId;
      final directory = sessionDirectory.isNotEmpty
          ? sessionDirectory
          : (effectiveDirectory ?? '').trim();
      if (effectiveServerId.isNotEmpty && directory.isNotEmpty) {
        await _sessionAttentionCompletionResolver?.removeIdentity(
          SessionAttentionIdentity(
            serverId: effectiveServerId,
            directory: directory,
            rootSessionId: session.id,
          ),
        );
      }
    }
    return succeeded;
  }

  ChatSession updatedOrPrevious(SessionActionTarget t, ChatSession fallback) {
    return _sessionForTarget(t) ?? fallback;
  }

  Future<bool> toggleSessionShare(
    ChatSession session, {
    SessionActionTarget? target,
  }) async {
    if (target != null && !target.isValid) return false;
    ChatSession? previous;
    bool isTargetActive = true;
    if (target != null) {
      previous = _sessionForTarget(target);
      isTargetActive = _isActiveTarget(target);
      if (previous == null) previous = session;
    } else {
      previous = _sessionById(session.id);
    }
    if (previous == null) {
      return false;
    }

    final optimistic = previous.copyWith(
      shareUrl: previous.shared ? null : previous.shareUrl,
      shared: !previous.shared,
    );
    if (target == null || isTargetActive) {
      _applySessionLocally(optimistic);
    } else {
      _applySessionForTarget(target!, optimistic);
      _reconcileSessionTabs(forcePersistence: false, notify: true);
    }
    notifyListeners();

    final effectiveProjectId = target != null ? _projectIdForTarget(target) : projectProvider.currentProjectId;
    final effectiveDirectory = target != null ? _directoryForTarget(target) : projectProvider.currentDirectory;
    final result = previous.shared
        ? await unshareChatSession(
            UnshareChatSessionParams(
              projectId: effectiveProjectId,
              sessionId: session.id,
              directory: effectiveDirectory,
            ),
          )
        : await shareChatSession(
            ShareChatSessionParams(
              projectId: effectiveProjectId,
              sessionId: session.id,
              directory: effectiveDirectory,
            ),
          );

    return result.fold(
      (failure) {
        if (target == null || isTargetActive) {
          _applySessionLocally(previous!);
        } else {
          _applySessionForTarget(target!, previous!);
        }
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        if (target == null || isTargetActive) {
          _applySessionLocally(updated);
          unawaited(_persistSessionCacheBestEffort());
        } else {
          _applySessionForTarget(target!, updated);
          _reconcileSessionTabs(forcePersistence: false, notify: true);
        }
        notifyListeners();
        return true;
      },
    );
  }

  @override
  void dispose() {
    titleGenerator?.cancelPendingWaiters();
    _sessionTabsDisposed = true;
    _sessionTabsGeneration += 1;
    _providersFetchId += 1;
    _sessionsFetchId += 1;
    _messagesFetchId += 1;
    for (final waiter in _sessionTabAuthorityWaiters.toList()) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    _sessionTabAuthorityWaiters.clear();
    _cellularDataSaverService.removeListener(_handleCellularDataSaverChanged);
    unawaited(
      _cancelActiveMessageSubscription(
        reason: 'dispose',
        invalidateGeneration: true,
      ),
    );
    _eventStreamGeneration += 1;
    final eventSubscription = _eventSubscription;
    final globalEventSubscription = _globalEventSubscription;
    _eventSubscription = null;
    _globalEventSubscription = null;
    eventSubscription?.cancel();
    globalEventSubscription?.cancel();
    _globalRefreshDebounce?.cancel();
    _deltaNotifyDebounce?.cancel();
    for (final timer in _sessionTabsPersistenceDebounceByServer.values) {
      timer.cancel();
    }
    final pendingSessionTabPayloads = Map<String, String>.from(
      _sessionTabsPendingPayloadByServer,
    );
    _sessionTabsPersistenceDebounceByServer.clear();
    _sessionTabsPendingPayloadByServer.clear();
    _sessionTabsPersistenceGenerationByServer.clear();
    for (final entry in pendingSessionTabPayloads.entries) {
      unawaited(
        _enqueueSessionTabsPersistence(
          serverId: entry.key,
          payload: entry.value,
        ),
      );
    }
    _selectionPersistenceDebounce?.cancel();
    _selectionPersistenceDebounce = null;
    if (_selectionPersistenceDirty) {
      _selectionPersistenceDirty = false;
      final origin = _scheduledSelectionOrigin;
      _scheduledSelectionOrigin = null;
      final fresh = _captureSelectionPersistenceSnapshot(
        syncRemote:
            origin?.syncRemote ?? _selectionPersistenceSyncRemote,
      );
      final snapshot = origin == null ? fresh : fresh.applyingOrigin(origin);
      _selectionPersistenceSyncRemote = false;
      unawaited(_persistSelectionSnapshot(snapshot, syncRemote: snapshot.syncRemote));
    }
    _sessionAttentionPublishDebounce?.cancel();
    _sessionAttentionThresholdTimer?.cancel();
    for (final timer in _messageFallbackDebounceById.values) {
      timer.cancel();
    }
    _messageFallbackDebounceById.clear();
    _syncHealthTimer?.cancel();
    _degradedPollingTimer?.cancel();
    _resumeGraceTimer?.cancel();
    _foregroundResumeSyncTimer?.cancel();
    _pendingQuestionsRetryTimer?.cancel();
    _invalidatePendingInteractionsLoads();
    _sessionUnreadHighlightTimer?.cancel();
    if (_ownsSessionAttentionCoordinator) {
      _sessionAttentionCoordinator.dispose();
    }
    super.dispose();
  }
}
