@Tags(<String>['slow'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/entities/session.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/cellular_data_saver_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - session ops', () {
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
      CellularDataSaverService? cellularDataSaverService,
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
        cellularDataSaverService: cellularDataSaverService,
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

    test(
      'renameSession returns true for no-op rename with same title',
      () async {
        await provider.loadSessions();
        final session = provider.sessions.first;

        final ok = await provider.renameSession(session, 'Session 1');

        expect(ok, isTrue);
        expect(
          provider.sessions.where((item) => item.id == session.id).first.title,
          'Session 1',
        );
      },
    );

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
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_child',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1300),
            title: 'Child Session',
            parentId: 'ses_1',
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
        expect(
          provider.visibleSessions.any((item) => item.id == 'ses_child'),
          isFalse,
        );

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
        // ADR-023: the resolver requires a server-confirmed user message
        // to scope the /session/{id}/diff call. Seed one so the diff
        // endpoint returns the expected FileDiff.
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_load_updates',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            parts: <MessagePart>[
              TextPart(
                id: 'prt_load_updates',
                messageId: 'msg_user_load_updates',
                sessionId: 'ses_1',
                text: 'edit',
              ),
            ],
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
        await provider.loadSessionInsights('ses_1', userInitiated: true);

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

    test('undoLastTurn reverts latest persisted user message', () async {
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        UserMessage(
          id: 'msg_user_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_1',
              messageId: 'msg_user_1',
              sessionId: 'ses_1',
              text: 'hello',
            ),
          ],
        ),
        AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1100),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_assistant_1',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'hi',
            ),
          ],
        ),
      ];

      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      final ok = await provider.undoLastTurn();

      expect(ok, isTrue);
      expect(chatRepository.lastRevertProjectId, 'default');
      expect(chatRepository.lastRevertSessionId, 'ses_1');
      expect(chatRepository.lastRevertMessageId, 'msg_user_1');
      expect(provider.currentSessionRevert?.messageId, 'msg_user_1');
      expect(provider.messages, isEmpty);

      final pendingSync = provider.consumePendingHistoryComposerSync(
        sessionId: 'ses_1',
      );
      expect(pendingSync, isNotNull);
      expect(pendingSync!.clear, isFalse);
      expect(pendingSync.draft?.text, 'hello');
    });

    test('revertToTurn reverts a historical persisted user message', () async {
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        UserMessage(
          id: 'msg_user_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_1',
              messageId: 'msg_user_1',
              sessionId: 'ses_1',
              text: 'first prompt',
            ),
          ],
        ),
        AssistantMessage(
          id: 'msg_assistant_1',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1100),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_assistant_1',
              messageId: 'msg_assistant_1',
              sessionId: 'ses_1',
              text: 'first answer',
            ),
          ],
        ),
        UserMessage(
          id: 'msg_user_2',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1300),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_2',
              messageId: 'msg_user_2',
              sessionId: 'ses_1',
              text: 'second prompt',
            ),
          ],
        ),
        AssistantMessage(
          id: 'msg_assistant_2',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1400),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_assistant_2',
              messageId: 'msg_assistant_2',
              sessionId: 'ses_1',
              text: 'second answer',
            ),
          ],
        ),
      ];

      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      final ok = await provider.revertToTurn('msg_user_1');

      expect(ok, isTrue);
      expect(chatRepository.lastRevertProjectId, 'default');
      expect(chatRepository.lastRevertSessionId, 'ses_1');
      expect(chatRepository.lastRevertMessageId, 'msg_user_1');
      expect(provider.currentSessionRevert?.messageId, 'msg_user_1');
      expect(provider.messages, isEmpty);

      final pendingSync = provider.consumePendingHistoryComposerSync(
        sessionId: 'ses_1',
      );
      expect(pendingSync, isNotNull);
      expect(pendingSync!.clear, isFalse);
      expect(pendingSync.draft?.text, 'first prompt');
    });

    test('revertToTurn rejects optimistic local user message ids', () async {
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      final ok = await provider.revertToTurn('local_user_1000_1');

      expect(ok, isFalse);
      expect(chatRepository.lastRevertMessageId, isNull);
    });

    test(
      'redoLastTurn advances revert boundary before full unrevert',
      () async {
        chatRepository.sessions[0] = chatRepository.sessions[0].copyWith(
          revert: const SessionRevert(messageId: 'msg_user_1'),
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_user_1',
                messageId: 'msg_user_1',
                sessionId: 'ses_1',
                text: 'hello',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_assistant_1',
                messageId: 'msg_assistant_1',
                sessionId: 'ses_1',
                text: 'hi',
              ),
            ],
          ),
          UserMessage(
            id: 'msg_user_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1300),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_user_2',
                messageId: 'msg_user_2',
                sessionId: 'ses_1',
                text: 'second',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1400),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_assistant_2',
                messageId: 'msg_assistant_2',
                sessionId: 'ses_1',
                text: 'again',
              ),
            ],
          ),
        ];

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        provider.consumePendingHistoryComposerSync(sessionId: 'ses_1');

        final ok = await provider.redoLastTurn();

        expect(ok, isTrue);
        expect(chatRepository.lastRevertProjectId, 'default');
        expect(chatRepository.lastRevertSessionId, 'ses_1');
        expect(chatRepository.lastRevertMessageId, 'msg_user_2');
        expect(chatRepository.lastUnrevertSessionId, isNull);
        expect(provider.currentSessionRevert?.messageId, 'msg_user_2');
        expect(
          provider.messages.map((message) => message.id).toList(),
          <String>['msg_user_1', 'msg_assistant_1'],
        );
        expect(
          provider.consumePendingHistoryComposerSync(sessionId: 'ses_1'),
          isNull,
        );
      },
    );

    test('redoLastTurn clears revert boundary on full unrevert flow', () async {
      chatRepository.sessions[0] = chatRepository.sessions[0].copyWith(
        revert: const SessionRevert(messageId: 'msg_user_1'),
      );
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      provider.consumePendingHistoryComposerSync(sessionId: 'ses_1');

      final ok = await provider.redoLastTurn();

      expect(ok, isTrue);
      expect(chatRepository.lastUnrevertProjectId, 'default');
      expect(chatRepository.lastUnrevertSessionId, 'ses_1');
      expect(provider.currentSessionRevert, isNull);

      final pendingSync = provider.consumePendingHistoryComposerSync(
        sessionId: 'ses_1',
      );
      expect(pendingSync, isNotNull);
      expect(pendingSync!.clear, isTrue);
    });

    test(
      'sendMessage after undo keeps replacement branch visible through stale refresh',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await sendStream.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_user_1',
                messageId: 'msg_user_1',
                sessionId: 'ses_1',
                text: 'first prompt',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_1',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1100),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_assistant_1',
                messageId: 'msg_assistant_1',
                sessionId: 'ses_1',
                text: 'first answer',
              ),
            ],
          ),
          UserMessage(
            id: 'msg_user_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1300),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_user_2',
                messageId: 'msg_user_2',
                sessionId: 'ses_1',
                text: 'second prompt',
              ),
            ],
          ),
          AssistantMessage(
            id: 'msg_assistant_2',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1400),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1500),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_assistant_2',
                messageId: 'msg_assistant_2',
                sessionId: 'ses_1',
                text: 'second answer',
              ),
            ],
          ),
        ];

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final undone = await provider.undoLastTurn();
        expect(undone, isTrue);
        expect(
          provider.messages.map((message) => message.id).toList(),
          <String>['msg_user_1', 'msg_assistant_1'],
        );

        final started = await provider.sendMessage('branch prompt');
        expect(started, isTrue);
        expect(provider.currentSessionRevert, isNull);
        expect(provider.canRedoCurrentSession, isFalse);
        expect(
          provider.messages.any(
            (message) =>
                message is UserMessage &&
                message.parts.whereType<TextPart>().any(
                  (part) => part.text == 'branch prompt',
                ),
          ),
          isTrue,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_user_2'),
          isFalse,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_assistant_2'),
          isFalse,
        );

        await provider.refreshActiveSessionView(includeStatus: false);

        expect(
          provider.messages.map((message) => message.id).toList(),
          hasLength(3),
        );
        expect(
          provider.messages.any(
            (message) =>
                message is UserMessage &&
                message.parts.whereType<TextPart>().any(
                  (part) => part.text == 'branch prompt',
                ),
          ),
          isTrue,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_user_2'),
          isFalse,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_assistant_2'),
          isFalse,
        );

        sendStream.add(
          Right(
            AssistantMessage(
              id: 'msg_branch_reply',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_branch_reply',
                  messageId: 'msg_branch_reply',
                  sessionId: 'ses_1',
                  text: 'branch answer',
                ),
              ],
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          provider.messages.any((message) => message.id == 'msg_branch_reply'),
          isTrue,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_user_2'),
          isFalse,
        );
        expect(
          provider.messages.any((message) => message.id == 'msg_assistant_2'),
          isFalse,
        );
      },
    );

    test('toggleSessionPinned updates scoped pin state and persists', () async {
      await provider.loadSessions();
      final session = provider.sessions.first;

      await provider.toggleSessionPinned(session);

      expect(provider.isSessionPinned(session.id), isTrue);
      final scopeId =
          provider.projectProvider.currentDirectory ??
          provider.projectProvider.currentProjectId;
      final pinnedJson = await localDataSource.getPinnedSessionsJson(
        serverId: provider.activeServerId,
        scopeId: scopeId,
      );
      expect(pinnedJson, isNotNull);
      final decoded = json.decode(pinnedJson!);
      expect(decoded, isA<List<dynamic>>());
      expect(decoded as List<dynamic>, contains(session.id));

      await provider.toggleSessionPinned(session);
      expect(provider.isSessionPinned(session.id), isFalse);
    });

    test(
      'visibleSessions keeps pinned sessions first across sort modes',
      () async {
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            title: 'Session 2',
          ),
        );

        await provider.loadSessions();
        expect(
          provider.visibleSessions.map((session) => session.id).toList(),
          <String>['ses_2', 'ses_1'],
        );

        final ses1 = provider.sessions
            .where((session) => session.id == 'ses_1')
            .first;
        await provider.toggleSessionPinned(ses1);

        expect(
          provider.visibleSessions.map((session) => session.id).toList(),
          <String>['ses_1', 'ses_2'],
        );

        provider.setSessionListSort(SessionListSort.oldest);
        expect(
          provider.visibleSessions.map((session) => session.id).toList(),
          <String>['ses_1', 'ses_2'],
        );

        provider.setSessionListSort(SessionListSort.title);
        expect(
          provider.visibleSessions.map((session) => session.id).toList(),
          <String>['ses_1', 'ses_2'],
        );
      },
    );

    test(
      'initializeProviders restores pinned sessions before list load',
      () async {
        final serverIdForScope =
            localDataSource.activeServerId ?? provider.activeServerId;
        final scopeId =
            provider.projectProvider.currentDirectory ??
            provider.projectProvider.currentProjectId;
        await localDataSource.savePinnedSessionsJson(
          json.encode(<String>['ses_1']),
          serverId: serverIdForScope,
          scopeId: scopeId,
        );

        await provider.initializeProviders();
        await provider.loadSessions();

        expect(provider.isSessionPinned('ses_1'), isTrue);
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
        await Future<void>.delayed(const Duration(milliseconds: 20));
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
        await Future<void>.delayed(const Duration(milliseconds: 450));

        final message = provider.messages.single as AssistantMessage;
        expect((message.parts.single as TextPart).text, 'done');
        expect(message.isCompleted, isTrue);
        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
      },
    );

    test(
      'treats an incomplete current-session assistant as active even before busy status is reported',
      () async {
        final draft = AssistantMessage(
          id: 'msg_ai_stale_draft',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_stale_draft',
              messageId: 'msg_ai_stale_draft',
              sessionId: 'ses_1',
              text: 'draft still open',
            ),
          ],
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[draft];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
        };

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);

        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);
      },
    );

    test(
      'treats busy session with latest user message as actively responding',
      () async {
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_pending_turn',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            parts: const <MessagePart>[
              TextPart(
                id: 'prt_user_pending_turn',
                messageId: 'msg_user_pending_turn',
                sessionId: 'ses_1',
                text: 'still waiting',
              ),
            ],
          ),
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);
      },
    );

    test(
      'treats busy tool-only assistant turn as actively responding',
      () async {
        final toolOnlyAssistant = AssistantMessage(
          id: 'msg_ai_tool_only',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1100),
          parts: <MessagePart>[
            ToolPart(
              id: 'prt_tool_only',
              messageId: 'msg_ai_tool_only',
              sessionId: 'ses_1',
              callId: 'call_tool_only',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'ls'},
                output: 'README.md',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(1000),
                  end: DateTime.fromMillisecondsSinceEpoch(1050),
                ),
              ),
            ),
          ],
        );

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          toolOnlyAssistant,
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
        };

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.loadSessionInsights('ses_1');

        expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);
      },
    );

    test('loadSessionInsights calls all 4 endpoints', () async {
      // ADR-023: the resolver requires a server-confirmed user message
      // before calling /session/{id}/diff. Seed one so the diff endpoint
      // is exercised alongside the other three.
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
        UserMessage(
          id: 'msg_user_load_all_4',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1500),
          parts: <MessagePart>[
            TextPart(
              id: 'prt_load_all_4',
              messageId: 'msg_user_load_all_4',
              sessionId: 'ses_1',
              text: 'edit',
            ),
          ],
        ),
      ];
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Reset counters after selectSession (which also calls loadSessionInsights).
      chatRepository.getSessionChildrenCallCount = 0;
      chatRepository.getSessionTodoCallCount = 0;
      chatRepository.getSessionDiffCallCount = 0;
      chatRepository.getSessionStatusCallCount = 0;

      await provider.loadSessionInsights('ses_1');

      expect(chatRepository.getSessionChildrenCallCount, 1);
      expect(chatRepository.getSessionTodoCallCount, 1);
      expect(chatRepository.getSessionDiffCallCount, 1);
      expect(chatRepository.getSessionStatusCallCount, 1);
    });

    test(
      'loadSessionInsights only refreshes status automatically on cellular data saver',
      () async {
        final dataSaverService = CellularDataSaverService.disabled();
        addTearDown(dataSaverService.dispose);
        dataSaverService.debugSetDataSaverEnabled(true);
        dataSaverService.debugSetTransport(DataSaverTransport.cellular);
        provider = buildProvider(cellularDataSaverService: dataSaverService);

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        chatRepository.getSessionChildrenCallCount = 0;
        chatRepository.getSessionTodoCallCount = 0;
        chatRepository.getSessionDiffCallCount = 0;
        chatRepository.getSessionStatusCallCount = 0;

        await provider.loadSessionInsights('ses_1');

        expect(chatRepository.getSessionChildrenCallCount, 0);
        expect(chatRepository.getSessionTodoCallCount, 0);
        expect(chatRepository.getSessionDiffCallCount, 0);
        expect(chatRepository.getSessionStatusCallCount, 1);
      },
    );

    test('loadSessionInsights handles partial failures gracefully', () async {
      chatRepository.sessionChildrenFailure = const ServerFailure(
        'children down',
      );
      chatRepository.sessionDiffFailure = const ServerFailure('diff down');
      chatRepository.sessionTodoById['ses_1'] = const <SessionTodo>[
        SessionTodo(
          id: 'todo_partial',
          content: 'Survive failure',
          status: 'pending',
          priority: 'low',
        ),
      ];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
      };

      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.loadSessionInsights('ses_1');

      // Todo and status populated despite children and diff failing.
      expect(provider.currentSessionTodo, hasLength(1));
      expect(provider.currentSessionTodo.single.id, 'todo_partial');
      expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
    });

    test(
      'loadSessionInsights keeps partial data when one endpoint throws',
      () async {
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.sessionTodoById['ses_1'] = const <SessionTodo>[
          SessionTodo(
            id: 'todo_after_throw',
            content: 'Still available',
            status: 'pending',
            priority: 'low',
          ),
        ];
        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
        };
        chatRepository.getSessionChildrenDelay = () async {
          throw StateError('children boom');
        };

        await expectLater(provider.loadSessionInsights('ses_1'), completes);

        expect(provider.currentSessionTodo, hasLength(1));
        expect(provider.currentSessionTodo.single.id, 'todo_after_throw');
        expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
        expect(provider.isLoadingSessionInsights, isFalse);
      },
    );

    test(
      'loadSessionInsights clears loading flag when status throws',
      () async {
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.getSessionStatusDelay = () async {
          throw StateError('status boom');
        };

        await expectLater(provider.loadSessionInsights('ses_1'), completes);

        expect(provider.isLoadingSessionInsights, isFalse);
        expect(
          provider.sessionInsightsError,
          'Some session details could not be loaded',
        );
      },
    );

    test('loadSessionInsights runs calls concurrently', () async {
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      // Set up delay hooks AFTER selectSession to avoid blocking it.
      final childrenStarted = Completer<void>();
      final todoStarted = Completer<void>();
      final gate = Completer<void>();

      // Children blocks on gate; todo signals when it starts.
      chatRepository.getSessionChildrenDelay = () async {
        childrenStarted.complete();
        await gate.future;
      };
      chatRepository.getSessionTodoDelay = () async {
        todoStarted.complete();
      };

      final insightsFuture = provider.loadSessionInsights('ses_1');

      // If sequential, todo would never start while children is blocked.
      // With parallel execution, todo starts independently.
      await todoStarted.future;
      expect(childrenStarted.isCompleted, isTrue);

      // Release the gate so loadSessionInsights can finish.
      gate.complete();
      await insightsFuture;
    });

    test('loadSessionInsights does not set loading flag when silent', () async {
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);

      var sawLoading = false;
      provider.addListener(() {
        if (provider.isLoadingSessionInsights) {
          sawLoading = true;
        }
      });

      await provider.loadSessionInsights('ses_1', silent: true);

      expect(sawLoading, isFalse);
    });

    test(
      'session.idle ends active send controls while stream teardown follows',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await sendStream.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);
        await provider.initializeProviders();

        await provider.sendMessage('pending stream');
        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(provider.canAbortActiveResponse, isTrue);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(provider.currentSessionStatus?.type, SessionStatusType.idle);
        expect(provider.isCurrentSessionActivelyResponding, isFalse);
        expect(provider.canAbortActiveResponse, isFalse);
      },
    );

    test('refreshes active session when realtime stream reconnects', () async {
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
      final updated = AssistantMessage(
        id: 'msg_ai_live',
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(1800),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_done',
            messageId: 'msg_ai_live',
            sessionId: 'ses_1',
            text: 'done after reconnect',
          ),
        ],
      );
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[draft];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
      };

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
      expect(
        ((provider.messages.single as AssistantMessage).parts.single
                as TextPart)
            .text,
        'draft',
      );

      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[updated];
      chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
        'ses_1': SessionStatusInfo(type: SessionStatusType.busy),
      };
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'server.connected',
          properties: <String, dynamic>{},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final message = provider.messages.single as AssistantMessage;
      expect((message.parts.single as TextPart).text, 'done after reconnect');
      expect(provider.currentSessionStatus?.type, SessionStatusType.busy);
    });

    test(
      'refreshActiveSessionView does not schedule scroll after a settled passive refresh',
      () async {
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.sessionStatusById = const <String, SessionStatusInfo>{
          'ses_1': SessionStatusInfo(type: SessionStatusType.idle),
        };
        await provider.loadSessionInsights('ses_1');

        var scrollRequests = 0;
        provider.setScrollToBottomCallback(({required reason}) {
          scrollRequests += 1;
        });

        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
          AssistantMessage(
            id: 'msg_refresh_scroll',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_refresh_scroll',
                messageId: 'msg_refresh_scroll',
                sessionId: 'ses_1',
                text: 'fresh message from refresh',
              ),
            ],
          ),
        ];

        await provider.refreshActiveSessionView(includeStatus: false);
        // Flush microtask-coalesced scroll callback.
        await Future<void>.value();

        expect(scrollRequests, 0);
      },
    );

    test('refreshActiveSessionView joins an in-flight refresh', () async {
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      chatRepository.getMessagesCallCount = 0;

      final firstRequestStarted = Completer<void>();
      final releaseFirstRequest = Completer<void>();
      chatRepository.getMessagesDelay = () async {
        if (!firstRequestStarted.isCompleted) {
          firstRequestStarted.complete();
        }
        await releaseFirstRequest.future;
      };

      final firstRefresh = provider.refreshActiveSessionView(
        reason: 'first-refresh',
        includeStatus: false,
      );
      await firstRequestStarted.future;

      var secondCompleted = false;
      final secondRefresh = provider
          .refreshActiveSessionView(
            reason: 'second-refresh',
            includeStatus: false,
          )
          .then((_) {
            secondCompleted = true;
          });

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondCompleted, isFalse);
      expect(chatRepository.getMessagesCallCount, 1);

      releaseFirstRequest.complete();
      await firstRefresh;
      await secondRefresh;

      expect(secondCompleted, isTrue);
      expect(chatRepository.getMessagesCallCount, 1);
    });

    test(
      'refreshActiveSessionView preserves completed assistant content against shorter same-id snapshot',
      () async {
        const sessionId = 'ses_1';
        final completedLocal = AssistantMessage(
          id: 'msg_completed_refresh_regression',
          sessionId: sessionId,
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2500),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_completed_refresh_regression',
              messageId: 'msg_completed_refresh_regression',
              sessionId: sessionId,
              text: 'complete final answer that must stay visible',
            ),
          ],
        );
        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          completedLocal,
        ];

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        chatRepository.messagesBySession[sessionId] = <ChatMessage>[
          AssistantMessage(
            id: completedLocal.id,
            sessionId: sessionId,
            time: completedLocal.time,
            parts: const <MessagePart>[
              TextPart(
                id: 'part_completed_refresh_regression',
                messageId: 'msg_completed_refresh_regression',
                sessionId: sessionId,
                text: 'complete final',
              ),
            ],
          ),
        ];

        await provider.refreshActiveSessionView(includeStatus: false);

        final refreshed = provider.messages.single as AssistantMessage;
        expect(refreshed.isCompleted, isTrue);
        expect(refreshed.completedTime, completedLocal.completedTime);
        expect(
          (refreshed.parts.single as TextPart).text,
          'complete final answer that must stay visible',
        );
      },
    );

    test(
      'refreshActiveSessionView preserves active local tail against stale snapshot',
      () async {
        final sendStream = StreamController<Either<Failure, ChatMessage>>();
        addTearDown(() async {
          await sendStream.close();
        });
        chatRepository.sendMessageHandler = (_, _, _, _) => sendStream.stream;

        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        unawaited(provider.sendMessage('Run live tools'));
        await Future<void>.delayed(Duration.zero);

        final liveAssistant = AssistantMessage(
          id: 'msg_live_tail',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_live_tail_tool',
              messageId: 'msg_live_tail',
              sessionId: 'ses_1',
              callId: 'call_live_tail_tool',
              tool: 'bash',
              state: ToolStateRunning(
                input: const <String, dynamic>{
                  'description': 'Collecting runtime details',
                  'command': 'git status --short',
                },
                time: DateTime.fromMillisecondsSinceEpoch(2200),
              ),
            ),
          ],
        );

        sendStream.add(Right(liveAssistant));
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(
          provider.messages.any((msg) => msg.id == 'msg_live_tail'),
          isTrue,
        );

        chatRepository.messagesBySession['ses_1'] = const <ChatMessage>[];
        await provider.refreshActiveSessionView(includeStatus: false);

        expect(provider.isCurrentSessionActivelyResponding, isTrue);
        expect(
          provider.messages.any((msg) => msg.id == 'msg_live_tail'),
          isTrue,
        );
      },
    );

    test(
      'enters degraded mode after repeated stream failures and recovers on signal',
      () async {
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

        chatRepository.emitEventFailure(const NetworkFailure('stream down 1'));
        chatRepository.emitEventFailure(const NetworkFailure('stream down 2'));
        chatRepository.emitEventFailure(const NetworkFailure('stream down 3'));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(provider.isInDegradedMode, isTrue);
        expect(provider.syncState, ChatSyncState.delayed);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(provider.isInDegradedMode, isFalse);
        expect(provider.syncState, ChatSyncState.connected);
      },
    );

    test(
      'resume foreground re-subscribes and reconciles session state',
      () async {
        final nextMessage = AssistantMessage(
          id: 'msg_resume',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_resume',
              messageId: 'msg_resume',
              sessionId: 'ses_1',
              text: 'after resume',
            ),
          ],
        );
        chatRepository.messagesBySession['ses_1'] = <ChatMessage>[nextMessage];

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

        final sessionsBefore = chatRepository.getSessionsCallCount;
        final messagesBefore = chatRepository.getMessagesCallCount;

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          chatRepository.getSessionsCallCount,
          greaterThan(sessionsBefore),
        );
        expect(
          chatRepository.getMessagesCallCount,
          greaterThan(messagesBefore),
        );
        expect(
          ((provider.messages.single as AssistantMessage).parts.single
                  as TextPart)
              .text,
          'after resume',
        );
      },
    );

    test(
      'foreground resume preserves visible state and ignores duplicate active calls',
      () async {
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(provider.sessions.first);

        final sessionsBefore = chatRepository.getSessionsCallCount;
        final messagesBefore = chatRepository.getMessagesCallCount;
        final states = <ChatState>[];
        provider.addListener(() => states.add(provider.state));

        await provider.setForegroundActive(false);
        await provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(provider.state, ChatState.loaded);
        expect(states, isNot(contains(ChatState.loading)));
        expect(
          chatRepository.getSessionsCallCount,
          greaterThan(sessionsBefore),
        );
        expect(
          chatRepository.getMessagesCallCount,
          greaterThan(messagesBefore),
        );

        final sessionsAfterResume = chatRepository.getSessionsCallCount;
        final messagesAfterResume = chatRepository.getMessagesCallCount;
        await provider.setForegroundActive(true);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(chatRepository.getSessionsCallCount, sessionsAfterResume);
        expect(chatRepository.getMessagesCallCount, messagesAfterResume);
      },
    );

    test(
      'global session.updated applies incrementally without broad session reload',
      () async {
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
        final sessionsBefore = chatRepository.getSessionsCallCount;
        final activeDirectory = provider.projectProvider.currentDirectory;

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'directory': ?activeDirectory,
              'info': const <String, dynamic>{
                'id': 'ses_1',
                'workspaceId': 'default',
                'title': 'Session 1 renamed',
                'time': <String, dynamic>{'created': 1000, 'updated': 2000},
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(provider.sessions.first.title, 'Session 1 renamed');
        expect(chatRepository.getSessionsCallCount, sessionsBefore);
      },
    );

    test(
      'global session.updated preserves parentId when payload omits parent fields',
      () async {
        chatRepository.sessions
          ..clear()
          ..addAll(<ChatSession>[
            ChatSession(
              id: 'ses_parent',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Parent',
            ),
            ChatSession(
              id: 'ses_child',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              title: 'Child',
              parentId: 'ses_parent',
            ),
          ]);

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
        final activeDirectory = provider.projectProvider.currentDirectory;

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'directory': ?activeDirectory,
              'info': const <String, dynamic>{
                'id': 'ses_child',
                'workspaceId': 'default',
                'title': 'Child renamed',
                'time': <String, dynamic>{'created': 2000, 'updated': 3000},
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final updatedChild = provider.sessions
            .where((session) => session.id == 'ses_child')
            .first;
        expect(updatedChild.title, 'Child renamed');
        expect(updatedChild.parentId, 'ses_parent');
      },
    );

    test(
      'global todo and interaction events apply incrementally to the active context',
      () async {
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
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final sessionsBefore = chatRepository.getSessionsCallCount;
        final activeDirectory = provider.projectProvider.currentDirectory;

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'todo.updated',
            properties: <String, dynamic>{
              'directory': activeDirectory,
              'sessionID': 'ses_1',
              'todos': const <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'todo_global_1',
                  'content': 'Review global sync event handling',
                  'status': 'in_progress',
                  'priority': 'high',
                },
              ],
            },
          ),
        );
        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'permission.asked',
            properties: <String, dynamic>{
              'id': 'perm_global_1',
              'sessionID': 'ses_1',
              'permission': 'bash',
              'patterns': <String>['*'],
              'always': <String>['*'],
              'metadata': <String, dynamic>{},
            },
          ),
        );
        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'question_global_1',
              'sessionID': 'ses_1',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Proceed with event-sourced reconcile?',
                  'header': 'Sync',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'Yes',
                      'description': 'Keep incremental sync',
                    },
                  ],
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(provider.currentSessionTodo, hasLength(1));
        expect(provider.currentSessionTodo.single.id, 'todo_global_1');
        expect(provider.currentThreadPermissionRequests, hasLength(1));
        expect(
          provider.currentThreadPermissionRequests.single.id,
          'perm_global_1',
        );
        expect(provider.currentThreadQuestionRequests, hasLength(1));
        expect(
          provider.currentThreadQuestionRequests.single.id,
          'question_global_1',
        );
        expect(chatRepository.getSessionsCallCount, sessionsBefore);
      },
    );

    test(
      'visibleSessions keeps ancestors needed for tree grouping beyond limit',
      () async {
        chatRepository.sessions
          ..clear()
          ..add(
            ChatSession(
              id: 'ses_parent',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              title: 'Parent',
            ),
          )
          ..add(
            ChatSession(
              id: 'ses_child',
              workspaceId: 'default',
              time: DateTime.fromMillisecondsSinceEpoch(999999),
              title: 'Child',
              parentId: 'ses_parent',
            ),
          )
          ..addAll(
            List<ChatSession>.generate(
              44,
              (index) => ChatSession(
                id: 'ses_root_$index',
                workspaceId: 'default',
                time: DateTime.fromMillisecondsSinceEpoch(900000 - index),
                title: 'Root $index',
              ),
            ),
          );

        await provider.loadSessions();

        expect(
          provider.visibleSessions.where((s) => s.id == 'ses_child'),
          isNotEmpty,
        );
        expect(
          provider.visibleSessions.where((s) => s.id == 'ses_parent'),
          isNotEmpty,
        );
      },
    );

    test(
      'ignores conflicting session.updated events while rename is pending',
      () async {
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

        final renameCompleter = Completer<Either<Failure, ChatSession>>();
        chatRepository.updateSessionHandler = (_, sessionId, input, _) {
          return renameCompleter.future;
        };

        await provider.initializeProviders();
        await provider.loadSessions();
        final session = provider.sessions.first;
        final activeDirectory = provider.projectProvider.currentDirectory;

        final renameFuture = provider.renameSession(session, 'Local Rename');
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(provider.sessions.first.title, 'Local Rename');

        chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'directory': ?activeDirectory,
              'info': <String, dynamic>{
                'id': session.id,
                'workspaceId': session.workspaceId,
                'title': 'Remote Old Title',
                'time': <String, dynamic>{
                  'created': session.time.millisecondsSinceEpoch,
                  'updated': session.time.millisecondsSinceEpoch,
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.sessions.first.title, 'Local Rename');

        final renamedSession = session.copyWith(title: 'Local Rename');
        renameCompleter.complete(Right(renamedSession));
        final ok = await renameFuture;
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(ok, isTrue);
        expect(provider.sessions.first.title, 'Local Rename');
      },
    );

    // ADR-023 regression coverage for /session/{id}/diff handling. The official
    // upstream SessionSummary.diff returns [] when messageID is omitted, so
    // CodeWalk must always scope the call to a server-confirmed user turn.
    group('ChatProvider - diff (ADR-023)', () {
      test(
        'loadSessionInsights targets the latest server-confirmed user message',
        () async {
          final session = ChatSession(
            id: 'ses_diff_adr_1',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Diff ADR 1',
          );
          chatRepository.sessions.add(session);
          chatRepository.messagesBySession[session.id] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_diff_1',
              sessionId: 'ses_diff_adr_1',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              parts: <MessagePart>[
                TextPart(
                  id: 'prt_diff_1',
                  messageId: 'msg_user_diff_1',
                  sessionId: 'ses_diff_adr_1',
                  text: 'edit',
                ),
              ],
            ),
          ];
          chatRepository.sessionDiffById[session.id] = const <SessionDiff>[
            SessionDiff(
              file: 'lib/main.dart',
              before: 'old',
              after: 'new',
              additions: 1,
              deletions: 1,
              status: 'modified',
            ),
          ];
          await provider.selectSession(session);
          // Let the unawaited selectSession -> loadSessionInsights settle.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          chatRepository.getSessionDiffCallCount = 0;
          chatRepository.lastGetSessionDiffMessageId = null;

          await provider.loadSessionInsights(session.id, userInitiated: true);

          // Critical: the resolver must have forwarded a non-null messageId
          // to the datasource so the upstream summary.diff call returns the
          // real diff instead of an empty list.
          expect(chatRepository.getSessionDiffCallCount, 1);
          expect(chatRepository.lastGetSessionDiffMessageId, 'msg_user_diff_1');
          expect(provider.currentSessionDiff, hasLength(1));
          expect(provider.isCurrentSessionDiffLoaded, isTrue);
          expect(provider.currentSessionDiffError, isNull);
        },
      );

      test(
        'automatic empty diff refresh does not clear a known-good diff',
        () async {
          final session = ChatSession(
            id: 'ses_diff_adr_2',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Diff ADR 2',
          );
          chatRepository.sessions.add(session);
          chatRepository.messagesBySession[session.id] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_diff_2',
              sessionId: 'ses_diff_adr_2',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              parts: <MessagePart>[
                TextPart(
                  id: 'prt_diff_2',
                  messageId: 'msg_user_diff_2',
                  sessionId: 'ses_diff_adr_2',
                  text: 'edit',
                ),
              ],
            ),
          ];

          // First, populate the diff cache via a successful scoped call.
          chatRepository.sessionDiffById[session.id] = const <SessionDiff>[
            SessionDiff(
              file: 'lib/main.dart',
              before: 'old',
              after: 'new',
              additions: 1,
              deletions: 1,
              status: 'modified',
            ),
          ];
          await provider.selectSession(session);
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(provider.currentSessionDiff, hasLength(1));

          // Now simulate an automatic refresh that returns no diff (e.g. the
          // latest server-confirmed turn produced no file changes).
          chatRepository.sessionDiffById[session.id] = const <SessionDiff>[];
          chatRepository.getSessionDiffCallCount = 0;
          chatRepository.lastGetSessionDiffMessageId = null;
          await provider.loadSessionInsights(session.id, silent: true);

          // The call MUST have used a messageId, otherwise upstream returns
          // [] and the bug is unfixed.
          expect(chatRepository.getSessionDiffCallCount, 1);
          expect(chatRepository.lastGetSessionDiffMessageId, 'msg_user_diff_2');
          // Existing non-empty diff must be preserved.
          expect(provider.currentSessionDiff, hasLength(1));
          expect(provider.currentSessionDiff.single.file, 'lib/main.dart');
        },
      );

      test('review-changes exhaustive scan clears the diff only when every '
          'eligible turn returns empty', () async {
        final session = ChatSession(
          id: 'ses_diff_adr_3',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Diff ADR 3',
        );
        chatRepository.sessions.add(session);
        // Seed two server-confirmed user messages, oldest first in cache
        // so the visible order walks newest-to-oldest.
        chatRepository.messagesBySession[session.id] = <ChatMessage>[
          UserMessage(
            id: 'msg_user_diff_older',
            sessionId: 'ses_diff_adr_3',
            time: DateTime.fromMillisecondsSinceEpoch(1500),
            parts: <MessagePart>[
              TextPart(
                id: 'prt_older',
                messageId: 'msg_user_diff_older',
                sessionId: 'ses_diff_adr_3',
                text: 'older edit',
              ),
            ],
          ),
          UserMessage(
            id: 'msg_user_diff_newer',
            sessionId: 'ses_diff_adr_3',
            time: DateTime.fromMillisecondsSinceEpoch(2500),
            parts: <MessagePart>[
              TextPart(
                id: 'prt_newer',
                messageId: 'msg_user_diff_newer',
                sessionId: 'ses_diff_adr_3',
                text: 'newer edit',
              ),
            ],
          ),
        ];

        chatRepository.sessionDiffById[session.id] = <SessionDiff>[];
        chatRepository.sessionDiffByMessageId[session.id] = {
          'msg_user_diff_older': const <SessionDiff>[
            SessionDiff(
              file: 'lib/main.dart',
              before: 'old',
              after: 'new',
              additions: 1,
              deletions: 1,
              status: 'modified',
            ),
          ],
          'msg_user_diff_newer': const <SessionDiff>[],
        };
        await provider.selectSession(session);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // The user opens the Review changes dialog: this triggers
        // exhaustiveDiffScan. The helper should fall back from the empty
        // latest-turn response to the older turn's diff.
        chatRepository.getSessionDiffCallCount = 0;
        chatRepository.lastGetSessionDiffMessageId = null;
        await provider.loadSessionInsights(
          session.id,
          userInitiated: true,
          exhaustiveDiffScan: true,
        );

        // The resolver must have walked to the older turn and picked up
        // the seeded diff instead of staying empty because the latest turn
        // produced no changes.
        expect(provider.currentSessionDiff, isNotEmpty);
        expect(provider.isCurrentSessionDiffLoaded, isTrue);
      });

      test(
        'loadSessionInsights marks loaded-empty when no user turn exists yet',
        () async {
          final session = ChatSession(
            id: 'ses_diff_adr_4',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Diff ADR 4',
          );
          chatRepository.sessions.add(session);
          // No UserMessage is seeded.
          chatRepository.sessionDiffById[session.id] = const <SessionDiff>[
            SessionDiff(
              file: 'lib/main.dart',
              before: 'old',
              after: 'new',
              additions: 1,
              deletions: 1,
              status: 'modified',
            ),
          ];
          await provider.selectSession(session);
          await Future<void>.delayed(const Duration(milliseconds: 30));

          await provider.loadSessionInsights(session.id, userInitiated: true);

          // The provider should not call the REST diff endpoint when there
          // is no server-confirmed user turn to scope it to, and the UI
          // state should reflect a definitive "loaded empty" result for
          // the user-initiated path.
          expect(chatRepository.getSessionDiffCallCount, 0);
          expect(provider.isCurrentSessionDiffLoaded, isTrue);
          expect(provider.currentSessionDiff, isEmpty);
        },
      );

      test(
        'loadSessionInsights latches an error when the diff request fails',
        () async {
          final session = ChatSession(
            id: 'ses_diff_adr_5',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Diff ADR 5',
          );
          chatRepository.sessions.add(session);
          chatRepository.messagesBySession[session.id] = <ChatMessage>[
            UserMessage(
              id: 'msg_user_diff_err',
              sessionId: 'ses_diff_adr_5',
              time: DateTime.fromMillisecondsSinceEpoch(1500),
              parts: <MessagePart>[
                TextPart(
                  id: 'prt_diff_err',
                  messageId: 'msg_user_diff_err',
                  sessionId: 'ses_diff_adr_5',
                  text: 'edit',
                ),
              ],
            ),
          ];
          await provider.selectSession(session);
          await Future<void>.delayed(const Duration(milliseconds: 30));
          chatRepository.sessionDiffFailure = const NetworkFailure('offline');

          await provider.loadSessionInsights(session.id, userInitiated: true);

          // A failure does not advance the loaded-state bookkeeping — the
          // error is latched instead so the UI can surface it.
          expect(provider.currentSessionDiff, isEmpty);
          expect(provider.currentSessionDiffError, 'offline');
        },
      );
    });
  });
}
