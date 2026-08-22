@Tags(<String>['slow'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/data/models/chat_session_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/provider.dart';
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
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

/// Generates an ascending user/assistant thread with stable ids
/// (`msg_user_<i>` / `msg_assistant_<i>` by index parity).
List<ChatMessage> _generateThreadMessages(String sessionId, int count) {
  return List<ChatMessage>.generate(count, (index) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(1000 + index);
    if (index.isEven) {
      return UserMessage(
        id: 'msg_user_$index',
        sessionId: sessionId,
        time: timestamp,
        parts: <MessagePart>[
          TextPart(
            id: 'part_user_$index',
            messageId: 'msg_user_$index',
            sessionId: sessionId,
            text: 'u$index',
          ),
        ],
      );
    }
    return AssistantMessage(
      id: 'msg_assistant_$index',
      sessionId: sessionId,
      time: timestamp,
      completedTime: timestamp,
      parts: <MessagePart>[
        TextPart(
          id: 'part_assistant_$index',
          messageId: 'msg_assistant_$index',
          sessionId: sessionId,
          text: 'a$index',
        ),
      ],
    );
  });
}

void main() {
  group('ChatProvider - messaging', () {
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
      Future<void> Function(bool isForeground)?
      sessionAttentionAppForegroundPublisher,
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
        sessionAttentionAppForegroundPublisher:
            sessionAttentionAppForegroundPublisher,
      );
    }

    Future<void> waitForCondition(
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 2),
      Duration interval = const Duration(milliseconds: 5),
    }) async {
      final stopwatch = Stopwatch()..start();
      while (!condition()) {
        if (stopwatch.elapsed >= timeout) {
          fail('Timed out waiting for condition after $timeout');
        }
        await Future<void>.delayed(interval);
      }
    }

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
      provider = buildProvider();
    });

    test('optimistic user ids are recognized only by local_user prefix', () {
      expect(
        provider.debugIsOptimisticLocalUserMessageId('local_user_123_1'),
        isTrue,
      );
      expect(
        provider.debugIsOptimisticLocalUserMessageId(
          'local_user_1700000000000_2',
        ),
        isTrue,
      );
      expect(
        provider.debugIsOptimisticLocalUserMessageId('msg_server_123'),
        isFalse,
      );
      expect(provider.debugIsOptimisticLocalUserMessageId(''), isFalse);
      expect(
        provider.debugIsOptimisticLocalUserMessageId('LOCAL_USER_123'),
        isFalse,
      );
    });

    test('publishes actual app foreground transitions once', () async {
      final transitions = <bool>[];
      final scopedProvider = buildProvider(
        sessionAttentionAppForegroundPublisher: (isForeground) async {
          transitions.add(isForeground);
        },
      );

      scopedProvider.setAppInForeground(
        false,
        isVisibleForSessionAttention: false,
      );
      scopedProvider.setAppInForeground(
        false,
        isVisibleForSessionAttention: false,
      );
      scopedProvider.setAppInForeground(
        true,
        isVisibleForSessionAttention: true,
      );
      await scopedProvider.setForegroundActive(false);

      expect(transitions, <bool>[false, true]);
      scopedProvider.dispose();
    });

    test('keeps overlay hidden while the app is inactive but visible', () {
      final transitions = <bool>[];
      final scopedProvider = buildProvider(
        sessionAttentionAppForegroundPublisher: (isForeground) async {
          transitions.add(isForeground);
        },
      );

      scopedProvider.setAppInForeground(
        false,
        isVisibleForSessionAttention: true,
      );
      scopedProvider.setAppInForeground(false);
      scopedProvider.setAppInForeground(
        false,
        isVisibleForSessionAttention: false,
      );

      expect(transitions, <bool>[false]);
      scopedProvider.dispose();
    });

    test('duplicate echo suppression ignores server-format local ids', () {
      final time = DateTime.fromMillisecondsSinceEpoch(2000);
      final localServerFormat = UserMessage(
        id: 'msg_local_wrong_prefix',
        sessionId: 'ses_1',
        time: time,
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_local_wrong_prefix',
            messageId: 'msg_local_wrong_prefix',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );
      final serverEcho = UserMessage(
        id: 'msg_server_echo',
        sessionId: 'ses_1',
        time: time.add(const Duration(milliseconds: 100)),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_server_echo',
            messageId: 'msg_server_echo',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );

      expect(
        provider.debugShouldSkipLocalUserAppendAsDuplicateEcho(
          localMessage: localServerFormat,
          mergedMessages: <ChatMessage>[serverEcho],
        ),
        isFalse,
      );
    });

    test('duplicate echo suppression accepts local_user matching content', () {
      final time = DateTime.fromMillisecondsSinceEpoch(3000);
      final localOptimistic = UserMessage(
        id: 'local_user_3000_1',
        sessionId: 'ses_1',
        time: time,
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_local_optimistic',
            messageId: 'local_user_3000_1',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );
      final serverEcho = UserMessage(
        id: 'msg_server_echo',
        sessionId: 'ses_1',
        time: time.add(const Duration(milliseconds: 100)),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_server_echo',
            messageId: 'msg_server_echo',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );

      expect(
        provider.debugShouldSkipLocalUserAppendAsDuplicateEcho(
          localMessage: localOptimistic,
          mergedMessages: <ChatMessage>[serverEcho],
        ),
        isTrue,
      );
    });

    test('duplicate echo suppression rejects very stale local_user echoes', () {
      final time = DateTime.fromMillisecondsSinceEpoch(4000);
      final localOptimistic = UserMessage(
        id: 'local_user_4000_1',
        sessionId: 'ses_1',
        time: time,
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_local_stale',
            messageId: 'local_user_4000_1',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );
      final staleServerEcho = UserMessage(
        id: 'msg_server_stale_echo',
        sessionId: 'ses_1',
        time: time.add(const Duration(minutes: 11)),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_server_stale_echo',
            messageId: 'msg_server_stale_echo',
            sessionId: 'ses_1',
            text: 'same content',
          ),
        ],
      );

      expect(
        provider.debugShouldSkipLocalUserAppendAsDuplicateEcho(
          localMessage: localOptimistic,
          mergedMessages: <ChatMessage>[staleServerEcho],
        ),
        isFalse,
      );
    });

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
      'loadSessions restores cached last-session snapshot and revalidates silently',
      () async {
        await provider.projectProvider.initializeProject();

        final snapshotSession = chatRepository.sessions.first;
        final snapshotMessage = AssistantMessage(
          id: 'msg_cached',
          sessionId: snapshotSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1010),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1011),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_cached',
              messageId: 'msg_cached',
              sessionId: 'ses_1',
              text: 'cached assistant reply',
            ),
          ],
        );
        final snapshotPayload = jsonEncode(<String, dynamic>{
          'session': ChatSessionModel.fromDomain(snapshotSession).toJson(),
          'messages': <Map<String, dynamic>>[
            ChatMessageModel.fromDomain(snapshotMessage).toJson(),
          ],
        });

        await localDataSource.saveCurrentSessionId(
          snapshotSession.id,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshot(
          snapshotPayload,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshotUpdatedAt(
          DateTime.now().millisecondsSinceEpoch,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );

        chatRepository.getMessagesFailure = const NetworkFailure(
          'offline',
          503,
        );

        await provider.loadSessions();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.currentSession?.id, snapshotSession.id);
        expect(provider.messages, hasLength(1));
        expect(
          (provider.messages.first as AssistantMessage).parts
              .whereType<TextPart>()
              .single
              .text,
          'cached assistant reply',
        );
        expect(provider.errorMessage, isNull);
        expect(chatRepository.getMessagesCallCount, greaterThan(0));
      },
    );

    test(
      'cached snapshot prunes reconciled optimistic echo but preserves pending prompt',
      () async {
        await provider.projectProvider.initializeProject();

        final snapshotSession = chatRepository.sessions.first;
        final canonicalUser = UserMessage(
          id: 'msg_user_canonical',
          sessionId: snapshotSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1010),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_canonical',
              messageId: 'msg_user_canonical',
              sessionId: 'ses_1',
              text: 'already reconciled prompt',
            ),
          ],
        );
        final reconciledOptimisticUser = UserMessage(
          id: 'local_user_reconciled',
          sessionId: snapshotSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_local_user_reconciled',
              messageId: 'local_user_reconciled',
              sessionId: 'ses_1',
              text: 'already reconciled prompt',
            ),
          ],
        );
        final pendingOptimisticUser = UserMessage(
          id: 'local_user_pending',
          sessionId: snapshotSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1020),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_local_user_pending',
              messageId: 'local_user_pending',
              sessionId: 'ses_1',
              text: 'still pending prompt',
            ),
          ],
        );
        final snapshotPayload = jsonEncode(<String, dynamic>{
          'session': ChatSessionModel.fromDomain(snapshotSession).toJson(),
          'messages': <Map<String, dynamic>>[
            ChatMessageModel.fromDomain(reconciledOptimisticUser).toJson(),
            ChatMessageModel.fromDomain(canonicalUser).toJson(),
            ChatMessageModel.fromDomain(pendingOptimisticUser).toJson(),
          ],
        });

        await localDataSource.saveCurrentSessionId(
          snapshotSession.id,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshot(
          snapshotPayload,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshotUpdatedAt(
          DateTime.now().millisecondsSinceEpoch,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        chatRepository.getMessagesFailure = const NetworkFailure(
          'offline',
          503,
        );

        await provider.loadSessions();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          provider.messages.map((message) => message.id),
          containsAll(<String>['msg_user_canonical', 'local_user_pending']),
        );
        expect(
          provider.messages.map((message) => message.id),
          isNot(contains('local_user_reconciled')),
        );
      },
    );

    test(
      'selectSession restores per-session snapshot cache before remote revalidation',
      () async {
        await provider.projectProvider.initializeProject();

        final secondSession = ChatSession(
          id: 'ses_2',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          title: 'Session 2',
        );
        chatRepository.sessions.add(secondSession);

        final cachedMessage = AssistantMessage(
          id: 'msg_cached_ses_2',
          sessionId: secondSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(2020),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2021),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_cached_ses_2',
              messageId: 'msg_cached_ses_2',
              sessionId: 'ses_2',
              text: 'cached swr message',
            ),
          ],
        );

        chatRepository.messagesBySession[secondSession.id] = <ChatMessage>[
          cachedMessage,
        ];

        await provider.loadSessions();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final firstSession = provider.sessions.firstWhere(
          (session) => session.id != secondSession.id,
        );

        await provider.selectSession(secondSession);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(provider.messages, hasLength(1));

        chatRepository.getMessagesFailure = const NetworkFailure(
          'offline',
          503,
        );

        await provider.selectSession(firstSession);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await provider.selectSession(secondSession);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.currentSession?.id, secondSession.id);
        expect(provider.state, ChatState.loaded);
        expect(provider.messages, hasLength(1));
        expect(
          (provider.messages.single as AssistantMessage).parts
              .whereType<TextPart>()
              .single
              .text,
          'cached swr message',
        );
      },
    );

    test(
      'createNewSession selects created session in directory-scoped context',
      () async {
        final scopedRepository = FakeChatRepository(
          sessions: <ChatSession>[
            ChatSession(
              id: 'ses_scoped_1',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Scoped Session',
              directory: '/tmp',
            ),
          ],
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
            projectRepository: FakeProjectRepository(),
            localDataSource: localDataSource,
          ),
          localDataSource: localDataSource,
        );

        await scopedProvider.projectProvider.initializeProject();
        await scopedProvider.loadSessions();
        expect(scopedProvider.currentSession?.id, 'ses_scoped_1');

        await scopedProvider.createNewSession();

        expect(scopedProvider.state, ChatState.loaded);
        expect(scopedProvider.currentSession, isNotNull);
        expect(scopedProvider.currentSession?.id, isNot('ses_scoped_1'));
        expect(
          scopedProvider.sessions.any(
            (session) => session.id == scopedProvider.currentSession?.id,
          ),
          isTrue,
        );
        expect(scopedProvider.messages, isEmpty);

        final storedCurrent = await localDataSource.getCurrentSessionId(
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        expect(storedCurrent, scopedProvider.currentSession?.id);
      },
    );

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

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(assistantPartial);
          await Future<void>.delayed(const Duration(milliseconds: 1));
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello provider');
        await waitForCondition(
          () =>
              provider.state == ChatState.loaded &&
              provider.messages.length == 2 &&
              provider.messages.last is AssistantMessage &&
              (provider.messages.last as AssistantMessage).completedTime !=
                  null,
        );

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
      'send does not fall back to hard-coded model when none is selectable',
      () async {
        appRepository.providersResult = Right(
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'openai',
                name: 'OpenAI',
                env: const <String>[],
                models: <String, Model>{'gpt-4o': testModel('gpt-4o')},
              ),
            ],
            defaultModels: const <String, String>{'openai': 'gpt-4o'},
            connected: const <String>[],
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final started = await provider.sendMessage('no selectable model');

        expect(started, isFalse);
        expect(chatRepository.lastSendInput, isNull);
        final rejectedDraft = provider.consumeRejectedDraft(sessionId: 'ses_1');
        expect(rejectedDraft, isNotNull);
        expect(rejectedDraft?.text, 'no selectable model');
      },
    );

    test('send failure in foreground queues draft restore for retry', () async {
      final sendStream = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await sendStream.close();
      });
      chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('retry this text');
      sendStream.add(const Left(NetworkFailure('temporary failure')));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final rejectedDraft = provider.consumeRejectedDraft(sessionId: 'ses_1');
      expect(rejectedDraft, isNotNull);
      expect(rejectedDraft?.text, 'retry this text');
      expect(rejectedDraft?.attachments, isEmpty);
      expect(rejectedDraft?.shellMode, isFalse);
    });

    test(
      'send network failure is surfaced as inline connection error',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await sendStream.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('network fail now');
        sendStream.add(const Left(NetworkFailure('Network connection failed')));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.state, ChatState.loaded);
        expect(provider.errorMessage, isNull);
        final inlineErrorMessage = provider.messages.last as AssistantMessage;
        expect(inlineErrorMessage.error, isNotNull);
        expect(inlineErrorMessage.error!.name, 'Connection failed');
        expect(
          inlineErrorMessage.error!.message,
          'Unable to reach the server. Check connection and server status.',
        );
      },
    );

    test('send 409 conflict keeps the session in busy state', () async {
      final sendStream = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await sendStream.close();
      });
      chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('conflict now');
      sendStream.add(
        const Left(
          ServerFailure('Session is busy processing another request.', 409),
        ),
      );
      await sendStream.close();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(provider.state, ChatState.loaded);
      expect(provider.errorMessage, isNull);
      expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      expect(
        provider.consumePendingUiNotice()?.message,
        'Session is busy processing another request.',
      );
      expect(
        provider.messages
            .whereType<AssistantMessage>()
            .where((message) => message.error != null)
            .toList(),
        isEmpty,
      );
    });

    test('send failure in background preserves draft for retry', () async {
      final sendStream = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await sendStream.close();
      });
      chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      provider.setAppInForeground(false);

      await provider.sendMessage('do not resurrect this text');
      sendStream.add(
        const Left(NetworkFailure('stream dropped in background')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Step 4 invariant: drafts are unconditionally preserved across
      // background transitions to prevent text loss.
      final draft = provider.consumeRejectedDraft(sessionId: 'ses_1');
      expect(draft, isNotNull);
      expect(draft!.text, 'do not resurrect this text');
    });

    test('send failure preserves attachment-only draft for retry', () async {
      final sendStream = StreamController<Either<Failure, ChatMessage>>();
      addTearDown(() async {
        await sendStream.close();
      });
      chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      const attachment = FileInputPart(
        mime: 'image/png',
        url: 'data:image/png;base64,AA==',
        filename: 'image.png',
      );
      await provider.sendMessage(
        '',
        attachments: const <FileInputPart>[attachment],
      );
      sendStream.add(const Left(NetworkFailure('temporary failure')));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final rejectedDraft = provider.consumeRejectedDraft(sessionId: 'ses_1');
      expect(rejectedDraft, isNotNull);
      expect(rejectedDraft?.text, '');
      expect(rejectedDraft?.attachments, const <FileInputPart>[attachment]);
      expect(rejectedDraft?.shellMode, isFalse);
    });

    test(
      'send failure outside active chat route preserves draft for retry',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await sendStream.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        provider.setChatRouteActive(false);

        await provider.sendMessage('draft from inactive route');
        sendStream.add(const Left(NetworkFailure('temporary failure')));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // Step 4 invariant: drafts are unconditionally preserved even when
        // the chat route is inactive, to prevent text loss.
        final draft = provider.consumeRejectedDraft(sessionId: 'ses_1');
        expect(draft, isNotNull);
        expect(draft!.text, 'draft from inactive route');
      },
    );

    test(
      'submitMessage lazily creates a new session from draft state',
      () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final initialSessionCount = chatRepository.sessions.length;
        final previousSessionId = provider.currentSession?.id;
        expect(previousSessionId, isNotNull);

        await provider.beginNewChatDraft();
        expect(provider.currentSession, isNull);

        await provider.submitMessage('start from lazy draft');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.currentSession, isNotNull);
        expect(provider.currentSession?.id, isNot(previousSessionId));
        expect(chatRepository.sessions.length, initialSessionCount + 1);
        expect(chatRepository.lastSendSessionId, provider.currentSession?.id);

        final textParts =
            chatRepository.lastSendInput?.parts
                .whereType<TextInputPart>()
                .toList(growable: false) ??
            const <TextInputPart>[];
        expect(textParts, hasLength(1));
        expect(textParts.first.text, 'start from lazy draft');
      },
    );

    test('sendMessage lazily creates a new session from draft state', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();

      final previousSessionId = provider.currentSession?.id;
      expect(previousSessionId, isNotNull);

      await provider.beginNewChatDraft();
      expect(provider.currentSession, isNull);

      final started = await provider.sendMessage('direct lazy draft send');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(started, isTrue);
      expect(provider.currentSession, isNotNull);
      expect(provider.currentSession?.id, isNot(previousSessionId));
      expect(chatRepository.lastSendSessionId, provider.currentSession?.id);
    });

    test(
      'submitMessage lazily creates a new session for slash command mode',
      () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final initialSessionCount = chatRepository.sessions.length;
        final previousSessionId = provider.currentSession?.id;
        expect(previousSessionId, isNotNull);

        await provider.beginNewChatDraft();
        expect(provider.currentSession, isNull);

        await provider.submitMessage(
          '/release-monitor v1.2.3',
          commandMode: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.currentSession, isNotNull);
        expect(provider.currentSession?.id, isNot(previousSessionId));
        expect(chatRepository.sessions.length, initialSessionCount + 1);
        expect(chatRepository.lastSendSessionId, provider.currentSession?.id);
        expect(chatRepository.lastSendInput?.mode, 'command');
        expect(
          chatRepository.lastSendInput?.parts.single,
          const TextInputPart(text: '/release-monitor v1.2.3'),
        );
      },
    );

    test(
      'loadSessions keeps New Chat draft active when cached snapshot exists',
      () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final existingSession = provider.sessions.first;
        final snapshotMessage = AssistantMessage(
          id: 'msg_snapshot_restore_guard',
          sessionId: existingSession.id,
          time: DateTime.fromMillisecondsSinceEpoch(1010),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1020),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_snapshot_restore_guard',
              messageId: 'msg_snapshot_restore_guard',
              sessionId: 'ses_1',
              text: 'cached snapshot message',
            ),
          ],
        );

        await localDataSource.saveLastSessionSnapshot(
          jsonEncode(<String, dynamic>{
            'session': ChatSessionModel.fromDomain(existingSession).toJson(),
            'messages': <Map<String, dynamic>>[
              ChatMessageModel.fromDomain(snapshotMessage).toJson(),
            ],
          }),
          serverId: 'srv_test',
          scopeId: '/tmp',
        );
        await localDataSource.saveLastSessionSnapshotUpdatedAt(
          DateTime.now().millisecondsSinceEpoch,
          serverId: 'srv_test',
          scopeId: '/tmp',
        );

        await provider.beginNewChatDraft();
        expect(provider.isDraftingNewChat, isTrue);
        expect(provider.currentSession, isNull);

        await provider.loadSessions();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.isDraftingNewChat, isTrue);
        expect(provider.currentSession, isNull);
        expect(provider.messages, isEmpty);
      },
    );

    test(
      'switching sessions ignores in-flight stream updates from previous session',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        chatRepository.sendMessageHandler = (_, _, _, _) {
          return streamController.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final session1 = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        final session2 = provider.sessions
            .where((item) => item.id == 'ses_2')
            .first;

        await provider.selectSession(session1);
        await provider.sendMessage('first session prompt');
        expect(provider.currentSession?.id, 'ses_1');

        await provider.selectSession(session2);
        expect(provider.currentSession?.id, 'ses_2');
        expect(provider.messages, isEmpty);

        streamController.add(
          Right(
            AssistantMessage(
              id: 'msg_assistant_old_session',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'prt_assistant_old_session',
                  messageId: 'msg_assistant_old_session',
                  sessionId: 'ses_1',
                  text: 'stale update',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.currentSession?.id, 'ses_2');
        expect(provider.messages, isEmpty);

        await streamController.close();
      },
    );

    test('switching sessions cancels the previous in-flight stream', () async {
      chatRepository.sessions.add(
        ChatSession(
          id: 'ses_2',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1500),
          title: 'Session 2',
        ),
      );

      final streamController = StreamController<Either<Failure, ChatMessage>>();
      var streamCancelled = false;
      streamController.onCancel = () {
        streamCancelled = true;
      };
      addTearDown(() async {
        await streamController.close();
      });

      chatRepository.sendMessageHandler = (_, _, _, _) {
        return streamController.stream;
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();

      final session1 = provider.sessions
          .where((item) => item.id == 'ses_1')
          .first;
      final session2 = provider.sessions
          .where((item) => item.id == 'ses_2')
          .first;

      await provider.selectSession(session1);
      await provider.sendMessage('keep stream alive');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await provider.selectSession(session2);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.currentSession?.id, 'ses_2');
      expect(streamCancelled, isTrue);
    });

    test(
      'switching back to a session reloads messages from server after canceling the stale stream',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        final streamController =
            StreamController<Either<Failure, ChatMessage>>();
        var streamCancelled = false;
        streamController.onCancel = () {
          streamCancelled = true;
        };
        addTearDown(() async {
          await streamController.close();
        });

        chatRepository.sendMessageHandler = (_, _, _, _) {
          return streamController.stream;
        };

        // Pre-populate server-side messages for ses_1 so loadMessages
        // returns them when the user switches back.
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_server_loaded',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_server_loaded',
                messageId: 'msg_server_loaded',
                sessionId: 'ses_1',
                text: 'loaded from server',
              ),
            ],
          ),
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final session1 = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        final session2 = provider.sessions
            .where((item) => item.id == 'ses_2')
            .first;

        await provider.selectSession(session1);
        await provider.sendMessage('keep stream updates alive');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await provider.selectSession(session2);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Stream callbacks stay irrelevant after the session switch.
        streamController.add(
          Right(
            AssistantMessage(
              id: 'msg_stream_stale',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(3000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_stream_stale',
                  messageId: 'msg_stream_stale',
                  sessionId: 'ses_1',
                  text: 'should be ignored',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Switch back to session1 — messages reload from server.
        await provider.selectSession(session1);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.currentSession?.id, 'ses_1');
        // The previous stream subscription is canceled on switch.
        expect(streamCancelled, isTrue);
        // Messages come from server, not from the stale stream.
        final assistant = provider.messages
            .whereType<AssistantMessage>()
            .where((message) => message.id == 'msg_server_loaded')
            .first;
        expect((assistant.parts.single as TextPart).text, 'loaded from server');
        expect(assistant.isCompleted, isTrue);
      },
    );

    test(
      'sending in another session cancels the previous session stream',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        final firstStream = StreamController<Either<Failure, ChatMessage>>();
        final secondStream = StreamController<Either<Failure, ChatMessage>>();
        var firstStreamCancelled = false;
        firstStream.onCancel = () {
          firstStreamCancelled = true;
        };
        addTearDown(() async {
          await firstStream.close();
          await secondStream.close();
        });

        var sendCalls = 0;
        chatRepository.sendMessageHandler = (_, _, _, _) {
          sendCalls += 1;
          if (sendCalls == 1) {
            return firstStream.stream;
          }
          return secondStream.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final session1 = provider.sessions
            .where((item) => item.id == 'ses_1')
            .first;
        final session2 = provider.sessions
            .where((item) => item.id == 'ses_2')
            .first;

        await provider.selectSession(session1);
        await provider.sendMessage('first session prompt');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        await provider.selectSession(session2);
        await provider.sendMessage('second session prompt');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(firstStreamCancelled, isTrue);
      },
    );

    test(
      'loadOlderMessages requests anchored sentinel limits and updates hasMore',
      () async {
        const sessionId = 'ses_1';
        final messages = List<ChatMessage>.generate(450, (index) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(1000 + index);
          if (index.isEven) {
            return UserMessage(
              id: 'msg_user_$index',
              sessionId: sessionId,
              time: timestamp,
              parts: <MessagePart>[
                TextPart(
                  id: 'part_user_$index',
                  messageId: 'msg_user_$index',
                  sessionId: sessionId,
                  text: 'u$index',
                ),
              ],
            );
          }
          return AssistantMessage(
            id: 'msg_assistant_$index',
            sessionId: sessionId,
            time: timestamp,
            completedTime: timestamp,
            parts: <MessagePart>[
              TextPart(
                id: 'part_assistant_$index',
                messageId: 'msg_assistant_$index',
                sessionId: sessionId,
                text: 'a$index',
              ),
            ],
          );
        });
        chatRepository.messagesBySession[sessionId] = messages;

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Cold open probes window+1 and keeps only the newest window.
        expect(provider.hasMoreOldMessages, isTrue);
        expect(provider.messages.length, 50);
        expect(provider.messages.first.id, 'msg_user_400');

        // Sentinel request: resident(50) + chunk(100) + 1.
        await provider.loadOlderMessages(chunkSize: 100);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.lastGetMessagesLimit, 151);
        expect(provider.messages.length, 151);
        expect(provider.messages.first.id, 'msg_assistant_299');
        // Exact-fit sentinel response cannot rule out deeper history yet.
        expect(provider.hasMoreOldMessages, isTrue);
        expect(provider.isLoadingOlderMessages, isFalse);

        // A larger second page exhausts the session: the sentinel response
        // comes back short, proving no older history remains.
        await provider.loadOlderMessages(chunkSize: 300);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.lastGetMessagesLimit, 452);
        expect(provider.messages.length, 450);
        expect(provider.messages.first.id, 'msg_user_0');
        expect(provider.hasMoreOldMessages, isFalse);
        expect(provider.isLoadingOlderMessages, isFalse);
      },
    );

    test(
      'cold open of an exact-window session reports no older history without extra roundtrips',
      () async {
        const sessionId = 'ses_1';
        chatRepository.messagesBySession[sessionId] =
            _generateThreadMessages(sessionId, 50);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // The sentinel probe came back short: exactly 50 exist server-side.
        expect(provider.messages.length, 50);
        expect(provider.messages.last.id, 'msg_assistant_49');
        expect(provider.hasMoreOldMessages, isFalse);

        // A direct older-page request is a safe no-op: the anchor sits at
        // position zero of the response and the sentinel stays short.
        await provider.loadOlderMessages();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.messages.length, 50);
        expect(provider.hasMoreOldMessages, isFalse);
      },
    );

    test(
      'cold open of a short session loads everything and reports no older history',
      () async {
        const sessionId = 'ses_1';
        chatRepository.messagesBySession[sessionId] =
            _generateThreadMessages(sessionId, 18);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.messages.length, 18);
        expect(provider.hasMoreOldMessages, isFalse);
      },
    );

    test(
      're-entering a deeply paged session restores a bounded window',
      () async {
        const sessionId = 'ses_1';
        chatRepository.messagesBySession[sessionId] =
            _generateThreadMessages(sessionId, 450);

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Page deep enough that the resident list far exceeds any window.
        await provider.loadOlderMessages(chunkSize: 400);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(provider.messages.length, 450);
        expect(provider.hasMoreOldMessages, isFalse);

        // Leaving (draft reset) and re-entering hydrates from the bounded
        // cache; the deferred SWR reconciliation may top up the delta tail
        // (200), but the deep 450-message resident list must not return.
        await provider.beginNewChatDraft();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(provider.messages, isEmpty);

        await provider.selectSession(session);
        await Future<void>.delayed(
          const Duration(milliseconds: 60),
        );
        expect(provider.messages.length, lessThan(450));
        expect(provider.messages.length, greaterThanOrEqualTo(50));
        expect(provider.messages.last.id, 'msg_assistant_449');
        final firstIndex = 450 - provider.messages.length;
        expect(
          provider.messages.first.id,
          firstIndex.isEven
              ? 'msg_user_$firstIndex'
              : 'msg_assistant_$firstIndex',
        );
        expect(provider.hasMoreOldMessages, isTrue);
      },
    );

    test(
      'loadMessages preserveVisibleState fetches tail first and falls back to full fetch when needed',
      () async {
        const sessionId = 'ses_1';
        final baseMessages = <ChatMessage>[
          AssistantMessage(
            id: 'base_1',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1001),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_base_1',
                messageId: 'base_1',
                sessionId: 'ses_1',
                text: 'base 1',
              ),
            ],
          ),
          AssistantMessage(
            id: 'base_2',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(2001),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_base_2',
                messageId: 'base_2',
                sessionId: 'ses_1',
                text: 'base 2',
              ),
            ],
          ),
        ];
        chatRepository.messagesBySession[sessionId] = List<ChatMessage>.from(
          baseMessages,
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final latestTail = <ChatMessage>[
          AssistantMessage(
            id: 'fresh_1',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(3001),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_fresh_1',
                messageId: 'fresh_1',
                sessionId: 'ses_1',
                text: 'fresh 1',
              ),
            ],
          ),
        ];
        final fullHistory = <ChatMessage>[...baseMessages, ...latestTail];
        var requestNumber = 0;
        chatRepository.getMessagesRequestedLimits.clear();
        chatRepository.getMessagesHandler =
            (String _, String __, {String? directory, int? limit}) async {
              requestNumber += 1;
              if (requestNumber == 1) {
                return Right(latestTail);
              }
              return Right(fullHistory);
            };

        await provider.loadMessages(sessionId, preserveVisibleState: true);
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(chatRepository.getMessagesRequestedLimits, hasLength(2));
        expect(chatRepository.getMessagesRequestedLimits.first, isNotNull);
        expect(chatRepository.getMessagesRequestedLimits.last, isNull);
        expect(
          provider.messages.map((message) => message.id).toList(),
          <String>['base_1', 'base_2', 'fresh_1'],
        );
      },
    );

    test(
      'loadMessages gap recovery promotes latest server tail before full backfill',
      () async {
        const sessionId = 'ses_1';
        final staleSnapshot = List<ChatMessage>.generate(150, (index) {
          final messageId = 'cached_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1001 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'cached $index',
              ),
            ],
          );
        });
        final serverHistory = List<ChatMessage>.generate(260, (index) {
          final messageId = 'server_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(5000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(5001 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'server $index',
              ),
            ],
          );
        });
        chatRepository.messagesBySession[sessionId] = List<ChatMessage>.from(
          staleSnapshot,
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final localDataSource =
            provider.localDataSource as InMemoryAppLocalDataSource;
        final initialSnapshot = await localDataSource
            .getSessionMessagesSnapshot(
              sessionId: sessionId,
              serverId: 'srv_test',
              scopeId: '/tmp',
            );

        final fullFetchGate = Completer<void>();
        var requestNumber = 0;
        chatRepository.messagesBySession[sessionId] = List<ChatMessage>.from(
          serverHistory,
        );
        chatRepository.getMessagesRequestedLimits.clear();
        chatRepository.getMessagesHandler =
            (String _, String __, {String? directory, int? limit}) async {
              requestNumber += 1;
              if (requestNumber == 1) {
                return Right(serverHistory.sublist(serverHistory.length - 200));
              }
              await fullFetchGate.future;
              return Right(serverHistory);
            };

        unawaited(provider.loadMessages(sessionId, preserveVisibleState: true));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.getMessagesRequestedLimits, <int?>[200, null]);
        expect(provider.hasMoreOldMessages, isTrue);
        expect(provider.messages.length, 200);
        expect(provider.messages.first.id, 'server_60');
        expect(provider.messages.last.id, 'server_259');

        final duringFallbackSnapshot = await localDataSource
            .getSessionMessagesSnapshot(
              sessionId: sessionId,
              serverId: 'srv_test',
              scopeId: '/tmp',
            );
        expect(duringFallbackSnapshot, initialSnapshot);

        fullFetchGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messages.length, 260);
        expect(provider.messages.first.id, 'server_0');
        expect(provider.messages.last.id, 'server_259');

        final refreshedSnapshot = await localDataSource
            .getSessionMessagesSnapshot(
              sessionId: sessionId,
              serverId: 'srv_test',
              scopeId: '/tmp',
            );
        expect(refreshedSnapshot, isNot(initialSnapshot));
        expect(refreshedSnapshot, contains('server_259'));
      },
    );

    test(
      'refreshActiveSessionView completes deferred no-overlap fallback after lock release',
      () async {
        const sessionId = 'ses_1';
        final staleSnapshot = List<ChatMessage>.generate(250, (index) {
          final messageId = 'cached_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1001 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'cached $index',
              ),
            ],
          );
        });
        final serverHistory = List<ChatMessage>.generate(260, (index) {
          final messageId = 'server_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(10000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(10001 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'server $index',
              ),
            ],
          );
        });
        chatRepository.messagesBySession[sessionId] = List<ChatMessage>.from(
          staleSnapshot,
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final fullFetchGate = Completer<void>();
        var requestNumber = 0;
        chatRepository.messagesBySession[sessionId] = List<ChatMessage>.from(
          serverHistory,
        );
        chatRepository.getMessagesRequestedLimits.clear();
        chatRepository.getMessagesHandler =
            (String _, String __, {String? directory, int? limit}) async {
              requestNumber += 1;
              if (requestNumber == 1) {
                return Right(serverHistory.sublist(serverHistory.length - 200));
              }
              await fullFetchGate.future;
              return Right(serverHistory);
            };

        await provider.refreshActiveSessionView(
          reason: 'test-gap-recovery',
          includeStatus: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.getMessagesRequestedLimits, <int?>[200, null]);
        expect(provider.messages.length, 200);
        expect(provider.messages.first.id, 'server_60');

        fullFetchGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messages.length, 260);
        expect(provider.messages.first.id, 'server_0');
        expect(provider.messages.last.id, 'server_259');
      },
    );

    test(
      'refreshActiveSessionView keeps visible completed local tail during no-overlap delta recovery',
      () async {
        const sessionId = 'ses_1';
        final cachedHistory = List<ChatMessage>.generate(205, (index) {
          final messageId = 'cached_visible_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(1000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1500 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'cached visible $index',
              ),
            ],
          );
        });
        final visibleFinal = AssistantMessage(
          id: 'msg_visible_final_tail',
          sessionId: sessionId,
          time: DateTime.fromMillisecondsSinceEpoch(20000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(20100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_visible_final_tail',
              messageId: 'msg_visible_final_tail',
              sessionId: sessionId,
              text: 'final answer that must not disappear during gap recovery',
            ),
          ],
        );
        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          ...cachedHistory,
          visibleFinal,
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((item) => item.id == sessionId),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final serverTail = List<ChatMessage>.generate(220, (index) {
          final messageId = 'server_gap_$index';
          return AssistantMessage(
            id: messageId,
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(10000 + index),
            completedTime: DateTime.fromMillisecondsSinceEpoch(10100 + index),
            parts: <MessagePart>[
              TextPart(
                id: 'part_$messageId',
                messageId: messageId,
                sessionId: sessionId,
                text: 'server gap $index',
              ),
            ],
          );
        });
        final fullFetchGate = Completer<void>();
        var requestNumber = 0;
        chatRepository.getMessagesRequestedLimits.clear();
        chatRepository.getMessagesHandler =
            (String _, String __, {String? directory, int? limit}) async {
              requestNumber += 1;
              if (requestNumber == 1) {
                return Right(serverTail.sublist(serverTail.length - 200));
              }
              await fullFetchGate.future;
              return Right(<ChatMessage>[...serverTail, visibleFinal]);
            };

        await provider.refreshActiveSessionView(
          reason: 'test-visible-tail-gap-recovery',
          includeStatus: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(chatRepository.getMessagesRequestedLimits, <int?>[200, null]);
        expect(
          provider.messages.any((message) => message.id == visibleFinal.id),
          isTrue,
          reason:
              'The locally visible completed final answer must not disappear while the full fetch is still blocked.',
        );
        expect(
          (provider.messages
                      .whereType<AssistantMessage>()
                      .firstWhere((message) => message.id == visibleFinal.id)
                      .parts
                      .single
                  as TextPart)
              .text,
          'final answer that must not disappear during gap recovery',
        );

        fullFetchGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.messages.last.id, visibleFinal.id);
      },
    );

    test(
      'refreshActiveSessionView does not schedule scroll callback for busy passive refresh message changes',
      () async {
        const sessionId = 'ses_1';
        final toolOnlyMessage = AssistantMessage(
          id: 'msg_tool_only_before_final',
          sessionId: sessionId,
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2010),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_tool_only_before_final',
              messageId: 'msg_tool_only_before_final',
              sessionId: sessionId,
              callId: 'call_tool_only_before_final',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/tmp',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2000),
                  end: DateTime.fromMillisecondsSinceEpoch(2005),
                ),
              ),
            ),
          ],
        );
        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          toolOnlyMessage,
        ];

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        final session = provider.sessions.firstWhere(
          (item) => item.id == sessionId,
        );
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        var scrollToBottomRequests = 0;
        provider.setScrollToBottomCallback(({required reason}) {
          scrollToBottomRequests += 1;
        });
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          sessionId: SessionStatusInfo(type: SessionStatusType.busy),
        };
        await provider.loadSessionInsights(sessionId);

        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          toolOnlyMessage,
          AssistantMessage(
            id: 'msg_final_after_tools',
            sessionId: sessionId,
            time: DateTime.fromMillisecondsSinceEpoch(2100),
            completedTime: DateTime.fromMillisecondsSinceEpoch(2110),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_final_after_tools',
                messageId: 'msg_final_after_tools',
                sessionId: sessionId,
                text: 'final response after tool calls',
              ),
            ],
          ),
        ];

        await provider.refreshActiveSessionView(
          reason: 'session-idle-final-reconcile',
          includeStatus: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.messages.last.id, 'msg_final_after_tools');
        expect(scrollToBottomRequests, 0);
      },
    );

    test(
      'providers refresh exposes failed state and recovers on retry',
      () async {
        appRepository.providersResult = const Left(
          NetworkFailure('providers down'),
        );

        await provider.initializeProviders();

        expect(
          provider.providersRefreshState,
          ChatProvidersRefreshState.failed,
        );
        expect(
          provider.providersRefreshErrorMessage,
          contains('providers down'),
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

        await provider.retryProvidersRefresh();

        expect(provider.providersRefreshState, ChatProvidersRefreshState.ready);
        expect(provider.providersRefreshErrorMessage, isNull);
        expect(provider.selectedProviderId, 'provider_a');
        expect(provider.selectedModelId, 'model_a');
      },
    );

    test('sendMessage sends shell mode payload when requested', () async {
      final assistantCompleted = AssistantMessage(
        id: 'msg_shell_done',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_shell_done',
            messageId: 'msg_shell_done',
            sessionId: 'ses_1',
            text: 'shell output',
          ),
        ],
      );
      chatRepository.sendMessageHandler = (_, _, _, _) async* {
        yield Right(assistantCompleted);
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('pwd', shellMode: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.state, ChatState.loaded);
      expect(chatRepository.lastSendInput?.mode, 'shell');
      expect(
        chatRepository.lastSendInput?.parts.single,
        const TextInputPart(text: 'pwd'),
      );
      final userMessage = provider.messages.first as UserMessage;
      expect((userMessage.parts.first as TextPart).text, '!pwd');
    });

    test('sendMessage sends slash command payload when requested', () async {
      final assistantCompleted = AssistantMessage(
        id: 'msg_command_done',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(2200),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2300),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_command_done',
            messageId: 'msg_command_done',
            sessionId: 'ses_1',
            text: 'command output',
          ),
        ],
      );
      chatRepository.sendMessageHandler = (_, _, _, _) async* {
        yield Right(assistantCompleted);
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('/release-monitor v1.2.3', commandMode: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.state, ChatState.loaded);
      expect(chatRepository.lastSendInput?.mode, 'command');
      expect(
        chatRepository.lastSendInput?.parts.single,
        const TextInputPart(text: '/release-monitor v1.2.3'),
      );
      final userMessage = provider.messages.first as UserMessage;
      expect(
        (userMessage.parts.first as TextPart).text,
        '/release-monitor v1.2.3',
      );
    });

    test(
      'stale REST busy does not keep Stop visible after stream settles with revealable content',
      () async {
        final assistantCompleted = AssistantMessage(
          id: 'msg_final',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_final',
              messageId: 'msg_final',
              sessionId: 'ses_1',
              text: 'final answer',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // After stream settles, state is loaded and Stop is hidden.
        expect(provider.state, ChatState.loaded);
        expect(provider.isCurrentSessionActivelyResponding, isFalse);
        expect(provider.canAbortActiveResponse, isFalse);

        // Even if a subsequent REST refresh reports busy, a settled text-only
        // response must not re-enable Stop or active-response attention.
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };
        await provider.loadSessionInsights('ses_1', silent: true);

        expect(provider.isCurrentSessionActivelyResponding, isFalse);
        expect(provider.canAbortActiveResponse, isFalse);
      },
    );

    test(
      'stale REST busy from refreshSessionStatusSnapshot does not keep Stop visible',
      () async {
        final assistantCompleted = AssistantMessage(
          id: 'msg_final_2',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_final_2',
              messageId: 'msg_final_2',
              sessionId: 'ses_1',
              text: 'final answer',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(assistantCompleted);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.canAbortActiveResponse, isFalse);

        // Even if a subsequent REST refresh reports busy, a settled text-only
        // response must not re-enable Stop.
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };
        await provider.refreshSessionStatusSnapshot();

        expect(provider.canAbortActiveResponse, isFalse);
      },
    );

    test('tool-only busy turn keeps Stop visible', () async {
      final toolOnlyMessage = AssistantMessage(
        id: 'msg_tool_step',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2010),
        parts: <MessagePart>[
          ToolPart(
            id: 'part_tool_step',
            messageId: 'msg_tool_step',
            sessionId: 'ses_1',
            callId: 'call_tool_step',
            tool: 'bash',
            state: ToolStateRunning(
              input: const <String, dynamic>{'command': 'pwd'},
              time: DateTime.fromMillisecondsSinceEpoch(2000),
            ),
          ),
        ],
      );

      chatRepository.sendMessageHandler = (_, _, _, _) async* {
        yield Right(toolOnlyMessage);
      };
      // Simulate server-side busy status (as if more tools are coming).
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
      };

      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      await provider.sendMessage('run tool');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Tool-only busy turn must keep Stop visible.
      expect(provider.isCurrentSessionActivelyResponding, isTrue);
      expect(provider.canAbortActiveResponse, isTrue);
    });

    test(
      'completed mixed tool+text final hides Stop while stale busy stays active',
      () async {
        final finalWithToolAndText = AssistantMessage(
          id: 'msg_mixed',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_mixed_tool',
              messageId: 'msg_mixed',
              sessionId: 'ses_1',
              callId: 'call_mixed',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'echo hi'},
                output: 'hi',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2000),
                  end: DateTime.fromMillisecondsSinceEpoch(2005),
                ),
              ),
            ),
            const TextPart(
              id: 'part_mixed_text',
              messageId: 'msg_mixed',
              sessionId: 'ses_1',
              text: 'final answer after tool',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(finalWithToolAndText);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);

        // Clearing the SSE-settled timestamp makes the subsequent REST busy
        // refresh accepted normally. The session is still actively responding
        // for scroll/follow purposes (busy with tool
        // surface parts), but canAbortActiveResponse returns false because
        // the latest completed assistant has revealable text content.
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };
        provider.clearSseSettledTimestamps();
        await provider.loadSessionInsights('ses_1', silent: true);

        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isFalse);
      },
    );

    test(
      'refreshSessionStatusSnapshot handles session switch during in-flight await',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            title: 'Session 2',
          ),
        );

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();

        final session1 = provider.sessions.where((s) => s.id == 'ses_1').first;
        final session2 = provider.sessions.where((s) => s.id == 'ses_2').first;

        await provider.selectSession(session1);
        await provider.initializeProviders();

        // Set gate and REST state AFTER initial load/refresh are done.
        final statusGate = Completer<void>();
        chatRepository.getSessionStatusDelay = () => statusGate.future;

        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        // Start refreshSessionStatusSnapshot — this captures
        // currentIdAtCall = ses_1 (before any await), then blocks
        // on getSessionStatus which hits the gate.
        unawaited(provider.refreshSessionStatusSnapshot());
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Switch sessions while refreshSessionStatusSnapshot is blocked.
        await provider.selectSession(session2);

        // Unblock the gate — the fold runs with the captured currentIdAtCall.
        statusGate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // No crash. Session B is current. Session A's status reflects the
        // REST response (the guard didn't fire since onDone never set the
        // SSE-settled flag in this test, but currentIdAtCall was correctly
        // captured as ses_1, not ses_2).
        expect(provider.currentSession?.id, 'ses_2');
        expect(
          provider.sessionStatusById['ses_1']?.type,
          SessionStatusType.busy,
        );
      },
    );

    test(
      'active stream reports as actively responding even after settled session',
      () async {
        final textOnlyMessage = AssistantMessage(
          id: 'msg_first',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_first',
              messageId: 'msg_first',
              sessionId: 'ses_1',
              text: 'settled answer',
            ),
          ],
        );

        var callCount = 0;
        StreamController<Either<Failure, ChatMessage>>? controller;
        chatRepository.sendMessageHandler = (_, _, _, _) {
          callCount += 1;
          if (callCount == 1) {
            return Stream<Either<Failure, ChatMessage>>.value(
              Right(textOnlyMessage),
            );
          }
          // Return a stream that stays alive until we close the controller.
          controller = StreamController<Either<Failure, ChatMessage>>();
          return controller!.stream;
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        // First send settles immediately.
        await provider.sendMessage('first');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(provider.state, ChatState.loaded);
        expect(provider.canAbortActiveResponse, isFalse);

        // Second send keeps the stream alive without data yet.
        await provider.sendMessage('second');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // The active stream keeps Stop visible.
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);

        // Close the controller so the stream settles.
        await controller!.close();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.isCurrentSessionActivelyResponding, isFalse);
      },
    );

    test(
      'SSE session.status busy after completed mixed final does not re-enable Stop',
      () async {
        final finalWithToolAndText = AssistantMessage(
          id: 'msg_mixed_sse',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_mixed_sse_tool',
              messageId: 'msg_mixed_sse',
              sessionId: 'ses_1',
              callId: 'call_mixed_sse',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'echo hi'},
                output: 'hi',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2000),
                  end: DateTime.fromMillisecondsSinceEpoch(2005),
                ),
              ),
            ),
            const TextPart(
              id: 'part_mixed_sse_text',
              messageId: 'msg_mixed_sse',
              sessionId: 'ses_1',
              text: 'final answer after tool',
            ),
          ],
        );

        chatRepository.sendMessageHandler = (_, _, _, _) async* {
          yield Right(finalWithToolAndText);
        };

        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        await provider.sendMessage('hello');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.state, ChatState.loaded);
        expect(provider.isCurrentSessionActivelyResponding, isFalse);
        expect(provider.canAbortActiveResponse, isFalse);

        // Simulate an SSE session.status busy event arriving after the
        // final response has already settled. The session is still
        // actively responding for scroll/follow purposes (busy with tool
        // surface parts), but canAbortActiveResponse remains false because
        // the latest completed assistant has revealable content. Stale
        // busy from any source must not re-enable Stop.
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

        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isFalse);
      },
    );

    test('latest user message under busy keeps Stop visible', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      // Set up a previous completed assistant followed by a user message as
      // the latest tail, then mark the session as busy. The latest user
      // message must win over the previous completed assistant for abort
      // eligibility.
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        AssistantMessage(
          id: 'msg_previous_final',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_previous_final',
              messageId: 'msg_previous_final',
              sessionId: 'ses_1',
              text: 'previous answer',
            ),
          ],
        ),
        UserMessage(
          id: 'msg_user_busy',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_busy',
              messageId: 'msg_user_busy',
              sessionId: 'ses_1',
              text: 'pending prompt',
            ),
          ],
        ),
      ];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
      };

      await provider.loadMessages('ses_1');
      await provider.loadSessionInsights('ses_1', silent: true);

      expect(provider.isCurrentSessionActivelyResponding, isTrue);
      expect(provider.canAbortActiveResponse, isTrue);
    });

    test('incomplete assistant under busy keeps Stop visible', () async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      // An incomplete assistant message (no completedTime) under busy
      // must keep Stop visible. The turn is still in progress.
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        AssistantMessage(
          id: 'msg_incomplete',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_incomplete',
              messageId: 'msg_incomplete',
              sessionId: 'ses_1',
              text: 'still generating...',
            ),
          ],
        ),
      ];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
      };

      await provider.loadMessages('ses_1');
      await provider.loadSessionInsights('ses_1', silent: true);

      expect(provider.isCurrentSessionActivelyResponding, isTrue);
      expect(provider.canAbortActiveResponse, isTrue);
    });

    test(
      'historical incomplete assistant does not keep Stop visible after final',
      () async {
        await provider.projectProvider.initializeProject();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        // A stale orphaned incomplete assistant earlier in history should not
        // keep the composer in Stop mode once the latest message is a completed
        // revealable assistant. Only the latest tail is abort-relevant.
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_old_incomplete',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_old_incomplete',
                messageId: 'msg_old_incomplete',
                sessionId: 'ses_1',
                text: 'old interrupted response',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_latest_final',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(3000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_latest_final',
                messageId: 'msg_latest_final',
                sessionId: 'ses_1',
                text: 'latest completed answer',
              ),
            ],
          ),
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.loadMessages('ses_1');
        await provider.loadSessionInsights('ses_1', silent: true);

        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isFalse);
      },
    );
  });
}
