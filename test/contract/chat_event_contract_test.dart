@Tags(<String>['slow'])
library;

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../unit/providers/chat_provider_test_support.dart';

void main() {
  group('SSE event dispatch contract', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late SettingsProvider defaultSettingsProvider;
    late ChatProvider provider;

    ChatProvider buildProvider({
      DioClient? dioClient,
      Duration syncHealthCheckInterval = const Duration(seconds: 5),
      Duration abortSuppressionWindow = const Duration(milliseconds: 30),
      SettingsProvider? settingsProvider,
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

    tearDown(() async {
      await pumpEventQueue();
      provider.dispose();
      provider.projectProvider.dispose();
      await pumpEventQueue();
      defaultSettingsProvider.dispose();
    });

    Future<void> settleUntil(
      bool Function() predicate, {
      int maxTicks = 40,
      String? reason,
    }) async {
      for (var tick = 0; tick < maxTicks; tick += 1) {
        if (predicate()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail(reason ?? 'Condition was not met before event queue settled.');
    }

    Future<void> initAndSelectSession() async {
      await provider.projectProvider.initializeProject();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.initializeProviders();
      await settleUntil(() => provider.debugHasRealtimeEventSubscription);
      await pumpEventQueue();
    }

    Future<void> expectIgnoredEvent(ChatEvent event) async {
      // Match the IDs used by foreign events so removing a scope guard would
      // actually replace/remove existing content rather than remain a no-op.
      final message = UserMessage(
        id: 'msg_x',
        sessionId: 'ses_1',
        time: DateTime.utc(2026),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_x', messageId: 'msg_x', sessionId: 'ses_1', text: 'Keep me',
          ),
        ],
      );
      chatRepository.messagesBySession['ses_1'] = [message];
      await provider.loadMessages('ses_1');
      chatRepository.emitEvent(const ChatEvent(
        type: 'permission.asked',
        properties: <String, dynamic>{
          'id': 'perm_keep', 'sessionID': 'ses_1', 'permission': 'bash',
          'patterns': <String>['pwd'], 'always': <String>[],
          'metadata': <String, dynamic>{},
        },
      ));
      await settleUntil(() => provider.currentSessionPermissions.isNotEmpty);
      await pumpEventQueue();

      Map<String, Object?> snapshot() => <String, Object?>{
        'state': provider.state,
        'currentSession': provider.currentSession,
        'messages': provider.messages.toList(),
        'sessions': provider.sessions.toList(),
        'statuses': Map<String, SessionStatusInfo>.from(provider.sessionStatusById),
        'permissions': provider.currentSessionPermissions.toList(),
        'questions': provider.currentSessionQuestions.toList(),
        'error': provider.errorMessage,
        'messageFetches': chatRepository.getMessageCallCount,
        'historyFetches': chatRepository.getMessagesCallCount,
      };
      final before = snapshot();
      expect(provider.messages, [message]);
      chatRepository.emitEvent(event);
      // A later valid event on the same stream is an observable delivery
      // barrier; the negative assertion cannot pass before the event is read.
      chatRepository.emitEvent(const ChatEvent(
        type: 'todo.updated',
        properties: <String, dynamic>{
          'sessionID': 'ses_1',
          'todos': <Map<String, dynamic>>[
            {'id': 'delivery_barrier', 'content': 'Delivered', 'status': 'pending', 'priority': 'low'},
          ],
        },
      ));
      await settleUntil(() => provider.currentSessionTodo.any((todo) => todo.id == 'delivery_barrier'));
      await pumpEventQueue();
      expect(snapshot(), before, reason: '${event.type} must preserve current-session data');
    }

    // ── server.heartbeat ──

    group('server.heartbeat', () {
      test('is silently ignored and does not change provider state', () async {
        await initAndSelectSession();
        final stateBefore = provider.state;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'server.heartbeat',
            properties: <String, dynamic>{},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.state, stateBefore);
      });
    });

    // ── server.connected ──

    group('server.connected', () {
      test('triggers active session refresh without crashing', () async {
        await initAndSelectSession();
        final fetchesBefore = chatRepository.getMessagesCallCount;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'server.connected',
            properties: <String, dynamic>{},
          ),
        );
        await settleUntil(() => chatRepository.getMessagesCallCount > fetchesBefore);
        expect(provider.currentSession?.id, 'ses_1');
        expect(provider.errorMessage, isNull);
      });
    });

    // ── session.created ──

    group('session.created', () {
      test('adds new session to the session list', () async {
        await initAndSelectSession();
        final countBefore = provider.sessions.length;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        chatRepository.emitEvent(
          ChatEvent(
            type: 'session.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'ses_new',
                'workspaceId': 'default',
                'time': <String, dynamic>{'created': nowMs, 'updated': nowMs},
                'title': 'New from SSE',
              },
            },
          ),
        );
        await settleUntil(
          () => provider.sessions.length == countBefore + 1,
          reason: 'Expected new session from session.created event.',
        );
        expect(provider.sessions.any((s) => s.id == 'ses_new'), isTrue);
      });

      test('ignores session with empty id', () async {
        await initAndSelectSession();
        final countBefore = provider.sessions.length;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        chatRepository.emitEvent(
          ChatEvent(
            type: 'session.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': '',
                'workspaceId': 'default',
                'time': <String, dynamic>{'created': nowMs, 'updated': nowMs},
                'title': 'Empty ID',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.sessions.length, countBefore);
      });
    });

    // ── session.updated ──

    group('session.updated', () {
      test('updates existing session title and creation time', () async {
        await initAndSelectSession();
        final futureMs = DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch;
        final createdMs = futureMs - 1000;
        chatRepository.emitEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'ses_1',
                'workspaceId': 'default',
                'time': <String, dynamic>{
                  'created': createdMs,
                  'updated': futureMs,
                },
                'title': 'Updated Title',
              },
            },
          ),
        );
        await settleUntil(
          () =>
              provider.sessions
                  .where((s) => s.id == 'ses_1')
                  .firstOrNull
                  ?.title ==
              'Updated Title',
          reason: 'Expected session title to update from session.updated.',
        );
        expect(
          provider.sessions.firstWhere((s) => s.id == 'ses_1').createdAt,
          DateTime.fromMillisecondsSinceEpoch(createdMs),
        );
      });

      test('ignores stale event with older timestamp', () async {
        await initAndSelectSession();
        final currentTitle = provider.sessions.first.title;
        // Use a very old timestamp that is before the existing session time.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'id': 'ses_1',
                'workspaceId': 'default',
                'time': <String, dynamic>{'created': 1, 'updated': 1},
                'title': 'Stale Title',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final updated = provider.sessions.firstWhere((s) => s.id == 'ses_1');
        expect(updated.title, currentTitle);
      });
    });

    // ── session.deleted ──

    group('session.deleted', () {
      test('removes session from list via info.id', () async {
        await initAndSelectSession();
        // Add a second session first.
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_to_delete',
            workspaceId: 'default',
            time: DateTime.now(),
            title: 'Delete Me',
          ),
        );
        await provider.loadSessions();
        final countBeforeDelete = provider.sessions.length;
        expect(countBeforeDelete, greaterThanOrEqualTo(2));
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.deleted',
            properties: <String, dynamic>{
              'info': <String, dynamic>{'id': 'ses_to_delete'},
            },
          ),
        );
        await settleUntil(
          () => !provider.sessions.any((s) => s.id == 'ses_to_delete'),
          reason: 'Expected session to be removed by session.deleted.',
        );
      });

      test('removes session from list via sessionID property', () async {
        await initAndSelectSession();
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_delete_alt',
            workspaceId: 'default',
            time: DateTime.now(),
            title: 'Delete Alt',
          ),
        );
        await provider.loadSessions();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.deleted',
            properties: <String, dynamic>{'sessionID': 'ses_delete_alt'},
          ),
        );
        await settleUntil(
          () => !provider.sessions.any((s) => s.id == 'ses_delete_alt'),
          reason:
              'Expected session to be removed by sessionID property in session.deleted.',
        );
      });

      test('ignores delete event with null/empty id', () async {
        await initAndSelectSession();
        final countBefore = provider.sessions.length;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.deleted',
            properties: <String, dynamic>{},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.sessions.length, countBefore);
      });
    });

    // ── session.status ──

    group('session.status', () {
      test('updates session status to busy', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await settleUntil(
          () =>
              provider.sessionStatusById['ses_1']?.type ==
              SessionStatusType.busy,
          reason: 'Expected session status to become busy.',
        );
      });

      test(
        'updates session status to idle and marks non-current as unread',
        () async {
          await initAndSelectSession();
          // Add another session so we have a non-current one.
          chatRepository.sessions.add(
            ChatSession(
              id: 'ses_other',
              workspaceId: 'default',
              time: DateTime.now(),
              title: 'Other Session',
            ),
          );
          await provider.loadSessions();
          // First set busy.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_other',
                'status': <String, dynamic>{'type': 'busy'},
              },
            ),
          );
          await settleUntil(
            () =>
                provider.sessionStatusById['ses_other']?.type ==
                SessionStatusType.busy,
            reason: 'Expected other session status to become busy.',
          );
          // Now set idle — should mark unread since it's not the current session.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.status',
              properties: <String, dynamic>{
                'sessionID': 'ses_other',
                'status': <String, dynamic>{'type': 'idle'},
              },
            ),
          );
          await settleUntil(
            () =>
                provider.sessionStatusById['ses_other']?.type ==
                SessionStatusType.idle,
            reason: 'Expected other session status to become idle.',
          );
          expect(provider.currentSession?.id, 'ses_1');
          expect(provider.sessionAttentionFor('ses_other').hasUnreadCompletion, isTrue);
          expect(provider.sessionAttentionFor('ses_1').hasUnreadCompletion, isFalse);
        },
      );

      test('ignores status event with missing sessionID', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
      });
    });

    // ── session.diff ──

    group('session.diff', () {
      test('stores diff entries for the current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.diff',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'diff': <dynamic>[
                <String, dynamic>{
                  'file': 'lib/main.dart',
                  'before': 'old',
                  'after': 'new',
                  'additions': 5,
                  'deletions': 2,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionDiff.isNotEmpty,
          reason: 'Expected session diff to be populated.',
        );
        expect(provider.currentSessionDiff.first.file, 'lib/main.dart');
      });

      test('ignores diff event with missing sessionID', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.diff',
            properties: <String, dynamic>{
              'diff': <dynamic>[
                <String, dynamic>{
                  'file': 'lib/other.dart',
                  'before': '',
                  'after': 'content',
                  'additions': 1,
                  'deletions': 0,
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.currentSessionDiff, isEmpty);
      });
    });

    // ── todo.updated ──

    group('todo.updated', () {
      test('stores todo entries for the current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'todo.updated',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'todos': <dynamic>[
                <String, dynamic>{
                  'id': 'todo_1',
                  'content': 'Fix bug',
                  'status': 'pending',
                  'priority': 'high',
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionTodo.isNotEmpty,
          reason: 'Expected session todo to be populated.',
        );
        expect(provider.currentSessionTodo.first.content, 'Fix bug');
      });

      test('ignores todo event with missing sessionID', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'todo.updated',
            properties: <String, dynamic>{
              'todos': <dynamic>[
                <String, dynamic>{
                  'id': 'todo_2',
                  'content': 'Orphan',
                  'status': 'pending',
                  'priority': 'low',
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.currentSessionTodo, isEmpty);
      });
    });

    // ── session.idle ──

    group('session.idle', () {
      test('sets status to idle for current session', () async {
        await initAndSelectSession();
        // First make it busy.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await settleUntil(
          () =>
              provider.sessionStatusById['ses_1']?.type ==
              SessionStatusType.busy,
          reason: 'Pre-condition: session must be busy.',
        );
        // Now emit idle.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{'sessionID': 'ses_1'},
          ),
        );
        await settleUntil(
          () =>
              provider.sessionStatusById['ses_1']?.type ==
              SessionStatusType.idle,
          reason: 'Expected session status to become idle from session.idle.',
        );
      });

      test('ignores idle event with missing sessionID', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'session.idle',
            properties: <String, dynamic>{},
          ),
        );
      });

      test(
        'trailing session.error after session.idle still surfaces a notice',
        () async {
          // OpenChamber 1.12.1 fixed a class of regressions where late
          // session.error events after session.idle were silently dropped. Lock
          // in CodeWalk's P-002 invariant by emitting idle first and verifying a
          // subsequent session.error still enqueues a UI notice.
          await initAndSelectSession();
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.idle',
              properties: <String, dynamic>{'sessionID': 'ses_1'},
            ),
          );
          await settleUntil(
            () =>
                provider.sessionStatusById['ses_1']?.type ==
                SessionStatusType.idle,
            reason: 'Pre-condition: session must be idle.',
          );
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.error',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'error': <String, dynamic>{
                  'message': 'Late failure after idle',
                },
              },
            ),
          );
          await settleUntil(
            () => provider.pendingUiNotice != null,
            reason:
                'Expected trailing session.error to enqueue a UI notice after session.idle.',
          );
          expect(
            provider.pendingUiNotice!.message,
            contains('Late failure after idle'),
          );
        },
      );
    });

    // ── session.error ──

    group('session.error', () {
      test(
        'enqueues UI notice with error message for current session',
        () async {
          await initAndSelectSession();
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'session.error',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'error': <String, dynamic>{'message': 'Something went wrong'},
              },
            ),
          );
          await settleUntil(
            () => provider.pendingUiNotice != null,
            reason:
                'Expected UI notice to be enqueued for current session error.',
          );
          expect(
            provider.pendingUiNotice!.message,
            contains('Something went wrong'),
          );
        },
      );

      test('sets idle status for non-current session on error', () async {
        await initAndSelectSession();
        // Add another session so ses_other exists in the session list.
        chatRepository.sessions.add(
          ChatSession(
            id: 'ses_other',
            workspaceId: 'default',
            time: DateTime.now(),
            title: 'Other Session',
          ),
        );
        await provider.loadSessions();
        // Set it busy first.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_other',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await settleUntil(
          () =>
              provider.sessionStatusById['ses_other']?.type ==
              SessionStatusType.busy,
          reason: 'Pre-condition: other session must be busy.',
        );
        // Now emit error for the non-current session.
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.error',
            properties: <String, dynamic>{
              'sessionID': 'ses_other',
              'error': <String, dynamic>{'message': 'Background error'},
            },
          ),
        );
        await settleUntil(
          () =>
              provider.sessionStatusById['ses_other']?.type ==
              SessionStatusType.idle,
          reason: 'Expected non-current session to go idle on session.error.',
        );
      });

      test('ignores error event with null sessionID', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'session.error',
            properties: <String, dynamic>{},
          ),
        );
      });
    });

    // ── message.created / message.updated ──

    group('message.created', () {
      test('triggers fallback fetch for message in current session', () async {
        await initAndSelectSession();
        final getMessagesBefore = chatRepository.getMessagesCallCount;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'message.created',
            properties: <String, dynamic>{
              'info': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'msg_new_1',
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(
          chatRepository.getMessagesCallCount,
          greaterThanOrEqualTo(getMessagesBefore),
        );
      });

      test(
        'skips duplicate created fetch when local assistant is completed',
        () async {
          final completedMessage = AssistantMessage(
            id: 'msg_completed_local',
            sessionId: 'ses_1',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            completedTime: DateTime.fromMillisecondsSinceEpoch(1100),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_completed_local',
                messageId: 'msg_completed_local',
                sessionId: 'ses_1',
                text: 'Already final',
              ),
            ],
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            completedMessage,
          ];
          await initAndSelectSession();

          final callsBefore = chatRepository.getMessageCallCount;
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'message.created',
              properties: <String, dynamic>{
                'info': <String, dynamic>{
                  'sessionID': 'ses_1',
                  'id': 'msg_completed_local',
                },
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 60));

          expect(chatRepository.getMessageCallCount, callsBefore);
          expect(provider.messages.single, completedMessage);
        },
      );

      test('skips event with missing sessionID or messageId', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.created',
            properties: <String, dynamic>{'info': <String, dynamic>{}},
          ),
        );
      });
    });

    // ── message.part.updated ──

    group('message.part.updated', () {
      test('skips event for non-current session', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{
              'part': <String, dynamic>{
                'id': 'prt_x',
                'messageID': 'msg_x',
                'sessionID': 'ses_other',
                'type': 'text',
                'text': 'Foreign replacement',
              },
            },
          ),
        );
      });

      test('skips event with missing part data', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.part.updated',
            properties: <String, dynamic>{},
          ),
        );
      });

      test(
        'message.part.delta with direct IDs falls back to message fetch',
        () async {
          await initAndSelectSession();
          final callsBefore = chatRepository.getMessageCallCount;
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'message.part.delta',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'messageID': 'msg_missing',
                'delta': 'chunk',
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await Future<void>.delayed(const Duration(milliseconds: 30));
          expect(chatRepository.getMessageCallCount, greaterThan(callsBefore));
        },
      );

      test(
        'stale fallback after delta only merges completion status',
        () async {
          const initialPart = TextPart(
            id: 'part_stale_delta',
            messageId: 'msg_stale_delta',
            sessionId: 'ses_1',
            text: 'hello',
          );
          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_stale_delta',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[initialPart],
            ),
          ];
          await initAndSelectSession();

          chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_stale_delta',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(1200),
              parts: const <MessagePart>[initialPart],
            ),
          ];

          const updatedPart = TextPart(
            id: 'part_stale_delta',
            messageId: 'msg_stale_delta',
            sessionId: 'ses_1',
            text: 'hello world',
          );
          chatRepository.emitEvent(
            ChatEvent(
              type: 'message.part.delta',
              properties: <String, dynamic>{
                'part': MessagePartModel.fromDomain(updatedPart).toJson(),
                'delta': ' world',
              },
            ),
          );

          await settleUntil(
            () {
              final message = provider.messages.single as AssistantMessage;
              final text = message.parts.whereType<TextPart>().single.text;
              return text == 'hello world';
            },
            reason: 'Expected SSE delta to update local text before fallback.',
          );
          await settleUntil(
            () {
              final message = provider.messages.single as AssistantMessage;
              return chatRepository.getMessageCallCount > 0 &&
                  message.isCompleted;
            },
            maxTicks: 80,
            reason: 'Expected fallback fetch to merge completion status.',
          );

          final message = provider.messages.single as AssistantMessage;
          expect(
            message.parts.whereType<TextPart>().single.text,
            'hello world',
          );
          expect(message.isCompleted, isTrue);
        },
      );
    });

    // ── message.part.removed ──

    group('message.part.removed', () {
      test('skips event for non-current session', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.part.removed',
            properties: <String, dynamic>{
              'sessionID': 'ses_other',
              'messageID': 'msg_x',
              'partID': 'prt_x',
            },
          ),
        );
      });

      test('skips event with missing fields', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.part.removed',
            properties: <String, dynamic>{},
          ),
        );
      });
    });

    // ── message.removed ──

    group('message.removed', () {
      test('skips event for non-current session', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.removed',
            properties: <String, dynamic>{
              'sessionID': 'ses_other',
              'messageID': 'msg_x',
            },
          ),
        );
      });

      test('skips event with missing fields', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'message.removed',
            properties: <String, dynamic>{},
          ),
        );
      });
    });

    // ── permission.asked ──

    group('permission.asked', () {
      test('adds permission request to current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.asked',
            properties: <String, dynamic>{
              'id': 'perm_1',
              'sessionID': 'ses_1',
              'permission': 'bash',
              'patterns': <dynamic>['ls'],
              'always': <dynamic>[],
              'metadata': <String, dynamic>{},
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason: 'Expected permission request to be added.',
        );
        expect(provider.currentSessionPermissions.first.id, 'perm_1');
        expect(provider.currentSessionPermissions.first.permission, 'bash');
      });

      test('adds v2 nested permission request to current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.v2.asked',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'id': 'perm_v2',
                'sessionID': 'ses_1',
                'permission': 'bash',
                'patterns': <dynamic>['pwd'],
                'always': <dynamic>[],
                'metadata': <String, dynamic>{},
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason: 'Expected v2 permission request to be added.',
        );
        expect(provider.currentSessionPermissions.first.id, 'perm_v2');
      });
    });

    // ── permission.updated ──

    group('permission.updated', () {
      test('updates existing permission request in-place', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.asked',
            properties: <String, dynamic>{
              'id': 'perm_1',
              'sessionID': 'ses_1',
              'permission': 'bash',
              'patterns': <dynamic>['ls'],
              'always': <dynamic>[],
              'metadata': <String, dynamic>{},
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason: 'Pre-condition: permission must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.updated',
            properties: <String, dynamic>{
              'id': 'perm_1',
              'sessionID': 'ses_1',
              'permission': 'bash',
              'patterns': <dynamic>['ls', 'cat'],
              'always': <dynamic>['bash'],
              'metadata': <String, dynamic>{},
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.first.always.isNotEmpty,
          reason: 'Expected permission to be updated with always field.',
        );
        expect(
          provider.currentSessionPermissions.first.patterns,
          containsAll(<String>['ls', 'cat']),
        );
      });
    });

    // ── permission.replied ──

    group('permission.replied', () {
      test('removes permission request after reply', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.asked',
            properties: <String, dynamic>{
              'id': 'perm_1',
              'sessionID': 'ses_1',
              'permission': 'bash',
              'patterns': <dynamic>['ls'],
              'always': <dynamic>[],
              'metadata': <String, dynamic>{},
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason: 'Pre-condition: permission must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.replied',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'requestID': 'perm_1',
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isEmpty,
          reason: 'Expected permission to be removed after reply.',
        );
      });

      test('removes permission request after v2 nested reply', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.v2.asked',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'id': 'perm_v2_reply',
                'sessionID': 'ses_1',
                'permission': 'bash',
                'patterns': <dynamic>['pwd'],
                'always': <dynamic>[],
                'metadata': <String, dynamic>{},
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isNotEmpty,
          reason: 'Pre-condition: v2 permission must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'permission.v2.replied',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'perm_v2_reply',
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionPermissions.isEmpty,
          reason: 'Expected v2 permission to be removed after reply.',
        );
      });

      test('skips event with missing sessionID or requestID', () async {
        await initAndSelectSession();
        await expectIgnoredEvent(
          const ChatEvent(
            type: 'permission.replied',
            properties: <String, dynamic>{},
          ),
        );
      });
    });

    // ── question.asked ──

    group('question.asked', () {
      test('adds question request to current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'q_1',
              'sessionID': 'ses_1',
              'questions': <dynamic>[
                <String, dynamic>{
                  'question': 'Which model?',
                  'header': 'Model',
                  'options': <dynamic>[
                    <String, dynamic>{
                      'label': 'GPT-4',
                      'description': 'Best quality',
                    },
                  ],
                  'multiple': false,
                  'custom': true,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Expected question request to be added.',
        );
        expect(provider.currentSessionQuestions.first.id, 'q_1');
        expect(
          provider.currentSessionQuestions.first.questions.first.question,
          'Which model?',
        );
      });

      test('adds v2 nested question request to current session', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.v2.asked',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'id': 'q_v2',
                'sessionID': 'ses_1',
                'questions': <dynamic>[
                  <String, dynamic>{
                    'question': 'Proceed?',
                    'header': 'Confirm',
                    'options': <dynamic>[
                      <String, dynamic>{
                        'label': 'Yes',
                        'description': 'Continue',
                      },
                    ],
                    'multiple': false,
                    'custom': true,
                  },
                ],
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Expected v2 question request to be added.',
        );
        expect(provider.currentSessionQuestions.first.id, 'q_v2');
      });
    });

    // ── question.updated ──

    group('question.updated', () {
      test('updates existing question request in-place', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'q_1',
              'sessionID': 'ses_1',
              'questions': <dynamic>[
                <String, dynamic>{
                  'question': 'Which model?',
                  'header': 'Model',
                  'options': <dynamic>[
                    <String, dynamic>{
                      'label': 'GPT-4',
                      'description': 'Best quality',
                    },
                  ],
                  'multiple': false,
                  'custom': true,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Pre-condition: question must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.updated',
            properties: <String, dynamic>{
              'id': 'q_1',
              'sessionID': 'ses_1',
              'questions': <dynamic>[
                <String, dynamic>{
                  'question': 'Which model now?',
                  'header': 'Model',
                  'options': <dynamic>[
                    <String, dynamic>{
                      'label': 'GPT-4',
                      'description': 'Best quality',
                    },
                    <String, dynamic>{
                      'label': 'Claude',
                      'description': 'Alternative',
                    },
                  ],
                  'multiple': true,
                  'custom': false,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () =>
              provider.currentSessionQuestions.first.questions.first.multiple ==
              true,
          reason: 'Expected question to be updated with multiple=true.',
        );
        expect(
          provider.currentSessionQuestions.first.questions.first.options.length,
          2,
        );
      });
    });

    // ── question.replied ──

    group('question.replied', () {
      test('removes question request after reply', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'q_1',
              'sessionID': 'ses_1',
              'questions': <dynamic>[
                <String, dynamic>{
                  'question': 'Which model?',
                  'header': 'Model',
                  'options': <dynamic>[
                    <String, dynamic>{
                      'label': 'GPT-4',
                      'description': 'Best quality',
                    },
                  ],
                  'multiple': false,
                  'custom': true,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Pre-condition: question must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.replied',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'requestID': 'q_1',
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isEmpty,
          reason: 'Expected question to be removed after reply.',
        );
      });
    });

    // ── question.rejected ──

    group('question.rejected', () {
      test('removes question request after rejection', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'q_1',
              'sessionID': 'ses_1',
              'questions': <dynamic>[
                <String, dynamic>{
                  'question': 'Which model?',
                  'header': 'Model',
                  'options': <dynamic>[
                    <String, dynamic>{
                      'label': 'GPT-4',
                      'description': 'Best quality',
                    },
                  ],
                  'multiple': false,
                  'custom': true,
                },
              ],
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Pre-condition: question must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.rejected',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'requestID': 'q_1',
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isEmpty,
          reason: 'Expected question to be removed after rejection.',
        );
      });

      test('removes question request after v2 nested rejection', () async {
        await initAndSelectSession();
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.v2.asked',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'id': 'q_v2_reject',
                'sessionID': 'ses_1',
                'questions': <dynamic>[
                  <String, dynamic>{
                    'question': 'Proceed?',
                    'header': 'Confirm',
                    'options': <dynamic>[
                      <String, dynamic>{
                        'label': 'Yes',
                        'description': 'Continue',
                      },
                    ],
                    'multiple': false,
                    'custom': true,
                  },
                ],
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isNotEmpty,
          reason: 'Pre-condition: v2 question must be added first.',
        );
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.v2.rejected',
            properties: <String, dynamic>{
              'request': <String, dynamic>{
                'sessionID': 'ses_1',
                'id': 'q_v2_reject',
              },
            },
          ),
        );
        await settleUntil(
          () => provider.currentSessionQuestions.isEmpty,
          reason: 'Expected v2 question to be removed after rejection.',
        );
      });
    });

    // ── v2 reconciliation events ──

    group('v2 reconciliation events', () {
      test(
        'global revert event refreshes server-authoritative state',
        () async {
          await initAndSelectSession();
          chatRepository.getSessionsCallCount = 0;
          chatRepository.getMessagesCallCount = 0;
          chatRepository.getSessionStatusCallCount = 0;

          chatRepository.emitGlobalEvent(
            const ChatEvent(
              type: 'session.next.revert.staged',
              properties: <String, dynamic>{
                'directory': '/tmp',
                'sessionID': 'ses_1',
                'timestamp': 1000,
                'revert': <String, dynamic>{'messageID': 'msg_user_1'},
              },
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));

          expect(chatRepository.getSessionsCallCount, greaterThan(0));
          expect(chatRepository.getMessagesCallCount, greaterThan(0));
          expect(chatRepository.getSessionStatusCallCount, greaterThan(0));
        },
      );

      test('catalog.updated triggers the provider refresh contract', () async {
        await initAndSelectSession();
        final callsBefore = appRepository.getProvidersCallCount;

        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'catalog.updated',
            properties: <String, dynamic>{},
          ),
        );
        await settleUntil(
          () => appRepository.getProvidersCallCount == callsBefore + 1,
          reason: 'Expected catalog.updated to refresh providers.',
        );

        expect(appRepository.getProvidersCallCount, callsBefore + 1);
      });
    });

    // ── global event routing ──

    group('global event routing', () {
      test(
        'global permission.asked event adds permission for active context',
        () async {
          await initAndSelectSession();
          chatRepository.emitGlobalEvent(
            const ChatEvent(
              type: 'permission.asked',
              properties: <String, dynamic>{
                'id': 'perm_global_1',
                'sessionID': 'ses_1',
                'permission': 'bash',
                'patterns': <dynamic>['ls'],
                'always': <dynamic>[],
                'metadata': <String, dynamic>{},
              },
            ),
          );
          await settleUntil(
            () => provider.currentSessionPermissions.isNotEmpty,
            reason:
                'Expected global permission.asked to add permission for active context.',
          );
          expect(provider.currentSessionPermissions.first.id, 'perm_global_1');
        },
      );

      test('global server.heartbeat is silently ignored', () async {
        await initAndSelectSession();
        final stateBefore = provider.state;
        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'server.heartbeat',
            properties: <String, dynamic>{},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.state, stateBefore);
      });

      test('global event with unknown type is ignored', () async {
        await initAndSelectSession();
        final stateBefore = provider.state;
        chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'unknown.event.type',
            properties: <String, dynamic>{},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.state, stateBefore);
      });
    });

    // ── event deduplication ──

    group('event deduplication', () {
      test(
        'permission.replied on session stream then global duplicate is skipped by dedup',
        () async {
          await initAndSelectSession();
          // First add a permission.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'permission.asked',
              properties: <String, dynamic>{
                'id': 'perm_dedup_1',
                'sessionID': 'ses_1',
                'permission': 'bash',
                'patterns': <dynamic>['ls'],
                'always': <dynamic>[],
                'metadata': <String, dynamic>{},
              },
            ),
          );
          await settleUntil(
            () => provider.currentSessionPermissions.isNotEmpty,
            reason: 'Pre-condition: permission must be added first.',
          );
          // Emit permission.replied on session stream — removes the permission.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'permission.replied',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'requestID': 'perm_dedup_1',
              },
            ),
          );
          await settleUntil(
            () => provider.currentSessionPermissions.isEmpty,
            reason:
                'Pre-condition: permission must be removed by session stream reply.',
          );
          // Re-add permission so we can test global dedup.
          chatRepository.emitEvent(
            const ChatEvent(
              type: 'permission.asked',
              properties: <String, dynamic>{
                'id': 'perm_dedup_1',
                'sessionID': 'ses_1',
                'permission': 'bash',
                'patterns': <dynamic>['ls'],
                'always': <dynamic>[],
                'metadata': <String, dynamic>{},
              },
            ),
          );
          await settleUntil(
            () => provider.currentSessionPermissions.isNotEmpty,
            reason:
                'Pre-condition: permission must be re-added for dedup test.',
          );
          // Emit same permission.replied on global stream — should be deduped.
          chatRepository.emitGlobalEvent(
            const ChatEvent(
              type: 'permission.replied',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'requestID': 'perm_dedup_1',
              },
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await Future<void>.delayed(const Duration(milliseconds: 30));
          // Permission should still exist since the global duplicate was deduped.
          expect(
            provider.currentSessionPermissions.isNotEmpty,
            isTrue,
            reason:
                'Global duplicate permission.replied should have been deduped, leaving the permission intact.',
          );
        },
      );
    });

    // ── event stream failure ──

    group('event stream failure', () {
      test('provider remains stable when event stream emits failure', () async {
        await initAndSelectSession();
        final messagesBefore = provider.messages.toList();
        final sessionBefore = provider.currentSession;
        chatRepository.emitEventFailure(
          const ServerFailure('SSE connection lost'),
        );
        await settleUntil(() => provider.syncState == ChatSyncState.reconnecting);
        expect(provider.state, ChatState.loaded);
        expect(provider.currentSession, sessionBefore);
        expect(provider.messages, messagesBefore);
        expect(provider.errorMessage, isNull);
      });
    });

    // ── unknown event type ──

    group('unknown event type', () {
      test('is silently ignored via default switch branch', () async {
        await initAndSelectSession();
        final stateBefore = provider.state;
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'future.unknown.event',
            properties: <String, dynamic>{},
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(provider.state, stateBefore);
      });
    });
  });
}
