import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/i18n/app_locales.dart';
import 'core/i18n/l10n_bridge.dart';
import 'core/logging/android_process_diagnostics.dart';
import 'core/logging/app_logger.dart';
import 'domain/entities/experience_settings.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/pages/app_shell_page.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/project_icon_provider.dart';
import 'presentation/providers/project_provider.dart';
import 'presentation/providers/quota_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/services/android_background_alert_worker.dart';
import 'presentation/services/desktop_window_chrome_service.dart';
import 'presentation/services/session_attention/session_overlay_entrypoint.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/opencode_theme_presets.dart';
import 'presentation/widgets/desktop_window_title_bar.dart';
import 'presentation/widgets/direct_provider.dart';

// Keeps the native Android service entrypoint reachable in AOT builds.
@pragma('vm:entry-point')
void _sessionOverlayAndroidEntrypointAnchor() {
  sessionOverlayAndroidMain();
}

/// Converts a material_ui [ColorScheme] (reported by dynamic_color 2.x)
/// into Flutter's [ColorScheme]. Both carry the same Material 3 roles.
ColorScheme _muiSchemeToFlutter(mui.ColorScheme scheme) {
  return ColorScheme(
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
}

Future<void> main(List<String> args) async {
  await runZonedGuarded<Future<void>>(() async {
    assert(() {
      BindingBase.debugZoneErrorsAreFatal = true;
      return true;
    }());
    WidgetsFlutterBinding.ensureInitialized();
    AppLogger.installGlobalHandlers();
    unawaited(AndroidProcessDiagnostics.recordStartup());
    if (_isAndroidRuntime()) {
      _configureAndroidMemoryBounds();
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    if (_isDesktopRuntime()) {
      await windowManager.ensureInitialized();
      await DesktopWindowChromeService.applyPersisted();
    }

    if (_isAndroidRuntime()) {
      await AndroidBackgroundAlertWorker.syncRegistrationFromPersistedSettings();
    }

    // Initialize dependency injection
    await di.init();

    runApp(const MyApp());
  }, AppLogger.recordZoneError);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = di.sl<AppProvider>();
            unawaited(provider.initialize());
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => di.sl<ProjectProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ProjectIconProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ChatProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<QuotaProvider>()),
        ChangeNotifierProvider(create: (_) => DesktopWindowChromeController()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = di.sl<SettingsProvider>();
            unawaited(provider.initialize());
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = di.sl<LocaleProvider>();
            unawaited(provider.initialize());
            return provider;
          },
        ),
      ],
      child: DynamicColorBuilder(
        builder: (mui.ColorScheme? lightDynamicMui, mui.ColorScheme? darkDynamicMui) {
          // dynamic_color 2.x reports schemes in material_ui's ColorScheme
          // type (a different class from Flutter's). Convert once at the
          // boundary so the theme pipeline keeps using Flutter's type.
          final lightDynamic = lightDynamicMui == null
              ? null
              : _muiSchemeToFlutter(lightDynamicMui);
          final darkDynamic = darkDynamicMui == null
              ? null
              : _muiSchemeToFlutter(darkDynamicMui);
          return DirectSelector<SettingsProvider, _AppSettingsRecord>(
            select: (provider) => (
              appDensity: provider.appDensity,
              useDynamicColor: provider.useDynamicColor,
              useAmoledDark: provider.useAmoledDark,
              customColorSeed: provider.customColorSeed,
              contrastLevel: provider.contrastLevel,
              themePreset: provider.themePreset,
              visualStyle: provider.visualStyle,
              themeMode: provider.themeMode,
              systemFontScale: provider.systemFontScale,
            ),
            builder: (context, appSettings, _) {
              return Consumer<LocaleProvider>(
                builder: (context, localeProvider, _) {
                  final settingsProvider = context.read<SettingsProvider>();
                  final appDensity = appSettings.appDensity;
                  final useDynamic = appSettings.useDynamicColor;
                  final useAmoledDark = appSettings.useAmoledDark;
                  final customSeed = appSettings.customColorSeed;
                  final contrastLevel = appSettings.contrastLevel;
                  final themePreset = appSettings.themePreset;
                  final visualStyle = appSettings.visualStyle;

                  // Sync actual dynamic color availability to provider so
                  // the settings UI can reflect reality (not just platform
                  // heuristic).
                  // Consider dynamic color available when the platform provides
                  // at least one scheme (light or dark).
                  // Read outside the Selector record: availability must not
                  // rebuild the whole MaterialApp on its own flap (the
                  // appearance section subscribes to it separately).
                  // Non-listening read: only that section rebuilds on
                  // availability-only changes.
                  final hasDynamic =
                      lightDynamic != null || darkDynamic != null;
                  final dynamicAvailable =
                      settingsProvider.dynamicColorAvailable;
                  if (dynamicAvailable != hasDynamic) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      settingsProvider.updateDynamicColorAvailability(
                        available: hasDynamic,
                      );
                    });
                  }

                  // Resolve seed color: custom pick or default brand
                  final seedColor = customSeed != null
                      ? Color(customSeed)
                      : AppTheme.seedColor;

                  final presetLightScheme = openCodeLightSchemeFor(themePreset);
                  final presetDarkScheme = openCodeDarkSchemeFor(themePreset);

                  // Use dynamic platform colors when available and enabled
                  final lightScheme =
                      presetLightScheme ??
                      (useDynamic && lightDynamic != null
                          ? lightDynamic
                          : ColorScheme.fromSeed(
                              seedColor: seedColor,
                              brightness: Brightness.light,
                              contrastLevel: contrastLevel,
                            ));
                  final darkScheme =
                      presetDarkScheme ??
                      (useDynamic && darkDynamic != null
                          ? darkDynamic
                          : ColorScheme.fromSeed(
                              seedColor: seedColor,
                              brightness: Brightness.dark,
                              contrastLevel: contrastLevel,
                            ));
                  final resolvedDarkScheme = useAmoledDark
                      ? _applyAmoledDarkScheme(darkScheme)
                      : darkScheme;
                  final lightThemeTokens = themePreset != null
                      ? openCodeThemeTokensFor(themePreset, Brightness.light)
                      : null;
                  final darkThemeTokens = themePreset != null
                      ? openCodeThemeTokensFor(themePreset, Brightness.dark)
                      : null;
                  final lightResolvedTokens =
                      lightThemeTokens ?? classicThemeTokensFrom(lightScheme);
                  final darkResolvedTokens =
                      darkThemeTokens ??
                      classicThemeTokensFrom(resolvedDarkScheme);

                  // Map user theme mode preference to Flutter ThemeMode
                  final themeMode = switch (appSettings.themeMode) {
                    ThemeModeOption.light => ThemeMode.light,
                    ThemeModeOption.dark => ThemeMode.dark,
                    ThemeModeOption.system => ThemeMode.system,
                  };
                  final systemFontScale = appSettings.systemFontScale;
                  return MaterialApp(
                    title: AppConstants.appName,
                    theme: AppTheme.lightFrom(
                      lightScheme,
                      appDensity: appDensity,
                      visualStyle: visualStyle,
                      themeExtensions: <ThemeExtension<dynamic>>[
                        lightResolvedTokens,
                      ],
                    ),
                    darkTheme: AppTheme.darkFrom(
                      resolvedDarkScheme,
                      appDensity: appDensity,
                      visualStyle: visualStyle,
                      themeExtensions: <ThemeExtension<dynamic>>[
                        darkResolvedTokens,
                      ],
                    ),
                    themeMode: themeMode,
                    locale: localeProvider.effectiveLocale,
                    localizationsDelegates: const [
                      AppLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                    supportedLocales: AppLocales.supported,
                    localeResolutionCallback: AppLocales.resolutionCallback,
                    builder: (context, child) {
                      L10nBridge.update(AppLocalizations.of(context));
                      final mediaQuery = MediaQuery.of(context);
                      final composedScaler = TextScaler.linear(systemFontScale);
                      return Builder(
                        builder: (themeContext) {
                          return Theme(
                            data: AppTheme.withResponsiveSnackBars(
                              Theme.of(themeContext),
                              mediaQuery,
                              textDirection:
                                  Directionality.maybeOf(themeContext) ??
                                  TextDirection.ltr,
                            ),
                            child: MediaQuery(
                              data: mediaQuery.copyWith(textScaler: composedScaler),
                              child: DesktopWindowChromeFrame(
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    home: const AppShellPage(),
                    debugShowCheckedModeBanner: false,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

bool _isDesktopRuntime() {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

bool _isAndroidRuntime() {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android;
}

/// Bounds Android image caches and releases them on memory pressure.
///
/// The Android release heap is capped (256 MB without largeHeap) while a
/// single platform message can transiently need tens of megabytes, so
/// unbounded caches directly contribute to release-only frame starvation.
/// Desktop keeps the default cache policy.
void _configureAndroidMemoryBounds() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 100;
  imageCache.maximumSizeBytes = 32 << 20;
  WidgetsBinding.instance.addObserver(_AndroidMemoryPressureObserver());
}

class _AndroidMemoryPressureObserver with WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  }
}

ColorScheme _applyAmoledDarkScheme(ColorScheme base) {
  const black = Colors.black;
  return base.copyWith(
    surface: black,
    surfaceDim: black,
    surfaceBright: black,
    surfaceContainerLowest: black,
    surfaceContainerLow: black,
    surfaceContainer: black,
    surfaceContainerHigh: black,
    surfaceContainerHighest: black,
  );
}

/// Direct-subscription replacement for the root Selector.
///
/// The provider package's InheritedWidget propagation does not rebuild
/// dependents in Android release builds on this device (notify fires,
/// direct listeners work, frames run, but Selector/Consumer builders never
/// re-run). [DirectSelector] subscribes via addListener directly (proven
/// path) and keeps Selector-equivalent filtering through record equality.
typedef _AppSettingsRecord = ({
  AppDensity appDensity,
  bool useDynamicColor,
  bool useAmoledDark,
  int? customColorSeed,
  double contrastLevel,
  OpenCodeThemePreset? themePreset,
  VisualStyle visualStyle,
  ThemeModeOption themeMode,
  double systemFontScale,
});
