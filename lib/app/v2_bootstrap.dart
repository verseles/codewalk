import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/l10n/generated/v2_localizations.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/theme/app_theme.dart';
import 'app_dependencies.dart';
import 'app_preferences_controller.dart';

/// Owns a composed v2 graph; widgets receive typed dependencies, not a locator.
class CodeWalkV2Bootstrap extends StatefulWidget {
  const CodeWalkV2Bootstrap({super.key, required this.dependencies});

  final AppDependencies dependencies;

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
        builder: (context, preferences, child) => MaterialApp.router(
          title: 'CodeWalk',
          routerConfig: dependencies.router,
          theme: AppTheme.lightFrom(
            ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
            appDensity: preferences.density,
            visualStyle: preferences.visualStyle,
          ),
          darkTheme: AppTheme.darkFrom(
            ColorScheme.fromSeed(
              seedColor: AppTheme.seedColor,
              brightness: Brightness.dark,
            ),
            appDensity: preferences.density,
            visualStyle: preferences.visualStyle,
          ),
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
        ),
      ),
    );
  }
}
