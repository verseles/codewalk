import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';

/// Technical comment translated to English.
class AppTheme {
  // Technical comment translated to English.
  static const Color primaryColor = Color(0xFF6366F1); // Indigo 500
  static const Color primaryVariant = Color(0xFF4F46E5); // Indigo 600
  static const Color secondaryColor = Color(0xFF06B6D4); // Cyan 500
  static const Color secondaryVariant = Color(0xFF0891B2); // Cyan 600

  // Technical comment translated to English.
  static const Color accentColor = Color(0xFF8B5CF6); // Violet 500
  static const Color accentVariant = Color(0xFF7C3AED); // Violet 600

  // Technical comment translated to English.
  static const Color surfaceDark = Color(
    0xFF0F0F23,
  ); // Technical comment translated to English.
  static const Color surfaceVariantDark = Color(
    0xFF1A1A2E,
  ); // Technical comment translated to English.
  static const Color backgroundDark = Color(
    0xFF0A0A0F,
  ); // Technical comment translated to English.
  static const Color cardDark = Color(
    0xFF16213E,
  ); // Technical comment translated to English.

  // Technical comment translated to English.
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color backgroundLight = Color(0xFFFFFFFF);

  // Technical comment translated to English.
  static const Color errorColor = Color(0xFFEF4444); // Red 500
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color infoColor = Color(0xFF3B82F6); // Blue 500

  // Technical comment translated to English.
  static const Color textPrimaryDark = Color(0xFFE2E8F0); // Slate 200
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textTertiaryDark = Color(0xFF64748B); // Slate 500

  // Technical comment translated to English.
  static const Color borderDark = Color(0xFF334155); // Slate 700
  static const Color dividerDark = Color(0xFF1E293B); // Slate 800

  /// Technical comment translated to English.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceLight,
        error: errorColor,
        tertiary: accentColor,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: AppConstants.smallPadding,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppConstants.defaultPadding),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
      ),
    );
  }

  /// Technical comment translated to English.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Technical comment translated to English.
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryVariant,
        onPrimaryContainer: textPrimaryDark,

        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryVariant,
        onSecondaryContainer: textPrimaryDark,

        tertiary: accentColor,
        onTertiary: Colors.white,
        tertiaryContainer: accentVariant,
        onTertiaryContainer: textPrimaryDark,

        error: errorColor,
        onError: Colors.white,
        errorContainer: Color(0xFF7F1D1D),
        onErrorContainer: Color(0xFFFECDD3),

        background: backgroundDark,
        onBackground: textPrimaryDark,

        surface: surfaceDark,
        onSurface: textPrimaryDark,
        surfaceVariant: surfaceVariantDark,
        onSurfaceVariant: textSecondaryDark,

        outline: borderDark,
        outlineVariant: dividerDark,

        inverseSurface: textPrimaryDark,
        onInverseSurface: backgroundDark,
        inversePrimary: primaryVariant,
      ),

      // Technical comment translated to English.
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryDark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(color: textPrimaryDark),
      ),

      // Technical comment translated to English.
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(color: borderDark.withOpacity(0.2), width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.smallPadding,
          vertical: AppConstants.smallPadding / 2,
        ),
      ),

      // Technical comment translated to English.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding * 1.5,
            vertical: AppConstants.defaultPadding,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Technical comment translated to English.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: AppConstants.smallPadding,
          ),
        ),
      ),

      // Technical comment translated to English.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantDark,
        contentPadding: const EdgeInsets.all(AppConstants.defaultPadding),

        // Technical comment translated to English.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: borderDark.withOpacity(0.3)),
        ),

        // Technical comment translated to English.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide(color: borderDark.withOpacity(0.3)),
        ),

        // Technical comment translated to English.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),

        // Technical comment translated to English.
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),

        // Technical comment translated to English.
        hintStyle: const TextStyle(color: textTertiaryDark),
        labelStyle: const TextStyle(color: textSecondaryDark),
      ),

      // Technical comment translated to English.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: const TextStyle(color: textPrimaryDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        elevation: 8,
      ),

      // Technical comment translated to English.
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius * 1.5),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondaryDark,
          fontSize: 16,
        ),
      ),

      // Technical comment translated to English.
      drawerTheme: DrawerThemeData(
        backgroundColor: surfaceDark,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppConstants.borderRadius),
            bottomRight: Radius.circular(AppConstants.borderRadius),
          ),
        ),
      ),

      // Technical comment translated to English.
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: textTertiaryDark,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Technical comment translated to English.
      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
        space: 1,
      ),

      // Technical comment translated to English.
      listTileTheme: const ListTileThemeData(
        textColor: textPrimaryDark,
        iconColor: textSecondaryDark,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppConstants.defaultPadding,
          vertical: AppConstants.smallPadding,
        ),
      ),

      // Technical comment translated to English.
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantDark,
        selectedColor: primaryColor.withOpacity(0.2),
        disabledColor: surfaceVariantDark.withOpacity(0.5),
        labelStyle: const TextStyle(color: textPrimaryDark),
        secondaryLabelStyle: const TextStyle(color: textSecondaryDark),
        brightness: Brightness.dark,
        elevation: 0,
        pressElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
      ),

      // Technical comment translated to English.
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimaryDark,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          color: textPrimaryDark,
          fontSize: 45,
          fontWeight: FontWeight.w400,
        ),
        displaySmall: TextStyle(
          color: textPrimaryDark,
          fontSize: 36,
          fontWeight: FontWeight.w400,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryDark,
          fontSize: 32,
          fontWeight: FontWeight.w400,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryDark,
          fontSize: 28,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryDark,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: TextStyle(
          color: textPrimaryDark,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleMedium: TextStyle(
          color: textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          color: textPrimaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          color: textPrimaryDark,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: textPrimaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          color: textSecondaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          color: textPrimaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.25,
        ),
        labelMedium: TextStyle(
          color: textSecondaryDark,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
        labelSmall: TextStyle(
          color: textTertiaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// Technical comment translated to English.
  static BoxDecoration createGradientDecoration({
    List<Color>? colors,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
    double borderRadius = AppConstants.borderRadius,
    Color? borderColor,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors:
            colors ??
            [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.1)],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : null,
    );
  }

  /// Technical comment translated to English.
  static List<BoxShadow> createCardShadow({
    Color? color,
    double blurRadius = 8,
    double spreadRadius = 0,
    Offset offset = const Offset(0, 2),
  }) {
    return [
      BoxShadow(
        color: (color ?? Colors.black).withOpacity(0.1),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
    ];
  }
}
