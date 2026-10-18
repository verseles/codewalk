import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_permission_mode_chip.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  late CatalogRig rig;
  late LiveDirectory directory;
  late PermissionModeStore policy;

  setUp(() async {
    rig = CatalogRig();
    await rig.save('a');
    await rig.sessions.initialize();
    directory = LiveDirectory();
    policy = PermissionModeStore(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    await policy.initialize();
  });

  tearDown(() {
    policy.dispose();
    rig.dispose();
  });

  Future<SessionLiveController> open(String id) async {
    final summary = CatalogSource(profile(id)).row('one');
    final live = SessionLiveController(
      hosts: rig.hosts,
      profile: profile(id),
      summary: summary,
      directory: directory,
      permissionModes: policy,
    );
    addTearDown(live.dispose);
    return live;
  }

  Future<void> pumpChip(WidgetTester tester, SessionLiveController live) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: V2Localizations.localizationsDelegates,
        supportedLocales: V2Localizations.supportedLocales,
        home: Scaffold(body: SessionPermissionModeChip(live: live)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the acknowledged default and switches to Ask', (
    tester,
  ) async {
    final live = await open('a');
    await pumpChip(tester, live);
    expect(find.text('Allow all'), findsOneWidget);
    expect(live.permissionModeState.source, PermissionModeSource.defaultOn);

    await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask').last);
    await tester.pumpAndSettle();

    expect(live.permissionModeState.mode, PermissionMode.ask);
    expect(live.permissionModeState.source, PermissionModeSource.session);
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('Allow all'), findsNothing);
  });

  testWidgets('offers the app default only for a session override', (
    tester,
  ) async {
    final live = await open('a');
    await policy.setSessionMode(live.session, PermissionMode.ask);
    await pumpChip(tester, live);
    await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
    await tester.pumpAndSettle();
    expect(find.text('Use app default'), findsOneWidget);
    await tester.tap(find.text('Use app default'));
    await tester.pumpAndSettle();
    expect(live.permissionModeState.source, PermissionModeSource.defaultOn);
    expect(find.text('Allow all'), findsOneWidget);
  });

  testWidgets('stays disabled while stored overrides are unreadable', (
    tester,
  ) async {
    final unreadable = PermissionModeStore(
      // The global default stays readable; only the overrides blob is corrupt.
      store: V2MetadataStore(
        backend: FakeMetadataBackend()
          ..values[PermissionModeStore.overridesKey] = 'not json',
      ),
    );
    await unreadable.initialize();
    addTearDown(unreadable.dispose);
    final summary = CatalogSource(profile('a')).row('one');
    final other = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
      permissionModes: unreadable,
    );
    addTearDown(other.dispose);
    expect(unreadable.defaultMode, PermissionMode.allowAll);
    expect(other.canChangePermissionMode, isFalse);
    await pumpChip(tester, other);
    expect(find.text('Permission mode unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
    await tester.pumpAndSettle();
    expect(find.text('Ask'), findsNothing);
    expect(await other.setPermissionMode(PermissionMode.ask), isFalse);
  });

  testWidgets('keeps the acknowledged label when the write fails', (
    tester,
  ) async {
    // The store refuses overrides it cannot persist.
    final failing = PermissionModeStore(
      store: V2MetadataStore(
        backend: FakeMetadataBackend()
          ..failWrite = PermissionModeStore.overridesKey,
      ),
    );
    await failing.initialize();
    addTearDown(failing.dispose);
    final summary = CatalogSource(profile('a')).row('one');
    final other = SessionLiveController(
      hosts: rig.hosts,
      profile: profile('a'),
      summary: summary,
      directory: directory,
      permissionModes: failing,
    );
    addTearDown(other.dispose);
    await pumpChip(tester, other);
    await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask').last);
    await tester.pumpAndSettle();
    expect(other.permissionModeState.mode, PermissionMode.allowAll);
    expect(find.text('Allow all'), findsOneWidget);
    expect(find.text('Could not save the permission mode.'), findsOneWidget);
  });
}
