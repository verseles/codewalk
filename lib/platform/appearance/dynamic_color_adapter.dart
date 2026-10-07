import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;

typedef DynamicSchemeBuilder =
    Widget Function(ColorScheme? light, ColorScheme? dark);
typedef DynamicColorSource = Widget Function(DynamicSchemeBuilder builder);

Widget platformDynamicColors(DynamicSchemeBuilder builder) =>
    DynamicColorBuilder(
      builder: (light, dark) => builder(
        light == null ? null : muiSchemeToFlutter(light),
        dark == null ? null : muiSchemeToFlutter(dark),
      ),
    );

/// dynamic_color 2.x reports material_ui schemes; copy every current M3 role.
ColorScheme muiSchemeToFlutter(mui.ColorScheme scheme) => ColorScheme(
  brightness: scheme.brightness,
  primary: scheme.primary,
  onPrimary: scheme.onPrimary,
  primaryContainer: scheme.primaryContainer,
  onPrimaryContainer: scheme.onPrimaryContainer,
  primaryFixed: scheme.primaryFixed,
  primaryFixedDim: scheme.primaryFixedDim,
  onPrimaryFixed: scheme.onPrimaryFixed,
  onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
  secondary: scheme.secondary,
  onSecondary: scheme.onSecondary,
  secondaryContainer: scheme.secondaryContainer,
  onSecondaryContainer: scheme.onSecondaryContainer,
  secondaryFixed: scheme.secondaryFixed,
  secondaryFixedDim: scheme.secondaryFixedDim,
  onSecondaryFixed: scheme.onSecondaryFixed,
  onSecondaryFixedVariant: scheme.onSecondaryFixedVariant,
  tertiary: scheme.tertiary,
  onTertiary: scheme.onTertiary,
  tertiaryContainer: scheme.tertiaryContainer,
  onTertiaryContainer: scheme.onTertiaryContainer,
  tertiaryFixed: scheme.tertiaryFixed,
  tertiaryFixedDim: scheme.tertiaryFixedDim,
  onTertiaryFixed: scheme.onTertiaryFixed,
  onTertiaryFixedVariant: scheme.onTertiaryFixedVariant,
  error: scheme.error,
  onError: scheme.onError,
  errorContainer: scheme.errorContainer,
  onErrorContainer: scheme.onErrorContainer,
  surface: scheme.surface,
  onSurface: scheme.onSurface,
  surfaceDim: scheme.surfaceDim,
  surfaceBright: scheme.surfaceBright,
  surfaceContainerLowest: scheme.surfaceContainerLowest,
  surfaceContainerLow: scheme.surfaceContainerLow,
  surfaceContainer: scheme.surfaceContainer,
  surfaceContainerHigh: scheme.surfaceContainerHigh,
  surfaceContainerHighest: scheme.surfaceContainerHighest,
  onSurfaceVariant: scheme.onSurfaceVariant,
  outline: scheme.outline,
  outlineVariant: scheme.outlineVariant,
  shadow: scheme.shadow,
  scrim: scheme.scrim,
  inverseSurface: scheme.inverseSurface,
  onInverseSurface: scheme.onInverseSurface,
  inversePrimary: scheme.inversePrimary,
  surfaceTint: scheme.surfaceTint,
);
