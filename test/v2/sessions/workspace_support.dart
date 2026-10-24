import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the session list of a mounted workspace: the saved servers load,
/// a single one opens on its own, and a compact window opens its list
/// drawer; a wider one keeps the list in its pane.
///
/// The first read of the list stays open until the test answers it, so the
/// frames are pumped for a fixed time instead of until they settle.
Future<void> showSessionList(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  final drawer = find.byKey(const ValueKey('workspace-drawer'));
  if (drawer.evaluate().isEmpty) return;
  final shell = tester.state<ScaffoldState>(
    find.ancestor(of: drawer, matching: find.byType(Scaffold)).last,
  );
  if (shell.isDrawerOpen) return;
  await tester.tap(drawer);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Whether the list drawer of a compact workspace is open.
bool sessionListDrawerOpen(WidgetTester tester) {
  final drawer = find.byKey(const ValueKey('workspace-drawer'));
  if (drawer.evaluate().isEmpty) return false;
  return tester
      .state<ScaffoldState>(
        find.ancestor(of: drawer, matching: find.byType(Scaffold)).last,
      )
      .isDrawerOpen;
}

/// Records each time the app asks the platform to go to the background.
List<String> recordSystemPops(WidgetTester tester) {
  final pops = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') pops.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return pops;
}
