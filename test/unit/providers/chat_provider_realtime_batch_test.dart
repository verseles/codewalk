import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - realtime batching (issue #176)', () {
    late FakeChatRepository repository;
    late ChatProvider provider;

    Future<void> withProvider(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      final fixtures = await buildDefaultTestFixtures();
      repository = fixtures.chatRepository;
      provider = buildChatProvider(
        chatRepository: repository,
        appRepository: fixtures.appRepository,
        localDataSource: fixtures.localDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
      );
      try {
        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        await tester.pump();
        await provider.refresh();
        repository.emitEvent(
          const ChatEvent(
            type: 'server.connected',
            properties: <String, dynamic>{},
          ),
        );
        await tester.pump();
        await provider.loadSessionInsights('ses_1');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(provider.debugHasRealtimeEventSubscription, isTrue);
        expect(provider.syncState, ChatSyncState.connected);
        expect(provider.debugHasPendingDeltaNotify, isFalse);
        await body();
      } finally {
        // Widget invariants run before package:test tearDown callbacks.
        // Dispose timer owners inside the fake-clock callback itself.
        await tester.pump();
        provider.dispose();
        provider.projectProvider.dispose();
        fixtures.defaultSettingsProvider.dispose();
        await tester.pump();
      }
    }

    void emitTodos(int count) {
      for (var index = 0; index < count; index++) {
        repository.sessionTodoById['ses_1'] = <SessionTodo>[
          SessionTodo(
            id: 'todo_$index',
            content: 'content_$index',
            status: 'pending',
            priority: 'medium',
          ),
        ];
        repository.emitEvent(
          ChatEvent(
            type: 'todo.updated',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'todos': <Map<String, dynamic>>[
                {
                  'id': 'todo_$index',
                  'content': 'content_$index',
                  'status': 'pending',
                  'priority': 'medium',
                },
              ],
            },
          ),
        );
      }
    }

    void emitStatus(String type) {
      repository.emitEvent(
        ChatEvent(
          type: 'session.status',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'status': <String, dynamic>{'type': type},
          },
        ),
      );
    }

    testWidgets(
      'todo.updated bursts coalesce into fewer notifications',
      (tester) async {
        await withProvider(tester, () async {
          var notifications = 0;
          provider.addListener(() => notifications++);
          emitTodos(6);
          await tester.pump();
          expect(provider.debugHasPendingDeltaNotify, isTrue);
          expect(notifications, 0);
          // Linux batches for 120ms. Pumping advances virtual, not wall, time.
          await tester.pump(const Duration(milliseconds: 119));
          expect(notifications, 0);
          await tester.pump(const Duration(milliseconds: 1));
          expect(notifications, inInclusiveRange(1, 5));
          expect(provider.currentSessionTodo.single.id, 'todo_5');
          expect(provider.debugHasPendingDeltaNotify, isFalse);
        });
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );

    for (final eventType in ['session.idle', 'session.status']) {
      final description = eventType == 'session.idle'
          ? 'session.idle flushes the pending batch immediately'
          : 'session.status idle flushes the pending batch immediately';
      testWidgets(description, (tester) async {
        await withProvider(tester, () async {
          // Establish the busy transition separately from the pending todo
          // batch; it has its own legitimate session/attention notifications.
          emitStatus('busy');
          await tester.pump(const Duration(milliseconds: 120));
          await tester.pump();
          var notifications = 0;
          final deliveredTodos = <String>[];
          provider.addListener(() {
            notifications++;
            deliveredTodos.addAll(
              provider.currentSessionTodo.map((todo) => todo.id),
            );
          });
          emitTodos(3);
          await tester.pump();
          expect(provider.debugHasPendingDeltaNotify, isTrue);
          expect(notifications, 0);

          if (eventType == 'session.idle') {
            repository.emitEvent(
              const ChatEvent(
                type: 'session.idle',
                properties: <String, dynamic>{'sessionID': 'ses_1'},
              ),
            );
          } else {
            emitStatus('idle');
          }
          // No virtual-time advance: the terminal event must flush the batch.
          await tester.pump();
          expect(
            provider.sessionStatusById['ses_1']?.type,
            SessionStatusType.idle,
          );
          expect(provider.debugHasPendingDeltaNotify, isFalse);
          expect(notifications, greaterThan(0));
          expect(deliveredTodos, contains('todo_2'));
        });
      }, variant: const TargetPlatformVariant({TargetPlatform.linux}));
    }

    testWidgets(
      'completed tool-only assistant step stays batched',
      (tester) async {
        await withProvider(tester, () async {
          repository.messagesBySession['ses_1'] = <ChatMessage>[
            AssistantMessage(
              id: 'msg_tool_step',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(2000),
              completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_step',
                  messageId: 'msg_tool_step',
                  sessionId: 'ses_1',
                  callId: 'call_tool_step',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'pwd'},
                    output: '/tmp/project',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(2000),
                      end: DateTime.fromMillisecondsSinceEpoch(2050),
                    ),
                  ),
                ),
              ],
            ),
          ];
          repository.emitEvent(
            const ChatEvent(
              type: 'message.updated',
              properties: <String, dynamic>{
                'info': <String, dynamic>{
                  'id': 'msg_tool_step',
                  'sessionID': 'ses_1',
                },
              },
            ),
          );
          await tester.pump();
          expect(
            provider.messages.map((message) => message.id),
            contains('msg_tool_step'),
          );
          expect(provider.debugHasPendingDeltaNotify, isTrue);
          await tester.pump(const Duration(milliseconds: 120));
          expect(provider.debugHasPendingDeltaNotify, isFalse);
        });
      },
      variant: const TargetPlatformVariant({TargetPlatform.linux}),
    );
  });
}
