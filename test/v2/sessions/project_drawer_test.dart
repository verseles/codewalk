import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/project_contexts_controller.dart';
import 'package:codewalk/features/sessions/project_picker_dialog.dart';
import 'package:codewalk/features/sessions/sessions_page.dart';
import 'package:codewalk/platform/sessions/project_workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_actions.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';
import 'workspace_support.dart';

/// The workspace over one saved server whose project contexts can be read
/// and saved, answered with [rows]; a compact window opens its drawer.
Future<(AppDependencies, CatalogRig, V2Localizations)> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale? locale,
  double scale = 1,
  List<SessionSummary> Function(CatalogSource source)? rows,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final actions = FakeActionSource(
    endpointSupport: const SessionActionSupport(SessionActionReason.none),
  );
  final dependencies = createAppDependencies(
    initialLink: Uri(path: '/sessions'),
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: LiveDirectory.new,
    sessionActionFactory: (profile, credential) => actions,
    metadataStore: V2MetadataStore(backend: FakeMetadataBackend()),
  );
  if (locale != null) dependencies.preferences.setLocale(locale);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
      child: CodeWalkV2Bootstrap(dependencies: dependencies),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  final source = rig.sources.single;
  source.respond(
    rows?.call(source) ??
        [
          source.row('one', directory: '/work/alpha', title: 'One'),
          source.row('two', directory: '/work/beta', title: 'Two'),
          source.row('three', directory: '/work/alpha', title: 'Three'),
        ],
  );
  await tester.pumpAndSettle();
  await showSessionList(tester);
  await tester.pumpAndSettle();
  return (dependencies, rig, dependencies.localizations.current);
}

ProjectContextsController _contexts(WidgetTester tester) =>
    tester.element(find.byType(SessionsPage)).read<ProjectContextsController>();

/// The row of session [id] in the shown project's list.
Finder _row(CatalogRig rig, String id) => find.byKey(
  ValueKey('live-open-${rig.sources.single.row(id).info.ref.storageKey}'),
);

Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the shown project lists its rows under the open projects', (
    tester,
  ) async {
    final (dependencies, _, l10n) = await _open(tester);
    final contexts = _contexts(tester);
    expect(contexts.active, '/work/alpha');
    expect(find.byKey(const ValueKey('project-title')), findsOneWidget);
    expect(find.text(l10n.workspaceOpenProjects), findsOneWidget);
    expect(
      find.byKey(const ValueKey('project-context-/work/alpha')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('project-count-/work/alpha')))
          .data,
      '2',
    );
    expect(find.text('One'), findsWidgets);
    expect(find.text('Three'), findsWidgets);
    // Another project's session is not a row of this list.
    expect(
      find.byKey(ValueKey(dependencies.sessions!.sessions.first.info.ref)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('live-open-profile_a/profile_a/ses_two')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await _closeApp(tester);
  });

  testWidgets(
    'switching projects keeps the left one as a preview and closing it '
    'keeps the last one open',
    (tester) async {
      final (dependencies, _, l10n) = await _open(tester);
      final contexts = _contexts(tester);
      expect(await contexts.openContext('/work/beta'), isTrue);
      await tester.pumpAndSettle();
      expect(dependencies.sessions!.directory, '/work/beta');
      // The project left previews its last rows.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'project-preview-',
              ),
        ),
        findsNWidgets(2),
      );
      // A tap on a project row shows it.
      await tester.tap(
        find.byKey(const ValueKey('project-context-/work/alpha')),
      );
      await tester.pumpAndSettle();
      expect(contexts.active, '/work/alpha');

      // The trailing menu closes a project; the last one stays open.
      final menu = find.descendant(
        of: find.byKey(const ValueKey('project-row-/work/beta')),
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text(l10n.chatCloseProject('beta')), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('project-close-/work/beta')));
      await tester.pumpAndSettle();
      expect(contexts.open, ['/work/alpha']);
      expect(contexts.closed, ['/work/beta']);

      // A long press opens the same menu and never switches.
      await tester.longPress(
        find.byKey(const ValueKey('project-context-/work/alpha')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('project-close-/work/alpha')));
      await tester.pumpAndSettle();
      expect(contexts.open, ['/work/alpha']);
      expect(
        find.text(l10n.projectProviderErrorAtLeastOneContext),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _closeApp(tester);
    },
  );

  testWidgets('each project shows again what it last showed', (tester) async {
    final (dependencies, rig, _) = await _open(
      tester,
      size: const Size(1280, 800),
    );
    final router = dependencies.router;
    String path() => router.routeInformationProvider.value.uri.path;
    final one = rig.sources.single.row('one').info.ref;
    // A session of alpha is shown, then beta from the list.
    router.go('/s/profile_a/${one.nativeId}');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final contexts = _contexts(tester);
    expect(contexts.viewOf('/work/alpha'), one);
    expect(await contexts.openContext('/work/beta'), isTrue);
    expect(await contexts.activate('/work/alpha'), isTrue);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('project-context-/work/beta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Beta never showed a session: its list (or draft) shows.
    expect(path(), '/sessions');
    expect(contexts.active, '/work/beta');
    await tester.tap(find.byKey(const ValueKey('project-context-/work/alpha')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(path(), '/s/profile_a/${one.nativeId}');
    expect(contexts.active, '/work/alpha');
    await _closeApp(tester);
  });

  testWidgets('closing the shown project shows the one that remains', (
    tester,
  ) async {
    final (dependencies, rig, _) = await _open(
      tester,
      size: const Size(1280, 800),
    );
    final router = dependencies.router;
    String path() => router.routeInformationProvider.value.uri.path;
    final contexts = _contexts(tester);
    final two = rig.sources.single.row('two').info.ref;
    expect(await contexts.openContext('/work/beta'), isTrue);
    router.go('/s/profile_a/${two.nativeId}');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(contexts.viewOf('/work/beta'), two);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('project-row-/work/beta')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    // The open session's live view keeps frames running: pump, not settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('project-close-/work/beta')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(contexts.active, '/work/alpha');
    expect(path(), '/sessions');
    await _closeApp(tester);
  });

  testWidgets('the keyboard highlight stays in view', (tester) async {
    final (_, rig, _) = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('project-title')));
    await tester.pumpAndSettle();
    rig.sources.single.projectReads.single.completion.complete([
      for (var i = 0; i < 40; i++)
        ProjectRef(const HostId('profile_a'), '/srv/p$i'),
    ]);
    await tester.pumpAndSettle();
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // The highlight moved past the open project to the 30th server project.
    final row = find.byKey(const ValueKey('project-picker-/srv/p29'));
    final list = find.descendant(
      of: find.byType(ProjectPickerDialog),
      matching: find.byType(Scrollable),
    );
    final viewport = tester.getRect(list.last);
    final rect = tester.getRect(row);
    expect(rect.top, greaterThanOrEqualTo(viewport.top - 1));
    expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 1));
    // A new query highlights its first result and shows the top.
    await tester.enterText(
      find.byKey(const ValueKey('project-picker-field')),
      '/srv/p',
    );
    // An absolute path is not searched on the server.
    await tester.pumpAndSettle();
    final top = tester.getRect(
      find.byKey(const ValueKey('project-picker-/srv/p0')),
    );
    expect(top.top, greaterThanOrEqualTo(viewport.top - 1));
    await tester.enterText(
      find.byKey(const ValueKey('project-picker-field')),
      '',
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // Wrapping from the last result back to the first keeps it in view.
    for (var i = 0; i < 11; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final first = tester.getRect(
      find.byKey(const ValueKey('project-picker-/work/alpha')),
    );
    expect(first.top, greaterThanOrEqualTo(viewport.top - 1));
    expect(first.bottom, lessThanOrEqualTo(viewport.bottom + 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _closeApp(tester);
  });

  testWidgets('search, the filter and sort menu and pins shape the list', (
    tester,
  ) async {
    final (dependencies, rig, l10n) = await _open(
      tester,
      rows: (source) => [
        source.row('a', directory: '/work/alpha', title: 'Bravo task'),
        source.row('b', directory: '/work/alpha', title: 'alpha notes'),
        source.row('c', directory: '/work/alpha', title: 'Charlie task'),
      ],
    );
    double top(String text) => tester.getTopLeft(find.text(text).last).dy;
    expect(top('Bravo task'), lessThan(top('Charlie task')));

    // The search is an icon until used; typing filters at once.
    expect(find.byKey(const ValueKey('sessions-search-field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sessions-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sessions-search-field')),
      'TASK',
    );
    await tester.pumpAndSettle();
    // Recent stays as it is; the project's rows follow the query.
    expect(_row(rig, 'b'), findsNothing);
    expect(_row(rig, 'a'), findsOneWidget);
    // Escape clears the query and collapses the field.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sessions-search-field')), findsNothing);
    expect(_row(rig, 'b'), findsOneWidget);

    // One menu holds the filter and the sort; its badge names both.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('sessions-filter-badge')))
          .data,
      'A/R',
    );
    await tester.tap(find.byKey(const ValueKey('sessions-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sessions-sort-title')));
    await tester.pumpAndSettle();
    expect(top('alpha notes'), lessThan(top('Bravo task')));
    expect(top('Bravo task'), lessThan(top('Charlie task')));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('sessions-filter-badge')))
          .data,
      'A/T',
    );

    // A pinned session leads its project whatever the sort.
    final charlie = rig.sources.single.row('c').info.ref.storageKey;
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('session-actions-$charlie')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('session-pin-$charlie')));
    await tester.pumpAndSettle();
    expect(top('Charlie task'), lessThan(top('alpha notes')));
    expect(find.byKey(ValueKey('session-pinned-$charlie')), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byKey(ValueKey('session-pinned-$charlie')))
          .semanticLabel,
      l10n.sessionsPinnedMark,
    );
    expect(dependencies.sessions!.directory, '/work/alpha');
    expect(tester.takeException(), isNull);
    await _closeApp(tester);
  });

  testWidgets('a kept query reopens the search expanded', (tester) async {
    final (_, rig, _) = await _open(tester);
    await _contexts(
      tester,
    ).setPreferences(const SessionListPreferences(query: 'thr'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sessions-search-field')), findsOneWidget);
    expect(_row(rig, 'one'), findsNothing);
    expect(_row(rig, 'three'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _closeApp(tester);
  });

  testWidgets('recent roots, the current accent and unread emphasis', (
    tester,
  ) async {
    final idle = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    final (_, rig, l10n) = await _open(
      tester,
      rows: (source) => [
        SessionSummary(
          info: source
              .row('done', directory: '/work/alpha', title: 'Done')
              .info,
          updatedAt: DateTime.utc(2026, 10, 12, 9),
          view: SessionViewMarker(idleAt: idle),
          outcome: SessionOutcome.succeeded,
        ),
        source.row(
          'kid',
          directory: '/work/alpha',
          title: 'Kid',
          parent: 'done',
        ),
      ],
    );
    expect(find.text(l10n.chatRecentSessions), findsOneWidget);
    final done = rig.sources.single.row('done').info.ref.storageKey;
    final kid = rig.sources.single.row('kid').info.ref.storageKey;
    expect(find.byKey(ValueKey('recent-$done')), findsOneWidget);
    // Only roots are recent.
    expect(find.byKey(ValueKey('recent-$kid')), findsNothing);
    expect(find.byKey(ValueKey('session-emphasis-$done')), findsOneWidget);
    expect(find.byKey(ValueKey('session-emphasis-$kid')), findsNothing);
    expect(tester.takeException(), isNull);
    await _closeApp(tester);
  });

  testWidgets('diff-stat pseudo summaries are never rendered', (tester) async {
    await _open(
      tester,
      rows: (source) => [
        SessionSummary(
          info: SessionInfo(
            ref: source.row('one').info.ref,
            title: 'One',
            ownership: const OwnershipInfo.unknown(reason: 'test'),
            lineage: const SessionLineage(),
            project: const ProjectRef(HostId('profile_a'), '/work/alpha'),
            metadata: CanonicalValue({
              'summary': {'additions': 12, 'deletions': 3},
            }),
          ),
          updatedAt: DateTime.utc(2026, 10, 12),
        ),
      ],
    );
    expect(find.text('One'), findsWidgets);
    expect(find.textContaining('additions'), findsNothing);
    expect(find.textContaining('deletions'), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('the project title opens the picker; a result opens at once', (
    tester,
  ) async {
    final (_, rig, l10n) = await _open(tester);
    final contexts = _contexts(tester);
    await tester.tap(find.byKey(const ValueKey('project-title')));
    await tester.pumpAndSettle();
    // A compact window gives the picker the whole screen.
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getSize(find.byType(ProjectPickerDialog)).width, 390);
    rig.sources.single.projectReads.single.completion.complete([
      const ProjectRef(HostId('profile_a'), '/work/beta'),
      const ProjectRef(HostId('profile_a'), '/srv/tools'),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('project-picker-field')),
      'too',
    );
    await tester.pump(const Duration(milliseconds: 300));
    rig.sources.single.findReads.single.$3.completion.complete([]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('project-picker-/work/beta')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('project-picker-/srv/tools')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(contexts.active, '/srv/tools');
    expect(contexts.open, ['/work/alpha', '/srv/tools']);
    expect(find.text(l10n.chatChooseDirectory), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('a typed path waits for its IME; Escape dismisses', (
    tester,
  ) async {
    final (_, rig, _) = await _open(tester, size: const Size(1280, 800));
    final contexts = _contexts(tester);
    await tester.tap(find.byKey(const ValueKey('project-title')));
    await tester.pumpAndSettle();
    // A desktop window centers a bounded dialog.
    expect(
      tester.getSize(find.byType(ProjectPickerDialog)).width,
      lessThanOrEqualTo(560),
    );
    await tester.showKeyboard(
      find.byKey(const ValueKey('project-picker-field')),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '/opt/x',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 4, end: 6),
      ),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    expect(rig.sources.single.locationReads, isEmpty);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '/opt/x',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    final (asked, location) = rig.sources.single.locationReads.single;
    expect(asked, '/opt/x');
    location.completion.complete(
      const ProjectRef(HostId('profile_a'), '/opt/x'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(contexts.active, '/opt/x');

    await tester.tap(find.byKey(const ValueKey('project-title')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('the browser walks folders in the same dialog', (tester) async {
    final (_, rig, _) = await _open(tester);
    final contexts = _contexts(tester);
    await tester.tap(find.byKey(const ValueKey('project-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-picker-browse')));
    // The listing shows a running indicator until it is answered.
    await tester.pump();
    await tester.pump();
    final source = rig.sources.single;
    expect(source.listReads.single.$2, '/work/alpha');
    source.listReads.single.$3.completion.complete([
      FileEntry(
        ref: FileRef(
          project: const ProjectRef(HostId('profile_a'), '/work/alpha'),
          path: 'lib',
        ),
        kind: const OpenValue.known(FileKind.directory),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('project-picker-folder-/work/alpha/lib')),
    );
    await tester.pump();
    await tester.pump();
    expect(source.listReads.last.$2, '/work/alpha/lib');
    source.listReads.last.$3.completion.complete([]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project-picker-open-browsed')));
    await tester.pump();
    await tester.pump();
    source.locationReads.last.$2.completion.complete(
      const ProjectRef(HostId('profile_a'), '/work/alpha/lib'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(contexts.active, '/work/alpha/lib');
    await _closeApp(tester);
  });

  for (final width in const [360.0, 412.0, 600.0, 839.0, 840.0, 1280.0]) {
    for (final locale in const [Locale('en'), Locale('ar'), Locale('ur')]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('the drawer fits $width ${locale.languageCode} ${scale}x', (
          tester,
        ) async {
          await _open(
            tester,
            size: Size(width, 800),
            locale: locale,
            scale: scale,
            rows: (source) => [
              source.row(
                'one',
                directory:
                    '/home/user/a/very/long/workspace/path/to/project-alpha',
                title: 'One ${'long title '.padRight(120, 'x')}',
              ),
              source.row('two', directory: '/srv/beta', title: 'Two'),
            ],
          );
          final contexts = _contexts(tester);
          expect(await contexts.openContext('/srv/beta'), isTrue);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('project-title')), findsOneWidget);
          expect(contexts.open, hasLength(2));
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('project-context-/srv/beta')),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(SessionsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(tester.takeException(), isNull);
          await _closeApp(tester);
        });
      }
    }
  }
}
