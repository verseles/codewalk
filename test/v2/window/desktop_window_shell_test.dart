import 'dart:ui' show AppExitType;

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/app_shell.dart';
import 'package:codewalk/app/desktop_window_band.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sessions/workspace_live_support.dart';
import 'desktop_window_fakes.dart';

const _band = ValueKey('desktop-window-band');
const _drag = ValueKey('desktop-window-drag');
const _minimize = ValueKey('desktop-window-minimize');
const _maximize = ValueKey('desktop-window-maximize');
const _close = ValueKey('desktop-window-close');
const _tabs = ValueKey('session-tabs');

/// The app-exit requests made, by their type.
List<AppExitType> _exits() {
  final exits = <AppExitType>[];
  final original = AppShell.exitApp;
  AppShell.exitApp = (type) async => exits.add(type);
  addTearDown(() => AppShell.exitApp = original);
  return exits;
}

/// A Linux window, its platform restored after the test.
void _linux() {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  debugDefaultTargetPlatformOverride = null;
}

/// The workspace, then the settings page over it.
Future<WorkspaceApp> _settings(
  WidgetTester tester, {
  FakeDesktopWindowPort? window,
}) async {
  final app = await launchWorkspace(
    tester,
    link: '/sessions',
    desktopWindow: window,
  );
  app.dependencies.router.go('/settings');
  await settleWorkspace(tester);
  return app;
}

Finder _inBand(Object key) =>
    find.descendant(of: find.byKey(_band), matching: find.byKey(key as Key));

void main() {
  testWidgets('on a wide window the tabs lead the band and the toolbar '
      'follows', (tester) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);
    await openLiveSession(tester, app);

    expect(tester.getTopLeft(find.byKey(_band)), Offset.zero);
    expect(find.byKey(_tabs), findsOneWidget);
    expect(_inBand(_tabs), findsOneWidget);
    final bandBottom = tester.getBottomLeft(find.byKey(_band)).dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('workspace-pane-toggle'))).dy,
      greaterThanOrEqualTo(bandBottom),
    );
    // The controls keep the right edge; the tabs take only their width.
    expect(tester.getTopRight(find.byKey(_close)).dx, 1280);
    expect(
      tester.getTopRight(find.byKey(_tabs)).dx,
      lessThan(tester.getTopLeft(find.byKey(_minimize)).dx),
    );
    await _end(tester);
  });

  testWidgets('the free band drags and maximizes; a tab keeps its gestures', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);
    await openLiveSession(tester, app);
    final free = Offset(
      tester.getTopLeft(find.byKey(_minimize)).dx - 40,
      tester.getCenter(find.byKey(_band)).dy,
    );

    await tester.dragFrom(free, const Offset(60, 20));
    await tester.pump();
    expect(window.drags, 1);

    await tester.tapAt(free);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(free);
    await settleWorkspace(tester);
    expect(window.toggled, 1);

    final ref = app.rig.sources.single.row('one').info.ref;
    final chip = find.byKey(ValueKey('session-tab-${ref.storageKey}'));
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(chip);
    await settleWorkspace(tester);
    expect(window.toggled, 1);
    expect(window.drags, 1);
    await _end(tester);
  });

  testWidgets('a full strip still leaves the band free to drag', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);
    await openLiveSession(tester, app);
    final source = app.rig.sources.single;
    for (var i = 0; i < 16; i++) {
      await app.dependencies.sessionTabs!.open(
        source.row(
          'extra$i',
          title: 'A long session title $i',
          directory: '/w',
        ),
      );
    }
    await settleWorkspace(tester);
    final minimize = tester.getTopLeft(find.byKey(_minimize)).dx;
    expect(
      tester.getTopRight(find.byKey(_tabs)).dx,
      lessThanOrEqualTo(minimize - DesktopWindowBand.dragReserve),
    );
    await tester.dragFrom(
      Offset(minimize - 20, tester.getCenter(find.byKey(_band)).dy),
      const Offset(60, 20),
    );
    await tester.pump();
    expect(window.drags, 1);
    await _end(tester);
    // The opened tabs leave their own timers to run out.
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the band controls minimize, maximize and close by the choice', (
    tester,
  ) async {
    _linux();
    final exits = _exits();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);

    await tester.tap(find.byKey(_minimize));
    await tester.pump();
    expect(window.minimized, 1);

    expect(find.byTooltip(app.l10n.desktopWindowMaximize), findsOneWidget);
    await tester.tap(find.byKey(_maximize));
    await tester.pump();
    expect(window.toggled, 1);
    window.maximizedNotifier.value = true;
    await tester.pump();
    expect(find.byTooltip(app.l10n.desktopWindowRestore), findsOneWidget);

    await tester.tap(find.byKey(_close));
    await tester.pump();
    expect(exits, [AppExitType.cancelable]);

    app.dependencies.preferences.setWindowCloseAction(
      WindowCloseAction.minimize,
    );
    await tester.tap(find.byKey(_close));
    await tester.pump();
    expect(exits, [AppExitType.cancelable]);
    expect(window.minimized, 2);

    // The window manager's close follows the same choice.
    window.requestClose();
    await tester.pump();
    expect(window.minimized, 3);
    app.dependencies.preferences.setWindowCloseAction(WindowCloseAction.close);
    window.requestClose();
    await tester.pump();
    expect(exits, [AppExitType.cancelable, AppExitType.cancelable]);
    await _end(tester);
  });

  testWidgets('mod+W without a tab follows the choice and mod+Q quits', (
    tester,
  ) async {
    _linux();
    final exits = _exits();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(
      tester,
      link: '/sessions',
      desktopWindow: window,
    );
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleWorkspace(tester);
    }

    await press(LogicalKeyboardKey.keyW);
    expect(exits, [AppExitType.cancelable]);
    app.dependencies.preferences.setWindowCloseAction(
      WindowCloseAction.minimize,
    );
    await press(LogicalKeyboardKey.keyW);
    expect(window.minimized, 1);
    expect(exits, [AppExitType.cancelable]);
    await press(LogicalKeyboardKey.keyQ);
    expect(exits, [AppExitType.cancelable, AppExitType.required]);
    await _end(tester);
  });

  testWidgets('without tabs the band keeps the drag area and controls', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);
    await openLiveSession(tester, app);
    app.dependencies.preferences.setShowSessionTabs(false);
    await settleWorkspace(tester);
    expect(find.byKey(_band), findsOneWidget);
    expect(find.byKey(_tabs), findsNothing);
    expect(_inBand(_drag), findsOneWidget);
    expect(_inBand(_close), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a compact window keeps its tabs in the page under the band', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(
      tester,
      size: const Size(390, 844),
      desktopWindow: window,
    );
    await openLiveSession(tester, app);
    expect(tester.getTopLeft(find.byKey(_band)), Offset.zero);
    expect(_inBand(_tabs), findsNothing);
    expect(_inBand(_close), findsOneWidget);
    final bandBottom = tester.getBottomLeft(find.byKey(_band)).dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('workspace-drawer'))).dy,
      greaterThanOrEqualTo(bandBottom),
    );
    await _end(tester);
  });

  testWidgets('settings keep the band above their page', (tester) async {
    _linux();
    final window = FakeDesktopWindowPort();
    await _settings(tester, window: window);
    expect(tester.getTopLeft(find.byKey(_band)), Offset.zero);
    expect(_inBand(_tabs), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('workspace-back'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(_band)).dy),
    );
    await _end(tester);
  });

  testWidgets('turning the integrated title bar off restores the system one', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await launchWorkspace(tester, desktopWindow: window);
    await openLiveSession(tester, app);
    app.dependencies.preferences.setIntegratedWindowChrome(false);
    await settleWorkspace(tester);
    expect(window.titleBarHidden, [true, false]);
    expect(find.byKey(_band), findsNothing);
    expect(find.byKey(_tabs), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('workspace-pane-toggle'))).dy,
      lessThan(tester.getTopLeft(find.byKey(_tabs)).dy),
    );
    await _end(tester);
  });

  testWidgets('a window manager that keeps its title bar gets no band', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort(hides: false);
    await launchWorkspace(tester, desktopWindow: window);
    expect(find.byKey(_band), findsNothing);
    await _end(tester);
  });

  testWidgets('Settings > Behavior holds the window choices on a desktop', (
    tester,
  ) async {
    _linux();
    final window = FakeDesktopWindowPort();
    final app = await _settings(tester, window: window);
    await tester.tap(
      find.byKey(const ValueKey('settings_destination_behavior')),
    );
    await settleWorkspace(tester);
    final list = find.descendant(
      of: find.byKey(const ValueKey('behavior_settings_list')),
      matching: find.byType(Scrollable),
    );
    final close = find.byKey(const ValueKey('settings_window_close_action'));
    await tester.scrollUntilVisible(close, 160, scrollable: list.first);
    await tester.tap(
      find.descendant(
        of: close,
        matching: find.text(app.l10n.desktopWindowMinimize),
      ),
    );
    await settleWorkspace(tester);
    expect(
      app.dependencies.preferences.windowCloseAction,
      WindowCloseAction.minimize,
    );
    final chrome = find.byKey(
      const ValueKey('settings_toggle_integrated_window_chrome'),
    );
    await tester.scrollUntilVisible(chrome, -160, scrollable: list.first);
    await tester.tap(chrome);
    await settleWorkspace(tester);
    expect(app.dependencies.preferences.integratedWindowChrome, isFalse);
    expect(find.byKey(_band), findsNothing);
    await _end(tester);
  });

  testWidgets('without a desktop window Behavior has no window choices', (
    tester,
  ) async {
    await _settings(tester);
    await tester.tap(
      find.byKey(const ValueKey('settings_destination_behavior')),
    );
    await settleWorkspace(tester);
    expect(
      find.byKey(const ValueKey('settings_window_close_action')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings_toggle_integrated_window_chrome')),
      findsNothing,
    );
    await _end(tester);
  });
}
