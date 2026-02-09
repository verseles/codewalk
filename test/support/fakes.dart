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

  @override
  Future<void> clearAll() async {
    serverHost = null;
    serverPort = null;
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
  }

  @override
  Future<String?> getApiKey() async => apiKey;

  @override
  Future<bool?> getBasicAuthEnabled() async => basicAuthEnabled;

  @override
  Future<String?> getBasicAuthPassword() async => basicAuthPassword;

  @override
  Future<String?> getBasicAuthUsername() async => basicAuthUsername;

  @override
  Future<String?> getCachedSessions() async => cachedSessions;

  @override
  Future<int?> getCachedSessionsUpdatedAt() async => cachedSessionsUpdatedAt;

  @override
  Future<String?> getCurrentSessionId() async => currentSessionId;

  @override
  Future<String?> getLastSessionId() async => lastSessionId;

  @override
  Future<String?> getSelectedModel() async => selectedModel;

  @override
  Future<String?> getSelectedProvider() async => selectedProvider;

  @override
  Future<String?> getServerHost() async => serverHost;

  @override
  Future<int?> getServerPort() async => serverPort;

  @override
  Future<String?> getThemeMode() async => themeMode;

  @override
  Future<void> saveApiKey(String apiKey) async {
    this.apiKey = apiKey;
  }

  @override
  Future<void> saveBasicAuthEnabled(bool enabled) async {
    basicAuthEnabled = enabled;
  }

  @override
  Future<void> saveBasicAuthPassword(String password) async {
    basicAuthPassword = password;
  }

  @override
  Future<void> saveBasicAuthUsername(String username) async {
    basicAuthUsername = username;
  }

  @override
  Future<void> saveCachedSessions(String sessionsJson) async {
    cachedSessions = sessionsJson;
  }

  @override
  Future<void> saveCachedSessionsUpdatedAt(int epochMs) async {
    cachedSessionsUpdatedAt = epochMs;
  }

  @override
  Future<void> saveCurrentSessionId(String sessionId) async {
    currentSessionId = sessionId;
  }

  @override
  Future<void> saveLastSessionId(String sessionId) async {
    lastSessionId = sessionId;
  }

  @override
  Future<void> saveSelectedModel(String modelId) async {
    selectedModel = modelId;
  }

  @override
  Future<void> saveSelectedProvider(String providerId) async {
    selectedProvider = providerId;
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
