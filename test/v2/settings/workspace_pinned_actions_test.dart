import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/workspace_chrome.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
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
            appBar: AppBar(actions: const [WorkspaceAppBarActions()]),
          ),
        ),
      ),
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

  test('fresh workspace pins only the implemented New Chat action', () {
    final preferences = AppPreferencesController();
    addTearDown(preferences.dispose);
    expect(preferences.appBarPins, [WorkspacePinnedAction.newChat]);
  });

  test(
    'two saved pins retain order; a fourth drops the oldest and survives restart',
    () async {
      final backend = FakeMetadataBackend()
        ..values[_key] = '["refresh","newChat"]';
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(preferences.dispose);
      await preferences.initialize();
      expect(preferences.appBarPins, [
        WorkspacePinnedAction.refresh,
        WorkspacePinnedAction.newChat,
      ]);
      preferences.setAppBarPinned(WorkspacePinnedAction.servers, true);
      preferences.setAppBarPinned(WorkspacePinnedAction.settings, true);
      await preferences.flush();
      final next = AppPreferencesController(
        store: V2MetadataStore(backend: backend),
      );
      addTearDown(next.dispose);
      await next.initialize();
      expect(next.appBarPins, [
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.servers,
        WorkspacePinnedAction.settings,
      ]);
      next.setAppBarPinned(WorkspacePinnedAction.servers, false);
      await next.flush();
      expect(next.appBarPins, [
        WorkspacePinnedAction.newChat,
        WorkspacePinnedAction.settings,
      ]);
    },
  );

  test('oversized valid saved lists retain the latest three actions', () async {
    final backend = FakeMetadataBackend()
      ..values[_key] = '["newChat","servers","refresh","settings"]';
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    expect(preferences.appBarPins, [
      WorkspacePinnedAction.servers,
      WorkspacePinnedAction.refresh,
      WorkspacePinnedAction.settings,
    ]);
  });

  test('unreadable or future pinned state survives unrelated edits', () async {
    const raw = '{"version":99,"actions":["future-action"]}';
    final backend = FakeMetadataBackend()..values[_key] = raw;
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    expect(preferences.canEditAppBarPins, isFalse);
    preferences.setAppBarPinned(WorkspacePinnedAction.refresh, true);
    preferences.setThemeMode(ThemeMode.dark);
    await preferences.flush();
    expect(preferences.appBarPins, [WorkspacePinnedAction.newChat]);
    expect(backend.values[_key], raw);
    expect(preferences.hasPersistenceError, isTrue);
  });
}
