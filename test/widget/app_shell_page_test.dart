import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/i18n/app_locales.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/datasources/app_local_datasource.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_chat_sessions.dart';
import 'package:codewalk/domain/usecases/get_providers.dart';
import 'package:codewalk/domain/usecases/get_session_children.dart';
import 'package:codewalk/domain/usecases/get_session_diff.dart';
import 'package:codewalk/domain/usecases/get_session_status.dart';
import 'package:codewalk/domain/usecases/get_session_todo.dart';
import 'package:codewalk/domain/usecases/list_pending_permissions.dart';
import 'package:codewalk/domain/usecases/list_pending_questions.dart';
import 'package:codewalk/domain/usecases/reject_question.dart';
import 'package:codewalk/domain/usecases/reply_permission.dart';
import 'package:codewalk/domain/usecases/reply_question.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/l10n/generated/app_localizations.dart';
import 'package:codewalk/presentation/pages/app_shell_page.dart';
import 'package:codewalk/presentation/pages/onboarding_wizard_page.dart';
import 'package:codewalk/presentation/pages/settings_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/locale_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/update_check_service.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart' hide Provider;

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders chat as the primary root screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test'
      ..defaultServerId = 'srv_test'
      ..serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'srv_test',
          'url': 'http://127.0.0.1:4096',
          'label': 'Test Server',
          'basicAuthEnabled': false,
          'basicAuthUsername': '',
          'basicAuthPassword': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ]);
    await tester.pumpWidget(
      _testApp(
        _buildChatProvider(localDataSource: localDataSource),
        _buildAppProvider(localDataSource: localDataSource),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Conversations'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sidebar_settings_icon_button')),
      findsOneWidget,
    );
  });

  testWidgets('opens logs directly from settings and returns via back arrow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test'
      ..defaultServerId = 'srv_test'
      ..serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'srv_test',
          'url': 'http://127.0.0.1:4096',
          'label': 'Test Server',
          'basicAuthEnabled': false,
          'basicAuthUsername': '',
          'basicAuthPassword': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ]);
    await tester.pumpWidget(
      _testApp(
        _buildChatProvider(localDataSource: localDataSource),
        _buildAppProvider(localDataSource: localDataSource),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar_settings_icon_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logs').first);
    await tester.pumpAndSettle();

    expect(find.text('App Logs'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Logs'), findsOneWidget);
  });

  testWidgets(
    'opens settings from sidebar and returns to chat via back arrow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test'
        ..defaultServerId = 'srv_test'
        ..serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'srv_test',
            'url': 'http://127.0.0.1:4096',
            'label': 'Test Server',
            'basicAuthEnabled': false,
            'basicAuthUsername': '',
            'basicAuthPassword': '',
            'createdAt': 0,
            'updatedAt': 0,
          },
        ]);
      await tester.pumpWidget(
        _testApp(
          _buildChatProvider(localDataSource: localDataSource),
          _buildAppProvider(localDataSource: localDataSource),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('sidebar_settings_icon_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Conversations'), findsOneWidget);
    },
  );

  testWidgets('desktop install flow shows installing and restart snackbars', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test'
      ..defaultServerId = 'srv_test'
      ..serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'srv_test',
          'url': 'http://127.0.0.1:4096',
          'label': 'Test Server',
          'basicAuthEnabled': false,
          'basicAuthUsername': '',
          'basicAuthPassword': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ]);
    final settingsProvider = SettingsProvider(
      localDataSource: localDataSource,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settingsProvider.initialize();
    await settingsProvider.setCheckUpdatesOnOpen(false);
    addTearDown(settingsProvider.dispose);

    await tester.pumpWidget(
      _testAppWithSettings(
        _buildChatProvider(localDataSource: localDataSource),
        _buildAppProvider(localDataSource: localDataSource),
        settingsProvider,
      ),
    );
    await tester.pumpAndSettle();

    settingsProvider.debugSetInstallStateForTesting(
      UpdateInstallState.installing,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Installing update...'), findsOneWidget);

    settingsProvider.debugSetInstallStateForTesting(UpdateInstallState.done);
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'Update installed. Restart is required to apply the new version.',
      ),
      findsOneWidget,
    );
    expect(find.text('Restart'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    debugDefaultTargetPlatformOverride = previousPlatform;
  });

  testWidgets(
    'startup update toast uses release fallback when install unsupported',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      ChatProvider? chatProvider;
      AppProvider? appProvider;
      SettingsProvider? settingsProvider;
      try {
        PackageInfo.setMockInitialValues(
          appName: 'CodeWalk',
          packageName: 'com.verseles.codewalk',
          version: '1.2.3',
          buildNumber: '45',
          buildSignature: '',
        );

        final localDataSource = InMemoryAppLocalDataSource()
          ..experienceSettingsJson = jsonEncode(<String, dynamic>{
            'checkUpdatesOnOpen': true,
            'skipOnboardingWizard': true,
          });
        settingsProvider = SettingsProvider(
          localDataSource: localDataSource,
          dioClient: _NoopDioClient(),
          soundService: SoundService(),
          updateCheckService: _FakeUpdateCheckService(
            const UpdateCheckResult(
              latestVersion: '1.3.0',
              releaseUrl:
                  'https://github.com/verseles/codewalk/releases/tag/v1.3.0',
              isNewer: true,
            ),
          ),
        );
        await settingsProvider.initialize();
        chatProvider = _buildChatProvider(localDataSource: localDataSource);
        appProvider = _buildAppProvider(
          localDataSource: localDataSource,
          dioClient: _NoopDioClient(),
        );

        await tester.pumpWidget(
          _testAppWithSettings(chatProvider, appProvider, settingsProvider),
        );
        await tester.pump();
        for (
          var i = 0;
          i < 10 && find.text('Update available: v1.3.0').evaluate().isEmpty;
          i += 1
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('Update available: v1.3.0'), findsOneWidget);
        expect(find.text('Install'), findsNothing);
        expect(find.text('GitHub'), findsOneWidget);
      } finally {
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        chatProvider?.dispose();
        appProvider?.dispose();
        settingsProvider?.dispose();
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    },
  );

  testWidgets(
    'keeps onboarding mounted after server add until the wizard is explicitly completed',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource();
      await tester.pumpWidget(
        _testApp(
          _buildChatProvider(localDataSource: localDataSource),
          _buildAppProvider(localDataSource: localDataSource),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to CodeWalk'), findsOneWidget);

      await tester.tap(find.text('Connect to a running server'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Test connection'));
      await tester.tap(find.text('Test connection'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      });
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingWizardPage), findsOneWidget);
      expect(find.byKey(const ValueKey('step_server_setup')), findsNothing);
      expect(find.text('Connection issue'), findsWidgets);
      expect(find.text('Try again'), findsOneWidget);
      expect(localDataSource.serverProfilesJson, isNotNull);
      expect(find.text('Conversations'), findsNothing);
    },
  );

  testWidgets('settings controls update live under the full shell topology', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test'
      ..defaultServerId = 'srv_test'
      ..experienceSettingsJson = '{"checkUpdatesOnOpen": false}'
      ..serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'srv_test',
          'url': 'http://127.0.0.1:4096',
          'label': 'Test Server',
          'basicAuthEnabled': false,
          'basicAuthUsername': '',
          'basicAuthPassword': '',
          'createdAt': 0,
          'updatedAt': 0,
        },
      ]);
    final chatProvider = _buildChatProvider(localDataSource: localDataSource);
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    final settingsProvider = SettingsProvider(
      localDataSource: chatProvider.localDataSource,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    unawaited(settingsProvider.initialize());
    addTearDown(settingsProvider.dispose);

    final localeProvider = LocaleProvider(
      settingsProvider: settingsProvider,
    );
    unawaited(localeProvider.initialize());
    addTearDown(localeProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ChangeNotifierProvider<ProjectProvider>.value(
            value: chatProvider.projectProvider,
          ),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settingsProvider,
          ),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocales.supported,
          theme: AppTheme.lightFrom(
            ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
          ).copyWith(splashFactory: InkRipple.splashFactory),
          home: const AppShellPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar_settings_icon_button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();

    final tipsToggle = find.byKey(
      const ValueKey<String>('settings_toggle_composer_tips'),
    );
    await tester.scrollUntilVisible(
      tipsToggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final before = tester.widget<SwitchListTile>(tipsToggle).value;
    await tester.tap(tipsToggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tipsToggle).value, isNot(before));
    expect(settingsProvider.showComposerTips, isNot(before));
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}

class _FakeUpdateCheckService extends UpdateCheckService {
  _FakeUpdateCheckService(this.result);

  final UpdateCheckResult? result;

  @override
  Future<UpdateCheckResult?> check(String currentVersion) async => result;
}

class _NoopDioClient extends DioClient {
  _NoopDioClient() : super(baseUrl: 'http://localhost');

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{} as T,
    );
  }
}

Widget _testApp(ChatProvider chatProvider, AppProvider appProvider) {
  if (di.sl.isRegistered<AppLocalDataSource>()) {
    di.sl.unregister<AppLocalDataSource>();
  }
  di.sl.registerSingleton<AppLocalDataSource>(chatProvider.localDataSource);

  final localDataSource =
      chatProvider.localDataSource as InMemoryAppLocalDataSource;
  final rawSettings = localDataSource.experienceSettingsJson;
  final settingsJson = rawSettings == null || rawSettings.trim().isEmpty
      ? <String, dynamic>{}
      : (jsonDecode(rawSettings) as Map).cast<String, dynamic>();
  settingsJson['checkUpdatesOnOpen'] = false;
  localDataSource.experienceSettingsJson = jsonEncode(settingsJson);

  final settingsProvider = SettingsProvider(
    localDataSource: chatProvider.localDataSource,
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  unawaited(settingsProvider.initialize());
  addTearDown(settingsProvider.dispose);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: chatProvider.projectProvider,
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocales.supported,
      theme: AppTheme.lightFrom(
        ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
      ).copyWith(splashFactory: InkRipple.splashFactory),
      home: const AppShellPage(),
    ),
  );
}

Widget _testAppWithSettings(
  ChatProvider chatProvider,
  AppProvider appProvider,
  SettingsProvider settingsProvider,
) {
  if (di.sl.isRegistered<AppLocalDataSource>()) {
    di.sl.unregister<AppLocalDataSource>();
  }
  di.sl.registerSingleton<AppLocalDataSource>(chatProvider.localDataSource);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: chatProvider.projectProvider,
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocales.supported,
      theme: AppTheme.lightFrom(
        ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
      ).copyWith(splashFactory: InkRipple.splashFactory),
      home: const AppShellPage(),
    ),
  );
}

ChatProvider _buildChatProvider({
  required InMemoryAppLocalDataSource localDataSource,
}) {
  final chatRepo = FakeChatRepository();
  final appRepo = FakeAppRepository()
    ..providersResult = Right(
      ProvidersResponse(
        providers: <Provider>[
          Provider(
            id: 'provider_1',
            name: 'Provider 1',
            env: const <String>[],
            models: <String, Model>{'model_1': _model('model_1')},
          ),
        ],
        defaultModels: const <String, String>{'provider_1': 'model_1'},
        connected: const <String>['provider_1'],
      ),
    );

  return ChatProvider(
    sendChatMessage: SendChatMessage(chatRepo),
    getChatSessions: GetChatSessions(chatRepo),
    createChatSession: CreateChatSession(chatRepo),
    getChatMessages: GetChatMessages(chatRepo),
    getChatMessage: GetChatMessage(chatRepo),
    getAgents: GetAgents(appRepo),
    getProviders: GetProviders(appRepo),
    deleteChatSession: DeleteChatSession(chatRepo),
    updateChatSession: UpdateChatSession(chatRepo),
    shareChatSession: ShareChatSession(chatRepo),
    unshareChatSession: UnshareChatSession(chatRepo),
    forkChatSession: ForkChatSession(chatRepo),
    getSessionStatus: GetSessionStatus(chatRepo),
    getSessionChildren: GetSessionChildren(chatRepo),
    getSessionTodo: GetSessionTodo(chatRepo),
    getSessionDiff: GetSessionDiff(chatRepo),
    watchChatEvents: WatchChatEvents(chatRepo),
    watchGlobalChatEvents: WatchGlobalChatEvents(chatRepo),
    listPendingPermissions: ListPendingPermissions(chatRepo),
    replyPermission: ReplyPermission(chatRepo),
    listPendingQuestions: ListPendingQuestions(chatRepo),
    replyQuestion: ReplyQuestion(chatRepo),
    rejectQuestion: RejectQuestion(chatRepo),
    projectProvider: ProjectProvider(
      projectRepository: FakeProjectRepository(),
      localDataSource: localDataSource,
    ),
    localDataSource: localDataSource,
  );
}

AppProvider _buildAppProvider({
  required InMemoryAppLocalDataSource localDataSource,
  DioClient? dioClient,
  bool initialize = true,
}) {
  final repository = FakeAppRepository();
  final provider = AppProvider(
    getAppInfo: GetAppInfo(repository),
    checkConnection: CheckConnection(repository),
    localDataSource: localDataSource,
    dioClient: dioClient ?? DioClient(),
    enableHealthPolling: false,
  );
  if (initialize) {
    unawaited(provider.initialize());
  }
  return provider;
}

Model _model(String id) {
  return Model(
    id: id,
    name: id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
  );
}
