@Tags(<String>['slow'])
library;

import 'dart:async';

import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

class _CountingLocalDataSource extends InMemoryAppLocalDataSource {
  int snapshotIdsWrites = 0;

  @override
  Future<void> saveSessionMessagesSnapshotIds(
    String snapshotIdsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    snapshotIdsWrites += 1;
    return super.saveSessionMessagesSnapshotIds(
      snapshotIdsJson,
      serverId: serverId,
      scopeId: scopeId,
    );
  }
}

void main() {
  group('ChatProvider - snapshot ids persistence (issue #177)', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late _CountingLocalDataSource localDataSource;
    late ChatProvider provider;

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = _CountingLocalDataSource();
      provider = buildChatProvider(
        chatRepository: chatRepository,
        appRepository: appRepository,
        localDataSource: localDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
      );
    });

    Future<void> waitForLoaded() async {
      for (var tick = 0; tick < 200; tick += 1) {
        if (provider.state == ChatState.loaded) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('Provider did not settle to loaded state.');
    }

    Future<void> sendCompleted(String text, String assistantId) async {
      final assistant = AssistantMessage(
        id: assistantId,
        sessionId: 'ses_1',
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
        parts: <MessagePart>[
          TextPart(
            id: 'prt_$assistantId',
            messageId: assistantId,
            sessionId: 'ses_1',
            text: 'answer $text',
          ),
        ],
      );
      chatRepository.sendMessageHandler = (_, _, _, _) async* {
        yield Right(assistant);
      };
      await provider.sendMessage(text);
      await waitForLoaded();
      // Let debounced snapshot drains finish.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    test('repeated snapshot writes skip unchanged ids payload', () async {
      await provider.projectProvider.initializeProject();
      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(
        provider.sessions.firstWhere((session) => session.id == 'ses_1'),
      );
      await provider.refresh();

      await sendCompleted('one', 'msg_a1');
      final writesAfterFirst = localDataSource.snapshotIdsWrites;
      expect(writesAfterFirst, greaterThan(0));

      await sendCompleted('two', 'msg_a2');
      final writesAfterSecond = localDataSource.snapshotIdsWrites;

      // Second snapshot of the same session must not rewrite the ids LRU:
      // ses_1 was already most-recent.
      expect(writesAfterSecond, writesAfterFirst);

      final storedIds = localDataSource.scopedStrings.values.where(
        (value) => value.contains('ses_1'),
      );
      expect(storedIds, isNotEmpty);
    });
  });
}
