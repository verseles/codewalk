import 'dart:ui' show AppExitType;

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/app_shell.dart';
import 'package:codewalk/app/resizable_session_pane.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workspace_live_support.dart';

double _paneWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(const ValueKey('workspace-sidebar'))).width;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await settleWorkspace(tester);
}

/// The app-exit requests the shortcuts make, by their type.
List<AppExitType> _exits() {
  final exits = <AppExitType>[];
  final original = AppShell.exitApp;
  AppShell.exitApp = (type) async => exits.add(type);
  addTearDown(() => AppShell.exitApp = original);
  return exits;
}

void main() {
  testWidgets('the pane resizes at once and saves when the drag ends', (
    tester,
  ) async {
    final app = await launchWorkspace(tester);
    final preferences = app.dependencies.preferences;
    final handle = find.byKey(const ValueKey('workspace-sidebar-handle'));
    expect(_paneWidth(tester), AppPreferencesController.sessionPaneDefault);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    // The layout follows the drag before anything is saved.
    expect(_paneWidth(tester), closeTo(400, 1));
    expect(preferences.sessionPaneWidth, isNull);
    await gesture.up();
    await settleWorkspace(tester);
    expect(preferences.sessionPaneWidth, closeTo(400, 1));

    // The width stays within its bounds.
    await tester.drag(handle, const Offset(400, 0));
    await settleWorkspace(tester);
    expect(
      preferences.sessionPaneWidth,
      AppPreferencesController.sessionPaneMax,
    );

    // A double tap restores the default.
    await tester.tap(handle);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(handle);
    await settleWorkspace(tester);
    expect(preferences.sessionPaneWidth, isNull);
    expect(_paneWidth(tester), AppPreferencesController.sessionPaneDefault);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a medium window keeps a fixed pane and the saved width', (
    tester,
  ) async {
    final app = await launchWorkspace(tester, size: const Size(700, 800));
    app.dependencies.preferences.setSessionPaneWidth(500);
    await settleWorkspace(tester);
    expect(_paneWidth(tester), ResizableSessionPane.fixedWidth);
    expect(
      find.byKey(const ValueKey('workspace-sidebar-handle')),
      findsNothing,
    );
    expect(app.dependencies.preferences.sessionPaneWidth, 500);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a hidden pane keeps the project and settings in the bar', (
    tester,
  ) async {
    final app = await launchWorkspace(tester);
    final toggle = find.byKey(const ValueKey('workspace-pane-toggle'));
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-settings')), findsNothing);

    await tester.tap(toggle);
    await settleWorkspace(tester);
    expect(app.dependencies.preferences.sessionPaneHidden, isTrue);
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsNothing);
    expect(
      find.byKey(const ValueKey('workspace-project-context')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('workspace-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace-server')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workspace-settings')));
    await settleWorkspace(tester);
    expect(
      app.dependencies.router.routerDelegate.currentConfiguration.last
          .matchedLocation,
      '/settings',
    );
    app.dependencies.router.go('/s/profile_a/ses_one');
    await settleWorkspace(tester);
    await tester.tap(toggle);
    await settleWorkspace(tester);
    expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mod+L and a single Escape focus the live composer', (
    tester,
  ) async {
    final app = await launchWorkspace(tester);
    await openLiveSession(tester, app);
    final input = find.byKey(const ValueKey('live-composer-input'));
    bool focused() =>
        tester.widget<TextField>(input).focusNode?.hasFocus ?? false;
    expect(focused(), isFalse);

    await _press(tester, LogicalKeyboardKey.keyL, control: true);
    expect(focused(), isTrue);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(focused(), isFalse);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(focused(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a field of the pane that lets the focus go keeps Escape', (
    tester,
  ) async {
    final app = await launchWorkspace(tester);
    await openLiveSession(tester, app);
    final input = find.byKey(const ValueKey('live-composer-input'));
    final search = find.byKey(const ValueKey('sessions-search-field'));
    bool focused(Finder field) =>
        tester.widget<TextField>(field).focusNode?.hasFocus ?? false;

    await tester.tap(find.byKey(const ValueKey('sessions-search')));
    await settleWorkspace(tester);
    expect(focused(search), isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settleWorkspace(tester);
    expect(focused(search), isFalse);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(focused(input), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Escape closes the drawer before it focuses the draft', (
    tester,
  ) async {
    await launchWorkspace(tester, link: '/sessions', size: const Size(390, 844));
    final scaffold = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await settleWorkspace(tester);
    expect(scaffold.isDrawerOpen, isTrue);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(scaffold.isDrawerOpen, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mod+R reads the list again and keeps the open view', (
    tester,
  ) async {
    final app = await launchWorkspace(tester);
    await openLiveSession(tester, app);
    final source = app.rig.sources.single;
    int reads() => source.queries.length + source.contextQueries.length;
    final before = reads();
    final opens = app.directory.opens.length;
    final wakes = app.directory.wakes;
    await _press(tester, LogicalKeyboardKey.keyR, control: true);
    expect(reads(), greaterThan(before));
    expect(app.directory.wakes, wakes + 1);
    expect(app.directory.opens, hasLength(opens));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('on a desktop mod+W without a tab closes and mod+Q quits', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final exits = _exits();
    await launchWorkspace(tester, link: '/sessions');
    await _press(tester, LogicalKeyboardKey.keyW, control: true);
    expect(exits, [AppExitType.cancelable]);
    await _press(tester, LogicalKeyboardKey.keyQ, control: true);
    expect(exits, [AppExitType.cancelable, AppExitType.required]);
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('on a phone mod+Q is left to the platform', (tester) async {
    final exits = _exits();
    await launchWorkspace(tester, link: '/sessions', size: const Size(390, 844));
    await _press(tester, LogicalKeyboardKey.keyQ, control: true);
    expect(exits, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
