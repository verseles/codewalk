import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/app_shell.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The catalog of the last [_open], to answer its later reads.
late CatalogSource _source;

/// The profiles and sources of the last [_open].
late CatalogRig _rig;

/// The workspace of [rig], without answering anything yet.
Future<AppDependencies> _pump(
  WidgetTester tester,
  CatalogRig rig, {
  Size size = const Size(390, 844),
  Locale? locale,
  double scale = 1,
  FakeActionSource? actions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final source =
      actions ??
      FakeActionSource(
        endpointSupport: const SessionActionSupport(SessionActionReason.none),
      );
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: LiveDirectory.new,
    sessionActionFactory: (profile, credential) => source,
  );
  if (locale != null) dependencies.preferences.setLocale(locale);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: CodeWalkV2Bootstrap(dependencies: dependencies),
    ),
  );
  // The saved servers load and the workspace picks one; its first read
  // stays open, so the list keeps a progress indicator running.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  return dependencies;
}

/// Opens the workspace on one saved profile whose list holds two projects
/// and a session the server attributed to none. A compact window opens its
/// list drawer unless [list] is false.
Future<(AppDependencies, V2Localizations)> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale? locale,
  double scale = 1,
  bool unread = false,
  bool list = true,
}) async {
  final rig = _rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final actions = FakeActionSource(
    endpointSupport: const SessionActionSupport(SessionActionReason.none),
  );
  final dependencies = await _pump(
    tester,
    rig,
    size: size,
    locale: locale,
    scale: scale,
    actions: actions,
  );
  // The single saved server opens without being chosen.
  final source = rig.sources.single;
  _source = source;
  if (unread) {
    actions.viewStates[source.row('one').info.ref.storageKey] =
        SessionViewState.unread;
  }
  source.respond([
    source.row('one', directory: '/work/alpha', title: 'One'),
    source.row('two', directory: '/work/beta', title: 'Two'),
    source.row('three', title: 'Three'),
  ]);
  await tester.pumpAndSettle();
  if (list) await showSessionList(tester);
  return (dependencies, dependencies.localizations.current);
}

/// Lets an open session start: its live view stays opening, so the frames
/// never settle.
Future<void> _settleSession(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final (width, pane) in const [
    (390.0, null),
    (599.0, null),
    (600.0, 260.0),
    (839.0, 260.0),
    (840.0, 300.0),
    (1280.0, 300.0),
  ]) {
    testWidgets(
      'the list is a drawer below 600 and a pane from there, $width',
      (tester) async {
        await _open(tester, size: Size(width, 800), list: false);
        final sidebar = find.byKey(const ValueKey('workspace-sidebar'));
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        if (pane == null) {
          // The chat takes the window and the list waits in the drawer.
          expect(sidebar, findsNothing);
          expect(find.byKey(const ValueKey('workspace-empty')), findsOneWidget);
          expect(find.text('One'), findsNothing);
          await showSessionList(tester);
        } else {
          expect(tester.getSize(sidebar).width, pane);
          // The detail keeps the rest, beside the list.
          expect(find.byKey(const ValueKey('workspace-empty')), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const ValueKey('workspace-empty'))).width,
            lessThanOrEqualTo(width - pane - 1),
          );
        }
        expect(find.text('One'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the narrowest pane leaves the detail its width', (tester) async {
    await _open(tester, size: const Size(600, 800));
    final sidebar = find.byKey(const ValueKey('workspace-sidebar'));
    // 600 leaves 339 for the detail beside a 260 pane.
    expect(tester.getSize(sidebar).width, 260);
    expect(
      tester.getSize(find.byType(WorkspaceHome)).width,
      greaterThanOrEqualTo(320),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('choosing a project shows its sessions', (tester) async {
    final (dependencies, l10n) = await _open(tester);
    // The first project the server returned is the shown one.
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('session-project-/work/beta')));
    await tester.pumpAndSettle();
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);

    // Choosing the shown project again changes nothing.
    await tester.tap(find.byKey(const ValueKey('session-project-/work/beta')));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);

    // The sessions without a project are a project of their own.
    await tester.tap(find.byKey(const ValueKey('session-project-')));
    await tester.pumpAndSettle();
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    expect(dependencies.sessions!.selectedProject, (project: null));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('another profile starts from its first project', (tester) async {
    final (dependencies, _) = await _open(tester);
    final controller = dependencies.sessions!;
    controller.selectProject(controller.sessions[1].info.project);
    expect(
      controller.selectedProject?.project?.canonicalDirectory,
      '/work/beta',
    );
    // The choice is dropped as soon as the profile changes, before the new
    // list arrives.
    await _rig.save('b');
    await controller.hosts.load();
    controller.selectProfile('profile_b').ignore();
    expect(controller.selectedProject, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tapped fallback project stays shown', (tester) async {
    final (dependencies, _) = await _open(tester);
    final controller = dependencies.sessions!;
    final source = _source;
    final one = source.row('one', directory: '/work/alpha', title: 'One');
    final two = source.row('two', directory: '/work/beta', title: 'Two');
    Future<void> reload(List<SessionSummary> rows) async {
      controller.refresh().ignore();
      await tester.pump();
      source.respond(rows);
      await tester.pumpAndSettle();
    }

    controller.selectProject(two.info.project);
    // Beta leaves the rows, so alpha is shown; tapping it records the choice
    // and beta's return does not take its place.
    await reload([one]);
    expect(controller.selectedProject, (project: one.info.project));
    controller.selectProject(one.info.project);
    await reload([one, two]);
    expect(controller.selectedProject, (project: one.info.project));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (name, size, locale, scale) in const [
    ('compact rtl', Size(390, 844), Locale('ar'), 1.0),
    ('wide rtl', Size(1280, 800), Locale('ar'), 1.0),
    ('compact 2x', Size(390, 844), Locale('en'), 2.0),
    ('medium 2x', Size(700, 800), Locale('en'), 2.0),
    ('wide 2x', Size(1280, 800), Locale('en'), 2.0),
  ]) {
    testWidgets('the workspace lays out without overflow, $name', (
      tester,
    ) async {
      final (dependencies, _) = await _open(
        tester,
        size: size,
        locale: locale,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      if (size.width >= 600) {
        final sidebar = tester.getRect(
          find.byKey(const ValueKey('workspace-sidebar')),
        );
        // The list stays on the start side: the right in a right-to-left
        // locale.
        if (locale.languageCode == 'ar') {
          expect(sidebar.right, size.width);
        } else {
          expect(sidebar.left, 0);
        }
      }
      final beta = find.byKey(const ValueKey('session-project-/work/beta'));
      await tester.scrollUntilVisible(
        beta,
        200,
        scrollable: find
            .ancestor(
              of: find.byKey(const ValueKey('sessions-profile')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(beta);
      await tester.pumpAndSettle();
      await tester.tap(beta);
      await tester.pumpAndSettle();
      expect(
        dependencies.sessions!.selectedProject?.project?.canonicalDirectory,
        '/work/beta',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('an unread row fits the narrow pane at 2x', (tester) async {
    await _open(
      tester,
      size: const Size(600, 800),
      locale: const Locale('ru'),
      scale: 2,
      unread: true,
    );
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
    expect(
      find.textContaining('прочитано', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('settings and servers are secondary pages, ${size.width}', (
      tester,
    ) async {
      final (dependencies, l10n) = await _open(tester, size: size);
      // A page pushed from the list is the top of the router's stack.
      String path() => dependencies.router.state.uri.path;

      await tester.tap(find.byKey(const ValueKey('sessions-settings')));
      await tester.pumpAndSettle();
      expect(path(), '/settings');
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsNothing);
      // The system back returns to the list instead of leaving the app.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(path(), '/sessions');

      await showSessionList(tester);
      await tester.tap(find.byKey(const ValueKey('sessions-hosts')));
      await tester.pumpAndSettle();
      expect(path(), '/hosts');
      // A page opened from a secondary page returns to it.
      await tester.tap(find.byIcon(Icons.qr_code).first);
      await tester.pumpAndSettle();
      expect(path(), '/pair');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(path(), '/hosts');
      await tester.tap(find.byKey(const ValueKey('workspace-back')));
      await tester.pumpAndSettle();
      expect(path(), '/sessions');
      await showSessionList(tester);
      expect(find.text('One'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a settings link with nothing under it goes back to the list', (
    tester,
  ) async {
    final (dependencies, _) = await _open(tester);
    dependencies.router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-back')));
    await tester.pumpAndSettle();
    expect(
      dependencies.router.routeInformationProvider.value.uri.path,
      '/sessions',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings opened by its shortcut go back to the list', (
    tester,
  ) async {
    final (dependencies, _) = await _open(tester, size: const Size(1280, 800));
    Future<void> shortcut() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await shortcut();
    expect(dependencies.router.state.uri.path, '/settings');
    // A second press does not stack another settings page.
    await shortcut();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(dependencies.router.state.uri.path, '/sessions');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the new-session shortcut opens the create', (tester) async {
    final (_, l10n) = await _open(tester, size: const Size(1280, 800));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsCreateTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tapped row opens its session and closes the drawer', (
    tester,
  ) async {
    final (dependencies, _) = await _open(tester);
    final one = _source.row('one');
    await tester.tap(
      find.byKey(ValueKey('live-open-${one.info.ref.storageKey}')),
    );
    await _settleSession(tester);
    expect(dependencies.router.state.uri.path, '/s/profile_a/ses_one');
    expect(find.byKey(const ValueKey('workspace-drawer')), findsOneWidget);
    expect(sessionListDrawerOpen(tester), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the row menu keeps the read-only history', (tester) async {
    final (dependencies, l10n) = await _open(tester);
    final one = _source.row('one');
    await tester.longPress(
      find.byKey(ValueKey('live-open-${one.info.ref.storageKey}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('history-open-${one.info.ref.storageKey}')),
      findsOneWidget,
    );
    expect(find.text(l10n.historyOpen), findsOneWidget);
    // Dismissing the menu neither opens nor selects the session.
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text(l10n.historyOpen), findsNothing);
    expect(dependencies.router.state.uri.path, '/sessions');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history is disabled while the catalog refreshes', (
    tester,
  ) async {
    final (dependencies, _) = await _open(tester);
    final one = _source.row('one');
    final refresh = dependencies.sessions!.refresh();
    await tester.pump();
    await tester.longPress(
      find.byKey(ValueKey('live-open-${one.info.ref.storageKey}')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final item = tester.widget<PopupMenuItem<dynamic>>(
      find.byKey(ValueKey('history-open-${one.info.ref.storageKey}')),
    );
    expect(item.enabled, isFalse);
    await tester.tapAt(Offset.zero);
    _source.respond([one]);
    await refresh;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final session in [false, true]) {
    testWidgets(
      'back at the root opens the drawer, then leaves, session $session',
      (tester) async {
        final pops = recordSystemPops(tester);
        final (dependencies, _) = await _open(tester, list: false);
        Future<void> settle() =>
            session ? _settleSession(tester) : tester.pumpAndSettle();
        if (session) {
          dependencies.router.go('/s/profile_a/ses_one');
          await settle();
        }
        final location = dependencies.router.state.uri.path;
        expect(sessionListDrawerOpen(tester), isFalse);
        expect(await tester.binding.handlePopRoute(), isTrue);
        await settle();
        expect(sessionListDrawerOpen(tester), isTrue);
        expect(pops, isEmpty);
        // With the drawer open, the back sends the app to the background.
        expect(await tester.binding.handlePopRoute(), isTrue);
        await settle();
        expect(pops, ['SystemNavigator.pop']);
        expect(dependencies.router.state.uri.path, location);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('a wide session goes to the background on back', (tester) async {
    final pops = recordSystemPops(tester);
    final (dependencies, _) = await _open(tester, size: const Size(1280, 800));
    dependencies.router.go('/s/profile_a/ses_one');
    await _settleSession(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _settleSession(tester);
    expect(pops, ['SystemNavigator.pop']);
    expect(dependencies.router.state.uri.path, '/s/profile_a/ses_one');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the home starts a new chat', (tester) async {
    final (_, l10n) = await _open(tester, list: false);
    expect(find.text(l10n.chatSelectOrCreate), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace-new-chat')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.sessionsCreateTitle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no saved server leads to the setup and reads nothing', (
    tester,
  ) async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    final dependencies = await _pump(tester, rig);
    final l10n = dependencies.localizations.current;
    expect(find.text(l10n.chatNoServerYet), findsOneWidget);
    expect(find.text(l10n.chatAddServerToStart), findsOneWidget);
    expect(rig.sources, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workspace-set-up-server')));
    await tester.pumpAndSettle();
    expect(dependencies.router.state.uri.path, '/hosts');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a server that does not answer keeps the ways out', (
    tester,
  ) async {
    final rig = CatalogRig();
    addTearDown(rig.dispose);
    await rig.save('a');
    final dependencies = await _pump(tester, rig);
    final l10n = dependencies.localizations.current;
    final source = rig.sources.single;
    source.fail(SessionCatalogFailure.connection);
    await tester.pumpAndSettle();
    expect(find.text('Server a'), findsOneWidget);
    expect(find.text(l10n.sessionsReadFailed), findsOneWidget);
    // Retry reads the list again from the same source.
    await tester.tap(find.byKey(const ValueKey('workspace-retry')));
    await tester.pumpAndSettle();
    expect(source.tasks, hasLength(2));
    source.fail(SessionCatalogFailure.connection);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-open-servers')));
    await tester.pumpAndSettle();
    expect(dependencies.router.state.uri.path, '/hosts');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
