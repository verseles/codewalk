import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../data/models/chat_session_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/provider.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/get_chat_sessions.dart';
import '../../domain/usecases/create_chat_session.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_providers.dart';
import '../../domain/usecases/delete_chat_session.dart';
import '../../core/errors/failures.dart';
import 'project_provider.dart';

/// Chat state
enum ChatState { initial, loading, loaded, error, sending }

/// Chat provider
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.sendChatMessage,
    required this.getChatSessions,
    required this.createChatSession,
    required this.getChatMessages,
    required this.getProviders,
    required this.deleteChatSession,
    required this.projectProvider,
    required this.localDataSource,
  });

  // Scroll callback
  VoidCallback? _scrollToBottomCallback;

  final SendChatMessage sendChatMessage;
  final GetChatSessions getChatSessions;
  final CreateChatSession createChatSession;
  final GetChatMessages getChatMessages;
  final GetProviders getProviders;
  final DeleteChatSession deleteChatSession;
  final ProjectProvider projectProvider;
  final AppLocalDataSource localDataSource;

  ChatState _state = ChatState.initial;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  List<ChatMessage> _messages = [];
  String? _errorMessage;
  StreamSubscription<dynamic>? _messageSubscription;

  // Project and provider-related state
  String? _currentProjectId;
  List<Provider> _providers = [];
  Map<String, String> _defaultModels = {};
  String? _selectedProviderId;
  String? _selectedModelId;
  String? _selectedVariantId;
  List<String> _recentModelKeys = <String>[];
  Map<String, int> _modelUsageCounts = <String, int>{};
  Map<String, String> _selectedVariantByModel = <String, String>{};
  String _activeServerId = 'legacy';
  int _providersFetchId = 0;
  int _sessionsFetchId = 0;
  int _messagesFetchId = 0;

  static const Duration _sessionsCacheTtl = Duration(days: 3);
  static const int _maxRecentModels = 8;

  // Getters
  ChatState get state => _state;
  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => _messages;
  String? get errorMessage => _errorMessage;
  String? get currentProjectId => _currentProjectId;
  List<Provider> get providers => _providers;
  Map<String, String> get defaultModels => _defaultModels;
  String? get selectedProviderId => _selectedProviderId;
  String? get selectedModelId => _selectedModelId;
  String? get selectedVariantId => _selectedVariantId;
  List<String> get recentModelKeys =>
      List<String>.unmodifiable(_recentModelKeys);
  Map<String, int> get modelUsageCounts =>
      Map<String, int>.unmodifiable(_modelUsageCounts);
  String get activeServerId => _activeServerId;

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
              .toList(growable: false);
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
    final key = _modelKey(providerId, modelId);
    _recentModelKeys.remove(key);
    _recentModelKeys.insert(0, key);
    if (_recentModelKeys.length > _maxRecentModels) {
      _recentModelKeys = _recentModelKeys.take(_maxRecentModels).toList();
    }
    _modelUsageCounts[key] = (_modelUsageCounts[key] ?? 0) + 1;
  }

  /// Initialize providers
  Future<void> initializeProviders() async {
    final fetchId = ++_providersFetchId;
    final serverId = await _resolveServerScopeId();
    final scopeId = _resolveContextScopeId();
    try {
      var failed = false;
      var connected = <String>[];
      final result = await getProviders();
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
        await _persistModelPreferenceState(
          serverId: serverId,
          scopeId: scopeId,
        );

        AppLogger.debug(
          'Selected provider=$_selectedProviderId model=$_selectedModelId variant=$_selectedVariantId server=$serverId',
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
      notifyListeners();
    }
  }

  String _resolveContextScopeId() {
    return projectProvider.currentProject?.path ??
        projectProvider.currentProjectId;
  }

  Future<String> _resolveServerScopeId() async {
    final stored = await localDataSource.getActiveServerId();
    if (stored != null && stored.isNotEmpty) {
      _activeServerId = stored;
      return stored;
    }
    _activeServerId = 'legacy';
    return 'legacy';
  }

  /// Reset provider state and reload server-scoped data.
  Future<void> onServerScopeChanged() async {
    _providersFetchId += 1;
    _sessionsFetchId += 1;
    _messagesFetchId += 1;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _sessions = <ChatSession>[];
    _messages = <ChatMessage>[];
    _currentSession = null;
    _errorMessage = null;
    _providers = <Provider>[];
    _defaultModels = <String, String>{};
    _selectedProviderId = null;
    _selectedModelId = null;
    _selectedVariantId = null;
    _recentModelKeys = <String>[];
    _modelUsageCounts = <String, int>{};
    _selectedVariantByModel = <String, String>{};
    _state = ChatState.initial;
    notifyListeners();

    await initializeProviders();
    await loadSessions();
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

  Future<void> setSelectedModel(String modelId) async {
    final provider = selectedProvider;
    if (provider == null || !provider.models.containsKey(modelId)) {
      return;
    }
    _selectedModelId = modelId;
    _selectedVariantId = _resolveStoredVariantForSelection();
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
      final result = await getChatSessions();

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
      if (fetchId != _sessionsFetchId) {
        return;
      }
      _sessions = sessions;
      _setState(ChatState.loaded);

      await _saveCachedSessions(sessions, serverId: serverId, scopeId: scopeId);

      if (fetchId != _sessionsFetchId) {
        return;
      }

      await loadLastSession(serverId: serverId, scopeId: scopeId);
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
        final cachedSessions = jsonList
            .map((json) => ChatSessionModel.fromJson(json).toDomain())
            .toList();

        if (cachedSessions.isNotEmpty) {
          _sessions = cachedSessions;
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
      final sessionId = await localDataSource.getCurrentSessionId(
        serverId: serverId,
        scopeId: scopeId,
      );
      if (sessionId != null) {
        final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
        if (session != null) {
          await selectSession(session);
        }
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
    final directory = projectProvider.currentProject?.path;
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

    result.fold((failure) => _handleFailure(failure), (session) {
      _sessions.insert(0, session);
      _currentSession = session;
      _messages
          .clear(); // Ensure message list is empty when a new session starts
      _setState(ChatState.loaded);
    });
  }

  /// Generate time-based session title
  String _generateSessionTitle(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(time.year, time.month, time.day);

    if (sessionDate == today) {
      // Show time for today's conversations
      return 'Today ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      final difference = today.difference(sessionDate).inDays;
      if (difference == 1) {
        // Yesterday conversation
        return 'Yesterday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (difference < 7) {
        // Show weekday for conversations within a week
        final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekday = weekdays[time.weekday - 1];
        return '$weekday ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        // Show date for older conversations
        return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  /// Select session
  Future<void> selectSession(ChatSession session) async {
    if (_currentSession?.id == session.id) return;

    // Clear current message list
    _messages.clear();
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
        _setState(ChatState.loaded);
      },
    );
  }

  /// Send message
  Future<void> sendMessage(String text) async {
    if (_currentSession == null || text.trim().isEmpty) return;

    _setState(ChatState.sending);

    // Sync project ID from ProjectProvider
    _currentProjectId = projectProvider.currentProjectId;

    // Generate message ID
    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    // Add user message to UI
    final userMessage = UserMessage(
      id: messageId,
      sessionId: _currentSession!.id,
      time: DateTime.now(),
      parts: [
        TextPart(
          id: '${messageId}_text',
          messageId: messageId,
          sessionId: _currentSession!.id,
          text: text,
          time: DateTime.now(),
        ),
      ],
    );

    _messages.add(userMessage);
    notifyListeners();

    // Ensure providers are initialized
    if (_selectedProviderId == null || _selectedModelId == null) {
      await initializeProviders();
    }

    _recordModelUsage();
    await _persistSelection();

    // Create chat input
    final input = ChatInput(
      messageId: messageId,
      providerId: _selectedProviderId ?? 'anthropic',
      modelId: _selectedModelId ?? 'claude-3-5-sonnet-20241022',
      variant: _selectedVariantId,
      parts: [TextInputPart(text: text)],
    );

    // Cancel previous subscription
    _messageSubscription?.cancel();

    // Send message and listen for streaming response
    _messageSubscription =
        sendChatMessage(
          SendChatMessageParams(
            projectId: projectProvider.currentProjectId,
            sessionId: _currentSession!.id,
            input: input,
          ),
        ).listen(
          (result) {
            result.fold((failure) => _handleFailure(failure), (message) {
              // Update or add assistant message
              _updateOrAddMessage(message);
            });
          },
          onError: (error) {
            _setError('Failed to send message: $error');
          },
          onDone: () {
            _setState(ChatState.loaded);
          },
        );
  }

  /// Update or add message
  void _updateOrAddMessage(ChatMessage message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      // Update existing message
      _messages[index] = message;
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

  /// Handle failure
  void _handleFailure(Failure failure) {
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

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == ChatState.error) {
      _setState(ChatState.loaded);
    }
  }

  /// Delete session
  Future<void> deleteSession(String sessionId) async {
    // Sync project ID from ProjectProvider
    _currentProjectId = projectProvider.currentProjectId;

    final result = await deleteChatSession(
      DeleteChatSessionParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
      ),
    );

    result.fold((failure) => _handleFailure(failure), (_) {
      // Remove session from local list
      _sessions.removeWhere((session) => session.id == sessionId);

      // If current session is deleted, clear current session and messages
      if (_currentSession?.id == sessionId) {
        _currentSession = null;
        _messages.clear();

        // If other sessions remain, select the first one
        if (_sessions.isNotEmpty) {
          selectSession(_sessions.first);
        }
      }

      notifyListeners();
    });
  }

  /// Refresh current session
  Future<void> refresh() async {
    if (_currentSession != null) {
      await loadMessages(_currentSession!.id);
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
    super.dispose();
  }
}
