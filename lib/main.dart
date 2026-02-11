import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'core/di/injection_container.dart' as di;
import 'presentation/theme/app_theme.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/project_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/pages/app_shell_page.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize dependency injection
  await di.init();

  runApp(const MyApp());
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
        ChangeNotifierProvider(
          create: (_) {
            final provider = di.sl<SettingsProvider>();
            unawaited(provider.initialize());
            return provider;
          },
        ),
      ],
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          final fallbackLight = ColorScheme.fromSeed(
            seedColor: AppTheme.seedColor,
            brightness: Brightness.light,
          );
          final fallbackDark = ColorScheme.fromSeed(
            seedColor: AppTheme.seedColor,
            brightness: Brightness.dark,
          );
          return MaterialApp(
            title: AppConstants.appName,
            theme: AppTheme.lightFrom(lightDynamic ?? fallbackLight),
            darkTheme: AppTheme.darkFrom(darkDynamic ?? fallbackDark),
            themeMode: ThemeMode.system,
            home: ChangeNotifierProvider(
              create: (_) => di.sl<ChatProvider>(),
              child: const AppShellPage(),
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
