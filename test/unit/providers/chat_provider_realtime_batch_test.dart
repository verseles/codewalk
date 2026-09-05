@Tags(<String>['slow'])
library;

import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
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
  });
}
