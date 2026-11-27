import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/project_icon_view.dart';
import 'package:codewalk/features/sessions/session_live_page.dart';
import 'package:codewalk/features/sessions/session_tab_chip.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_live_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../hosts/fakes.dart';
import '../storage/storage_fakes.dart';
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
  V2MetadataStore? store,
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
    metadataStore: store,
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

Future<void> _middleClose(WidgetTester tester, _App app, String id) async {
  await tester.ensureVisible(_tab(app, id));
  await tester.tap(
    _tab(app, id),
    kind: PointerDeviceKind.mouse,
    buttons: kMiddleMouseButton,
  );
}

String _location(_App app) =>
    app.dependencies.router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('project icon reaches tabs and recent rows at ${size.width}', (
      tester,
    ) async {
      _useMemoryPreferences();
      final app = await _launch(tester, '/s/profile_a/ses_one', size: size);
      final source = app.rig.sources.single;
      source.respond([source.row('one', directory: '/work/a')]);
      await _settle(tester);
      await _visit(tester, app, ['one']);
      final uri = Uri.dataFromString(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><circle cx="8" cy="8" r="8" fill="red"/></svg>',
        mimeType: 'image/svg+xml',
      );
      source.projectReads.single.completion.complete([
        ProjectInfo(ProjectRef(source.harness.host, '/work/a'), icon: uri),
      ]);
      await _settle(tester);
      final image = find.descendant(
        of: _tab(app, 'one'),
        matching: find.byType(ProjectIconView),
      );
      expect(tester.widget<ProjectIconView>(image).source, uri);
      final tabs = app.dependencies.sessionTabs!;
      final tab = tabs.tabs.single;
      expect(await tabs.setIcon(tab, 'bug'), isTrue);
      await _settle(tester);
      expect(
        find.descendant(
          of: _tab(app, 'one'),
          matching: find.byIcon(Symbols.bug_report),
        ),
        findsOneWidget,
      );
      expect(image, findsNothing);
      expect(await tabs.setIcon(tab, null), isTrue);
      await _settle(tester);
      expect(image, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('session-tabs-recent-button')),
      );
      await _settle(tester);
      final recent = find.byKey(
        ValueKey('session-tabs-recent-${_ref(app, 'one').storageKey}'),
      );
      expect(
        tester
            .widget<ProjectIconView>(
              find.descendant(
                of: recent,
                matching: find.byType(ProjectIconView),
              ),
            )
            .source,
        uri,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'the strip shows all server tabs grouped by project and switches',
    (tester) async {
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
      // Other projects share the same server strip.
      expect(_tab(app, 'other'), findsOneWidget);

      await tester.tap(_tab(app, 'one'));
      await _settle(tester);
      expect(_location(app), '/s/profile_a/ses_one');
      // The view of the first tab was kept, not opened again.
      expect(app.directory.opens, hasLength(3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in const [Size(1280, 800), Size(390, 844)]) {
    testWidgets('tabs stand on the strip\'s bottom edge at ${size.width}', (
      tester,
    ) async {
      _useMemoryPreferences();
      final app = await _launch(tester, '/s/profile_a/ses_one', size: size);
      final source = app.rig.sources.single;
      source.respond([source.row('one', title: 'One', directory: '/work/a')]);
      await _settle(tester);
      await _visit(tester, app, ['one']);
      // The selected tab meets the page below with no gap (owner, beta.21).
      final strip = tester.getRect(find.byKey(const ValueKey('session-tabs')));
      expect(tester.getRect(_tab(app, 'one')).bottom, strip.bottom);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
    expect(find.byIcon(Symbols.mark_chat_unread), findsNothing);

    await _visit(tester, app, ['two']);
    handle.emit(view(41));
    await tester.pump();
    await _visit(tester, app, ['one']);
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.mark_chat_unread), findsOneWidget);
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

    await _middleClose(tester, app, 'two');
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_three'],
    );
    // The next displayed tab takes its place in stable order; Undo never
    // navigates.
    expect(_location(app), '/s/profile_a/ses_three');
    expect(find.text(app.l10n.sessionTabClosedMessage('Two')), findsOneWidget);

    await tester.tap(find.text(app.l10n.sessionTabUndo));
    await _settle(tester);
    expect(
      [for (final tab in tabs.tabs) tab.ref.nativeId],
      ['ses_one', 'ses_two', 'ses_three'],
    );
    expect(_location(app), '/s/profile_a/ses_three');
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

    await _middleClose(tester, app, 'one');
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

    await _middleClose(tester, app, 'two');
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

    await _middleClose(tester, app, 'two');
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
    await _middleClose(tester, app, 'two');
    await _middleClose(tester, app, 'three');
    await _settle(tester);
    expect(
      [for (final tab in app.dependencies.sessionTabs!.tabs) tab.ref.nativeId],
      ['ses_one'],
    );
    expect(_location(app), '/s/profile_a/ses_one');
    expect(find.byType(SessionLivePage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the close key on a shown child returns to its parent', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/sessions');
    final source = app.rig.sources.single;
    source.respond([
      source.row('parent', title: 'Parent', directory: '/w'),
      source.row('kid', title: 'Kid', directory: '/w', parent: 'parent'),
    ]);
    await _settle(tester);
    await _visit(tester, app, ['parent']);
    final tabs = app.dependencies.sessionTabs!;
    expect([for (final tab in tabs.tabs) tab.ref.nativeId], ['ses_parent']);

    // The child is visited, never tabbed: the strip shows the parent's tab
    // as the selected one while the child is on screen.
    app.dependencies.router.go('/s/profile_a/ses_kid');
    await _settle(tester);
    expect(find.byType(SessionLivePage), findsOneWidget);
    expect([for (final tab in tabs.tabs) tab.ref.nativeId], ['ses_parent']);
    expect(tabs.selectedFor(const HostId('profile_a'))?.nativeId, 'ses_parent');
    expect(
      tester
          .widget<SessionTabChip>(
            find.ancestor(
              of: _tab(app, 'parent'),
              matching: find.byType(SessionTabChip),
            ),
          )
          .selected,
      isTrue,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_parent');
    expect([for (final tab in tabs.tabs) tab.ref.nativeId], ['ses_parent']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a saved child tab is not a launch tab; the list stays', (
    tester,
  ) async {
    // A tab an older build saved for the child, selected on its server.
    final backend = FakeMetadataBackend();
    final store = V2MetadataStore(backend: backend);
    const ref = SessionRef(
      HostId('profile_a'),
      HarnessInstanceId('profile_a'),
      'ses_kid',
    );
    backend.values[SessionTabsStore.key] = SessionTabsStore.encode(
      SessionTabsState(
        tabs: const [
          SessionTab(
            ref: ref,
            project: ProjectRef(HostId('profile_a'), '/w'),
            title: 'Kid',
            lastOpenedAtMs: 1,
          ),
        ],
        selected: {const HostId('profile_a'): ref},
      ),
    );
    final app = await _launch(tester, '/sessions', store: store);
    final source = app.rig.sources.single;
    source.respond([
      source.row('parent', title: 'Parent', directory: '/w'),
      source.row('kid', title: 'Kid', directory: '/w', parent: 'parent'),
    ]);
    await _settle(tester);
    // The saved child never navigates: the list stays on the list, and the
    // record leaves once the rows prove the child.
    expect(_location(app), '/sessions');
    expect(
      app.dependencies.sessionTabs!.tabs.any((tab) => tab.ref == ref),
      isFalse,
    );
    expect(app.dependencies.sessionTabs!.takeRemoved(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the close key closes the current tab', (tester) async {
    _useMemoryPreferences();
    final app = await _launch(tester, '/s/profile_a/ses_three');
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
    // The modal barrier also covers the shell-owned toolbar.
    await tester.tapAt(const Offset(195, 20));
    await _settle(tester);
    expect(one, findsNothing);
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.tap(find.byKey(const ValueKey('session-tabs-recent-button')));
    await _settle(tester);
    expect(one, findsOneWidget);
    await tester.tap(one);
    await _settle(tester);
    expect(_location(app), '/s/profile_a/ses_one');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final newDraft in [false, true]) {
    testWidgets(
      'cold child restore respects primary tabs and new draft ($newDraft)',
      (tester) async {
        final backend = FakeMetadataBackend();
        final store = V2MetadataStore(backend: backend);
        const root = SessionRef(
          HostId('profile_a'),
          HarnessInstanceId('profile_a'),
          'ses_parent',
        );
        const child = SessionRef(
          HostId('profile_a'),
          HarnessInstanceId('profile_a'),
          'ses_kid',
        );
        backend.values[SessionTabsStore.key] = SessionTabsStore.encode(
          SessionTabsState(
            tabs: const [
              SessionTab(
                ref: root,
                project: null,
                title: 'Parent',
                lastOpenedAtMs: 1,
              ),
              SessionTab(
                ref: child,
                project: null,
                title: 'Kid',
                lastOpenedAtMs: 2,
              ),
            ],
            selected: {const HostId('profile_a'): child},
          ),
        );
        final app = await _launch(tester, '/sessions', store: store);
        final source = app.rig.sources.single;
        source.respond([source.row('parent', title: 'Parent')]);
        await _settle(tester);
        expect(_location(app), '/sessions');
        if (newDraft) {
          await tester.tap(find.byKey(const ValueKey('workspace-new-chat')));
          await _settle(tester);
        }
        final read = source.reads.firstWhere((entry) => entry.$1 == child);
        read.$2.completion.complete(source.row('kid', parent: 'parent'));
        await _settle(tester);
        expect(
          _location(app),
          newDraft ? '/sessions' : '/s/profile_a/ses_parent',
        );
        expect(
          app.dependencies.sessionTabs!.tabs.any((tab) => tab.ref == child),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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

  testWidgets('the first-use hint explains the gestures once', (tester) async {
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

    final hint = find.byKey(const ValueKey('session-tabs-gesture-hint'));
    expect(hint, findsOneWidget);
    // The dismissal is a filled action, never bare text over the chat.
    expect(
      tester.widget(
        find.byKey(const ValueKey('session-tabs-gesture-hint-dismiss')),
      ),
      isA<FilledButton>(),
    );
    await tester.tap(
      find.byKey(const ValueKey('session-tabs-gesture-hint-dismiss')),
    );
    await _settle(tester);
    expect(hint, findsNothing);
    await app.dependencies.preferences.flush();
    expect(app.dependencies.preferences.tabsGestureHintDismissed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the strip can be hidden from the display preferences', (
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
    expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);

    app.dependencies.preferences.setShowSessionTabs(false);
    await _settle(tester);
    expect(find.byKey(const ValueKey('session-tabs')), findsNothing);
    expect(
      find.byKey(const ValueKey('session-tabs-gesture-hint')),
      findsNothing,
    );

    app.dependencies.preferences.setShowSessionTabs(true);
    await _settle(tester);
    expect(find.byKey(const ValueKey('session-tabs')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (label, locale, rtl) in [
    ('LTR', null, false),
    ('RTL', const Locale('ar'), true),
  ]) {
    testWidgets(
      'clicking a visible tab keeps its order and scroll offset in $label; off-screen tabs still reveal (#498)',
      (tester) async {
        _useMemoryPreferences();
        final app = await _launch(
          tester,
          '/s/profile_a/ses_t1',
          size: const Size(840, 800),
        );
        if (locale != null) {
          app.dependencies.preferences.setLocale(locale);
          await _settle(tester);
        }
        final source = app.rig.sources.single;
        const ids = ['t1', 't2', 't3', 't4', 't5', 't6', 't7', 't8'];
        source.respond([
          for (final id in ids)
            source.row(
              id,
              title: 'Session Tab ${id.toUpperCase()}',
              directory: '/work/a',
            ),
        ]);
        await _settle(tester);
        await _visit(tester, app, ids);

        final stripFinder = find.byKey(const ValueKey('session-tabs-regular'));
        ScrollPosition scrollPosition() => tester
            .state<ScrollableState>(
              find.descendant(
                of: stripFinder,
                matching: find.byType(Scrollable),
              ),
            )
            .position;
        final position = scrollPosition();
        expect(position.maxScrollExtent, greaterThan(200));

        // Navigate back to t1 so t1 is revealed at the leading edge.
        await _visit(tester, app, ['t1']);
        expect(identical(scrollPosition(), position), isTrue);
        expect(position.pixels, closeTo(0, 0.5));

        // Scroll so t3 and t4 are both completely inside the viewport and well
        // away from the leading edge, then tap t4 and t3: tab order and scroll
        // offset must stay intact in both directions.
        await _visit(tester, app, ['t3']);
        final viewport = tester.getRect(stripFinder);
        final t4Initial = tester.getRect(_tab(app, 't4'));
        final delta = rtl
            ? (viewport.left - t4Initial.left) + 40
            : (t4Initial.right - viewport.right) + 40;
        final targetOffset = (position.pixels + delta).clamp(
          0.0,
          position.maxScrollExtent,
        );
        position.jumpTo(targetOffset);
        await _settle(tester);
        final t4RectBefore = tester.getRect(_tab(app, 't4'));
        if (rtl) {
          expect(t4RectBefore.right, lessThan(viewport.right - 20));
          expect(t4RectBefore.left, greaterThanOrEqualTo(viewport.left - 0.5));
        } else {
          expect(t4RectBefore.left, greaterThan(viewport.left + 20));
          expect(t4RectBefore.right, lessThanOrEqualTo(viewport.right + 0.5));
        }

        final offsetBefore = position.pixels;
        await tester.tap(_tab(app, 't4'));
        await _settle(tester);
        expect(_location(app), '/s/profile_a/ses_t4');
        expect(position.pixels, closeTo(offsetBefore, 0.5));

        // Clicking back to already-visible t3 also preserves the scroll offset.
        await tester.tap(_tab(app, 't3'));
        await _settle(tester);
        expect(_location(app), '/s/profile_a/ses_t3');
        expect(position.pixels, closeTo(offsetBefore, 0.5));
        for (var i = 0; i < ids.length - 1; i++) {
          final currentX = tester.getTopLeft(_tab(app, ids[i])).dx;
          final nextX = tester.getTopLeft(_tab(app, ids[i + 1])).dx;
          expect(currentX, rtl ? greaterThan(nextX) : lessThan(nextX));
        }

        // Activating an off-screen tab on the trailing (t8) or leading (t1)
        // side still scrolls it into view.
        await _visit(tester, app, ['t8']);
        final t8Rect = tester.getRect(_tab(app, 't8'));
        expect(t8Rect.left, greaterThanOrEqualTo(viewport.left - 0.5));
        expect(t8Rect.right, lessThanOrEqualTo(viewport.right + 0.5));
        await _visit(tester, app, ['t1']);
        final t1Rect = tester.getRect(_tab(app, 't1'));
        expect(t1Rect.left, greaterThanOrEqualTo(viewport.left - 0.5));
        expect(t1Rect.right, lessThanOrEqualTo(viewport.right + 0.5));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the chat overflow opens the display choices', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('workspace-actions')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('workspace-display-menu')));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('workspace-display-sheet')),
      findsOneWidget,
    );

    // The same choice the Settings toggle writes, applied in place; Recent
    // sessions is no longer a choice (#534).
    expect(
      find.byKey(const ValueKey('display-toggle-recent-sessions')),
      findsNothing,
    );
    final tabs = find.byKey(const ValueKey('display-toggle-session-tabs'));
    await tester.ensureVisible(tabs);
    await tester.tap(tabs);
    await _settle(tester);
    expect(app.dependencies.preferences.showSessionTabs, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
