import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;

import 'package:codewalk/core/errors/failures.dart';
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

  testWidgets('desktop file explorer expands tree and opens file viewer tab', (
    WidgetTester tester,
  ) async {
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
      FileNode(path: '/repo/a/lib', name: 'lib', type: FileNodeType.directory),
      FileNode(
        path: '/repo/a/README.md',
        name: 'README.md',
        type: FileNodeType.file,
      ),
    ];
    projectRepository.filesByPath['/repo/a/lib'] = const <FileNode>[
      FileNode(
        path: '/repo/a/lib/main.dart',
        name: 'main.dart',
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
      find.byKey(const ValueKey<String>('file_viewer_panel')),
      findsOneWidget,
    );
    expect(find.text('void main() => print("ok");'), findsOneWidget);
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

      expect(find.text('void fallbackPath() {}'), findsOneWidget);
      expect(find.text('File is empty.'), findsNothing);
    },
  );

  testWidgets('quick open finds file and opens viewer tab', (
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
      find.byKey(const ValueKey<String>('file_viewer_panel')),
      findsOneWidget,
    );
    expect(find.text('class ChatProvider {}'), findsOneWidget);
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
    expect(find.text('Binary file preview is not available.'), findsOneWidget);

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
      find.byKey(const ValueKey<String>('file_viewer_retry_button')),
      findsOneWidget,
    );
    expect(find.textContaining('Failed to read file'), findsOneWidget);
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
