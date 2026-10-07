// GENERATED CODE - DO NOT MODIFY BY HAND.
// Offline selective port: tool/theme/port_v2_appearance.py

import 'package:flutter/material.dart';

import 'opencode_theme_preferences.dart';
import 'opencode_web_theme_registry.dart';

const OpenCodeThemePreset kDefaultOpenCodeThemePreset = OpenCodeThemePreset.oc2;

@immutable
class OpenCodeThemePalette {
  const OpenCodeThemePalette({
    required this.id,
    required this.label,
    required this.seedColor,
  });

  final String id;
  final String label;
  final Color seedColor;
}

@immutable
class OpenCodeThemeTokens extends ThemeExtension<OpenCodeThemeTokens> {
  const OpenCodeThemeTokens({
    required this.themeId,
    required this.themeLabel,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.inlineCodeBackground,
    required this.codeBlockBackground,
    required this.border,
    required this.textBase,
    required this.textMuted,
    required this.markdownHeading,
    required this.markdownLink,
    required this.markdownLinkText,
    required this.markdownInlineCode,
    required this.markdownCodeBlock,
    required this.markdownBlockQuote,
    required this.markdownEmphasis,
    required this.markdownStrong,
    required this.markdownHorizontalRule,
    required this.markdownListItem,
    required this.markdownListEnumeration,
    required this.markdownImage,
    required this.markdownImageText,
    required this.syntaxComment,
    required this.syntaxKeyword,
    required this.syntaxFunction,
    required this.syntaxVariable,
    required this.syntaxString,
    required this.syntaxNumber,
    required this.syntaxType,
    required this.syntaxOperator,
    required this.syntaxPunctuation,
    required this.syntaxProperty,
    required this.syntaxConstant,
  });

  final String themeId;
  final String themeLabel;
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color inlineCodeBackground;
  final Color codeBlockBackground;
  final Color border;
  final Color textBase;
  final Color textMuted;
  final Color markdownHeading;
  final Color markdownLink;
  final Color markdownLinkText;
  final Color markdownInlineCode;
  final Color markdownCodeBlock;
  final Color markdownBlockQuote;
  final Color markdownEmphasis;
  final Color markdownStrong;
  final Color markdownHorizontalRule;
  final Color markdownListItem;
  final Color markdownListEnumeration;
  final Color markdownImage;
  final Color markdownImageText;
  final Color syntaxComment;
  final Color syntaxKeyword;
  final Color syntaxFunction;
  final Color syntaxVariable;
  final Color syntaxString;
  final Color syntaxNumber;
  final Color syntaxType;
  final Color syntaxOperator;
  final Color syntaxPunctuation;
  final Color syntaxProperty;
  final Color syntaxConstant;

  @override
  OpenCodeThemeTokens copyWith({
    String? themeId,
    String? themeLabel,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? inlineCodeBackground,
    Color? codeBlockBackground,
    Color? border,
    Color? textBase,
    Color? textMuted,
    Color? markdownHeading,
    Color? markdownLink,
    Color? markdownLinkText,
    Color? markdownInlineCode,
    Color? markdownCodeBlock,
    Color? markdownBlockQuote,
    Color? markdownEmphasis,
    Color? markdownStrong,
    Color? markdownHorizontalRule,
    Color? markdownListItem,
    Color? markdownListEnumeration,
    Color? markdownImage,
    Color? markdownImageText,
    Color? syntaxComment,
    Color? syntaxKeyword,
    Color? syntaxFunction,
    Color? syntaxVariable,
    Color? syntaxString,
    Color? syntaxNumber,
    Color? syntaxType,
    Color? syntaxOperator,
    Color? syntaxPunctuation,
    Color? syntaxProperty,
    Color? syntaxConstant,
  }) {
    return OpenCodeThemeTokens(
      themeId: themeId ?? this.themeId,
      themeLabel: themeLabel ?? this.themeLabel,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      inlineCodeBackground: inlineCodeBackground ?? this.inlineCodeBackground,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      border: border ?? this.border,
      textBase: textBase ?? this.textBase,
      textMuted: textMuted ?? this.textMuted,
      markdownHeading: markdownHeading ?? this.markdownHeading,
      markdownLink: markdownLink ?? this.markdownLink,
      markdownLinkText: markdownLinkText ?? this.markdownLinkText,
      markdownInlineCode: markdownInlineCode ?? this.markdownInlineCode,
      markdownCodeBlock: markdownCodeBlock ?? this.markdownCodeBlock,
      markdownBlockQuote: markdownBlockQuote ?? this.markdownBlockQuote,
      markdownEmphasis: markdownEmphasis ?? this.markdownEmphasis,
      markdownStrong: markdownStrong ?? this.markdownStrong,
      markdownHorizontalRule:
          markdownHorizontalRule ?? this.markdownHorizontalRule,
      markdownListItem: markdownListItem ?? this.markdownListItem,
      markdownListEnumeration:
          markdownListEnumeration ?? this.markdownListEnumeration,
      markdownImage: markdownImage ?? this.markdownImage,
      markdownImageText: markdownImageText ?? this.markdownImageText,
      syntaxComment: syntaxComment ?? this.syntaxComment,
      syntaxKeyword: syntaxKeyword ?? this.syntaxKeyword,
      syntaxFunction: syntaxFunction ?? this.syntaxFunction,
      syntaxVariable: syntaxVariable ?? this.syntaxVariable,
      syntaxString: syntaxString ?? this.syntaxString,
      syntaxNumber: syntaxNumber ?? this.syntaxNumber,
      syntaxType: syntaxType ?? this.syntaxType,
      syntaxOperator: syntaxOperator ?? this.syntaxOperator,
      syntaxPunctuation: syntaxPunctuation ?? this.syntaxPunctuation,
      syntaxProperty: syntaxProperty ?? this.syntaxProperty,
      syntaxConstant: syntaxConstant ?? this.syntaxConstant,
    );
  }

  @override
  ThemeExtension<OpenCodeThemeTokens> lerp(
    covariant ThemeExtension<OpenCodeThemeTokens>? other,
    double t,
  ) {
    if (other is! OpenCodeThemeTokens) {
      return this;
    }
    return OpenCodeThemeTokens(
      themeId: t < 0.5 ? themeId : other.themeId,
      themeLabel: t < 0.5 ? themeLabel : other.themeLabel,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      inlineCodeBackground: Color.lerp(
        inlineCodeBackground,
        other.inlineCodeBackground,
        t,
      )!,
      codeBlockBackground: Color.lerp(
        codeBlockBackground,
        other.codeBlockBackground,
        t,
      )!,
      border: Color.lerp(border, other.border, t)!,
      textBase: Color.lerp(textBase, other.textBase, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      markdownHeading: Color.lerp(markdownHeading, other.markdownHeading, t)!,
      markdownLink: Color.lerp(markdownLink, other.markdownLink, t)!,
      markdownLinkText: Color.lerp(
        markdownLinkText,
        other.markdownLinkText,
        t,
      )!,
      markdownInlineCode: Color.lerp(
        markdownInlineCode,
        other.markdownInlineCode,
        t,
      )!,
      markdownCodeBlock: Color.lerp(
        markdownCodeBlock,
        other.markdownCodeBlock,
        t,
      )!,
      markdownBlockQuote: Color.lerp(
        markdownBlockQuote,
        other.markdownBlockQuote,
        t,
      )!,
      markdownEmphasis: Color.lerp(
        markdownEmphasis,
        other.markdownEmphasis,
        t,
      )!,
      markdownStrong: Color.lerp(markdownStrong, other.markdownStrong, t)!,
      markdownHorizontalRule: Color.lerp(
        markdownHorizontalRule,
        other.markdownHorizontalRule,
        t,
      )!,
      markdownListItem: Color.lerp(
        markdownListItem,
        other.markdownListItem,
        t,
      )!,
      markdownListEnumeration: Color.lerp(
        markdownListEnumeration,
        other.markdownListEnumeration,
        t,
      )!,
      markdownImage: Color.lerp(markdownImage, other.markdownImage, t)!,
      markdownImageText: Color.lerp(
        markdownImageText,
        other.markdownImageText,
        t,
      )!,
      syntaxComment: Color.lerp(syntaxComment, other.syntaxComment, t)!,
      syntaxKeyword: Color.lerp(syntaxKeyword, other.syntaxKeyword, t)!,
      syntaxFunction: Color.lerp(syntaxFunction, other.syntaxFunction, t)!,
      syntaxVariable: Color.lerp(syntaxVariable, other.syntaxVariable, t)!,
      syntaxString: Color.lerp(syntaxString, other.syntaxString, t)!,
      syntaxNumber: Color.lerp(syntaxNumber, other.syntaxNumber, t)!,
      syntaxType: Color.lerp(syntaxType, other.syntaxType, t)!,
      syntaxOperator: Color.lerp(syntaxOperator, other.syntaxOperator, t)!,
      syntaxPunctuation: Color.lerp(
        syntaxPunctuation,
        other.syntaxPunctuation,
        t,
      )!,
      syntaxProperty: Color.lerp(syntaxProperty, other.syntaxProperty, t)!,
      syntaxConstant: Color.lerp(syntaxConstant, other.syntaxConstant, t)!,
    );
  }
}

OpenCodeThemePalette? openCodeThemePaletteFor(OpenCodeThemePreset? preset) {
  if (preset == null) {
    return null;
  }
  final definition = _definitionFor(preset);
  final seedColor = Color.lerp(
    definition.light.palette.primary,
    definition.dark.palette.primary,
    0.5,
  )!;
  return OpenCodeThemePalette(
    id: definition.id,
    label: definition.name,
    seedColor: seedColor,
  );
}

List<OpenCodeThemePreset> openCodeThemePresetOptions() {
  return const <OpenCodeThemePreset>[
    OpenCodeThemePreset.oc2,
    OpenCodeThemePreset.amoled,
    OpenCodeThemePreset.aura,
    OpenCodeThemePreset.ayu,
    OpenCodeThemePreset.carbonfox,
    OpenCodeThemePreset.catppuccin,
    OpenCodeThemePreset.catppuccinFrappe,
    OpenCodeThemePreset.catppuccinMacchiato,
    OpenCodeThemePreset.cobalt2,
    OpenCodeThemePreset.cursor,
    OpenCodeThemePreset.dracula,
    OpenCodeThemePreset.everforest,
    OpenCodeThemePreset.flexoki,
    OpenCodeThemePreset.github,
    OpenCodeThemePreset.gruvbox,
    OpenCodeThemePreset.kanagawa,
    OpenCodeThemePreset.lucentOrng,
    OpenCodeThemePreset.material,
    OpenCodeThemePreset.matrix,
    OpenCodeThemePreset.mercury,
    OpenCodeThemePreset.monokai,
    OpenCodeThemePreset.nightowl,
    OpenCodeThemePreset.nord,
    OpenCodeThemePreset.oneDark,
    OpenCodeThemePreset.onedarkPro,
    OpenCodeThemePreset.opencode,
    OpenCodeThemePreset.orng,
    OpenCodeThemePreset.osakaJade,
    OpenCodeThemePreset.palenight,
    OpenCodeThemePreset.rosepine,
    OpenCodeThemePreset.shadesofpurple,
    OpenCodeThemePreset.solarized,
    OpenCodeThemePreset.synthwave84,
    OpenCodeThemePreset.tokyonight,
    OpenCodeThemePreset.vercel,
    OpenCodeThemePreset.vesper,
    OpenCodeThemePreset.zenburn,
  ];
}

String openCodeThemePresetLabel(OpenCodeThemePreset preset) {
  return _definitionFor(preset).name;
}

ColorScheme? openCodeLightSchemeFor(OpenCodeThemePreset? preset) {
  return _openCodeColorSchemeFor(preset, Brightness.light);
}

ColorScheme? openCodeDarkSchemeFor(OpenCodeThemePreset? preset) {
  return _openCodeColorSchemeFor(preset, Brightness.dark);
}

OpenCodeThemeTokens? openCodeThemeTokensFor(
  OpenCodeThemePreset? preset,
  Brightness brightness,
) {
  if (preset == null) {
    return null;
  }
  final definition = _definitionFor(preset);
  final variant = brightness == Brightness.dark
      ? definition.dark
      : definition.light;
  final palette = variant.palette;
  final accent = palette.accent ?? palette.info;
  final interactive = palette.interactive ?? palette.primary;
  final background = palette.neutral;
  final textBase = _overrideOr(variant, 'markdown-text', palette.ink);
  final textMuted = _overrideOr(
    variant,
    'text-weak',
    _mix(textBase, background, brightness == Brightness.dark ? 0.38 : 0.48),
  );
  final surfaceBase = _overlay(
    background,
    palette.ink,
    brightness == Brightness.dark ? 0.045 : 0.02,
  );
  final surfaceRaised = _overlay(
    surfaceBase,
    interactive,
    brightness == Brightness.dark ? 0.08 : 0.045,
  );
  final codeBlockBackground = _overlay(
    surfaceBase,
    interactive,
    brightness == Brightness.dark ? 0.14 : 0.08,
  );
  final inlineCodeBackground = _overlay(
    surfaceBase,
    accent,
    brightness == Brightness.dark ? 0.1 : 0.06,
  );
  final border = _mix(
    background,
    palette.ink,
    brightness == Brightness.dark ? 0.2 : 0.14,
  );
  final syntaxComment = _overrideOr(variant, 'syntax-comment', textMuted);
  final syntaxKeyword = _overrideOr(variant, 'syntax-keyword', accent);
  final syntaxPrimitive = _overrideOr(variant, 'syntax-primitive', interactive);
  final syntaxProperty = _overrideOr(variant, 'syntax-property', palette.info);
  final syntaxConstant = _overrideOr(variant, 'syntax-constant', accent);
  final syntaxType = _overrideOr(variant, 'syntax-type', palette.warning);

  return OpenCodeThemeTokens(
    themeId: definition.id,
    themeLabel: definition.name,
    surfaceBase: surfaceBase,
    surfaceRaised: surfaceRaised,
    inlineCodeBackground: inlineCodeBackground,
    codeBlockBackground: codeBlockBackground,
    border: border,
    textBase: textBase,
    textMuted: textMuted,
    markdownHeading: _overrideOr(variant, 'markdown-heading', palette.primary),
    markdownLink: _overrideOr(variant, 'markdown-link', interactive),
    markdownLinkText: _overrideOr(variant, 'markdown-link-text', palette.info),
    markdownInlineCode: _overrideOr(variant, 'markdown-code', palette.success),
    markdownCodeBlock: _overrideOr(variant, 'markdown-code-block', textBase),
    markdownBlockQuote: _overrideOr(
      variant,
      'markdown-block-quote',
      palette.warning,
    ),
    markdownEmphasis: _overrideOr(variant, 'markdown-emph', palette.warning),
    markdownStrong: _overrideOr(variant, 'markdown-strong', accent),
    markdownHorizontalRule: _overrideOr(
      variant,
      'markdown-horizontal-rule',
      border,
    ),
    markdownListItem: _overrideOr(variant, 'markdown-list-item', interactive),
    markdownListEnumeration: _overrideOr(
      variant,
      'markdown-list-enumeration',
      palette.info,
    ),
    markdownImage: _overrideOr(variant, 'markdown-image', interactive),
    markdownImageText: _overrideOr(
      variant,
      'markdown-image-text',
      palette.info,
    ),
    syntaxComment: syntaxComment,
    syntaxKeyword: syntaxKeyword,
    syntaxFunction: syntaxProperty,
    syntaxVariable: _overrideOr(variant, 'syntax-variable', textBase),
    syntaxString: _overrideOr(variant, 'syntax-string', palette.success),
    syntaxNumber: syntaxPrimitive,
    syntaxType: syntaxType,
    syntaxOperator: _overrideOr(variant, 'syntax-operator', textMuted),
    syntaxPunctuation: _overrideOr(variant, 'syntax-punctuation', textBase),
    syntaxProperty: syntaxProperty,
    syntaxConstant: syntaxConstant,
  );
}

OpenCodeThemeTokens classicThemeTokensFrom(ColorScheme colorScheme) {
  final surfaceBase = colorScheme.surface;
  final surfaceRaised = colorScheme.surfaceContainerLow;
  final codeBlockBackground = colorScheme.surfaceContainerHighest;
  final inlineCodeBackground = _overlay(
    codeBlockBackground,
    colorScheme.primary,
    colorScheme.brightness == Brightness.dark ? 0.1 : 0.05,
  );
  final textBase = colorScheme.onSurface;
  final textMuted = colorScheme.onSurfaceVariant;
  return OpenCodeThemeTokens(
    themeId: 'codewalk-classic',
    themeLabel: 'CodeWalk Classic',
    surfaceBase: surfaceBase,
    surfaceRaised: surfaceRaised,
    inlineCodeBackground: inlineCodeBackground,
    codeBlockBackground: codeBlockBackground,
    border: colorScheme.outlineVariant,
    textBase: textBase,
    textMuted: textMuted,
    markdownHeading: colorScheme.primary,
    markdownLink: colorScheme.primary,
    markdownLinkText: colorScheme.tertiary,
    markdownInlineCode: colorScheme.secondary,
    markdownCodeBlock: textBase,
    markdownBlockQuote: colorScheme.secondary,
    markdownEmphasis: colorScheme.secondary,
    markdownStrong: colorScheme.primary,
    markdownHorizontalRule: colorScheme.outlineVariant,
    markdownListItem: colorScheme.primary,
    markdownListEnumeration: colorScheme.tertiary,
    markdownImage: colorScheme.primary,
    markdownImageText: colorScheme.tertiary,
    syntaxComment: textMuted,
    syntaxKeyword: colorScheme.secondary,
    syntaxFunction: colorScheme.primary,
    syntaxVariable: textBase,
    syntaxString: colorScheme.tertiary,
    syntaxNumber: colorScheme.primary,
    syntaxType: colorScheme.secondary,
    syntaxOperator: textMuted,
    syntaxPunctuation: textBase,
    syntaxProperty: colorScheme.tertiary,
    syntaxConstant: colorScheme.primary,
  );
}

OpenCodeThemeDefinitionData _definitionFor(OpenCodeThemePreset preset) {
  final definition = openCodeWebThemeDefinitionForId(
    openCodeThemePresetKey(preset),
  );
  if (definition != null) {
    return definition;
  }
  return openCodeWebThemeDefinitionForId(
    openCodeThemePresetKey(kDefaultOpenCodeThemePreset),
  )!;
}

ColorScheme? _openCodeColorSchemeFor(
  OpenCodeThemePreset? preset,
  Brightness brightness,
) {
  final tokens = openCodeThemeTokensFor(preset, brightness);
  if (tokens == null) {
    return null;
  }
  final definition = _definitionFor(preset!);
  final variant = brightness == Brightness.dark
      ? definition.dark
      : definition.light;
  final palette = variant.palette;
  final accent = palette.accent ?? palette.info;
  final interactive = palette.interactive ?? palette.primary;
  final base = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  );
  final primaryContainer = _overlay(
    tokens.surfaceBase,
    palette.primary,
    brightness == Brightness.dark ? 0.26 : 0.22,
  );
  final secondaryContainer = _overlay(
    tokens.surfaceBase,
    accent,
    brightness == Brightness.dark ? 0.22 : 0.18,
  );
  final tertiaryContainer = _overlay(
    tokens.surfaceBase,
    palette.info,
    brightness == Brightness.dark ? 0.2 : 0.16,
  );
  final inverseSurface = _mix(tokens.surfaceBase, tokens.textBase, 0.9);
  return base.copyWith(
    primary: palette.primary,
    secondary: accent,
    tertiary: palette.info,
    error: palette.error,
    surface: tokens.surfaceBase,
    surfaceDim: _mix(tokens.surfaceBase, Colors.black, 0.08),
    surfaceBright: _mix(tokens.surfaceBase, Colors.white, 0.06),
    surfaceContainerLowest: variant.palette.neutral,
    surfaceContainerLow: _overlay(tokens.surfaceBase, palette.ink, 0.03),
    surfaceContainer: tokens.surfaceRaised,
    surfaceContainerHigh: _overlay(tokens.surfaceRaised, interactive, 0.05),
    surfaceContainerHighest: tokens.codeBlockBackground,
    onSurface: tokens.textBase,
    onSurfaceVariant: tokens.textMuted,
    outline: tokens.border,
    outlineVariant: _mix(tokens.surfaceBase, palette.ink, 0.08),
    primaryContainer: primaryContainer,
    onPrimaryContainer: _bestOn(primaryContainer),
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: _bestOn(secondaryContainer),
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: _bestOn(tertiaryContainer),
    inverseSurface: inverseSurface,
    onInverseSurface: _bestOn(inverseSurface),
    surfaceTint: palette.primary,
  );
}

Color _overrideOr(
  OpenCodeThemeVariantData variant,
  String key,
  Color fallback,
) {
  return variant.overrides[key] ?? fallback;
}

Color _mix(Color a, Color b, double t) {
  return Color.lerp(a, b, t)!;
}

Color _overlay(Color base, Color overlay, double opacity) {
  return Color.alphaBlend(overlay.withValues(alpha: opacity), base);
}

Color _bestOn(Color background) {
  return background.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}
