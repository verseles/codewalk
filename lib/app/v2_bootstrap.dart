import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/settings/release_history_controller.dart';
import '../features/settings/update_check_controller.dart';
import '../platform/appearance/dynamic_color_adapter.dart';
import '../platform/sessions/session_draft_store.dart';
import '../shared/diagnostics/diagnostics_controller.dart';
import '../shared/l10n/generated/v2_localizations.dart';
import '../shared/l10n/l10n_bridge.dart';
import '../shared/sessions/permission_mode.dart';
import '../shared/sessions/session_history_source.dart';
import '../shared/sessions/session_live_source.dart';
import '../shared/theme/app_theme.dart';
import '../shared/theme/appearance_theme_resolver.dart';
import 'app_dependencies.dart';
import 'app_keyboard_shortcuts.dart';
import 'app_preferences_controller.dart';
import 'workspace_controller.dart';

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

class _CodeWalkV2BootstrapState extends State<CodeWalkV2Bootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.dependencies.liveWake?.lifecycle(state);
    // The app may be killed once it leaves the foreground: what was typed
    // and not yet written is written now.
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.dependencies.sessionDrafts?.flush());
    }
  }

  @override
  void didUpdateWidget(CodeWalkV2Bootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dependencies, widget.dependencies)) {
      oldWidget.dependencies.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        ChangeNotifierProvider.value(value: dependencies.hosts),
        Provider<SessionHistoryFactory?>.value(
          value: dependencies.historyFactory,
        ),
        Provider<SessionLiveDirectory?>.value(
          value: dependencies.liveDirectory,
        ),
        Provider<SessionDraftStore?>.value(value: dependencies.sessionDrafts),
        if (dependencies.permissionModes case final modes?)
          ChangeNotifierProvider<EditablePermissionModePolicy>.value(
            value: modes,
          ),
        if (dependencies.sessions case final sessions?)
          ChangeNotifierProvider<SessionsController>.value(value: sessions),
        if (dependencies.sessionTabs case final tabs?)
          ChangeNotifierProvider<SessionTabsController>.value(value: tabs),
        if (dependencies.workspace case final workspace?)
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
        if (dependencies.diagnostics case final diagnostics?)
          ChangeNotifierProvider<DiagnosticsController>.value(
            value: diagnostics,
          ),
        if (dependencies.releaseHistory case final history?)
          ChangeNotifierProvider<ReleaseHistoryController>.value(
            value: history,
          ),
        if (dependencies.updates case final updates?)
          ChangeNotifierProvider<UpdateCheckController>.value(value: updates),
        if (dependencies.pairing case final pairing?)
          ChangeNotifierProvider.value(value: pairing),
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
                child: AppKeyboardShortcuts(
                  preferences: preferences,
                  // Opened over the current page, like the gear, so the
                  // system back returns to it; never twice in a row.
                  openSettings: () {
                    final router = dependencies.router;
                    if (router.state.uri.path != '/settings') {
                      router.push('/settings');
                    }
                  },
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
