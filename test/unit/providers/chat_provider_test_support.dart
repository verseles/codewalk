// Shared utilities for ChatProvider split test files.
//
// Contains public versions of helpers that were originally private in the
// monolithic chat_provider_test.dart. No main() — this is not a test file.
import 'dart:convert';

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
import 'package:codewalk/domain/usecases/abort_chat_session.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/get_session_children.dart';
import 'package:codewalk/domain/usecases/get_session_diff.dart';
import 'package:codewalk/domain/usecases/get_session_status.dart';
import 'package:codewalk/domain/usecases/get_session_todo.dart';
import 'package:codewalk/domain/usecases/list_pending_permissions.dart';
import 'package:codewalk/domain/usecases/list_pending_questions.dart';
import 'package:codewalk/domain/usecases/reject_question.dart';
import 'package:codewalk/domain/usecases/reply_permission.dart';
import 'package:codewalk/domain/usecases/reply_question.dart';
import 'package:codewalk/domain/usecases/revert_chat_message.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unrevert_chat_messages.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/cellular_data_saver_service.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:codewalk/presentation/services/event_feedback_dispatcher.dart';
import 'package:codewalk/presentation/services/session_tab_icon_override_store.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../support/fakes.dart';

/// Fake DIO client that records GET/PATCH calls to /config.
class RecordingDioClient extends DioClient {
  RecordingDioClient({Map<String, dynamic>? configResponse})
    : _configResponse = configResponse ?? <String, dynamic>{},
      super(baseUrl: 'http://localhost');

  final Map<String, dynamic> _configResponse;
  final List<Map<String, dynamic>?> getQueries = <Map<String, dynamic>?>[];
  final List<Map<String, dynamic>?> patchQueries = <Map<String, dynamic>?>[];
  final List<dynamic> patchBodies = <dynamic>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/config') {
      getQueries.add(queryParameters);
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _configResponse as T,
      );
    }
    throw UnimplementedError('Unexpected GET path in test: $path');
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path == '/config') {
      patchQueries.add(queryParameters);
      patchBodies.add(data);
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: _configResponse as T,
      );
    }
    throw UnimplementedError('Unexpected PATCH path in test: $path');
  }
}

/// Extracts the __codewalk sync payload from a PATCH body.
Map<String, dynamic>? codewalkSyncPayloadFromPatch(dynamic body) {
  if (body is! Map) {
    return null;
  }
  final agent = body['agent'];
  if (agent is! Map) {
    return null;
  }
  final syncAgent = agent['__codewalk'];
  if (syncAgent is! Map) {
    return null;
  }
  final options = syncAgent['options'];
  if (options is! Map) {
    return null;
  }
  final codewalk = options['codewalk'];
  if (codewalk is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(codewalk);
}

/// Extracts the selection sub-map from a PATCH body.
Map<String, dynamic>? selectionPayloadFromPatch(dynamic body) {
  final codewalk = codewalkSyncPayloadFromPatch(body);
  final selection = codewalk?['selection'];
  if (selection is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(selection);
}

/// Extracts the variant value for a specific agent/model key from a PATCH body.
String? variantPayloadValueFromPatch(
  dynamic body, {
  required String agentName,
  required String modelKey,
}) {
  final codewalk = codewalkSyncPayloadFromPatch(body);
  if (codewalk != null) {
    final byAgent = codewalk['variantByAgentAndModel'];
    if (byAgent is Map) {
      final agentMap = byAgent[agentName];
      if (agentMap is Map) {
        final value = agentMap[modelKey];
        if (value != null) {
          return value.toString();
        }
      }
    }
  }

  if (body is! Map) {
    return null;
  }
  final agent = body['agent'];
  if (agent is! Map) {
    return null;
  }
  final legacyAgent = agent[agentName];
  if (legacyAgent is! Map) {
    return null;
  }
  final options = legacyAgent['options'];
  if (options is! Map) {
    return null;
  }
  final legacyCodewalk = options['codewalk'];
  if (legacyCodewalk is! Map) {
    return null;
  }
  final variantByModel = legacyCodewalk['variantByModel'];
  if (variantByModel is! Map) {
    return null;
  }
  final value = variantByModel[modelKey];
  return value?.toString();
}

/// Creates a test [Model] with sensible defaults.
Model testModel(
  String id, {
  Map<String, ModelVariant> variants = const <String, ModelVariant>{},
  ModelCost cost = const ModelCost(input: 0.001, output: 0.002),
  bool hidden = false,
  String? status,
}) {
  return Model(
    id: id,
    name: id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: cost,
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
    variants: variants,
    hidden: hidden,
    status: status,
  );
}

/// Builds a [ChatProvider] wired to fake repositories and test defaults.
ChatProvider buildChatProvider({
  required FakeChatRepository chatRepository,
  required FakeAppRepository appRepository,
  required InMemoryAppLocalDataSource localDataSource,
  required SettingsProvider defaultSettingsProvider,
  DioClient? dioClient,
  Duration syncSignalStaleThreshold = const Duration(seconds: 20),
  Duration syncHealthCheckInterval = const Duration(seconds: 5),
  Duration abortSuppressionWindow = const Duration(milliseconds: 30),
  Duration shortcutCycleWindow = const Duration(seconds: 3),
  DateTime Function()? sessionTabsNow,
  SettingsProvider? settingsProvider,
  CellularDataSaverService? cellularDataSaverService,
  EventFeedbackDispatcher? eventFeedbackDispatcher,
  ChatTitleGenerator? titleGenerator,
  Future<void> Function(SessionAttentionAggregate aggregate)?
  sessionAttentionAggregatePublisher,
  Future<void> Function(bool isForeground)?
  sessionAttentionAppForegroundPublisher,
  ProjectProvider? projectProvider,
  SessionTabIconOverrideStore? sessionTabIconOverrideStore,
}) {
  return ChatProvider(
    sendChatMessage: SendChatMessage(chatRepository),
    abortChatSession: AbortChatSession(chatRepository),
    getChatSessions: GetChatSessions(chatRepository),
    createChatSession: CreateChatSession(chatRepository),
    getChatMessages: GetChatMessages(chatRepository),
    getChatMessage: GetChatMessage(chatRepository),
    getAgents: GetAgents(appRepository),
    getProviders: GetProviders(appRepository),
    deleteChatSession: DeleteChatSession(chatRepository),
    updateChatSession: UpdateChatSession(chatRepository),
    shareChatSession: ShareChatSession(chatRepository),
    unshareChatSession: UnshareChatSession(chatRepository),
    forkChatSession: ForkChatSession(chatRepository),
    getSessionStatus: GetSessionStatus(chatRepository),
    getSessionChildren: GetSessionChildren(chatRepository),
    getSessionTodo: GetSessionTodo(chatRepository),
    getSessionDiff: GetSessionDiff(chatRepository),
    watchChatEvents: WatchChatEvents(chatRepository),
    watchGlobalChatEvents: WatchGlobalChatEvents(chatRepository),
    listPendingPermissions: ListPendingPermissions(chatRepository),
    replyPermission: ReplyPermission(chatRepository),
    listPendingQuestions: ListPendingQuestions(chatRepository),
    replyQuestion: ReplyQuestion(chatRepository),
    rejectQuestion: RejectQuestion(chatRepository),
    revertChatMessage: RevertChatMessage(chatRepository),
    unrevertChatMessages: UnrevertChatMessages(chatRepository),
    projectProvider:
        projectProvider ??
        ProjectProvider(
          projectRepository: FakeProjectRepository(),
          localDataSource: localDataSource,
        ),
    localDataSource: localDataSource,
    settingsProvider: settingsProvider ?? defaultSettingsProvider,
    dioClient: dioClient,
    cellularDataSaverService: cellularDataSaverService,
    eventFeedbackDispatcher: eventFeedbackDispatcher,
    titleGenerator: titleGenerator,
    sessionAttentionAggregatePublisher: sessionAttentionAggregatePublisher,
    sessionAttentionAppForegroundPublisher:
        sessionAttentionAppForegroundPublisher,
    syncSignalStaleThreshold: syncSignalStaleThreshold,
    syncHealthCheckInterval: syncHealthCheckInterval,
    abortSuppressionWindow: abortSuppressionWindow,
    shortcutCycleWindow: shortcutCycleWindow,
    sessionTabsNow: sessionTabsNow,
    sessionTabIconOverrideStore: sessionTabIconOverrideStore,
  );
}

/// Holds the pre-initialized fake repositories and settings provider that every
/// ChatProvider test file needs in its setUp. Build with [buildDefaultTestFixtures].
class ChatProviderTestFixtures {
  ChatProviderTestFixtures({
    required this.chatRepository,
    required this.appRepository,
    required this.localDataSource,
    required this.defaultSettingsProvider,
  });

  final FakeChatRepository chatRepository;
  final FakeAppRepository appRepository;
  final InMemoryAppLocalDataSource localDataSource;
  final SettingsProvider defaultSettingsProvider;
}

/// Builds the standard test fixtures shared by all ChatProvider split-test
/// files. Call in setUp and assign results to the group-level late variables,
/// then build the provider with the local buildProvider() wrapper.
Future<ChatProviderTestFixtures> buildDefaultTestFixtures() async {
  final chatRepository = FakeChatRepository(
    sessions: <ChatSession>[
      ChatSession(
        id: 'ses_1',
        workspaceId: 'default',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        title: 'Session 1',
      ),
    ],
  );
  final appRepository = FakeAppRepository()
    ..providersResult = Right(
      ProvidersResponse(
        providers: <Provider>[
          Provider(
            id: 'provider_a',
            name: 'Provider A',
            env: const <String>[],
            models: <String, Model>{'model_a': testModel('model_a')},
          ),
        ],
        defaultModels: const <String, String>{'provider_a': 'model_a'},
        connected: const <String>['provider_a'],
      ),
    );
  final localDataSource = InMemoryAppLocalDataSource();
  localDataSource.activeServerId = 'srv_test';

  localDataSource.experienceSettingsJson = jsonEncode(
    ExperienceSettings.defaults()
        .copyWith(enableExperimentalMultiDeviceSync: true)
        .toJson(),
  );
  final defaultSettingsProvider = SettingsProvider(
    localDataSource: localDataSource,
    dioClient: RecordingDioClient(),
    soundService: SoundService(),
  );
  await defaultSettingsProvider.initialize();

  return ChatProviderTestFixtures(
    chatRepository: chatRepository,
    appRepository: appRepository,
    localDataSource: localDataSource,
    defaultSettingsProvider: defaultSettingsProvider,
  );
}

/// Builds a [SettingsProvider] with controllable multi-device sync toggle.
Future<SettingsProvider> buildTestSettingsProvider({
  required InMemoryAppLocalDataSource localDataSource,
  required bool enableExperimentalMultiDeviceSync,
}) async {
  localDataSource.experienceSettingsJson = jsonEncode(
    ExperienceSettings.defaults()
        .copyWith(
          enableExperimentalMultiDeviceSync: enableExperimentalMultiDeviceSync,
        )
        .toJson(),
  );
  final settingsProvider = SettingsProvider(
    localDataSource: localDataSource,
    dioClient: RecordingDioClient(),
    soundService: SoundService(),
  );
  await settingsProvider.initialize();
  return settingsProvider;
}
