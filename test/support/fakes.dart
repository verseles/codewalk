import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/data/datasources/app_local_datasource.dart';
import 'package:codewalk/domain/entities/app_info.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/worktree.dart';
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
  String? selectedVariantMapJson;
  String? recentModelsJson;
  String? modelUsageCountsJson;
  String? themeMode;
  String? lastSessionId;
  String? currentSessionId;
  String? currentProjectId;
  String? openProjectIdsJson;
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
    selectedVariantMapJson = null;
    recentModelsJson = null;
    modelUsageCountsJson = null;
    themeMode = null;
    lastSessionId = null;
    currentSessionId = null;
    currentProjectId = null;
    openProjectIdsJson = null;
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
  Future<String?> getCurrentProjectId({String? serverId}) async {
    if (serverId == null) return currentProjectId;
    return scopedStrings[_key('current_project_id', serverId: serverId)];
  }

  @override
  Future<String?> getOpenProjectIdsJson({String? serverId}) async {
    if (serverId == null) return openProjectIdsJson;
    return scopedStrings[_key('open_project_ids', serverId: serverId)];
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
  Future<String?> getSelectedVariantMap({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return selectedVariantMapJson;
    return scopedStrings[_key(
      'selected_variant_map',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getRecentModelsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return recentModelsJson;
    return scopedStrings[_key(
      'recent_models',
      serverId: serverId,
      scopeId: scopeId,
    )];
  }

  @override
  Future<String?> getModelUsageCountsJson({
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) return modelUsageCountsJson;
    return scopedStrings[_key(
      'model_usage_counts',
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
  Future<void> saveCurrentProjectId(
    String projectId, {
    String? serverId,
  }) async {
    if (serverId == null) {
      currentProjectId = projectId;
      return;
    }
    scopedStrings[_key('current_project_id', serverId: serverId)] = projectId;
  }

  @override
  Future<void> saveOpenProjectIdsJson(
    String projectIdsJson, {
    String? serverId,
  }) async {
    if (serverId == null) {
      openProjectIdsJson = projectIdsJson;
      return;
    }
    scopedStrings[_key('open_project_ids', serverId: serverId)] =
        projectIdsJson;
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
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      selectedVariantMapJson = variantMapJson;
      return;
    }
    scopedStrings[_key(
          'selected_variant_map',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        variantMapJson;
  }

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      this.recentModelsJson = recentModelsJson;
      return;
    }
    scopedStrings[_key('recent_models', serverId: serverId, scopeId: scopeId)] =
        recentModelsJson;
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (serverId == null && scopeId == null) {
      modelUsageCountsJson = usageCountsJson;
      return;
    }
    scopedStrings[_key(
          'model_usage_counts',
          serverId: serverId,
          scopeId: scopeId,
        )] =
        usageCountsJson;
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

  @override
  Future<void> clearChatContextCache({
    required String serverId,
    required String scopeId,
  }) async {
    scopedStrings.remove(
      _key('cached_sessions', serverId: serverId, scopeId: scopeId),
    );
    scopedInts.remove(
      _key('cached_sessions_updated_at', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key('current_session_id', serverId: serverId, scopeId: scopeId),
    );
    scopedStrings.remove(
      _key('last_session_id', serverId: serverId, scopeId: scopeId),
    );
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
  String? lastSendDirectory;
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
  Failure? updateSessionFailure;
  Failure? shareSessionFailure;
  Failure? unshareSessionFailure;
  Failure? forkSessionFailure;
  Failure? sessionStatusFailure;
  Failure? sessionChildrenFailure;
  Failure? sessionTodoFailure;
  Failure? sessionDiffFailure;
  final StreamController<Either<Failure, ChatEvent>> eventController =
      StreamController<Either<Failure, ChatEvent>>.broadcast();
  final StreamController<Either<Failure, ChatEvent>> globalEventController =
      StreamController<Either<Failure, ChatEvent>>.broadcast();
  List<ChatPermissionRequest> pendingPermissions = <ChatPermissionRequest>[];
  List<ChatQuestionRequest> pendingQuestions = <ChatQuestionRequest>[];
  String? lastPermissionRequestId;
  String? lastPermissionReply;
  String? lastPermissionMessage;
  String? lastQuestionReplyRequestId;
  List<List<String>>? lastQuestionAnswers;
  String? lastQuestionRejectRequestId;
  Map<String, SessionStatusInfo> sessionStatusById =
      <String, SessionStatusInfo>{};
  final Map<String, List<ChatSession>> sessionChildrenById =
      <String, List<ChatSession>>{};
  final Map<String, List<SessionTodo>> sessionTodoById =
      <String, List<SessionTodo>>{};
  final Map<String, List<SessionDiff>> sessionDiffById =
      <String, List<SessionDiff>>{};

  void emitEvent(ChatEvent event) {
    eventController.add(Right(event));
  }

  void emitEventFailure(Failure failure) {
    eventController.add(Left(failure));
  }

  void emitGlobalEvent(ChatEvent event) {
    globalEventController.add(Right(event));
  }

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
    String? search,
    bool? rootsOnly,
    int? startEpochMs,
    int? limit,
  }) async {
    lastGetSessionsDirectory = directory;
    if (getSessionsFailure != null) return Left(getSessionsFailure!);
    var list = List<ChatSession>.from(sessions);
    if (rootsOnly == true) {
      list = list
          .where((item) => item.parentId == null)
          .toList(growable: false);
    }
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      list = list
          .where(
            (item) =>
                (item.title ?? '').toLowerCase().contains(term) ||
                (item.summary ?? '').toLowerCase().contains(term),
          )
          .toList(growable: false);
    }
    if (startEpochMs != null) {
      list = list
          .where((item) => item.time.millisecondsSinceEpoch >= startEpochMs)
          .toList(growable: false);
    }
    if (limit != null && list.length > limit) {
      list = list.take(limit).toList(growable: false);
    }
    return Right(list);
  }

  @override
  Future<Either<Failure, Map<String, SessionStatusInfo>>> getSessionStatus({
    String? directory,
  }) async {
    if (sessionStatusFailure != null) {
      return Left(sessionStatusFailure!);
    }
    return Right(Map<String, SessionStatusInfo>.from(sessionStatusById));
  }

  @override
  Future<Either<Failure, List<ChatSession>>> getSessionChildren(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (sessionChildrenFailure != null) {
      return Left(sessionChildrenFailure!);
    }
    return Right(
      List<ChatSession>.from(
        sessionChildrenById[sessionId] ?? const <ChatSession>[],
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionTodo>>> getSessionTodo(
    String projectId,
    String sessionId, {
    String? directory,
  }) async {
    if (sessionTodoFailure != null) {
      return Left(sessionTodoFailure!);
    }
    return Right(
      List<SessionTodo>.from(
        sessionTodoById[sessionId] ?? const <SessionTodo>[],
      ),
    );
  }

  @override
  Future<Either<Failure, List<SessionDiff>>> getSessionDiff(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    if (sessionDiffFailure != null) {
      return Left(sessionDiffFailure!);
    }
    return Right(
      List<SessionDiff>.from(
        sessionDiffById[sessionId] ?? const <SessionDiff>[],
      ),
    );
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
  Future<Either<Failure, List<ChatPermissionRequest>>> listPermissions({
    String? directory,
  }) async {
    return Right(List<ChatPermissionRequest>.from(pendingPermissions));
  }

  @override
  Future<Either<Failure, void>> replyPermission({
    required String requestId,
    required String reply,
    String? message,
    String? directory,
  }) async {
    lastPermissionRequestId = requestId;
    lastPermissionReply = reply;
    lastPermissionMessage = message;
    pendingPermissions = pendingPermissions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<ChatQuestionRequest>>> listQuestions({
    String? directory,
  }) async {
    return Right(List<ChatQuestionRequest>.from(pendingQuestions));
  }

  @override
  Future<Either<Failure, void>> replyQuestion({
    required String requestId,
    required List<List<String>> answers,
    String? directory,
  }) async {
    lastQuestionReplyRequestId = requestId;
    lastQuestionAnswers = answers;
    pendingQuestions = pendingQuestions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> rejectQuestion({
    required String requestId,
    String? directory,
  }) async {
    lastQuestionRejectRequestId = requestId;
    pendingQuestions = pendingQuestions
        .where((item) => item.id != requestId)
        .toList(growable: false);
    return const Right(null);
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeEvents({String? directory}) {
    return eventController.stream;
  }

  @override
  Stream<Either<Failure, ChatEvent>> subscribeGlobalEvents() {
    return globalEventController.stream;
  }

  @override
  Stream<Either<Failure, ChatMessage>> sendMessage(
    String projectId,
    String sessionId,
    ChatInput input, {
    String? directory,
  }) {
    lastSendProjectId = projectId;
    lastSendSessionId = sessionId;
    lastSendDirectory = directory;
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
  }) async {
    if (shareSessionFailure != null) return Left(shareSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(
      shared: true,
      shareUrl: 'https://share.mock/$sessionId',
    );
    sessions[index] = updated;
    return Right(updated);
  }

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
  }) async {
    if (unshareSessionFailure != null) return Left(unshareSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(shared: false, shareUrl: null);
    sessions[index] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, ChatSession>> forkSession(
    String projectId,
    String sessionId, {
    String? messageId,
    String? directory,
  }) async {
    if (forkSessionFailure != null) return Left(forkSessionFailure!);
    final parent = sessions.where((item) => item.id == sessionId).firstOrNull;
    if (parent == null) {
      return const Left(NotFoundFailure('Session not found'));
    }
    final forked = ChatSession(
      id: 'ses_${sessions.length + 1}',
      workspaceId: parent.workspaceId,
      time: DateTime.now(),
      title: '${parent.title ?? 'Conversation'} (fork)',
      parentId: parent.id,
      directory: parent.directory,
    );
    sessions.insert(0, forked);
    sessionChildrenById.putIfAbsent(parent.id, () => <ChatSession>[])
      ..add(forked);
    return Right(forked);
  }

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
    if (updateSessionFailure != null) return Left(updateSessionFailure!);
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return const Left(NotFoundFailure('Session not found'));
    final updated = sessions[index].copyWith(
      title: input.title ?? sessions[index].title,
      archivedAt:
          input.archivedAtEpochMs == null || input.archivedAtEpochMs! <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(input.archivedAtEpochMs!),
    );
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
  FakeProjectRepository({
    Project? currentProject,
    List<Project>? projects,
    List<Worktree>? worktrees,
  }) : _currentProject =
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
           ],
       _worktrees = List<Worktree>.from(worktrees ?? <Worktree>[]);

  Project _currentProject;
  final List<Project> _projects;
  final List<Worktree> _worktrees;
  Failure? worktreeFailure;

  @override
  Future<Either<Failure, Project>> getCurrentProject({
    String? directory,
  }) async {
    if (directory != null && directory.trim().isNotEmpty) {
      final byDirectory = _projects
          .where((project) => project.path == directory)
          .firstOrNull;
      if (byDirectory != null) {
        return Right(byDirectory);
      }
    }
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

  @override
  Future<Either<Failure, List<Worktree>>> getWorktrees({
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    if (directory == null || directory.trim().isEmpty) {
      return Right(List<Worktree>.from(_worktrees));
    }
    return Right(
      _worktrees
          .where((item) => item.directory.startsWith(directory))
          .toList(growable: false),
    );
  }

  @override
  Future<Either<Failure, Worktree>> createWorktree(
    String name, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    final normalized = name.trim().toLowerCase().replaceAll(' ', '-');
    final base = directory ?? '/tmp';
    final created = Worktree(
      id: 'wt_${_worktrees.length + 1}',
      name: name,
      directory: '$base/$normalized',
      projectId: _currentProject.id,
      active: false,
      createdAt: DateTime.now(),
    );
    _worktrees.add(created);
    return Right(created);
  }

  @override
  Future<Either<Failure, void>> resetWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteWorktree(
    String worktreeId, {
    String? directory,
  }) async {
    if (worktreeFailure != null) {
      return Left(worktreeFailure!);
    }
    _worktrees.removeWhere((item) => item.id == worktreeId);
    return const Right(null);
  }
}

DioException dioConnectionError([String message = 'connection error']) {
  return DioException(
    requestOptions: RequestOptions(path: '/'),
    type: DioExceptionType.connectionError,
    message: message,
  );
}
