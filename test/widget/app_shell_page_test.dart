import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/get_app_info.dart';
import 'package:codewalk/domain/usecases/get_chat_message.dart';
import 'package:codewalk/domain/usecases/get_chat_messages.dart';
import 'package:codewalk/domain/usecases/get_agents.dart';
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
import 'package:codewalk/presentation/pages/app_shell_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders chat as the primary root screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
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
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('opens logs from sidebar and returns to chat via back arrow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    await tester.pumpWidget(
      _testApp(
        _buildChatProvider(localDataSource: localDataSource),
        _buildAppProvider(localDataSource: localDataSource),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logs'));
    await tester.pumpAndSettle();

    expect(find.text('App Logs'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Conversations'), findsOneWidget);
  });

  testWidgets(
    'opens settings from sidebar and returns to chat via back arrow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      await tester.pumpWidget(
        _testApp(
          _buildChatProvider(localDataSource: localDataSource),
          _buildAppProvider(localDataSource: localDataSource),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Conversations'), findsOneWidget);
    },
  );
}

Widget _testApp(ChatProvider chatProvider, AppProvider appProvider) {
  final settingsProvider = SettingsProvider(
    localDataSource: chatProvider.localDataSource,
    soundService: SoundService(),
  );
  unawaited(settingsProvider.initialize());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: chatProvider.projectProvider,
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: MaterialApp(home: const AppShellPage()),
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
}) {
  final repository = FakeAppRepository();
  final provider = AppProvider(
    getAppInfo: GetAppInfo(repository),
    checkConnection: CheckConnection(repository),
    localDataSource: localDataSource,
    dioClient: DioClient(),
    enableHealthPolling: false,
  );
  unawaited(provider.initialize());
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
