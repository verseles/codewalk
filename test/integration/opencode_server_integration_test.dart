import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/datasources/app_remote_datasource.dart';
import 'package:codewalk/data/datasources/chat_remote_datasource.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/data/repositories/app_repository_impl.dart';
import 'package:codewalk/data/repositories/chat_repository_impl.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../support/fakes.dart';
import '../support/mock_opencode_server.dart';

void main() {
  group('integration with controllable mock OpenCode server', () {
    late MockOpenCodeServer server;

    setUp(() async {
      server = MockOpenCodeServer();
      await server.start();
    });

    tearDown(() async {
      await server.close();
    });

    test('AppRepository reads /path and /provider successfully', () async {
      final dioClient = DioClient();
      dioClient.updateBaseUrl(server.baseUrl);

      final repository = AppRepositoryImpl(
        remoteDataSource: AppRemoteDataSourceImpl(dio: dioClient.dio),
        localDataSource: InMemoryAppLocalDataSource(),
        dioClient: dioClient,
      );

      final appInfoResult = await repository.getAppInfo();
      final providersResult = await repository.getProviders();

      expect(appInfoResult.isRight(), isTrue);
      expect(providersResult.isRight(), isTrue);

      appInfoResult.fold((_) => fail('expected app info'), (appInfo) {
        expect(appInfo.path.root, '/workspace/project');
        expect(appInfo.path.cwd, '/workspace/project');
      });

      providersResult.fold((_) => fail('expected providers'), (providers) {
        expect(providers.providers, hasLength(1));
        expect(providers.defaultModels['mock-provider'], 'mock-model');
      });
    });

    test(
      'ChatRemoteDataSource performs session CRUD against mock server',
      () async {
        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final before = await remote.getSessions();
        expect(before, hasLength(1));

        final created = await remote.createSession(
          'default',
          const SessionCreateInputModel(title: 'Created via integration test'),
        );

        final afterCreate = await remote.getSessions();
        expect(afterCreate.map((s) => s.id), contains(created.id));

        await remote.deleteSession('default', created.id);
        final afterDelete = await remote.getSessions();
        expect(afterDelete.map((s) => s.id), isNot(contains(created.id)));
      },
    );

    test(
      'ChatRemoteDataSource consumes SSE update after initial send response',
      () async {
        server.streamMessageUpdates = true;

        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final messages = await remote
            .sendMessage(
              'default',
              'ses_1',
              const ChatInputModel(
                messageId: 'msg_user_1',
                providerId: 'mock-provider',
                modelId: 'mock-model',
                parts: <ChatInputPartModel>[
                  ChatInputPartModel(type: 'text', text: 'hello integration'),
                ],
              ),
            )
            .toList();

        expect(messages.length, greaterThanOrEqualTo(2));
        expect((messages.first.parts.single).text, 'working');
        expect((messages.last.parts.single).text, 'done');
        expect(messages.last.completedTime, isNotNull);
      },
    );

    test('ChatRemoteDataSource includes variant in outbound payload', () async {
      final remote = ChatRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
      );

      await remote
          .sendMessage(
            'default',
            'ses_1',
            const ChatInputModel(
              messageId: 'msg_user_variant',
              providerId: 'mock-provider',
              modelId: 'mock-model',
              variant: 'high',
              parts: <ChatInputPartModel>[
                ChatInputPartModel(type: 'text', text: 'variant please'),
              ],
            ),
          )
          .first;

      expect(server.lastSendMessagePayload, isNotNull);
      expect(server.lastSendMessagePayload?['variant'], 'high');
    });

    test('ChatRepository maps send 400 error to ValidationFailure', () async {
      server.sendMessageValidationError = true;

      final repository = ChatRepositoryImpl(
        remoteDataSource: ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        ),
      );

      final streamValues = await repository
          .sendMessage(
            'default',
            'ses_1',
            const ChatInput(
              messageId: 'msg_user_2',
              providerId: 'mock-provider',
              modelId: 'mock-model',
              parts: <ChatInputPart>[TextInputPart(text: 'trigger 400')],
            ),
          )
          .toList();

      expect(streamValues, hasLength(1));
      streamValues.single.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test(
      'switching active server isolates session cache by server id',
      () async {
        final serverB = MockOpenCodeServer(
          initialSessionTitle: 'Second Server Session',
        );
        await serverB.start();
        addTearDown(() => serverB.close());

        final localDataSource = InMemoryAppLocalDataSource();
        final dioClient = DioClient();
        final appRepository = AppRepositoryImpl(
          remoteDataSource: AppRemoteDataSourceImpl(dio: dioClient.dio),
          localDataSource: localDataSource,
          dioClient: dioClient,
        );
        final chatRepository = ChatRepositoryImpl(
          remoteDataSource: ChatRemoteDataSourceImpl(dio: dioClient.dio),
        );
        final projectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(),
        );

        final appProvider = AppProvider(
          getAppInfo: GetAppInfo(appRepository),
          checkConnection: CheckConnection(appRepository),
          localDataSource: localDataSource,
          dioClient: dioClient,
          enableHealthPolling: false,
        );
        await appProvider.initialize();
        final initial = appProvider.activeServer!;
        await appProvider.updateServerProfile(
          id: initial.id,
          url: server.baseUrl,
          label: 'Server A',
          basicAuthEnabled: false,
          basicAuthUsername: '',
          basicAuthPassword: '',
        );
        await appProvider.addServerProfile(
          url: serverB.baseUrl,
          label: 'Server B',
        );

        final chatProvider = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(chatRepository),
          projectProvider: projectProvider,
          localDataSource: localDataSource,
        );
        await projectProvider.initializeProject();

        await chatProvider.initializeProviders();
        await chatProvider.loadSessions();
        expect(chatProvider.sessions.first.title, 'Initial Session');

        final serverBId = appProvider.serverProfiles
            .where((p) => p.label == 'Server B')
            .first
            .id;
        final switched = await appProvider.setActiveServer(serverBId);
        expect(switched, isTrue);
        await chatProvider.onServerScopeChanged();
        expect(chatProvider.sessions.first.title, 'Second Server Session');

        final serverAId = appProvider.serverProfiles
            .where((p) => p.label == 'Server A')
            .first
            .id;
        await appProvider.setActiveServer(serverAId);
        await chatProvider.onServerScopeChanged();
        expect(chatProvider.sessions.first.title, 'Initial Session');

        final scopeId =
            projectProvider.currentProject?.path ??
            projectProvider.currentProjectId;
        final keyA = 'cached_sessions::$serverAId::$scopeId';
        final keyB = 'cached_sessions::$serverBId::$scopeId';
        expect(localDataSource.scopedStrings[keyA], isNotNull);
        expect(localDataSource.scopedStrings[keyB], isNotNull);
        expect(
          localDataSource.scopedStrings[keyA],
          isNot(equals(localDataSource.scopedStrings[keyB])),
        );
      },
    );
  });
}
