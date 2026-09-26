import 'dart:async';

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/presentation/pages/server_settings_page.dart';
import 'package:codewalk/presentation/pages/settings/sections/servers_settings_section.dart';
import 'package:codewalk/presentation/pages/settings/widgets/settings_search_navigation.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/services/local_opencode_server_runtime_types.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:codewalk/presentation/widgets/searchable_dropdown_form_field.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/pump_localized_app.dart';

class _RecordingAppProvider extends AppProvider {
  _RecordingAppProvider(InMemoryAppLocalDataSource local)
    : super(
        getAppInfo: GetAppInfo(FakeAppRepository()),
        checkConnection: CheckConnection(FakeAppRepository()),
        localDataSource: local,
        dioClient: DioClient(),
        localServerRuntime: FakeLocalOpencodeServerRuntime(supported: false),
        enableHealthPolling: false,
        serverHealthProbe: (profile) async => profile.displayName == 'Beta'
            ? ServerHealthStatus.unhealthy
            : ServerHealthStatus.healthy,
      );

  Completer<void>? activationGate;
  int activationCalls = 0;

  @override
  Future<bool> setActiveServer(String id, {bool blockUnhealthy = true}) async {
    activationCalls++;
    if (activationGate != null) await activationGate!.future;
    return super.setActiveServer(id, blockUnhealthy: blockUnhealthy);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAppLocalDataSource localDataSource;
  late _RecordingAppProvider appProvider;

  Future<void> prepareFixture(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    appProvider = _RecordingAppProvider(localDataSource);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  setUp(() {
    // Let the widget initialize cached futures inside its fake-async zone.
    localDataSource = InMemoryAppLocalDataSource()
      ..serverProfilesJson =
          '[{"id":"alpha","url":"http://127.0.0.1:4101","label":"Alpha","createdAt":1,"updatedAt":1},{"id":"beta","url":"http://127.0.0.1:4102","label":"Beta","createdAt":2,"updatedAt":2}]'
      ..activeServerId = 'alpha'
      ..defaultServerId = 'alpha';
  });

  tearDown(() => appProvider.dispose());

  testWidgets('renders server list with active/default metadata', (
    WidgetTester tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();

    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Default'), findsWidgets);

    await _scrollToServer(tester, 'Beta');
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('blocks activating an unhealthy server by tapping its row', (
    WidgetTester tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    await _scrollToServer(tester, 'Beta');

    final betaTile = find.ancestor(
      of: find.text('Beta'),
      matching: find.byType(ListTile),
    );
    await tester.tap(betaTile);
    await tester.pumpAndSettle();

    expect(find.text('Cannot activate an unhealthy server'), findsOneWidget);
    expect(appProvider.activeServer!.displayName, 'Alpha');
  });

  testWidgets('G4 server row activates once and preserves default selection', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    final defaultId = appProvider.defaultServerId;
    appProvider.setHealthForTesting(beta.id, ServerHealthStatus.healthy);
    await tester.pump();
    expect(find.byType(SearchableDropdownFormField<String>), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(appProvider.activeServerId, beta.id);
    expect(appProvider.defaultServerId, defaultId);
    final row = find.descendant(
      of: find.byKey(ValueKey('settings_server_${beta.id}')),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(row).selected, isTrue);
    expect(tester.widget<ListTile>(row).onTap, isNull);
  });

  testWidgets('G4 inline server search filters without switching and clears', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final activeId = appProvider.activeServerId;
    final search = find.byKey(const ValueKey('settings_servers_filter'));
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    for (final query in ['bEtA', '4102', beta.id]) {
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(appProvider.activeServerId, activeId);
    }
    await tester.enterText(search, 'no matching server');
    await tester.pumpAndSettle();
    expect(find.text('No servers found'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings_servers_active')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('G4 overflow management does not activate its profile', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final activeId = appProvider.activeServerId;
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    final row = find.byKey(ValueKey('settings_server_${beta.id}'));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Symbols.more_vert)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set Active'), findsNothing);
    expect(find.text('Set Default'), findsOneWidget);
    expect(appProvider.activeServerId, activeId);
    await tester.tap(find.text('Set Default'));
    await tester.pumpAndSettle();
    expect(appProvider.defaultServerId, beta.id);
    expect(appProvider.activeServerId, activeId);
  });

  testWidgets('G4 server selection ignores repeated taps while pending', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    appProvider.setHealthForTesting(beta.id, ServerHealthStatus.unknown);
    appProvider.activationCalls = 0;
    appProvider.activationGate = Completer<void>();
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(appProvider.activationCalls, 1);
    expect(appProvider.activeServer!.displayName, 'Alpha');
    appProvider.activationGate!.complete();
    await tester.pumpAndSettle();
    expect(appProvider.activeServerId, beta.id);
  });

  testWidgets('G4 server row supports keyboard activation', (tester) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    appProvider.setHealthForTesting(beta.id, ServerHealthStatus.healthy);
    await tester.pump();
    Focus.of(tester.element(find.text('Beta'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(appProvider.activeServerId, beta.id);
  });

  testWidgets('G4 failed activation releases the row for retry', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(_testApp(appProvider));
    await tester.pumpAndSettle();
    final beta = appProvider.serverProfiles.firstWhere(
      (p) => p.displayName == 'Beta',
    );
    appProvider.setHealthForTesting(beta.id, ServerHealthStatus.healthy);
    appProvider.activationGate = Completer<void>();
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    appProvider.activationGate!.completeError(StateError('fixture failure'));
    await tester.pumpAndSettle();
    expect(appProvider.activeServer!.displayName, 'Alpha');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    appProvider.activationGate = null;
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(appProvider.activeServerId, beta.id);
  });

  testWidgets(
    'G4 server metadata wraps on narrow RTL screens with large text',
    (tester) async {
      await prepareFixture(tester, size: const Size(390, 844));
      await appProvider.addServerProfile(
        url: 'https://long-name.example.test/long/workspace/server/path',
        label: 'Servidor com nome longo para testar a seleção responsiva',
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: localizedMaterialApp(
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
            ),
            home: const ServerSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _scrollToServer(
        tester,
        'Servidor com nome longo para testar a seleção responsiva',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('G4 search destination reveals the unified server filter', (
    tester,
  ) async {
    await prepareFixture(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: appProvider,
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SettingsSearchDestination(
              request: SettingsSearchRequest(
                'settings_servers_active',
                'Choose active server',
                1,
              ),
              child: ServersSettingsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings_servers_filter')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings_highlight_settings_servers_active')),
      findsOneWidget,
    );
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('G4 Settings card theme is scoped at width $width', (
      tester,
    ) async {
      await prepareFixture(tester, size: Size(width, 900));
      for (final style in VisualStyle.values) {
        final theme = AppTheme.lightFrom(
          ColorScheme.fromSeed(seedColor: Colors.blue),
          visualStyle: style,
        );
        await tester.pumpWidget(_testApp(appProvider, theme: theme));
        await tester.pumpAndSettle();
        final alpha = appProvider.serverProfiles.firstWhere(
          (p) => p.displayName == 'Alpha',
        );
        final card = find.byKey(ValueKey('settings_server_${alpha.id}'));
        final shape =
            Theme.of(tester.element(card)).cardTheme.shape! as OutlinedBorder;
        expect(shape.side, BorderSide.none);
        if (style == VisualStyle.refined) {
          expect(
            (theme.cardTheme.shape! as OutlinedBorder).side,
            isNot(BorderSide.none),
          );
        }
        expect(
          Theme.of(tester.element(card)).inputDecorationTheme,
          theme.inputDecorationTheme,
        );
      }
    });
  }

  testWidgets('local server card opens separate setup debug page', (
    WidgetTester tester,
  ) async {
    await prepareFixture(tester);

    final localServerRuntime = FakeLocalOpencodeServerRuntime(
      supported: true,
      diagnoseResult: const LocalOpencodeEnvironmentReport(
        supported: true,
        platform: 'linux',
        opencode: LocalToolStatus(available: true, path: '/tmp/opencode'),
        node: LocalToolStatus(available: true),
        npm: LocalToolStatus(available: true),
        bun: LocalToolStatus(available: true),
        wsl: LocalToolStatus(available: false),
        hasNetworkAccess: true,
        installDirectoryWritable: true,
        recommendation: 'Ready',
      ),
    );
    final supportedProvider = AppProvider(
      getAppInfo: GetAppInfo(FakeAppRepository()),
      checkConnection: CheckConnection(FakeAppRepository()),
      localDataSource: InMemoryAppLocalDataSource(),
      dioClient: DioClient(),
      localServerRuntime: localServerRuntime,
      enableHealthPolling: false,
    );
    await supportedProvider.initialize();
    await tester.pumpWidget(_testApp(supportedProvider));
    await tester.pumpAndSettle();

    expect(find.text('Setup Debug'), findsOneWidget);

    await tester.tap(find.text('Setup Debug'));
    await tester.pumpAndSettle();

    expect(find.text('OpenCode Setup Debug'), findsOneWidget);
  });

  testWidgets(
    'add server opens unified wizard and preserves remote setup form',
    (WidgetTester tester) async {
      await prepareFixture(tester);
      await tester.pumpWidget(_testApp(appProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Server'));
      await tester.pumpAndSettle();

      expect(find.text('Server connection'), findsOneWidget);
      expect(find.text('Choose another path'), findsOneWidget);
      expect(find.text('AI generated titles'), findsOneWidget);

      final urlField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      final expectedDefaultUrl = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4096'
          : 'http://127.0.0.1:4096';
      expect(urlField.controller?.text, expectedDefaultUrl);

      await tester.tap(find.text('Choose another path'));
      await tester.pumpAndSettle();

      expect(find.text('Connect to a running server'), findsOneWidget);
      expect(find.text('Show me the setup steps'), findsOneWidget);
      expect(find.text('Let CodeWalk set it up locally'), findsOneWidget);

      await tester.ensureVisible(find.text('Show me the setup steps'));
      await tester.tap(find.text('Show me the setup steps'));
      await tester.pumpAndSettle();

      expect(find.text('Quick setup'), findsOneWidget);
      expect(
        find.textContaining('opencode serve --hostname 0.0.0.0 --port 4096'),
        findsOneWidget,
      );
      expect(find.text('Protect access with password'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Symbols.content_copy_rounded), findsOneWidget);
      expect(find.text('1. Install OpenCode CLI.'), findsOneWidget);
      expect(find.textContaining('opencode.ai/docs/server'), findsNothing);
      expect(find.textContaining('Use this URL in the app'), findsNothing);
      expect(find.text('4. Verify with /global/health or /doc.'), findsNothing);

      await tester.tap(find.text('Protect access with password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'mypass123');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('OPENCODE_SERVER_PASSWORD=\'mypass123\''),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue to server URL'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();

      final clearedUrlField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(clearedUrlField.controller?.text, isEmpty);
      expect(find.text('AI generated titles'), findsOneWidget);
    },
  );
}

Widget _testApp(AppProvider appProvider, {ThemeData? theme}) {
  return ChangeNotifierProvider<AppProvider>.value(
    value: appProvider,
    child: localizedMaterialApp(theme: theme, home: const ServerSettingsPage()),
  );
}

Future<void> _scrollToServer(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isNotEmpty) {
    return;
  }

  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
}
