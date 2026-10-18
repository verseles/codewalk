import 'package:codewalk/features/sessions/session_live_controller.dart';
import 'package:codewalk/features/sessions/session_permission_mode_chip.dart';
import 'package:codewalk/platform/sessions/permission_mode_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/permission_mode.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk/shared/sessions/session_unrestricted.dart';
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

  group('Unrestricted', () {
    Future<(SessionLiveController, LiveHandle)> live(
      WidgetTester tester,
      SessionUnrestrictedState state,
    ) async {
      final controller = await open('a');
      final opening = controller.start();
      final handle = directory.grant(controller.session)
        ..unrestrictedAvailable = true
        ..unrestrictedState = state;
      await opening;
      handle.emit(
        SessionLiveView(
          session: controller.session,
          phase: SessionLivePhase.live,
          state: liveState(controller.session),
        ),
      );
      await tester.pump();
      return (controller, handle);
    }

    testWidgets('turning it on needs explicit confirmation', (tester) async {
      final (controller, handle) = await live(
        tester,
        const SessionUnrestrictedState(phase: SessionUnrestrictedPhase.off),
      );
      handle.unrestrictedAction = (_) => const SessionUnrestrictedState(
        phase: SessionUnrestrictedPhase.on,
        inEffect: true,
      );
      await pumpChip(tester, controller);
      await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-unrestricted-on')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('live-unrestricted-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(handle.unrestrictedCalls, isEmpty);
      expect(find.text('Allow all'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-unrestricted-on')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-unrestricted-confirm')));
      await tester.pumpAndSettle();
      expect(handle.unrestrictedCalls, ['enable']);
      expect(find.text('Unrestricted'), findsOneWidget);
      // The local mode is a separate axis and is untouched.
      expect(controller.permissionModeState.mode, PermissionMode.allowAll);
    });

    testWidgets('a rule CodeWalk did not add is shown but never offered', (
      tester,
    ) async {
      final (controller, handle) = await live(
        tester,
        const SessionUnrestrictedState(
          phase: SessionUnrestrictedPhase.elsewhere,
          inEffect: true,
        ),
      );
      await pumpChip(tester, controller);
      expect(find.text('Unrestricted'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
      await tester.pumpAndSettle();
      expect(find.text('Set outside CodeWalk'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-unrestricted-off')), findsNothing);
      expect(find.byKey(const ValueKey('live-unrestricted-on')), findsNothing);
      await tester.tap(find.text('Set outside CodeWalk'));
      await tester.pumpAndSettle();
      expect(handle.unrestrictedCalls, isEmpty);
    });

    testWidgets('turning it off explains that children keep the rule', (
      tester,
    ) async {
      final (controller, handle) = await live(
        tester,
        const SessionUnrestrictedState(
          phase: SessionUnrestrictedPhase.on,
          inEffect: true,
        ),
      );
      handle.unrestrictedAction = (_) =>
          const SessionUnrestrictedState(phase: SessionUnrestrictedPhase.off);
      await pumpChip(tester, controller);
      await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-unrestricted-off')));
      await tester.pumpAndSettle();
      expect(handle.unrestrictedCalls, ['disable']);
      expect(
        find.text(
          'Unrestricted turned off. Existing child sessions keep the rule '
          'they copied.',
        ),
        findsOneWidget,
      );
      expect(find.text('Allow all'), findsOneWidget);
    });

    testWidgets('rules changed elsewhere are reported, not overwritten', (
      tester,
    ) async {
      final (controller, handle) = await live(
        tester,
        const SessionUnrestrictedState(
          phase: SessionUnrestrictedPhase.on,
          inEffect: true,
        ),
      );
      handle.unrestrictedAction = (_) => const SessionUnrestrictedState(
        phase: SessionUnrestrictedPhase.conflict,
        inEffect: true,
        notice: SessionUnrestrictedNotice.changedElsewhere,
      );
      await pumpChip(tester, controller);
      await tester.tap(find.byKey(const ValueKey('live-permission-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-unrestricted-off')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The session rules changed elsewhere. CodeWalk did not overwrite '
          'them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unrestricted'), findsOneWidget);
    });

    testWidgets('compact width keeps the label in semantics', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (controller, _) = await live(
        tester,
        const SessionUnrestrictedState(
          phase: SessionUnrestrictedPhase.on,
          inEffect: true,
        ),
      );
      await pumpChip(tester, controller);
      expect(find.text('Unrestricted'), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Permission mode: Unrestricted: Set for this session',
        ),
        findsOneWidget,
      );
    });
  });
}
