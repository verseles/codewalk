import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Initialize providers
  Future<void> initializeProviders() async {
    try {
      final result = await getProviders();
      result.fold(
        (failure) {
          print('Failed to load providers: ${failure.toString()}');
        },
        (providersResponse) {
          _providers = providersResponse.providers;
          _defaultModels = providersResponse.defaultModels;

          if (_providers.isNotEmpty) {
            // Selection priority: first connected provider, then first available
            Provider? selectedProvider;

            // Try connected providers first
            for (final connectedId in providersResponse.connected) {
              selectedProvider = _providers
                  .where((p) => p.id == connectedId)
                  .firstOrNull;
              if (selectedProvider != null) break;
            }

            // Fall back to first available provider
            selectedProvider ??= _providers.first;

            _selectedProviderId = selectedProvider.id;

            // Get default model or first available model
            if (_defaultModels.containsKey(selectedProvider.id)) {
              _selectedModelId = _defaultModels[selectedProvider.id];
            } else if (selectedProvider.models.isNotEmpty) {
              _selectedModelId = selectedProvider.models.keys.first;
            }

            print(
              'Selected provider: $_selectedProviderId, model: $_selectedModelId',
            );
          }
        },
      );
    } catch (e) {
      print('Exception while initializing providers: $e');
    }
    notifyListeners();
  }

  /// Load session list
  Future<void> loadSessions() async {
    if (_state == ChatState.loading) return;

    _setState(ChatState.loading);
    clearError();

    try {
      // First try loading from cache
      await _loadCachedSessions();

      // Then fetch latest data from server
      final result = await getChatSessions();

      result.fold((failure) => _handleFailure(failure), (sessions) async {
        _sessions = sessions;
        _setState(ChatState.loaded);

        // Save to cache
        await _saveCachedSessions(sessions);

        // Restore last selected session
        await loadLastSession();
      });
    } catch (e) {
      _setError('Failed to load session list: ${e.toString()}');
    }
  }

  /// Load sessions from cache
  Future<void> _loadCachedSessions() async {
    try {
      final cachedData = await localDataSource.getCachedSessions();
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        final cachedSessions = jsonList
            .map((json) => ChatSessionModel.fromJson(json).toDomain())
            .toList();

        if (cachedSessions.isNotEmpty) {
          _sessions = cachedSessions;
          _setState(ChatState.loaded);
          notifyListeners();
        }
      }
    } catch (e) {
      print('Failed to load cached sessions: $e');
    }
  }

  /// Save sessions to cache
  Future<void> _saveCachedSessions(List<ChatSession> sessions) async {
    try {
      final jsonList = sessions
          .map((session) => ChatSessionModel.fromDomain(session).toJson())
          .toList();
      final jsonString = json.encode(jsonList);
      await localDataSource.saveCachedSessions(jsonString);
    } catch (e) {
      print('Failed to save session cache: $e');
    }
  }

  /// Save current session ID
  Future<void> _saveCurrentSessionId(String sessionId) async {
    try {
      await localDataSource.saveCurrentSessionId(sessionId);
    } catch (e) {
      print('Failed to save current session ID: $e');
    }
  }

  /// Load last selected session
  Future<void> loadLastSession() async {
    try {
      final sessionId = await localDataSource.getCurrentSessionId();
      if (sessionId != null) {
        final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
        if (session != null) {
          await selectSession(session);
        }
      }
    } catch (e) {
      print('Failed to load last session: $e');
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
    await _saveCurrentSessionId(session.id);

    // Load messages for selected session
    await loadMessages(session.id);
  }

  /// Load message list
  Future<void> loadMessages(String sessionId) async {
    // Sync project ID from ProjectProvider; projectId is optional for the new API
    _currentProjectId = projectProvider.currentProjectId;

    _setState(ChatState.loading);

    final result = await getChatMessages(
      GetChatMessagesParams(
        projectId: projectProvider.currentProjectId,
        sessionId: sessionId,
      ),
    );

    result.fold((failure) => _handleFailure(failure), (messages) {
      _messages = messages;
      _setState(ChatState.loaded);
    });
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

    // Create chat input
    final input = ChatInput(
      messageId: messageId,
      providerId: _selectedProviderId ?? 'anthropic',
      modelId: _selectedModelId ?? 'claude-3-5-sonnet-20241022',
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
      print(
        '🔄 Updated message: ${message.id}, parts count: ${message.parts.length}',
      );
    } else {
      // Add new message
      _messages.add(message);
      print('➕ Add new message: ${message.id}, role: ${message.role}');
    }

    // Check if there is an unfinished assistant message
    if (message is AssistantMessage) {
      print(
        '🤖 Assistant message status: ${message.isCompleted ? "completed" : "in progress"}',
      );
      if (message.isCompleted && _state == ChatState.sending) {
        print('✅ Message completed, set state to loaded');
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
