import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/shortcuts/shortcut_action.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

// #553: a new install starts on the GitHub theme; an existing one keeps its.
// It also starts with session tabs on a desktop and without them on a phone.

void main() {
  Future<AppPreferencesController> load(FakeMetadataBackend backend) async {
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: backend),
    );
    addTearDown(preferences.dispose);
    await preferences.initialize();
    await pumpEventQueue();
    return preferences;
  }

  test('a new install starts on GitHub, and keeps it', () async {
    final backend = FakeMetadataBackend();
    expect((await load(backend)).themePreset, OpenCodeThemePreset.github);
    expect(backend.values['cw2.settings.themePreset'], 'github');
    // The next run is no longer new, and the saved choice holds.
    expect((await load(backend)).themePreset, OpenCodeThemePreset.github);
  });

  test('a default chosen after that stays the default', () async {
    final backend = FakeMetadataBackend();
    final first = await load(backend);
    first.setThemePreset(null);
    await pumpEventQueue();
    expect((await load(backend)).themePreset, isNull);
  });

  test('a shortcut saved during the first load does not hold it', () async {
    final preferences = AppPreferencesController(
      store: V2MetadataStore(backend: FakeMetadataBackend()),
    );
    addTearDown(preferences.dispose);
    final loading = preferences.initialize();
    // Its save waits for the load, which must not wait for it.
    preferences.setShortcutBinding(ShortcutAction.openSettings, 'a');
    await loading.timeout(const Duration(seconds: 2));
    expect(preferences.themePreset, OpenCodeThemePreset.github);
  });

  test('an existing install keeps what it had', () async {
    final backend = FakeMetadataBackend()
      ..values[V2MetadataStore.schemaKey] = 1;
    final preferences = await load(backend);
    expect(preferences.themePreset, isNull);
    expect(preferences.showSessionTabs, isTrue);
    expect(backend.values.containsKey('cw2.settings.themePreset'), isFalse);
    expect(backend.values.containsKey('cw2.settings.showSessionTabs'), isFalse);
  });

  group('session tabs on a new install', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${platform.name} starts without them, and keeps it', () async {
        debugDefaultTargetPlatformOverride = platform;
        final backend = FakeMetadataBackend();
        expect((await load(backend)).showSessionTabs, isFalse);
        expect(backend.values['cw2.settings.showSessionTabs'], isFalse);
        expect((await load(backend)).showSessionTabs, isFalse);
      });
    }

    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test('${platform.name} starts with them', () async {
        debugDefaultTargetPlatformOverride = platform;
        final backend = FakeMetadataBackend();
        expect((await load(backend)).showSessionTabs, isTrue);
        expect(
          backend.values.containsKey('cw2.settings.showSessionTabs'),
          isFalse,
        );
      });
    }

    test('a phone that turns them on keeps them on', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = FakeMetadataBackend();
      (await load(backend)).setShowSessionTabs(true);
      await pumpEventQueue();
      expect((await load(backend)).showSessionTabs, isTrue);
    });

    test('a choice made during the first load wins', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final preferences = AppPreferencesController(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      );
      addTearDown(preferences.dispose);
      final loading = preferences.initialize();
      preferences
        ..setShowSessionTabs(false)
        ..setShowSessionTabs(true);
      await loading;
      expect(preferences.showSessionTabs, isTrue);
    });

    test('an existing phone install keeps its tabs', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final backend = FakeMetadataBackend()
        ..values[V2MetadataStore.schemaKey] = 1;
      expect((await load(backend)).showSessionTabs, isTrue);
    });
  });
}
