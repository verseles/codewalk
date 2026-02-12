import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/presentation/pages/server_settings_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAppLocalDataSource localDataSource;
  late AppProvider appProvider;

  setUp(() async {
    localDataSource = InMemoryAppLocalDataSource();
    appProvider = AppProvider(
      getAppInfo: GetAppInfo(FakeAppRepository()),
      checkConnection: CheckConnection(FakeAppRepository()),
      localDataSource: localDataSource,
      dioClient: DioClient(),
      enableHealthPolling: false,
    );
    await appProvider.initialize();
    await appProvider.addServerProfile(
      url: 'http://127.0.0.1:4101',
      label: 'Alpha',
      setAsActive: true,
    );
    await appProvider.addServerProfile(
      url: 'http://127.0.0.1:4102',
      label: 'Beta',
    );
    final alpha = appProvider.serverProfiles
        .where((p) => p.displayName == 'Alpha')
        .first;
    final beta = appProvider.serverProfiles
        .where((p) => p.displayName == 'Beta')
        .first;
    appProvider.setHealthForTesting(alpha.id, ServerHealthStatus.healthy);
    appProvider.setHealthForTesting(beta.id, ServerHealthStatus.unhealthy);
  });

  testWidgets('renders server list with active/default metadata', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();

    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Default'), findsWidgets);
  });

  testWidgets('blocks activating unhealthy server from action menu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();

    final betaTile = find.ancestor(
      of: find.text('Beta'),
      matching: find.byType(ListTile),
    );
    final betaMenu = find.descendant(
      of: betaTile,
      matching: find.byIcon(Icons.more_vert),
    );
    expect(betaMenu, findsOneWidget);

    await tester.tap(betaMenu);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Active'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot activate an unhealthy server'), findsOneWidget);
  });

  testWidgets('add/edit dialog exposes AI generated title privacy toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Server'));
    await tester.pumpAndSettle();

    expect(find.text('Enable AI generated titles'), findsOneWidget);
    expect(
      find.textContaining('This is a free service powered by https://ch.at'),
      findsOneWidget,
    );
  });
}

Widget _testApp(AppProvider appProvider) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: appProvider,
    child: const MaterialApp(home: ServerSettingsPage()),
  );
}
