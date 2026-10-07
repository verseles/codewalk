import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'opencode_theme_preferences.dart';
import 'opencode_theme_presets.dart';
import 'theme_preferences.dart';

/// The consolidated v1 precedence, independent of storage and platform plugins.
({ThemeData light, ThemeData dark}) resolveAppearanceThemes({
  OpenCodeThemePreset? preset,
  int? customColorSeed,
  double contrastLevel = 0,
  bool useDynamicColor = true,
  bool useAmoledDark = false,
  AppDensity density = AppDensity.normal,
  VisualStyle visualStyle = VisualStyle.refined,
  ColorScheme? lightDynamic,
  ColorScheme? darkDynamic,
}) {
  final seed = customColorSeed == null
      ? AppTheme.seedColor
      : Color(customColorSeed);
  ColorScheme resolve(Brightness brightness, ColorScheme? dynamic) =>
      (brightness == Brightness.light
          ? openCodeLightSchemeFor(preset)
          : openCodeDarkSchemeFor(preset)) ??
      (useDynamicColor ? dynamic : null) ??
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        contrastLevel: contrastLevel.isFinite ? contrastLevel.clamp(-1, 1) : 0,
      );
  final light = resolve(Brightness.light, lightDynamic);
  var dark = resolve(Brightness.dark, darkDynamic);
  if (useAmoledDark) {
    dark = dark.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: Colors.black,
      surfaceContainer: Colors.black,
      surfaceContainerHigh: Colors.black,
      surfaceContainerHighest: Colors.black,
    );
  }
  return (
    light: AppTheme.lightFrom(
      light,
      appDensity: density,
      visualStyle: visualStyle,
      themeExtensions: [
        openCodeThemeTokensFor(preset, Brightness.light) ??
            classicThemeTokensFrom(light),
      ],
    ),
    dark: AppTheme.darkFrom(
      dark,
      appDensity: density,
      visualStyle: visualStyle,
      themeExtensions: [
        openCodeThemeTokensFor(preset, Brightness.dark) ??
            classicThemeTokensFrom(dark),
      ],
    ),
  );
}
