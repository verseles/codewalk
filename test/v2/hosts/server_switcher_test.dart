import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/app/workspace_controller.dart';
import 'package:codewalk/features/hosts/endpoint_health_controller.dart';
import 'package:codewalk/features/hosts/hosts_controller.dart';
import 'package:codewalk/features/hosts/hosts_page.dart';
import 'package:codewalk/features/hosts/server_switcher.dart';
import 'package:codewalk/features/sessions/sessions_controller.dart';
import 'package:codewalk/platform/sessions/workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../sessions/fakes.dart';
import '../storage/storage_fakes.dart';

final class _Rig {
  _Rig(WidgetTester tester) {
    health = EndpointHealthController(
      hosts: catalog.hosts,
      now: () => tester.binding.clock.now().toUtc(),
    );
    store = WorkspaceStore(store: V2MetadataStore(backend: backend));
    workspace = WorkspaceController(
      catalog: catalog.sessions,
      store: store,
      health: health,
    );
  }
  final catalog = CatalogRig(withFeed: false);
  final backend = FakeMetadataBackend();
  final preferences = AppPreferencesController();
  late final EndpointHealthController health;
  late final WorkspaceStore store;
  late final WorkspaceController workspace;

  Future<void> start(WidgetTester tester, {bool hostsPage = false}) async {
    await catalog.save('a');
    await catalog.save('b');
    await catalog.sessions.initialize();
    await workspace.initialize();
    final selecting = catalog.sessions.selectProfile('profile_a');
    catalog.sources.single.respond([]);
    await selecting;
    health.start(foreground: true);
    await tester.pump();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionsController>.value(
            value: catalog.sessions,
          ),
          ChangeNotifierProvider<HostsController>.value(value: catalog.hosts),
          ListenableProvider<EndpointHealthController?>.value(value: health),
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<AppPreferencesController>.value(
            value: preferences,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: const [WorkspaceAppBarActions()]),
            body: hostsPage ? const HostsPage() : const ServerSwitcher(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    preferences.dispose();
    workspace.dispose();
    health.dispose();
    catalog.dispose();
  }
}

void main() {
  test('server search matches label, URL and ID without reordering', () {
    final a = profile('a');
    final b = EndpointProfile(
      id: 'profile_beta',
      label: 'Other',
      endpoint: Uri.parse('https://beta.example.test/proxy/'),
    );
    expect(filterSavedServers([a, b], 'SERVER A'), [a]);
    expect(filterSavedServers([a, b], 'beta.example'), [b]);
    expect(filterSavedServers([a, b], 'PROFILE_BETA'), [b]);
    expect(filterSavedServers([a, b], ''), [a, b]);
  });

  testWidgets(
    'picker search keeps selection; a pending switch is shared and survives connectivity failure',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester);
        await tester.tap(find.byKey(const ValueKey('sessions-profile')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('server-switcher-search')),
          'profile_b',
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('server-switch-profile_a')),
          findsNothing,
        );
        expect(rig.catalog.sessions.selectedProfile?.id, 'profile_a');
        await tester.tap(find.byKey(const ValueKey('server-switch-profile_b')));
        await tester.pump();
        expect(rig.workspace.switchingServer, isTrue);
        expect(
          await rig.workspace.selectServer('profile_a'),
          ServerSwitchResult.busy,
        );
        expect(rig.catalog.sources, hasLength(2));
        rig.catalog.sources.last.fail(SessionCatalogFailure.connection);
        await tester.pumpAndSettle();
        expect(rig.workspace.switchingServer, isFalse);
        expect(rig.catalog.sessions.selectedProfile?.id, 'profile_b');
        expect(rig.store.activeProfile, 'profile_b');
        expect(rig.catalog.sessions.failure, SessionCatalogFailure.connection);
        expect(
          find.byKey(const ValueKey('server-switcher-search')),
          findsNothing,
        );
        expect(
          find.text('Online'),
          findsOneWidget,
          reason: 'stream/catalog errors do not replace health status',
        );
      } finally {
        rig.dispose();
      }
    },
  );

  testWidgets('known unhealthy targets cannot replace the selected server', (
    tester,
  ) async {
    final rig = _Rig(tester);
    try {
      await rig.start(tester);
      final b = profile('b');
      rig.catalog.hosts.observeAssessment(
        b,
        rig.catalog.hosts.credentialFor(b)!,
        const EndpointAssessment(EndpointStatus.unreachable),
      );
      await tester.tap(find.byKey(const ValueKey('sessions-profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('server-switch-profile_b')));
      await tester.pump();
      expect(rig.catalog.sessions.selectedProfile?.id, 'profile_a');
      expect(rig.store.activeProfile, 'profile_a');
      expect(rig.catalog.sources, hasLength(1));
      expect(
        find.byKey(const ValueKey('server-switcher-search')),
        findsOneWidget,
      );
    } finally {
      rig.dispose();
    }
  });

  testWidgets(
    'Hosts search filters one list without switching or changing order',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester, hostsPage: true);
        await tester.enterText(
          find.byKey(const ValueKey('hosts-search')),
          'profile_b',
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('saved-server-profile_a')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('saved-server-profile_b')),
          findsOneWidget,
        );
        expect(rig.catalog.sessions.selectedProfile?.id, 'profile_a');
        await tester.enterText(find.byKey(const ValueKey('hosts-search')), '');
        await tester.pump();
        expect(
          find.byKey(const ValueKey('saved-server-profile_a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('saved-server-profile_b')),
          findsOneWidget,
        );
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('saved-server-profile_a')))
              .dy,
          lessThan(
            tester
                .getTopLeft(
                  find.byKey(const ValueKey('saved-server-profile_b')),
                )
                .dy,
          ),
        );
        expect(tester.takeException(), isNull);
      } finally {
        rig.dispose();
      }
    },
  );

  testWidgets(
    'pin controls retain the latest three real actions without executing them',
    (tester) async {
      final rig = _Rig(tester);
      try {
        await rig.start(tester);
        await tester.tap(find.byKey(const ValueKey('workspace-actions')));
        await tester.pumpAndSettle();
        for (final action in ['refresh', 'servers', 'settings']) {
          await tester.tap(find.byKey(ValueKey('workspace-pin-$action')));
          await tester.pump();
        }
        expect(rig.preferences.appBarPins, [
          WorkspacePinnedAction.refresh,
          WorkspacePinnedAction.servers,
          WorkspacePinnedAction.settings,
        ]);
        expect(rig.catalog.sources, hasLength(1));
        await tester.tapAt(const Offset(0, 0));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workspace-pinned-newChat')),
          findsNothing,
        );
        for (final action in ['refresh', 'servers', 'settings']) {
          expect(
            find.byKey(ValueKey('workspace-pinned-$action')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        rig.dispose();
      }
    },
  );
}
