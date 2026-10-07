import 'package:codewalk/domain/entities/experience_settings.dart'
    as legacy_model;
import 'package:codewalk/platform/appearance/dynamic_color_adapter.dart';
import 'package:codewalk/presentation/theme/opencode_theme_presets.dart'
    as legacy;
import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/theme/appearance_theme_resolver.dart';
import 'package:codewalk/shared/theme/opencode_theme_preferences.dart';
import 'package:codewalk/shared/theme/opencode_theme_presets.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;

void main() {
  test(
    'all 37 presets retain the consolidated v1 palettes and semantic colors',
    () {
      expect(openCodeThemePresetOptions(), hasLength(37));
      for (final preset in openCodeThemePresetOptions()) {
        final id = openCodeThemePresetKey(preset);
        final old = legacy_model.openCodeThemePresetFromKey(id)!;
        expect(openCodeThemePresetFromKey(id), preset);
        expect(
          openCodeLightSchemeFor(preset),
          legacy.openCodeLightSchemeFor(old),
        );
        expect(
          openCodeDarkSchemeFor(preset),
          legacy.openCodeDarkSchemeFor(old),
        );
        for (final brightness in Brightness.values) {
          final tokens = openCodeThemeTokensFor(preset, brightness)!;
          final oldTokens = legacy.openCodeThemeTokensFor(old, brightness)!;
          expect(tokens.markdownLink, oldTokens.markdownLink);
          expect(tokens.syntaxKeyword, oldTokens.syntaxKeyword);
          expect(tokens.surfaceBase, oldTokens.surfaceBase);
        }
      }
      expect(openCodeThemePresetFromKey('oc-1'), OpenCodeThemePreset.oc2);
      expect(openCodeThemePresetFromKey('system'), OpenCodeThemePreset.oc2);
      expect(openCodeThemePresetFromKey('unknown'), isNull);
    },
  );

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

  test('all five density tiers resolve in both visual styles', () {
    for (final density in AppDensity.values) {
      for (final style in VisualStyle.values) {
        final result = resolveAppearanceThemes(
          density: density,
          visualStyle: style,
        );
        expect(result.light.visualDensity, AppTheme.visualDensityFor(density));
        expect(result.dark.visualDensity, AppTheme.visualDensityFor(density));
      }
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
