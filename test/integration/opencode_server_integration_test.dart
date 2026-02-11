import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/datasources/app_remote_datasource.dart';
import 'package:codewalk/data/datasources/chat_remote_datasource.dart';
import 'package:codewalk/data/datasources/project_remote_datasource.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/data/repositories/app_repository_impl.dart';
import 'package:codewalk/data/repositories/chat_repository_impl.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
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
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
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

    test(
      'AppRepository reads /path, /provider and /agent successfully',
      () async {
        final dioClient = DioClient();
        dioClient.updateBaseUrl(server.baseUrl);

        final repository = AppRepositoryImpl(
          remoteDataSource: AppRemoteDataSourceImpl(dio: dioClient.dio),
          localDataSource: InMemoryAppLocalDataSource(),
          dioClient: dioClient,
        );

        final appInfoResult = await repository.getAppInfo();
        final providersResult = await repository.getProviders();
        final agentsResult = await repository.getAgents();

        expect(appInfoResult.isRight(), isTrue);
        expect(providersResult.isRight(), isTrue);
        expect(agentsResult.isRight(), isTrue);

        appInfoResult.fold((_) => fail('expected app info'), (appInfo) {
          expect(appInfo.path.root, '/workspace/project');
          expect(appInfo.path.cwd, '/workspace/project');
        });

        providersResult.fold((_) => fail('expected providers'), (providers) {
          expect(providers.providers, hasLength(1));
          expect(providers.defaultModels['mock-provider'], 'mock-model');
        });

        agentsResult.fold((_) => fail('expected agents'), (agents) {
          expect(agents.any((agent) => agent.name == 'build'), isTrue);
          expect(agents.any((agent) => agent.name == 'plan'), isTrue);
        });
      },
    );

    test(
      'ProjectRemoteDataSource supports project context and worktrees',
      () async {
        final remote = ProjectRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final projects = await remote.getProjects();
        expect(projects.projects.length, 2);

        final current = await remote.getCurrentProject(
          directory: '/workspace/alt',
        );
        expect(current.path, '/workspace/alt');

        final worktreesBefore = await remote.getWorktrees(
          directory: '/workspace',
        );
        expect(worktreesBefore, isNotEmpty);

        final created = await remote.createWorktree(
          'feature-15',
          directory: '/workspace/project',
        );
        expect(created.directory, '/workspace/project/feature-15');

        await remote.resetWorktree(created.id, directory: '/workspace/project');
        await remote.deleteWorktree(
          created.id,
          directory: '/workspace/project',
        );
      },
    );

    test('ChatRemoteDataSource subscribes to /global/event stream', () async {
      server.scriptedGlobalEvents = <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'session.updated',
          'properties': <String, dynamic>{'directory': '/workspace/project'},
        },
      ];
      final remote = ChatRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
      );

      final events = await remote.subscribeGlobalEvents().take(1).toList();
      expect(events.single.type, 'session.updated');
      expect(events.single.properties['directory'], '/workspace/project');
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
      'ChatRemoteDataSource supports lifecycle endpoints (status/todo/diff/share/fork/archive)',
      () async {
        server.sessionStatusById = <String, Map<String, dynamic>>{
          'ses_1': <String, dynamic>{'type': 'busy'},
        };
        server.sessionTodoById['ses_1'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'todo_1',
            'content': 'Implement lifecycle',
            'status': 'in_progress',
            'priority': 'high',
          },
        ];
        server.sessionDiffById['ses_1'] = <Map<String, dynamic>>[
          <String, dynamic>{
            'file': 'lib/main.dart',
            'before': 'old',
            'after': 'new',
            'additions': 8,
            'deletions': 2,
            'status': 'modified',
          },
        ];

        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final renamed = await remote.updateSession(
          'default',
          'ses_1',
          const SessionUpdateInputModel(title: 'Renamed Session'),
        );
        expect(renamed.title, 'Renamed Session');

        final archived = await remote.updateSession(
          'default',
          'ses_1',
          const SessionUpdateInputModel(archivedAtEpochMs: 1739079999999),
        );
        expect(archived.time.archived, 1739079999999);

        final unarchived = await remote.updateSession(
          'default',
          'ses_1',
          const SessionUpdateInputModel(archivedAtEpochMs: 0),
        );
        expect(unarchived.time.archived, isNull);

        final shared = await remote.shareSession('default', 'ses_1');
        expect(shared.share?.url, isNotNull);

        final unshared = await remote.unshareSession('default', 'ses_1');
        expect(unshared.share, isNull);

        final forked = await remote.forkSession('default', 'ses_1');
        expect(forked.parentId, 'ses_1');

        final children = await remote.getSessionChildren('default', 'ses_1');
        expect(children.map((item) => item.id), contains(forked.id));

        final todo = await remote.getSessionTodo('default', 'ses_1');
        expect(todo.single.id, 'todo_1');

        final diff = await remote.getSessionDiff('default', 'ses_1');
        expect(diff.single.file, 'lib/main.dart');

        final status = await remote.getSessionStatus();
        expect(status['ses_1']?.type, 'busy');
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

    test(
      'ChatRemoteDataSource sendMessage forwards directory to event and message fetch',
      () async {
        server.streamMessageUpdates = true;
        server.requiredEventDirectory = '/workspace/project';
        server.requiredMessageDirectory = '/workspace/project';

        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final messages = await remote
            .sendMessage(
              'default',
              'ses_1',
              const ChatInputModel(
                messageId: 'msg_user_dir_1',
                providerId: 'mock-provider',
                modelId: 'mock-model',
                parts: <ChatInputPartModel>[
                  ChatInputPartModel(type: 'text', text: 'hello directory'),
                ],
              ),
              directory: '/workspace/project',
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

    test('ChatRemoteDataSource includes agent in outbound payload', () async {
      final remote = ChatRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
      );

      await remote
          .sendMessage(
            'default',
            'ses_1',
            const ChatInputModel(
              messageId: 'msg_user_agent',
              providerId: 'mock-provider',
              modelId: 'mock-model',
              mode: 'plan',
              parts: <ChatInputPartModel>[
                ChatInputPartModel(type: 'text', text: 'agent please'),
              ],
            ),
          )
          .first;

      expect(server.lastSendMessagePayload, isNotNull);
      expect(server.lastSendMessagePayload?['agent'], 'plan');
    });

    test(
      'ChatRemoteDataSource subscribes and reconnects on SSE closure',
      () async {
        server.eventCloseDelayMs = 40;
        server.scriptedEventsByConnection = <List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'session.status',
              'properties': <String, dynamic>{
                'sessionID': 'ses_1',
                'status': <String, dynamic>{'type': 'busy'},
              },
            },
          ],
          <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'question.asked',
              'properties': <String, dynamic>{
                'id': 'q_1',
                'sessionID': 'ses_1',
                'questions': <dynamic>[
                  <String, dynamic>{
                    'question': 'Proceed?',
                    'header': 'Confirm',
                    'options': <dynamic>[
                      <String, dynamic>{
                        'label': 'Yes',
                        'description': 'continue',
                      },
                    ],
                  },
                ],
              },
            },
          ],
        ];

        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final collected = await remote
            .subscribeEvents()
            .map((event) => event.type)
            .where((type) => type != 'server.connected')
            .take(2)
            .toList();

        expect(collected, <String>['session.status', 'question.asked']);
        expect(server.eventConnectionCount, greaterThanOrEqualTo(2));
      },
    );

    test(
      'ChatRemoteDataSource lists and responds to permission/question prompts',
      () async {
        server.pendingPermissions = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'perm_1',
            'sessionID': 'ses_1',
            'permission': 'edit',
            'patterns': <String>['lib/**'],
            'always': <String>[],
            'metadata': <String, dynamic>{},
          },
        ];
        server.pendingQuestions = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'q_1',
            'sessionID': 'ses_1',
            'questions': <dynamic>[
              <String, dynamic>{
                'question': 'Continue?',
                'header': 'Confirm',
                'options': <dynamic>[
                  <String, dynamic>{
                    'label': 'Yes',
                    'description': 'Continue execution',
                  },
                ],
              },
            ],
          },
        ];

        final remote = ChatRemoteDataSourceImpl(
          dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
        );

        final permissions = await remote.listPermissions();
        final questions = await remote.listQuestions();
        expect(permissions.single.id, 'perm_1');
        expect(questions.single.id, 'q_1');

        await remote.replyPermission(requestId: 'perm_1', reply: 'once');
        expect(server.lastPermissionReplyRequestId, 'perm_1');
        expect(server.lastPermissionReplyPayload?['reply'], 'once');

        await remote.replyQuestion(
          requestId: 'q_1',
          answers: const <List<String>>[
            <String>['Yes'],
          ],
        );
        expect(server.lastQuestionReplyRequestId, 'q_1');
        expect(
          server.lastQuestionReplyPayload?['answers'],
          const <List<String>>[
            <String>['Yes'],
          ],
        );
      },
    );

    test('ChatRemoteDataSource rejects pending question requests', () async {
      server.pendingQuestions = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'q_reject_1',
          'sessionID': 'ses_1',
          'questions': <dynamic>[
            <String, dynamic>{
              'question': 'Stop execution?',
              'header': 'Confirm',
              'options': <dynamic>[
                <String, dynamic>{
                  'label': 'Stop',
                  'description': 'Reject request',
                },
              ],
            },
          ],
        },
      ];

      final remote = ChatRemoteDataSourceImpl(
        dio: Dio(BaseOptions(baseUrl: server.baseUrl)),
      );

      final before = await remote.listQuestions();
      expect(before.single.id, 'q_reject_1');

      await remote.rejectQuestion(requestId: 'q_reject_1');
      expect(server.lastQuestionRejectRequestId, 'q_reject_1');

      final after = await remote.listQuestions();
      expect(after, isEmpty);
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
          projectRepository: FakeProjectRepository(
            currentProject: Project(
              id: 'proj_workspace',
              name: 'Workspace',
              path: '/workspace/project',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
            projects: <Project>[
              Project(
                id: 'proj_workspace',
                name: 'Workspace',
                path: '/workspace/project',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            ],
          ),
          localDataSource: localDataSource,
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
