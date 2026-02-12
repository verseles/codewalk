import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;
import 'package:simple_icons/simple_icons.dart';

import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/domain/entities/agent.dart';
import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/domain/entities/chat_realtime.dart';
import 'package:codewalk/domain/entities/chat_session.dart';
import 'package:codewalk/domain/entities/file_node.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/domain/entities/provider.dart';
import 'package:codewalk/domain/usecases/check_connection.dart';
import 'package:codewalk/domain/usecases/create_chat_session.dart';
import 'package:codewalk/domain/usecases/delete_chat_session.dart';
import 'package:codewalk/domain/usecases/fork_chat_session.dart';
import 'package:codewalk/domain/usecases/abort_chat_session.dart';
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
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:codewalk/presentation/providers/app_provider.dart';
import 'package:codewalk/presentation/providers/chat_provider.dart';
import 'package:codewalk/presentation/providers/project_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/utils/session_title_formatter.dart';

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

    testWidgets('delays hamburger alert badge during initial server issues', (
      WidgetTester tester,
    ) async {
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

      appProvider.reset();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('appbar_drawer_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('appbar_drawer_alert_badge')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('appbar_drawer_alert_badge')),
        findsNothing,
      );
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

    testWidgets('desktop sidebars can be hidden and restored from menu', (
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

      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('hide_conversations_sidebar_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conversations'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('desktop_sidebars_menu_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('desktop_sidebar_menu_item_conversations'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conversations'), findsOneWidget);
    });

    testWidgets('mobile app bar opens files dialog in fullscreen', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(localDataSource: localDataSource);
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('appbar_quick_open_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('mobile_files_dialog_fullscreen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('file_tree_quick_open_button')),
        findsOneWidget,
      );
    });

    testWidgets('applies compact app bar toolbar heights', (
      WidgetTester tester,
    ) async {
      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(localDataSource: localDataSource);
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.binding.setSurfaceSize(const Size(1000, 900));
      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      final desktopAppBar = tester.widget<AppBar>(find.byType(AppBar).first);
      expect(desktopAppBar.toolbarHeight, 48);

      await tester.binding.setSurfaceSize(const Size(700, 900));
      await tester.pumpAndSettle();

      final mobileAppBar = tester.widget<AppBar>(find.byType(AppBar).first);
      expect(mobileAppBar.toolbarHeight, 50);

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });

  testWidgets(
    'hides attachment button when selected model does not support attachments',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(localDataSource: localDataSource);
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add attachment'), findsNothing);
    },
  );

  testWidgets('shows only supported attachment options for image-only model', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      providersResponse: ProvidersResponse(
        providers: <Provider>[
          Provider(
            id: 'provider_1',
            name: 'Provider 1',
            env: const <String>[],
            models: <String, Model>{
              'model_1': _model(
                'model_1',
                attachment: true,
                modalities: const <String, dynamic>{
                  'input': <String>['text', 'image'],
                },
              ),
            },
          ),
        ],
        defaultModels: const <String, String>{'provider_1': 'model_1'},
        connected: const <String>['provider_1'],
      ),
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add attachment'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('composer_input_row')),
        matching: find.byTooltip('Add attachment'),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('New Chat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add attachment'));
    await tester.pumpAndSettle();
    expect(find.text('Select Images'), findsOneWidget);
    expect(find.text('Select PDF'), findsNothing);
  });

  testWidgets(
    'shows both image and PDF options when model supports both modalities',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(
        localDataSource: localDataSource,
        providersResponse: ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'provider_1',
              name: 'Provider 1',
              env: const <String>[],
              models: <String, Model>{
                'model_1': _model(
                  'model_1',
                  attachment: true,
                  modalities: const <String, dynamic>{
                    'input': <String>['text', 'image', 'pdf'],
                  },
                ),
              },
            ),
          ],
          defaultModels: const <String, String>{'provider_1': 'model_1'},
          connected: const <String>['provider_1'],
        ),
      );
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add attachment'), findsOneWidget);
      await tester.tap(find.byTooltip('New Chat').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add attachment'));
      await tester.pumpAndSettle();
      expect(find.text('Select Images'), findsOneWidget);
      expect(find.text('Select PDF'), findsOneWidget);
    },
  );

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
    expect(
      find.byKey(const ValueKey<String>('project_selector_button')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('project_selector_button')),
          )
          .dx,
      lessThan(220),
    );

    await tester.tap(find.byTooltip('Choose Directory'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('project_selector_dialog_content')),
      findsOneWidget,
    );
    expect(find.text('Project context'), findsOneWidget);
    expect(find.text('Current directory: /repo/a'), findsOneWidget);
    expect(find.text('Select a directory/workspace below'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('closed project can be archived from closed list', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_main',
        name: 'Main',
        path: '/repo/main',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_main',
          name: 'Main',
          path: '/repo/main',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        Project(
          id: 'proj_ws',
          name: 'Workspace Feature',
          path: '/repo/main/feature-a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1),
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

    expect(find.text('Workspace Feature'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Archive closed project Workspace Feature'),
    );
    await tester.pumpAndSettle();

    expect(provider.projectProvider.archivedProjectIds, contains('proj_ws'));
    expect(find.text('Workspace Feature'), findsNothing);
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
      find.byKey(const ValueKey<String>('project_selector_dialog_content')),
      findsOneWidget,
    );
    final mobileDialogSize = tester.getSize(
      find.byKey(const ValueKey<String>('project_selector_dialog_content')),
    );
    expect(mobileDialogSize.width, closeTo(390, 0.5));
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
    projectRepository.gitDirectories.add('/repo/custom');
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
      provider.projectProvider.currentDirectory,
      '/repo/custom/feature-api',
    );
    expect(
      find.text('Workspace created in /repo/custom: Feature API'),
      findsOneWidget,
    );
  });

  testWidgets('create workspace supports browsing directories dynamically', (
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
    projectRepository.directoriesByPath['/repo/a'] = <String>[
      '/repo/a/client',
      '/repo/a/server',
    ];
    projectRepository.directoriesByPath['/repo/a/client'] = <String>[
      '/repo/a/client/app',
    ];
    projectRepository.gitDirectories.add('/repo/a/client/app');

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

    await tester.tap(
      find.byKey(
        const ValueKey<String>('workspace_open_directory_picker_button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('directory_picker_sheet')),
      findsOneWidget,
    );
    expect(
      find.text('Workspace creation requires a Git repository directory.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('directory_picker_item_/repo/a/client'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('directory_picker_item_/repo/a/client/app'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('directory_picker_use_current')),
    );
    await tester.pumpAndSettle();

    expect(find.text('/repo/a/client/app'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('workspace_name_input')),
      'Feature Browser',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
      projectRepository.lastCreatedWorktreeDirectory,
      '/repo/a/client/app',
    );
  });

  testWidgets(
    'desktop file explorer expands tree and opens open-files dialog',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final projectRepository = FakeProjectRepository(
        currentProject: Project(
          id: 'proj_files',
          name: 'Project Files',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_files',
            name: 'Project Files',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      );
      projectRepository.filesByPath['.'] = const <FileNode>[
        FileNode(
          path: '/repo/a/.github',
          name: '.github',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/.vscode',
          name: '.vscode',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/.idea',
          name: '.idea',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/.dart_tool',
          name: '.dart_tool',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/android',
          name: 'android',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/ios',
          name: 'ios',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/macos',
          name: 'macos',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/lib',
          name: 'lib',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/src',
          name: 'src',
          type: FileNodeType.directory,
        ),
        FileNode(
          path: '/repo/a/package.json',
          name: 'package.json',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/README.md',
          name: 'README.md',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/scripts/setup.sh',
          name: 'setup.sh',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/scripts/login.ash',
          name: 'login.ash',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/Jenkinsfile',
          name: 'Jenkinsfile',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/jenkins.yaml',
          name: 'jenkins.yaml',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/vite.config.ts',
          name: 'vite.config.ts',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/vite-env.d.ts',
          name: 'vite-env.d.ts',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/vite.svg',
          name: 'vite.svg',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/id_rsa',
          name: 'id_rsa',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/id_ed25519',
          name: 'id_ed25519',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/dev.pem',
          name: 'dev.pem',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/logo.svg',
          name: 'logo.svg',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/vector.svgz',
          name: 'vector.svgz',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/photo.png',
          name: 'photo.png',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/.env.production',
          name: '.env.production',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/notes.txt',
          name: 'notes.txt',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/data.csv',
          name: 'data.csv',
          type: FileNodeType.file,
        ),
        FileNode(
          path: '/repo/a/data.tsv',
          name: 'data.tsv',
          type: FileNodeType.file,
        ),
      ];
      projectRepository.filesByPath['/repo/a/.github'] = const <FileNode>[
        FileNode(
          path: '/repo/a/.github/workflows',
          name: 'workflows',
          type: FileNodeType.directory,
        ),
      ];
      projectRepository.filesByPath['/repo/a/lib'] = const <FileNode>[
        FileNode(
          path: '/repo/a/lib/main.dart',
          name: 'main.dart',
          type: FileNodeType.file,
        ),
      ];
      projectRepository.filesByPath['/repo/a/src'] = const <FileNode>[
        FileNode(
          path: '/repo/a/src/App.vue',
          name: 'App.vue',
          type: FileNodeType.file,
        ),
      ];
      projectRepository.fileContentsByPath['/repo/a/lib/main.dart'] =
          const FileContent(
            path: '/repo/a/lib/main.dart',
            content: 'void main() => print("ok");',
            isBinary: false,
          );

      final provider = _buildChatProvider(
        localDataSource: localDataSource,
        projectRepository: projectRepository,
      );
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('file_tree_list')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/package.json'),
          ),
          matching: find.byIcon(SimpleIcons.npm),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.github'),
          ),
          matching: find.byIcon(SimpleIcons.github),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.idea'),
          ),
          matching: find.byIcon(SimpleIcons.jetbrains),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.dart_tool'),
          ),
          matching: find.byIcon(SimpleIcons.dart),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/android'),
          ),
          matching: find.byIcon(SimpleIcons.android),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('file_tree_item_/repo/a/ios')),
          matching: find.byIcon(SimpleIcons.ios),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/macos'),
          ),
          matching: find.byIcon(SimpleIcons.macos),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.vscode'),
          ),
          matching: find.byIcon(SimpleIcons.vscodium),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/scripts/setup.sh'),
          ),
          matching: find.byIcon(SimpleIcons.iterm2),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/scripts/login.ash'),
          ),
          matching: find.byIcon(SimpleIcons.iterm2),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/Jenkinsfile'),
          ),
          matching: find.byIcon(SimpleIcons.jenkins),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/jenkins.yaml'),
          ),
          matching: find.byIcon(SimpleIcons.jenkins),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/vite.config.ts'),
          ),
          matching: find.byIcon(SimpleIcons.vite),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/vite-env.d.ts'),
          ),
          matching: find.byIcon(SimpleIcons.vite),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/id_rsa'),
          ),
          matching: find.byIcon(SimpleIcons.passbolt),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/id_ed25519'),
          ),
          matching: find.byIcon(SimpleIcons.passbolt),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/dev.pem'),
          ),
          matching: find.byIcon(SimpleIcons.passbolt),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/logo.svg'),
          ),
          matching: find.byIcon(SimpleIcons.svg),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/vector.svgz'),
          ),
          matching: find.byIcon(SimpleIcons.inkscape),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/photo.png'),
          ),
          matching: find.byIcon(SimpleIcons.googlephotos),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.env.production'),
          ),
          matching: find.byIcon(SimpleIcons.dotenv),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/notes.txt'),
          ),
          matching: find.byIcon(Icons.article),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/data.csv'),
          ),
          matching: find.byIcon(Icons.table_chart),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/data.tsv'),
          ),
          matching: find.byIcon(Icons.table_rows),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('file_tree_item_/repo/a/.github')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/.github/workflows'),
          ),
          matching: find.byIcon(SimpleIcons.githubactions),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('file_tree_item_/repo/a/src')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('file_tree_item_/repo/a/src/App.vue'),
          ),
          matching: find.byIcon(SimpleIcons.vuedotjs),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('file_tree_item_/repo/a/lib')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('file_tree_item_/repo/a/lib/main.dart'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
          matching: find.text('void main() => print("ok");'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('desktop open files button opens centered dialog with tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_tabs_desktop',
        name: 'Project Tabs Desktop',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_tabs_desktop',
          name: 'Project Tabs Desktop',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    projectRepository.filesByPath['.'] = const <FileNode>[
      FileNode(
        path: '/repo/a/lib/main.dart',
        name: 'main.dart',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.fileContentsByPath['/repo/a/lib/main.dart'] =
        const FileContent(
          path: '/repo/a/lib/main.dart',
          content: 'void desktopTabs() {}',
          isBinary: false,
        );

    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: projectRepository,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('file_tree_item_/repo/a/lib/main.dart'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.byTooltip('Close'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('file_tree_open_files_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open_files_dialog_centered')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.byKey(
          const ValueKey<String>('file_viewer_tab_/repo/a/lib/main.dart'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'file viewer fallback retries relative path when absolute result is empty',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1300, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final projectRepository = FakeProjectRepository(
        currentProject: Project(
          id: 'proj_files_fallback',
          name: 'Project Files Fallback',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        projects: <Project>[
          Project(
            id: 'proj_files_fallback',
            name: 'Project Files Fallback',
            path: '/repo/a',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
      );
      projectRepository.filesByPath['.'] = const <FileNode>[
        FileNode(
          path: '/repo/a/lib/main.dart',
          name: 'main.dart',
          type: FileNodeType.file,
        ),
      ];
      projectRepository.fileContentsByPath['lib/main.dart'] = const FileContent(
        path: 'lib/main.dart',
        content: 'void fallbackPath() {}',
        isBinary: false,
      );

      final provider = _buildChatProvider(
        localDataSource: localDataSource,
        projectRepository: projectRepository,
      );
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('file_tree_item_/repo/a/lib/main.dart'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
          matching: find.text('void fallbackPath() {}'),
        ),
        findsOneWidget,
      );
      expect(find.text('File is empty.'), findsNothing);
    },
  );

  testWidgets('quick open finds file and opens open-files dialog', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_search',
        name: 'Project Search',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_search',
          name: 'Project Search',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    projectRepository.searchResultsByQuery['chat'] = const <FileNode>[
      FileNode(
        path: '/repo/a/lib/chat_provider.dart',
        name: 'chat_provider.dart',
        type: FileNodeType.file,
      ),
      FileNode(
        path: '/repo/a/docs/chat.md',
        name: 'chat.md',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.fileContentsByPath['/repo/a/lib/chat_provider.dart'] =
        const FileContent(
          path: '/repo/a/lib/chat_provider.dart',
          content: 'class ChatProvider {}',
          isBinary: false,
        );

    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: projectRepository,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('file_tree_quick_open_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('quick_open_input')),
      'chat',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'quick_open_result_/repo/a/lib/chat_provider.dart',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open_files_dialog_centered')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.text('class ChatProvider {}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mobile open files button opens fullscreen tab dialog', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_tabs_mobile',
        name: 'Project Tabs Mobile',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_tabs_mobile',
          name: 'Project Tabs Mobile',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    projectRepository.filesByPath['.'] = const <FileNode>[
      FileNode(
        path: '/repo/a/lib/mobile.dart',
        name: 'mobile.dart',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.searchResultsByQuery['mobile'] = const <FileNode>[
      FileNode(
        path: '/repo/a/lib/mobile.dart',
        name: 'mobile.dart',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.fileContentsByPath['/repo/a/lib/mobile.dart'] =
        const FileContent(
          path: '/repo/a/lib/mobile.dart',
          content: 'void mobileTabs() {}',
          isBinary: false,
        );

    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: projectRepository,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    final newChatX = tester.getCenter(find.byTooltip('New Chat').first).dx;
    final openFilesX = tester.getCenter(find.byTooltip('Open Files')).dx;
    expect(newChatX, greaterThan(openFilesX));

    final refreshFinder = find.byTooltip('Refresh');
    if (refreshFinder.evaluate().isNotEmpty) {
      final refreshX = tester.getCenter(refreshFinder.first).dx;
      expect(newChatX, greaterThan(refreshX));
    }

    await tester.tap(
      find.byKey(const ValueKey<String>('appbar_quick_open_button')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('file_tree_quick_open_button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('quick_open_input')),
      'mobile',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('quick_open_result_/repo/a/lib/mobile.dart'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open_files_dialog_fullscreen')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_fullscreen')),
        matching: find.text('void mobileTabs() {}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('file viewer shows binary and error states', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final projectRepository = FakeProjectRepository(
      currentProject: Project(
        id: 'proj_binary',
        name: 'Project Binary',
        path: '/repo/a',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      projects: <Project>[
        Project(
          id: 'proj_binary',
          name: 'Project Binary',
          path: '/repo/a',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
    );
    projectRepository.filesByPath['.'] = const <FileNode>[
      FileNode(
        path: '/repo/a/assets/logo.png',
        name: 'logo.png',
        type: FileNodeType.file,
      ),
      FileNode(
        path: '/repo/a/lib/error.dart',
        name: 'error.dart',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.fileContentsByPath['/repo/a/assets/logo.png'] =
        const FileContent(
          path: '/repo/a/assets/logo.png',
          content: '',
          isBinary: true,
          mimeType: 'image/png',
        );

    final provider = _buildChatProvider(
      localDataSource: localDataSource,
      projectRepository: projectRepository,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('file_tree_item_/repo/a/assets/logo.png'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.text('Binary file preview is not available.'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.byTooltip('Close'),
      ),
    );
    await tester.pumpAndSettle();

    projectRepository.fileContentFailure = const ServerFailure(
      'forced read failure',
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>('file_tree_item_/repo/a/lib/error.dart'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.byKey(
          const ValueKey<String>('file_viewer_retry_button'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('open_files_dialog_centered')),
        matching: find.textContaining('Failed to read file'),
      ),
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

  testWidgets(
    'refreshes active session on reconnect and keeps no manual 5s polling',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_refresh',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Refresh Session',
          ),
        ],
      );
      repository.messagesBySession['ses_refresh'] = <ChatMessage>[
        AssistantMessage(
          id: 'msg_refresh_1',
          sessionId: 'ses_refresh',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_refresh_1',
              messageId: 'msg_refresh_1',
              sessionId: 'ses_refresh',
              text: 'initial',
            ),
          ],
        ),
      ];
      final appRepository = FakeAppRepository();

      final localDataSource = InMemoryAppLocalDataSource()
        ..activeServerId = 'srv_test';
      final provider = _buildChatProvider(
        chatRepository: repository,
        localDataSource: localDataSource,
      );
      final appProvider = _buildAppProvider(
        localDataSource: localDataSource,
        appRepository: appRepository,
      );

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      await provider.initializeProviders();
      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await tester.pumpAndSettle();

      final baseMessageCalls = repository.getMessagesCallCount;
      final baseStatusCalls = repository.getSessionStatusCallCount;

      appRepository.checkConnectionResult = const Right(false);
      await appProvider.checkConnection();
      await tester.pumpAndSettle();

      appRepository.checkConnectionResult = const Right(true);
      await appProvider.checkConnection();
      await tester.pumpAndSettle();

      expect(repository.getMessagesCallCount, greaterThan(baseMessageCalls));
      expect(
        repository.getSessionStatusCallCount,
        greaterThan(baseStatusCalls),
      );

      final reconnectMessageCalls = repository.getMessagesCallCount;
      final reconnectStatusCalls = repository.getSessionStatusCallCount;

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(repository.getMessagesCallCount, reconnectMessageCalls);
      expect(repository.getSessionStatusCallCount, reconnectStatusCalls);
    },
  );

  testWidgets(
    'mobile long-press on user message bubble pre-fills composer input',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_mobile_hold',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Mobile Hold Session',
          ),
        ],
      );
      repository.messagesBySession['ses_mobile_hold'] = <ChatMessage>[
        UserMessage(
          id: 'msg_user_hold',
          sessionId: 'ses_mobile_hold',
          time: DateTime.fromMillisecondsSinceEpoch(1200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_hold',
              messageId: 'msg_user_hold',
              sessionId: 'ses_mobile_hold',
              text: 'reusar esse prompt',
            ),
          ],
        ),
      ];

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

      final backgroundHoldListenerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Listener &&
            widget.behavior == HitTestBehavior.opaque &&
            widget.onPointerDown != null &&
            widget.onPointerMove != null,
      );
      expect(backgroundHoldListenerFinder, findsWidgets);

      final listener = tester.widget<Listener>(
        backgroundHoldListenerFinder.first,
      );
      listener.onPointerDown?.call(
        const PointerDownEvent(pointer: 1, position: Offset.zero),
      );
      await tester.pump(const Duration(milliseconds: 350));
      final chatInputFieldFinder = find.descendant(
        of: find.byKey(const ValueKey<String>('composer_input_row')),
        matching: find.byType(TextField),
      );
      var inputField = tester.widget<TextField>(chatInputFieldFinder);
      expect(inputField.controller!.text, 'reusar esse prompt');
      expect(
        inputField.focusNode?.hasFocus,
        isFalse,
        reason: 'Input must stay unfocused until finger is released',
      );

      listener.onPointerUp?.call(
        const PointerUpEvent(pointer: 1, position: Offset.zero),
      );
      await tester.pumpAndSettle();

      inputField = tester.widget<TextField>(chatInputFieldFinder);
      expect(inputField.controller!.text, 'reusar esse prompt');
      expect(inputField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets('hides refresh actions in refreshless mode', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository();
    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
  });

  testWidgets('rejects question request from chat interaction card', (
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
    repository.pendingQuestions = const <ChatQuestionRequest>[
      ChatQuestionRequest(
        id: 'q_widget_reject_1',
        sessionId: 'ses_1',
        questions: <ChatQuestionInfo>[
          ChatQuestionInfo(
            question: 'Proceed?',
            header: 'Confirm',
            options: <ChatQuestionOption>[
              ChatQuestionOption(label: 'Yes', description: 'Continue'),
              ChatQuestionOption(label: 'No', description: 'Stop'),
            ],
          ),
        ],
      ),
    ];

    final localDataSource = InMemoryAppLocalDataSource()
      ..activeServerId = 'srv_test';
    final provider = _buildChatProvider(
      chatRepository: repository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.initializeProviders();
    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pumpAndSettle();

    expect(find.text('Submit Answers'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(repository.lastQuestionRejectRequestId, 'q_widget_reject_1');
    expect(find.text('Submit Answers'), findsNothing);
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
    'uses provider brand icons for selected model and model selector items',
    (WidgetTester tester) async {
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
        providersResponse: ProvidersResponse(
          providers: <Provider>[
            Provider(
              id: 'anthropic',
              name: 'Anthropic',
              env: const <String>[],
              models: <String, Model>{
                'claude-sonnet-4-5': _model(
                  'claude-sonnet-4-5',
                  name: 'Claude Sonnet 4.5',
                ),
              },
            ),
            Provider(
              id: 'google',
              name: 'Google',
              env: const <String>[],
              models: <String, Model>{
                'claude-opus-via-google': _model(
                  'claude-opus-via-google',
                  name: 'Claude Opus via Google',
                ),
                'gemini-2.5-pro': _model(
                  'gemini-2.5-pro',
                  name: 'Gemini 2.5 Pro',
                ),
              },
            ),
            Provider(
              id: 'minimax',
              name: 'MiniMax',
              env: const <String>[],
              models: <String, Model>{
                'minimax-m1': _model('minimax-m1', name: 'MiniMax M1'),
              },
            ),
            Provider(
              id: 'xai',
              name: 'xAI',
              env: const <String>[],
              models: <String, Model>{
                'grok-3': _model('grok-3', name: 'Grok 3'),
              },
            ),
            Provider(
              id: 'mistral',
              name: 'Mistral',
              env: const <String>[],
              models: <String, Model>{
                'mistral-large': _model('mistral-large', name: 'Mistral Large'),
              },
            ),
            Provider(
              id: 'openrouter',
              name: 'OpenRouter',
              env: const <String>[],
              models: <String, Model>{
                'openrouter-model': _model(
                  'openrouter-model',
                  name: 'OpenRouter Model',
                ),
              },
            ),
          ],
          defaultModels: const <String, String>{
            'anthropic': 'claude-sonnet-4-5',
            'google': 'claude-opus-via-google',
            'minimax': 'minimax-m1',
            'xai': 'grok-3',
            'mistral': 'mistral-large',
            'openrouter': 'openrouter-model',
          },
          connected: const <String>[
            'anthropic',
            'google',
            'minimax',
            'xai',
            'mistral',
            'openrouter',
          ],
        ),
      );
      final appProvider = _buildAppProvider(localDataSource: localDataSource);

      await tester.pumpWidget(_testApp(provider, appProvider));
      await tester.pumpAndSettle();

      await provider.loadSessions();
      await provider.selectSession(provider.sessions.first);
      await provider.setSelectedModelByProvider(
        providerId: 'google',
        modelId: 'claude-opus-via-google',
      );
      await tester.pumpAndSettle();

      final modelSelectorChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      expect(modelSelectorChip.avatar, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      await tester.pumpAndSettle();

      final anthropicTile = tester.widget<ListTile>(
        find.byKey(
          const ValueKey<String>(
            'model_selector_item_anthropic_claude-sonnet-4-5',
          ),
        ),
      );
      final anthropicLeadingIcon = anthropicTile.leading as Icon?;
      expect(anthropicLeadingIcon?.icon, SimpleIcons.claude);

      final googleClaudeTile = tester.widget<ListTile>(
        find.byKey(
          const ValueKey<String>(
            'model_selector_item_google_claude-opus-via-google',
          ),
        ),
      );
      final googleClaudeLeadingIcon = googleClaudeTile.leading as Icon?;
      expect(googleClaudeLeadingIcon?.icon, SimpleIcons.claude);

      final googleTile = tester.widget<ListTile>(
        find.byKey(
          const ValueKey<String>('model_selector_item_google_gemini-2.5-pro'),
        ),
      );
      final googleLeadingIcon = googleTile.leading as Icon?;
      expect(googleLeadingIcon?.icon, SimpleIcons.googlegemini);

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await provider.setSelectedModelByProvider(
        providerId: 'minimax',
        modelId: 'minimax-m1',
      );
      await tester.pumpAndSettle();
      final minimaxChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      expect(minimaxChip.avatar, isNull);

      await provider.setSelectedModelByProvider(
        providerId: 'xai',
        modelId: 'grok-3',
      );
      await tester.pumpAndSettle();
      final xaiChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      expect(xaiChip.avatar, isNull);

      await provider.setSelectedModelByProvider(
        providerId: 'mistral',
        modelId: 'mistral-large',
      );
      await tester.pumpAndSettle();
      final mistralChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      expect(mistralChip.avatar, isNull);

      await provider.setSelectedModelByProvider(
        providerId: 'openrouter',
        modelId: 'openrouter-model',
      );
      await tester.pumpAndSettle();
      final openrouterChip = tester.widget<ActionChip>(
        find.byKey(const ValueKey<String>('model_selector_button')),
      );
      expect(openrouterChip.avatar, isNull);
    },
  );

  testWidgets('shows agent selector and updates selected agent', (
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
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.byKey(const ValueKey<String>('agent_selector_button')),
      findsOneWidget,
    );
    expect(find.text('Build'), findsOneWidget);
    final agentChip = tester.widget<ActionChip>(
      find.byKey(const ValueKey<String>('agent_selector_button')),
    );
    expect(agentChip.avatar, isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('agent_selector_button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('agent_selector_item_build')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('agent_selector_item_plan')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('agent_selector_item_plan')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan'), findsOneWidget);
    expect(provider.selectedAgentName, 'plan');
  });

  testWidgets('uses backend agent color on selector label', (
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
    final appRepository = FakeAppRepository()
      ..agentsResult = const Right(<Agent>[
        Agent(
          name: 'build',
          mode: 'primary',
          hidden: false,
          native: false,
          color: '#ff6b00',
        ),
        Agent(
          name: 'plan',
          mode: 'primary',
          hidden: false,
          native: false,
          color: '#00a8ff',
        ),
      ]);
    final provider = _buildChatProvider(
      chatRepository: repository,
      appRepository: appRepository,
      localDataSource: localDataSource,
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pump(const Duration(milliseconds: 150));

    final chipText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('agent_selector_button')),
        matching: find.text('Build'),
      ),
    );
    expect(chipText.style?.color, const Color(0xFFFF6B00));
  });

  testWidgets('desktop shortcut cycles selected agent', (
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
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pumpAndSettle();

    expect(provider.selectedAgentName, 'build');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(provider.selectedAgentName, 'plan');
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

  testWidgets('auto-follows incoming messages while user stays at latest', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_follow',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Follow Session',
        ),
      ],
    );
    repository.messagesBySession['ses_follow'] = _threadMessages(
      'ses_follow',
      40,
    );

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

    final listFinder = find.byKey(const ValueKey<String>('chat_message_list'));
    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    final scrollableBefore = tester.state<ScrollableState>(scrollableFinder);
    expect(
      scrollableBefore.position.maxScrollExtent -
          scrollableBefore.position.pixels,
      lessThanOrEqualTo(1),
    );
    expect(find.byTooltip('Go to latest message'), findsNothing);

    await provider.sendMessage('trigger auto follow');
    await tester.pump();

    streamController.add(
      Right(
        AssistantMessage(
          id: 'msg_follow_1',
          sessionId: 'ses_follow',
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(3200),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_follow_1',
              messageId: 'msg_follow_1',
              sessionId: 'ses_follow',
              text:
                  'auto-follow should keep chat pinned to the latest message even when new content arrives while user is already at the bottom',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableAfter = tester.state<ScrollableState>(scrollableFinder);
    expect(
      scrollableAfter.position.maxScrollExtent -
          scrollableAfter.position.pixels,
      lessThanOrEqualTo(1),
    );
    expect(
      find.textContaining('auto-follow should keep chat pinned'),
      findsOneWidget,
    );
    expect(find.byTooltip('Go to latest message'), findsNothing);
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

    final listFinder = find.byKey(const ValueKey<String>('chat_message_list'));
    final scrollableFinder = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    final scrollableBefore = tester.state<ScrollableState>(scrollableFinder);
    final pixelsBeforeIncoming = scrollableBefore.position.pixels;

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

    final scrollableAfter = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollableAfter.position.pixels, closeTo(pixelsBeforeIncoming, 1));

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

  testWidgets(
    'shows thinking then receiving indicators while reply is in progress',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = FakeChatRepository(
        sessions: <ChatSession>[
          ChatSession(
            id: 'ses_progress',
            workspaceId: 'default',
            time: DateTime.fromMillisecondsSinceEpoch(1000),
            title: 'Progress Session',
          ),
        ],
      );
      repository.messagesBySession['ses_progress'] = const <ChatMessage>[];

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

      await provider.sendMessage('status progress');
      await tester.pump();

      expect(find.text('Thinking...'), findsOneWidget);

      streamController.add(
        Right(
          AssistantMessage(
            id: 'msg_assistant_progress',
            sessionId: 'ses_progress',
            time: DateTime.fromMillisecondsSinceEpoch(2000),
            parts: const <MessagePart>[
              TextPart(
                id: 'part_assistant_progress',
                messageId: 'msg_assistant_progress',
                sessionId: 'ses_progress',
                text: 'partial token',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Receiving response...'), findsOneWidget);
      expect(find.text('Thinking...'), findsNothing);
    },
  );

  testWidgets('keeps input editable while responding and stop aborts session', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_stop',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Stop Session',
        ),
      ],
    );
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

    await provider.sendMessage('trigger stop');
    await tester.pump();

    final chatInputFieldFinder = find.descendant(
      of: find.byKey(const ValueKey<String>('composer_input_row')),
      matching: find.byType(TextField),
    );
    final inputField = tester.widget<TextField>(chatInputFieldFinder);
    expect(inputField.enabled, isTrue);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    await tester.enterText(chatInputFieldFinder, 'draft while receiving');
    await tester.pump();
    final updatedInputField = tester.widget<TextField>(chatInputFieldFinder);
    expect(updatedInputField.controller!.text, 'draft while receiving');

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pumpAndSettle();

    expect(repository.abortSessionCallCount, 1);
    expect(repository.lastAbortSessionId, 'ses_stop');
  });

  testWidgets('shows snackbar when stop request fails', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_stop_fail',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Stop Fail Session',
        ),
      ],
    )..abortSessionFailure = const ServerFailure('abort failed');
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

    await provider.sendMessage('trigger failing stop');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pumpAndSettle();

    expect(provider.errorMessage, 'Server error. Please try again later');
    expect(find.byType(SnackBar), findsOneWidget);
    final chatInputFieldFinder = find.descendant(
      of: find.byKey(const ValueKey<String>('composer_input_row')),
      matching: find.byType(TextField),
    );
    final inputField = tester.widget<TextField>(chatInputFieldFinder);
    expect(inputField.enabled, isTrue);
  });

  testWidgets('shows consistent fallback title in active session header', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final untitledTime = DateTime(2026, 2, 11, 10, 30);
    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_untitled',
          workspaceId: 'default',
          time: untitledTime,
          title: null,
        ),
      ],
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

    final expected = SessionTitleFormatter.fallbackTitle(time: untitledTime);
    expect(find.text(expected), findsWidgets);
  });

  testWidgets('active session header keeps only essential info', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_compact_header',
          workspaceId: 'default',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          title: 'Compact Header Session',
        ),
      ],
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

    expect(
      find.byKey(const ValueKey<String>('chat_compact_session_header')),
      findsOneWidget,
    );
    expect(find.textContaining('Children:'), findsNothing);
    expect(find.textContaining('Todos:'), findsNothing);
    expect(find.textContaining('Diff:'), findsNothing);
  });

  testWidgets('renames current session through inline header editor', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeChatRepository(
      sessions: <ChatSession>[
        ChatSession(
          id: 'ses_inline',
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
    );
    final appProvider = _buildAppProvider(localDataSource: localDataSource);

    await tester.pumpWidget(_testApp(provider, appProvider));
    await tester.pumpAndSettle();

    await provider.loadSessions();
    await provider.selectSession(provider.sessions.first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('session_title_edit_button')).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('session_title_editor_field')).first,
      'Renamed Inline',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('session_title_save_button')).first,
    );
    await tester.pumpAndSettle();

    expect(provider.currentSession?.title, 'Renamed Inline');
    expect(
      provider.sessions.where((item) => item.id == 'ses_inline').first.title,
      'Renamed Inline',
    );
  });
}

Widget _testApp(ChatProvider provider, AppProvider appProvider) {
  final settingsProvider = SettingsProvider(
    localDataSource: provider.localDataSource,
    dioClient: DioClient(),
    soundService: SoundService(),
  );
  unawaited(settingsProvider.initialize());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(value: provider),
      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ChangeNotifierProvider<ProjectProvider>.value(
        value: provider.projectProvider,
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
    ],
    child: const MaterialApp(home: ChatPage()),
  );
}

ChatProvider _buildChatProvider({
  FakeChatRepository? chatRepository,
  FakeProjectRepository? projectRepository,
  FakeAppRepository? appRepository,
  required InMemoryAppLocalDataSource localDataSource,
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
    projectProvider: ProjectProvider(
      projectRepository: projectRepository ?? FakeProjectRepository(),
      localDataSource: localDataSource,
    ),
    localDataSource: localDataSource,
  );
}

AppProvider _buildAppProvider({
  required InMemoryAppLocalDataSource localDataSource,
  FakeAppRepository? appRepository,
}) {
  final repository = appRepository ?? FakeAppRepository();
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
  bool attachment = false,
  Map<String, dynamic>? modalities,
  Map<String, ModelVariant> variants = const <String, ModelVariant>{},
}) {
  return Model(
    id: id,
    name: name ?? id,
    releaseDate: '2025-01-01',
    attachment: attachment,
    reasoning: false,
    temperature: true,
    toolCall: false,
    cost: const ModelCost(input: 0.001, output: 0.002),
    limit: const ModelLimit(context: 1000, output: 100),
    options: const <String, dynamic>{},
    modalities: modalities,
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
