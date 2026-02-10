import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
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
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPage responsive shell', () {
    testWidgets('shows drawer on mobile width', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
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
      final provider = _buildChatProvider(localDataSource: localDataSource);
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Desktop Shortcuts'), findsNothing);
    });

    testWidgets('shows utility pane on large desktop width', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(localDataSource: localDataSource);
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
    });
  });

  testWidgets('shows active directory and directory selector guidance', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: FakeProjectRepository(
        currentProject: Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_a',
            name: 'Project A',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      ),
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Choose Directory'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose Directory'));
    await tester.pumpAndSettle();

    expect(find.text('Current directory: /repo/a'), findsOneWidget);
    expect(find.text('Select a directory/workspace below'), findsOneWidget);
  });

  testWidgets('shows basename directory and compact controls on mobile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: FakeProjectRepository(
        currentProject: Project(
          id: 'proj_mobile',
          name: 'Project Mobile',
          path: '/repo/mobile-project',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_mobile',
            name: 'Project Mobile',
            path: '/repo/mobile-project',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      ),
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    expect(find.text('mobile-project'), findsOneWidget);
    expect(find.byTooltip('Focus Input'), findsNothing);

    await tester.tap(find.byTooltip('Choose Directory'));
    await tester.pumpAndSettle();
    expect(
      find.text('Current directory: /repo/mobile-project'),
      findsOneWidget,
    );
  });

  testWidgets('shows global label when current context is root', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: FakeProjectRepository(
        currentProject: Project(
          id: 'proj_root',
          name: '/',
          path: '/',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_root',
            name: '/',
            path: '/',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      ),
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Choose Directory'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose Directory'));
    await tester.pumpAndSettle();
    expect(find.text('Current directory: Global'), findsOneWidget);
  });

  testWidgets('create workspace allows overriding base directory', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_a',
        name: 'Project A',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_a',
          name: 'Project A',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: projectRepository,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose Directory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create workspace in directory...'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('workspace_name_input')),
      'Feature API',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('workspace_base_directory_input')),
      '/repo/custom',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(projectRepository.lastCreatedWorktreeName, 'Feature API');
    expect(projectRepository.lastCreatedWorktreeDirectory, '/repo/custom');
    expect(
      find.text('Workspace created in /repo/custom: Feature API'),
      findsOneWidget,
    );
  });

  testWidgets('sends message from chat input and renders assistant response', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_1',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Session 1',
        ),
      ],
    );

    repository.sendMessageHandler = (_, sessionId, __, ___) {
      final reply = AssistantMessage(
        id: 'msg_assistant_widget',
        sessionId: sessionId,
        time: DateTime.fromMillisecondsSinceEpoch(2000),
        completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
        parts: const <MessagePart>[
          TextPart(
            id: 'prt_widget_reply',
            messageId: 'msg_assistant_widget',
            sessionId: 'ses_1',
            text: 'ok from widget',
          ),
        ],
      );
      return Stream<Either<Failure, ChatMessage>>.value(Right(reply));
    };

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pump(const Duration(milliseconds: 150));

    await provider.loadSessions();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Session 1').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'hello from widget');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.lastSendInput, isNotNull);
    expect(find.text('hello from widget'), findsOneWidget);
    expect(find.text('ok from widget'), findsOneWidget);
  });

  testWidgets('shows model selector with search and quick reasoning selector', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_1',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Session 1',
        ),
      ],
    );

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
      includeVariants: true,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const ValueKey<String>('model_selector_button')),
      findsOneWidget,
    );
    expect(find.text('model_1'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('model_selector_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search model or provider'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('model_selector_provider_header_provider_1'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search model or provider'),
      'missing-model',
    );
    await tester.pumpAndSettle();
    expect(find.text('No models found'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('variant_selector_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('variant_selector_option_low')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Low'), findsOneWidget);
  });

  testWidgets(
    'model selector shows top 3 recent models and alphabetical providers',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final recentModelsJson = jsonEncode(<String>[
        'provider_a/model_a3',
        'provider_z/model_z2',
        'provider_a/model_a2',
      ]);
      localDataSource.recentModelsJson = recentModelsJson;
      for (final serverId in <String>['srv_test', 'legacy']) {
        for (final scopeId in <String>['/tmp', 'default']) {
          await localDataSource.saveRecentModelsJson(
            recentModelsJson,
            serverId: serverId,
            scopeId: scopeId,
          );
        }
      }

      final provider = _buildChatProvider(
        localDataSource: localDataSource,
        providersResponse: ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_z',
              name: 'Zulu Provider',
              env: const <String>[],
              models: <String, Model>{
                'model_z1': _model('model_z1', name: 'Z1'),
                'model_z2': _model('model_z2', name: 'Z2'),
              },
            ),
            Provider(
              id: 'provider_a',
              name: 'Alpha Provider',
              env: const <String>[],
              models: <String, Model>{
                'model_a1': _model('model_a1', name: 'A1'),
                'model_a2': _model('model_a2', name: 'A2'),
                'model_a3': _model('model_a3', name: 'A3'),
              },
            ),
          ],
          defaultModels: const <String, String>{'provider_a': 'model_a1'},
          connected: const <String>['provider_a', 'provider_z'],
        ),
      );
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();
      final scopedServerId =
          await localDataSource.getActiveServerId() ?? 'legacy';
      final scopedScopeId =
          provider.projectProvider.currentDirectory ??
          provider.projectProvider.currentProjectId;
      await localDataSource.saveRecentModelsJson(
        recentModelsJson,
        serverId: scopedServerId,
        scopeId: scopedScopeId,
      );
      await provider.initializeProviders();
      await tester.pumpAndSettle();
      expect(provider.recentModelKeys, isNotEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('model_selector_recent_header')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('model_selector_recent_provider_a_model_a3'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('model_selector_recent_provider_z_model_z2'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('model_selector_recent_provider_a_model_a2'),
        ),
        findsOneWidget,
      );

      final alphaDy = tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>(
                'model_selector_provider_header_provider_a',
              ),
            ),
          )
          .dy;
      final zuluDy = tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>(
                'model_selector_provider_header_provider_z',
              ),
            ),
          )
          .dy;
      expect(alphaDy, lessThan(zuluDy));
    },
  );

  testWidgets('opens conversation at latest message and toggles jump FAB', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_scroll',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Scrollable Session',
        ),
      ],
    );
    repository.messagesBySession['ses_scroll'] = _threadMessages(
      'ses_scroll',
      40,
    );

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pumpAndSettle();

    expect(find.text('message 39'), findsOneWidget);
    expect(find.byTooltip('Go to latest message'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey<String>('chat_message_list')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Go to latest message'), findsOneWidget);

    await tester.tap(find.byTooltip('Go to latest message'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Go to latest message'), findsNothing);
    expect(find.text('message 39'), findsOneWidget);
  });

  testWidgets('highlights jump FAB when new messages arrive below viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_live',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Live Session',
        ),
      ],
    );
    repository.messagesBySession['ses_live'] = _threadMessages('ses_live', 40);

    final streamController = StreamController<Either<Failure, ChatMessage>>();
    addTearDown(() async {
      await streamController.close();
    });
    repository.sendMessageHandler = (_, __, ___, ____) =>
        streamController.stream;

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await provider.initializeProviders();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey<String>('chat_message_list')),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();

    final fabFinder = find.byKey(const ValueKey<String>('jump_to_latest_fab'));
    expect(fabFinder, findsOneWidget);
    expect(
      find.descendant(
        of: fabFinder,
        matching: find.byIcon(Icons.arrow_downward_rounded),
      ),
      findsOneWidget,
    );

    await provider.sendMessage('trigger streaming reply');
    await tester.pump();

    streamController.add(
      Right(
        AssistantMessage(
          id: 'msg_stream_1',
          sessionId: 'ses_live',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_stream_1',
              messageId: 'msg_stream_1',
              sessionId: 'ses_live',
              text: 'live response',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: fabFinder,
        matching: find.byIcon(Icons.mark_chat_unread_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Go to latest message'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mark_chat_unread_outlined), findsNothing);
  });
}

Widget _testApp(ChatProvider provider, AppProvider appProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: provider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: provider.projectProvider,
      ),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

ChatProvider _buildChatProvider({
  FakeChatRepository? chatRepository,
  FakeProjectRepository? projectRepository,
  required InMemoryAppLocalDataSource localDataSource,
  bool includeVariants = false,
  ProvidersResponse? providersResponse,
}) {
  final chatRepo = chatRepository ?? FakeChatRepository();
  final appRepo = FakeAppRepository()
    ..providersResult = Right(
      providersResponse ??
          ProvidersResponse(
            providers: <Provider>[
              Provider(
                id: 'provider_1',
                name: 'Provider 1',
                env: const <String>[],
                models: <String, Model>{
                  'model_1': _model(
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
      projectRepository: projectRepository ?? FakeProjectRepository(),
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

Model _model(
  String id, {
  String? name,
  Map<String, ModelVariant> variants = const <String, ModelVariant>{},
}) {
  return Model(
    id: id,
    name: name ?? id,
    releaseDate: '2025-01-01',
    attachment: false,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
    variants: variants,
  );
}

List<ChatMessage> _threadMessages(String sessionId, int count) {
  return List<ChatMessage>.generate(count, (index) {
    final messageId = 'msg_${sessionId}_$index';
    return UserMessage(
      id: messageId,
      sessionId: sessionId,
      time: DateTime.fromMillisecondsSinceEpoch(index * 1000),
      parts: <MessagePart>[
        TextPart(
          id: 'part_${sessionId}_$index',
          messageId: messageId,
          sessionId: sessionId,
          text: 'message $index',
        ),
      ],
    );
  });
}
