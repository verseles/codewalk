import 'dart:async';

import 'package:codewalk/app/live_wake.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_chrome_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

final class _Rig {
  _Rig(WidgetTester tester, {bool feed = false, Duration? liveMinInterval}) {
    catalog = CatalogRig(
      actions: actions,
      withFeed: feed,
      liveMinInterval: liveMinInterval ?? Duration.zero,
    );
    health = EndpointHealthController(
      hosts: catalog.hosts,
      now: () => tester.binding.clock.now().toUtc(),
    );
    tabs = SessionTabsController(
      catalog: catalog.sessions,
      store: SessionTabsStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      ),
    );
    chrome = WorkspaceChromeController(
      health: health,
      catalog: catalog.sessions,
      tabs: tabs,
    );
  }
  final actions = FakeActionSource();
  late final CatalogRig catalog;
  late final EndpointHealthController health;
  late final SessionTabsController tabs;
  late final WorkspaceChromeController chrome;
  late SessionSummary current;

  Future<void> start(WidgetTester tester, {bool attention = false}) async {
    await catalog.save('a');
    await catalog.save('b');
    await catalog.sessions.initialize();
    await tabs.initialize();
    final selecting = catalog.sessions.selectProfile('profile_a');
    final source = catalog.sources.single;
    current = source.row('current', directory: '/work/a');
    final reply = source.row('reply', directory: '/work/a');
    final other = source.row('elsewhere', directory: '/work/b');
    final error = source.row('error', directory: '/work/a');
    SessionSummary failed(SessionSummary row) => SessionSummary(
      info: row.info,
      execution: const ExecutionState(
        kind: OpenValue.known(ExecutionKind.idle),
        lastOutcome: ExecutionOutcome(
          OpenValue.known(ExecutionOutcomeKind.failed),
        ),
      ),
    );
    source.respond([
      current,
      if (attention) ...[reply, failed(error), failed(other)],
    ]);
    await selecting;
    catalog.sessions.selectProject(current.info.project!);
    if (attention) {
      actions.viewStates[reply.info.ref.storageKey] = SessionViewState.unread;
    }
    chrome.locationChanged('/s/profile_a/ses_current');
    health.start(foreground: true);
    await tester.pump();
    // Later automatic reads stay pending; the test owns all observations.
    (catalog.hosts.prober as FakeProber).pendingResult =
        Completer<EndpointAssessment>().future;
  }

  void observe(EndpointStatus status) {
    final profile = catalog.sessions.selectedProfile!;
    catalog.hosts.observeAssessment(
      profile,
      catalog.hosts.credentialFor(profile)!,
      EndpointAssessment(status),
    );
  }

  void dispose() {
    chrome.dispose();
    tabs.dispose();
    health.dispose();
    catalog.dispose();
  }
}

void main() {
  testWidgets(
    'a list catching up spins the hamburger and a server back retries it',
    (tester) async {
      final rig = _Rig(
        tester,
        feed: true,
        liveMinInterval: const Duration(minutes: 1),
      );
      await rig.start(tester);
      final recovery = LiveRecovery(
        health: rig.health,
        catalog: rig.catalog.sessions,
        tabs: rig.tabs,
      );
      final source = rig.catalog.sources.single;
      // A zero debounce still needs the fake clock to move.
      Future<void> tick() => tester.pump(const Duration(milliseconds: 10));
      // The catch-up read that follows the feed opening.
      await tick();
      expect(source.tasks, hasLength(2));
      source.respond([rig.current]);
      await tick();
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);

      // The feed reconnects (a re-read waits out its minute) and drops.
      rig.catalog.feed.emit(const SessionCatalogConnection(true));
      await tick();
      rig.catalog.feed.emit(const SessionCatalogConnection(false));
      await tick();
      expect(rig.catalog.sessions.behind, isTrue);
      // The list recovers by itself, so the hamburger shows it (#467).
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.syncing);
      final reads = source.tasks.length;

      // The server stops answering, then answers again: the list retries
      // now instead of waiting out its minute.
      rig.observe(EndpointStatus.unreachable);
      await tick();
      expect(source.tasks, hasLength(reads));
      rig.observe(EndpointStatus.compatible);
      await tick();
      expect(source.tasks, hasLength(reads + 1));
      source.respond([rig.current]);
      await tick();
      // The list read, but its feed is still down: it keeps spinning.
      expect(rig.catalog.sessions.behind, isTrue);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.syncing);
      // The feed reconnects and a wake re-reads: the list is current again.
      rig.catalog.feed.emit(const SessionCatalogConnection(true));
      await tick();
      recovery.retry();
      await tick();
      source.respond([rig.current]);
      await tick();
      expect(rig.catalog.sessions.behind, isFalse);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      recovery.dispose();
      rig.dispose();
    },
  );

  testWidgets('a head read waiting to retry spins the hamburger', (
    tester,
  ) async {
    final rig = _Rig(tester, liveMinInterval: const Duration(minutes: 1));
    await rig.start(tester);
    final source = rig.catalog.sources.single;
    expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
    // The head read fails for a passing cause: the list retries by itself
    // after a wait, and the hamburger shows it (#467).
    final read = rig.catalog.sessions.refresh();
    source.fail(SessionCatalogFailure.connection);
    await read;
    await tester.pump();
    expect(rig.catalog.sessions.behind, isFalse);
    expect(rig.catalog.sessions.retrying, isTrue);
    expect(rig.chrome.badge.kind, WorkspaceBadgeKind.syncing);
    rig.dispose();
  });

  testWidgets('warning waits five seconds of grace then five of debounce', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      rig.observe(EndpointStatus.unreachable);
      await tester.pump(const Duration(seconds: 4));
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      await tester.pump(const Duration(seconds: 1));
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.serverAlert);
      await tester.pump(const Duration(seconds: 4));
      expect(rig.chrome.warningRevision, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(rig.chrome.warningRevision, 1);
      expect(rig.chrome.takeWarning()?.id, 'profile_a');
      expect(rig.chrome.takeWarning(), isNull);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.chrome.warningRevision, 1);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('recovery cancels a warning during its debounce', (tester) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      rig.observe(EndpointStatus.unreachable);
      await tester.pump(const Duration(seconds: 9));
      rig.observe(EndpointStatus.compatible);
      await tester.pump(const Duration(seconds: 20));
      expect(rig.chrome.warningRevision, 0);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('background cancels warnings and resume starts a new grace', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      rig.observe(EndpointStatus.unreachable);
      await tester.pump(const Duration(seconds: 6));
      rig.health.setForeground(false);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.chrome.warningRevision, 0);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      rig.health.setForeground(true);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      await tester.pump(const Duration(seconds: 9));
      expect(rig.chrome.warningRevision, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(rig.chrome.warningRevision, 1);
    } finally {
      rig.dispose();
    }
  });

  testWidgets('switching servers cancels the old endpoint warning', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      rig.observe(EndpointStatus.unreachable);
      await tester.pump(const Duration(seconds: 9));
      final selecting = rig.catalog.sessions.selectProfile('profile_b');
      rig.catalog.sources.last.respond([]);
      await selecting;
      await tester.pump(const Duration(seconds: 20));
      expect(rig.chrome.warningRevision, 0);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
    } finally {
      rig.dispose();
    }
  });

  testWidgets(
    'one badge prioritizes server alert, current-project error, then unread',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester, attention: true);
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.error);
        expect(rig.chrome.badge.session?.nativeId, 'ses_error');
        rig.chrome.locationChanged('/s/profile_a/ses_error');
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.unread);
        expect(rig.chrome.badge.session?.nativeId, 'ses_reply');
        rig.observe(EndpointStatus.unreachable);
        await tester.pump(const Duration(seconds: 5));
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.serverAlert);
        await tester.pumpWidget(
          ListenableProvider<WorkspaceChromeController?>.value(
            value: rig.chrome,
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    WorkspaceMenuButton(openDrawer: () {}),
                    const WorkspaceDrawerNotice(),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('workspace-badge-serverAlert')),
          findsOneWidget,
        );
        expect(find.text('Server connection needs attention.'), findsOneWidget);
        expect(find.byIcon(Symbols.close), findsNothing);
        rig.observe(EndpointStatus.compatible);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('workspace-badge-unread')),
          findsOneWidget,
        );
        expect(find.text('"reply" has a new reply.'), findsOneWidget);
      } finally {
        rig.dispose();
      }
    },
  );

  testWidgets(
    'resume sync has its own badge while server health stays online',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester);
        final directory = LiveDirectory();
        final live = rig.tabs.live(
          rig.current.info.ref,
          () => SessionLiveController(
            hosts: rig.catalog.hosts,
            health: rig.health,
            profile: profile('a'),
            summary: rig.current,
            directory: directory,
          ),
        );
        final opening = live.start();
        final handle = directory.grant(live.session);
        await opening;
        void emit(SessionLivePhase phase) => handle.emit(
          SessionLiveView(
            session: live.session,
            phase: phase,
            state: liveState(live.session),
          ),
        );
        emit(SessionLivePhase.live);
        await tester.pump();
        rig.health.setForeground(false);
        rig.health.setForeground(true);
        emit(SessionLivePhase.reconnecting);
        await tester.pump();
        expect(
          rig.health.view(profile('a')).status,
          EndpointHealthStatus.online,
        );
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.syncing);
        await tester.pump(const Duration(seconds: 10));
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.syncAlert);
        expect(
          workspaceBadgeText(V2LocalizationsEn(), rig.chrome.badge),
          V2LocalizationsEn().chatBadgeSyncing,
        );
        expect(
          rig.health.view(profile('a')).status,
          EndpointHealthStatus.online,
        );
        expect(
          rig.chrome.badge.session,
          live.session,
          reason: 'an escalated sync notice leads to its conversation',
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: WorkspaceDrawerNotice()),
            ),
            GoRoute(
              path: '/s/:host/:session',
              builder: (_, state) => Scaffold(
                body: Text('Conversation ${state.pathParameters['session']}'),
              ),
            ),
            GoRoute(
              path: '/hosts',
              builder: (_, _) => const Scaffold(body: Text('Servers')),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            ListenableProvider<WorkspaceChromeController?>.value(
              value: rig.chrome,
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.tap(
            find.byKey(const ValueKey('workspace-drawer-notice')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Conversation ${live.session.nativeId}'),
            findsOneWidget,
          );
          expect(find.text('Servers'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
        emit(SessionLivePhase.live);
        await tester.pump();
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      } finally {
        rig.dispose();
      }
    },
  );
}
