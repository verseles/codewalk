import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

typedef _Open = ({
  AppDependencies dependencies,
  V2Localizations l10n,
  CatalogRig rig,
  LiveDirectory directory,
});

/// Opens the app on [link] with one saved profile, `profile_a`.
Future<_Open> _open(
  WidgetTester tester,
  String link, {
  Size size = const Size(1280, 800),
  CatalogRig? rig,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (rig == null) {
    rig = CatalogRig();
    addTearDown(rig.dispose);
  }
  await rig.save('a');
  final directory = LiveDirectory();
  final dependencies = createAppDependencies(
    initialLink: Uri.parse(link),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
  );
  await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
  await _settle(tester);
  return (
    dependencies: dependencies,
    l10n: dependencies.localizations.current,
    rig: rig,
    directory: directory,
  );
}

/// Lets the frames run out; a spinner never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder get _notice => find.byKey(const ValueKey('session-notice'));

void main() {
  testWidgets('a link to a loaded session opens it beside the list', (
    tester,
  ) async {
    final app = await _open(tester, '/s/profile_a/ses_one');
    // The list follows the server of the link.
    expect(app.dependencies.sessions!.selectedProfile?.id, 'profile_a');
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    expect(source.reads, isEmpty);
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a row opens the same route a link takes', (tester) async {
    final app = await _open(tester, '/sessions');
    app.dependencies.sessions!.selectProfile('profile_a').ignore();
    await tester.pump();
    final source = app.rig.sources.single;
    final row = source.row('one', title: 'One');
    source.respond([row]);
    await _settle(tester);
    await tester.tap(find.byKey(ValueKey(row.info.ref)));
    await _settle(tester);
    final button = find.byKey(ValueKey('live-open-${row.info.ref.storageKey}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await _settle(tester);
    expect(app.dependencies.router.state.uri.path, '/s/profile_a/ses_one');
    expect(find.byType(SessionLivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a session outside the loaded rows is read from its server', (
    tester,
  ) async {
    final app = await _open(tester, '/s/profile_a/ses_far');
    final source = app.rig.sources.single;
    source.respond([source.row('one')]);
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsNothing);
    final (ref, task) = source.reads.single;
    expect(ref.nativeId, 'ses_far');
    expect(find.byKey(const ValueKey('session-opening')), findsOneWidget);
    task.completion.complete(source.row('far', title: 'Far'));
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    expect(find.text('Far'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a read answering another session is not opened', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_far');
    final source = app.rig.sources.single;
    source.respond(const []);
    await _settle(tester);
    source.reads.single.$2.completion.complete(source.row('other'));
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsNothing);
    expect(find.text(app.l10n.sessionLinkUnreadable), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a missing session says so', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_gone');
    final source = app.rig.sources.single;
    source.respond(const []);
    await _settle(tester);
    source.reads.single.$2.completion.completeError(
      const SessionCatalogException(SessionCatalogFailure.notFound),
    );
    await _settle(tester);
    expect(find.text(app.l10n.sessionLinkNotFound), findsOneWidget);
    expect(find.byKey(const ValueKey('session-retry')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an unreadable session offers a retry', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_far');
    final source = app.rig.sources.single;
    source.respond(const []);
    await _settle(tester);
    source.reads.single.$2.completion.completeError(
      const SessionCatalogException(SessionCatalogFailure.connection),
    );
    await _settle(tester);
    expect(find.text(app.l10n.sessionLinkUnreadable), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('session-retry')));
    await _settle(tester);
    expect(source.reads, hasLength(2));
    source.reads.last.$2.completion.complete(source.row('far'));
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a read that wants a login says so', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_far');
    final source = app.rig.sources.single;
    source.respond(const []);
    await _settle(tester);
    source.reads.single.$2.completion.completeError(
      const SessionCatalogException(
        SessionCatalogFailure.authenticationRequired,
      ),
    );
    await _settle(tester);
    expect(find.text(app.l10n.hostsAuthRequired), findsWidgets);
    // After the login is fixed, the retry reads the list, then the session.
    await tester.tap(find.byKey(const ValueKey('session-retry')));
    await _settle(tester);
    expect(source.reads, hasLength(1));
    source.respond(const []);
    await _settle(tester);
    expect(source.reads, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the open session stays when the list no longer shows it', (
    tester,
  ) async {
    final app = await _open(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    final ref = source.row('one').info.ref;
    app.directory.grant(ref);
    await tester.pump();
    final state = tester.state(find.byType(SessionLivePage));
    // A refresh, a filter or a page the row is not in.
    app.dependencies.sessions!.refresh().ignore();
    await tester.pump();
    source.respond([source.row('two')]);
    await _settle(tester);
    expect(tester.state(find.byType(SessionLivePage)), same(state));
    expect(app.directory.handles.single.closes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a reload of the saved servers keeps the open session', (
    tester,
  ) async {
    final app = await _open(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    app.directory.grant(source.row('one').info.ref);
    await tester.pump();
    final state = tester.state(find.byType(SessionLivePage));
    // Opening Servers reloads them, as often as the user opens it.
    for (var i = 0; i < 2; i++) {
      app.dependencies.sessions!.hosts.load().ignore();
      await tester.pump();
      expect(tester.state(find.byType(SessionLivePage)), same(state));
      await _settle(tester);
      expect(app.dependencies.sessions!.selectedProfile?.id, 'profile_a');
    }
    expect(tester.state(find.byType(SessionLivePage)), same(state));
    expect(app.directory.opens, hasLength(1));
    // The lease outlives the reload too.
    expect(app.directory.handles.single.closes, 0);
    expect(app.dependencies.router.state.uri.path, '/s/profile_a/ses_one');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('another server chosen in the list leaves the session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('b');
    final app = await _open(tester, '/s/profile_a/ses_one', rig: rig);
    final source = app.rig.sources.last;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    app.dependencies.sessions!.selectProfile('profile_b').ignore();
    await _settle(tester);
    expect(app.dependencies.router.state.uri.path, '/sessions');
    expect(find.byType(SessionLivePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a link to an unsaved server says so', (tester) async {
    final app = await _open(tester, '/s/elsewhere/ses_one');
    expect(find.text(app.l10n.sessionLinkUnknownServer), findsOneWidget);
    expect(app.rig.sources, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a server that wants a login says so', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_one');
    app.rig.sources.single.fail(SessionCatalogFailure.authenticationRequired);
    await _settle(tester);
    expect(_notice, findsOneWidget);
    expect(find.text(app.l10n.hostsAuthRequired), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a compact session keeps the list in a drawer', (tester) async {
    final app = await _open(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workspace-drawer')));
    await _settle(tester);
    expect(find.byType(Drawer), findsOneWidget);
    // The system back closes the drawer first, then returns to the list.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settle(tester);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(SessionLivePage), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settle(tester);
    expect(app.dependencies.router.state.uri.path, '/sessions');
    expect(find.byType(SessionLivePage), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a resize keeps the open session and its lease', (tester) async {
    final app = await _open(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One')]);
    await _settle(tester);
    final ref = source.row('one').info.ref;
    app.directory.grant(ref);
    await tester.pump();
    final state = tester.state(find.byType(SessionLivePage));

    tester.view.physicalSize = const Size(390, 844);
    await _settle(tester);
    expect(tester.state(find.byType(SessionLivePage)), same(state));
    expect(app.directory.opens, hasLength(1));
    expect(app.directory.handles.single.closes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
