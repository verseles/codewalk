import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/config/feature_flags.dart';
import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/chat_realtime_model.dart';
import '../../data/models/chat_session_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/agent.dart';
import '../../domain/entities/provider.dart';
import '../../domain/usecases/create_chat_session.dart';
import '../../domain/usecases/delete_chat_session.dart';
import '../../domain/usecases/fork_chat_session.dart';
import '../../domain/usecases/get_chat_message.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_agents.dart';
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
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/share_chat_session.dart';
import '../../domain/usecases/unshare_chat_session.dart';
import '../../domain/usecases/update_chat_session.dart';
import '../../domain/usecases/watch_chat_events.dart';
import '../../domain/usecases/watch_global_chat_events.dart';
import '../../core/errors/failures.dart';
import '../services/event_feedback_dispatcher.dart';
import '../utils/session_title_formatter.dart';
import 'project_provider.dart';

/// Chat state
enum ChatState { initial, loading, loaded, error, sending }

enum ChatSyncState { connected, reconnecting, delayed }

enum SessionListFilter { active, archived, all }

enum SessionListSort { recent, oldest, title }

class _ChatContextSnapshot {
  const _ChatContextSnapshot({
    required this.sessions,
    required this.currentSession,
    required this.messages,
    required this.sessionStatusById,
    required this.pendingPermissionsBySession,
    required this.pendingQuestionsBySession,
    required this.sessionChildrenById,
    required this.sessionTodoById,
    required this.sessionDiffById,
    required this.sessionSearchQuery,
    required this.sessionListFilter,
    required this.sessionListSort,
    required this.sessionVisibleLimit,
  });

  final List<ChatSession> sessions;
  final ChatSession? currentSession;
  final List<ChatMessage> messages;
  final Map<String, SessionStatusInfo> sessionStatusById;
  final Map<String, List<ChatPermissionRequest>> pendingPermissionsBySession;
  final Map<String, List<ChatQuestionRequest>> pendingQuestionsBySession;
  final Map<String, List<ChatSession>> sessionChildrenById;
  final Map<String, List<SessionTodo>> sessionTodoById;
  final Map<String, List<SessionDiff>> sessionDiffById;
  final String sessionSearchQuery;
  final SessionListFilter sessionListFilter;
  final SessionListSort sessionListSort;
  final int sessionVisibleLimit;
}

/// Chat provider
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.sendChatMessage,
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
    required this.projectProvider,
    required this.localDataSource,
    this.eventFeedbackDispatcher,
    Duration syncSignalStaleThreshold = const Duration(seconds: 20),
    Duration syncHealthCheckInterval = const Duration(seconds: 5),
    Duration degradedPollingInterval = const Duration(seconds: 30),
    int degradedFailureThreshold = 3,
    bool refreshlessRealtimeEnabled = FeatureFlags.refreshlessRealtime,
  }) {
    _syncSignalStaleThreshold = syncSignalStaleThreshold;
    _syncHealthCheckInterval = syncHealthCheckInterval;
    _degradedPollingInterval = degradedPollingInterval;
    _degradedFailureThreshold = degradedFailureThreshold;
    _refreshlessRealtimeEnabled = refreshlessRealtimeEnabled;
    _activeContextKey = _composeContextKey(
      _activeServerId,
      _resolveContextScopeId(),
    );
  }

  // Scroll callback
  VoidCallback? _scrollToBottomCallback;

  final SendChatMessage sendChatMessage;
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
  final ProjectProvider projectProvider;
  final AppLocalDataSource localDataSource;
  final EventFeedbackDispatcher? eventFeedbackDispatcher;

  ChatState _state = ChatState.initial;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  String? _errorMessage;
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<dynamic>? _globalEventSubscription;
  int _eventStreamGeneration = 0;
  Timer? _globalRefreshDebounce;
  bool _isRespondingInteraction = false;
  Map<String, SessionStatusInfo> _sessionStatusById =
      <String, SessionStatusInfo>{};
  Map<String, List<ChatPermissionRequest>> _pendingPermissionsBySession =
      <String, List<ChatPermissionRequest>>{};
  Map<String, List<ChatQuestionRequest>> _pendingQuestionsBySession =
      <String, List<ChatQuestionRequest>>{};
  Map<String, List<ChatSession>> _sessionChildrenById =
      <String, List<ChatSession>>{};
  Map<String, List<SessionTodo>> _sessionTodoById =
      <String, List<SessionTodo>>{};
  Map<String, List<SessionDiff>> _sessionDiffById =
      <String, List<SessionDiff>>{};
  String _sessionSearchQuery = '';
  SessionListFilter _sessionListFilter = SessionListFilter.active;
  SessionListSort _sessionListSort = SessionListSort.recent;
  int _sessionVisibleLimit = 40;
  bool _isLoadingSessionInsights = false;
  String? _sessionInsightsError;
  final Set<String> _pendingLocalUserMessageIds = <String>{};
  bool _activeSessionRefreshInFlight = false;

  // Project and provider-related state
  String? _currentProjectId;
  List<Provider> _providers = [];
  Map<String, String> _defaultModels = {};
  List<Agent> _agents = <Agent>[];
  String? _selectedProviderId;
  String? _selectedModelId;
  String? _selectedAgentName;
  String? _selectedVariantId;
  List<String> _recentModelKeys = <String>[];
  Map<String, int> _modelUsageCounts = <String, int>{};
  Map<String, String> _selectedVariantByModel = <String, String>{};
  String _activeServerId = 'legacy';
  int _providersFetchId = 0;
  int _sessionsFetchId = 0;
  int _messagesFetchId = 0;
  String _activeContextKey = 'legacy::default';
  final Map<String, _ChatContextSnapshot> _contextSnapshots =
      <String, _ChatContextSnapshot>{};
  final Set<String> _dirtyContextKeys = <String>{};
  Timer? _syncHealthTimer;
  Timer? _degradedPollingTimer;
  DateTime? _lastRealtimeSignalAt;
  ChatSyncState _syncState = ChatSyncState.reconnecting;
  bool _isForegroundActive = true;
  bool _degradedMode = false;
  DateTime? _degradedModeStartedAt;
  int _consecutiveRealtimeFailures = 0;
  bool _pendingRefreshSessions = false;
  bool _pendingRefreshStatus = false;
  bool _pendingRefreshActiveSession = false;
  bool _featureFlagLogged = false;
  final Map<String, String> _pendingRenameTitleBySessionId = <String, String>{};
  late final Duration _syncSignalStaleThreshold;
  late final Duration _syncHealthCheckInterval;
  late final Duration _degradedPollingInterval;
  late final int _degradedFailureThreshold;
  late final bool _refreshlessRealtimeEnabled;

  static const Duration _sessionsCacheTtl = Duration(days: 3);
  static const int _maxRecentModels = 8;

  // Getters
  ChatState get state => _state;
  List<ChatSession> get sessions => _sessions;
  String get sessionSearchQuery => _sessionSearchQuery;
  SessionListFilter get sessionListFilter => _sessionListFilter;
  SessionListSort get sessionListSort => _sessionListSort;
  bool get isLoadingSessionInsights => _isLoadingSessionInsights;
  String? get sessionInsightsError => _sessionInsightsError;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => _messages;
  String? get errorMessage => _errorMessage;
  String? get currentProjectId => _currentProjectId;
  List<Provider> get providers => _providers;
  Map<String, String> get defaultModels => _defaultModels;
  List<Agent> get agents => List<Agent>.unmodifiable(_agents);
  List<Agent> get selectableAgents =>
      List<Agent>.unmodifiable(_sortedSelectableAgents(_agents));
  String? get selectedAgentName => _selectedAgentName;
  String get selectedAgentLabel =>
      _selectedAgentName == null ? 'Select agent' : _selectedAgentName!;
  String? get selectedProviderId => _selectedProviderId;
  String? get selectedModelId => _selectedModelId;
  String? get selectedVariantId => _selectedVariantId;
  List<String> get recentModelKeys =>
      List<String>.unmodifiable(_recentModelKeys);
  Map<String, int> get modelUsageCounts =>
      Map<String, int>.unmodifiable(_modelUsageCounts);
  String get activeServerId => _activeServerId;
  bool get isRespondingInteraction => _isRespondingInteraction;
  ChatSyncState get syncState => _syncState;
  bool get isInDegradedMode => _degradedMode;
  bool get refreshlessRealtimeEnabled => _refreshlessRealtimeEnabled;
  Map<String, SessionStatusInfo> get sessionStatusById =>
      Map<String, SessionStatusInfo>.unmodifiable(_sessionStatusById);

  List<ChatSession> get visibleSessions {
    final query = _sessionSearchQuery.trim().toLowerCase();
    final filtered = _sessions
        .where((session) {
          final archived = session.archived;
          switch (_sessionListFilter) {
            case SessionListFilter.active:
              if (archived) {
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
      ..sort((a, b) {
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
      });

    if (sorted.length <= _sessionVisibleLimit) {
      return sorted;
    }
    return sorted.take(_sessionVisibleLimit).toList(growable: false);
  }

  bool get canLoadMoreSessions {
    final query = _sessionSearchQuery.trim().toLowerCase();
    final total = _sessions.where((session) {
      final archived = session.archived;
      switch (_sessionListFilter) {
        case SessionListFilter.active:
          if (archived) {
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

  List<ChatSession> get currentSessionChildren {
    final sessionId = _currentSession?.id;
    if (sessionId == null) {
      return const <ChatSession>[];
    }
    return List<ChatSession>.unmodifiable(
      _sessionChildrenById[sessionId] ?? const <ChatSession>[],
    );
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
      return 'Auto';
    }
    final variant = selectedModel?.variants[selected];
    return variant?.name ?? selected;
  }

  /// Set scroll-to-bottom callback
  void setScrollToBottomCallback(VoidCallback? callback) {
    _scrollToBottomCallback = callback;
  }

  /// Set state
  void _setState(ChatState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Set error
  void _setError(String message) {
    _errorMessage = message;
    _setState(ChatState.error);
  }

  String _modelKey(String providerId, String modelId) {
    return '$providerId/$modelId';
  }

  String? _providerFromModelKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0) {
      return null;
    }
    return modelKey.substring(0, separatorIndex);
  }

  String? _modelFromModelKey(String modelKey) {
    final separatorIndex = modelKey.indexOf('/');
    if (separatorIndex <= 0 || separatorIndex == modelKey.length - 1) {
      return null;
    }
    return modelKey.substring(separatorIndex + 1);
  }

  bool _isSelectableAgent(Agent agent) {
    if (agent.hidden) {
      return false;
    }
    final mode = agent.mode.trim().toLowerCase();
    return mode.isEmpty || mode == 'primary' || mode == 'all';
  }

  int _agentNamePriority(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized == 'build') {
      return 0;
    }
    if (normalized == 'plan') {
      return 1;
    }
    return 2;
  }

  int _agentModePriority(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'primary':
        return 0;
      case 'all':
        return 1;
      default:
        return 2;
    }
  }

  List<Agent> _sortedSelectableAgents(List<Agent> agents) {
    final selectable = agents.where(_isSelectableAgent).toList(growable: false)
      ..sort((a, b) {
        final byPinned = _agentNamePriority(
          a.name,
        ).compareTo(_agentNamePriority(b.name));
        if (byPinned != 0) {
          return byPinned;
        }
        final byMode = _agentModePriority(
          a.mode,
        ).compareTo(_agentModePriority(b.mode));
        if (byMode != 0) {
          return byMode;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return selectable;
  }

  String? _resolvePreferredAgentName(List<Agent> available, String? persisted) {
    final selectable = _sortedSelectableAgents(available);
    if (selectable.isEmpty) {
      return null;
    }
    final persistedName = persisted?.trim();
    if (persistedName != null && persistedName.isNotEmpty) {
      final exact = selectable
          .where((agent) => agent.name == persistedName)
          .firstOrNull;
      if (exact != null) {
        return exact.name;
      }
      final normalized = persistedName.toLowerCase();
      final caseInsensitive = selectable
          .where((agent) => agent.name.toLowerCase() == normalized)
          .firstOrNull;
      if (caseInsensitive != null) {
        return caseInsensitive.name;
      }
    }
    return selectable.first.name;
  }

  String _composeContextKey(String serverId, String scopeId) {
    return '$serverId::$scopeId';
  }

  String? _scopeIdFromContextKey(String contextKey) {
    final separatorIndex = contextKey.indexOf('::');
    if (separatorIndex <= 0 || separatorIndex == contextKey.length - 2) {
      return null;
    }
    return contextKey.substring(separatorIndex + 2);
  }

  String? _serverIdFromContextKey(String contextKey) {
    final separatorIndex = contextKey.indexOf('::');
    if (separatorIndex <= 0) {
      return null;
    }
    return contextKey.substring(0, separatorIndex);
  }

  void _storeCurrentContextSnapshot() {
    _contextSnapshots[_activeContextKey] = _ChatContextSnapshot(
      sessions: _sessions,
      currentSession: _currentSession,
      messages: _messages,
      sessionStatusById: _sessionStatusById,
      pendingPermissionsBySession: _pendingPermissionsBySession,
      pendingQuestionsBySession: _pendingQuestionsBySession,
      sessionChildrenById: _sessionChildrenById,
      sessionTodoById: _sessionTodoById,
      sessionDiffById: _sessionDiffById,
      sessionSearchQuery: _sessionSearchQuery,
      sessionListFilter: _sessionListFilter,
      sessionListSort: _sessionListSort,
      sessionVisibleLimit: _sessionVisibleLimit,
    );
  }

  void _restoreContextSnapshot(String contextKey) {
    final snapshot = _contextSnapshots[contextKey];
    if (snapshot == null) {
      _sessions = <ChatSession>[];
      _currentSession = null;
      _messages = <ChatMessage>[];
      _sessionStatusById = <String, SessionStatusInfo>{};
      _pendingPermissionsBySession = <String, List<ChatPermissionRequest>>{};
      _pendingQuestionsBySession = <String, List<ChatQuestionRequest>>{};
      _sessionChildrenById = <String, List<ChatSession>>{};
      _sessionTodoById = <String, List<SessionTodo>>{};
      _sessionDiffById = <String, List<SessionDiff>>{};
      _sessionSearchQuery = '';
      _sessionListFilter = SessionListFilter.active;
      _sessionListSort = SessionListSort.recent;
      _sessionVisibleLimit = 40;
      return;
    }

    _sessions = _filterSessionsForCurrentContext(snapshot.sessions);
    _currentSession = snapshot.currentSession;
    _messages = snapshot.messages;
    _pendingLocalUserMessageIds.clear();
    _sessionStatusById = snapshot.sessionStatusById;
    _pendingPermissionsBySession = snapshot.pendingPermissionsBySession;
    _pendingQuestionsBySession = snapshot.pendingQuestionsBySession;
    _sessionChildrenById = snapshot.sessionChildrenById;
    _sessionTodoById = snapshot.sessionTodoById;
    _sessionDiffById = snapshot.sessionDiffById;
    _sessionSearchQuery = snapshot.sessionSearchQuery;
    _sessionListFilter = snapshot.sessionListFilter;
    _sessionListSort = snapshot.sessionListSort;
    _sessionVisibleLimit = snapshot.sessionVisibleLimit;
  }

  List<ChatSession> _filterSessionsForCurrentContext(
    List<ChatSession> sessions,
  ) {
    final currentDirectory = _normalizeDirectory(
      projectProvider.currentDirectory,
    );
    if (currentDirectory == null) {
      return List<ChatSession>.from(sessions);
    }

    final hasDirectoryMetadata = sessions.any((session) {
      return _normalizeDirectory(_sessionDirectory(session)) != null;
    });
    if (!hasDirectoryMetadata) {
      return List<ChatSession>.from(sessions);
    }

    return sessions.where((session) {
      final sessionDirectory = _normalizeDirectory(_sessionDirectory(session));
      return sessionDirectory == currentDirectory;
    }).toList();
  }

  String? _sessionDirectory(ChatSession session) {
    final direct = _normalizeDirectory(session.directory);
    if (direct != null) {
      return direct;
    }
    final workspace = _normalizeDirectory(session.path?.workspace);
    if (workspace != null) {
      return workspace;
    }
    return _normalizeDirectory(session.path?.root);
  }

  String? _normalizeDirectory(String? raw) {
    if (raw == null) {
      return null;
    }
    var normalized = raw.trim();
    if (normalized.isEmpty || normalized == '-') {
      return null;
    }
    normalized = normalized.replaceAll('\\', '/');
    if (normalized.length > 1) {
      normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    }
    return normalized;
  }

  Future<void> _loadModelPreferenceState({
    required String serverId,
    required String scopeId,
  }) async {
    _recentModelKeys = <String>[];
    _modelUsageCounts = <String, int>{};
    _selectedVariantByModel = <String, String>{};

    final recentJson = await localDataSource.getRecentModelsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (recentJson != null && recentJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(recentJson);
        if (decoded is List<dynamic>) {
          _recentModelKeys = decoded
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .take(_maxRecentModels)
              .toList();
        }
      } catch (_) {
        _recentModelKeys = <String>[];
      }
    }

    final usageJson = await localDataSource.getModelUsageCountsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (usageJson != null && usageJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(usageJson);
        if (decoded is Map<String, dynamic>) {
          _modelUsageCounts = decoded.map(
            (key, value) => MapEntry(
              key,
              value is num ? value.toInt() : int.tryParse('$value') ?? 0,
            ),
          );
          _modelUsageCounts.removeWhere((_, value) => value <= 0);
        }
      } catch (_) {
        _modelUsageCounts = <String, int>{};
      }
    }

    final variantsJson = await localDataSource.getSelectedVariantMap(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (variantsJson != null && variantsJson.trim().isNotEmpty) {
      try {
        final decoded = json.decode(variantsJson);
        if (decoded is Map<String, dynamic>) {
          _selectedVariantByModel = decoded.map(
            (key, value) => MapEntry(key, '$value'),
          );
          _selectedVariantByModel.removeWhere(
            (_, value) => value.trim().isEmpty,
          );
        }
      } catch (_) {
        _selectedVariantByModel = <String, String>{};
      }
    }
  }

  Future<void> _persistModelPreferenceState({
    required String serverId,
    required String scopeId,
  }) async {
    await localDataSource.saveRecentModelsJson(
      json.encode(_recentModelKeys),
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveModelUsageCountsJson(
      json.encode(_modelUsageCounts),
      serverId: serverId,
      scopeId: scopeId,
    );
    await localDataSource.saveSelectedVariantMap(
      json.encode(_selectedVariantByModel),
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Future<void> _refreshAgents({
    required String serverId,
    required String scopeId,
  }) async {
    final result = await getAgents(directory: projectProvider.currentDirectory);
    if (result.isLeft()) {
      final failure = result.fold((value) => value, (_) => null);
      AppLogger.warn('Failed to load agents: ${failure.toString()}');
      _agents = <Agent>[];
      _selectedAgentName = null;
      return;
    }
    final agents = result.fold((_) => const <Agent>[], (value) => value);
    _agents = List<Agent>.from(agents);
    final persisted = await localDataSource.getSelectedAgent(
      serverId: serverId,
      scopeId: scopeId,
    );
    _selectedAgentName = _resolvePreferredAgentName(_agents, persisted);
  }

  String? _resolveStoredVariantForSelection() {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      return null;
    }
    final model = selectedModel;
    if (model == null || model.variants.isEmpty) {
      return null;
    }
    final modelKey = _modelKey(providerId, modelId);
    final persistedVariant = _selectedVariantByModel[modelKey];
    if (persistedVariant == null ||
        !model.variants.containsKey(persistedVariant)) {
      return null;
    }
    return persistedVariant;
  }

  void _recordModelUsage() {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    if (providerId == null || modelId == null) {
      return;
    }
    _recentModelKeys = List<String>.from(_recentModelKeys);
    final key = _modelKey(providerId, modelId);
    _recentModelKeys.remove(key);
    _recentModelKeys.insert(0, key);
    if (_recentModelKeys.length > _maxRecentModels) {
      _recentModelKeys = _recentModelKeys.take(_maxRecentModels).toList();
    }
    _modelUsageCounts[key] = (_modelUsageCounts[key] ?? 0) + 1;
  }

  void _sortSessionsInPlace() {
    _sessions.sort((a, b) {
      if (_sessionListSort == SessionListSort.oldest) {
        return a.time.compareTo(b.time);
      }
      if (_sessionListSort == SessionListSort.title) {
        return (a.title ?? '').toLowerCase().compareTo(
          (b.title ?? '').toLowerCase(),
        );
      }
      return b.time.compareTo(a.time);
    });
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

  Future<void> _cancelSubscriptionSafely(
    StreamSubscription<dynamic>? subscription, {
    required String label,
  }) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel().timeout(const Duration(seconds: 2));
    } catch (error) {
      AppLogger.warn('Failed to cancel $label subscription', error: error);
    }
  }

  void _setSyncState(ChatSyncState nextState, {String? reason}) {
    if (_syncState == nextState) {
      return;
    }
    _syncState = nextState;
    AppLogger.info(
      'sync_state_changed state=${nextState.name} reason=${reason ?? "-"}',
    );
    notifyListeners();
  }

  void _markRealtimeSignal({required String source}) {
    _lastRealtimeSignalAt = DateTime.now();
    _consecutiveRealtimeFailures = 0;
    if (_degradedMode) {
      _exitDegradedMode(reason: 'signal-restored:$source');
    }
    _setSyncState(ChatSyncState.connected, reason: 'signal:$source');
  }

  void _handleRealtimeStreamFailure({required String source, Object? error}) {
    _consecutiveRealtimeFailures += 1;
    AppLogger.warn(
      'event_stream_reconnecting source=$source attempts=$_consecutiveRealtimeFailures',
      error: error,
    );
    _setSyncState(ChatSyncState.reconnecting, reason: 'stream-failure:$source');
    if (_refreshlessRealtimeEnabled &&
        _consecutiveRealtimeFailures >= _degradedFailureThreshold) {
      _enterDegradedMode(reason: 'stream-failure:$source');
    }
  }

  void _startSyncHealthMonitor() {
    if (!_refreshlessRealtimeEnabled) {
      return;
    }
    _syncHealthTimer?.cancel();
    _syncHealthTimer = Timer.periodic(_syncHealthCheckInterval, (_) {
      _evaluateSyncHealth();
    });
  }

  void _evaluateSyncHealth() {
    if (!_refreshlessRealtimeEnabled || !_isForegroundActive) {
      return;
    }
    final signalAt = _lastRealtimeSignalAt;
    if (signalAt == null) {
      return;
    }
    final stale =
        DateTime.now().difference(signalAt) > _syncSignalStaleThreshold;
    if (!stale) {
      return;
    }
    _setSyncState(ChatSyncState.delayed, reason: 'stale-signal');
    _enterDegradedMode(reason: 'stale-signal');
  }

  void _enterDegradedMode({required String reason}) {
    if (!_refreshlessRealtimeEnabled || !_isForegroundActive || _degradedMode) {
      return;
    }
    _degradedMode = true;
    _degradedModeStartedAt = DateTime.now();
    _setSyncState(ChatSyncState.delayed, reason: 'degraded-enter:$reason');
    AppLogger.warn(
      'sync_degraded_entered reason=$reason interval=${_degradedPollingInterval.inSeconds}s',
    );
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = Timer.periodic(_degradedPollingInterval, (_) {
      unawaited(_runDegradedScopedSync(reason: 'degraded-periodic'));
    });
    unawaited(_runDegradedScopedSync(reason: 'degraded-enter'));
  }

  void _exitDegradedMode({required String reason}) {
    if (!_degradedMode) {
      return;
    }
    _degradedMode = false;
    final startedAt = _degradedModeStartedAt;
    _degradedModeStartedAt = null;
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = null;
    final durationSeconds = startedAt == null
        ? null
        : DateTime.now().difference(startedAt).inSeconds;
    AppLogger.info(
      'sync_degraded_recovered reason=$reason duration_s=${durationSeconds ?? 0}',
    );
  }

  Future<void> _runDegradedScopedSync({required String reason}) async {
    if (!_degradedMode || !_isForegroundActive) {
      return;
    }
    AppLogger.info('sync_degraded_poll_tick reason=$reason');
    await loadSessions();
    await refreshActiveSessionView(reason: 'degraded-sync:$reason');
  }

  Future<void> setForegroundActive(bool isActive) async {
    _isForegroundActive = isActive;
    if (!_refreshlessRealtimeEnabled) {
      return;
    }

    if (!isActive) {
      _syncHealthTimer?.cancel();
      _syncHealthTimer = null;
      _degradedPollingTimer?.cancel();
      _degradedPollingTimer = null;
      _degradedMode = false;
      _degradedModeStartedAt = null;
      _setSyncState(ChatSyncState.reconnecting, reason: 'app-background');
      await _pauseRealtimeSubscriptions();
      return;
    }

    _startSyncHealthMonitor();
    await _resumeRealtimeAfterForeground();
  }

  Future<void> _pauseRealtimeSubscriptions() async {
    _eventStreamGeneration += 1;
    await _cancelSubscriptionSafely(
      _eventSubscription,
      label: 'realtime event',
    );
    await _cancelSubscriptionSafely(
      _globalEventSubscription,
      label: 'global event',
    );
    _eventSubscription = null;
    _globalEventSubscription = null;
  }

  Future<void> _resumeRealtimeAfterForeground() async {
    AppLogger.info('sync_resume_reconcile_start');
    await _startRealtimeEventSubscription();
    await _loadPendingInteractions();
    await loadSessions();
    await refreshActiveSessionView(reason: 'foreground-resume');
    AppLogger.info('sync_resume_reconcile_complete');
  }

  Future<void> _startRealtimeEventSubscription() async {
    final generation = ++_eventStreamGeneration;
    final previousSubscription = _eventSubscription;
    final previousGlobalSubscription = _globalEventSubscription;
    _eventSubscription = null;
    _globalEventSubscription = null;
    await _cancelSubscriptionSafely(
      previousSubscription,
      label: 'realtime event',
    );
    await _cancelSubscriptionSafely(
      previousGlobalSubscription,
      label: 'global event',
    );
    _setSyncState(ChatSyncState.reconnecting, reason: 'subscription-start');
    _startSyncHealthMonitor();

    final directory = projectProvider.currentDirectory;
    final newSubscription = watchChatEvents(directory: directory).listen(
      (result) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        result.fold(
          (failure) {
            _handleRealtimeStreamFailure(
              source: 'session-stream-failure',
              error: failure,
            );
          },
          (event) {
            _markRealtimeSignal(source: 'session-stream');
            _applyChatEvent(event);
          },
        );
      },
      onError: (error) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(
          source: 'session-stream-exception',
          error: error,
        );
      },
      onDone: () {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(source: 'session-stream-done');
      },
    );

    if (generation != _eventStreamGeneration) {
      await newSubscription.cancel();
      return;
    }

    _eventSubscription = newSubscription;

    final globalSubscription = watchGlobalChatEvents().listen(
      (result) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        result.fold(
          (failure) {
            _handleRealtimeStreamFailure(
              source: 'global-stream-failure',
              error: failure,
            );
          },
          (event) {
            _markRealtimeSignal(source: 'global-stream');
            _handleGlobalEvent(event);
          },
        );
      },
      onError: (error) {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(
          source: 'global-stream-exception',
          error: error,
        );
      },
      onDone: () {
        if (generation != _eventStreamGeneration) {
          return;
        }
        _handleRealtimeStreamFailure(source: 'global-stream-done');
      },
    );

    if (generation != _eventStreamGeneration) {
      await globalSubscription.cancel();
      return;
    }
    _globalEventSubscription = globalSubscription;
  }

  Future<void> _loadPendingInteractions() async {
    final directory = projectProvider.currentDirectory;

    final permissionsResult = await listPendingPermissions(
      directory: directory,
    );
    permissionsResult.fold(
      (failure) {
        AppLogger.warn('Failed to load pending permissions: $failure');
      },
      (permissions) {
        final grouped = <String, List<ChatPermissionRequest>>{};
        for (final item in permissions) {
          grouped.putIfAbsent(item.sessionId, () => <ChatPermissionRequest>[])
            ..add(item);
        }
        _pendingPermissionsBySession = grouped;
      },
    );

    final questionsResult = await listPendingQuestions(directory: directory);
    questionsResult.fold(
      (failure) {
        AppLogger.warn('Failed to load pending questions: $failure');
      },
      (questions) {
        final grouped = <String, List<ChatQuestionRequest>>{};
        for (final item in questions) {
          grouped.putIfAbsent(item.sessionId, () => <ChatQuestionRequest>[])
            ..add(item);
        }
        _pendingQuestionsBySession = grouped;
      },
    );

    notifyListeners();
  }

  void _upsertSession(ChatSession session) {
    final existingIndex = _sessions.indexWhere((item) => item.id == session.id);
    if (existingIndex == -1) {
      _sessions.add(session);
      _sortSessionsInPlace();
      return;
    }
    _sessions[existingIndex] = session;
    _sortSessionsInPlace();
  }

  void _removeSessionById(String sessionId) {
    _sessions.removeWhere((item) => item.id == sessionId);
    _pendingRenameTitleBySessionId.remove(sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.firstOrNull;
      _messages = <ChatMessage>[];
      _pendingLocalUserMessageIds.clear();
    }
    _sessionStatusById.remove(sessionId);
    _pendingPermissionsBySession.remove(sessionId);
    _pendingQuestionsBySession.remove(sessionId);
    _sessionChildrenById.remove(sessionId);
    _sessionTodoById.remove(sessionId);
    _sessionDiffById.remove(sessionId);
  }

  void _applyChatEvent(ChatEvent event) {
    final eventSessionId = _extractEventSessionId(event.properties);
    final sessionTitleHint = _sessionTitleForNotification(eventSessionId);
    unawaited(
      eventFeedbackDispatcher?.handle(
        event,
        sessionTitleHint: sessionTitleHint,
      ),
    );
    final properties = event.properties;
    switch (event.type) {
      case 'server.connected':
        unawaited(
          refreshActiveSessionView(reason: 'realtime-server-connected'),
        );
        break;
      case 'session.created':
      case 'session.updated':
        final info = properties['info'];
        if (info is Map<String, dynamic>) {
          final nextSession = ChatSessionModel.fromJson(info).toDomain();
          final existing = _sessionById(nextSession.id);
          if (existing != null && nextSession.time.isBefore(existing.time)) {
            AppLogger.debug(
              'Ignoring stale session event for ${nextSession.id}: incoming=${nextSession.time.toIso8601String()} existing=${existing.time.toIso8601String()}',
            );
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
          if (_currentSession?.id == nextSession.id) {
            _currentSession = nextSession;
          }
          notifyListeners();
        }
        break;
      case 'session.deleted':
        final info = properties['info'];
        final sessionId =
            (info is Map<String, dynamic> ? info['id'] as String? : null) ??
            properties['sessionID'] as String? ??
            properties['id'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          final deletedCurrent = _currentSession?.id == sessionId;
          _removeSessionById(sessionId);
          if (deletedCurrent && _currentSession != null) {
            unawaited(loadMessages(_currentSession!.id));
            unawaited(loadSessionInsights(_currentSession!.id, silent: true));
          }
          notifyListeners();
        }
        break;
      case 'session.status':
        final sessionId = properties['sessionID'] as String?;
        final statusMap = properties['status'];
        if (sessionId != null && statusMap is Map<String, dynamic>) {
          final status = SessionStatusModel.fromJson(statusMap).toDomain();
          _sessionStatusById[sessionId] = status;
          notifyListeners();
        }
        break;
      case 'session.diff':
        final sessionId = properties['sessionID'] as String?;
        final diffRaw = properties['diff'];
        if (sessionId != null && diffRaw is List) {
          final parsed = diffRaw
              .whereType<Map>()
              .map(
                (item) => SessionDiff(
                  file: item['file'] as String? ?? '',
                  before: item['before'] as String? ?? '',
                  after: item['after'] as String? ?? '',
                  additions: (item['additions'] as num?)?.toInt() ?? 0,
                  deletions: (item['deletions'] as num?)?.toInt() ?? 0,
                  status: item['status'] as String?,
                ),
              )
              .toList(growable: false);
          _sessionDiffById[sessionId] = parsed;
          notifyListeners();
        }
        break;
      case 'todo.updated':
        final sessionId = properties['sessionID'] as String?;
        final todosRaw = properties['todos'];
        if (sessionId != null && todosRaw is List) {
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
          notifyListeners();
        }
        break;
      case 'session.idle':
        final sessionId = properties['sessionID'] as String?;
        if (sessionId != null) {
          _sessionStatusById[sessionId] = const SessionStatusInfo(
            type: SessionStatusType.idle,
          );
          notifyListeners();
        }
        break;
      case 'session.error':
        final sessionId = properties['sessionID'] as String?;
        if (sessionId != null && sessionId == _currentSession?.id) {
          final error = properties['error'] as Map<String, dynamic>?;
          final data = error?['data'] as Map<String, dynamic>? ?? {};
          final message =
              data['message'] as String? ??
              error?['message'] as String? ??
              'Session error';
          _setError(message);
        }
        break;
      case 'message.updated':
      case 'message.created':
        final info = properties['info'] as Map<String, dynamic>?;
        final sessionId = info?['sessionID'] as String?;
        final messageId = info?['id'] as String?;
        if (sessionId != null &&
            messageId != null &&
            _currentSession?.id == sessionId) {
          unawaited(_fetchMessageFallback(sessionId, messageId));
        }
        break;
      case 'message.part.updated':
        final partMap = properties['part'] as Map<String, dynamic>?;
        final part = partMap == null
            ? null
            : MessagePartModel.fromJson(partMap).toDomain();
        final sessionId = part?.sessionId;
        final messageId = part?.messageId;
        if (sessionId == null ||
            messageId == null ||
            _currentSession?.id != sessionId) {
          break;
        }

        final partIndex = _messages.indexWhere((item) => item.id == messageId);
        final delta = properties['delta'] as String?;
        if (part == null ||
            partIndex == -1 ||
            (delta != null && delta.isNotEmpty)) {
          unawaited(_fetchMessageFallback(sessionId, messageId));
          break;
        }
        final message = _messages[partIndex];
        final nextParts = List<MessagePart>.from(message.parts);
        final existingPartIndex = nextParts.indexWhere(
          (item) => item.id == part.id,
        );
        if (existingPartIndex == -1) {
          nextParts.add(part);
        } else {
          nextParts[existingPartIndex] = part;
        }
        _messages[partIndex] = _copyMessageWithParts(message, nextParts);
        notifyListeners();
        _scrollToBottomCallback?.call();
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
        _messages[messageIndex] = _copyMessageWithParts(message, nextParts);
        notifyListeners();
        break;
      case 'message.removed':
        final sessionId = properties['sessionID'] as String?;
        final messageId = properties['messageID'] as String?;
        if (sessionId == null ||
            messageId == null ||
            _currentSession?.id != sessionId) {
          break;
        }
        _messages.removeWhere((item) => item.id == messageId);
        notifyListeners();
        break;
      case 'permission.asked':
      case 'permission.updated':
        final permission = ChatPermissionRequestModel.fromJson(
          properties,
        ).toDomain();
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
        notifyListeners();
        break;
      case 'permission.replied':
        final sessionId = properties['sessionID'] as String?;
        final requestId = properties['requestID'] as String?;
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
        notifyListeners();
        break;
      case 'question.asked':
      case 'question.updated':
        final question = ChatQuestionRequestModel.fromJson(
          properties,
        ).toDomain();
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
        notifyListeners();
        break;
      case 'question.replied':
      case 'question.rejected':
        final sessionId = properties['sessionID'] as String?;
        final requestId = properties['requestID'] as String?;
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
        notifyListeners();
        break;
      default:
        break;
    }
  }

  String? _extractEventSessionId(Map<String, dynamic> properties) {
    final direct = properties['sessionID']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final info = properties['info'];
    if (info is Map) {
      final nested = info['sessionID']?.toString().trim();
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
      final nestedId = info['id']?.toString().trim();
      if (nestedId != null && nestedId.isNotEmpty) {
        return nestedId;
      }
    }
    return null;
  }

  String? _sessionTitleForNotification(String? sessionId) {
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    final session = _sessionById(sessionId);
    if (session == null) {
      return null;
    }
    return SessionTitleFormatter.displayTitle(
      time: session.time,
      title: session.title,
    );
  }

  void _handleGlobalEvent(ChatEvent event) {
    final type = event.type;
    final affectsContext =
        type.startsWith('session.') ||
        type.startsWith('message.') ||
        type.startsWith('project.') ||
        type.startsWith('worktree.');
    if (!affectsContext) {
      return;
    }

    final directory = _extractDirectoryFromEvent(event);
    if (directory == null || directory.trim().isEmpty) {
      _dirtyContextKeys.add(_activeContextKey);
      if (_tryApplyGlobalEventIncremental(event)) {
        return;
      }
      _scheduleCurrentContextRefresh(
        reason: 'global:$type:no-directory',
        refreshSessions: true,
        refreshStatus: true,
        refreshActiveSession: true,
      );
      return;
    }

    final targetContextKey = _composeContextKey(_activeServerId, directory);
    _dirtyContextKeys.add(targetContextKey);

    if (targetContextKey == _activeContextKey) {
      if (_tryApplyGlobalEventIncremental(event)) {
        return;
      }
      _scheduleGlobalFallbackReconcile(event);
      return;
    }

    _contextSnapshots.remove(targetContextKey);
    unawaited(_clearPersistedContextCache(targetContextKey));
  }

  bool _tryApplyGlobalEventIncremental(ChatEvent event) {
    const supportedTypes = <String>{
      'server.connected',
      'session.created',
      'session.updated',
      'session.deleted',
      'session.status',
      'session.diff',
      'session.idle',
      'session.error',
      'todo.updated',
      'message.created',
      'message.updated',
      'message.part.updated',
      'message.part.removed',
      'message.removed',
      'permission.asked',
      'permission.updated',
      'permission.replied',
      'question.asked',
      'question.updated',
      'question.replied',
      'question.rejected',
    };
    if (!supportedTypes.contains(event.type)) {
      return false;
    }
    _applyChatEvent(event);
    return true;
  }

  void _scheduleGlobalFallbackReconcile(ChatEvent event) {
    final type = event.type;
    final refreshSessions =
        type.startsWith('session.') ||
        type.startsWith('project.') ||
        type.startsWith('worktree.');
    final refreshActiveSession = type.startsWith('message.');
    _scheduleCurrentContextRefresh(
      reason: 'global:$type:fallback',
      refreshSessions: refreshSessions,
      refreshStatus: refreshSessions || refreshActiveSession,
      refreshActiveSession: refreshActiveSession,
    );
  }

  String? _extractDirectoryFromEvent(ChatEvent event) {
    final properties = event.properties;
    final direct = properties['directory'] as String?;
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final info = properties['info'];
    if (info is Map<String, dynamic>) {
      final value = info['directory'] as String?;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final session = properties['session'];
    if (session is Map<String, dynamic>) {
      final value = session['directory'] as String?;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final project = properties['project'];
    if (project is Map<String, dynamic>) {
      final value = project['directory'] as String?;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  Future<void> _clearPersistedContextCache(String contextKey) async {
    final serverId = _serverIdFromContextKey(contextKey);
    final scopeId = _scopeIdFromContextKey(contextKey);
    if (serverId == null || scopeId == null) {
      return;
    }
    await localDataSource.clearChatContextCache(
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  void _scheduleCurrentContextRefresh({
    required String reason,
    bool refreshSessions = false,
    bool refreshStatus = false,
    bool refreshActiveSession = false,
  }) {
    _pendingRefreshSessions = _pendingRefreshSessions || refreshSessions;
    _pendingRefreshStatus = _pendingRefreshStatus || refreshStatus;
    _pendingRefreshActiveSession =
        _pendingRefreshActiveSession || refreshActiveSession;
    _globalRefreshDebounce?.cancel();
    _globalRefreshDebounce = Timer(const Duration(milliseconds: 300), () {
      final shouldRefreshSessions = _pendingRefreshSessions;
      final shouldRefreshStatus = _pendingRefreshStatus;
      final shouldRefreshActiveSession = _pendingRefreshActiveSession;
      _pendingRefreshSessions = false;
      _pendingRefreshStatus = false;
      _pendingRefreshActiveSession = false;

      AppLogger.info(
        'scoped_reconcile_triggered reason=$reason sessions=$shouldRefreshSessions active=$shouldRefreshActiveSession status=$shouldRefreshStatus',
      );

      if (shouldRefreshSessions) {
        unawaited(loadSessions());
      }

      if (shouldRefreshActiveSession) {
        unawaited(
          refreshActiveSessionView(
            reason: 'scoped-reconcile:$reason',
            includeStatus: !shouldRefreshSessions && shouldRefreshStatus,
          ),
        );
        return;
      }

      if (!shouldRefreshSessions && shouldRefreshStatus) {
        unawaited(refreshSessionStatusSnapshot());
      }
    });
  }

  ChatMessage _copyMessageWithParts(
    ChatMessage message,
    List<MessagePart> parts,
  ) {
    if (message is AssistantMessage) {
      return AssistantMessage(
        id: message.id,
        sessionId: message.sessionId,
        time: message.time,
        parts: parts,
        completedTime: message.completedTime,
        providerId: message.providerId,
        modelId: message.modelId,
        cost: message.cost,
        tokens: message.tokens,
        error: message.error,
        mode: message.mode,
        summary: message.summary,
      );
    }
    return UserMessage(
      id: message.id,
      sessionId: message.sessionId,
      time: message.time,
      parts: parts,
    );
  }

  Future<void> _fetchMessageFallback(String sessionId, String messageId) async {
    final result = await getChatMessage(
      GetChatMessageParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
        messageId: messageId,
        directory: projectProvider.currentDirectory,
      ),
    );
    result.fold((failure) {
      AppLogger.warn(
        'Message fallback fetch failed for $messageId: ${failure.toString()}',
      );
    }, _updateOrAddMessage);
  }

  List<ChatMessage> _mergeServerMessagesWithPendingLocalUsers(
    List<ChatMessage> serverMessages,
  ) {
    if (_pendingLocalUserMessageIds.isEmpty) {
      return serverMessages;
    }

    final merged = List<ChatMessage>.from(serverMessages);
    final existingIds = serverMessages.map((message) => message.id).toSet();

    _pendingLocalUserMessageIds.removeWhere(existingIds.contains);

    if (_pendingLocalUserMessageIds.isEmpty) {
      return merged;
    }

    for (final message in _messages) {
      if (message is! UserMessage) {
        continue;
      }
      if (!_pendingLocalUserMessageIds.contains(message.id)) {
        continue;
      }
      if (existingIds.contains(message.id)) {
        continue;
      }
      merged.add(message);
    }

    return merged;
  }

  Future<void> refreshActiveSessionView({
    String reason = 'manual',
    bool includeStatus = true,
  }) async {
    final session = _currentSession;
    if (session == null) {
      return;
    }
    if (_activeSessionRefreshInFlight) {
      return;
    }

    _activeSessionRefreshInFlight = true;
    AppLogger.debug(
      'Refreshing active session view reason=$reason session=${session.id}',
    );

    try {
      final messagesResult = await getChatMessages(
        GetChatMessagesParams(
          projectId: projectProvider.currentProjectId,
          sessionId: session.id,
          directory: projectProvider.currentDirectory,
        ),
      );

      messagesResult.fold(
        (failure) {
          AppLogger.warn(
            'Failed to refresh active session messages for ${session.id}: $failure',
          );
        },
        (messages) {
          if (_currentSession?.id != session.id) {
            return;
          }
          _messages = _mergeServerMessagesWithPendingLocalUsers(messages);
          notifyListeners();
        },
      );

      if (includeStatus) {
        await refreshSessionStatusSnapshot();
      }
    } finally {
      _activeSessionRefreshInFlight = false;
    }
  }

  Future<void> refreshSessionStatusSnapshot({bool silent = true}) async {
    final result = await getSessionStatus(
      GetSessionStatusParams(directory: projectProvider.currentDirectory),
    );
    result.fold(
      (failure) {
        if (!silent) {
          _sessionInsightsError = 'Failed to load session status';
          notifyListeners();
        }
        AppLogger.warn('Failed to load session status snapshot: $failure');
      },
      (statusMap) {
        _sessionStatusById = statusMap;
        if (!silent) {
          _sessionInsightsError = null;
        }
        notifyListeners();
      },
    );
  }

  Future<void> loadSessionInsights(
    String sessionId, {
    String? messageId,
    bool silent = false,
  }) async {
    if (!silent) {
      _isLoadingSessionInsights = true;
      _sessionInsightsError = null;
      notifyListeners();
    }

    final directory = projectProvider.currentDirectory;
    final projectId = projectProvider.currentProjectId;

    final childrenResult = await getSessionChildren(
      GetSessionChildrenParams(
        projectId: projectId,
        sessionId: sessionId,
        directory: directory,
      ),
    );
    childrenResult.fold(
      (failure) {
        AppLogger.warn(
          'Failed to load session children for $sessionId: $failure',
        );
      },
      (children) {
        _sessionChildrenById[sessionId] = children;
      },
    );

    final todoResult = await getSessionTodo(
      GetSessionTodoParams(
        projectId: projectId,
        sessionId: sessionId,
        directory: directory,
      ),
    );
    todoResult.fold(
      (failure) {
        AppLogger.warn('Failed to load session todo for $sessionId: $failure');
      },
      (todos) {
        _sessionTodoById[sessionId] = todos;
      },
    );

    final diffResult = await getSessionDiff(
      GetSessionDiffParams(
        projectId: projectId,
        sessionId: sessionId,
        messageId: messageId,
        directory: directory,
      ),
    );
    diffResult.fold(
      (failure) {
        AppLogger.warn('Failed to load session diff for $sessionId: $failure');
      },
      (diff) {
        _sessionDiffById[sessionId] = diff;
      },
    );

    final statusResult = await getSessionStatus(
      GetSessionStatusParams(directory: directory),
    );
    statusResult.fold(
      (failure) {
        AppLogger.warn('Failed to refresh status for $sessionId: $failure');
        if (!silent) {
          _sessionInsightsError = 'Some session details could not be loaded';
        }
      },
      (statusMap) {
        _sessionStatusById = statusMap;
      },
    );

    if (!silent) {
      _isLoadingSessionInsights = false;
    }
    notifyListeners();
  }

  Future<void> respondPermissionRequest({
    required String requestId,
    required String reply,
    String? message,
  }) async {
    if (_isRespondingInteraction) {
      return;
    }
    _isRespondingInteraction = true;
    notifyListeners();
    final result = await replyPermission(
      ReplyPermissionParams(
        requestId: requestId,
        reply: reply,
        message: message,
        directory: projectProvider.currentDirectory,
      ),
    );
    _isRespondingInteraction = false;
    result.fold(_handleFailure, (_) {
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
    });
    notifyListeners();
  }

  Future<void> submitQuestionAnswers({
    required String requestId,
    required List<List<String>> answers,
  }) async {
    if (_isRespondingInteraction) {
      return;
    }
    _isRespondingInteraction = true;
    notifyListeners();
    final result = await replyQuestion(
      ReplyQuestionParams(
        requestId: requestId,
        answers: answers,
        directory: projectProvider.currentDirectory,
      ),
    );
    _isRespondingInteraction = false;
    result.fold(_handleFailure, (_) {
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
    });
    notifyListeners();
  }

  Future<void> rejectQuestionRequest({required String requestId}) async {
    if (_isRespondingInteraction) {
      return;
    }
    _isRespondingInteraction = true;
    notifyListeners();
    final result = await rejectQuestion(
      RejectQuestionParams(
        requestId: requestId,
        directory: projectProvider.currentDirectory,
      ),
    );
    _isRespondingInteraction = false;
    result.fold(_handleFailure, (_) {
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
    });
    notifyListeners();
  }

  /// Initialize providers
  Future<void> initializeProviders() async {
    if (!_featureFlagLogged) {
      _featureFlagLogged = true;
      AppLogger.info(
        'refreshless_feature_enabled=$_refreshlessRealtimeEnabled',
      );
    }
    final fetchId = ++_providersFetchId;
    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    try {
      var failed = false;
      var connected = <String>[];
      final result = await getProviders(
        directory: projectProvider.currentDirectory,
      );
      if (fetchId != _providersFetchId) {
        return;
      }
      result.fold(
        (failure) {
          failed = true;
          AppLogger.warn('Failed to load providers: ${failure.toString()}');
        },
        (providersResponse) {
          _providers = providersResponse.providers;
          _defaultModels = providersResponse.defaultModels;
          connected = providersResponse.connected;
        },
      );

      if (failed) {
        return;
      }

      await _refreshAgents(serverId: serverId, scopeId: scopeId);

      if (_providers.isNotEmpty) {
        await _loadModelPreferenceState(serverId: serverId, scopeId: scopeId);

        final persistedProvider = await localDataSource.getSelectedProvider(
          serverId: serverId,
          scopeId: scopeId,
        );
        final persistedModel = await localDataSource.getSelectedModel(
          serverId: serverId,
          scopeId: scopeId,
        );

        Provider? selectedProvider;

        if (persistedProvider != null) {
          selectedProvider = _providers
              .where((p) => p.id == persistedProvider)
              .firstOrNull;
        }

        // Try connected providers first
        if (selectedProvider == null) {
          for (final connectedId in connected) {
            selectedProvider = _providers
                .where((p) => p.id == connectedId)
                .firstOrNull;
            if (selectedProvider != null) break;
          }
        }

        // Then try providers from recent usage.
        if (selectedProvider == null) {
          for (final recentModelKey in _recentModelKeys) {
            final providerId = _providerFromModelKey(recentModelKey);
            if (providerId == null) {
              continue;
            }
            selectedProvider = _providers
                .where((p) => p.id == providerId)
                .firstOrNull;
            if (selectedProvider != null) {
              break;
            }
          }
        }

        // Fall back to first available provider
        selectedProvider ??= _providers.first;
        _selectedProviderId = selectedProvider.id;

        if (persistedModel != null &&
            selectedProvider.models.containsKey(persistedModel)) {
          _selectedModelId = persistedModel;
        } else {
          for (final recentModelKey in _recentModelKeys) {
            final providerId = _providerFromModelKey(recentModelKey);
            final modelId = _modelFromModelKey(recentModelKey);
            if (providerId != selectedProvider.id || modelId == null) {
              continue;
            }
            if (selectedProvider.models.containsKey(modelId)) {
              _selectedModelId = modelId;
              break;
            }
          }
        }

        if (_selectedModelId == null &&
            selectedProvider.models.isNotEmpty &&
            _modelUsageCounts.isNotEmpty) {
          String? mostUsedModelId;
          var mostUsedCount = -1;
          for (final modelId in selectedProvider.models.keys) {
            final usage =
                _modelUsageCounts[_modelKey(selectedProvider.id, modelId)] ?? 0;
            if (usage > mostUsedCount) {
              mostUsedCount = usage;
              mostUsedModelId = modelId;
            }
          }
          if (mostUsedModelId != null && mostUsedCount > 0) {
            _selectedModelId = mostUsedModelId;
          }
        }

        if (_selectedModelId == null &&
            _defaultModels.containsKey(selectedProvider.id)) {
          final defaultModelId = _defaultModels[selectedProvider.id];
          if (defaultModelId != null &&
              selectedProvider.models.containsKey(defaultModelId)) {
            _selectedModelId = defaultModelId;
          }
        }

        if (_selectedModelId == null && selectedProvider.models.isNotEmpty) {
          _selectedModelId = selectedProvider.models.keys.first;
        }

        _selectedVariantId = _resolveStoredVariantForSelection();

        if (_selectedProviderId != null) {
          await localDataSource.saveSelectedProvider(
            _selectedProviderId!,
            serverId: serverId,
            scopeId: scopeId,
          );
        }
        if (_selectedModelId != null) {
          await localDataSource.saveSelectedModel(
            _selectedModelId!,
            serverId: serverId,
            scopeId: scopeId,
          );
        }
        await localDataSource.saveSelectedAgent(
          _selectedAgentName,
          serverId: serverId,
          scopeId: scopeId,
        );
        await _persistModelPreferenceState(
          serverId: serverId,
          scopeId: scopeId,
        );

        AppLogger.debug(
          'Selected agent=$_selectedAgentName provider=$_selectedProviderId model=$_selectedModelId variant=$_selectedVariantId server=$serverId',
        );
      } else {
        _selectedProviderId = null;
        _selectedModelId = null;
        _selectedVariantId = null;
        _recentModelKeys = <String>[];
        _modelUsageCounts = <String, int>{};
        _selectedVariantByModel = <String, String>{};
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Exception while initializing providers',
        error: e,
        stackTrace: stackTrace,
      );
    }
    if (fetchId == _providersFetchId) {
      if (_refreshlessRealtimeEnabled && !_isForegroundActive) {
        _setSyncState(ChatSyncState.reconnecting, reason: 'background-init');
      } else {
        await _startRealtimeEventSubscription();
      }
      await _loadPendingInteractions();
      await refreshSessionStatusSnapshot();
      notifyListeners();
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

  Future<void> onProjectScopeChanged() async {
    await _switchContext(reason: 'project');
  }

  /// Reset provider state and reload server-scoped data.
  Future<void> onServerScopeChanged() async {
    await _switchContext(reason: 'server');
  }

  Future<void> _switchContext({required String reason}) async {
    _storeCurrentContextSnapshot();

    _providersFetchId += 1;
    _sessionsFetchId += 1;
    _messagesFetchId += 1;
    _eventStreamGeneration += 1;
    await _cancelSubscriptionSafely(
      _messageSubscription,
      label: 'message stream',
    );
    await _cancelSubscriptionSafely(
      _eventSubscription,
      label: 'realtime event',
    );
    await _cancelSubscriptionSafely(
      _globalEventSubscription,
      label: 'global event',
    );
    _messageSubscription = null;
    _eventSubscription = null;
    _globalEventSubscription = null;
    _consecutiveRealtimeFailures = 0;
    _lastRealtimeSignalAt = null;
    _degradedMode = false;
    _degradedModeStartedAt = null;
    _degradedPollingTimer?.cancel();
    _degradedPollingTimer = null;
    if (_refreshlessRealtimeEnabled) {
      _setSyncState(ChatSyncState.reconnecting, reason: 'context-switch');
    }

    final serverId = await _resolveServerScopeId();
    final nextScope = _resolveContextScopeId();
    final nextContextKey = _composeContextKey(serverId, nextScope);
    _activeContextKey = nextContextKey;
    _currentProjectId = projectProvider.currentProjectId;
    _restoreContextSnapshot(nextContextKey);

    _errorMessage = null;
    _isLoadingSessionInsights = false;
    _sessionInsightsError = null;
    _isRespondingInteraction = false;
    _providers = <Provider>[];
    _defaultModels = <String, String>{};
    _agents = <Agent>[];
    _selectedAgentName = null;
    _selectedProviderId = null;
    _selectedModelId = null;
    _selectedVariantId = null;
    _recentModelKeys = <String>[];
    _modelUsageCounts = <String, int>{};
    _selectedVariantByModel = <String, String>{};
    _state = _sessions.isEmpty ? ChatState.initial : ChatState.loaded;
    notifyListeners();

    AppLogger.info(
      'Switching chat context reason=$reason context=$_activeContextKey',
    );
    await initializeProviders();

    final contextMarkedDirty = _dirtyContextKeys.remove(nextContextKey);
    if (contextMarkedDirty || _sessions.isEmpty) {
      await loadSessions();
      return;
    }

    await loadLastSession(serverId: serverId, scopeId: nextScope);
  }

  Future<void> _persistSelection() async {
    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    if (_selectedProviderId != null) {
      await localDataSource.saveSelectedProvider(
        _selectedProviderId!,
        serverId: serverId,
        scopeId: scopeId,
      );
    }
    if (_selectedModelId != null) {
      await localDataSource.saveSelectedModel(
        _selectedModelId!,
        serverId: serverId,
        scopeId: scopeId,
      );
    }
    await localDataSource.saveSelectedAgent(
      _selectedAgentName,
      serverId: serverId,
      scopeId: scopeId,
    );
    await _persistModelPreferenceState(serverId: serverId, scopeId: scopeId);
  }

  Future<void> setSelectedProvider(String providerId) async {
    final provider = _providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null) {
      return;
    }
    _selectedProviderId = provider.id;

    String? nextModelId;
    if (_selectedModelId != null &&
        provider.models.containsKey(_selectedModelId)) {
      nextModelId = _selectedModelId;
    }

    if (nextModelId == null) {
      for (final recentModelKey in _recentModelKeys) {
        final recentProviderId = _providerFromModelKey(recentModelKey);
        final recentModelId = _modelFromModelKey(recentModelKey);
        if (recentProviderId == provider.id &&
            recentModelId != null &&
            provider.models.containsKey(recentModelId)) {
          nextModelId = recentModelId;
          break;
        }
      }
    }

    if (nextModelId == null) {
      final defaultModelId = _defaultModels[provider.id];
      if (defaultModelId != null &&
          provider.models.containsKey(defaultModelId)) {
        nextModelId = defaultModelId;
      }
    }

    nextModelId ??= provider.models.keys.firstOrNull;
    _selectedModelId = nextModelId;
    _selectedVariantId = _resolveStoredVariantForSelection();
    await _persistSelection();
    notifyListeners();
  }

  Future<void> setSelectedModelByProvider({
    required String providerId,
    required String modelId,
  }) async {
    final provider = _providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null || !provider.models.containsKey(modelId)) {
      return;
    }
    _selectedProviderId = providerId;
    _selectedModelId = modelId;
    _selectedVariantId = _resolveStoredVariantForSelection();
    await _persistSelection();
    notifyListeners();
  }

  Future<void> setSelectedModel(String modelId) async {
    final provider = selectedProvider;
    if (provider == null || !provider.models.containsKey(modelId)) {
      return;
    }
    await setSelectedModelByProvider(providerId: provider.id, modelId: modelId);
  }

  Future<void> setSelectedAgent(String agentName) async {
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
    _selectedAgentName = next;
    await _persistSelection();
    notifyListeners();
  }

  Future<void> setSelectedVariant(String? variantId) async {
    final providerId = _selectedProviderId;
    final modelId = _selectedModelId;
    final model = selectedModel;
    if (providerId == null || modelId == null || model == null) {
      return;
    }

    final modelKey = _modelKey(providerId, modelId);
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

    await _persistSelection();
    notifyListeners();
  }

  Future<void> cycleVariant() async {
    final model = selectedModel;
    if (model == null || model.variants.isEmpty) {
      return;
    }
    final variantIds = model.variants.keys.toList(growable: false);
    final selectedVariant = _selectedVariantId;
    if (selectedVariant == null) {
      await setSelectedVariant(variantIds.first);
      return;
    }
    final currentIndex = variantIds.indexOf(selectedVariant);
    if (currentIndex == -1 || currentIndex >= variantIds.length - 1) {
      await setSelectedVariant(null);
      return;
    }
    await setSelectedVariant(variantIds[currentIndex + 1]);
  }

  Future<void> cycleAgent({bool reverse = false}) async {
    final available = selectableAgents;
    if (available.isEmpty) {
      return;
    }

    final selected = _selectedAgentName;
    if (selected == null) {
      await setSelectedAgent(available.first.name);
      return;
    }

    final currentIndex = available.indexWhere(
      (agent) => agent.name == selected,
    );
    if (currentIndex == -1) {
      await setSelectedAgent(available.first.name);
      return;
    }

    final delta = reverse ? -1 : 1;
    final nextIndex = (currentIndex + delta) % available.length;
    final normalizedIndex = nextIndex < 0
        ? nextIndex + available.length
        : nextIndex;
    await setSelectedAgent(available[normalizedIndex].name);
  }

  /// Load session list
  Future<void> loadSessions() async {
    if (_state == ChatState.loading) return;
    final fetchId = ++_sessionsFetchId;

    _setState(ChatState.loading);
    clearError();

    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();

    try {
      // First try loading from cache
      await _loadCachedSessions(serverId: serverId, scopeId: scopeId);

      // Then fetch latest data from server
      final result = await getChatSessions(
        GetChatSessionsParams(directory: projectProvider.currentDirectory),
      );

      if (fetchId != _sessionsFetchId) {
        return;
      }

      if (result.isLeft()) {
        if (fetchId != _sessionsFetchId) {
          return;
        }
        final failure = result.fold((f) => f, (_) => null);
        if (failure != null) {
          _handleFailure(failure);
        }
        return;
      }

      final sessions = result.fold((_) => <ChatSession>[], (value) => value);
      final filteredSessions = _filterSessionsForCurrentContext(sessions);
      if (fetchId != _sessionsFetchId) {
        return;
      }
      _sessions = filteredSessions;
      _sessionVisibleLimit = 40;
      _sortSessionsInPlace();
      _setState(ChatState.loaded);

      await _saveCachedSessions(
        filteredSessions,
        serverId: serverId,
        scopeId: scopeId,
      );

      if (fetchId != _sessionsFetchId) {
        return;
      }

      await loadLastSession(serverId: serverId, scopeId: scopeId);
      await refreshSessionStatusSnapshot();
    } catch (e, stackTrace) {
      if (fetchId != _sessionsFetchId) {
        return;
      }
      AppLogger.error(
        'Failed to load session list',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Failed to load session list: ${e.toString()}');
    }
  }

  /// Load sessions from cache
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
              _sessionsCacheTtl;
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        final cachedSessions = _filterSessionsForCurrentContext(
          jsonList
              .map((json) => ChatSessionModel.fromJson(json).toDomain())
              .toList(),
        );

        if (cachedSessions.isNotEmpty) {
          _sessions = cachedSessions;
          _sortSessionsInPlace();
          _setState(ChatState.loaded);
          if (!isFresh) {
            AppLogger.info(
              'Session cache is stale (> ${_sessionsCacheTtl.inDays} days). Refreshing from server.',
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

  /// Save sessions to cache
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

  Future<void> _persistSessionCacheBestEffort() async {
    try {
      final serverId = await _resolveServerScopeId();
      final scopeId = _resolveContextScopeId();
      await _saveCachedSessions(
        _sessions,
        serverId: serverId,
        scopeId: scopeId,
      );
    } catch (e, stackTrace) {
      AppLogger.warn(
        'Failed to persist sessions cache',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Save current session ID
  Future<void> _saveCurrentSessionId(
    String sessionId, {
    required String serverId,
    required String scopeId,
  }) async {
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
  }

  /// Load last selected session
  Future<void> loadLastSession({
    required String serverId,
    required String scopeId,
  }) async {
    try {
      if (_sessions.isEmpty) {
        _currentSession = null;
        _messages = <ChatMessage>[];
        return;
      }

      final storedSessionId = await localDataSource.getCurrentSessionId(
        serverId: serverId,
        scopeId: scopeId,
      );

      ChatSession? targetSession;
      if (storedSessionId != null && storedSessionId.trim().isNotEmpty) {
        targetSession = _sessions
            .where((session) => session.id == storedSessionId)
            .firstOrNull;
      }

      targetSession ??= _sessions
          .where((session) => session.id == _currentSession?.id)
          .firstOrNull;
      targetSession ??= _sessions.reduce((left, right) {
        return left.time.isAfter(right.time) ? left : right;
      });

      if (_currentSession?.id != targetSession.id) {
        await selectSession(targetSession);
        return;
      }

      if (_messages.isEmpty) {
        await loadMessages(targetSession.id);
      }

      if (storedSessionId != targetSession.id) {
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
  Future<void> createNewSession({String? parentId, String? title}) async {
    final projectId = projectProvider.currentProjectId;
    final directory = projectProvider.currentDirectory;
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

    if (result.isLeft()) {
      final failure = result.fold((value) => value, (_) => null);
      if (failure != null) {
        _handleFailure(failure);
      }
      return;
    }

    final session = result.fold((_) => null, (value) => value);
    if (session == null) {
      _setError('Failed to create session');
      return;
    }

    _sessions = List<ChatSession>.from(_sessions);
    _removeSessionById(session.id);
    _sessions.add(session);
    _sortSessionsInPlace();
    _currentSession = session;
    _messages = <ChatMessage>[];
    _pendingLocalUserMessageIds.clear();
    _sessionInsightsError = null;

    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    await _saveCurrentSessionId(
      session.id,
      serverId: serverId,
      scopeId: scopeId,
    );
    unawaited(_persistSessionCacheBestEffort());
    unawaited(loadSessionInsights(session.id, silent: true));
    _setState(ChatState.loaded);
  }

  /// Generate time-based session title
  String _generateSessionTitle(DateTime time) {
    return SessionTitleFormatter.fallbackTitle(time: time);
  }

  /// Select session
  Future<void> selectSession(ChatSession session) async {
    if (_currentSession?.id == session.id) {
      await loadSessionInsights(session.id, silent: true);
      return;
    }

    // Clear current message list
    _messages.clear();
    _pendingLocalUserMessageIds.clear();
    _currentSession = session;
    notifyListeners();

    // Save current session ID
    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    await _saveCurrentSessionId(
      session.id,
      serverId: serverId,
      scopeId: scopeId,
    );

    // Load messages for selected session
    await loadMessages(session.id);
    await loadSessionInsights(session.id, silent: true);
  }

  /// Load message list
  Future<void> loadMessages(String sessionId) async {
    final fetchId = ++_messagesFetchId;
    // Sync project ID from ProjectProvider; projectId is optional for the new API
    _currentProjectId = projectProvider.currentProjectId;

    _setState(ChatState.loading);

    final result = await getChatMessages(
      GetChatMessagesParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
        directory: projectProvider.currentDirectory,
      ),
    );

    if (fetchId != _messagesFetchId) {
      return;
    }

    result.fold(
      (failure) {
        if (fetchId != _messagesFetchId) {
          return;
        }
        _handleFailure(failure);
      },
      (messages) {
        if (fetchId != _messagesFetchId || _currentSession?.id != sessionId) {
          return;
        }
        _messages = messages;
        _pendingLocalUserMessageIds.clear();
        _setState(ChatState.loaded);
      },
    );
  }

  /// Send message
  Future<void> sendMessage(
    String text, {
    List<FileInputPart> attachments = const <FileInputPart>[],
    bool shellMode = false,
  }) async {
    final trimmedText = text.trim();
    final effectiveAttachments = shellMode
        ? const <FileInputPart>[]
        : attachments;
    if (_currentSession == null ||
        (trimmedText.isEmpty && effectiveAttachments.isEmpty)) {
      return;
    }

    AppLogger.info(
      'Provider send start session=${_currentSession!.id} agent=${_selectedAgentName ?? "-"} provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"} variant=${_selectedVariantId ?? "auto"}',
    );
    _setState(ChatState.sending);

    try {
      // Sync project ID from ProjectProvider
      _currentProjectId = projectProvider.currentProjectId;

      // Generate message ID
      final localMessageId =
          'local_user_${DateTime.now().microsecondsSinceEpoch}';

      // Add user message to UI
      final now = DateTime.now();
      final userParts = <MessagePart>[];
      if (trimmedText.isNotEmpty) {
        userParts.add(
          TextPart(
            id: '${localMessageId}_text',
            messageId: localMessageId,
            sessionId: _currentSession!.id,
            text: shellMode ? '!$trimmedText' : trimmedText,
            time: now,
          ),
        );
      }
      for (var index = 0; index < effectiveAttachments.length; index += 1) {
        final attachment = effectiveAttachments[index];
        userParts.add(
          FilePart(
            id: '${localMessageId}_file_$index',
            messageId: localMessageId,
            sessionId: _currentSession!.id,
            url: attachment.url,
            mime: attachment.mime,
            filename: attachment.filename,
          ),
        );
      }
      final userMessage = UserMessage(
        id: localMessageId,
        sessionId: _currentSession!.id,
        time: now,
        parts: userParts,
      );

      _messages.add(userMessage);
      _pendingLocalUserMessageIds.add(localMessageId);
      notifyListeners();

      // Ensure providers are initialized
      if (_selectedProviderId == null || _selectedModelId == null) {
        AppLogger.info('Provider send initializing provider/model selection');
        await initializeProviders();
        AppLogger.info(
          'Provider send initialized provider=${_selectedProviderId ?? "-"} model=${_selectedModelId ?? "-"}',
        );
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

      // Create chat input
      final inputParts = <ChatInputPart>[
        if (trimmedText.isNotEmpty) TextInputPart(text: trimmedText),
        ...effectiveAttachments,
      ];
      final input = ChatInput(
        providerId: _selectedProviderId ?? 'anthropic',
        modelId: _selectedModelId ?? 'claude-3-5-sonnet-20241022',
        variant: _selectedVariantId,
        mode: shellMode ? 'shell' : selectedAgentForSend,
        parts: inputParts,
      );

      // Cancel previous subscription
      _messageSubscription?.cancel();

      AppLogger.info(
        'Provider send subscribing stream session=${_currentSession!.id} directory=${projectProvider.currentDirectory ?? "-"}',
      );

      // Send message and listen for streaming response
      _messageSubscription =
          sendChatMessage(
            SendChatMessageParams(
              projectId: projectProvider.currentProjectId,
              sessionId: _currentSession!.id,
              input: input,
              directory: projectProvider.currentDirectory,
            ),
          ).listen(
            (result) {
              result.fold((failure) => _handleFailure(failure), (message) {
                // Update or add assistant message
                _updateOrAddMessage(message);
              });
            },
            onError: (error) {
              AppLogger.error('Provider send stream error', error: error);
              _setError('Failed to send message: $error');
            },
            onDone: () {
              AppLogger.info('Provider send stream finished');
              _setState(ChatState.loaded);
              final sessionId = _currentSession?.id;
              if (sessionId != null) {
                unawaited(loadSessionInsights(sessionId, silent: true));
              }
            },
          );
      AppLogger.info('Provider send stream subscription attached');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Provider send setup failed',
        error: error,
        stackTrace: stackTrace,
      );
      _setError('Failed to start message send');
    }
  }

  /// Update or add message
  void _updateOrAddMessage(ChatMessage message) {
    if (message is UserMessage) {
      final pendingLocalIndex = _findPendingLocalUserMessageIndex(message);
      if (pendingLocalIndex != -1) {
        final previousId = _messages[pendingLocalIndex].id;
        _pendingLocalUserMessageIds.remove(previousId);
        _messages[pendingLocalIndex] = message;
        notifyListeners();
        _scrollToBottomCallback?.call();
        return;
      }
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      // Update existing message
      _messages[index] = message;
      if (message is UserMessage) {
        _pendingLocalUserMessageIds.remove(message.id);
      }
      AppLogger.debug(
        'Updated message: ${message.id}, parts=${message.parts.length}',
      );
    } else {
      // Add new message
      _messages.add(message);
      AppLogger.debug('Added new message: ${message.id}, role=${message.role}');
    }

    // Check if there is an unfinished assistant message
    if (message is AssistantMessage) {
      AppLogger.debug(
        'Assistant message status: ${message.isCompleted ? "completed" : "in_progress"}',
      );
      if (message.isCompleted && _state == ChatState.sending) {
        AppLogger.debug('Message completed, setting state to loaded');
        _setState(ChatState.loaded);
      }
    }

    notifyListeners();

    // Trigger auto-scroll
    _scrollToBottomCallback?.call();
  }

  String _normalizedUserMessageSignature(UserMessage message) {
    final textSignature = message.parts
        .whereType<TextPart>()
        .map((part) => part.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
    final fileSignature = message.parts
        .whereType<FilePart>()
        .map((part) => '${part.mime.trim()}|${part.url.trim()}')
        .where((value) => value.isNotEmpty)
        .join('\n');
    if (fileSignature.isEmpty) {
      return textSignature;
    }
    return '$textSignature\n$fileSignature'.trim();
  }

  int _findPendingLocalUserMessageIndex(UserMessage incoming) {
    final incomingSignature = _normalizedUserMessageSignature(incoming);
    if (incomingSignature.isEmpty) {
      return -1;
    }

    for (var index = 0; index < _messages.length; index += 1) {
      final current = _messages[index];
      if (current is! UserMessage) {
        continue;
      }
      if (!_pendingLocalUserMessageIds.contains(current.id)) {
        continue;
      }
      if (current.sessionId != incoming.sessionId) {
        continue;
      }
      final currentSignature = _normalizedUserMessageSignature(current);
      if (currentSignature != incomingSignature) {
        continue;
      }
      final delta = incoming.time.difference(current.time).abs();
      if (delta > const Duration(minutes: 5)) {
        continue;
      }
      return index;
    }
    return -1;
  }

  /// Handle failure
  void _handleFailure(Failure failure) {
    AppLogger.warn(
      'Chat failure handled type=${failure.runtimeType} message=${failure.message}',
    );
    switch (failure.runtimeType) {
      case NetworkFailure:
        _setError('Network connection failed. Please check network settings');
        break;
      case ServerFailure:
        _setError('Server error. Please try again later');
        break;
      case NotFoundFailure:
        _setError('Resource not found');
        break;
      case ValidationFailure:
        _setError('Invalid input parameters');
        break;
      default:
        _setError('Unknown error. Please try again later');
        break;
    }
  }

  ChatSession? _sessionById(String sessionId) {
    return _sessions.where((session) => session.id == sessionId).firstOrNull;
  }

  void _applySessionLocally(ChatSession session) {
    _upsertSession(session);
    if (_currentSession?.id == session.id) {
      _currentSession = session;
    }
  }

  Future<bool> renameSession(ChatSession session, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final previous = _sessionById(session.id);
    if (previous == null) {
      return false;
    }
    final previousTitle = previous.title?.trim();
    if (trimmed == previousTitle) {
      return true;
    }

    final optimistic = previous.copyWith(title: trimmed);
    _pendingRenameTitleBySessionId[session.id] = trimmed;
    _applySessionLocally(optimistic);
    notifyListeners();

    final result = await updateChatSession(
      UpdateChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        input: SessionUpdateInput(title: trimmed),
        directory: projectProvider.currentDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _pendingRenameTitleBySessionId.remove(session.id);
        _applySessionLocally(previous);
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        _pendingRenameTitleBySessionId.remove(session.id);
        _applySessionLocally(updated);
        unawaited(_persistSessionCacheBestEffort());
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> setSessionArchived(ChatSession session, bool archived) async {
    final previous = _sessionById(session.id);
    if (previous == null) {
      return false;
    }

    final archivedAt = archived ? DateTime.now() : null;
    final optimistic = previous.copyWith(
      archivedAt: archivedAt,
      title: previous.title,
    );
    _applySessionLocally(optimistic);

    if (archived && _sessionListFilter == SessionListFilter.active) {
      if (_currentSession?.id == session.id) {
        _currentSession = _sessions.firstWhere(
          (item) => item.id != session.id && !item.archived,
          orElse: () => previous,
        );
      }
    }
    notifyListeners();

    final result = await updateChatSession(
      UpdateChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        input: SessionUpdateInput(
          archivedAtEpochMs: archived ? archivedAt!.millisecondsSinceEpoch : 0,
        ),
        directory: projectProvider.currentDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _applySessionLocally(previous);
        if (_currentSession?.id != previous.id && session.id == previous.id) {
          _currentSession = previous;
        }
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        _applySessionLocally(updated);
        unawaited(_persistSessionCacheBestEffort());
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> toggleSessionShare(ChatSession session) async {
    final previous = _sessionById(session.id);
    if (previous == null) {
      return false;
    }

    final optimistic = previous.copyWith(
      shareUrl: previous.shared ? null : previous.shareUrl,
      shared: !previous.shared,
    );
    _applySessionLocally(optimistic);
    notifyListeners();

    final result = previous.shared
        ? await unshareChatSession(
            UnshareChatSessionParams(
              projectId: projectProvider.currentProjectId,
              sessionId: session.id,
              directory: projectProvider.currentDirectory,
            ),
          )
        : await shareChatSession(
            ShareChatSessionParams(
              projectId: projectProvider.currentProjectId,
              sessionId: session.id,
              directory: projectProvider.currentDirectory,
            ),
          );

    return result.fold(
      (failure) {
        _applySessionLocally(previous);
        _handleFailure(failure);
        notifyListeners();
        return false;
      },
      (updated) {
        _applySessionLocally(updated);
        unawaited(_persistSessionCacheBestEffort());
        notifyListeners();
        return true;
      },
    );
  }

  Future<ChatSession?> forkSession(
    ChatSession session, {
    String? messageId,
    bool selectForked = true,
  }) async {
    final result = await forkChatSession(
      ForkChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: session.id,
        messageId: messageId,
        directory: projectProvider.currentDirectory,
      ),
    );

    return result.fold(
      (failure) {
        _handleFailure(failure);
        return null;
      },
      (forked) async {
        _applySessionLocally(forked);
        unawaited(_persistSessionCacheBestEffort());
        notifyListeners();
        if (selectForked) {
          await selectSession(forked);
        }
        return forked;
      },
    );
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == ChatState.error) {
      _setState(ChatState.loaded);
    }
  }

  /// Delete session
  Future<void> deleteSession(String sessionId) async {
    _currentProjectId = projectProvider.currentProjectId;
    final previousSessions = List<ChatSession>.from(_sessions);
    final previousCurrent = _currentSession;
    final previousMessages = List<ChatMessage>.from(_messages);
    final wasCurrent = previousCurrent?.id == sessionId;

    _removeSessionById(sessionId);
    _sortSessionsInPlace();

    if (wasCurrent) {
      _currentSession = _sessions.firstOrNull;
      _messages = <ChatMessage>[];
    }
    notifyListeners();

    final result = await deleteChatSession(
      DeleteChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
        directory: projectProvider.currentDirectory,
      ),
    );

    result.fold(
      (failure) {
        _sessions = previousSessions;
        _currentSession = previousCurrent;
        _messages = previousMessages;
        _sortSessionsInPlace();
        _handleFailure(failure);
      },
      (_) async {
        if (wasCurrent && _currentSession != null) {
          await loadMessages(_currentSession!.id);
          await loadSessionInsights(_currentSession!.id, silent: true);
        }
        notifyListeners();
      },
    );
  }

  /// Refresh current session
  Future<void> refresh() async {
    if (_currentSession != null) {
      await refreshActiveSessionView(reason: 'manual-refresh');
    } else {
      // If there is no current session, reload sessions
      if (_sessions.isNotEmpty) {
        // Assume workspaceId exists; in practice it should come from app state
        // Adjust based on actual app behavior
        _setState(ChatState.loaded);
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _eventStreamGeneration += 1;
    _eventSubscription?.cancel();
    _globalEventSubscription?.cancel();
    _globalRefreshDebounce?.cancel();
    _syncHealthTimer?.cancel();
    _degradedPollingTimer?.cancel();
    super.dispose();
  }
}
