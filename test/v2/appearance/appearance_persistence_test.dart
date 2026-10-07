import 'dart:async';

import 'package:codewalk/app/app_preferences_controller.dart';
import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppPreferencesController controller(FakeMetadataBackend backend) =>
      AppPreferencesController(store: V2MetadataStore(backend: backend));

  test('hydration consumes imported values without writing defaults', () async {
    final backend = FakeMetadataBackend();
    backend.values.addAll({
      'cw2.schema': 1,
      'cw2.settings.themeMode': 'dark',
      'cw2.settings.visualStyle': 'classic',
      'cw2.settings.themePreset': 'oc-1',
      'cw2.settings.appDensity': 'extra_dense',
      'cw2.settings.customColorSeed': 0xFF6750A4.toDouble(),
      'cw2.settings.contrastLevel': 1,
      'cw2.settings.useAmoledDark': true,
      'cw2.settings.useDynamicColor': false,
      'cw2.settings.localeCode': 'pt',
    });
    final graph = await loadAppDependencies(
      metadataStore: V2MetadataStore(backend: backend),
    );
    addTearDown(graph.dispose);
    final p = graph.preferences;
    expect(p.themeMode, ThemeMode.dark);
    expect(p.visualStyle, VisualStyle.classic);
    expect(p.themePreset, OpenCodeThemePreset.oc2);
    expect(p.density, AppDensity.extraDense);
    expect(p.customColorSeed, 0xFF6750A4);
    expect(p.contrastLevel, 1);
    expect(p.useAmoledDark, isTrue);
    expect(p.useDynamicColor, isFalse);
    expect(p.locale, isNull);
    expect(backend.writes, isEmpty);
  });

  test(
    'round trip and nullable clears touch only the selected v2 keys',
    () async {
      final backend = FakeMetadataBackend();
      backend.values['legacy.settings'] = 'untouched';
      final first = controller(backend);
      addTearDown(first.dispose);
      await first.initialize();
      first.setThemeMode(ThemeMode.dark);
      first.setVisualStyle(VisualStyle.classic);
      first.setDensity(AppDensity.extraSpacious);
      first.setThemePreset(OpenCodeThemePreset.dracula);
      first.setCustomColorSeed(0xFF006B5E);
      first.setContrastLevel(0.5);
      first.setUseAmoledDark(true);
      first.setUseDynamicColor(false);
      await first.flush();
      final second = controller(backend);
      addTearDown(second.dispose);
      await second.initialize();
      expect(second.themeMode, ThemeMode.dark);
      expect(second.visualStyle, VisualStyle.classic);
      expect(second.density, AppDensity.extraSpacious);
      expect(second.themePreset, OpenCodeThemePreset.dracula);
      expect(second.customColorSeed, 0xFF006B5E);
      expect(second.contrastLevel, 0.5);
      expect(second.useAmoledDark, isTrue);
      expect(second.useDynamicColor, isFalse);
      second.setThemePreset(null);
      second.setCustomColorSeed(null);
      await second.flush();
      expect(backend.values.containsKey('cw2.settings.themePreset'), isFalse);
      expect(
        backend.values.containsKey('cw2.settings.customColorSeed'),
        isFalse,
      );
      expect(backend.values['legacy.settings'], 'untouched');
      expect(backend.removals.toSet(), {
        'cw2.settings.themePreset',
        'cw2.settings.customColorSeed',
      });
    },
  );

  test(
    'invalid fields remain stored without poisoning valid preferences',
    () async {
      final backend = FakeMetadataBackend();
      backend.values.addAll({
        'cw2.settings.themeMode': 42,
        'cw2.settings.themePreset': 'unknown',
        'cw2.settings.appDensity': 'unknown',
        'cw2.settings.customColorSeed': double.infinity,
        'cw2.settings.contrastLevel': double.nan,
        'cw2.settings.useAmoledDark': true,
      });
      final p = controller(backend);
      addTearDown(p.dispose);
      await p.initialize();
      expect(p.themeMode, ThemeMode.system);
      expect(p.visualStyle, VisualStyle.refined);
      expect(p.themePreset, isNull);
      expect(p.density, AppDensity.normal);
      expect(p.customColorSeed, isNull);
      expect(p.contrastLevel, 0);
      expect(p.useAmoledDark, isTrue);
      expect(backend.values['cw2.settings.themePreset'], 'unknown');
      expect(backend.writes, ['cw2.schema']);
    },
  );

  test(
    'rapid changes serialize and disposal keeps the last accepted write',
    () async {
      final backend = FakeMetadataBackend();
      final p = controller(backend);
      await p.initialize();
      backend.blockedKey = 'cw2.settings.contrastLevel';
      backend.entered = Completer<void>();
      backend.release = Completer<void>();
      p.setContrastLevel(-0.5);
      await backend.entered!.future;
      p.setContrastLevel(0.5);
      p.setContrastLevel(1);
      var afterDispose = 0;
      p.addListener(() => afterDispose++);
      p.dispose();
      backend.release!.complete();
      await p.flush();
      p.setContrastLevel(0);
      expect(backend.values['cw2.settings.contrastLevel'], 1);
      expect(afterDispose, 0);
    },
  );

  test('failure is visible and retry saves the current choice', () async {
    final backend = FakeMetadataBackend();
    final p = controller(backend);
    addTearDown(p.dispose);
    await p.initialize();
    backend.failWrite = 'cw2.settings.themeMode';
    p.setThemeMode(ThemeMode.dark);
    await p.flush();
    expect(p.hasPersistenceError, isTrue);
    expect(p.themeMode, ThemeMode.dark);
    backend.failWrite = null;
    await p.retryPersistence();
    expect(p.hasPersistenceError, isFalse);
    expect(backend.values['cw2.settings.themeMode'], 'dark');
  });

  test('future schema preserves data and reports unsaved choices', () async {
    final backend = FakeMetadataBackend();
    backend.values.addAll({
      'cw2.schema': 99,
      'cw2.settings.themeMode': 'light',
    });
    final p = controller(backend);
    addTearDown(p.dispose);
    await p.initialize();
    p.setThemeMode(ThemeMode.dark);
    await p.flush();
    expect(p.hasPersistenceError, isTrue);
    expect(backend.values['cw2.settings.themeMode'], 'light');
    expect(backend.writes, isEmpty);
  });
}
