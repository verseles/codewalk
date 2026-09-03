import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('theme mode change repaints without restart', (
    WidgetTester tester,
  ) async {
    final provider = SettingsProvider(
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    addTearDown(provider.dispose);

    ThemeMode resolveMode(ThemeModeOption option) {
      return switch (option) {
        ThemeModeOption.light => ThemeMode.light,
        ThemeModeOption.dark => ThemeMode.dark,
        ThemeModeOption.system => ThemeMode.system,
      };
    }

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: provider,
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: resolveMode(settings.themeMode),
              home: Builder(
                builder: (context) {
                  return Text('${Theme.of(context).brightness}');
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    var notifications = 0;
    provider.addListener(() {
      notifications++;
    });
    await provider.setThemeMode(ThemeModeOption.dark);
    expect(notifications, greaterThanOrEqualTo(1));
    // MaterialApp animates theme changes through AnimatedTheme; settle it.
    await tester.pumpAndSettle();
    expect(provider.themeMode, ThemeModeOption.dark);
    expect(find.text('Brightness.dark'), findsOneWidget);

    await provider.setThemeMode(ThemeModeOption.light);
    await tester.pumpAndSettle();
    expect(provider.themeMode, ThemeModeOption.light);
    expect(find.text('Brightness.light'), findsOneWidget);
  });
}
