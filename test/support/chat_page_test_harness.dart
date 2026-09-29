import 'dart:async';
import 'dart:convert';

import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/data/datasources/app_local_datasource.dart';
import 'package:codewalk/data/datasources/quota_remote_datasource.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/abort_chat_session.dart';
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
import 'package:codewalk/domain/usecases/revert_chat_message.dart';
import 'package:codewalk/domain/usecases/send_chat_message.dart';
import 'package:codewalk/domain/usecases/share_chat_session.dart';
import 'package:codewalk/domain/usecases/unrevert_chat_messages.dart';
import 'package:codewalk/domain/usecases/unshare_chat_session.dart';
import 'package:codewalk/domain/usecases/update_chat_session.dart';
import 'package:codewalk/domain/usecases/watch_chat_events.dart';
import 'package:codewalk/domain/usecases/watch_global_chat_events.dart';
import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/quota_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/cellular_data_saver_service.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/workspace_file_operations_service.dart';
import 'package:codewalk/presentation/theme/app_theme.dart';
import 'package:codewalk/presentation/widgets/desktop_window_title_bar.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import '../unit/providers/chat_provider_test_support.dart' show testModel;
import 'fakes.dart';
import 'pump_localized_app.dart';

Widget buildChatPageTestApp(
  ChatProvider provider,
  AppProvider appProvider, {
  SettingsProvider? settingsProvider,
  QuotaProvider? quotaProvider,
  QuotaRemoteDataSource? quotaRemoteDataSource,
  CellularDataSaverService? cellularDataSaverService,
  WorkspaceFileOperationsService? fileOperationsService,
  MediaQueryData? mediaQueryData,
  bool integratedWindowChrome = false,
  bool forwardSettingsNotifications = true,
}) {
  if (di.sl.isRegistered<AppLocalDataSource>()) {
    di.sl.unregister<AppLocalDataSource>();
  }
  di.sl.registerSingleton<AppLocalDataSource>(provider.localDataSource);
  if (di.sl.isRegistered<WorkspaceFileOperationsService>()) {
    di.sl.unregister<WorkspaceFileOperationsService>();
  }
  di.sl.registerSingleton<WorkspaceFileOperationsService>(
    fileOperationsService ?? FakeWorkspaceFileOperationsService(),
  );
  final effectiveSettingsProvider =
      settingsProvider ??
      SettingsProvider(
        localDataSource: provider.localDataSource,
        dioClient: DioClient(),
        soundService: SoundService(),
        cellularDataSaverService: cellularDataSaverService,
      );
  if (settingsProvider == null) {
    addTearDown(effectiveSettingsProvider.dispose);
    disableAutomaticUpdateChecksForTest(
      provider.localDataSource as InMemoryAppLocalDataSource,
    );
    unawaited(effectiveSettingsProvider.initialize());
  }
  final effectiveQuotaProvider =
      quotaProvider ??
      QuotaProvider(
        remoteDataSource: quotaRemoteDataSource ?? FakeQuotaRemoteDataSource(),
      );
  final desktopWindowChromeController = integratedWindowChrome
      ? DesktopWindowChromeController()
      : null;
  if (desktopWindowChromeController != null) {
    addTearDown(desktopWindowChromeController.dispose);
  }
  Widget home = const ChatPage();
  if (mediaQueryData != null) {
    home = MediaQuery(data: mediaQueryData, child: home);
  }
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: provider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: provider.projectProvider,
      ),
      if (forwardSettingsNotifications)
        ChangeNotifierProvider<SettingsProvider>.value(
          value: effectiveSettingsProvider,
        )
      else
        InheritedProvider<SettingsProvider>.value(
          value: effectiveSettingsProvider,
        ),
      ChangeNotifierProvider<QuotaProvider>.value(
        value: effectiveQuotaProvider,
      ),
      if (desktopWindowChromeController != null)
        ChangeNotifierProvider<DesktopWindowChromeController>.value(
          value: desktopWindowChromeController,
        ),
    ],
    child: localizedMaterialApp(
      theme: AppTheme.lightFrom(
        ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
      ),
      builder: integratedWindowChrome
          ? (context, child) => DesktopWindowChromeFrame(child: child!)
          : null,
      home: home,
    ),
  );
}

void disableAutomaticUpdateChecksForTest(InMemoryAppLocalDataSource source) {
  final raw = source.experienceSettingsJson;
  final settings = raw == null || raw.trim().isEmpty
      ? <String, dynamic>{}
      : (jsonDecode(raw) as Map).cast<String, dynamic>();
  settings['checkUpdatesOnOpen'] = false;
  settings['sessionTabsGestureHintDismissed'] = true;
  source.experienceSettingsJson = jsonEncode(settings);
}

ChatProvider buildChatPageProvider({
  FakeChatRepository? chatRepository,
  FakeProjectRepository? projectRepository,
  FakeAppRepository? appRepository,
  required InMemoryAppLocalDataSource localDataSource,
  CellularDataSaverService? cellularDataSaverService,
  bool includeVariants = false,
  ProvidersResponse? providersResponse,
}) {
  final chatRepo = chatRepository ?? FakeChatRepository();
  final appRepo = appRepository ?? FakeAppRepository();
  appRepo.providersResult = Right(
    providersResponse ??
        ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_1',
              name: 'Provider 1',
              env: const <String>[],
              models: <String, Model>{
                'model_1': testModel(
                  'model_1',
                  variants: includeVariants
                      ? const <String, ModelVariant>{
                          'low': ModelVariant(id: 'low', name: 'Low'),
                          'high': ModelVariant(id: 'high', name: 'High'),
                        }
                      : const <String, ModelVariant>{},
                ),
              },
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
    abortChatSession: AbortChatSession(chatRepo),
    listPendingPermissions: ListPendingPermissions(chatRepo),
    replyPermission: ReplyPermission(chatRepo),
    listPendingQuestions: ListPendingQuestions(chatRepo),
    replyQuestion: ReplyQuestion(chatRepo),
    rejectQuestion: RejectQuestion(chatRepo),
    revertChatMessage: RevertChatMessage(chatRepo),
    unrevertChatMessages: UnrevertChatMessages(chatRepo),
    projectProvider: ProjectProvider(
      projectRepository: projectRepository ?? FakeProjectRepository(),
      localDataSource: localDataSource,
    ),
    localDataSource: localDataSource,
    cellularDataSaverService: cellularDataSaverService,
    syncHealthCheckInterval: const Duration(milliseconds: 150),
    foregroundResumeSyncIndicatorDuration: const Duration(milliseconds: 250),
    foregroundResumeSyncIndicatorMaxCycles: 2,
    abortSuppressionWindow: const Duration(milliseconds: 500),
    sessionTabsPersistenceDebounce: Duration.zero,
  );
}

AppProvider buildChatPageAppProvider({
  required InMemoryAppLocalDataSource localDataSource,
  FakeAppRepository? appRepository,
  CellularDataSaverService? cellularDataSaverService,
}) {
  final activeId = localDataSource.activeServerId?.trim();
  final profiles = localDataSource.serverProfilesJson;
  if (activeId != null &&
      activeId.isNotEmpty &&
      (profiles == null || profiles.trim().isEmpty)) {
    localDataSource.defaultServerId ??= activeId;
    localDataSource.serverProfilesJson = jsonEncode(<Map<String, dynamic>>[
      {
        'id': activeId,
        'url': 'http://127.0.0.1:4096',
        'label': 'Test Server',
        'basicAuthEnabled': false,
        'basicAuthUsername': '',
        'basicAuthPassword': '',
        'createdAt': 0,
        'updatedAt': 0,
      },
    ]);
  }
  final repository = appRepository ?? FakeAppRepository();
  final provider = AppProvider(
    getAppInfo: GetAppInfo(repository),
    checkConnection: CheckConnection(repository),
    localDataSource: localDataSource,
    dioClient: DioClient(),
    cellularDataSaverService: cellularDataSaverService,
    enableHealthPolling: false,
  );
  unawaited(provider.initialize());
  return provider;
}
