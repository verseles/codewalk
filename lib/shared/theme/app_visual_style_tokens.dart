import 'package:flutter/material.dart';

import 'app_shapes.dart';
import 'theme_preferences.dart';

@immutable
class AppVisualStyleTokens extends ThemeExtension<AppVisualStyleTokens> {
  const AppVisualStyleTokens({
    required this.visualStyle,
    required this.cardRadius,
    required this.controlRadius,
    required this.panelRadius,
    required this.dialogRadius,
    required this.bubbleRadius,
    required this.bubbleTightCornerRadius,
    required this.cardSurface,
    required this.panelSurface,
    required this.composerSurface,
    required this.mutedControlSurface,
    required this.selectedSurface,
    required this.separator,
    required this.focusBorder,
    required this.softShadow,
    required this.dividerThickness,
    required this.focusedBorderWidth,
    required this.enabledBorderWidth,
    required this.composerShadow,
  });

  factory AppVisualStyleTokens.classic(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    return AppVisualStyleTokens(
      visualStyle: VisualStyle.classic,
      cardRadius: AppShapes.borderExtraLarge,
      controlRadius: AppShapes.borderLarge,
      panelRadius: AppShapes.borderLarge,
      dialogRadius: AppShapes.borderExtraLarge,
      bubbleRadius: AppShapes.borderLarge,
      bubbleTightCornerRadius: const Radius.circular(6),
      cardSurface: colorScheme.surfaceContainerLow,
      panelSurface: colorScheme.surfaceContainer,
      composerSurface: Color.alphaBlend(
        colorScheme.surfaceContainerHighest.withValues(
          alpha: brightness == Brightness.dark ? 0.94 : 0.96,
        ),
        colorScheme.surface,
      ),
      mutedControlSurface: colorScheme.surfaceContainerHighest,
      selectedSurface: colorScheme.secondaryContainer,
      separator: colorScheme.outlineVariant,
      focusBorder: colorScheme.primary,
      softShadow: Colors.black.withValues(alpha: 0.07),
      dividerThickness: 1,
      focusedBorderWidth: 2,
      enabledBorderWidth: 1,
      composerShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  factory AppVisualStyleTokens.refined(
    ColorScheme colorScheme,
    Brightness brightness,
  ) {
    return AppVisualStyleTokens(
      visualStyle: VisualStyle.refined,
      cardRadius: BorderRadius.circular(14),
      controlRadius: BorderRadius.circular(12),
      panelRadius: BorderRadius.circular(14),
      dialogRadius: BorderRadius.circular(20),
      bubbleRadius: BorderRadius.circular(14),
      bubbleTightCornerRadius: const Radius.circular(5),
      cardSurface: _surfaceOverlay(
        colorScheme,
        brightness == Brightness.dark ? 0.18 : 0.14,
      ),
      panelSurface: _surfaceOverlay(
        colorScheme,
        brightness == Brightness.dark ? 0.14 : 0.10,
      ),
      composerSurface: _surfaceOverlay(
        colorScheme,
        brightness == Brightness.dark ? 0.34 : 0.28,
      ),
      mutedControlSurface: _surfaceOverlay(
        colorScheme,
        brightness == Brightness.dark ? 0.28 : 0.22,
      ),
      selectedSurface: Color.alphaBlend(
        colorScheme.primary.withValues(
          alpha: brightness == Brightness.dark ? 0.18 : 0.12,
        ),
        colorScheme.surface,
      ),
      separator: colorScheme.outlineVariant.withValues(
        alpha: brightness == Brightness.dark ? 0.48 : 0.58,
      ),
      focusBorder: colorScheme.primary,
      softShadow: Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.16 : 0.035,
      ),
      dividerThickness: 0.75,
      focusedBorderWidth: 1.5,
      enabledBorderWidth: 0.75,
      composerShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(
            alpha: brightness == Brightness.dark ? 0.12 : 0.035,
          ),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  final VisualStyle visualStyle;
  final BorderRadius cardRadius;
  final BorderRadius controlRadius;
  final BorderRadius panelRadius;
  final BorderRadius dialogRadius;
  final BorderRadius bubbleRadius;
  final Radius bubbleTightCornerRadius;
  final Color cardSurface;
  final Color panelSurface;
  final Color composerSurface;
  final Color mutedControlSurface;
  final Color selectedSurface;
  final Color separator;
  final Color focusBorder;
  final Color softShadow;
  final double dividerThickness;
  final double focusedBorderWidth;
  final double enabledBorderWidth;
  final List<BoxShadow> composerShadow;

  bool get isRefined => visualStyle == VisualStyle.refined;

  @override
  AppVisualStyleTokens copyWith({
    VisualStyle? visualStyle,
    BorderRadius? cardRadius,
    BorderRadius? controlRadius,
    BorderRadius? panelRadius,
    BorderRadius? dialogRadius,
    BorderRadius? bubbleRadius,
    Radius? bubbleTightCornerRadius,
    Color? cardSurface,
    Color? panelSurface,
    Color? composerSurface,
    Color? mutedControlSurface,
    Color? selectedSurface,
    Color? separator,
    Color? focusBorder,
    Color? softShadow,
    double? dividerThickness,
    double? focusedBorderWidth,
    double? enabledBorderWidth,
    List<BoxShadow>? composerShadow,
  }) {
    return AppVisualStyleTokens(
      visualStyle: visualStyle ?? this.visualStyle,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      bubbleTightCornerRadius:
          bubbleTightCornerRadius ?? this.bubbleTightCornerRadius,
      cardSurface: cardSurface ?? this.cardSurface,
      panelSurface: panelSurface ?? this.panelSurface,
      composerSurface: composerSurface ?? this.composerSurface,
      mutedControlSurface: mutedControlSurface ?? this.mutedControlSurface,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      separator: separator ?? this.separator,
      focusBorder: focusBorder ?? this.focusBorder,
      softShadow: softShadow ?? this.softShadow,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
      enabledBorderWidth: enabledBorderWidth ?? this.enabledBorderWidth,
      composerShadow: composerShadow ?? this.composerShadow,
    );
  }

  @override
  ThemeExtension<AppVisualStyleTokens> lerp(
    covariant ThemeExtension<AppVisualStyleTokens>? other,
    double t,
  ) {
    if (other is! AppVisualStyleTokens) {
      return this;
    }
    return AppVisualStyleTokens(
      visualStyle: t < 0.5 ? visualStyle : other.visualStyle,
      cardRadius: BorderRadius.lerp(cardRadius, other.cardRadius, t)!,
      controlRadius: BorderRadius.lerp(controlRadius, other.controlRadius, t)!,
      panelRadius: BorderRadius.lerp(panelRadius, other.panelRadius, t)!,
      dialogRadius: BorderRadius.lerp(dialogRadius, other.dialogRadius, t)!,
      bubbleRadius: BorderRadius.lerp(bubbleRadius, other.bubbleRadius, t)!,
      bubbleTightCornerRadius: Radius.lerp(
        bubbleTightCornerRadius,
        other.bubbleTightCornerRadius,
        t,
      )!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      composerSurface: Color.lerp(composerSurface, other.composerSurface, t)!,
      mutedControlSurface: Color.lerp(
        mutedControlSurface,
        other.mutedControlSurface,
        t,
      )!,
      selectedSurface: Color.lerp(selectedSurface, other.selectedSurface, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      focusBorder: Color.lerp(focusBorder, other.focusBorder, t)!,
      softShadow: Color.lerp(softShadow, other.softShadow, t)!,
      dividerThickness: _lerpDouble(
        dividerThickness,
        other.dividerThickness,
        t,
      ),
      focusedBorderWidth: _lerpDouble(
        focusedBorderWidth,
        other.focusedBorderWidth,
        t,
      ),
      enabledBorderWidth: _lerpDouble(
        enabledBorderWidth,
        other.enabledBorderWidth,
        t,
      ),
      composerShadow:
          BoxShadow.lerpList(composerShadow, other.composerShadow, t) ??
          composerShadow,
    );
  }
}

extension AppVisualStyleTokensX on ThemeData {
  AppVisualStyleTokens get visualStyleTokens =>
      extension<AppVisualStyleTokens>() ??
      AppVisualStyleTokens.classic(colorScheme, brightness);
}

Color _surfaceOverlay(ColorScheme colorScheme, double alpha) {
  return Color.alphaBlend(
    colorScheme.surfaceContainerHighest.withValues(alpha: alpha),
    colorScheme.surface,
  );
}

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
