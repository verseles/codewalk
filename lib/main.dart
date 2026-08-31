import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

// Keeps the native Android service entrypoint reachable in AOT builds.
@pragma('vm:entry-point')
void _sessionOverlayAndroidEntrypointAnchor() {
  sessionOverlayAndroidMain();
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
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Selector<
            SettingsProvider,
            ({
              AppDensity appDensity,
              bool useDynamicColor,
              bool useAmoledDark,
              int? customColorSeed,
              double contrastLevel,
              OpenCodeThemePreset? themePreset,
              VisualStyle visualStyle,
              ThemeModeOption themeMode,
              double systemFontScale,
              bool dynamicColorAvailable,
            })
          >(
            selector: (context, settingsProvider) => (
              appDensity: settingsProvider.appDensity,
              useDynamicColor: settingsProvider.useDynamicColor,
              useAmoledDark: settingsProvider.useAmoledDark,
              customColorSeed: settingsProvider.customColorSeed,
              contrastLevel: settingsProvider.contrastLevel,
              themePreset: settingsProvider.themePreset,
              visualStyle: settingsProvider.visualStyle,
              themeMode: settingsProvider.themeMode,
              systemFontScale: settingsProvider.systemFontScale,
              dynamicColorAvailable: settingsProvider.dynamicColorAvailable,
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
                  final hasDynamic =
                      lightDynamic != null || darkDynamic != null;
                  if (appSettings.dynamicColorAvailable != hasDynamic) {
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
                      return Theme(
                        data: AppTheme.withResponsiveSnackBars(
                          Theme.of(context),
                          mediaQuery,
                          textDirection:
                              Directionality.maybeOf(context) ??
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
