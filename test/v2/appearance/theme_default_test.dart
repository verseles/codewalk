import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/shortcuts/shortcut_action.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

// #553: a new install starts on the GitHub theme; an existing one keeps its.

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
    expect((await load(backend)).themePreset, isNull);
    expect(backend.values.containsKey('cw2.settings.themePreset'), isFalse);
  });
}
