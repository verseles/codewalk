import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/data/datasources/app_local_datasource.dart';
import 'package:codewalk/domain/entities/app_info.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/repositories/app_repository.dart';
import 'package:codewalk/domain/repositories/chat_repository.dart';
import 'package:codewalk/domain/repositories/project_repository.dart';

class InMemoryAppLocalDataSource implements AppLocalDataSource {
  String? serverHost;
  int? serverPort;
  String? serverProfilesJson;
  String? activeServerId;
  String? defaultServerId;
  String? apiKey;
  String? selectedProvider;
  String? selectedModel;
  String? themeMode;
  String? lastSessionId;
  String? currentSessionId;
  String? cachedSessions;
  int? cachedSessionsUpdatedAt;
  bool? basicAuthEnabled;
  String? basicAuthUsername;
  String? basicAuthPassword;
  final Map<String, String> scopedStrings = <String, String>{};
  final Map<String, int> scopedInts = <String, int>{};
  final Map<String, bool> scopedBools = <String, bool>{};

  String _key(String base, {String? serverId, String? scopeId}) {
    if (serverId == null || serverId.isEmpty) {
      return base;
    }
    if (scopeId == null || scopeId.isEmpty) {
      return '$base::$serverId';
    }
    return '$base::$serverId::$scopeId';
  }

  @override
  Future<void> clearAll() async {
    serverHost = null;
    serverPort = null;
    serverProfilesJson = null;
    activeServerId = null;
    defaultServerId = null;
    apiKey = null;
    selectedProvider = null;
    selectedModel = null;
    themeMode = null;
    lastSessionId = null;
    currentSessionId = null;
    cachedSessions = null;
    cachedSessionsUpdatedAt = null;
    basicAuthEnabled = null;
    basicAuthUsername = null;
    basicAuthPassword = null;
    scopedStrings.clear();
    scopedInts.clear();
    scopedBools.clear();
  }

  @override
  Future<String?> getActiveServerId() async => activeServerId;

  @override
  Future<String?> getApiKey({String? serverId}) async {
    if (serverId == null) return apiKey;
    return scopedStrings[_key('api_key', serverId: serverId)];
  }

  @override
  Future<bool?> getBasicAuthEnabled({String? serverId}) async {
    if (serverId == null) return basicAuthEnabled;
    return scopedBools[_key('basic_auth_enabled', serverId: serverId)];
  }

  @override
  Future<String?> getBasicAuthPassword({String? serverId}) async {
    if (serverId == null) return basicAuthPassword;
    return scopedStrings[_key('basic_auth_password', serverId: serverId)];
  }

  @override
  Future<String?> getBasicAuthUsername({String? serverId}) async {
    if (serverId == null) return basicAuthUsername;
    return scopedStrings[_key('basic_auth_username', serverId: serverId)];
  }

  @override
  Future<String?> getCachedSessions({String? serverId, String? scopeId}) async {
    if (serverId == null && scopeId == null) return cachedSessions;
    return scopedStrings[_key(
      'cached_sessions',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<int?> getCachedSessionsUpdatedAt({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return cachedSessionsUpdatedAt;
    return scopedInts[_key(
      'cached_sessions_updated_at',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getCurrentSessionId({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return currentSessionId;
    return scopedStrings[_key(
      'current_session_id',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getDefaultServerId() async => defaultServerId;

  @override
  Future<String?> getLastSessionId() async => lastSessionId;

  @override
  Future<String?> getSelectedModel({String? serverId, String? scopeId}) async {
    if (serverId == null && scopeId == null) return selectedModel;
    return scopedStrings[_key(
      'selected_model',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getSelectedProvider({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return selectedProvider;
    return scopedStrings[_key(
      'selected_provider',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getServerProfilesJson() async => serverProfilesJson;

  @override
  Future<String?> getServerHost() async => serverHost;

  @override
  Future<int?> getServerPort() async => serverPort;

  @override
  Future<String?> getThemeMode() async => themeMode;

  @override
  Future<void> saveActiveServerId(String serverId) async {
    activeServerId = serverId;
  }

  @override
  Future<void> saveApiKey(String apiKey, {String? serverId}) async {
    if (serverId == null) {
      this.apiKey = apiKey;
      return;
    }
    scopedStrings[_key('api_key', serverId: serverId)] = apiKey;
  }

  @override
  Future<void> saveBasicAuthEnabled(bool enabled, {String? serverId}) async {
    if (serverId == null) {
      basicAuthEnabled = enabled;
      return;
    }
    scopedBools[_key('basic_auth_enabled', serverId: serverId)] = enabled;
  }

  @override
  Future<void> saveBasicAuthPassword(
    String password, {
    String? serverId,
  }) async {
    if (serverId == null) {
      basicAuthPassword = password;
      return;
    }
    scopedStrings[_key('basic_auth_password', serverId: serverId)] = password;
  }

  @override
  Future<void> saveBasicAuthUsername(
    String username, {
    String? serverId,
  }) async {
    if (serverId == null) {
      basicAuthUsername = username;
      return;
    }
    scopedStrings[_key('basic_auth_username', serverId: serverId)] = username;
  }

  @override
  Future<void> saveCachedSessions(
    String sessionsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      cachedSessions = sessionsJson;
      return;
    }
    scopedStrings[_key(
          'cached_sessions',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionsJson;
  }

  @override
  Future<void> saveCachedSessionsUpdatedAt(
    int epochMs, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      cachedSessionsUpdatedAt = epochMs;
      return;
    }
    scopedInts[_key(
          'cached_sessions_updated_at',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        epochMs;
  }

  @override
  Future<void> saveCurrentSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      currentSessionId = sessionId;
      return;
    }
    scopedStrings[_key(
          'current_session_id',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionId;
  }

  @override
  Future<void> saveDefaultServerId(String? serverId) async {
    defaultServerId = serverId;
  }

  @override
  Future<void> saveLastSessionId(
    String sessionId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      lastSessionId = sessionId;
      return;
    }
    scopedStrings[_key(
          'last_session_id',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        sessionId;
  }

  @override
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedModel = modelId;
      return;
    }
    scopedStrings[_key(
          'selected_model',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        modelId;
  }

  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedProvider = providerId;
      return;
    }
    scopedStrings[_key(
          'selected_provider',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        providerId;
  }

  @override
  Future<void> saveServerProfilesJson(String profilesJson) async {
    serverProfilesJson = profilesJson;
  }

  @override
  Future<void> saveServerHost(String host) async {
    serverHost = host;
  }

  @override
  Future<void> saveServerPort(int port) async {
    serverPort = port;
  }

  @override
  Future<void> saveThemeMode(String themeMode) async {
    this.themeMode = themeMode;
  }
}

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    List<ChatSession>? sessions,
    this.providersDefault = const ProvidersResponse(
      providers: <Provider>[],
      defaultModels: <String, String>{},
      connected: <String>[],
    ),
  }) : sessions = sessions ?? <ChatSession>[];

  final List<ChatSession> sessions;
  final Map<String, List<ChatMessage>> messagesBySession =
      <String, List<ChatMessage>>{};
  final ProvidersResponse providersDefault;

  String? lastGetSessionsDirectory;
  String? lastSendProjectId;
  String? lastSendSessionId;
  ChatInput? lastSendInput;
  Stream<Either<Failure, ChatMessage>> Function(
    String projectId,
    String sessionId,
    ChatInput input,
    String? directory,
  )?
  sendMessageHandler;

  Failure? getSessionsFailure;
  Failure? createSessionFailure;
  Failure? getMessagesFailure;
  Failure? deleteSessionFailure;

  @override
  Future<Either<Failure, void>> abortSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, ChatSession>> createSession(
    String projectId,
    SessionCreateInput input, {
    String? directory,
  }) async {
    if (createSessionFailure != null) return Left(createSessionFailure!);
    final created = ChatSession(
      id: 'ses_${sessions.length + 1}',
      workspaceId: 'default',
      time: DateTime.now(),
      title: input.title ?? 'New chat',
    );
    sessions.insert(0, created);
    messagesBySession.putIfAbsent(created.id, () => <ChatMessage>[]);
    return Right(created);
  }

  @override
  Future<Either<Failure, void>> deleteSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (deleteSessionFailure != null) return Left(deleteSessionFailure!);
    sessions.removeWhere((s) => s.id == sessionId);
    messagesBySession.remove(sessionId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, ChatMessage>> getMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async {
    final found = messagesBySession[sessionId]
        ?.where((m) => m.id == messageId)
        .firstOrNull;
    if (found == null) {
      return const Left(NotFoundFailure('Message not found'));
    }
    return Right(found);
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (getMessagesFailure != null) return Left(getMessagesFailure!);
    return Right(
      List<ChatMessage>.from(messagesBySession[sessionId] ?? const []),
    );
  }

  @override
  Future<Either<Failure, ChatSession>> getSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    final found = sessions.where((s) => s.id == sessionId).firstOrNull;
    if (found == null) {
      return const Left(NotFoundFailure('Session not found'));
    }
    return Right(found);
  }

  @override
  Future<Either<Failure, List<ChatSession>>> getSessions({
    String? directory,
  }) async {
    lastGetSessionsDirectory = directory;
    if (getSessionsFailure != null) return Left(getSessionsFailure!);
    return Right(List<ChatSession>.from(sessions));
  }

  @override
  Future<Either<Failure, void>> initSession(
    String projectId,
    String sessionId, {
    required String messageId,
    required String providerId,
    required String modelId,
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, void>> revertMessage(
    String projectId,
    String sessionId,
    String messageId, {
    String? directory,
  }) async => const Right(null);

  @override
  Stream<Either<Failure, ChatMessage>> sendMessage(
    String projectId,
    String sessionId,
    ChatInput input, {
    String? directory,
  }) {
    lastSendProjectId = projectId;
    lastSendSessionId = sessionId;
    lastSendInput = input;

    if (sendMessageHandler != null) {
      return sendMessageHandler!(projectId, sessionId, input, directory);
    }

    final assistant = AssistantMessage(
      id: 'msg_assistant_1',
      sessionId: sessionId,
      time: DateTime.now(),
      completedTime: DateTime.now(),
      parts: const <MessagePart>[
        TextPart(
          id: 'prt_assistant_1',
          messageId: 'msg_assistant_1',
          sessionId: 'session',
          text: 'ok',
        ),
      ],
    );
    messagesBySession
        .putIfAbsent(sessionId, () => <ChatMessage>[])
        .add(assistant);
    return Stream<Either<Failure, ChatMessage>>.value(Right(assistant));
  }

  @override
  Future<Either<Failure, ChatSession>> shareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async => getSession(projectId, sessionId, directory: directory);

  @override
  Future<Either<Failure, void>> summarizeSession(
    String projectId,
    String sessionId, {
    required String providerId,
    required String modelId,
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, ChatSession>> unshareSession(
    String projectId,
    String sessionId, {
    String? directory,
  }) async => getSession(projectId, sessionId, directory: directory);

  @override
  Future<Either<Failure, void>> unrevertMessages(
    String projectId,
    String sessionId, {
    String? directory,
  }) async => const Right(null);

  @override
  Future<Either<Failure, ChatSession>> updateSession(
    String projectId,
    String sessionId,
    SessionUpdateInput input, {
    String? directory,
  }) async {
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(title: input.title);
    sessions[index] = updated;
    return Right(updated);
  }
}

class FakeAppRepository implements AppRepository {
  Either<Failure, AppInfo> appInfoResult = Right(
    AppInfo(
      hostname: 'localhost',
      git: true,
      path: const AppPath(
        config: '/tmp/config',
        data: '/tmp/data',
        root: '/tmp/root',
        cwd: '/tmp/cwd',
        state: '/tmp/state',
      ),
      time: const AppTime(initialized: 1),
    ),
  );
  Either<Failure, bool> checkConnectionResult = const Right(true);
  Either<Failure, bool> initializeResult = const Right(true);
  Either<Failure, ProvidersResponse> providersResult = const Right(
    ProvidersResponse(
      providers: <Provider>[],
      defaultModels: <String, String>{},
      connected: <String>[],
    ),
  );
  String? updatedHost;
  int? updatedPort;

  @override
  Future<Either<Failure, bool>> checkConnection({String? directory}) async {
    return checkConnectionResult;
  }

  @override
  Future<Either<Failure, AppInfo>> getAppInfo({String? directory}) async {
    return appInfoResult;
  }

  @override
  Future<Either<Failure, ProvidersResponse>> getProviders({
    String? directory,
  }) async {
    return providersResult;
  }

  @override
  Future<Either<Failure, bool>> initializeApp({String? directory}) async {
    return initializeResult;
  }

  @override
  Future<Either<Failure, void>> updateServerConfig(
    String host,
    int port,
  ) async {
    updatedHost = host;
    updatedPort = port;
    return const Right(null);
  }
}

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository({Project? currentProject, List<Project>? projects})
    : _currentProject =
          currentProject ??
          Project(
            id: 'default',
            name: 'Default',
            path: '/tmp',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
      _projects =
          projects ??
          <Project>[
            Project(
              id: 'default',
              name: 'Default',
              path: '/tmp',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ];

  final Project _currentProject;
  final List<Project> _projects;

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    return Right(_currentProject);
  }

  @override
  Future<Either<Failure, Project>> getProject(String projectId) async {
    return Right(
      _projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => _currentProject,
      ),
    );
  }

  @override
  Future<Either<Failure, List<Project>>> getProjects() async {
    return Right(_projects);
  }
}

DioException dioConnectionError([String message = 'connection error']) {
  return DioException(
    requestOptions: RequestOptions(path: '/'),
    type: DioExceptionType.connectionError,
    message: message,
  );
}
