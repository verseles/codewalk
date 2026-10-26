import 'dart:async';

import 'package:codewalk/app/app_dependencies.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/features/sessions/session_tab_icons.dart';
import 'package:codewalk/platform/sessions/session_draft_store.dart';
import 'package:codewalk/platform/sessions/session_tab_icon_store.dart';
import 'package:codewalk/platform/sessions/session_tabs_store.dart';
import 'package:codewalk/platform/sessions/workspace_draft_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/payload_store.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

void _useMemoryPreferences() {
  final platform = SharedPreferencesAsyncPlatform.instance;
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = platform);
}

/// Launches the app on a session of `profile_a` with the rows of two
/// projects, `/work/a` (one, two, three) and `/work/b` (other).
Future<_App> _launch(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
  FakeMetadataBackend? backend,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final rig = CatalogRig();
  addTearDown(rig.dispose);
  await rig.save('a');
  final directory = LiveDirectory();
  // Drafts are read in fake time: no file I/O.
  final metadata = V2MetadataStore(backend: backend ?? FakeMetadataBackend());
  final payloads = PreferencesPayloadStore(metadata);
  final dependencies = createAppDependencies(
    initialLink: Uri.parse('/s/profile_a/ses_one'),
    metadataStore: metadata,
    profileRepository: rig.repository,
    endpointProber: FakeProber(),
    sessionCatalogFactory: rig.create,
    sessionLiveDirectory: () => directory,
    draftStore: SessionDraftStore(payloads: payloads, index: metadata),
    workspaceDraftStore: WorkspaceDraftStore(
      payloads: payloads,
      index: metadata,
    ),
  );
  // The same root as the relaunches with another text scale, so those keep
  // the app's controllers.
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(tester.view),
      child: CodeWalkV2Bootstrap(dependencies: dependencies),
    ),
  );
  await _settle(tester);
  final source = rig.sources.single;
  source.respond([
    source.row('one', title: 'One', directory: '/work/a'),
    source.row('two', title: 'Two', directory: '/work/a'),
    source.row('three', title: 'Three', directory: '/work/a'),
    source.row('other', title: 'Other', directory: '/work/b'),
  ]);
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

/// Opens the project contexts of [directories] in order; the last is shown.
Future<void> _open(
  WidgetTester tester,
  _App app,
  List<String> directories,
) async {
  for (final directory in directories) {
    expect(
      await app.dependencies.projectContexts!.openContext(directory),
      isTrue,
    );
    await _settle(tester);
  }
}

SessionRef _ref(_App app, String id) => app.rig.sources.single.row(id).info.ref;

Finder _tab(_App app, String id) =>
    find.byKey(ValueKey('session-tab-${_ref(app, id).storageKey}'));

String _location(_App app) =>
    app.dependencies.router.routerDelegate.currentConfiguration.uri.toString();

List<String> _ids(_App app) => [
  for (final tab in app.dependencies.sessionTabs!.tabs) tab.ref.nativeId,
];

SessionTab _sessionTab(_App app, String id) => app
    .dependencies
    .sessionTabs!
    .tabs
    .firstWhere((tab) => tab.ref == _ref(app, id));

Future<void> _longPress(WidgetTester tester, _App app, String id) async {
  await tester.ensureVisible(_tab(app, id));
  await tester.longPress(_tab(app, id));
  await _settle(tester);
}

Future<void> _dismissMenu(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await _settle(tester);
}

/// The text field of the draft composer has the focus.
bool _composerFocused(WidgetTester tester) =>
    tester
        .widget<TextField>(find.byKey(const ValueKey('workspace-draft-text')))
        .focusNode
        ?.hasFocus ??
    false;

void main() {
  testWidgets('every menu opener shows the actions without selecting the tab', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _visit(tester, app, ['one', 'two']);

    await _longPress(tester, app, 'one');
    expect(find.text(app.l10n.sessionsActionRename), findsOneWidget);
    expect(find.text(app.l10n.sessionTabChangeIconAction), findsOneWidget);
    expect(_location(app), '/s/profile_a/ses_two');
    await _dismissMenu(tester);
    expect(find.text(app.l10n.sessionsActionRename), findsNothing);

    // A secondary click opens the same menu where the pointer is.
    final center = tester.getCenter(_tab(app, 'one'));
    await tester.tapAt(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await _settle(tester);
    expect(find.text(app.l10n.sessionsActionRename), findsOneWidget);
    expect(_location(app), '/s/profile_a/ses_two');
    await _dismissMenu(tester);

    // Shift+F10 on the focused tab opens it from the keyboard.
    Focus.of(
      tester.element(
        find.descendant(of: _tab(app, 'one'), matching: find.text('One')),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _settle(tester);
    expect(find.text(app.l10n.sessionsActionRename), findsOneWidget);
    expect(_location(app), '/s/profile_a/ses_two');
    await _dismissMenu(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tab pinned from its menu moves to the pinned region', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a']);
    await _visit(tester, app, ['one', 'two']);
    final tabs = app.dependencies.sessionTabs!;
    final pinned = find.byKey(const ValueKey('session-tabs-pinned'));

    await _longPress(tester, app, 'one');
    await tester.tap(find.text(app.l10n.sessionPin));
    await _settle(tester);
    expect(tabs.isPinned(_sessionTab(app, 'one')), isTrue);
    expect(
      find.descendant(of: pinned, matching: _tab(app, 'one')),
      findsOneWidget,
    );
    // An inactive pinned tab is icon-only; the saved order is unchanged.
    expect(
      find.descendant(of: _tab(app, 'one'), matching: find.text('One')),
      findsNothing,
    );
    expect(_ids(app), ['ses_one', 'ses_two']);
    expect(_location(app), '/s/profile_a/ses_two');

    await _longPress(tester, app, 'one');
    await tester.tap(find.text(app.l10n.sessionUnpin));
    await _settle(tester);
    expect(tabs.isPinned(_sessionTab(app, 'one')), isFalse);
    expect(pinned, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing a pinned tab unpins it; undo pins it back', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a']);
    await _visit(tester, app, ['one', 'two']);
    final tabs = app.dependencies.sessionTabs!;
    final row = app.dependencies.sessions!.findSession(_ref(app, 'one'))!;
    expect(
      await app.dependencies.projectContexts!.setPinned(row, pinned: true),
      isTrue,
    );
    await _settle(tester);

    await tester.ensureVisible(_tab(app, 'one'));
    await tester.tap(
      _tab(app, 'one'),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await _settle(tester);
    expect(_ids(app), ['ses_two']);
    expect(app.dependencies.projectContexts!.isPinned(row), isFalse);

    await tester.tap(find.text(app.l10n.sessionTabUndo));
    await _settle(tester);
    expect(_ids(app), ['ses_one', 'ses_two']);
    expect(tabs.isPinned(_sessionTab(app, 'one')), isTrue);
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('close project is refused for the only open project', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a']);
    await _visit(tester, app, ['one', 'two']);
    final contexts = app.dependencies.projectContexts!;
    expect(contexts.open, ['/work/a']);

    await _longPress(tester, app, 'one');
    expect(find.text(app.l10n.chatCloseProject('a')), findsOneWidget);
    expect(
      find.text(app.l10n.projectProviderErrorAtLeastOneContext),
      findsOneWidget,
    );
    // The disabled entry ignores the tap and the menu stays open.
    await tester.tap(find.text(app.l10n.chatCloseProject('a')));
    await _settle(tester);
    expect(find.text(app.l10n.chatCloseProject('a')), findsOneWidget);
    await _dismissMenu(tester);
    expect(contexts.open, ['/work/a']);
    expect(_ids(app), ['ses_one', 'ses_two']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('close project from a tab closes its tabs and keeps the view', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a', '/work/b']);
    await _visit(tester, app, ['one', 'other']);
    final contexts = app.dependencies.projectContexts!;

    await _longPress(tester, app, 'one');
    await tester.tap(find.text(app.l10n.chatCloseProject('a')));
    await _settle(tester);
    expect(contexts.open, ['/work/b']);
    expect(_ids(app), ['ses_other']);
    expect(_location(app), '/s/profile_a/ses_other');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing the shown project from its tab leaves its session', (
    tester,
  ) async {
    _useMemoryPreferences();
    final backend = FakeMetadataBackend();
    final app = await _launch(tester, backend: backend);
    await _open(tester, app, ['/work/a', '/work/b']);
    await _visit(tester, app, ['one', 'other', 'one']);
    final contexts = app.dependencies.projectContexts!;
    expect(contexts.active, '/work/a');
    expect(
      await app.dependencies.sessionTabs!.setIcon(
        _sessionTab(app, 'one'),
        SessionTabIconPreset.bug.id,
      ),
      isTrue,
    );

    // The menu belongs to a tab that leaves with the project, and the
    // glyph cleanup still saves while the strip redraws without it.
    backend
      ..blockedKey = SessionTabIconStore.key
      ..release = Completer<void>();
    await _longPress(tester, app, 'one');
    await tester.tap(find.text(app.l10n.chatCloseProject('a')));
    await _settle(tester);
    expect(_tab(app, 'one'), findsNothing);
    backend.release!.complete();
    await _settle(tester);
    expect(contexts.open, ['/work/b']);
    expect(_ids(app), ['ses_other']);
    expect(_location(app), '/s/profile_a/ses_other');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a tab of another project offers only its local actions', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a', '/work/b']);
    await _visit(tester, app, ['one', 'other', 'one']);
    // The row of the other project is known, but not in the shown list.
    final other = _ref(app, 'other');
    expect(app.dependencies.sessions!.findSession(other), isNotNull);
    expect(app.dependencies.sessions!.lists(other), isFalse);

    await _longPress(tester, app, 'other');
    expect(find.text(app.l10n.sessionPin), findsOneWidget);
    expect(find.text(app.l10n.sessionsActionHide), findsOneWidget);
    expect(find.text(app.l10n.sessionTabChangeIconAction), findsOneWidget);
    for (final command in [
      app.l10n.sessionsActionRename,
      app.l10n.sessionsActionFork,
      app.l10n.sessionsActionDelete,
    ]) {
      expect(find.text(command), findsNothing);
    }
    await _dismissMenu(tester);

    await _longPress(tester, app, 'one');
    expect(find.text(app.l10n.sessionsActionRename), findsOneWidget);
    await _dismissMenu(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a custom icon chosen in the menu is kept for the tab', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a']);
    await _visit(tester, app, ['one', 'two']);
    final tabs = app.dependencies.sessionTabs!;

    await _longPress(tester, app, 'one');
    await tester.tap(find.text(app.l10n.sessionTabChangeIconAction));
    await _settle(tester);
    await tester.tap(
      find.byKey(
        ValueKey('session_tab_icon_option_${SessionTabIconPreset.bug.id}'),
      ),
    );
    await _settle(tester);
    expect(tabs.iconFor(_ref(app, 'one')), SessionTabIconPreset.bug.id);
    expect(
      find.descendant(
        of: _tab(app, 'one'),
        matching: find.byIcon(SessionTabIconPreset.bug.icon),
      ),
      findsOneWidget,
    );
    expect(_location(app), '/s/profile_a/ses_two');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a double tap and Delete close a tab without a close button', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _visit(tester, app, ['one', 'two', 'three']);
    expect(find.byIcon(Icons.close), findsNothing);

    // Closing a background tab never navigates.
    await tester.ensureVisible(_tab(app, 'one'));
    await tester.tap(_tab(app, 'one'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(_tab(app, 'one'));
    await _settle(tester);
    expect(_ids(app), ['ses_two', 'ses_three']);
    expect(_location(app), '/s/profile_a/ses_three');

    Focus.of(
      tester.element(
        find.descendant(of: _tab(app, 'two'), matching: find.text('Two')),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await _settle(tester);
    expect(_ids(app), ['ses_three']);
    expect(_location(app), '/s/profile_a/ses_three');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('closing the only tab opens its project draft as a placeholder', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a']);
    await _visit(tester, app, ['one']);

    await tester.tap(
      _tab(app, 'one'),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await _settle(tester);
    expect(_ids(app), isEmpty);
    expect(_location(app), '/sessions');
    final drafts = app.dependencies.workspaceDrafts!;
    expect(drafts.isDraftActive, isTrue);
    expect(drafts.currentKey?.canonicalDirectory, '/work/a');
    final placeholder = find.byKey(const ValueKey('session-tab-draft'));
    expect(placeholder, findsOneWidget);
    expect(_composerFocused(tester), isTrue);

    // The placeholder has no menu and is never saved as a tab.
    await tester.longPress(placeholder);
    await _settle(tester);
    expect(find.text(app.l10n.sessionsActionRename), findsNothing);
    expect(find.text(app.l10n.sessionTabChangeIconAction), findsNothing);
    expect(_ids(app), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the inline + of a group opens a draft of that project', (
    tester,
  ) async {
    _useMemoryPreferences();
    final app = await _launch(tester);
    await _open(tester, app, ['/work/a', '/work/b']);
    await _visit(tester, app, ['one', 'other', 'one']);
    final project = _sessionTab(app, 'other').project!;
    final add = find.byKey(ValueKey('session-tab-add-${project.storageKey}'));
    expect(add, findsOneWidget);

    await tester.ensureVisible(add);
    await tester.tap(add);
    await _settle(tester);
    final drafts = app.dependencies.workspaceDrafts!;
    expect(_location(app), '/sessions');
    expect(drafts.currentKey?.canonicalDirectory, '/work/b');
    expect(app.dependencies.projectContexts!.active, '/work/b');
    // The group's draft replaces its +; the other group keeps its own.
    expect(add, findsNothing);
    expect(find.byKey(const ValueKey('session-tab-draft')), findsOneWidget);
    expect(_composerFocused(tester), isTrue);
    expect(_ids(app), ['ses_one', 'ses_other']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [360.0, 412.0, 600.0, 839.0, 840.0, 1280.0]) {
    for (final language in ['en', 'ar', 'ur']) {
      testWidgets('the strip fits $width / $language at 1x and 2x', (
        tester,
      ) async {
        _useMemoryPreferences();
        final app = await _launch(tester, size: Size(width, 800));
        await _open(tester, app, ['/work/a', '/work/b']);
        await _visit(tester, app, ['one', 'two', 'other', 'three']);
        // The pin needs its project shown.
        await _open(tester, app, ['/work/a']);
        final row = app.dependencies.sessions!.findSession(_ref(app, 'one'));
        expect(
          await app.dependencies.projectContexts!.setPinned(row!, pinned: true),
          isTrue,
        );
        app.dependencies.preferences.setLocale(Locale(language));
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData.fromView(
                tester.view,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: CodeWalkV2Bootstrap(dependencies: app.dependencies),
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
          final strip = find.byKey(const ValueKey('session-tabs'));
          expect(strip, findsOneWidget);
          // The shown tab is scrolled into view and every tab keeps a
          // 48 dp target.
          final shown = tester.getRect(_tab(app, 'three'));
          final bounds = tester.getRect(strip);
          expect(shown.left, greaterThanOrEqualTo(bounds.left - 0.5));
          expect(shown.right, lessThanOrEqualTo(bounds.right + 0.5));
          for (final id in ['one', 'two', 'three', 'other']) {
            expect(tester.getSize(_tab(app, id)).height, 48);
          }
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('session-tabs-pinned')),
              matching: _tab(app, 'one'),
            ),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
