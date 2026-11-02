import 'package:codewalk/shared/theme/app_surface_tokens.dart';
import 'package:codewalk/shared/theme/app_theme.dart';
import 'package:codewalk/shared/theme/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds light and dark material3 themes', () {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: AppTheme.seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppTheme.seedColor,
      brightness: Brightness.dark,
    );

    final lightTheme = AppTheme.lightFrom(lightScheme);
    final darkTheme = AppTheme.darkFrom(darkScheme);

    expect(lightTheme.useMaterial3, isTrue);
    expect(darkTheme.useMaterial3, isTrue);
    expect(lightTheme.brightness, Brightness.light);
    expect(darkTheme.brightness, Brightness.dark);
  });

  test('adds the single visual style tokens to every theme', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppTheme.seedColor);
    final theme = AppTheme.lightFrom(scheme);

    final tokens = theme.extension<AppSurfaceTokens>();

    expect(tokens, isNotNull);
    expect(tokens!.cardRadius, BorderRadius.circular(14));
  });

  test('preserves caller extensions beside visual style tokens', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppTheme.seedColor);
    const callerTokens = _CallerTokens(42);
    final theme = AppTheme.lightFrom(
      scheme,
      themeExtensions: <ThemeExtension<dynamic>>[callerTokens],
    );

    expect(theme.extension<_CallerTokens>(), same(callerTokens));
    expect(theme.extension<AppSurfaceTokens>(), isNotNull);
  });

  test('maps density helpers consistently', () {
    expect(AppTheme.usesCompactLayout(AppDensity.extraDense), isTrue);
    expect(AppTheme.usesCompactLayout(AppDensity.dense), isTrue);
    expect(AppTheme.usesCompactLayout(AppDensity.normal), isFalse);

    expect(
      AppTheme.visualDensityFor(AppDensity.extraDense),
      const VisualDensity(horizontal: -2, vertical: -2),
    );
    expect(
      AppTheme.visualDensityFor(AppDensity.extraSpacious),
      const VisualDensity(horizontal: 2, vertical: 2),
    );
  });

  test('applies every density tier to the resulting Material theme', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppTheme.seedColor);
    const expected = <AppDensity, VisualDensity>{
      AppDensity.extraDense: VisualDensity(horizontal: -2, vertical: -2),
      AppDensity.dense: VisualDensity.compact,
      AppDensity.normal: VisualDensity.standard,
      AppDensity.spacious: VisualDensity.comfortable,
      AppDensity.extraSpacious: VisualDensity(horizontal: 2, vertical: 2),
    };
    for (final entry in expected.entries) {
      final theme = AppTheme.lightFrom(scheme, appDensity: entry.key);
      expect(theme.visualDensity, entry.value, reason: entry.key.name);
    }
  });

  test('visual tokens interpolate between light and dark schemes', () {
    final scheme = ColorScheme.fromSeed(seedColor: AppTheme.seedColor);
    final light = AppSurfaceTokens.fromScheme(scheme, Brightness.light);
    final dark = AppSurfaceTokens.fromScheme(scheme, Brightness.dark);
    final middle = light.lerp(dark, 0.5) as AppSurfaceTokens;

    expect(
      (light.lerp(dark, 0) as AppSurfaceTokens).cardSurface,
      light.cardSurface,
    );
    expect(
      (light.lerp(dark, 1) as AppSurfaceTokens).cardSurface,
      dark.cardSurface,
    );
    expect(
      middle.cardSurface,
      Color.lerp(light.cardSurface, dark.cardSurface, 0.5),
    );
    expect(
      middle.controlRadius,
      BorderRadius.lerp(light.controlRadius, dark.controlRadius, 0.5),
    );
  });

  test('uses simple mobile snackbar styling without close icon', () {
    final theme = AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    final resolved = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(390, 844)),
    );

    expect(resolved.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(resolved.snackBarTheme.showCloseIcon, isFalse);
    expect(
      resolved.snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(16, 8, 16, 16),
    );
    expect(resolved.snackBarTheme.width, isNull);
    expect(
      (resolved.snackBarTheme.shape! as RoundedRectangleBorder).borderRadius,
      theme.surfaceTokens.controlRadius,
    );
  });

  test('uses the visual style control radius for snackbars', () {
    final theme = AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    final resolved = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(390, 844)),
    );

    expect(
      (resolved.snackBarTheme.shape! as RoundedRectangleBorder).borderRadius,
      theme.surfaceTokens.controlRadius,
    );
  });

  test('limits desktop snackbar width through lateral inset padding', () {
    final theme = AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    final resolved = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(1200, 900)),
    );

    expect(resolved.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(resolved.snackBarTheme.showCloseIcon, isTrue);
    expect(
      resolved.snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(756, 8, 24, 24),
    );
    expect(resolved.snackBarTheme.width, isNull);
    expect(
      (resolved.snackBarTheme.shape! as RoundedRectangleBorder).borderRadius,
      theme.surfaceTokens.controlRadius,
    );
  });

  test('mirrors desktop snackbar lateral side in RTL layouts', () {
    final theme = AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    final resolved = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(1200, 900)),
      textDirection: TextDirection.rtl,
    );

    expect(
      resolved.snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(24, 8, 756, 24),
    );
  });

  test('uses expanded window size class for desktop snackbar layout', () {
    final theme = AppTheme.lightFrom(
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );

    final medium = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(839, 900)),
    );
    final expanded = AppTheme.withResponsiveSnackBars(
      theme,
      const MediaQueryData(size: Size(840, 900)),
    );

    expect(
      medium.snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(16, 8, 16, 16),
    );
    expect(medium.snackBarTheme.showCloseIcon, isFalse);
    expect(
      expanded.snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(396, 8, 24, 24),
    );
    expect(expanded.snackBarTheme.showCloseIcon, isTrue);
  });

  test('scales composer model controls by density', () {
    expect(
      AppDensitySpacing.composerModelControlsPadding(AppDensity.normal),
      const EdgeInsets.fromLTRB(8, 0, 8, 2),
    );
    expect(AppDensitySpacing.composerModelControlGap(AppDensity.normal), 8);
    expect(
      AppDensitySpacing.composerModelControlChipPadding(AppDensity.normal),
      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonPadding(AppDensity.normal),
      const EdgeInsets.all(8),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonSize(AppDensity.normal),
      const Size.square(40),
    );

    expect(
      AppDensitySpacing.composerModelControlGap(AppDensity.extraDense),
      lessThan(AppDensitySpacing.composerModelControlGap(AppDensity.normal)),
    );
    expect(
      AppDensitySpacing.composerModelControlGap(AppDensity.extraSpacious),
      greaterThan(AppDensitySpacing.composerModelControlGap(AppDensity.normal)),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonSize(AppDensity.extraDense),
      const Size.square(40),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonSize(AppDensity.dense),
      const Size.square(40),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonSize(AppDensity.spacious),
      const Size.square(44),
    );
    expect(
      AppDensitySpacing.composerModelControlButtonSize(
        AppDensity.extraSpacious,
      ),
      const Size.square(48),
    );
    for (final density in AppDensity.values) {
      expect(
        AppDensitySpacing.composerModelControlButtonSize(density).width,
        greaterThanOrEqualTo(40),
      );
      expect(
        AppDensitySpacing.composerModelControlButtonSize(density).height,
        greaterThanOrEqualTo(40),
      );
    }
  });
}

@immutable
class _CallerTokens extends ThemeExtension<_CallerTokens> {
  const _CallerTokens(this.value);

  final double value;

  @override
  _CallerTokens copyWith({double? value}) => _CallerTokens(value ?? this.value);

  @override
  _CallerTokens lerp(covariant _CallerTokens? other, double t) =>
      other == null ? this : _CallerTokens(value + (other.value - value) * t);
}
