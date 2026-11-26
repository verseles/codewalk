import 'dart:async';

import 'package:codewalk/app/live_wake.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_chrome_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_tabs_controller.dart';
import 'package:codewalk/features/settings/apk_update_controller.dart';
import 'package:codewalk/features/settings/update_check_controller.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations_en.dart';
import 'package:codewalk/shared/releases/apk_integrity.dart';
import 'package:codewalk/shared/releases/apk_update.dart';
import 'package:codewalk/shared/releases/app_version.dart';
import 'package:codewalk/shared/releases/release_source.dart';
import 'package:codewalk/shared/releases/update_selector.dart';
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

  testWidgets('warning waits seven seconds of grace then five of debounce', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      rig.observe(EndpointStatus.unreachable);
      // The resume grace is 7 s (#503).
      await tester.pump(const Duration(seconds: 6));
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
      await tester.pump(const Duration(seconds: 8));
      rig.health.setForeground(false);
      await tester.pump(const Duration(seconds: 30));
      expect(rig.chrome.warningRevision, 0);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      rig.health.setForeground(true);
      expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);
      await tester.pump(const Duration(seconds: 11));
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
        await tester.pump(liveResumeGrace);
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

  testWidgets(
    'excludes child and stale >1h unread sessions, fills dots, and surfaces cached APK quick-install badge and drawer tile',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester);
        final source = rig.catalog.sources.single;
        final now = tester.binding.clock.now().toUtc();
        final childUnread = source.row(
          'child',
          directory: '/work/a',
          parent: 'current',
          view: SessionViewMarker(
            idleAt: now.subtract(const Duration(minutes: 5)),
          ),
        );
        final staleUnread = source.row(
          'old',
          directory: '/work/a',
          view: SessionViewMarker(
            idleAt: now.subtract(const Duration(hours: 2)),
          ),
        );
        final freshUnread = source.row(
          'fresh',
          directory: '/work/a',
          view: SessionViewMarker(
            idleAt: now.subtract(const Duration(minutes: 10)),
          ),
        );
        rig.actions.viewStates[childUnread.info.ref.storageKey] =
            SessionViewState.unread;
        rig.actions.viewStates[staleUnread.info.ref.storageKey] =
            SessionViewState.unread;

        final refresh = rig.catalog.sessions.refresh();
        source.respond([rig.current, childUnread, staleUnread]);
        await refresh;
        await tester.pump();
        // Child and >1h stale unread sessions do not badge the idle hamburger.
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);

        // A fresh (<1h) root unread session badges until its 1h window expires.
        rig.actions.viewStates[freshUnread.info.ref.storageKey] =
            SessionViewState.unread;
        final refresh2 = rig.catalog.sessions.refresh();
        source.respond([rig.current, childUnread, staleUnread, freshUnread]);
        await refresh2;
        await tester.pump();
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.unread);
        await tester.pump(const Duration(minutes: 51));
        expect(rig.chrome.badge.kind, WorkspaceBadgeKind.none);

        // Cached APK update outranks unread/idle and exposes one-tap install in drawer.
        final store = _MiniApkStore();
        final installer = _MiniApkInstaller();
        final checks = UpdateCheckController(
          source: _EmptyReleaseSource(),
          store: V2MetadataStore(backend: FakeMetadataBackend()),
          installedVersion: () async => '2.1.0',
          target: UpdateTarget.androidArm64,
        );
        final apkUpdates = ApkUpdateController(
          fetcher: _MiniApkFetcher(store),
          installer: installer,
          fileStore: store,
          checks: checks,
          installedBuildNumber: () async => '1',
          packageName: () async => codewalkAndroidApplicationId,
          isForeground: () => true,
        );
        final updateChrome = WorkspaceChromeController(
          health: rig.health,
          catalog: rig.catalog.sessions,
          tabs: rig.tabs,
          apkUpdates: apkUpdates,
          updates: checks,
        )..locationChanged('/s/profile_a/ses_current');
        addTearDown(() {
          updateChrome.dispose();
          apkUpdates.dispose();
          checks.dispose();
          unawaited(installer.close());
        });

        await apkUpdates.start(
          UpdateCandidate(
            tag: 'v2.2.0',
            version: AppVersion.tryParse('2.2.0')!,
            assetUrl: Uri.parse(
              'https://github.com/verseles/codewalk/releases/download/v2.2.0/codewalk-android-arm64.apk',
            ),
          ),
        );
        // Simulate user cancelling confirmation so APK remains ready in cache.
        installer.signalsController.add(ApkInstallSignal.aborted);
        await tester.pump();
        expect(apkUpdates.hasPendingCachedUpdate, isTrue);
        expect(updateChrome.badge.kind, WorkspaceBadgeKind.updateReady);

        await tester.pumpWidget(
          ListenableProvider<WorkspaceChromeController?>.value(
            value: updateChrome,
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
          find.byKey(const ValueKey('workspace-badge-updateReady')),
          findsOneWidget,
        );
        expect(find.text('Update downloaded. Tap to install.'), findsOneWidget);
        final opensBefore = installer.opens;
        await tester.tap(find.byKey(const ValueKey('workspace-drawer-notice')));
        await tester.pump();
        expect(installer.opens, opensBefore + 1);
      } finally {
        rig.dispose();
      }
    },
  );
}

class _EmptyReleaseSource implements ReleaseSource {
  @override
  ReleaseSourceTask start({String? until}) => _EmptyReleaseTask();
  @override
  void close() {}
}

class _EmptyReleaseTask implements ReleaseSourceTask {
  @override
  Future<ReleaseSourceResult> get result async =>
      const ReleaseSourceResult.success('[]');
  @override
  void cancel() {}
}

class _MiniApkStore implements ApkFileStore {
  final Map<String, String> files = {};
  @override
  Future<String> partPath(String tag) async => '/tmp/$tag.part';
  @override
  Future<String> finalPath(String tag) async => '/tmp/$tag.apk';
  @override
  Future<void> rename(String from, String to) async {
    files[to] = files[from] ?? '';
    files.remove(from);
  }

  @override
  Future<void> delete(String path) async => files.remove(path);
  @override
  Future<bool> exists(String path) async => files.containsKey(path);
  @override
  Future<String?> sha256(String path) async => files[path];
  @override
  Future<void> writeSidecar(ApkCachedRecord record) async {}
  @override
  Future<ApkCachedRecord?> restoreCached({
    required int installedBuildNumber,
  }) async => null;
  @override
  Future<void> cleanupStale({int? installedBuildNumber}) async {}
}

class _MiniApkFetcher implements ApkAssetFetcher {
  _MiniApkFetcher(this.store);
  final _MiniApkStore store;
  static const _sha =
      '64d338107e0175b26d25343ed00af2a01ac009c9286c16c9f1aed32ac7c58f5b';
  @override
  Future<String> fetchText(Uri uri, {int maxBytes = 256 * 1024}) async {
    if (uri.path.endsWith('SHA256SUMS')) {
      return '$_sha  codewalk-android-arm64.apk\n';
    }
    return '{"schema":1,"tag":"v2.2.0","version":"2.2.0","assets":{"codewalk-android-arm64.apk":{"abi":"arm64-v8a","application_id":"com.verseles.codewalk","sha256":"$_sha","signer_sha256":"$codewalkAndroidSignerSha256","size":10,"version_code":2,"version_name":"2.2.0"}}}';
  }

  @override
  Future<ApkDownloadResult> download(
    Uri uri,
    String partPath, {
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
    int? expectedBytes,
    String? expectedSha256,
  }) async {
    store.files[partPath] = _sha;
    return const ApkDownloadResult(bytes: 10, sha256: _sha);
  }

  @override
  void close() {}
  @override
  void cancelActive() {}
}

class _MiniApkInstaller implements ApkInstaller {
  int opens = 0;
  // ignore: close_sinks
  final StreamController<ApkInstallSignal> signalsController =
      StreamController<ApkInstallSignal>.broadcast();
  Future<void> close() => signalsController.close();
  @override
  Stream<ApkInstallSignal> get signals => signalsController.stream;
  @override
  Future<ApkInstallOutcome> open(
    String path, {
    int? versionCode,
    String? tag,
    String? notificationTitle,
    String? notificationBody,
    String? notificationChannel,
  }) async {
    opens++;
    return ApkInstallOutcome.committed;
  }

  @override
  Future<void> clearPendingMarker() async {}
}
