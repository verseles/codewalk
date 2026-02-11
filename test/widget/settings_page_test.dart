import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('shows modular sections and opens notifications section', (
    WidgetTester tester,
  ) async {
    final local = InMemoryAppLocalDataSource();
    final settingsProvider = SettingsProvider(
      localDataSource: local,
      soundService: SoundService(),
    );
    unawaited(settingsProvider.initialize());

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Shortcuts'), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);

    await tester.tap(find.text('Notifications').first);
    await tester.pumpAndSettle();

    expect(find.text('Agent updates'), findsOneWidget);
    expect(find.text('Permissions and questions'), findsOneWidget);
  });
}
