import 'dart:async';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('empty project enters the new chat draft', () {
    late FakeChatRepository chatRepository;
    late FakeAppRepository appRepository;
    late InMemoryAppLocalDataSource localDataSource;
    late SettingsProvider defaultSettingsProvider;

    setUp(() async {
      final fixtures = await buildDefaultTestFixtures();
      chatRepository = fixtures.chatRepository;
      appRepository = fixtures.appRepository;
      localDataSource = fixtures.localDataSource;
      defaultSettingsProvider = fixtures.defaultSettingsProvider;
    });

    ChatProvider build() => buildChatProvider(
      chatRepository: chatRepository,
      appRepository: appRepository,
      localDataSource: localDataSource,
      defaultSettingsProvider: defaultSettingsProvider,
    );

    test('a project without sessions drafts automatically', () async {
      chatRepository.sessions.clear();
      final provider = build();
      addTearDown(provider.dispose);

      await provider.loadSessions();
      await Future<void>.delayed(Duration.zero);

      // The composer becomes usable without the redundant "New chat" gate.
      expect(provider.isDraftingNewChat, isTrue);
      // And nothing was created remotely just by opening the project.
      expect(provider.currentSession, isNull);
      expect(chatRepository.sessions, isEmpty);
    });

    test('a project with sessions is left alone', () async {
      final provider = build();
      addTearDown(provider.dispose);

      await provider.loadSessions();
      await Future<void>.delayed(Duration.zero);

      expect(provider.sessions, isNotEmpty);
      expect(provider.isDraftingNewChat, isFalse);
    });

    test(
      'an authoritative empty load does not clobber an existing draft',
      () async {
        chatRepository.sessions.clear();
        final provider = build();
        addTearDown(provider.dispose);

        await provider.beginNewChatDraft();
        expect(provider.isDraftingNewChat, isTrue);

        await provider.loadSessions();
        await Future<void>.delayed(Duration.zero);

        expect(provider.isDraftingNewChat, isTrue);
        expect(provider.currentSession, isNull);
      },
    );

    test(
      'keeps the draft visible while creating the first real session',
      () async {
        chatRepository.sessions.clear();
        final provider = build();
        addTearDown(provider.dispose);

        await provider.loadSessions();
        final createGate = Completer<void>();
        chatRepository.createSessionDelay = () => createGate.future;

        final creation = provider.createNewSession();
        while (chatRepository.createSessionCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(provider.isDraftingNewChat, isTrue);
        expect(provider.currentSession, isNull);
        createGate.complete();
        await creation;

        expect(provider.isDraftingNewChat, isFalse);
        expect(provider.currentSession, isNotNull);
        expect(provider.sessionTabs, hasLength(1));
        expect(provider.sessionTabs.single.isSelected, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
    );

    test('retains the draft after creation failure for retry', () async {
      chatRepository.sessions.clear();
      final provider = build();
      addTearDown(provider.dispose);

      await provider.loadSessions();
      chatRepository.createSessionFailure = const NetworkFailure(
        'create failed',
      );

      await provider.createNewSession();

      expect(provider.isDraftingNewChat, isTrue);
      expect(provider.currentSession, isNull);
      expect(provider.sessionTabs, isEmpty);
    });

    test(
      'does not send the draft into a session selected while creating lazily',
      () async {
        final provider = build();
        addTearDown(provider.dispose);

        await provider.loadSessions();
        final existingSession = provider.sessions.single;
        await provider.beginNewChatDraft();

        final createGate = Completer<void>();
        chatRepository.createSessionDelay = () => createGate.future;
        final sending = provider.sendMessage('draft text');
        while (chatRepository.createSessionCallCount == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        await provider.selectSession(existingSession);
        createGate.complete();

        expect(await sending, isFalse);
        expect(chatRepository.lastSendSessionId, isNull);
        expect(provider.currentSession?.id, existingSession.id);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
    );

    test(
      'does not overwrite a selected session while create persistence is pending',
      () async {
        final provider = build();
        addTearDown(provider.dispose);

        await provider.loadSessions();
        final existingSession = provider.sessions.single;
        await provider.beginNewChatDraft();

        final saveStarted = Completer<void>();
        final saveGate = Completer<void>();
        var gateCreateSave = true;
        localDataSource.saveCurrentSessionIdDelay = (sessionId) {
          if (gateCreateSave && sessionId.isNotEmpty) {
            gateCreateSave = false;
            saveStarted.complete();
            return saveGate.future;
          }
          return Future<void>.value();
        };

        final creation = provider.createNewSession();
        await saveStarted.future;
        final selection = provider.selectSession(existingSession);
        await Future<void>.delayed(Duration.zero);
        saveGate.complete();
        await selection;

        await creation;
        expect(provider.currentSession?.id, existingSession.id);
        expect(
          await localDataSource.getCurrentSessionId(
            serverId: provider.activeServerId,
            scopeId: provider.projectProvider.currentScopeId,
          ),
          existingSession.id,
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
    );
  });
}
