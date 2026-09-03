import 'dart:async';

import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/core/tailscale/tailscale_service.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/presentation/pages/onboarding_wizard_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/local_opencode_server_runtime_types.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';

class _NoopTailscaleService extends TailscaleService {
  @override
  TailscaleState get state => const TailscaleState.disconnected();

  @override
  Stream<TailscaleState> get stateChanges =>
      Stream<TailscaleState>.value(state);

  @override
  http.Client get httpClient => throw UnsupportedError('No Tailscale client');

  @override
  Future<TailscaleState> upForProfile({
    required String profileId,
    required String profileLabel,
  }) async {
    return state;
  }

  @override
  Future<void> down() async {}
}

class _DelayedLocalOpencodeServerRuntime
    extends FakeLocalOpencodeServerRuntime {
  _DelayedLocalOpencodeServerRuntime() : super(supported: true);

  final Completer<void> _startGate = Completer<void>();

  void finishStart() => _startGate.complete();

  @override
  Future<LocalOpencodeServerStartResult> start({
    required String host,
    required int port,
    String? commandPath,
  }) async {
    await _startGate.future;
    return super.start(host: host, port: port, commandPath: commandPath);
  }
}

class _DelayedExperienceSettingsDataSource extends InMemoryAppLocalDataSource {
  Completer<void>? _saveGate;

  void delayNextSave() {
    _saveGate = Completer<void>();
  }

  void finishSave() {
    _saveGate?.complete();
    _saveGate = null;
  }

  @override
  Future<void> saveExperienceSettingsJson(String settingsJson) async {
    await _saveGate?.future;
    await super.saveExperienceSettingsJson(settingsJson);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryAppLocalDataSource localDataSource;
  late AppProvider appProvider;
  late SettingsProvider settingsProvider;

  setUp(() async {
    localDataSource = InMemoryAppLocalDataSource();
    appProvider = AppProvider(
      getAppInfo: GetAppInfo(FakeAppRepository()),
      checkConnection: CheckConnection(FakeAppRepository()),
      localDataSource: localDataSource,
      dioClient: DioClient(),
      tailscaleService: _NoopTailscaleService(),
      serverHealthProbe: (_) async => ServerHealthStatus.unhealthy,
      serverHealthRequestTimeout: const Duration(milliseconds: 5),
      enableHealthPolling: false,
    );
    settingsProvider = SettingsProvider(
      localDataSource: localDataSource,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await appProvider.initialize();
    await settingsProvider.initialize();
  });

  Widget buildWizard({
    VoidCallback? onComplete,
    AppProvider? providerOverride,
    SetupWizardInitialFlow initialFlow = SetupWizardInitialFlow.choose,
    bool showSkipAction = true,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(
          value: providerOverride ?? appProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocales.supported,
        home: OnboardingWizardPage(
          onComplete: onComplete,
          initialFlow: initialFlow,
          showSkipAction: showSkipAction,
        ),
      ),
    );
  }

  Future<AppProvider> createManagedProvider(
    FakeLocalOpencodeServerRuntime localServerRuntime,
  ) async {
    final provider = AppProvider(
      getAppInfo: GetAppInfo(FakeAppRepository()),
      checkConnection: CheckConnection(FakeAppRepository()),
      localDataSource: localDataSource,
      dioClient: DioClient(),
      localServerRuntime: localServerRuntime,
      serverHealthProbe: (_) async => ServerHealthStatus.healthy,
      localServerHealthProbe: (_) async => ServerHealthStatus.healthy,
      enableHealthPolling: false,
    );
    await provider.initialize();
    return provider;
  }

  group('welcome step', () {
    testWidgets('shows beginner-friendly welcome options', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to CodeWalk'), findsOneWidget);
      expect(find.text('Connect to a running server'), findsOneWidget);
      expect(find.text('Show me the setup steps'), findsOneWidget);
      expect(find.text('What is OpenCode?'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('prioritizes guided setup when local setup is unsupported', (
      WidgetTester tester,
    ) async {
      await _setCompactSurface(tester);
      final unsupportedProvider = AppProvider(
        getAppInfo: GetAppInfo(FakeAppRepository()),
        checkConnection: CheckConnection(FakeAppRepository()),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: FakeLocalOpencodeServerRuntime(supported: false),
        enableHealthPolling: false,
      );
      await unsupportedProvider.initialize();

      await tester.pumpWidget(
        buildWizard(providerOverride: unsupportedProvider),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget(
          find.byKey(const ValueKey('first_run_primary_setup_action')),
        ),
        isA<FilledButton>(),
      );
      expect(find.text('Show me the setup steps'), findsOneWidget);
      expect(
        tester.widget(
          find.byKey(const ValueKey('first_run_connect_server_action')),
        ),
        isA<OutlinedButton>(),
      );
      expect(find.text('Connect to a running server'), findsOneWidget);
      expect(find.text('Let CodeWalk set it up locally'), findsNothing);
      expect(
        find.text('Available only on desktop (Linux/macOS/Windows).'),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_server_setup')), findsOneWidget);
      expect(find.text('Quick setup'), findsOneWidget);
    });

    testWidgets('prioritizes managed setup by capability on narrow windows', (
      WidgetTester tester,
    ) async {
      await _setCompactSurface(tester);
      final supportedProvider = AppProvider(
        getAppInfo: GetAppInfo(FakeAppRepository()),
        checkConnection: CheckConnection(FakeAppRepository()),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: FakeLocalOpencodeServerRuntime(supported: true),
        enableHealthPolling: false,
      );
      await supportedProvider.initialize();

      await tester.pumpWidget(buildWizard(providerOverride: supportedProvider));
      await tester.pumpAndSettle();

      expect(
        tester.widget(
          find.byKey(const ValueKey('first_run_primary_setup_action')),
        ),
        isA<FilledButton>(),
      );
      expect(find.text('Let CodeWalk set it up locally'), findsOneWidget);
      expect(
        tester.widget(
          find.byKey(const ValueKey('first_run_connect_server_action')),
        ),
        isA<OutlinedButton>(),
      );
      expect(
        tester.widget(
          find.byKey(const ValueKey('first_run_guided_setup_action')),
        ),
        isA<TextButton>(),
      );

      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_local_setup')), findsOneWidget);
    });

    testWidgets('preserves the complete chooser outside first run', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      final unsupportedProvider = AppProvider(
        getAppInfo: GetAppInfo(FakeAppRepository()),
        checkConnection: CheckConnection(FakeAppRepository()),
        localDataSource: localDataSource,
        dioClient: DioClient(),
        localServerRuntime: FakeLocalOpencodeServerRuntime(supported: false),
        enableHealthPolling: false,
      );
      await unsupportedProvider.initialize();

      await tester.pumpWidget(
        buildWizard(
          providerOverride: unsupportedProvider,
          showSkipAction: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect to a running server'), findsOneWidget);
      expect(find.text('Show me the setup steps'), findsOneWidget);
      expect(find.text('Let CodeWalk set it up locally'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
        findsNothing,
      );
    });

    testWidgets(
      'supports large text and accessible tap targets on compact UI',
      (WidgetTester tester) async {
        await _setCompactSurface(tester);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final unsupportedProvider = AppProvider(
          getAppInfo: GetAppInfo(FakeAppRepository()),
          checkConnection: CheckConnection(FakeAppRepository()),
          localDataSource: localDataSource,
          dioClient: DioClient(),
          localServerRuntime: FakeLocalOpencodeServerRuntime(supported: false),
          enableHealthPolling: false,
        );
        await unsupportedProvider.initialize();

        await tester.pumpWidget(
          buildWizard(providerOverride: unsupportedProvider),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('what_is_opencode_tile')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester, meetsGuideline(androidTapTargetGuideline));
      },
    );
  });

  group('skip flow', () {
    testWidgets('skip without checkbox calls onComplete', (
      WidgetTester tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(buildWizard(onComplete: () => completed = true));
      await tester.pumpAndSettle();

      // Tap the Skip button in the AppBar.
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Skip dialog should appear.
      expect(find.text('Skip setup?'), findsOneWidget);
      expect(find.text("Don't show again"), findsOneWidget);

      // Confirm skip WITHOUT checking "Don't show again".
      await tester.tap(find.widgetWithText(FilledButton, 'Skip'));
      await tester.pumpAndSettle();

      // onComplete should have been called.
      expect(completed, isTrue);

      // The persistent flag should remain false.
      expect(settingsProvider.skipOnboardingWizard, isFalse);
    });

    testWidgets('skip with checkbox persists skipOnboardingWizard', (
      WidgetTester tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(buildWizard(onComplete: () => completed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Check the "Don't show again" checkbox.
      await tester.tap(find.text("Don't show again"));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(settingsProvider.skipOnboardingWizard, isTrue);
    });

    testWidgets('skip dialog Enter confirms the primary action', (
      WidgetTester tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(buildWizard(onComplete: () => completed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('cancel in skip dialog returns to wizard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Skip setup?'), findsOneWidget);

      // Cancel the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Should still be on the welcome step.
      expect(find.text('Welcome to CodeWalk'), findsOneWidget);
    });
  });

  group('server setup step', () {
    testWidgets('connect to server navigates to URL form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect to a running server'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_server_setup')), findsOneWidget);

      if (find.text('Continue to server URL').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continue to server URL'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Connection tips'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('open_code_setup_debug_button_server_form')),
        findsOneWidget,
      );
      expect(find.text('Show setup steps'), findsOneWidget);

      await tester.tap(find.text('Connection tips'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Suggested local OpenCode server URL:'),
        findsOneWidget,
      );
    });

    testWidgets('server form can reopen the setup steps inline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect to a running server'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show setup steps'));
      await tester.pumpAndSettle();

      expect(find.text('Quick setup'), findsOneWidget);
      expect(find.text('Continue to server URL'), findsOneWidget);
    });

    testWidgets('need help shows quick guide then continues to form', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Show me the setup steps'));
      await tester.tap(find.text('Show me the setup steps'));
      await tester.pumpAndSettle();

      // Quick guide should be visible.
      expect(find.text('Quick setup'), findsOneWidget);
      expect(find.text('Continue to server URL'), findsOneWidget);

      // Tap continue to show the URL form.
      await tester.tap(find.text('Continue to server URL'));
      await tester.pumpAndSettle();

      expect(find.text('Server connection'), findsOneWidget);
    });

    testWidgets('test connection adds server and moves to step 2', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect to a running server'));
      await tester.pumpAndSettle();

      // Tap "Test connection" and let the async chain complete.
      await tester.ensureVisible(find.text('Test connection'));
      await tester.tap(find.text('Test connection'));
      await tester.runAsync(() async {
        // Keep a margin above the injected health timeout.
        await Future<void>.delayed(const Duration(milliseconds: 180));
      });
      // Use pump instead of pumpAndSettle to avoid timeout from spinner.
      await tester.pump();

      // Server should have been added (health may fail, but profile persists).
      expect(appProvider.serverProfiles.length, 1);
    });

    testWidgets(
      'health check failure exposes degraded and management actions',
      (WidgetTester tester) async {
        await _setLargeSurface(tester);
        var completed = false;
        await tester.pumpWidget(
          buildWizard(onComplete: () => completed = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect to a running server'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'http://127.0.0.1:1',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Test connection'));
        await tester.tap(find.text('Test connection'));
        await _waitForReadyFailure(tester);

        expect(find.text('Connection issue'), findsWidgets);
        expect(find.text('Start using CodeWalk'), findsOneWidget);
        expect(find.text('Add Server'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('View setup debug'), findsOneWidget);
        expect(appProvider.serverProfiles.length, 1);

        await tester.ensureVisible(
          find.byKey(const ValueKey('continue_with_unhealthy_server_button')),
        );
        await tester.tap(
          find.byKey(const ValueKey('continue_with_unhealthy_server_button')),
        );
        await _waitForCondition(tester, () => completed);

        expect(completed, isTrue);
      },
    );

    testWidgets(
      'add another server after health failure keeps the failed profile',
      (WidgetTester tester) async {
        await _setLargeSurface(tester);
        await tester.pumpWidget(buildWizard());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect to a running server'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'http://127.0.0.1:1',
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Test connection'));
        await tester.tap(find.text('Test connection'));
        await _waitForReadyFailure(tester);

        expect(appProvider.serverProfiles.length, 1);

        await tester.ensureVisible(find.text('Add Server'));
        await tester.tap(find.text('Add Server'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('step_server_setup')), findsOneWidget);
        expect(appProvider.serverProfiles.length, 1);

        final urlField = tester.widget<TextFormField>(
          find.byType(TextFormField).first,
        );
        final expectedDefaultUrl =
            defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:4096'
            : 'http://127.0.0.1:4096';
        expect(urlField.controller?.text, expectedDefaultUrl);
      },
    );

    testWidgets(
      'try again re-checks health instead of adding duplicate server',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildWizard());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Connect to a running server'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Test connection'));
        await tester.tap(find.text('Test connection'));
        await tester.runAsync(() async {
          // Keep a margin above the injected health timeout.
          await Future<void>.delayed(const Duration(milliseconds: 180));
        });
        await tester.pump();

        // Server was added.
        expect(appProvider.serverProfiles.length, 1);

        // If step 2 shows "Try again", use it.
        if (find.text('Try again').evaluate().isNotEmpty) {
          await tester.tap(find.text('Try again'));
          await tester.pump();

          // Back on step 1, tap "Test connection" again.
          if (find.text('Test connection').evaluate().isNotEmpty) {
            await tester.ensureVisible(find.text('Test connection'));
            await tester.tap(find.text('Test connection'));
            await tester.runAsync(() async {
              // Keep a margin above the injected health timeout.
              await Future<void>.delayed(const Duration(milliseconds: 180));
            });
            await tester.pump();
          }

          // Should NOT have added a duplicate server.
          expect(appProvider.serverProfiles.length, 1);
        }
      },
    );
  });

  testWidgets('managed local setup opens separate setup debug page', (
    WidgetTester tester,
  ) async {
    await _setLargeSurface(tester);

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
        recommendation: 'Use Existing OpenCode',
      ),
    );
    final managedProvider = AppProvider(
      getAppInfo: GetAppInfo(FakeAppRepository()),
      checkConnection: CheckConnection(FakeAppRepository()),
      localDataSource: localDataSource,
      dioClient: DioClient(),
      localServerRuntime: localServerRuntime,
      enableHealthPolling: false,
    );
    await managedProvider.initialize();

    await tester.pumpWidget(
      buildWizard(
        providerOverride: managedProvider,
        initialFlow: SetupWizardInitialFlow.managedLocalServer,
        showSkipAction: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('open_code_setup_debug_button_local')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('open_code_setup_debug_button_local')),
    );
    await tester.tap(
      find.byKey(const ValueKey('open_code_setup_debug_button_local')),
    );
    await tester.pumpAndSettle();

    expect(find.text('OpenCode Setup Debug'), findsOneWidget);
  });

  group('managed local first-run completion', () {
    testWidgets('requires a running server and completes through Ready', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      var completed = false;
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
      );
      final managedProvider = await createManagedProvider(localServerRuntime);

      await tester.pumpWidget(
        buildWizard(
          providerOverride: managedProvider,
          onComplete: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_local_setup')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
        findsNothing,
      );
      expect(completed, isFalse);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start'));
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_ready_success')), findsOneWidget);
      expect(
        managedProvider.localServerStatus,
        LocalServerRuntimeStatus.running,
      );
      expect(managedProvider.activeServer?.url, 'http://127.0.0.1:4096');
      expect(settingsProvider.pendingPostOnboardingChatTour, isFalse);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Start using CodeWalk'),
      );
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(settingsProvider.pendingPostOnboardingChatTour, isTrue);
    });

    testWidgets('keeps failed managed startup in the local setup step', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      var completed = false;
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
        startResult: const LocalOpencodeServerStartResult(
          ok: false,
          errorMessage: 'opencode command was not found',
        ),
      );
      final managedProvider = await createManagedProvider(localServerRuntime);

      await tester.pumpWidget(
        buildWizard(
          providerOverride: managedProvider,
          onComplete: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start'));
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_local_setup')), findsOneWidget);
      expect(find.text('opencode command was not found'), findsWidgets);
      expect(managedProvider.serverProfiles, isEmpty);
      expect(settingsProvider.pendingPostOnboardingChatTour, isFalse);
      expect(completed, isFalse);
    });

    testWidgets('already running managed server can continue to Ready', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
      );
      final managedProvider = await createManagedProvider(localServerRuntime);
      expect(await managedProvider.startLocalServer(), isTrue);

      await tester.pumpWidget(buildWizard(providerOverride: managedProvider));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.tap(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_ready_success')), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_local_setup')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
        findsOneWidget,
      );
    });

    testWidgets('does not complete after managed server exits from Ready', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      var completed = false;
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
      );
      final managedProvider = await createManagedProvider(localServerRuntime);
      expect(await managedProvider.startLocalServer(), isTrue);

      await tester.pumpWidget(
        buildWizard(
          providerOverride: managedProvider,
          onComplete: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.tap(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('step_ready_success')), findsOneWidget);

      localServerRuntime.emitExit(1);
      await tester.pumpAndSettle();
      expect(
        managedProvider.localServerStatus,
        LocalServerRuntimeStatus.failed,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Start using CodeWalk'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_local_setup')), findsOneWidget);
      expect(settingsProvider.pendingPostOnboardingChatTour, isFalse);
      expect(completed, isFalse);
    });

    testWidgets('pending managed start does not override later navigation', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      final localServerRuntime = _DelayedLocalOpencodeServerRuntime();
      final managedProvider = await createManagedProvider(localServerRuntime);

      await tester.pumpWidget(buildWizard(providerOverride: managedProvider));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start'));
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pump();

      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('step_welcome')), findsOneWidget);

      localServerRuntime.finishStart();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('step_welcome')), findsOneWidget);
      expect(find.byKey(const ValueKey('step_ready_success')), findsNothing);
    });

    testWidgets('serializes Ready completion while tour state persists', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      var completionCount = 0;
      final delayedDataSource = _DelayedExperienceSettingsDataSource();
      localDataSource = delayedDataSource;
      settingsProvider.dispose();
      settingsProvider = SettingsProvider(
        localDataSource: localDataSource,
        dioClient: DioClient(),
        soundService: SoundService(),
      );
      await settingsProvider.initialize();
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
      );
      final managedProvider = await createManagedProvider(localServerRuntime);
      expect(await managedProvider.startLocalServer(), isTrue);

      await tester.pumpWidget(
        buildWizard(
          providerOverride: managedProvider,
          onComplete: () => completionCount += 1,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('first_run_primary_setup_action')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.tap(
        find.byKey(const ValueKey('first_run_managed_continue_to_ready')),
      );
      await tester.pumpAndSettle();

      delayedDataSource.delayNextSave();
      final readyAction = find.widgetWithText(
        FilledButton,
        'Start using CodeWalk',
      );
      await tester.tap(readyAction);
      await tester.pump();

      expect(tester.widget<FilledButton>(readyAction).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Choose another path'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pump();
      expect(find.byKey(const ValueKey('step_ready_success')), findsOneWidget);
      expect(completionCount, 0);

      delayedDataSource.finishSave();
      await tester.pumpAndSettle();

      expect(completionCount, 1);
      expect(settingsProvider.pendingPostOnboardingChatTour, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      settingsProvider.dispose();
    });

    testWidgets('settings completion does not arm the chat tour', (
      WidgetTester tester,
    ) async {
      await _setLargeSurface(tester);
      var completed = false;
      final localServerRuntime = FakeLocalOpencodeServerRuntime(
        supported: true,
      );
      final managedProvider = await createManagedProvider(localServerRuntime);

      await tester.pumpWidget(
        buildWizard(
          providerOverride: managedProvider,
          initialFlow: SetupWizardInitialFlow.managedLocalServer,
          showSkipAction: false,
          onComplete: () => completed = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(settingsProvider.pendingPostOnboardingChatTour, isFalse);
    });
  });

  group('oauth toggle', () {
    testWidgets('shows OAuth toggle on supported platform', (
      WidgetTester tester,
    ) async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          buildWizard(initialFlow: SetupWizardInitialFlow.connectServer),
        );
        await tester.pumpAndSettle();

        // Navigate to the server URL form.
        if (find.text('Continue to server URL').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continue to server URL'));
          await tester.pumpAndSettle();
        }

        expect(find.text('Use OAuth (Cloudflare Access)'), findsOneWidget);
        expect(
          find.text('Opens a browser for Cloudflare Access Managed OAuth.'),
          findsOneWidget,
        );
        expect(find.text('Use Basic Auth'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    testWidgets('toggling OAuth disables Basic Auth and vice versa', (
      WidgetTester tester,
    ) async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          buildWizard(initialFlow: SetupWizardInitialFlow.connectServer),
        );
        await tester.pumpAndSettle();

        if (find.text('Continue to server URL').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continue to server URL'));
          await tester.pumpAndSettle();
        }

        Finder authSwitch(String title) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(SwitchListTile),
          ),
          matching: find.byType(Switch),
        );
        final oauthSwitch = authSwitch('Use OAuth (Cloudflare Access)');
        final basicSwitch = authSwitch('Use Basic Auth');

        await tester.ensureVisible(oauthSwitch);
        await tester.pumpAndSettle();
        await tester.tap(oauthSwitch);
        await tester.pumpAndSettle();

        expect(find.text('Username'), findsNothing);

        await tester.ensureVisible(basicSwitch);
        await tester.pumpAndSettle();
        await tester.tap(basicSwitch);
        await tester.pumpAndSettle();

        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    testWidgets('shows unsupported message when OAuth not available', (
      WidgetTester tester,
    ) async {
      final previous = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          buildWizard(initialFlow: SetupWizardInitialFlow.connectServer),
        );
        await tester.pumpAndSettle();

        if (find.text('Continue to server URL').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continue to server URL'));
          await tester.pumpAndSettle();
        }

        expect(
          find.text(
            'Cloudflare Access OAuth is not available on this platform. '
            'Use Basic Auth instead.',
          ),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });

    testWidgets('OAuth subtitle updates based on platform support', (
      WidgetTester tester,
    ) async {
      final previous = debugDefaultTargetPlatformOverride;
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await tester.pumpWidget(
          buildWizard(initialFlow: SetupWizardInitialFlow.connectServer),
        );
        await tester.pumpAndSettle();

        if (find.text('Continue to server URL').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continue to server URL'));
          await tester.pumpAndSettle();
        }

        expect(
          find.text('Opens a browser for Cloudflare Access Managed OAuth.'),
          findsOneWidget,
        );

        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        await tester.pumpWidget(
          buildWizard(initialFlow: SetupWizardInitialFlow.connectServer),
        );
        await tester.pumpAndSettle();

        if (find.text('Continue to server URL').evaluate().isNotEmpty) {
          await tester.tap(find.text('Continue to server URL'));
          await tester.pumpAndSettle();
        }

        expect(
          find.text('Opens a browser for Cloudflare Access Managed OAuth.'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = previous;
      }
    });
  });

  group('back navigation', () {
    testWidgets('back from step 1 returns to welcome', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWizard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect to a running server'));
      await tester.pumpAndSettle();
      expect(find.text('Server connection'), findsOneWidget);

      // Tap back arrow.
      await tester.tap(find.byIcon(Symbols.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to CodeWalk'), findsOneWidget);
    });
  });
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _waitForReadyFailure(WidgetTester tester) async {
  final failure = find.byKey(const ValueKey('step_ready_failed'));
  for (var attempt = 0; attempt < 30; attempt++) {
    if (failure.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() predicate,
) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (predicate()) {
      await tester.pump();
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
}
