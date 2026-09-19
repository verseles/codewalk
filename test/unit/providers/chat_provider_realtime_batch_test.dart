@Tags(<String>['slow'])
library;

import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - realtime batching (issue #176)', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late ChatProvider provider;
    late SettingsProvider defaultSettingsProvider;

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
      provider = buildChatProvider(
        chatRepository: chatRepository,
        appRepository: appRepository,
        localDataSource: localDataSource,
        defaultSettingsProvider: defaultSettingsProvider,
      );
    });

    Future<void> settleUntil(
      bool Function() predicate, {
      String? reason,
    }) async {
      for (var tick = 0; tick < 40; tick += 1) {
        if (predicate()) {
          return;
        }
        await pumpEventQueue();
      }
      fail(reason ?? 'Condition was not met before event queue settled.');
    }

    test('todo.updated bursts coalesce into fewer notifications', () async {
      await provider.projectProvider.initializeProject();
      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(
        provider.sessions.firstWhere((session) => session.id == 'ses_1'),
      );
      await provider.refresh();
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected realtime subscription before burst.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      var notifications = 0;
      provider.addListener(() => notifications += 1);

      // Six distinct payloads: every event changes state, so without
      // batching each one would notify.
      for (var index = 0; index < 6; index += 1) {
        chatRepository.emitEvent(
          ChatEvent(
            type: 'todo.updated',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'todos': <Map<String, dynamic>>[
                <String, dynamic>{
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

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(notifications, lessThan(6));
      expect(provider.currentSessionTodo.single.id, 'todo_5');
    });

    test('session.idle flushes the pending batch immediately', () async {
      await provider.projectProvider.initializeProject();
      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(
        provider.sessions.firstWhere((session) => session.id == 'ses_1'),
      );
      await provider.refresh();
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected realtime subscription before idle flush.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.status',
          properties: <String, dynamic>{
            'sessionID': 'ses_1',
            'status': <String, dynamic>{'type': 'busy'},
          },
        ),
      );
      chatRepository.emitEvent(
        const ChatEvent(
          type: 'session.idle',
          properties: <String, dynamic>{'sessionID': 'ses_1'},
        ),
      );

      // Idle is terminal: the final state must be visible without
      // waiting for the batch window.
      await pumpEventQueue();
      await pumpEventQueue();

      expect(provider.sessionStatusById['ses_1']?.type.name, 'idle');
    });

    test('session.status idle flushes the pending batch immediately', () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await provider.projectProvider.initializeProject();
        await provider.initializeProviders();
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions.firstWhere((session) => session.id == 'ses_1'),
        );
        await provider.refresh();
        await settleUntil(
          () => provider.debugHasRealtimeEventSubscription,
          reason: 'Expected realtime subscription before status flush.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Arm a pending batch, then end the turn via session.status idle
        // (no session.idle): the terminal frame must flush immediately
        // instead of waiting for the 120ms desktop batch window.
        for (var index = 0; index < 3; index += 1) {
          chatRepository.emitEvent(
            ChatEvent(
              type: 'todo.updated',
              properties: <String, dynamic>{
                'sessionID': 'ses_1',
                'todos': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'todo_flush_$index',
                    'content': 'content_$index',
                    'status': 'pending',
                    'priority': 'medium',
                  },
                ],
              },
            ),
          );
        }
        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'busy'},
            },
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();
        expect(provider.debugHasPendingDeltaNotify, isTrue);

        chatRepository.emitEvent(
          const ChatEvent(
            type: 'session.status',
            properties: <String, dynamic>{
              'sessionID': 'ses_1',
              'status': <String, dynamic>{'type': 'idle'},
            },
          ),
        );

        // No batch-window wait: terminal idle must already be delivered.
        await pumpEventQueue();
        await pumpEventQueue();

      expect(provider.sessionStatusById['ses_1']?.type.name, 'idle');
      expect(provider.debugHasPendingDeltaNotify, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    });

    test('completed tool-only assistant step stays batched', () async {
      await provider.projectProvider.initializeProject();
      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(
        provider.sessions.firstWhere((session) => session.id == 'ses_1'),
      );
      await provider.refresh();
      await settleUntil(
        () => provider.debugHasRealtimeEventSubscription,
        reason: 'Expected realtime subscription before tool step.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // A NEW completed tool-only step must not flush: busy tool chains
      // keep #176 coalescing; only revealable completion is terminal.
      chatRepository.messagesBySession['ses_1'] = <ChatMessage>[
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
      chatRepository.emitEvent(
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

      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        provider.messages
            .whereType<AssistantMessage>()
            .any((message) => message.id == 'msg_tool_step'),
        isTrue,
      );
      expect(provider.debugHasPendingDeltaNotify, isTrue);
    });
  });
}
