import 'dart:convert';

import 'package:codewalk/platform/appearance/dynamic_color_adapter.dart';
import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/theme/appearance_theme_resolver.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:codewalk/shared/theme/opencode_theme_presets.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;

void main() {
  test('all 37 presets resolve by key and unknown keys do not', () {
    expect(openCodeThemePresetOptions(), hasLength(37));
    for (final preset in openCodeThemePresetOptions()) {
      expect(
        openCodeThemePresetFromKey(openCodeThemePresetKey(preset)),
        preset,
      );
    }
    expect(openCodeThemePresetFromKey('oc-1'), OpenCodeThemePreset.oc2);
    expect(openCodeThemePresetFromKey('system'), OpenCodeThemePreset.oc2);
    expect(openCodeThemePresetFromKey('unknown'), isNull);
  });

  // The palettes are frozen, with no generator left. The value was taken when
  // all 37 presets still compared equal to the consolidated v1 palettes. A
  // deliberate palette change updates it.
  test('the frozen palettes of all presets keep their values', () {
    String colors(Iterable<Color> values) =>
        values.map((color) => color.toARGB32()).join(',');
    String scheme(ColorScheme value) => colors([
      value.primary,
      value.onPrimary,
      value.primaryContainer,
      value.onPrimaryContainer,
      value.secondary,
      value.onSecondary,
      value.tertiary,
      value.onTertiary,
      value.error,
      value.onError,
      value.surface,
      value.onSurface,
      value.onSurfaceVariant,
      value.outline,
      value.outlineVariant,
    ]);
    final buffer = StringBuffer();
    for (final preset in openCodeThemePresetOptions()) {
      buffer.writeln(openCodeThemePresetKey(preset));
      buffer.writeln(scheme(openCodeLightSchemeFor(preset)!));
      buffer.writeln(scheme(openCodeDarkSchemeFor(preset)!));
      for (final brightness in Brightness.values) {
        final tokens = openCodeThemeTokensFor(preset, brightness)!;
        buffer.writeln(
          colors([
            tokens.markdownLink,
            tokens.syntaxKeyword,
            tokens.surfaceBase,
          ]),
        );
      }
    }
    expect(
      sha256.convert(utf8.encode(buffer.toString())).toString(),
      '8d39830c2dccd65a6b47c114bb95597260f785f874f28ab0cf07bab6d6cb9856',
    );
  });

  test('preset precedes dynamic; missing brightness uses seeded contrast', () {
    final dynamic = ColorScheme.fromSeed(seedColor: Colors.green);
    final preset = resolveAppearanceThemes(
      preset: OpenCodeThemePreset.dracula,
      lightDynamic: dynamic,
      contrastLevel: 1,
    );
    expect(
      preset.light.colorScheme,
      openCodeLightSchemeFor(OpenCodeThemePreset.dracula),
    );
    final partial = resolveAppearanceThemes(
      lightDynamic: dynamic,
      contrastLevel: 1,
    );
    expect(partial.light.colorScheme, dynamic);
    expect(
      partial.dark.colorScheme,
      ColorScheme.fromSeed(
        seedColor: AppTheme.seedColor,
        brightness: Brightness.dark,
        contrastLevel: 1,
      ),
    );
    final disabled = resolveAppearanceThemes(
      lightDynamic: dynamic,
      useDynamicColor: false,
      customColorSeed: 0xFF6750A4,
      contrastLevel: 0.5,
    );
    expect(
      disabled.light.colorScheme,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        contrastLevel: 0.5,
      ),
    );
  });

  test('AMOLED changes dark surfaces only and retains preset tokens', () {
    final base = resolveAppearanceThemes(preset: OpenCodeThemePreset.dracula);
    final amoled = resolveAppearanceThemes(
      preset: OpenCodeThemePreset.dracula,
      useAmoledDark: true,
    );
    expect(amoled.light.colorScheme, base.light.colorScheme);
    final d = amoled.dark.colorScheme;
    expect([
      d.surface,
      d.surfaceDim,
      d.surfaceBright,
      d.surfaceContainerLowest,
      d.surfaceContainerLow,
      d.surfaceContainer,
      d.surfaceContainerHigh,
      d.surfaceContainerHighest,
    ], everyElement(Colors.black));
    expect(d.primary, base.dark.colorScheme.primary);
    expect(
      amoled.dark.extension<OpenCodeThemeTokens>()!.surfaceBase,
      base.dark.extension<OpenCodeThemeTokens>()!.surfaceBase,
    );
  });

  test('all five density tiers resolve to their visual density', () {
    for (final density in AppDensity.values) {
      final result = resolveAppearanceThemes(density: density);
      expect(result.light.visualDensity, AppTheme.visualDensityFor(density));
      expect(result.dark.visualDensity, AppTheme.visualDensityFor(density));
    }
  });

  test(
    'dynamic adapter preserves custom roles instead of regenerating a seed',
    () {
      final source = mui.ColorScheme.fromSeed(seedColor: Colors.purple)
          .copyWith(
            primaryFixedDim: Colors.orange,
            onPrimaryFixedVariant: Colors.blue,
            surfaceContainerHighest: Colors.pink,
            inversePrimary: Colors.teal,
            surfaceTint: Colors.red,
          );
      final actual = muiSchemeToFlutter(source);
      expect(actual.primaryFixedDim, Colors.orange);
      expect(actual.onPrimaryFixedVariant, Colors.blue);
      expect(actual.surfaceContainerHighest, Colors.pink);
      expect(actual.inversePrimary, Colors.teal);
      expect(actual.surfaceTint, Colors.red);
      expect(actual.primary, source.primary);
      expect(actual.onSurface, source.onSurface);
    },
  );
}
