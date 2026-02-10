import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
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
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../../support/fakes.dart';

void main() {
  group('ChatProvider', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;

    setUp(() {
      chatRepository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Session 1',
          ),
        ],
      );
      appRepository = FakeAppRepository();
      localDataSource = InMemoryAppLocalDataSource();
      localDataSource.activeServerId = 'srv_test';

      provider = ChatProvider(
        sendChatMessage: SendChatMessage(chatRepository),
        getChatSessions: GetChatSessions(chatRepository),
        createChatSession: CreateChatSession(chatRepository),
        getChatMessages: GetChatMessages(chatRepository),
        getChatMessage: GetChatMessage(chatRepository),
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
        projectProvider: ProjectProvider(
          projectRepository: FakeProjectRepository(),
          localDataSource: localDataSource,
        ),
        localDataSource: localDataSource,
      );
    });

    test(
      'initializeProviders chooses first connected provider and default model',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': _model('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_b': 'model_b'},
            connected: const <String>['provider_b'],
          ),
        );

        await provider.initializeProviders();

        expect(provider.providers, hasLength(2));
        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_b');
      },
    );

    test(
      'setSelectedModel and cycleVariant update selection and payload',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_reasoning': _model(
                    'model_reasoning',
                    variants: const <String, ModelVariant>{
                      'low': ModelVariant(id: 'low', name: 'Low'),
                      'high': ModelVariant(id: 'high', name: 'High'),
                    },
                  ),
                },
              ),
            ],
            defaultModels: const <String, String>{
              'provider_a': 'model_reasoning',
            },
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        expect(provider.selectedVariantId, isNull);

        await provider.cycleVariant();
        expect(provider.selectedVariantId, 'low');

        await provider.cycleVariant();
        expect(provider.selectedVariantId, 'high');

        await provider.cycleVariant();
        expect(provider.selectedVariantId, isNull);

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.setSelectedVariant('high');
        await provider.sendMessage('variant payload');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.lastSendInput?.variant, 'high');
        expect(chatRepository.lastSendInput?.messageId, isNull);
      },
    );

    test('cycleVariant is no-op when current model has no variants', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'model_plain': _model('model_plain')},
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_plain'},
          connected: const <String>['provider_a'],
        ),
      );

      await provider.initializeProviders();
      expect(provider.selectedVariantId, isNull);

      await provider.cycleVariant();
      expect(provider.selectedVariantId, isNull);
    });

    test(
      'initializeProviders restores recent/frequent model preference from local storage',
      () async {
        final scopeId =
            provider.projectProvider.currentProject?.path ??
            provider.projectProvider.currentProjectId;

        await localDataSource.saveRecentModelsJson(
          jsonEncode(<String>['provider_b/model_hot']),
          serverId: 'srv_test',
          scopeId: scopeId,
        );
        await localDataSource.saveModelUsageCountsJson(
          jsonEncode(<String, int>{'provider_b/model_hot': 7}),
          serverId: 'srv_test',
          scopeId: scopeId,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_hot': _model('model_hot')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>[],
          ),
        );

        await provider.initializeProviders();

        expect(provider.selectedProviderId, 'provider_b');
        expect(provider.selectedModelId, 'model_hot');
        expect(provider.recentModelKeys.first, 'provider_b/model_hot');
        expect(provider.modelUsageCounts['provider_b/model_hot'], 7);
      },
    );

    test('loadSessions merges cache startup with remote refresh', () async {
      await provider.projectProvider.initializeProject();

      final cachedSession = ChatSession(
        id: 'cached_1',
        workspaceId: 'default',
        time: DateTime.fromMillisecondsSinceEpoch(500),
        title: 'Cached Session',
      );
      final cachedJson = jsonEncode(<Map<String, dynamic>>[
        ChatSessionModel.fromDomain(cachedSession).toJson(),
      ]);
      await localDataSource.saveCachedSessions(
        cachedJson,
        serverId: 'srv_test',
        scopeId: '/tmp',
      );

      await provider.loadSessions();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.state, ChatState.loaded);
      expect(provider.sessions.first.id, anyOf('cached_1', 'ses_1'));

      final savedScoped =
          localDataSource.scopedStrings['cached_sessions::srv_test::/tmp'];
      expect(savedScoped, isNotNull);
      final savedCache = jsonDecode(savedScoped!) as List<dynamic>;
      expect(
        (savedCache.first as Map<String, dynamic>)['id'],
        anyOf('cached_1', 'ses_1'),
      );
    });

    test(
      'sendMessage appends user message and final assistant reply',
      () async {
        final assistantPartial = AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_partial',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'draft',
            ),
          ],
        );
        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_done',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'final answer',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantPartial);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello provider');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.messages.length, 2);
        expect((provider.messages.first as UserMessage).parts, hasLength(1));
        final assistant = provider.messages.last as AssistantMessage;
        expect((assistant.parts.single as TextPart).text, 'final answer');
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello provider'),
        );
        expect(chatRepository.lastSendInput?.messageId, isNull);
        expect(
          chatRepository.lastSendDirectory,
          provider.projectProvider.currentProject?.path,
        );
      },
    );

    test(
      'sendMessage works when recent models are restored from local storage',
      () async {
        final scopeId =
            provider.projectProvider.currentProject?.path ??
            provider.projectProvider.currentProjectId;
        await localDataSource.saveRecentModelsJson(
          jsonEncode(<String>['provider_a/model_a']),
          serverId: 'srv_test',
          scopeId: scopeId,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_recent_storage',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_recent_storage_done',
              messageId: 'msg_assistant_recent_storage',
              sessionId: 'ses_1',
              text: 'answer from restored recent model',
            ),
          ],
        );
        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello from restored recent storage');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.state, ChatState.loaded);
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello from restored recent storage'),
        );
        final assistant = provider.messages.last as AssistantMessage;
        expect(
          (assistant.parts.single as TextPart).text,
          'answer from restored recent model',
        );
      },
    );

    test(
      'sendMessage continues when local selection persistence fails',
      () async {
        final failingLocalDataSource = _ThrowingPersistenceLocalDataSource();
        failingLocalDataSource.activeServerId = 'srv_test';

        final resilientProvider = ChatProvider(
          sendChatMessage: SendChatMessage(chatRepository),
          getChatSessions: GetChatSessions(chatRepository),
          createChatSession: CreateChatSession(chatRepository),
          getChatMessages: GetChatMessages(chatRepository),
          getChatMessage: GetChatMessage(chatRepository),
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
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(),
            localDataSource: failingLocalDataSource,
          ),
          localDataSource: failingLocalDataSource,
        );

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        final assistantCompleted = AssistantMessage(
          id: 'msg_assistant_resilient',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_resilient_done',
              messageId: 'msg_assistant_resilient',
              sessionId: 'ses_1',
              text: 'resilient answer',
            ),
          ],
        );
        chatRepository.sendMessageHandler = (_, __, ___, ____) async* {
          yield Right(assistantCompleted);
        };

        await resilientProvider.projectProvider.initializeProject();
        await resilientProvider.initializeProviders();
        await resilientProvider.loadSessions();
        await resilientProvider.selectSession(resilientProvider.sessions.first);

        await resilientProvider.sendMessage('hello with persistence failure');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(resilientProvider.state, ChatState.loaded);
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: 'hello with persistence failure'),
        );
        expect(chatRepository.lastSendInput?.messageId, isNull);
        final assistant = resilientProvider.messages.last as AssistantMessage;
        expect((assistant.parts.single as TextPart).text, 'resilient answer');
      },
    );

    test('renameSession applies persisted title on success', () async {
      await provider.loadSessions();
      final session = provider.sessions.first;

      final ok = await provider.renameSession(session, 'Renamed Session');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(ok, isTrue);
      expect(
        provider.sessions.where((item) => item.id == session.id).first.title,
        'Renamed Session',
      );
      expect(
        chatRepository.sessions
            .where((item) => item.id == session.id)
            .first
            .title,
        'Renamed Session',
      );
    });

    test('renameSession rolls back optimistic title on failure', () async {
      await provider.loadSessions();
      final session = provider.sessions.first;
      chatRepository.updateSessionFailure = const ServerFailure(
        'update failed',
      );

      final ok = await provider.renameSession(session, 'Broken Rename');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(ok, isFalse);
      expect(
        provider.sessions.where((item) => item.id == session.id).first.title,
        'Session 1',
      );
      expect(provider.state, ChatState.error);
    });

    test(
      'share/archive/fork lifecycle operations update provider state',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1200),
            title: 'Session 2',
          ),
        );

        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );

        final shared = await provider.toggleSessionShare(
          provider.currentSession!,
        );
        expect(shared, isTrue);
        expect(provider.currentSession?.shared, isTrue);
        expect(provider.currentSession?.shareUrl, isNotNull);

        final archived = await provider.setSessionArchived(
          provider.currentSession!,
          true,
        );
        expect(archived, isTrue);
        final archivedSession = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        expect(archivedSession.archived, isTrue);

        final unarchived = await provider.setSessionArchived(
          archivedSession,
          false,
        );
        expect(unarchived, isTrue);
        final unarchivedSession = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        expect(unarchivedSession.archived, isFalse);

        final forked = await provider.forkSession(unarchivedSession);
        expect(forked, isNotNull);
        expect(forked?.parentId, 'ses_1');
        expect(provider.currentSession?.id, forked?.id);
      },
    );

    test(
      'loadSessionInsights updates children, todo, diff and status maps',
      () async {
        final child = ChatSession(
          id: 'ses_child_1',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          title: 'Child Session',
          parentId: 'ses_1',
        );
        chatRepository.sessionChildrenById['ses_1'] = <ChatSession>[child];
        chatRepository.sessionTodoById['ses_1'] = const <SessionTodo>[
          SessionTodo(
            id: 'todo_1',
            content: 'Implement feature',
            status: 'in_progress',
            priority: 'high',
          ),
        ];
        chatRepository.sessionDiffById['ses_1'] = const <SessionDiff>[
          SessionDiff(
            file: 'lib/main.dart',
            before: '',
            after: '',
            additions: 10,
            deletions: 2,
            status: 'modified',
          ),
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionChildren, hasLength(1));
        expect(provider.currentSessionChildren.single.id, 'ses_child_1');
        expect(provider.currentSessionTodo, hasLength(1));
        expect(provider.currentSessionTodo.single.id, 'todo_1');
        expect(provider.currentSessionDiff, hasLength(1));
        expect(provider.currentSessionDiff.single.file, 'lib/main.dart');
        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      },
    );

    test(
      'deleteSession clears current session when deleting active one',
      () async {
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentSession?.id, 'ses_1');

        await provider.deleteSession('ses_1');
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(provider.sessions, isEmpty);
        expect(provider.currentSession, isNull);
        expect(provider.messages, isEmpty);
      },
    );

    test('loadSessions surfaces mapped failure state', () async {
      chatRepository.getSessionsFailure = const NetworkFailure('no network');

      await provider.loadSessions();

      expect(provider.state, ChatState.error);
      expect(
        provider.errorMessage,
        'Network connection failed. Please check network settings',
      );
    });

    test(
      'applies realtime message.updated fallback fetch and session status',
      () async {
        final draft = AssistantMessage(
          id: 'msg_ai_live',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_draft',
              messageId: 'msg_ai_live',
              sessionId: 'ses_1',
              text: 'draft',
            ),
          ],
        );
        final completed = AssistantMessage(
          id: 'msg_ai_live',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_done',
              messageId: 'msg_ai_live',
              sessionId: 'ses_1',
              text: 'done',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[draft];

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        expect(
          ((provider.messages.single as AssistantMessage).parts.single
                  as TextPart)
              .text,
          'draft',
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[completed];
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'msg_ai_live',
                'sessionID': 'ses_1',
              },
            },
          ),
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'done');
        expect(message.isCompleted, isTrue);
        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      },
    );

    test(
      'loads and responds to pending permission and question requests',
      () async {
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Proceed?',
                header: 'Confirm',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'continue'),
                ],
              ),
            ],
          ),
        ];
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': _model('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentPermissionRequest?.id, 'perm_1');
        expect(provider.currentQuestionRequest?.id, 'q_1');

        await provider.respondPermissionRequest(
          requestId: 'perm_1',
          reply: 'once',
        );
        expect(chatRepository.lastPermissionRequestId, 'perm_1');
        expect(chatRepository.lastPermissionReply, 'once');

        await provider.submitQuestionAnswers(
          requestId: 'q_1',
          answers: const <List<String>>[
            <String>['Yes'],
          ],
        );
        expect(chatRepository.lastQuestionReplyRequestId, 'q_1');
        expect(chatRepository.lastQuestionAnswers, const <List<String>>[
          <String>['Yes'],
        ]);
      },
    );

    test(
      'switches project context with isolated directory session state',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();
        expect(scopedRepository.lastGetSessionsDirectory, '/repo/a');
        expect(scopedProvider.sessions.first.id, 'ses_a');

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedRepository.lastGetSessionsDirectory, '/repo/b');
        expect(scopedProvider.sessions.first.id, 'ses_b');

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.first.id, 'ses_a');
      },
    );

    test(
      'switching project restores last session for each directory automatically',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A Old',
            ),
            ChatSession(
              id: 'ses_a_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A New',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();

        expect(scopedProvider.currentSession?.id, 'ses_a_new');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/a'],
          'ses_a_new',
        );

        scopedRepository.sessions
          ..clear()
          ..addAll(<ChatSession>[
            ChatSession(
              id: 'ses_b_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              title: 'Session B Old',
            ),
            ChatSession(
              id: 'ses_b_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2500),
              title: 'Session B New',
            ),
          ]);
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedProvider.currentSession?.id, 'ses_b_new');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/b'],
          'ses_b_new',
        );

        final oldSessionB = scopedProvider.sessions
            .where((session) => session.id == 'ses_b_old')
            .first;
        await scopedProvider.selectSession(oldSessionB);
        expect(scopedProvider.currentSession?.id, 'ses_b_old');
        expect(
          scopedLocal.scopedStrings['current_session_id::srv_test::/repo/b'],
          'ses_b_old',
        );

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.currentSession?.id, 'ses_a_new');

        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.currentSession?.id, 'ses_b_old');
      },
    );

    test(
      'filters mixed session list to active directory when server returns unscoped data',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A',
              directory: '/repo/a',
            ),
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
              directory: '/repo/b',
            ),
            ChatSession(
              id: 'ses_unknown',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session Unknown',
            ),
          ],
        );

        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();

        expect(scopedRepository.lastGetSessionsDirectory, '/repo/a');
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_a',
        ]);

        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedRepository.lastGetSessionsDirectory, '/repo/b');
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_b',
        ]);
      },
    );

    test(
      'global event marks non-active context dirty and reloads on return',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a_old',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A Old',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getProviders: GetProviders(appRepository),
          deleteChatSession: DeleteChatSession(scopedRepository),
          updateChatSession: UpdateChatSession(scopedRepository),
          shareChatSession: ShareChatSession(scopedRepository),
          unshareChatSession: UnshareChatSession(scopedRepository),
          forkChatSession: ForkChatSession(scopedRepository),
          getSessionStatus: GetSessionStatus(scopedRepository),
          getSessionChildren: GetSessionChildren(scopedRepository),
          getSessionTodo: GetSessionTodo(scopedRepository),
          getSessionDiff: GetSessionDiff(scopedRepository),
          watchChatEvents: WatchChatEvents(scopedRepository),
          watchGlobalChatEvents: WatchGlobalChatEvents(scopedRepository),
          listPendingPermissions: ListPendingPermissions(scopedRepository),
          replyPermission: ReplyPermission(scopedRepository),
          listPendingQuestions: ListPendingQuestions(scopedRepository),
          replyQuestion: ReplyQuestion(scopedRepository),
          rejectQuestion: RejectQuestion(scopedRepository),
          projectProvider: ProjectProvider(
            projectRepository: FakeProjectRepository(
              currentProject: Project(
                id: 'proj_a',
                name: 'Project A',
                path: '/repo/a',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
              projects: <Project>[
                Project(
                  id: 'proj_a',
                  name: 'Project A',
                  path: '/repo/a',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                ),
                Project(
                  id: 'proj_b',
                  name: 'Project B',
                  path: '/repo/b',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
                ),
              ],
            ),
            localDataSource: scopedLocal,
          ),
          localDataSource: scopedLocal,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();
        expect(scopedProvider.sessions.first.id, 'ses_a_old');

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.first.id, 'ses_b');

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{'directory': '/repo/a'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_a_new',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session A New',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();

        expect(scopedProvider.sessions.first.id, 'ses_a_new');
      },
    );
  });
}

Model _model(
  String id, {
  Map<String, ModelVariant> variants = const <String, ModelVariant>{},
}) {
  return Model(
    id: id,
    name: id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
    variants: variants,
  );
}

class _ThrowingPersistenceLocalDataSource extends InMemoryAppLocalDataSource {
  @override
  Future<void> saveSelectedProvider(
    String providerId, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedProvider failed');
  }

  @override
  Future<void> saveSelectedModel(
    String modelId, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedModel failed');
  }

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveRecentModelsJson failed');
  }

  @override
  Future<void> saveModelUsageCountsJson(
    String usageCountsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveModelUsageCountsJson failed');
  }

  @override
  Future<void> saveSelectedVariantMap(
    String variantMapJson, {
    String? serverId,
    String? scopeId,
  }) async {
    throw Exception('saveSelectedVariantMap failed');
  }
}
