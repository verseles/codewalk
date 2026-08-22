@Tags(<String>['slow'])
library;

import 'package:codewalk/domain/entities/chat_composer_draft.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

void main() {
  group('ChatProvider - composer drafts', () {
    test(
      'restores persisted draft on cold start without project hydration',
      () async {
        final localDataSource = InMemoryAppLocalDataSource()
          ..activeServerId = 'srv_test';
        final warmFixtures = await buildDefaultTestFixtures(
          localDataSourceOverride: localDataSource,
        );
        addTearDown(warmFixtures.defaultSettingsProvider.dispose);

        // Warm phase: the project context is hydrated, like a live session
        // where the user typed the draft.
        final warmProjectProvider = ProjectProvider(
          projectRepository: FakeProjectRepository(),
          localDataSource: localDataSource,
        );
        await warmProjectProvider.initializeProject();
        expect(warmProjectProvider.currentDirectory, isNotNull);
        final providerA = buildChatProvider(
          chatRepository: warmFixtures.chatRepository,
          appRepository: warmFixtures.appRepository,
          localDataSource: localDataSource,
          defaultSettingsProvider: warmFixtures.defaultSettingsProvider,
          projectProvider: warmProjectProvider,
        );
        addTearDown(providerA.dispose);

        await providerA.persistComposerDraftForSession(
          sessionId: 'ses_1',
          draft: const ChatComposerDraft(text: 'cold draft'),
        );
        expect(
          await localDataSource.getSessionComposerDraftJson(
            sessionId: 'ses_1',
            serverId: 'srv_test',
          ),
          isNotNull,
        );

        // Cold phase: same storage, but the project context was never
        // hydrated yet (server unreachable / still loading), which must not
        // hide the draft.
        final coldFixtures = await buildDefaultTestFixtures(
          localDataSourceOverride: localDataSource,
        );
        addTearDown(coldFixtures.defaultSettingsProvider.dispose);
        final providerB = buildChatProvider(
          chatRepository: coldFixtures.chatRepository,
          appRepository: coldFixtures.appRepository,
          localDataSource: localDataSource,
          defaultSettingsProvider: coldFixtures.defaultSettingsProvider,
        );
        addTearDown(providerB.dispose);

        await providerB.loadSessions();
        // Drain the auto-select insight chain so it cannot outlive the
        // provider disposal registered in the tear-downs.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await providerB.selectSession(
          providerB.sessions.where((session) => session.id == 'ses_1').first,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(
          providerB.debugPendingHistoryComposerDraft?.text,
          'cold draft',
        );
      },
    );

    test('clears the stored draft when it is sent or erased', () async {
      final fixtures = await buildDefaultTestFixtures();
      addTearDown(fixtures.defaultSettingsProvider.dispose);
      final provider = buildChatProvider(
        chatRepository: fixtures.chatRepository,
        appRepository: fixtures.appRepository,
        localDataSource: fixtures.localDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
      );
      addTearDown(provider.dispose);

      Future<String?> storedJson() => fixtures.localDataSource
          .getSessionComposerDraftJson(sessionId: 'ses_1', serverId: 'srv_test');

      await provider.persistComposerDraftForSession(
        sessionId: 'ses_1',
        draft: const ChatComposerDraft(text: 'to be cleared'),
      );
      expect(await storedJson(), isNotNull);

      await provider.persistComposerDraftForSession(
        sessionId: 'ses_1',
        draft: null,
      );
      expect(await storedJson(), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('persists under an explicitly provided server id', () async {
      final fixtures = await buildDefaultTestFixtures();
      addTearDown(fixtures.defaultSettingsProvider.dispose);
      final provider = buildChatProvider(
        chatRepository: fixtures.chatRepository,
        appRepository: fixtures.appRepository,
        localDataSource: fixtures.localDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
      );
      addTearDown(provider.dispose);

      // The page captures the active server at staging time so a server
      // switch during the debounce window cannot re-key the draft.
      await provider.persistComposerDraftForSession(
        sessionId: 'ses_1',
        draft: const ChatComposerDraft(text: 'server pinned'),
        serverId: 'srv_other',
      );

      expect(
        await fixtures.localDataSource.getSessionComposerDraftJson(
          sessionId: 'ses_1',
          serverId: 'srv_other',
        ),
        isNotNull,
      );
      expect(
        await fixtures.localDataSource.getSessionComposerDraftJson(
          sessionId: 'ses_1',
          serverId: 'srv_test',
        ),
        isNull,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
