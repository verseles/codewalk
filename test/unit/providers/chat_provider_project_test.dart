@Tags(<String>['slow'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/agent.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/session_attention_overlay/session_attention_models.dart';
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
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/chat_title_generator.dart';
import 'package:codewalk/presentation/services/event_feedback_dispatcher.dart';
import 'package:codewalk/presentation/services/notification_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

class _ScopedGatedConfigDioClient extends DioClient {
  _ScopedGatedConfigDioClient({required this.configByDirectory})
    : super(baseUrl: 'http://localhost');

  final Map<String, Map<String, dynamic>> configByDirectory;
  String? gatedDirectory;
  Completer<void>? gatedRequestStarted;
  Completer<void>? gatedRequestRelease;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path != '/config') {
      throw UnimplementedError('Unexpected GET path in test: $path');
    }
    final directory = queryParameters?['directory'] as String? ?? '';
    if (directory == gatedDirectory) {
      final started = gatedRequestStarted;
      if (started != null && !started.isCompleted) {
        started.complete();
      }
      await gatedRequestRelease?.future;
      gatedDirectory = null;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: (configByDirectory[directory] ?? const <String, dynamic>{}) as T,
    );
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (path != '/config') {
      throw UnimplementedError('Unexpected PATCH path in test: $path');
    }
    final directory = queryParameters?['directory'] as String? ?? '';
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: (configByDirectory[directory] ?? const <String, dynamic>{}) as T,
    );
  }
}

void main() {
  group('ChatProvider - project', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;
    late SettingsProvider defaultSettingsProvider;

    ChatProvider buildProvider({
      DioClient? dioClient,
      Duration syncHealthCheckInterval = const Duration(seconds: 5),
      Duration abortSuppressionWindow = const Duration(milliseconds: 30),
      SettingsProvider? settingsProvider,
      Future<void> Function(SessionAttentionAggregate aggregate)?
      sessionAttentionAggregatePublisher,
      ProjectProvider? projectProvider,
    }) {
      return buildChatProvider(
        chatRepository: chatRepository,
        appRepository: appRepository,
        localDataSource: localDataSource,
        defaultSettingsProvider: defaultSettingsProvider,
        dioClient: dioClient,
        syncHealthCheckInterval: syncHealthCheckInterval,
        abortSuppressionWindow: abortSuppressionWindow,
        settingsProvider: settingsProvider,
        sessionAttentionAggregatePublisher: sessionAttentionAggregatePublisher,
        projectProvider: projectProvider,
      );
    }

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
      provider = buildProvider();
    });

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
                models: <String, Model>{'model_a': testModel('model_a')},
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
          sessionId: 'ses_1',
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
        expect(chatRepository.lastQuestionReplyRequestId, 'q_1');
        expect(chatRepository.lastQuestionAnswers, const <List<String>>[
          <String>['Yes'],
        ]);
      },
    );

    test(
      'delayed pending permission reload does not resurrect a replied request',
      () async {
        const permission = ChatPermissionRequest(
          id: 'perm_race_1',
          sessionId: 'ses_1',
          permission: 'edit',
          patterns: <String>['lib/**'],
          always: <String>[],
          metadata: <String, dynamic>{},
        );
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          permission,
        ];
        appRepository.providersResult = Right(
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

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        expect(provider.currentPermissionRequest?.id, 'perm_race_1');

        await provider.setForegroundActive(false);
        final reloadGate = Completer<void>();
        chatRepository.listPermissionsDelay = () => reloadGate.future;

        final resumeFuture = provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        await provider.respondPermissionRequest(
          sessionId: 'ses_1',
          requestId: 'perm_race_1',
          reply: 'once',
        );

        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          permission,
        ];
        reloadGate.complete();
        await resumeFuture;
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.lastPermissionRequestId, 'perm_race_1');
        expect(provider.currentPermissionRequest, isNull);
        expect(provider.currentThreadPermissionRequests, isEmpty);
      },
    );

    test(
      'respondPermissionRequest is blocked while realtime transport reconnects',
      () async {
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_blocked_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        appRepository.providersResult = Right(
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

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        chatRepository.emitEventFailure(const NetworkFailure('stream offline'));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await provider.respondPermissionRequest(
          sessionId: 'ses_1',
          requestId: 'perm_blocked_1',
          reply: 'once',
        );

        expect(chatRepository.lastPermissionRequestId, isNull);
        expect(provider.currentPermissionRequest?.id, 'perm_blocked_1');
        expect(
          provider.consumePendingUiNotice()?.message,
          contains('Reconnecting'),
        );
      },
    );

    test(
      'session.deleted does not clear pinned sessions before authoritative load completes',
      () async {
        await provider.projectProvider.initializeProject();
        final scopeId = provider.projectProvider.currentDirectory;
        await localDataSource.savePinnedSessionsJson(
          jsonEncode(<String>['ses_ghost']),
          serverId: 'srv_test',
          scopeId: scopeId,
        );

        await provider.initializeProviders();
        expect(provider.pinnedSessionIds, contains('ses_ghost'));

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.deleted',
            properties: <String, dynamic>{'sessionID': 'ses_ghost'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.pinnedSessionIds, contains('ses_ghost'));

        await provider.loadSessions();

        expect(provider.pinnedSessionIds, isNot(contains('ses_ghost')));
      },
    );

    test(
      'collects current-thread permissions including subagent descendants',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_child_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(900),
            title: 'Child Session',
            parentId: 'ses_1',
          ),
        );

        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_root_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
          ChatPermissionRequest(
            id: 'perm_sub_1',
            sessionId: 'ses_child_1',
            permission: 'bash',
            patterns: <String>['*'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
          ChatPermissionRequest(
            id: 'perm_other_1',
            sessionId: 'ses_unrelated',
            permission: 'read',
            patterns: <String>['README.md'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];

        appRepository.providersResult = Right(
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

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );

        expect(
          provider.currentThreadPermissionRequests.map((item) => item.id),
          <String>['perm_root_1', 'perm_sub_1'],
        );
        final currentSessionId = provider.currentSession?.id;
        final subagentRequestIds = provider.currentThreadPermissionRequests
            .where((item) => item.sessionId != currentSessionId)
            .map((item) => item.id)
            .toList(growable: false);

        expect(subagentRequestIds, <String>['perm_sub_1']);
      },
    );

    test(
      'collects current-thread questions including subagent descendants',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_child_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(900),
            title: 'Child Session',
            parentId: 'ses_1',
          ),
        );

        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_root_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Approve root?',
                header: 'Root',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Continue'),
                ],
              ),
            ],
          ),
          ChatQuestionRequest(
            id: 'q_sub_1',
            sessionId: 'ses_child_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Approve child?',
                header: 'Child',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Continue'),
                ],
              ),
            ],
          ),
          ChatQuestionRequest(
            id: 'q_other_1',
            sessionId: 'ses_unrelated',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Ignore other?',
                header: 'Other',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Continue'),
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
                models: <String, Model>{'model_a': testModel('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );

        expect(
          provider.currentThreadQuestionRequests.map((item) => item.id),
          <String>['q_root_1', 'q_sub_1'],
        );
      },
    );

    test(
      'rejectQuestionRequest removes pending question from provider state',
      () async {
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_reject_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Reject this?',
                header: 'Confirm',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'Yes', description: 'Reject'),
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
                models: <String, Model>{'model_a': testModel('model_a')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentQuestionRequest?.id, 'q_reject_1');

        await provider.rejectQuestionRequest(requestId: 'q_reject_1');

        expect(chatRepository.lastQuestionRejectRequestId, 'q_reject_1');
        expect(provider.currentQuestionRequest, isNull);
      },
    );

    test(
      'submitQuestionAnswers marks request as submit-failed on failure',
      () async {
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_submit_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Pick one',
                header: 'Pick',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'A', description: 'Alpha'),
                ],
              ),
            ],
          ),
        ];
        chatRepository.replyQuestionFailure = const ServerFailure(
          'submit rejected',
        );
        appRepository.providersResult = Right(
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

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        expect(provider.currentQuestionRequest?.id, 'q_submit_1');

        await provider.submitQuestionAnswers(
          requestId: 'q_submit_1',
          answers: <List<String>>[
            <String>['A'],
          ],
        );

        // Request stays in the pending list so the UI can show a retry state.
        expect(provider.currentQuestionRequest?.id, 'q_submit_1');
        expect(provider.questionSubmitFailedRequestIds, contains('q_submit_1'));

        // Clearing the error marker is exposed for the UI to use on retry.
        provider.dismissQuestionSubmitError('q_submit_1');
        expect(
          provider.questionSubmitFailedRequestIds,
          isNot(contains('q_submit_1')),
        );
      },
    );

    test(
      'questionSubmitFailedRequestIds is pruned when the request disappears',
      () async {
        // Seed a failure via the real submit path; the reply will fail
        // and the request will end up in questionSubmitFailedRequestIds.
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[
          ChatQuestionRequest(
            id: 'q_orphan_1',
            sessionId: 'ses_1',
            questions: <ChatQuestionInfo>[
              ChatQuestionInfo(
                question: 'Pick one',
                header: 'Pick',
                options: <ChatQuestionOption>[
                  ChatQuestionOption(label: 'A', description: 'Alpha'),
                ],
              ),
            ],
          ),
        ];
        chatRepository.replyQuestionFailure = const ServerFailure(
          'submit rejected',
        );
        appRepository.providersResult = Right(
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

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.submitQuestionAnswers(
          requestId: 'q_orphan_1',
          answers: <List<String>>[
            <String>['A'],
          ],
        );
        expect(provider.questionSubmitFailedRequestIds, contains('q_orphan_1'));

        // The submit-failure marker is retained for a short window so the user
        // can retry even if the server list momentarily omits the request;
        // once the retention expires, the reload prunes the orphan marker.
        provider.debugQuestionSubmitFailedRetention = Duration.zero;
        chatRepository.pendingQuestions = const <ChatQuestionRequest>[];
        await provider.reloadPendingInteractionsForTest();

        expect(
          provider.questionSubmitFailedRequestIds,
          isNot(contains('q_orphan_1')),
        );
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
          getAgents: GetAgents(appRepository),
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
      'project fast-path bounds in-flight stream cancellation across round-trip',
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
        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        var streamCancelled = false;
        final cancelStarted = Completer<void>();
        final cancelGate = Completer<void>();
        streamController.onCancel = () {
          streamCancelled = true;
          if (!cancelStarted.isCompleted) {
            cancelStarted.complete();
          }
          return cancelGate.future;
        };
        scopedRepository.sendMessageHandler = (_, _, _, _) {
          return streamController.stream;
        };
        addTearDown(() async {
          if (!cancelGate.isCompleted) {
            cancelGate.complete();
          }
          await streamController.close();
        });

        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
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
        await scopedProvider.selectSession(scopedProvider.sessions.first);

        await scopedProvider.sendMessage('keep this conversation alive');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await scopedProvider.projectProvider.switchProject('proj_b');
        final switchToProjectB = scopedProvider.onProjectScopeChanged(
          waitForRevalidation: false,
        );
        await cancelStarted.future.timeout(const Duration(milliseconds: 100));
        await switchToProjectB.timeout(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(streamCancelled, isTrue);
        expect(scopedProvider.currentSession?.id, 'ses_a');
        cancelGate.complete();
      },
    );

    test('pinned sessions stay isolated per project scope', () async {
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
        getAgents: GetAgents(appRepository),
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

      final projectASession = scopedProvider.sessions.first;
      await scopedProvider.toggleSessionPinned(projectASession);
      expect(scopedProvider.isSessionPinned('ses_a'), isTrue);

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

      expect(scopedProvider.isSessionPinned('ses_a'), isFalse);
      expect(scopedProvider.isSessionPinned('ses_b'), isFalse);

      scopedRepository.sessions
        ..clear()
        ..add(
          ChatSession(
            id: 'ses_a',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Session A',
          ),
        );
      await scopedProvider.projectProvider.switchProject('proj_a');
      await scopedProvider.onProjectScopeChanged();

      expect(scopedProvider.isSessionPinned('ses_a'), isTrue);
    });

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
          getAgents: GetAgents(appRepository),
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
      'project switch can return quickly and revalidate sessions in background',
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
          getAgents: GetAgents(appRepository),
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
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_a',
        ]);

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b_cached',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Session B Cached',
            ),
          );
        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_b_cached',
        ]);

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged();
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_a',
        ]);

        final networkGate = Completer<void>();
        final networkStarted = Completer<void>();
        scopedRepository.getSessionsDelay = () async {
          if (!networkStarted.isCompleted) {
            networkStarted.complete();
          }
          await networkGate.future;
        };
        final messagesGate = Completer<void>();
        final messagesStarted = Completer<void>();
        scopedRepository.getMessagesDelay = () async {
          if (!messagesStarted.isCompleted) {
            messagesStarted.complete();
          }
          await messagesGate.future;
        };

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_b_fresh',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: 'Session B Fresh',
            ),
          );

        await scopedProvider.projectProvider.switchProject('proj_b');
        await scopedProvider
            .onProjectScopeChanged(waitForRevalidation: false)
            .timeout(const Duration(milliseconds: 300));

        await networkStarted.future;
        await messagesStarted.future;
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_b_cached',
        ]);

        messagesGate.complete();
        networkGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(scopedProvider.sessions.map((item) => item.id), <String>[
          'ses_b_fresh',
        ]);
      },
    );

    test(
      'fast cold project switch preserves the persisted last-session snapshot',
      () async {
        final projectA = Project(
          id: 'proj_cold_a',
          name: 'Cold Project A',
          path: '/repo/cold/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_cold_b',
          name: 'Cold Project B',
          path: '/repo/cold/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        final sessionA = ChatSession(
          id: 'ses_cold_a',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Cold session A',
          directory: projectA.path,
        );
        final projectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(
            currentProject: projectA,
            projects: <Project>[projectA, projectB],
          ),
          localDataSource: localDataSource,
        );
        final scopedProvider = buildProvider(projectProvider: projectProvider);
        addTearDown(scopedProvider.dispose);
        chatRepository.sessions
          ..clear()
          ..add(sessionA);

        const snapshot = '{"sentinel":true}';
        await localDataSource.saveLastSessionSnapshot(
          snapshot,
          serverId: 'srv_test',
          scopeId: projectB.path,
        );
        await projectProvider.initializeProject();
        await scopedProvider.loadSessions();

        final networkGate = Completer<void>();
        chatRepository.getSessionsDelay = () => networkGate.future;
        await projectProvider.switchProject(projectB.id);
        await scopedProvider
            .onProjectScopeChanged(waitForRevalidation: false)
            .timeout(const Duration(milliseconds: 300));

        expect(
          await localDataSource.getLastSessionSnapshot(
            serverId: 'srv_test',
            scopeId: projectB.path,
          ),
          snapshot,
        );

        networkGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
    );

    test(
      'project switch fast-path does not leak draft mode across contexts',
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
          getAgents: GetAgents(appRepository),
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
        expect(scopedProvider.currentSession?.id, 'ses_a');

        await scopedProvider.beginNewChatDraft();
        expect(scopedProvider.isDraftingNewChat, isTrue);
        expect(scopedProvider.currentSession, isNull);

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
        await scopedProvider
            .onProjectScopeChanged(waitForRevalidation: false)
            .timeout(const Duration(milliseconds: 300));
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(scopedProvider.isDraftingNewChat, isFalse);
        expect(scopedProvider.currentSession?.id, 'ses_b');

        scopedRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Session A',
            ),
          );

        await scopedProvider.projectProvider.switchProject('proj_a');
        await scopedProvider
            .onProjectScopeChanged(waitForRevalidation: false)
            .timeout(const Duration(milliseconds: 300));
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(scopedProvider.isDraftingNewChat, isTrue);
        expect(scopedProvider.currentSession, isNull);
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
          getAgents: GetAgents(appRepository),
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
      'loadSessions excludes internal _title_gen sessions from Conversations',
      () async {
        chatRepository.sessions
          ..clear()
          ..addAll(<ChatSession>[
            ChatSession(
              id: 'ses_internal_title',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              title: ChatTitleGenerator.ephemeralSessionTitle,
            ),
            ChatSession(
              id: 'ses_user_visible',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Visible Conversation',
            ),
          ]);

        await provider.loadSessions();

        expect(provider.sessions.map((session) => session.id), <String>[
          'ses_user_visible',
        ]);
        expect(provider.visibleSessions.map((session) => session.id), <String>[
          'ses_user_visible',
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
          getAgents: GetAgents(appRepository),
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

    test(
      'global session.updated patches inactive cached sessions immediately',
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
          getAgents: GetAgents(appRepository),
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
        expect(scopedProvider.sessions.first.title, 'Session A Old');

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
        expect(scopedProvider.sessions.first.title, 'Session B');

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'info': <String, dynamic>{
                'id': 'ses_a_old',
                'workspaceId': 'default',
                'title': 'Session A Renamed',
                'time': <String, dynamic>{'created': 1000, 'updated': 3000},
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final inactiveSessions = scopedProvider.visibleSessionsForScopeId(
          '/repo/a',
        );
        expect(inactiveSessions, isNotEmpty);
        expect(inactiveSessions.first.title, 'Session A Renamed');
      },
    );

    test(
      'global idle status transition preserves inactive recent unread attention',
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
              id: 'ses_a_child',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1100),
              title: 'Child A',
              parentId: 'ses_a_old',
            ),
          ],
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final feedbackDispatcher = _RecordingEventFeedbackDispatcher(
          settingsProvider: defaultSettingsProvider,
        );
        final scopedProvider = ChatProvider(
          sendChatMessage: SendChatMessage(scopedRepository),
          getChatSessions: GetChatSessions(scopedRepository),
          createChatSession: CreateChatSession(scopedRepository),
          getChatMessages: GetChatMessages(scopedRepository),
          getChatMessage: GetChatMessage(scopedRepository),
          getAgents: GetAgents(appRepository),
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
          eventFeedbackDispatcher: feedbackDispatcher,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();

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

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'sessionID': 'ses_a_old',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'sessionID': 'ses_a_child',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final busyAttention = scopedProvider.sessionAttentionForScope(
          'ses_a_old',
          scopeId: '/repo/a',
        );
        expect(busyAttention.isActive, isTrue);
        expect(busyAttention.hasUnreadCompletion, isFalse);

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'sessionID': 'ses_a_old',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final unreadAttentionAfterStatus = scopedProvider
            .sessionAttentionForScope('ses_a_old', scopeId: '/repo/a');
        expect(unreadAttentionAfterStatus.isActive, isFalse);
        expect(unreadAttentionAfterStatus.hasUnreadCompletion, isTrue);
        expect(unreadAttentionAfterStatus.unreadCompletionAt, isNotNull);
        expect(feedbackDispatcher.handledTypes, contains('session.idle'));
        expect(feedbackDispatcher.lastCurrentSessionId, 'ses_b');
        feedbackDispatcher.clear();

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'sessionID': 'ses_a_old',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final unreadAttention = scopedProvider.sessionAttentionForScope(
          'ses_a_old',
          scopeId: '/repo/a',
        );
        expect(unreadAttention.isActive, isFalse);
        expect(unreadAttention.hasUnreadCompletion, isTrue);
        expect(unreadAttention.unreadCompletionAt, isNotNull);
        expect(feedbackDispatcher.handledTypes, isEmpty);

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'id': 'question_inactive_project',
              'sessionID': 'ses_a_child',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Proceed in inactive project?',
                  'header': 'Inactive project',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'Yes',
                      'description': 'Continue',
                    },
                  ],
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final pendingAttention = scopedProvider.sessionAttentionForScope(
          'ses_a_child',
          scopeId: '/repo/a',
        );
        expect(pendingAttention.hasPendingInteraction, isTrue);
        expect(feedbackDispatcher.handledTypes, contains('question.asked'));

        final firstAggregate = scopedProvider.rootSessionAttentionAggregate();
        expect(firstAggregate.candidates, hasLength(1));
        expect(
          firstAggregate.candidates.single.identity,
          const SessionAttentionIdentity(
            serverId: 'srv_test',
            directory: '/repo/a',
            rootSessionId: 'ses_a_old',
          ),
        );
        expect(
          firstAggregate.candidates.single.kind,
          RootSessionAttentionKind.pendingInteraction,
        );
        final nextAggregate = scopedProvider.rootSessionAttentionAggregate();
        expect(nextAggregate.generation, firstAggregate.generation);
        expect(nextAggregate.revision, firstAggregate.revision + 1);

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'question.replied',
            properties: <String, dynamic>{
              'directory': '/repo/a',
              'sessionID': 'ses_a_child',
              'requestID': 'question_inactive_project',
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final clearedAttention = scopedProvider.sessionAttentionForScope(
          'ses_a_child',
          scopeId: '/repo/a',
        );
        expect(clearedAttention.hasPendingInteraction, isFalse);
        expect(feedbackDispatcher.dismissedSessionIds, contains('ses_a_child'));
      },
    );

    test(
      'publishes live root attention outside the widget render gate',
      () async {
        final published = <SessionAttentionAggregate>[];
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_background_attention',
            workspaceId: 'default',
            directory: '/repo/a',
            time: DateTime.fromMillisecondsSinceEpoch(500),
            title: 'Background work',
          ),
        );
        chatRepository.sessionStatusById['ses_background_attention'] =
            const SessionStatusInfo(type: SessionStatusType.busy);
        provider.dispose();
        provider = buildProvider(
          sessionAttentionAggregatePublisher: (aggregate) async {
            published.add(aggregate);
          },
        );

        await provider.loadSessions();
        await provider.refreshSessionStatusSnapshot();
        await Future<void>.delayed(const Duration(milliseconds: 180));

        expect(published, isNotEmpty);
        expect(
          published.last.candidates.any(
            (candidate) =>
                candidate.identity.rootSessionId ==
                    'ses_background_attention' &&
                candidate.kind == RootSessionAttentionKind.active,
          ),
          isTrue,
        );
      },
    );

    test(
      'dirty inactive context keeps cached sessions visible during fast switch',
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
          getAgents: GetAgents(appRepository),
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
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(scopedProvider.sessions.first.id, 'ses_b');

        scopedRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{'directory': '/repo/a'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final revalidationGate = Completer<void>();
        final revalidationStarted = Completer<void>();
        scopedRepository.getSessionsDelay = () async {
          if (!revalidationStarted.isCompleted) {
            revalidationStarted.complete();
          }
          await revalidationGate.future;
        };
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
        await scopedProvider
            .onProjectScopeChanged(waitForRevalidation: false)
            .timeout(const Duration(milliseconds: 300));

        await revalidationStarted.future;
        expect(scopedProvider.sessions.first.id, 'ses_a_old');

        revalidationGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(scopedProvider.sessions.first.id, 'ses_a_new');
      },
    );

    test('toggleModelFavorite adds and removes model from favorites', () async {
      appRepository.providersResult = Right(
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'prov_a',
              name: 'Provider A',
              env: const <String>[],
              models: <String, Model>{'mod_a': testModel('mod_a')},
            ),
          ],
          defaultModels: const <String, String>{'prov_a': 'mod_a'},
          connected: const <String>['prov_a'],
        ),
      );
      await provider.initializeProviders();

      expect(
        provider.isModelFavorite(providerId: 'prov_a', modelId: 'mod_a'),
        isFalse,
      );

      await provider.toggleModelFavorite(
        providerId: 'prov_a',
        modelId: 'mod_a',
      );
      expect(
        provider.isModelFavorite(providerId: 'prov_a', modelId: 'mod_a'),
        isTrue,
      );
      expect(provider.favoriteModelKeys, contains('prov_a/mod_a'));

      await provider.toggleModelFavorite(
        providerId: 'prov_a',
        modelId: 'mod_a',
      );
      expect(
        provider.isModelFavorite(providerId: 'prov_a', modelId: 'mod_a'),
        isFalse,
      );
      expect(provider.favoriteModelKeys, isEmpty);
    });

    test(
      'favorite models persist and reload across provider instances',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'prov_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'mod_a': testModel('mod_a')},
              ),
            ],
            defaultModels: const <String, String>{'prov_a': 'mod_a'},
            connected: const <String>['prov_a'],
          ),
        );
        await provider.initializeProviders();
        await provider.toggleModelFavorite(
          providerId: 'prov_a',
          modelId: 'mod_a',
        );

        // Verify the data was persisted to local storage.
        final storedJson = await localDataSource.getFavoriteModelsJson(
          serverId: 'srv_test',
        );
        expect(storedJson, isNotNull);
        final decoded = json.decode(storedJson!) as List<dynamic>;
        expect(decoded, contains('prov_a/mod_a'));

        // Build a new provider instance and verify favorites are loaded.
        final provider2 = buildProvider();
        await provider2.initializeProviders();
        // Let coalesced microtask notifications flush before asserting.
        await Future<void>.delayed(Duration.zero);
        expect(
          provider2.isModelFavorite(providerId: 'prov_a', modelId: 'mod_a'),
          isTrue,
        );
        provider2.dispose();
      },
    );

    test(
      'legacy scoped favorite models are deleted after server migration',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'prov_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'mod_a': testModel('mod_a')},
              ),
            ],
            defaultModels: const <String, String>{'prov_a': 'mod_a'},
            connected: const <String>['prov_a'],
          ),
        );
        await localDataSource.saveFavoriteModelsJson(
          json.encode(<String>['prov_a/mod_a']),
          serverId: 'srv_test',
          scopeId: 'default',
        );

        await provider.initializeProviders();

        expect(
          await localDataSource.getFavoriteModelsJson(
            serverId: 'srv_test',
            scopeId: 'default',
          ),
          isNull,
        );
        expect(
          await localDataSource.getFavoriteModelsJson(serverId: 'srv_test'),
          isNotNull,
        );
      },
    );

    test(
      'favorite models stay shared across projects on the same server',
      () async {
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProjectProvider = ProjectProvider(
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
        );
        final scopedProvider = ChatProvider(
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
          projectProvider: scopedProjectProvider,
          localDataSource: scopedLocal,
        );
        addTearDown(scopedProvider.dispose);

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'prov_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'mod_a': testModel('mod_a')},
              ),
            ],
            defaultModels: const <String, String>{'prov_a': 'mod_a'},
            connected: const <String>['prov_a'],
          ),
        );

        await scopedProjectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.toggleModelFavorite(
          providerId: 'prov_a',
          modelId: 'mod_a',
        );

        await scopedProjectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged();
        await scopedProvider.initializeProviders();

        expect(
          scopedProvider.isModelFavorite(
            providerId: 'prov_a',
            modelId: 'mod_a',
          ),
          isTrue,
        );
      },
    );

    test(
      'warm switch restores target composer selection before refresh completes',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_b',
          name: 'Project B',
          path: '/repo/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        await scopedLocal.saveSelectedProvider(
          'prov_a',
          serverId: 'srv_test',
          scopeId: projectA.path,
        );
        await scopedLocal.saveSelectedModel(
          'mod_a',
          serverId: 'srv_test',
          scopeId: projectA.path,
        );
        await scopedLocal.saveSelectedAgent(
          'agent_a',
          serverId: 'srv_test',
          scopeId: projectA.path,
        );
        await scopedLocal.saveSelectedVariantMap(
          jsonEncode(<String, String>{'prov_a/mod_a': 'high'}),
          serverId: 'srv_test',
          scopeId: projectA.path,
        );
        await scopedLocal.saveSelectedProvider(
          'prov_b',
          serverId: 'srv_test',
          scopeId: projectB.path,
        );
        await scopedLocal.saveSelectedModel(
          'mod_b',
          serverId: 'srv_test',
          scopeId: projectB.path,
        );
        await scopedLocal.saveSelectedAgent(
          'agent_b',
          serverId: 'srv_test',
          scopeId: projectB.path,
        );
        await scopedLocal.saveSelectedVariantMap(
          jsonEncode(<String, String>{'prov_b/mod_b': 'careful'}),
          serverId: 'srv_test',
          scopeId: projectB.path,
        );

        ProvidersResponse responseFor(String? directory) {
          final suffix = directory == projectB.path ? 'b' : 'a';
          final providerId = 'prov_$suffix';
          final modelId = 'mod_$suffix';
          final variantId = suffix == 'a' ? 'high' : 'careful';
          return ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: providerId,
                name: 'Provider $suffix',
                env: const <String>[],
                models: <String, Model>{
                  modelId: testModel(
                    modelId,
                    variants: <String, ModelVariant>{
                      variantId: ModelVariant(id: variantId, name: variantId),
                    },
                  ),
                },
              ),
            ],
            defaultModels: <String, String>{providerId: modelId},
            connected: <String>[providerId],
          );
        }

        Completer<void>? providerGateA;
        Completer<void>? providerGateB;
        Completer<void>? providerStartedA;
        Completer<void>? providerStartedB;
        final scopedAppRepository = FakeAppRepository()
          ..getProvidersHandler = (directory) async {
            if (directory == projectA.path) {
              final started = providerStartedA;
              if (started != null && !started.isCompleted) {
                started.complete();
              }
              await providerGateA?.future;
            } else if (directory == projectB.path) {
              final started = providerStartedB;
              if (started != null && !started.isCompleted) {
                started.complete();
              }
              await providerGateB?.future;
            }
            return Right(responseFor(directory));
          }
          ..getAgentsHandler = (directory) async => Right(<Agent>[
            Agent(
              name: directory == projectB.path ? 'agent_b' : 'agent_a',
              mode: 'primary',
              hidden: false,
              native: false,
            ),
          ]);
        final scopedProjectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(
            currentProject: projectA,
            projects: <Project>[projectA, projectB],
          ),
          localDataSource: scopedLocal,
        );
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              directory: projectA.path,
            ),
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              directory: projectB.path,
            ),
          ],
        );
        final warmProvider = buildChatProvider(
          chatRepository: scopedRepository,
          appRepository: scopedAppRepository,
          localDataSource: scopedLocal,
          defaultSettingsProvider: defaultSettingsProvider,
          projectProvider: scopedProjectProvider,
        );
        addTearDown(warmProvider.dispose);

        await scopedProjectProvider.initializeProject();
        await warmProvider.initializeProviders();
        await warmProvider.loadSessions();
        expect(warmProvider.selectedProviderId, 'prov_a');
        expect(warmProvider.selectedModelId, 'mod_a');
        expect(warmProvider.selectedAgentName, 'agent_a');
        expect(warmProvider.selectedVariantId, 'high');

        await scopedProjectProvider.switchProject(projectB.id);
        await warmProvider.onProjectScopeChanged(waitForRevalidation: false);
        await warmProvider.initializeProviders();
        expect(warmProvider.selectedProviderId, 'prov_b');
        expect(warmProvider.selectedModelId, 'mod_b');
        expect(warmProvider.selectedAgentName, 'agent_b');
        expect(warmProvider.selectedVariantId, 'careful');
        await Future<void>.delayed(Duration.zero);
        expect(
          scopedLocal
              .scopedStrings['provider_catalog_cache::srv_test::/repo/a'],
          isNotNull,
        );
        expect(
          scopedLocal
              .scopedStrings['provider_catalog_cache::srv_test::/repo/b'],
          isNotNull,
        );

        await scopedProjectProvider.switchProject(projectA.id);
        await warmProvider.onProjectScopeChanged(waitForRevalidation: false);
        await warmProvider.initializeProviders();

        providerGateA = Completer<void>();
        providerStartedA = Completer<void>();
        final staleRefreshA = warmProvider.initializeProviders();
        await providerStartedA.future;

        providerGateB = Completer<void>();
        providerStartedB = Completer<void>();
        await scopedProjectProvider.switchProject(projectB.id);
        await warmProvider.onProjectScopeChanged(waitForRevalidation: false);
        await providerStartedB.future;

        expect(warmProvider.selectedProviderId, 'prov_b');
        expect(warmProvider.selectedModelId, 'mod_b');
        expect(warmProvider.selectedAgentName, 'agent_b');
        expect(warmProvider.selectedVariantId, 'careful');
        expect(
          warmProvider.selectableAgents.map((agent) => agent.name),
          <String>['agent_b'],
        );

        providerGateA.complete();
        await staleRefreshA;
        expect(warmProvider.selectedProviderId, 'prov_b');
        expect(warmProvider.selectedAgentName, 'agent_b');

        providerGateB.complete();
        await warmProvider.initializeProviders();
        expect(warmProvider.selectedProviderId, 'prov_b');
        expect(warmProvider.selectedAgentName, 'agent_b');
      },
    );

    test(
      'same-server project switch keeps cached providers visible during refresh',
      () async {
        final scopedLocal = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProjectProvider = ProjectProvider(
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
        );
        final scopedProvider = ChatProvider(
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
          projectProvider: scopedProjectProvider,
          localDataSource: scopedLocal,
        );
        addTearDown(scopedProvider.dispose);

        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'prov_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'mod_a': testModel('mod_a')},
              ),
            ],
            defaultModels: const <String, String>{'prov_a': 'mod_a'},
            connected: const <String>['prov_a'],
          ),
        );

        await scopedProjectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        expect(scopedProvider.providers, isNotEmpty);

        await scopedProjectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await scopedProvider.initializeProviders();
        await scopedProjectProvider.switchProject('proj_a');
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await scopedProvider.initializeProviders();

        appRepository.providersResult = const Left(
          NetworkFailure('refresh failed'),
        );

        await scopedProjectProvider.switchProject('proj_b');
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(scopedProvider.providers, isNotEmpty);
        expect(scopedProvider.providers.single.id, 'prov_a');
        expect(
          scopedProvider.providersRefreshState,
          ChatProvidersRefreshState.ready,
        );

        await scopedProvider.initializeProviders();
      },
    );

    test(
      'remote selection response from the previous project is ignored',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_b',
          name: 'Project B',
          path: '/repo/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        localDataSource = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final scopedProjectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(
            currentProject: projectA,
            projects: <Project>[projectA, projectB],
          ),
          localDataSource: localDataSource,
        );
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{'model_a': testModel('model_a')},
              ),
              Provider(
                id: 'provider_b',
                name: 'Provider B',
                env: const <String>[],
                models: <String, Model>{'model_b': testModel('model_b')},
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a', 'provider_b'],
          ),
        );
        chatRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_a',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              directory: projectA.path,
            ),
            ChatSession(
              id: 'ses_b',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              directory: projectB.path,
            ),
          ],
        );
        final dioClient = _ScopedGatedConfigDioClient(
          configByDirectory: <String, Map<String, dynamic>>{
            projectA.path: <String, dynamic>{'model': 'provider_a/model_a'},
            projectB.path: <String, dynamic>{'model': 'provider_b/model_b'},
          },
        );
        final scopedProvider = buildProvider(
          dioClient: dioClient,
          projectProvider: scopedProjectProvider,
        );
        addTearDown(scopedProvider.dispose);

        await scopedProjectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        await scopedProvider.loadSessions();
        await scopedProvider.selectSession(
          scopedProvider.sessions.firstWhere(
            (session) => session.id == 'ses_a',
          ),
        );

        dioClient
          ..gatedDirectory = projectA.path
          ..gatedRequestStarted = Completer<void>()
          ..gatedRequestRelease = Completer<void>();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_a',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await dioClient.gatedRequestStarted!.future;

        await scopedProjectProvider.switchProject(projectB.id);
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await scopedProvider.initializeProviders();
        expect(scopedProvider.selectedProviderId, 'provider_b');
        expect(scopedProvider.selectedModelId, 'model_b');

        dioClient.gatedRequestRelease!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(scopedProvider.selectedProviderId, 'provider_b');
        expect(scopedProvider.selectedModelId, 'model_b');
      },
    );

    test(
      'selection persistence from the previous project does not patch the next project',
      () async {
        final projectA = Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        final projectB = Project(
          id: 'proj_b',
          name: 'Project B',
          path: '/repo/b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        );
        localDataSource = DelayedSelectionPersistenceLocalDataSource(
          delay: const Duration(milliseconds: 20),
        )..activeServerId = 'srv_test';
        final scopedProjectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(
            currentProject: projectA,
            projects: <Project>[projectA, projectB],
          ),
          localDataSource: localDataSource,
        );
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_a',
                name: 'Provider A',
                env: const <String>[],
                models: <String, Model>{
                  'model_a': testModel('model_a'),
                  'model_b': testModel('model_b'),
                },
              ),
            ],
            defaultModels: const <String, String>{'provider_a': 'model_a'},
            connected: const <String>['provider_a'],
          ),
        );
        final dioClient = RecordingDioClient(
          configResponse: <String, dynamic>{'model': 'provider_a/model_a'},
        );
        final scopedProvider = buildProvider(
          dioClient: dioClient,
          projectProvider: scopedProjectProvider,
        );
        addTearDown(scopedProvider.dispose);

        await scopedProjectProvider.initializeProject();
        await scopedProvider.initializeProviders();
        dioClient.patchQueries.clear();

        await scopedProvider.setSelectedModelByProvider(
          providerId: 'provider_a',
          modelId: 'model_b',
        );
        await scopedProjectProvider.switchProject(projectB.id);
        await scopedProvider.onProjectScopeChanged(waitForRevalidation: false);
        await scopedProvider.initializeProviders();
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(
          dioClient.patchQueries.where(
            (query) => query?['directory'] == projectB.path,
          ),
          isEmpty,
        );
      },
    );

    test(
      'stale catalog failure preserves newer persisted composer selection',
      () async {
        appRepository.agentsResult = const Right(<Agent>[
          Agent(
            name: 'agent_old',
            mode: 'primary',
            hidden: false,
            native: false,
          ),
        ]);
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_old',
                name: 'Old Provider',
                env: const <String>[],
                models: <String, Model>{'model_old': testModel('model_old')},
              ),
            ],
            defaultModels: const <String, String>{'provider_old': 'model_old'},
            connected: const <String>['provider_old'],
          ),
        );
        await provider.initializeProviders();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        const scopeId = 'default';
        await localDataSource.saveSelectedProvider(
          'provider_new',
          serverId: 'srv_test',
          scopeId: scopeId,
        );
        await localDataSource.saveSelectedModel(
          'model_new',
          serverId: 'srv_test',
          scopeId: scopeId,
        );
        await localDataSource.saveSelectedVariantMap(
          jsonEncode(<String, String>{'provider_new/model_new': 'high'}),
          serverId: 'srv_test',
          scopeId: scopeId,
        );
        appRepository.providersResult = const Left(NetworkFailure('offline'));
        appRepository.agentsResult = const Right(<Agent>[
          Agent(
            name: 'agent_new',
            mode: 'primary',
            hidden: false,
            native: false,
          ),
        ]);

        provider = buildProvider();
        addTearDown(provider.dispose);
        await provider.initializeProviders();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.selectedProviderId, 'provider_new');
        expect(provider.selectedModelId, 'model_new');
        expect(provider.selectedVariantId, 'high');
        expect(
          await localDataSource.getSelectedProvider(
            serverId: 'srv_test',
            scopeId: scopeId,
          ),
          'provider_new',
        );
        expect(
          await localDataSource.getSelectedModel(
            serverId: 'srv_test',
            scopeId: scopeId,
          ),
          'model_new',
        );
        final refreshedCache =
            jsonDecode(
                  (await localDataSource.getProviderCatalogCacheJson(
                    serverId: 'srv_test',
                    scopeId: scopeId,
                  ))!,
                )
                as Map<String, dynamic>;
        expect(
          (refreshedCache['agents'] as List<dynamic>).whereType<Map>().map(
            (agent) => agent['name'],
          ),
          contains('agent_new'),
        );
      },
    );

    test(
      'provider success with agent failure preserves persisted agent',
      () async {
        await localDataSource.saveSelectedAgent(
          'agent_saved',
          serverId: 'srv_test',
          scopeId: 'default',
        );
        appRepository.providersResult = Right(
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
        appRepository.agentsResult = const Left(NetworkFailure('offline'));

        provider = buildProvider();
        addTearDown(provider.dispose);
        await provider.initializeProviders();

        expect(provider.selectedAgentName, 'agent_saved');
      },
    );

    test('currentThreadPermissionRequests returns identical cached list on '
        'repeated access without mutations', () async {
      chatRepository.pendingPermissions = const <ChatPermissionRequest>[
        ChatPermissionRequest(
          id: 'perm_cache_1',
          sessionId: 'ses_1',
          permission: 'edit',
          patterns: <String>['lib/**'],
          always: <String>[],
          metadata: <String, dynamic>{},
        ),
      ];
      appRepository.providersResult = Right(
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

      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      final first = provider.currentThreadPermissionRequests;
      final second = provider.currentThreadPermissionRequests;
      expect(identical(first, second), isTrue);
    });

    test(
      'currentThreadPermissionRequests cache invalidates on permission event',
      () async {
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_inv_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        appRepository.providersResult = Right(
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

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final before = provider.currentThreadPermissionRequests;
        expect(before.map((item) => item.id), <String>['perm_inv_1']);

        // Respond to the permission request (removes it from pending map).
        await provider.respondPermissionRequest(
          sessionId: 'ses_1',
          requestId: 'perm_inv_1',
          reply: 'once',
        );

        final after = provider.currentThreadPermissionRequests;
        expect(identical(before, after), isFalse);
        expect(after, isEmpty);
      },
    );

    test(
      'currentThreadPermissionRequests cache invalidates on session switch',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(500),
            title: 'Session 2',
          ),
        );
        chatRepository.pendingPermissions = const <ChatPermissionRequest>[
          ChatPermissionRequest(
            id: 'perm_sw_1',
            sessionId: 'ses_1',
            permission: 'edit',
            patterns: <String>['lib/**'],
            always: <String>[],
            metadata: <String, dynamic>{},
          ),
        ];
        appRepository.providersResult = Right(
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

        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_1').first,
        );

        final beforeSwitch = provider.currentThreadPermissionRequests;
        expect(beforeSwitch.map((item) => item.id), <String>['perm_sw_1']);

        // Switch to a session that has no pending permissions.
        await provider.selectSession(
          provider.sessions.where((item) => item.id == 'ses_2').first,
        );

        final afterSwitch = provider.currentThreadPermissionRequests;
        expect(identical(beforeSwitch, afterSwitch), isFalse);
        expect(afterSwitch, isEmpty);
      },
    );
  });
}

class _RecordingEventFeedbackDispatcher extends EventFeedbackDispatcher {
  _RecordingEventFeedbackDispatcher({
    required SettingsProvider settingsProvider,
  }) : super(
         settingsProvider: settingsProvider,
         notificationService: NotificationService(assumeInitialized: true),
         soundService: SoundService(),
       );

  final List<String> handledTypes = <String>[];
  final List<String> dismissedSessionIds = <String>[];
  String? lastCurrentSessionId;

  void clear() {
    handledTypes.clear();
    dismissedSessionIds.clear();
    lastCurrentSessionId = null;
  }

  @override
  Future<void> handle(
    ChatEvent event, {
    String? sessionTitleHint,
    bool isRootSession = true,
    bool isAppInForeground = true,
    String? currentSessionId,
  }) async {
    handledTypes.add(event.type);
    lastCurrentSessionId = currentSessionId;
  }

  @override
  Future<void> dismissForSession(String sessionId) async {
    dismissedSessionIds.add(sessionId);
  }
}
