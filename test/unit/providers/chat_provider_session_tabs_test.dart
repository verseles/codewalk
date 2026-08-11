import 'dart:async';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/persisted_session_tabs_state.dart';
import 'package:codewalk/domain/entities/session_tab_icon_overrides.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/services/session_tab_icon_override_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'chat_provider_test_support.dart';

const int _hourMs = 60 * 60 * 1000;

SessionTabIdentity _identity(
  String sessionId, {
  String serverId = 'server-a',
  String directory = '/work/project',
}) {
  return SessionTabIdentity(
    serverId: serverId,
    directory: directory,
    sessionId: sessionId,
  );
}

SessionTabCandidate _candidate(
  String sessionId, {
  int updatedAtMs = 0,
  String serverId = 'server-a',
  String directory = '/work/project',
  SessionStatusType status = SessionStatusType.idle,
  bool isSelected = false,
  bool isArchived = false,
  bool isRoot = true,
  List<String> pendingQuestionIds = const <String>[],
  String? completionToken,
  String? errorToken,
}) {
  return SessionTabCandidate(
    identity: _identity(sessionId, serverId: serverId, directory: directory),
    title: 'Title $sessionId',
    serverUpdatedAtMs: updatedAtMs,
    status: status,
    isSelected: isSelected,
    isArchived: isArchived,
    isRoot: isRoot,
    pendingQuestionIds: pendingQuestionIds,
    completionToken: completionToken,
    errorToken: errorToken,
  );
}

PersistedSessionTab _persisted(
  String sessionId, {
  int lastOpenedAtMs = 0,
  int serverUpdatedAtMs = 0,
  String directory = '/work/project',
  String? title,
  List<String> seenQuestionIds = const <String>[],
  String? seenCompletionToken,
  String? seenErrorToken,
}) {
  return PersistedSessionTab(
    directory: directory,
    sessionId: sessionId,
    title: title ?? 'Persisted $sessionId',
    lastOpenedAtMs: lastOpenedAtMs,
    serverUpdatedAtMs: serverUpdatedAtMs,
    seenQuestionIds: seenQuestionIds,
    seenCompletionToken: seenCompletionToken,
    seenErrorToken: seenErrorToken,
  );
}

void main() {
  group('SessionTabReconciler', () {
    test('pinned identities bypass recency and local tombstones', () {
      const nowMs = 10 * _hourMs;
      final pinnedIdentity = _identity('pinned-old');
      final result = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: const PersistedSessionTabsState(
          closed: <PersistedClosedSessionTab>[
            PersistedClosedSessionTab(
              directory: '/work/project',
              sessionId: 'pinned-old',
              closedAtMs: 9 * _hourMs,
              observedServerUpdatedAtMs: _hourMs,
            ),
          ],
        ),
        candidates: <SessionTabCandidate>[
          _candidate('pinned-old', updatedAtMs: _hourMs),
        ],
        pinnedIdentities: <SessionTabIdentity>{pinnedIdentity},
        nowMs: nowMs,
      );

      expect(result.tabs, hasLength(1));
      expect(result.tabs.single.identity, pinnedIdentity);
      expect(result.tabs.single.isPinned, isTrue);
      expect(result.persistedState.closed, isEmpty);
      expect(
        result.persistedState.open.single.toJson(),
        isNot(contains('isPinned')),
      );
    });

    test('pins keep eligibility rules and stable-partition tab order', () {
      const nowMs = 10 * _hourMs;
      final result = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            _persisted('regular-a', lastOpenedAtMs: nowMs),
            _persisted('pinned-b', lastOpenedAtMs: nowMs),
            _persisted('regular-c', lastOpenedAtMs: nowMs),
          ],
        ),
        candidates: <SessionTabCandidate>[
          _candidate('regular-a', updatedAtMs: nowMs),
          _candidate('pinned-b', updatedAtMs: nowMs),
          _candidate('regular-c', updatedAtMs: nowMs),
          _candidate('pinned-child', updatedAtMs: 1, isRoot: false),
          _candidate('pinned-archived', updatedAtMs: 1, isArchived: true),
        ],
        pinnedIdentities: <SessionTabIdentity>{
          _identity('pinned-b'),
          _identity('pinned-child'),
          _identity('pinned-archived'),
        },
        nowMs: nowMs,
      );

      expect(result.tabs.map((tab) => tab.identity.sessionId), <String>[
        'pinned-b',
        'regular-a',
        'regular-c',
      ]);
      expect(result.tabs.map((tab) => tab.isPinned), <bool>[
        true,
        false,
        false,
      ]);
    });

    test('uses the exact cutoff and retains selected or busy roots', () {
      const nowMs = 10 * _hourMs;
      const cutoffMs = nowMs - 3 * _hourMs;

      final result = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: const PersistedSessionTabsState(),
        candidates: <SessionTabCandidate>[
          _candidate('too-old', updatedAtMs: cutoffMs - 1),
          _candidate('at-cutoff', updatedAtMs: cutoffMs),
          _candidate('busy', updatedAtMs: 1, status: SessionStatusType.busy),
          _candidate('selected', updatedAtMs: 2, isSelected: true),
          _candidate('child', updatedAtMs: nowMs, isRoot: false),
          _candidate('archived', updatedAtMs: nowMs, isArchived: true),
          _candidate('other-server', updatedAtMs: nowMs, serverId: 'server-b'),
        ],
        nowMs: nowMs,
      );

      expect(result.tabs.map((tab) => tab.identity.sessionId), <String>[
        'busy',
        'selected',
        'at-cutoff',
      ]);
    });

    test(
      'bootstraps only the newest old session for a newly opened project',
      () {
        const nowMs = 10 * _hourMs;
        const reopenedDirectory = '/work/reopened';
        final result = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              _persisted(
                'existing',
                directory: '/work/existing',
                lastOpenedAtMs: nowMs,
              ),
              _persisted(
                'locally-newest',
                directory: reopenedDirectory,
                lastOpenedAtMs: 4 * _hourMs,
                serverUpdatedAtMs: 2 * _hourMs,
              ),
            ],
            closed: const <PersistedClosedSessionTab>[
              PersistedClosedSessionTab(
                directory: reopenedDirectory,
                sessionId: 'suppressed-newest',
                closedAtMs: 9 * _hourMs,
                observedServerUpdatedAtMs: 6 * _hourMs,
              ),
            ],
          ),
          candidates: <SessionTabCandidate>[
            _candidate(
              'server-older',
              directory: reopenedDirectory,
              updatedAtMs: 3 * _hourMs,
            ),
            _candidate(
              'locally-newest',
              directory: reopenedDirectory,
              updatedAtMs: 2 * _hourMs,
            ),
            _candidate(
              'suppressed-newest',
              directory: reopenedDirectory,
              updatedAtMs: 6 * _hourMs,
            ),
          ],
          nowMs: nowMs,
          bootstrapDirectory: reopenedDirectory,
        );

        expect(result.tabs.map((tab) => tab.identity.sessionId), <String>[
          'existing',
          'locally-newest',
        ]);
        expect(result.persistedState.closed, hasLength(1));
      },
    );

    test('bootstraps all recent sessions without adding an old fallback', () {
      const nowMs = 10 * _hourMs;
      const reopenedDirectory = '/work/reopened';
      const cutoffMs = nowMs - 3 * _hourMs;
      final result = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: const PersistedSessionTabsState(),
        candidates: <SessionTabCandidate>[
          _candidate(
            'old-latest',
            directory: reopenedDirectory,
            updatedAtMs: cutoffMs - 1,
          ),
          _candidate(
            'recent-a',
            directory: reopenedDirectory,
            updatedAtMs: cutoffMs,
          ),
          _candidate(
            'recent-b',
            directory: reopenedDirectory,
            updatedAtMs: nowMs,
          ),
        ],
        nowMs: nowMs,
        bootstrapDirectory: reopenedDirectory,
      );

      expect(result.tabs.map((tab) => tab.identity.sessionId), <String>[
        'recent-a',
        'recent-b',
      ]);
    });

    test('deduplicates while preserving existing order and append order', () {
      const nowMs = 10 * _hourMs;
      final result = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            _persisted('a', lastOpenedAtMs: _hourMs, title: 'Old A'),
            _persisted('b', lastOpenedAtMs: 8 * _hourMs),
            _persisted('a', lastOpenedAtMs: 9 * _hourMs, title: 'New A'),
          ],
        ),
        candidates: <SessionTabCandidate>[
          _candidate('c', updatedAtMs: 8 * _hourMs),
          _candidate('c', updatedAtMs: 8 * _hourMs),
          _candidate('d', updatedAtMs: 9 * _hourMs),
        ],
        nowMs: nowMs,
      );

      expect(result.tabs.map((tab) => tab.identity.sessionId), <String>[
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(result.tabs.first.lastOpenedAtMs, 9 * _hourMs);
      expect(result.persistedState.open, hasLength(4));
    });

    test(
      'closed tabs reopen only explicitly or after a newer server update',
      () {
        const closedAtMs = 8 * _hourMs;
        const observedAtMs = 7 * _hourMs;
        final identity = _identity('a');
        final closed = SessionTabReconciler.close(
          state: PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              _persisted('a', serverUpdatedAtMs: observedAtMs),
            ],
          ),
          identity: identity,
          nowMs: closedAtMs,
        );

        final suppressed = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: closed,
          candidates: <SessionTabCandidate>[
            _candidate(
              'a',
              updatedAtMs: observedAtMs,
              status: SessionStatusType.busy,
              isSelected: true,
            ),
          ],
          nowMs: closedAtMs,
        );
        expect(suppressed.tabs, isEmpty);
        expect(suppressed.persistedState.closed, hasLength(1));
        expect(
          suppressed.persistedState.closed.single.observedServerUpdatedAtMs,
          observedAtMs,
        );

        final remotelyUpdated = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: closed,
          candidates: <SessionTabCandidate>[
            _candidate('a', updatedAtMs: observedAtMs + 1),
          ],
          nowMs: closedAtMs,
        );
        expect(remotelyUpdated.tabs.single.identity, identity);
        expect(remotelyUpdated.persistedState.closed, isEmpty);

        final explicitlyOpened = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: closed,
          candidates: <SessionTabCandidate>[
            _candidate('a', updatedAtMs: observedAtMs),
          ],
          nowMs: closedAtMs,
          explicitlyOpened: identity,
        );
        expect(explicitlyOpened.tabs.single.lastOpenedAtMs, closedAtMs);
        expect(explicitlyOpened.persistedState.closed, isEmpty);
      },
    );

    test(
      'retains old tombstones until an authoritative archive clears them',
      () {
        const nowMs = 12 * _hourMs;
        final result = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: const PersistedSessionTabsState(
            closed: <PersistedClosedSessionTab>[
              PersistedClosedSessionTab(
                directory: '/work/project',
                sessionId: 'a',
                closedAtMs: 8 * _hourMs,
                observedServerUpdatedAtMs: 7 * _hourMs,
              ),
            ],
          ),
          candidates: <SessionTabCandidate>[
            _candidate('a', updatedAtMs: 7 * _hourMs),
          ],
          nowMs: nowMs,
        );

        expect(result.tabs, isEmpty);
        expect(result.persistedState.closed, hasLength(1));

        final archived = SessionTabReconciler.reconcile(
          serverId: 'server-a',
          persistedState: result.persistedState,
          candidates: <SessionTabCandidate>[
            _candidate('a', updatedAtMs: 7 * _hourMs, isArchived: true),
          ],
          nowMs: nowMs,
        );
        expect(archived.tabs, isEmpty);
        expect(archived.persistedState.closed, isEmpty);
      },
    );

    test('derives unseen attention from deterministic persisted markers', () {
      const nowMs = 10 * _hourMs;
      final seen = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            _persisted(
              'a',
              lastOpenedAtMs: nowMs,
              seenQuestionIds: const <String>['question-1'],
              seenCompletionToken: 'completion-1',
              seenErrorToken: 'error-1',
            ),
          ],
        ),
        candidates: <SessionTabCandidate>[
          _candidate(
            'a',
            updatedAtMs: nowMs,
            pendingQuestionIds: const <String>['question-1'],
            completionToken: 'completion-1',
            errorToken: 'error-1',
          ),
        ],
        nowMs: nowMs,
      );
      expect(seen.tabs.single.requiresAttention, isFalse);

      final unseen = SessionTabReconciler.reconcile(
        serverId: 'server-a',
        persistedState: seen.persistedState,
        candidates: <SessionTabCandidate>[
          _candidate(
            'a',
            updatedAtMs: nowMs,
            pendingQuestionIds: const <String>['question-1', 'question-2'],
            completionToken: 'completion-2',
            errorToken: 'error-2',
          ),
        ],
        nowMs: nowMs,
      );

      expect(unseen.tabs.single.hasUnseenQuestion, isTrue);
      expect(unseen.tabs.single.hasUnseenCompletion, isTrue);
      expect(unseen.tabs.single.hasUnseenError, isTrue);
      expect(unseen.tabs.single.attentionKind, SessionAttentionKind.error);
    });
  });

  group('ChatProvider session tabs', () {
    late ChatProviderTestFixtures fixtures;
    late ChatProvider provider;
    final now = DateTime.utc(2026, 7, 30, 4);

    setUp(() async {
      fixtures = await buildDefaultTestFixtures();
      fixtures.chatRepository.sessions
        ..clear()
        ..add(
          ChatSession(
            id: 'session-live',
            workspaceId: 'default',
            directory: '/work/project',
            time: now.subtract(const Duration(hours: 4)),
            title: 'Live session',
          ),
        );
      provider = buildChatProvider(
        chatRepository: fixtures.chatRepository,
        appRepository: fixtures.appRepository,
        localDataSource: fixtures.localDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
        sessionTabsNow: () => now,
      );
      addTearDown(provider.dispose);
    });

    test(
      'successful automatic selection opens and persists the visible tab',
      () async {
        await provider.loadSessions();
        await provider.debugWaitForSessionTabPersistence();

        expect(provider.sessionTabs, hasLength(1));
        expect(provider.sessionTabs.single.identity.sessionId, 'session-live');
        expect(
          provider.sessionTabs.single.lastOpenedAtMs,
          now.millisecondsSinceEpoch,
        );
        final raw = await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        );
        final persisted = PersistedSessionTabsState.decode(raw);
        expect(persisted.open.single.sessionId, 'session-live');
        expect(
          persisted.open.single.lastOpenedAtMs,
          now.millisecondsSinceEpoch,
        );
      },
    );

    test('closing a tab persists its local tombstone', () async {
      await provider.loadSessions();
      final identity = provider.sessionTabs.single.identity;

      provider.closeSessionTab(identity);
      await provider.debugWaitForSessionTabPersistence();
      await provider.loadSessionTabs();

      expect(provider.sessionTabs, isEmpty);
      final persisted = PersistedSessionTabsState.decode(
        await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        ),
      );
      expect(persisted.open, isEmpty);
      expect(persisted.closed, hasLength(1));
      expect(persisted.closed.single.sessionId, identity.sessionId);
      expect(persisted.closed.single.directory, identity.directory);
    });

    test(
      'tab icon persists separately and survives close and reload',
      () async {
        await provider.loadSessions();
        final tab = provider.sessionTabs.single;

        expect(
          await provider.setSessionTabIconPreset(tab.identity, 'terminal'),
          isTrue,
        );
        provider.closeSessionTab(tab.identity);
        await provider.debugWaitForSessionTabPersistence();

        final iconState = SessionTabIconOverridesState.decode(
          await fixtures.localDataSource.getSessionTabIconOverridesJson(
            serverId: 'srv_test',
          ),
        );
        expect(iconState.entries.single.presetId, 'terminal');
        final tabStateRaw = await fixtures.localDataSource
            .getSessionTabsStateJson(serverId: 'srv_test');
        expect(tabStateRaw, isNot(contains('iconPreset')));

        final reloaded = buildChatProvider(
          chatRepository: fixtures.chatRepository,
          appRepository: fixtures.appRepository,
          localDataSource: fixtures.localDataSource,
          defaultSettingsProvider: fixtures.defaultSettingsProvider,
          sessionTabsNow: () => now,
        );
        addTearDown(reloaded.dispose);
        await reloaded.loadSessions();

        expect(reloaded.sessionTabs.single.iconPresetId, 'terminal');
      },
    );

    test(
      'tab bootstrap observes an icon mutation during its tab read',
      () async {
        final delayedLocalDataSource = _DelayedIconBootstrapLocalDataSource()
          ..activeServerId = 'srv_test';
        final store = SessionTabIconOverrideStore(
          localDataSource: delayedLocalDataSource,
        );
        await delayedLocalDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/project',
                sessionId: 'session-live',
                title: 'Live session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );
        await store.setPreset(
          serverId: 'srv_test',
          directory: '/work/project',
          sessionId: 'session-live',
          presetId: 'code',
          updatedAtMs: 1,
        );
        final delayedProvider = buildChatProvider(
          chatRepository: fixtures.chatRepository,
          appRepository: fixtures.appRepository,
          localDataSource: delayedLocalDataSource,
          defaultSettingsProvider: fixtures.defaultSettingsProvider,
          sessionTabsNow: () => now,
          sessionTabIconOverrideStore: store,
        );
        addTearDown(delayedProvider.dispose);

        final load = delayedProvider.loadSessionTabs();
        await delayedLocalDataSource.tabReadStarted.future;
        await store.setPreset(
          serverId: 'srv_test',
          directory: '/work/project',
          sessionId: 'session-live',
          presetId: 'bug',
          updatedAtMs: 2,
        );
        delayedLocalDataSource.releaseTabRead.complete();
        await load;

        expect(delayedProvider.sessionTabs.single.iconPresetId, 'bug');
      },
    );

    test('reset removes the tab icon override entry', () async {
      await provider.loadSessions();
      final identity = provider.sessionTabs.single.identity;
      await provider.setSessionTabIconPreset(identity, 'bug');

      expect(await provider.setSessionTabIconPreset(identity, ' '), isTrue);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.sessionTabs.single.iconPresetId, isNull);
      expect(
        SessionTabIconOverridesState.decode(
          await fixtures.localDataSource.getSessionTabIconOverridesJson(
            serverId: 'srv_test',
          ),
        ).entries,
        isEmpty,
      );
    });

    test(
      'restoring a closed tab removes its tombstone and keeps order',
      () async {
        await provider.loadSessions();
        final tab = provider.sessionTabs.single;

        provider.closeSessionTab(tab.identity);
        final restored = provider.restoreClosedSessionTab(tab, index: 0);
        await provider.debugWaitForSessionTabPersistence();

        expect(restored, isTrue);
        expect(provider.sessionTabs.single.identity, tab.identity);
        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'srv_test',
          ),
        );
        expect(persisted.open.single.sessionId, tab.identity.sessionId);
        expect(persisted.closed, isEmpty);
        expect(provider.restoreClosedSessionTab(tab, index: 0), isTrue);
      },
    );

    test('sidebar pin reopens a tombstoned tab without navigation', () async {
      await provider.loadSessions();
      final session = provider.sessions.single;
      final identity = provider.sessionTabs.single.identity;
      provider.closeSessionTab(identity);
      expect(provider.sessionTabs, isEmpty);

      await provider.toggleSessionPinned(session);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.currentSession?.id, session.id);
      expect(provider.isSessionPinned(session.id), isTrue);
      expect(provider.sessionTabs.single.identity, identity);
      expect(provider.sessionTabs.single.isPinned, isTrue);
      final persisted = PersistedSessionTabsState.decode(
        await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        ),
      );
      expect(persisted.closed, isEmpty);
    });

    test(
      'live active pins supersede a stale active-context snapshot',
      () async {
        await provider.loadSessions();
        final session = provider.sessions.single;
        await provider.toggleSessionPinned(session);
        provider.debugStoreCurrentContextSnapshot();

        await provider.toggleSessionPinned(session);
        await provider.debugWaitForSessionTabPersistence();

        expect(provider.isSessionPinned(session.id), isFalse);
        expect(
          provider.sessionTabs.any(
            (tab) => tab.identity.sessionId == session.id && tab.isPinned,
          ),
          isFalse,
        );
      },
    );

    test('closing and restoring a pinned tab updates the shared pin', () async {
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["other-scope-session"]',
        serverId: 'srv_test',
        scopeId: '/work/project',
      );
      await provider.loadSessions();
      final session = provider.sessions.single;
      await provider.toggleSessionPinned(session);
      await provider.setSessionTabIconPreset(
        provider.sessionTabs.single.identity,
        'research',
      );
      final pinnedTab = provider.sessionTabs.single;
      expect(pinnedTab.isPinned, isTrue);

      provider.closeSessionTab(pinnedTab.identity);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isFalse);
      expect(provider.sessionTabs, isEmpty);
      expect(
        SessionTabIconOverridesState.decode(
          await fixtures.localDataSource.getSessionTabIconOverridesJson(
            serverId: 'srv_test',
          ),
        ).entries.single.presetId,
        'research',
      );

      expect(provider.restoreClosedSessionTab(pinnedTab, index: 0), isTrue);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isTrue);
      expect(provider.sessionTabs.single.isPinned, isTrue);
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        contains('session-live'),
      );
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: '/work/project',
        ),
        '["other-scope-session"]',
      );
    });

    test(
      'cold scoped pin retains an old persisted tab after restart',
      () async {
        await fixtures.localDataSource.savePinnedSessionsJson(
          '["session-cold"]',
          serverId: 'srv_test',
          scopeId: '/work/cold',
        );
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/cold',
                sessionId: 'session-cold',
                title: 'Cold pinned session',
                lastOpenedAtMs: now
                    .subtract(const Duration(hours: 12))
                    .millisecondsSinceEpoch,
                serverUpdatedAtMs: now
                    .subtract(const Duration(hours: 12))
                    .millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );

        await provider.loadSessionTabs();

        expect(provider.sessionTabs.single.identity.sessionId, 'session-cold');
        expect(provider.sessionTabs.single.isPinned, isTrue);
      },
    );

    test('active cold pin survives tab load before preferences', () async {
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["session-active-cold"]',
        serverId: 'srv_test',
        scopeId: 'default',
      );
      await fixtures.localDataSource.saveSessionTabsStateJson(
        PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            PersistedSessionTab(
              directory: '/work/active-cold',
              sessionId: 'session-active-cold',
              title: 'Active cold pin',
              lastOpenedAtMs: now
                  .subtract(const Duration(hours: 12))
                  .millisecondsSinceEpoch,
              serverUpdatedAtMs: now
                  .subtract(const Duration(hours: 12))
                  .millisecondsSinceEpoch,
            ),
          ],
        ).encode(),
        serverId: 'srv_test',
      );

      await provider.loadSessionTabs();
      await provider.debugWaitForSessionTabPersistence();

      expect(
        provider.sessionTabs.single.identity.sessionId,
        'session-active-cold',
      );
      expect(provider.sessionTabs.single.isPinned, isTrue);
      final persisted = PersistedSessionTabsState.decode(
        await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        ),
      );
      expect(persisted.open.single.sessionId, 'session-active-cold');

      final tab = provider.sessionTabs.single;
      provider.closeSessionTab(tab.identity);
      await provider.debugWaitForSessionTabPersistence();
      expect(provider.sessionTabs, isEmpty);
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        '[]',
      );
    });

    test(
      'active exact pin read recovers when scoped enumeration fails',
      () async {
        final fallbackLocalDataSource = _FailingPinnedScopeScanLocalDataSource()
          ..activeServerId = 'srv_test';
        await fallbackLocalDataSource.savePinnedSessionsJson(
          '["session-fallback"]',
          serverId: 'srv_test',
          scopeId: 'default',
        );
        await fallbackLocalDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/fallback',
                sessionId: 'session-fallback',
                title: 'Fallback pin',
                lastOpenedAtMs: _hourMs,
                serverUpdatedAtMs: _hourMs,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );
        final fallbackProvider = buildChatProvider(
          chatRepository: fixtures.chatRepository,
          appRepository: fixtures.appRepository,
          localDataSource: fallbackLocalDataSource,
          defaultSettingsProvider: fixtures.defaultSettingsProvider,
          sessionTabsNow: () => now,
        );
        addTearDown(fallbackProvider.dispose);

        await fallbackProvider.loadSessionTabs();

        expect(fallbackProvider.sessionTabs.single.isPinned, isTrue);
        expect(
          fallbackProvider.sessionTabs.single.identity.sessionId,
          'session-fallback',
        );
      },
    );

    test('pin mutation wins over a delayed stale preference read', () async {
      final delayedLocalDataSource = _DelayedPinnedPreferenceLocalDataSource()
        ..activeServerId = 'srv_test';
      await delayedLocalDataSource.savePinnedSessionsJson(
        '["session-live"]',
        serverId: 'srv_test',
        scopeId: 'default',
      );
      await delayedLocalDataSource.saveSessionTabsStateJson(
        PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            PersistedSessionTab(
              directory: '/work/project',
              sessionId: 'session-live',
              title: 'Live session',
              lastOpenedAtMs: _hourMs,
              serverUpdatedAtMs: _hourMs,
            ),
          ],
        ).encode(),
        serverId: 'srv_test',
      );
      final delayedProvider = buildChatProvider(
        chatRepository: fixtures.chatRepository,
        appRepository: fixtures.appRepository,
        localDataSource: delayedLocalDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
        sessionTabsNow: () => now,
      );
      addTearDown(delayedProvider.dispose);
      await delayedProvider.loadSessionTabs();
      expect(delayedProvider.sessionTabs.single.isPinned, isTrue);

      final initialization = delayedProvider.initializeProviders();
      await delayedLocalDataSource.pinReadStarted.future;
      await delayedProvider.toggleSessionPinned(
        fixtures.chatRepository.sessions.single,
      );
      delayedLocalDataSource.releasePinRead.complete();
      await initialization;
      await delayedProvider.debugWaitForSessionTabPersistence();

      expect(delayedProvider.isSessionPinned('session-live'), isFalse);
      expect(delayedProvider.sessionTabs.any((tab) => tab.isPinned), isFalse);
      expect(
        await delayedLocalDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        '[]',
      );
    });

    test('equivalent cold scope spellings union their pin sets', () async {
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["session-a"]',
        serverId: 'srv_test',
        scopeId: '/work/cold',
      );
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["session-b"]',
        serverId: 'srv_test',
        scopeId: '/work/cold/',
      );
      await fixtures.localDataSource.saveSessionTabsStateJson(
        PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            _persisted(
              'session-a',
              directory: '/work/cold',
              lastOpenedAtMs: _hourMs,
            ),
            _persisted(
              'session-b',
              directory: '/work/cold',
              lastOpenedAtMs: _hourMs,
            ),
          ],
        ).encode(),
        serverId: 'srv_test',
      );

      await provider.loadSessionTabs();

      expect(
        provider.sessionTabs.map((tab) => tab.identity.sessionId).toSet(),
        <String>{'session-a', 'session-b'},
      );
      expect(provider.sessionTabs.every((tab) => tab.isPinned), isTrue);
    });

    test(
      'active equivalent scopes stay unioned after preference load',
      () async {
        await fixtures.localDataSource.savePinnedSessionsJson(
          '["session-a"]',
          serverId: 'srv_test',
          scopeId: 'default',
        );
        await fixtures.localDataSource.savePinnedSessionsJson(
          '["session-b"]',
          serverId: 'srv_test',
          scopeId: 'default/',
        );
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              _persisted(
                'session-a',
                directory: '/work/a',
                lastOpenedAtMs: _hourMs,
              ),
              _persisted(
                'session-b',
                directory: '/work/b',
                lastOpenedAtMs: _hourMs,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );

        await provider.loadSessionTabs();
        await provider.initializeProviders();

        expect(provider.isSessionPinned('session-a'), isTrue);
        expect(provider.isSessionPinned('session-b'), isTrue);
        expect(provider.sessionTabs.every((tab) => tab.isPinned), isTrue);
      },
    );

    test('closing a duplicate legacy pin clears every owning scope', () async {
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["session-live"]',
        serverId: 'srv_test',
        scopeId: 'default',
      );
      await fixtures.localDataSource.savePinnedSessionsJson(
        '["session-live"]',
        serverId: 'srv_test',
        scopeId: '/work/project',
      );
      await provider.initializeProviders();
      await provider.loadSessions();
      final tab = provider.sessionTabs.single;
      expect(tab.pinScopeIds, <String>{'default', '/work/project'});

      provider.closeSessionTab(tab.identity);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.sessionTabs, isEmpty);
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        '[]',
      );
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: '/work/project',
        ),
        '[]',
      );

      expect(provider.restoreClosedSessionTab(tab, index: 0), isTrue);
      await provider.debugWaitForSessionTabPersistence();
      expect(provider.sessionTabs.single.pinScopeIds, <String>{'default'});
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        '["session-live"]',
      );
      expect(
        await fixtures.localDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: '/work/project',
        ),
        '[]',
      );
    });

    test('preference save captures a concurrent pin at write time', () async {
      final delayedLocalDataSource = _DelayedPreferenceSaveLocalDataSource()
        ..activeServerId = 'srv_test';
      final delayedProvider = buildChatProvider(
        chatRepository: fixtures.chatRepository,
        appRepository: fixtures.appRepository,
        localDataSource: delayedLocalDataSource,
        defaultSettingsProvider: fixtures.defaultSettingsProvider,
        sessionTabsNow: () => now,
      );
      addTearDown(delayedProvider.dispose);
      await delayedProvider.loadSessions();
      final session = delayedProvider.sessions.single;

      final preferenceWrite = delayedProvider.toggleModelFavorite(
        providerId: 'provider-a',
        modelId: 'model-a',
      );
      await delayedLocalDataSource.recentWriteStarted.future;
      await delayedProvider.toggleSessionPinned(session);
      delayedLocalDataSource.releaseRecentWrite.complete();
      await preferenceWrite;
      await delayedProvider.debugWaitForSessionTabPersistence();

      expect(
        await delayedLocalDataSource.getPinnedSessionsJson(
          serverId: 'srv_test',
          scopeId: 'default',
        ),
        contains('session-live'),
      );
    });

    test('successful archive clears both the tab and shared pin', () async {
      await provider.loadSessions();
      final session = provider.sessions.single;
      await provider.toggleSessionPinned(session);

      expect(await provider.setSessionArchived(session, true), isTrue);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isFalse);
      expect(provider.sessionTabs, isEmpty);
    });

    test('failed archive preserves both the tab and shared pin', () async {
      await provider.loadSessions();
      final session = provider.sessions.single;
      await provider.toggleSessionPinned(session);
      fixtures.chatRepository.updateSessionFailure = const ServerFailure(
        'archive failed',
      );

      expect(await provider.setSessionArchived(session, true), isFalse);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isTrue);
      expect(provider.sessionTabs.single.identity.sessionId, session.id);
      expect(provider.sessionTabs.single.isPinned, isTrue);
    });

    test(
      'authoritative absence clears pin mirror, disk, and pinned tab',
      () async {
        await fixtures.localDataSource.savePinnedSessionsJson(
          '["session-ghost"]',
          serverId: 'srv_test',
          scopeId: 'default',
        );
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/ghost',
                sessionId: 'session-ghost',
                title: 'Ghost session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );

        await provider.initializeProviders();
        await provider.loadSessionTabs();
        expect(provider.sessionTabs.single.isPinned, isTrue);
        await provider.loadSessions();
        await provider.debugWaitForSessionTabPersistence();

        expect(provider.isSessionPinned('session-ghost'), isFalse);
        expect(
          provider.sessionTabs.any(
            (tab) => tab.identity.sessionId == 'session-ghost',
          ),
          isFalse,
        );
        expect(
          await fixtures.localDataSource.getPinnedSessionsJson(
            serverId: 'srv_test',
            scopeId: 'default',
          ),
          '[]',
        );
      },
    );

    test('failed delete preserves both the tab and shared pin', () async {
      await provider.loadSessions();
      final session = provider.sessions.single;
      await provider.toggleSessionPinned(session);
      fixtures.chatRepository.deleteSessionFailure = const ServerFailure(
        'delete failed',
      );

      await provider.deleteSession(session.id);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isTrue);
      expect(provider.sessionTabs.single.identity.sessionId, session.id);
      expect(provider.sessionTabs.single.isPinned, isTrue);
    });

    test('successful delete clears both the tab and shared pin', () async {
      await provider.loadSessions();
      final session = provider.sessions.single;
      await provider.toggleSessionPinned(session);

      await provider.deleteSession(session.id);
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.isSessionPinned(session.id), isFalse);
      expect(provider.sessionTabs, isEmpty);
    });

    test(
      'restores a persisted tab without a loaded context candidate',
      () async {
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/unloaded',
                projectId: 'project-unloaded',
                sessionId: 'session-unloaded',
                title: 'Unloaded session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );
        await provider.loadSessionTabs();
        final tab = provider.sessionTabs.single;

        provider.closeSessionTab(tab.identity);
        final restored = provider.restoreClosedSessionTab(tab, index: 0);
        await provider.debugWaitForSessionTabPersistence();

        expect(restored, isTrue);
        expect(provider.sessionTabs.single.identity, tab.identity);
        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'srv_test',
          ),
        );
        expect(persisted.open.single.sessionId, tab.identity.sessionId);
        expect(persisted.closed, isEmpty);
      },
    );

    test(
      'question attention persists as seen after selecting its tab',
      () async {
        fixtures.chatRepository.sessions.add(
          ChatSession(
            id: 'session-other',
            workspaceId: 'default',
            directory: '/work/project',
            time: now.subtract(const Duration(hours: 5)),
            title: 'Other session',
          ),
        );
        await provider.loadSessions();
        await provider.selectSession(
          provider.sessions
              .where((session) => session.id == 'session-other')
              .single,
        );
        await provider.selectSession(
          provider.sessions
              .where((session) => session.id == 'session-live')
              .single,
        );
        await provider.initializeProviders();

        fixtures.chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'question-1',
              'sessionID': 'session-other',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Proceed?',
                  'header': 'Confirm',
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
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(
          provider.sessionTabs
              .where((tab) => tab.identity.sessionId == 'session-other')
              .single
              .hasUnseenQuestion,
          isTrue,
        );

        await provider.selectSession(
          provider.sessions
              .where((session) => session.id == 'session-other')
              .single,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await provider.debugWaitForSessionTabPersistence();

        final selectedTab = provider.sessionTabs
            .where((tab) => tab.identity.sessionId == 'session-other')
            .single;
        expect(selectedTab.hasUnseenQuestion, isFalse);
        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'srv_test',
          ),
        );
        expect(
          persisted.open
              .where((tab) => tab.sessionId == 'session-other')
              .single
              .seenQuestionIds,
          contains('question-1'),
        );
      },
    );

    test(
      'background question remains unseen until chat is foregrounded',
      () async {
        await provider.loadSessions();
        await provider.initializeProviders();
        await provider.setForegroundActive(false);

        fixtures.chatRepository.emitEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'id': 'question-background',
              'sessionID': 'session-live',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Review?',
                  'header': 'Review',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'Yes',
                      'description': 'Review now',
                    },
                  ],
                },
              ],
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(provider.sessionTabs.single.hasUnseenQuestion, isTrue);

        await provider.setForegroundActive(true);
        await provider.debugWaitForSessionTabPersistence();

        expect(provider.sessionTabs.single.hasUnseenQuestion, isFalse);
      },
    );

    test(
      'inactive persisted tab receives question attention from global events',
      () async {
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/other',
                projectId: 'project-other',
                sessionId: 'session-other',
                title: 'Other session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );
        await provider.loadSessions();
        await provider.initializeProviders();

        fixtures.chatRepository.emitGlobalEvent(
          const ChatEvent(
            type: 'question.asked',
            properties: <String, dynamic>{
              'directory': '/work/other',
              'id': 'question-inactive',
              'sessionID': 'session-other',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question': 'Proceed?',
                  'header': 'Confirm',
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
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final inactiveTab = provider.sessionTabs
            .where((tab) => tab.identity.sessionId == 'session-other')
            .single;
        expect(inactiveTab.hasUnseenQuestion, isTrue);
        expect(
          inactiveTab.attentionKind,
          SessionAttentionKind.pendingInteraction,
        );

        fixtures.chatRepository.emitGlobalEvent(
          ChatEvent(
            type: 'session.updated',
            properties: <String, dynamic>{
              'directory': '/work/other',
              'info': <String, dynamic>{
                'id': 'session-other',
                'workspaceId': 'project-other',
                'title': 'Renamed other session',
                'time': <String, dynamic>{
                  'created': now.millisecondsSinceEpoch - 1,
                  'updated': now.millisecondsSinceEpoch + 1,
                },
              },
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final renamedTab = provider.sessionTabs
            .where((tab) => tab.identity.sessionId == 'session-other')
            .single;
        expect(renamedTab.title, 'Renamed other session');
        expect(renamedTab.hasUnseenQuestion, isTrue);
      },
    );

    test('confirmed deletion removes tab without a tombstone', () async {
      await provider.loadSessions();
      final identity = provider.sessionTabs.single.identity;
      await provider.setSessionTabIconPreset(identity, 'code');

      await provider.deleteSession('session-live');
      await provider.debugWaitForSessionTabPersistence();

      expect(provider.sessionTabs, isEmpty);
      final persisted = PersistedSessionTabsState.decode(
        await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        ),
      );
      expect(persisted.open, isEmpty);
      expect(persisted.closed, isEmpty);
      expect(
        SessionTabIconOverridesState.decode(
          await fixtures.localDataSource.getSessionTabIconOverridesJson(
            serverId: 'srv_test',
          ),
        ).entries,
        isEmpty,
      );
    });

    test(
      'confirmed deletion keeps a same-id tab from another directory',
      () async {
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/other',
                sessionId: 'session-live',
                title: 'Other same-id session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'srv_test',
        );
        await provider.loadSessions();

        await provider.deleteSession('session-live');
        await provider.debugWaitForSessionTabPersistence();

        expect(provider.sessionTabs, hasLength(1));
        expect(provider.sessionTabs.single.identity.directory, '/work/other');
        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'srv_test',
          ),
        );
        expect(persisted.open, hasLength(1));
        expect(persisted.open.single.directory, '/work/other');
        expect(persisted.closed, isEmpty);
      },
    );

    test('project-history removal clears tabs for that directory', () async {
      await fixtures.localDataSource.saveSessionTabsStateJson(
        PersistedSessionTabsState(
          open: <PersistedSessionTab>[
            PersistedSessionTab(
              directory: '/work/other',
              projectId: 'project-other',
              sessionId: 'session-other',
              title: 'Other session',
              lastOpenedAtMs: now.millisecondsSinceEpoch,
              serverUpdatedAtMs: now.millisecondsSinceEpoch,
            ),
          ],
          closed: <PersistedClosedSessionTab>[
            PersistedClosedSessionTab(
              directory: '/work/other',
              projectId: 'project-other',
              sessionId: 'session-closed',
              closedAtMs: now.millisecondsSinceEpoch,
              observedServerUpdatedAtMs: now.millisecondsSinceEpoch,
            ),
          ],
        ).encode(),
        serverId: 'srv_test',
      );
      await fixtures.localDataSource.saveSessionTabIconOverridesJson(
        SessionTabIconOverridesState(
          entries: <SessionTabIconOverride>[
            SessionTabIconOverride(
              serverId: 'srv_test',
              directory: '/work/other',
              sessionId: 'session-other',
              presetId: 'bug',
              updatedAtMs: 1,
            ),
            SessionTabIconOverride(
              serverId: 'srv_test',
              directory: '/work/project',
              sessionId: 'session-live',
              presetId: 'code',
              updatedAtMs: 2,
            ),
          ],
        ).encode(),
        serverId: 'srv_test',
      );
      await provider.loadSessions();

      await provider.removeSessionTabsForProjectHistory('/work/other/');
      await provider.debugWaitForSessionTabPersistence();

      expect(
        provider.sessionTabs.any(
          (tab) => tab.identity.directory == '/work/other',
        ),
        isFalse,
      );
      final persisted = PersistedSessionTabsState.decode(
        await fixtures.localDataSource.getSessionTabsStateJson(
          serverId: 'srv_test',
        ),
      );
      expect(
        persisted.open.any((tab) => tab.directory == '/work/other'),
        isFalse,
      );
      expect(
        persisted.closed.any((tab) => tab.directory == '/work/other'),
        isFalse,
      );
      final iconState = SessionTabIconOverridesState.decode(
        await fixtures.localDataSource.getSessionTabIconOverridesJson(
          serverId: 'srv_test',
        ),
      );
      expect(iconState.entries, hasLength(1));
      expect(iconState.entries.single.directory, '/work/project');
    });

    test(
      'project-history removal targets the captured inactive server',
      () async {
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/other',
                sessionId: 'session-other',
                title: 'Other session',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'server-a',
        );
        await fixtures.localDataSource.saveSessionTabIconOverridesJson(
          SessionTabIconOverridesState(
            entries: <SessionTabIconOverride>[
              SessionTabIconOverride(
                serverId: 'server-a',
                directory: '/work/other',
                sessionId: 'session-other',
                presetId: 'tools',
                updatedAtMs: 1,
              ),
            ],
          ).encode(),
          serverId: 'server-a',
        );
        await provider.loadSessions();

        await provider.removeSessionTabsForProjectHistory(
          '/work/other',
          serverId: 'server-a',
        );

        expect(provider.activeServerId, 'srv_test');
        expect(provider.sessionTabs, isNotEmpty);
        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'server-a',
          ),
        );
        expect(persisted.open, isEmpty);
        expect(persisted.closed, isEmpty);
        expect(
          SessionTabIconOverridesState.decode(
            await fixtures.localDataSource.getSessionTabIconOverridesJson(
              serverId: 'server-a',
            ),
          ).entries,
          isEmpty,
        );
      },
    );

    test(
      'concurrent inactive-server removals serialize read-modify-write',
      () async {
        await fixtures.localDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              PersistedSessionTab(
                directory: '/work/one',
                sessionId: 'session-one',
                title: 'One',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
              PersistedSessionTab(
                directory: '/work/two',
                sessionId: 'session-two',
                title: 'Two',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
              PersistedSessionTab(
                directory: '/work/keep',
                sessionId: 'session-keep',
                title: 'Keep',
                lastOpenedAtMs: now.millisecondsSinceEpoch,
                serverUpdatedAtMs: now.millisecondsSinceEpoch,
              ),
            ],
          ).encode(),
          serverId: 'server-a',
        );

        await Future.wait(<Future<void>>[
          provider.removeSessionTabsForProjectHistory(
            '/work/one',
            serverId: 'server-a',
          ),
          provider.removeSessionTabsForProjectHistory(
            '/work/two',
            serverId: 'server-a',
          ),
        ]);

        final persisted = PersistedSessionTabsState.decode(
          await fixtures.localDataSource.getSessionTabsStateJson(
            serverId: 'server-a',
          ),
        );
        expect(persisted.open, hasLength(1));
        expect(persisted.open.single.directory, '/work/keep');
      },
    );

    test(
      'a late read from the previous server cannot replace active tabs',
      () async {
        final delayedLocalDataSource = _DelayedSessionTabsLocalDataSource()
          ..activeServerId = 'server-a';
        await delayedLocalDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              _persisted('tab-a', lastOpenedAtMs: now.millisecondsSinceEpoch),
            ],
          ).encode(),
          serverId: 'server-a',
        );
        await delayedLocalDataSource.saveSessionTabsStateJson(
          PersistedSessionTabsState(
            open: <PersistedSessionTab>[
              _persisted('tab-b', lastOpenedAtMs: now.millisecondsSinceEpoch),
            ],
          ).encode(),
          serverId: 'server-b',
        );
        final delayedProvider = buildChatProvider(
          chatRepository: fixtures.chatRepository,
          appRepository: fixtures.appRepository,
          localDataSource: delayedLocalDataSource,
          defaultSettingsProvider: fixtures.defaultSettingsProvider,
          sessionTabsNow: () => now,
        );
        addTearDown(delayedProvider.dispose);

        final firstLoad = delayedProvider.loadSessionTabs();
        await delayedLocalDataSource.serverAReadStarted.future;
        delayedLocalDataSource.activeServerId = 'server-b';
        final switchServer = delayedProvider.onServerScopeChanged();
        await Future<void>.delayed(Duration.zero);
        delayedLocalDataSource.releaseServerARead.complete();
        await Future.wait(<Future<void>>[firstLoad, switchServer]);

        expect(delayedProvider.activeServerId, 'server-b');
        expect(
          delayedProvider.sessionTabs.map((tab) => tab.identity.sessionId),
          contains('tab-b'),
        );
        expect(
          delayedProvider.sessionTabs.map((tab) => tab.identity.sessionId),
          isNot(contains('tab-a')),
        );
      },
    );
  });
}

class _DelayedSessionTabsLocalDataSource extends InMemoryAppLocalDataSource {
  final Completer<void> serverAReadStarted = Completer<void>();
  final Completer<void> releaseServerARead = Completer<void>();

  @override
  Future<String?> getSessionTabsStateJson({required String serverId}) async {
    if (serverId == 'server-a') {
      if (!serverAReadStarted.isCompleted) serverAReadStarted.complete();
      await releaseServerARead.future;
    }
    return super.getSessionTabsStateJson(serverId: serverId);
  }
}

class _DelayedPinnedPreferenceLocalDataSource
    extends InMemoryAppLocalDataSource {
  final Completer<void> pinReadStarted = Completer<void>();
  final Completer<void> releasePinRead = Completer<void>();

  @override
  Future<String?> getPinnedSessionsJson({
    String? serverId,
    String? scopeId,
  }) async {
    final value = await super.getPinnedSessionsJson(
      serverId: serverId,
      scopeId: scopeId,
    );
    if (serverId == 'srv_test' && scopeId == 'default') {
      if (!pinReadStarted.isCompleted) pinReadStarted.complete();
      await releasePinRead.future;
    }
    return value;
  }
}

class _DelayedPreferenceSaveLocalDataSource extends InMemoryAppLocalDataSource {
  final Completer<void> recentWriteStarted = Completer<void>();
  final Completer<void> releaseRecentWrite = Completer<void>();

  @override
  Future<void> saveRecentModelsJson(
    String recentModelsJson, {
    String? serverId,
    String? scopeId,
  }) async {
    if (!recentWriteStarted.isCompleted) recentWriteStarted.complete();
    await releaseRecentWrite.future;
    await super.saveRecentModelsJson(
      recentModelsJson,
      serverId: serverId,
      scopeId: scopeId,
    );
  }
}

class _FailingPinnedScopeScanLocalDataSource
    extends InMemoryAppLocalDataSource {
  @override
  Future<Map<String, Set<String>>> getPinnedSessionsByScope({
    required String serverId,
  }) {
    throw StateError('scope scan failed');
  }
}

class _DelayedIconBootstrapLocalDataSource extends InMemoryAppLocalDataSource {
  final Completer<void> tabReadStarted = Completer<void>();
  final Completer<void> releaseTabRead = Completer<void>();

  @override
  Future<String?> getSessionTabsStateJson({required String serverId}) async {
    if (!tabReadStarted.isCompleted) tabReadStarted.complete();
    await releaseTabRead.future;
    return super.getSessionTabsStateJson(serverId: serverId);
  }
}
