import 'dart:convert';

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../storage/storage_fakes.dart';

const _key = 'cw2.settings.appBarPins';

void main() {
  testWidgets('an unavailable action can still be unpinned', (tester) async {
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppPreferencesController?>.value(
        value: preferences,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const [WorkspaceAppBarActions(compact: false)],
            ),
          ),
        ),
      ),
    );
    // Without an active live session, contextUsage stays hidden from the bar.
    expect(
      find.byKey(const ValueKey('workspace-pinned-contextUsage')),
      findsNothing,
    );
    final action = tester.widget<IconButton>(
      find.byKey(const ValueKey('workspace-pinned-newChat')),
    );
    expect(action.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('workspace-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-pin-newChat')));
    await tester.pump();
    expect(
      preferences.appBarPins,
      isNot(contains(WorkspacePinnedAction.newChat)),
    );
    await preferences.flush();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('fresh workspace pins contextUsage to the left of New Chat', () {
    final preferences = AppPreferencesController();
    addTearDown(preferences.dispose);
    expect(preferences.appBarPins, [
      WorkspacePinnedAction.contextUsage,
      WorkspacePinnedAction.newChat,
    ]);
  });

  test(
    'legacy saved pins migrate once with contextUsage left of newChat, drop Refresh, allow 4 pins, and persist unpinning',
    () async {
      final backend = FakeMetadataBackend()
        ..values[_key] = '["refresh","newChat"]';
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      await preferences.flush();
      expect(preferences.appBarPins, [
        WorkspacePinnedAction.contextUsage,
        WorkspacePinnedAction.newChat,
      ]);
      expect(preferences.canEditAppBarPins, isTrue);
      // Persisted as v:1 atomic envelope so migration runs only once.
      final stored = jsonDecode(backend.values[_key]! as String) as Map;
      expect(stored['v'], 1);
      expect(stored['pins'], ['contextUsage', 'newChat']);

      preferences.setAppBarPinned(WorkspacePinnedAction.servers, true);
      preferences.setAppBarPinned(WorkspacePinnedAction.settings, true);
      await preferences.flush();

      final next = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(next.dispose);
      await next.initialize();
      expect(next.appBarPins, [
        WorkspacePinnedAction.contextUsage,
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.settings,
      ]);

      // Unpinning contextUsage persists across restarts and is never re-added.
      next.setAppBarPinned(WorkspacePinnedAction.contextUsage, false);
      await next.flush();

      final afterUnpin = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(afterUnpin.dispose);
      await afterUnpin.initialize();
      expect(afterUnpin.appBarPins, [
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.settings,
      ]);

      // Re-pinning contextUsage places it immediately to the left of newChat.
      afterUnpin.setAppBarPinned(WorkspacePinnedAction.contextUsage, true);
      expect(afterUnpin.appBarPins, [
        WorkspacePinnedAction.contextUsage,
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.settings,
      ]);
    },
  );

  test(
    'legacy list without newChat inserts contextUsage at index 0 and keeps order',
    () async {
      final backend = FakeMetadataBackend()
        ..values[_key] = '["servers","refresh","settings"]';
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      await preferences.flush();
      expect(preferences.appBarPins, [
        WorkspacePinnedAction.contextUsage,
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.settings,
      ]);
    },
  );

  test(
    'legacy 3-pin list with newChat in the middle keeps all 4 pins after migration',
    () async {
      final backend = FakeMetadataBackend()
        ..values[_key] = '["servers","newChat","settings"]';
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      await preferences.flush();
      expect(preferences.appBarPins, [
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.contextUsage,
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.settings,
      ]);
    },
  );

  test('unreadable or future pinned state survives unrelated edits', () async {
    const raw = '{"version":99,"actions":["future-action"]}';
    final backend = FakeMetadataBackend()..values[_key] = raw;
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    expect(preferences.canEditAppBarPins, isFalse);
    preferences.setAppBarPinned(WorkspacePinnedAction.servers, true);
    preferences.setThemeMode(ThemeMode.dark);
    await preferences.flush();
    expect(preferences.appBarPins, AppPreferencesController.defaultAppBarPins);
    expect(backend.values[_key], raw);
    expect(preferences.hasPersistenceError, isTrue);
  });

  test(
    'failed legacy pin migration records persistence error and retries',
    () async {
      final backend = FakeMetadataBackend()
        ..values[_key] = '["newChat"]'
        ..failWrite = _key;
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      await preferences.flush();
      expect(preferences.hasPersistenceError, isTrue);

      backend.failWrite = null;
      await preferences.retryPersistence();
      await preferences.flush();
      expect(preferences.hasPersistenceError, isFalse);
      final stored = jsonDecode(backend.values[_key]! as String) as Map;
      expect(stored['v'], 1);
      expect(stored['pins'], ['contextUsage', 'newChat']);
    },
  );
}
