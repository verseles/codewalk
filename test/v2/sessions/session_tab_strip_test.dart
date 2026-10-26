import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

typedef _App = ({
  AppDependencies dependencies,
  V2Localizations l10n,
  CatalogRig rig,
  LiveDirectory directory,
});

/// Saved tabs outlive the app: every launch of a test reads the same store.
void _useMemoryPreferences() {
  final platform = SharedPreferencesAsyncPlatform.instance;
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = platform);
}

/// Launches the app on [link] with one saved profile, `profile_a`.
Future<_App> _launch(
  WidgetTester tester,
  String link, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens each of [ids] in turn, granting its lease, and ends on the last.
Future<void> _visit(WidgetTester tester, _App app, List<String> ids) async {
  final source = app.rig.sources.single;
  for (final id in ids) {
    app.dependencies.router.go('/s/profile_a/ses_$id');
    await _settle(tester);
    final ref = source.row(id).info.ref;
    // A session of a project the list does not show is read on its own.
    for (final (read, task) in source.reads.toList()) {
      if (read != ref || task.completion.isCompleted) continue;
      task.completion.complete(
        source.served.firstWhere((row) => row.info.ref == ref),
      );
      await _settle(tester);
    }
    if (app.directory.handles.every((handle) => handle.session != ref)) {
      app.directory.grant(ref);
      await tester.pump();
    }
  }
}

SessionRef _ref(_App app, String id) => app.rig.sources.single.row(id).info.ref;

Finder _tab(_App app, String id) =>
    find.byKey(ValueKey('session-tab-${_ref(app, id).storageKey}'));

String _location(_App app) =>
    app.dependencies.router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('the strip shows the tabs of the shown project and switches', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([
      source.row('one', title: 'One', directory: '/work/a'),
      source.row('two', title: 'Two', directory: '/work/a'),
      source.row('other', title: 'Other', directory: '/work/b'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'other', 'two']);

    expect(_tab(app, 'one'), findsOneWidget);
    expect(_tab(app, 'two'), findsOneWidget);
    // Another project keeps its own set.
    expect(_tab(app, 'other'), findsNothing);

    await tester.tap(_tab(app, 'one'));
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_one');
    // The view of the first tab was kept, not opened again.
    expect(app.directory.opens, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tab shown again keeps the reader\'s place', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one']);
    final one = _ref(app, 'one');
    app.directory.handles.single.emit(
      SessionLiveView(
        session: one,
        phase: SessionLivePhase.live,
        state: liveState(
          one,
          items: [
            for (var i = 0; i < 40; i++)
              AssistantText(
                meta: liveMeta(one, 'a$i'),
                text: 'row $i',
                complete: true,
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    ScrollController list() => tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    final place = list().offset;
    expect(place, lessThan(list().position.maxScrollExtent));

    await _visit(tester, app, ['two', 'one']);
    await tester.pumpAndSettle();
    expect(list().offset, place);
    expect(find.byKey(const ValueKey('live-jump-latest')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tab shown again keeps the reader\'s place in older rows', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one']);
    final one = _ref(app, 'one');
    final handle = app.directory.handles.single;
    SessionLiveView view(int from) => SessionLiveView(
      session: one,
      phase: SessionLivePhase.live,
      state: liveState(
        one,
        items: [
          for (var i = from; i < 60; i++)
            AssistantText(
              meta: liveMeta(one, 'a$i'),
              text: 'row $i',
              complete: true,
            ),
        ],
      ),
    );
    handle.emit(view(30));
    await tester.pumpAndSettle();
    // Older rows page in above the rows the timeline first showed.
    handle.emit(view(0));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('row 5'),
      find.byType(CustomScrollView),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    final place = tester.getTopLeft(find.text('row 5')).dy;

    await _visit(tester, app, ['two', 'one']);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row 5')).dy, place);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('content that arrives while a tab is hidden is marked', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one']);
    final one = _ref(app, 'one');
    final handle = app.directory.handles.single;
    SessionLiveView view(int count) => SessionLiveView(
      session: one,
      phase: SessionLivePhase.live,
      state: liveState(
        one,
        items: [
          for (var i = 0; i < count; i++)
            AssistantText(
              meta: liveMeta(one, 'a$i'),
              text: 'row $i',
              complete: true,
            ),
        ],
      ),
    );
    handle.emit(view(40));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mark_chat_unread), findsNothing);

    await _visit(tester, app, ['two']);
    handle.emit(view(41));
    await tester.pump();
    await _visit(tester, app, ['one']);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mark_chat_unread), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a turn that ends while a tab is hidden is revealed', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one']);
    final one = _ref(app, 'one');
    final handle = app.directory.handles.single;
    SessionLiveView view(List<TimelineItem> items) => SessionLiveView(
      session: one,
      phase: SessionLivePhase.live,
      state: liveState(
        one,
        items: items,
        execution: const ExecutionState(
          kind: OpenValue.known(ExecutionKind.idle),
        ),
      ),
    );
    final first = [
      AssistantText(meta: liveMeta(one, 'a0'), text: 'short', complete: true),
    ];
    handle.emit(view(first));
    await tester.pumpAndSettle();

    await _visit(tester, app, ['two']);
    // A whole turn runs and ends while the tab is hidden.
    handle.emit(
      view([
        ...first,
        AssistantText(
          meta: liveMeta(one, 'a1'),
          text: 'a long answer ' * 200,
          complete: true,
        ),
      ]),
    );
    await tester.pump();
    await _visit(tester, app, ['one']);
    await tester.pumpAndSettle();
    final list = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    // The answer starts at the top of the viewport, not at its end.
    expect(list.offset, lessThan(list.position.maxScrollExtent));
    expect(find.byKey(const ValueKey('live-jump-latest')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing the shown tab goes to its neighbour; undo restores', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([
      source.row('one', title: 'One'),
      source.row('two', title: 'Two'),
      source.row('three', title: 'Three'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two', 'three', 'two']);
    final tabs = app.dependencies.sessionTabs!;

    await tester.tap(
      find.byKey(ValueKey('session-tab-close-${_ref(app, 'two').storageKey}')),
    );
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_three'],
    );
    // The next tab of the project takes its place.
    expect(_location(app), '/s/profile_a/ses_three');
    expect(find.text(app.l10n.sessionTabClosedMessage('Two')), findsOneWidget);

    await tester.tap(find.text(app.l10n.sessionTabUndo));
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_two', 'ses_three'],
    );
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing a background tab stays; undo puts it back there', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one', title: 'One'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two']);
    final tabs = app.dependencies.sessionTabs!;

    await tester.tap(
      find.byKey(ValueKey('session-tab-close-${_ref(app, 'one').storageKey}')),
    );
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.tap(find.text(app.l10n.sessionTabUndo));
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_two'],
    );
    expect(_location(app), '/s/profile_a/ses_two');
    expect(tabs.selectedFor(_ref(app, 'two').host), _ref(app, 'two'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('undo after moving on puts the tab back without showing it', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([
      source.row('one'),
      source.row('two', title: 'Two'),
      source.row('three'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two', 'three', 'two']);
    final tabs = app.dependencies.sessionTabs!;

    await tester.tap(
      find.byKey(ValueKey('session-tab-close-${_ref(app, 'two').storageKey}')),
    );
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_three');
    // The reader moves on before using the undo.
    await _visit(tester, app, ['one']);
    await tester.tap(find.text(app.l10n.sessionTabUndo));
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_two', 'ses_three'],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    expect(tabs.selectedFor(_ref(app, 'one').host), _ref(app, 'one'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('moving on while undo saves keeps the new place', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([
      source.row('one'),
      source.row('two', title: 'Two'),
      source.row('three'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two', 'three', 'two']);
    final tabs = app.dependencies.sessionTabs!;

    await tester.tap(
      find.byKey(ValueKey('session-tab-close-${_ref(app, 'two').storageKey}')),
    );
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_three');
    await tester.tap(find.text(app.l10n.sessionTabUndo));
    // The reader moves on before the undo is saved.
    app.dependencies.router.go('/s/profile_a/ses_one');
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_two', 'ses_three'],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    expect(tabs.selectedFor(_ref(app, 'one').host), _ref(app, 'one'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing the shown tab and its neighbour at once lands open', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two'), source.row('three')]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two', 'three', 'two']);

    // Both closes start before either is saved.
    await tester.tap(
      find.byKey(ValueKey('session-tab-close-${_ref(app, 'two').storageKey}')),
    );
    await tester.tap(
      find.byKey(
        ValueKey('session-tab-close-${_ref(app, 'three').storageKey}'),
      ),
    );
    await _settle(tester);
    expect(
      [for (final tab in app.dependencies.sessionTabs!.tabs) tab.ref.nativeId],
      ['ses_one'],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    expect(find.byType(SessionLivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the close key closes the current tab', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_one');
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(
      [for (final tab in app.dependencies.sessionTabs!.tabs) tab.ref.nativeId],
      ['ses_one'],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('holding Ctrl cycles the recent tabs and opens on release', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_two');
    final source = app.rig.sources.single;
    source.respond([
      source.row('one', title: 'One'),
      source.row('two', title: 'Two'),
      source.row('three', title: 'Three'),
    ]);
    await _settle(tester);
    // Most recent first: three, one, two.
    await _visit(tester, app, ['two', 'one', 'three']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final switcher = find.byKey(const ValueKey('session-tab-switcher'));
    expect(switcher, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(switcher, findsNothing);
    expect(_location(app), '/s/profile_a/ses_two');

    // A tab chosen on the strip ends the switcher; the release opens
    // nothing else.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.tap(_tab(app, 'two'));
    await tester.pump();
    expect(switcher, findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_two');

    // Escape leaves the shown tab.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(switcher, findsNothing);
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a held Tab keeps cycling; leaving the app ends the switcher', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_two');
    final source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two'), source.row('three')]);
    await _settle(tester);
    // Most recent first: three, one, two.
    await _visit(tester, app, ['two', 'one', 'three']);
    final switcher = find.byKey(const ValueKey('session-tab-switcher'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_two');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(switcher, findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(switcher, findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a compact window lists the recent tabs in a sheet', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(
      tester,
      '/s/profile_a/ses_one',
      size: const Size(390, 844),
    );
    final source = app.rig.sources.single;
    source.respond([
      source.row('one', title: 'One', directory: '/work/a'),
      source.row('two', title: 'Two', directory: '/work/b'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['one', 'two']);

    await tester.tap(find.byKey(const ValueKey('session-tabs-recent-button')));
    await _settle(tester);
    // The sheet holds every tab of the server, whatever its project.
    final one = find.byKey(
      ValueKey('session-tabs-recent-${_ref(app, 'one').storageKey}'),
    );
    expect(one, findsOneWidget);
    await tester.tap(one);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_one');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a restart restores the tabs and returns to the selected one', (
    tester,
  ) async {
    _useMemoryPreferences();
    var app = await _launch(tester, '/s/profile_a/ses_two');
    var source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    await _visit(tester, app, ['two', 'one']);
    final before = app.dependencies.sessionTabs!.tabs;
    await tester.pumpWidget(const SizedBox.shrink());

    app = await _launch(tester, '/sessions');
    source = app.rig.sources.single;
    source.respond([source.row('one'), source.row('two')]);
    await _settle(tester);
    // The same tabs in the same order; showing one again only marks it
    // opened.
    expect(
      [for (final tab in app.dependencies.sessionTabs!.tabs) tab.ref],
      [for (final tab in before) tab.ref],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    expect(find.byType(SessionLivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a launch on another page leaves the list on the list', (
    tester,
  ) async {
    _useMemoryPreferences();
    var app = await _launch(tester, '/s/profile_a/ses_one');
    app.rig.sources.single.respond([app.rig.sources.single.row('one')]);
    await _settle(tester);
    await _visit(tester, app, ['one']);
    await tester.pumpWidget(const SizedBox.shrink());

    app = await _launch(tester, '/settings');
    app.dependencies.router.go('/sessions');
    await _settle(tester);
    expect(_location(app), '/sessions');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (label, direction, scale) in [
    ('RTL', TextDirection.rtl, 1.0),
    ('2x text', TextDirection.ltr, 2.0),
  ]) {
    testWidgets('the strip lays out in $label on a phone', (tester) async {
      _useMemoryPreferences();
      final app = await _launch(
        tester,
        '/s/profile_a/ses_one',
        size: const Size(390, 844),
      );
      final source = app.rig.sources.single;
      source.respond([
        source.row('one', title: 'A long session title ' * 4),
        source.row('two', title: 'Two'),
      ]);
      await _settle(tester);
      await _visit(tester, app, ['one', 'two']);
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQueryData.fromView(
              tester.view,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: CodeWalkV2Bootstrap(dependencies: app.dependencies),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
