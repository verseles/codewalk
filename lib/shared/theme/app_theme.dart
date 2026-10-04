import 'package:flutter/material.dart';

import '../layout/window_size_class.dart';
import 'app_shapes.dart';
import 'app_visual_style_tokens.dart';
import 'theme_preferences.dart';

class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF3A6EA5);
  static const double _desktopSnackBarMaxWidth = 420;
  static const double _desktopSnackBarSideInset = 24;
  static const double _mobileSnackBarHorizontalInset = 16;

  static ThemeData lightFrom(
    ColorScheme colorScheme, {
    AppDensity appDensity = AppDensity.normal,
    VisualStyle visualStyle = VisualStyle.classic,
    Iterable<ThemeExtension<dynamic>> themeExtensions =
        const <ThemeExtension<dynamic>>[],
  }) {
    return _buildTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      appDensity: appDensity,
      visualStyle: visualStyle,
      themeExtensions: themeExtensions,
    );
  }

  static ThemeData darkFrom(
    ColorScheme colorScheme, {
    AppDensity appDensity = AppDensity.normal,
    VisualStyle visualStyle = VisualStyle.classic,
    Iterable<ThemeExtension<dynamic>> themeExtensions =
        const <ThemeExtension<dynamic>>[],
  }) {
    return _buildTheme(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      appDensity: appDensity,
      visualStyle: visualStyle,
      themeExtensions: themeExtensions,
    );
  }

  static VisualDensity visualDensityFor(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const VisualDensity(
        horizontal: -2,
        vertical: -2,
      ),
      AppDensity.dense => VisualDensity.compact,
      AppDensity.normal => VisualDensity.standard,
      AppDensity.spacious => VisualDensity.comfortable,
      AppDensity.extraSpacious => const VisualDensity(
        horizontal: 2,
        vertical: 2,
      ),
    };
  }

  static bool usesCompactLayout(AppDensity density) {
    return density == AppDensity.extraDense || density == AppDensity.dense;
  }

  static ThemeData withResponsiveSnackBars(
    ThemeData theme,
    MediaQueryData mediaQuery, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final viewportWidth = mediaQuery.size.width;
    final wideLayout = WindowSizeClass.fromWidth(
      viewportWidth,
    ).isAtLeastExpanded;
    final desktopLooseInset = wideLayout
        ? (viewportWidth - _desktopSnackBarMaxWidth - _desktopSnackBarSideInset)
              .clamp(_desktopSnackBarSideInset, viewportWidth)
              .toDouble()
        : _mobileSnackBarHorizontalInset;
    final snackBarInset = wideLayout
        ? EdgeInsets.fromLTRB(
            textDirection == TextDirection.rtl
                ? _desktopSnackBarSideInset
                : desktopLooseInset,
            8,
            textDirection == TextDirection.rtl
                ? desktopLooseInset
                : _desktopSnackBarSideInset,
            24,
          )
        : const EdgeInsets.fromLTRB(
            _mobileSnackBarHorizontalInset,
            8,
            _mobileSnackBarHorizontalInset,
            16,
          );
    final visualTokens = theme.visualStyleTokens;
    final snackBarBorderRadius = visualTokens.isRefined
        ? visualTokens.controlRadius
        : AppShapes.borderLarge;

    return theme.copyWith(
      snackBarTheme: theme.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        insetPadding: snackBarInset,
        showCloseIcon: wideLayout,
        shape: RoundedRectangleBorder(borderRadius: snackBarBorderRadius),
      ),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required AppDensity appDensity,
    required VisualStyle visualStyle,
    required Iterable<ThemeExtension<dynamic>> themeExtensions,
  }) {
    final refined = visualStyle == VisualStyle.refined;
    final visualTokens = refined
        ? AppVisualStyleTokens.refined(colorScheme, brightness)
        : AppVisualStyleTokens.classic(colorScheme, brightness);
    final resolvedThemeExtensions = List<ThemeExtension<dynamic>>.of(
      themeExtensions,
    )..add(visualTokens);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      visualDensity: visualDensityFor(appDensity),
      extensions: resolvedThemeExtensions,
    );

    final textTheme = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: colorScheme,
    ).black;

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: refined
            ? Colors.transparent
            : colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: visualTokens.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: refined
              ? visualTokens.cardRadius
              : BorderRadius.circular(AppShapes.extraLarge),
          side: refined
              ? BorderSide(
                  color: visualTokens.separator,
                  width: visualTokens.enabledBorderWidth,
                )
              : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: visualTokens.separator,
        thickness: visualTokens.dividerThickness,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: refined
            ? visualTokens.mutedControlSurface
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: visualTokens.controlRadius,
          borderSide: BorderSide(
            color: visualTokens.separator,
            width: visualTokens.enabledBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: visualTokens.controlRadius,
          borderSide: BorderSide(
            color: visualTokens.separator,
            width: visualTokens.enabledBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: visualTokens.controlRadius,
          borderSide: BorderSide(
            color: visualTokens.focusBorder,
            width: visualTokens.focusedBorderWidth,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: refined
              ? visualTokens.controlRadius
              : AppShapes.borderLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: refined
            ? colorScheme.surface
            : colorScheme.surfaceContainer,
        indicatorColor: visualTokens.selectedSurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: refined
            ? visualTokens.panelSurface
            : colorScheme.surfaceContainerLow,
        selectedIconTheme: IconThemeData(
          color: colorScheme.onSecondaryContainer,
        ),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: visualTokens.selectedSurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: refined ? 0 : null,
        focusElevation: refined ? 0 : null,
        hoverElevation: refined ? 0 : null,
        highlightElevation: refined ? 0 : null,
        shape: refined
            ? RoundedRectangleBorder(borderRadius: AppShapes.borderFull)
            : null,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        showCloseIcon: false,
        closeIconColor: colorScheme.onInverseSurface,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: refined
              ? visualTokens.controlRadius
              : AppShapes.borderSmall,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: refined
                ? visualTokens.controlRadius
                : AppShapes.borderLarge,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: refined
                ? visualTokens.controlRadius
                : AppShapes.borderLarge,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: refined
                ? visualTokens.controlRadius
                : AppShapes.borderLarge,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: refined
                ? visualTokens.controlRadius
                : BorderRadius.circular(AppShapes.medium),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: refined
                ? visualTokens.dialogRadius.topLeft
                : const Radius.circular(AppShapes.extraLarge),
          ),
        ),
        showDragHandle: true,
        surfaceTintColor: refined ? Colors.transparent : null,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: refined
              ? visualTokens.dialogRadius
              : BorderRadius.circular(AppShapes.extraLarge),
        ),
        surfaceTintColor: refined ? Colors.transparent : null,
      ),
    );
  }
}

/// Density-aware spacing values for chrome and composer surfaces.
///
/// Every method returns the value that matches the current hardcoded default
/// when [AppDensity.normal] is passed — zero regression at the default tier.
class AppDensitySpacing {
  AppDensitySpacing._();

  // --- Horizontal padding (composer rows, chrome edges) ---

  /// Horizontal padding for composer chip/input rows.
  /// normal=12, dense/extraDense=8, spacious=16, extraSpacious=20
  static double horizontalPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 8,
      AppDensity.dense => 8,
      AppDensity.normal => 12,
      AppDensity.spacious => 16,
      AppDensity.extraSpacious => 20,
    };
  }

  // --- Vertical padding (composer rows, chrome items) ---

  /// Vertical padding for composer chip rows above the input.
  /// normal=4, dense/extraDense=2, spacious=6, extraSpacious=8
  static double chipRowVerticalPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 2,
      AppDensity.dense => 2,
      AppDensity.normal => 4,
      AppDensity.spacious => 6,
      AppDensity.extraSpacious => 8,
    };
  }

  /// Vertical padding for the main input row.
  /// normal=4, dense/extraDense=2, spacious=6, extraSpacious=8
  static double inputRowVerticalPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 2,
      AppDensity.dense => 2,
      AppDensity.normal => 4,
      AppDensity.spacious => 6,
      AppDensity.extraSpacious => 8,
    };
  }

  // --- Gaps between elements ---

  /// Gap between controls in a row (e.g. attach button to input bubble,
  /// input bubble to send button, popup menu icon to label).
  /// normal=8, dense/extraDense=4, spacious=12, extraSpacious=16
  static double itemGap(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 4,
      AppDensity.dense => 4,
      AppDensity.normal => 8,
      AppDensity.spacious => 12,
      AppDensity.extraSpacious => 16,
    };
  }

  /// Small gap for tight groupings (e.g. trailing edge of actions bar,
  /// chip icon-to-label spacing).
  /// normal=2, dense/extraDense=0, spacious=4, extraSpacious=6
  static double smallGap(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 0,
      AppDensity.dense => 0,
      AppDensity.normal => 2,
      AppDensity.spacious => 4,
      AppDensity.extraSpacious => 6,
    };
  }

  /// Medium gap for wider groupings (e.g. spinner-to-text in overlay,
  /// section-level separations).
  /// normal=12, dense/extraDense=8, spacious=16, extraSpacious=20
  static double mediumGap(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 8,
      AppDensity.dense => 8,
      AppDensity.normal => 12,
      AppDensity.spacious => 16,
      AppDensity.extraSpacious => 20,
    };
  }

  // --- Content padding ---

  /// TextField contentPadding inside the composer input bubble.
  /// normal=(16,7,8,7), scaled proportionally per tier.
  static EdgeInsets textFieldContentPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.fromLTRB(12, 5, 6, 5),
      AppDensity.dense => const EdgeInsets.fromLTRB(14, 6, 7, 6),
      AppDensity.normal => const EdgeInsets.fromLTRB(16, 7, 8, 7),
      AppDensity.spacious => const EdgeInsets.fromLTRB(18, 9, 10, 9),
      AppDensity.extraSpacious => const EdgeInsets.fromLTRB(20, 11, 12, 11),
    };
  }

  /// ListTile contentPadding for selector tiles in chrome dialogs.
  /// normal=8, dense/extraDense=4, spacious=12, extraSpacious=16
  static EdgeInsets listTileContentPadding(AppDensity density) {
    return EdgeInsets.symmetric(horizontal: listTileHorizontalPadding(density));
  }

  static double listTileHorizontalPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 4,
      AppDensity.dense => 4,
      AppDensity.normal => 8,
      AppDensity.spacious => 12,
      AppDensity.extraSpacious => 16,
    };
  }

  // --- Chrome-specific ---

  /// AppBar titleSpacing (desktop only; mobile stays 0).
  /// normal=4, dense/extraDense=0, spacious=8, extraSpacious=12
  static double appBarTitleSpacing(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 0,
      AppDensity.dense => 0,
      AppDensity.normal => 4,
      AppDensity.spacious => 8,
      AppDensity.extraSpacious => 12,
    };
  }

  /// Padding for the sync status chip in the AppBar actions.
  /// normal=6, dense/extraDense=2, spacious=10, extraSpacious=14
  static double syncChipRightPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 2,
      AppDensity.dense => 2,
      AppDensity.normal => 6,
      AppDensity.spacious => 10,
      AppDensity.extraSpacious => 14,
    };
  }

  /// Padding for the timeline search result count label.
  /// normal=4, dense/extraDense=2, spacious=8, extraSpacious=12
  static EdgeInsets searchResultLabelPadding(AppDensity density) {
    return EdgeInsets.symmetric(
      horizontal: searchResultLabelHorizontal(density),
    );
  }

  static double searchResultLabelHorizontal(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 2,
      AppDensity.dense => 2,
      AppDensity.normal => 4,
      AppDensity.spacious => 8,
      AppDensity.extraSpacious => 12,
    };
  }

  /// Section header padding in chrome selector dialogs.
  /// normal=(8,6,8,6), scaled per tier.
  static EdgeInsets sectionHeaderPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.fromLTRB(4, 4, 4, 4),
      AppDensity.dense => const EdgeInsets.fromLTRB(6, 5, 6, 5),
      AppDensity.normal => const EdgeInsets.fromLTRB(8, 6, 8, 6),
      AppDensity.spacious => const EdgeInsets.fromLTRB(12, 8, 12, 8),
      AppDensity.extraSpacious => const EdgeInsets.fromLTRB(16, 10, 16, 10),
    };
  }

  /// Header chip padding (e.g. status chips in the AppBar).
  /// normal=(8,6), scaled per tier.
  static EdgeInsets headerChipPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 4,
      ),
      AppDensity.dense => const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 5,
      ),
      AppDensity.normal => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      AppDensity.spacious => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      AppDensity.extraSpacious => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
    };
  }

  /// Project scope loading overlay card padding.
  /// normal=(18,14), scaled per tier.
  static EdgeInsets overlayCardPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      AppDensity.dense => const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      AppDensity.normal => const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      AppDensity.spacious => const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),
      AppDensity.extraSpacious => const EdgeInsets.symmetric(
        horizontal: 26,
        vertical: 22,
      ),
    };
  }

  // --- Composer-specific ---

  /// Block reason inner padding (the colored banner inside the composer).
  /// normal=(12,10), scaled per tier.
  static EdgeInsets blockReasonInnerPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      AppDensity.dense => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      AppDensity.normal => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      AppDensity.spacious => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      AppDensity.extraSpacious => const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
    };
  }

  /// Padding for the composer row that hosts permission, agent, model, and
  /// variant controls. The normal tier matches the pre-density layout.
  static EdgeInsets composerModelControlsPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.fromLTRB(6, 0, 6, 1),
      AppDensity.dense => const EdgeInsets.fromLTRB(8, 0, 8, 2),
      AppDensity.normal => const EdgeInsets.fromLTRB(8, 0, 8, 2),
      AppDensity.spacious => const EdgeInsets.fromLTRB(12, 0, 12, 4),
      AppDensity.extraSpacious => const EdgeInsets.fromLTRB(16, 0, 16, 6),
    };
  }

  /// Horizontal gap between controls in the composer model-controls row.
  static double composerModelControlGap(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => 4,
      AppDensity.dense => 6,
      AppDensity.normal => 8,
      AppDensity.spacious => 10,
      AppDensity.extraSpacious => 12,
    };
  }

  /// Inner padding for compact chips in the composer model-controls row.
  static EdgeInsets composerModelControlChipPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 0,
      ),
      AppDensity.dense => const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 0,
      ),
      AppDensity.normal => const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 0,
      ),
      AppDensity.spacious => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      AppDensity.extraSpacious => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
    };
  }

  /// IconButton padding for the composer permission control.
  static EdgeInsets composerModelControlButtonPadding(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const EdgeInsets.all(4),
      AppDensity.dense => const EdgeInsets.all(6),
      AppDensity.normal => const EdgeInsets.all(8),
      AppDensity.spacious => const EdgeInsets.all(10),
      AppDensity.extraSpacious => const EdgeInsets.all(12),
    };
  }

  /// IconButton minimum size for the composer permission control.
  /// Compact tiers keep the previous 40dp floor because this safety-sensitive
  /// control uses shrinkWrap to avoid composer overflow.
  static Size composerModelControlButtonSize(AppDensity density) {
    return switch (density) {
      AppDensity.extraDense => const Size.square(40),
      AppDensity.dense => const Size.square(40),
      AppDensity.normal => const Size.square(40),
      AppDensity.spacious => const Size.square(44),
      AppDensity.extraSpacious => const Size.square(48),
    };
  }

  // --- Convenience builders ---

  /// Composer chip row padding (horizontal + top/bottom).
  static EdgeInsets composerChipRowPadding(AppDensity density) {
    return EdgeInsets.fromLTRB(
      horizontalPadding(density),
      chipRowVerticalPadding(density),
      horizontalPadding(density),
      0,
    );
  }

  /// Composer popover row padding (horizontal only, no vertical).
  static EdgeInsets composerPopoverRowPadding(AppDensity density) {
    return EdgeInsets.fromLTRB(
      horizontalPadding(density),
      0,
      horizontalPadding(density),
      0,
    );
  }

  /// Main composer input row padding.
  static EdgeInsets composerInputRowPadding(AppDensity density) {
    return EdgeInsets.fromLTRB(
      horizontalPadding(density),
      inputRowVerticalPadding(density),
      horizontalPadding(density),
      inputRowVerticalPadding(density),
    );
  }
}
