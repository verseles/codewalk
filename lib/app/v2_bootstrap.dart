import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../platform/appearance/dynamic_color_adapter.dart';
import '../shared/l10n/generated/v2_localizations.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/theme/app_theme.dart';
import '../shared/theme/appearance_theme_resolver.dart';
import 'app_dependencies.dart';
import 'app_preferences_controller.dart';

/// Owns a composed v2 graph; widgets receive typed dependencies, not a locator.
class CodeWalkV2Bootstrap extends StatefulWidget {
  const CodeWalkV2Bootstrap({
    super.key,
    required this.dependencies,
    this.dynamicColors = platformDynamicColors,
  });

  final AppDependencies dependencies;
  final DynamicColorSource dynamicColors;

  @override
  State<CodeWalkV2Bootstrap> createState() => _CodeWalkV2BootstrapState();
}

class _CodeWalkV2BootstrapState extends State<CodeWalkV2Bootstrap> {
  @override
  void didUpdateWidget(CodeWalkV2Bootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dependencies, widget.dependencies)) {
      oldWidget.dependencies.dispose();
    }
  }

  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dependencies.preferences),
        ChangeNotifierProvider.value(value: dependencies.navigation),
        Provider.value(value: dependencies.localizations),
      ],
      child: Consumer<AppPreferencesController>(
        builder: (context, preferences, child) => widget.dynamicColors((
          light,
          dark,
        ) {
          final available = light != null || dark != null;
          if (available != preferences.dynamicColorAvailable) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && identical(widget.dependencies, dependencies)) {
                preferences.setDynamicColorAvailable(available);
              }
            });
          }
          final themes = resolveAppearanceThemes(
            preset: preferences.themePreset,
            customColorSeed: preferences.customColorSeed,
            contrastLevel: preferences.contrastLevel,
            useDynamicColor: preferences.useDynamicColor,
            useAmoledDark: preferences.useAmoledDark,
            density: preferences.density,
            visualStyle: preferences.visualStyle,
            lightDynamic: light,
            darkDynamic: dark,
          );
          return MaterialApp.router(
            title: 'CodeWalk',
            routerConfig: dependencies.router,
            theme: themes.light,
            darkTheme: themes.dark,
            themeMode: preferences.themeMode,
            locale: preferences.locale,
            supportedLocales: V2Localizations.supportedLocales,
            localizationsDelegates: V2Localizations.localizationsDelegates,
            localeListResolutionCallback: resolveV2LocaleList,
            builder: (context, child) {
              dependencies.localizations.update(V2Localizations.of(context));
              return Theme(
                data: AppTheme.withResponsiveSnackBars(
                  Theme.of(context),
                  MediaQuery.of(context),
                  textDirection: Directionality.of(context),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        }),
      ),
    );
  }
}
