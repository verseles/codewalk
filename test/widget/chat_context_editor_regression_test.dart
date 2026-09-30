import 'dart:typed_data';

import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/core/errors/failures.dart';
import 'package:codewalk/core/network/dio_client.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/domain/entities/file_node.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/presentation/providers/project_icon_provider.dart';
import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:codewalk/presentation/services/project_icon_discovery_service_base.dart';
import 'package:codewalk/presentation/services/project_icon_models.dart';
import 'package:codewalk/presentation/services/project_icon_store_base.dart';
import 'package:codewalk/presentation/services/sound_service.dart';
import 'package:codewalk/presentation/services/workspace_file_operations_service.dart';
import 'package:codewalk/presentation/widgets/project_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';

class _IconStore implements ProjectIconStore {
  ProjectIconData? icon;

  @override
  Future<ProjectIconData?> readIcon(String key) async => icon;

  @override
  Future<void> deleteIcon(String key) async => icon = null;

  @override
  Future<ProjectIconData> saveIcon({
    required Project project,
    required String key,
    required ProjectIconCandidate candidate,
  }) async => icon!;
}

class _IconDiscovery implements ProjectIconDiscoveryService {
  ProjectIconCandidate? candidate;

  @override
  bool get isSupported => true;

  @override
  Future<ProjectIconDiscoveryResult> discover(Project project) async =>
      candidate == null
      ? const ProjectIconDiscoveryResult(
          status: ProjectIconDiscoveryStatus.error,
        )
      : ProjectIconDiscoveryResult.found(candidate!);
}

Project _project(String id) => Project(
  id: id,
  name: id,
  path: '/repo/$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  tearDown(() async => di.sl.reset());

  testWidgets('hidden project context icon updates and keeps picker action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final local = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
    disableAutomaticUpdateChecksForTest(local);
    final first = _project('first');
    final second = _project('second');
    final chat = buildChatPageProvider(
      localDataSource: local,
      projectRepository: FakeProjectRepository(
        currentProject: first,
        projects: [first, second],
      ),
    );
    final app = buildChatPageAppProvider(localDataSource: local);
    final settings = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    final store = _IconStore();
    final discovery = _IconDiscovery();
    final icons = ProjectIconProvider(
      store: store,
      discoveryService: discovery,
    );
    await settings.initialize();
    await settings.setDesktopPaneVisible(DesktopPane.conversations, false);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProjectIconProvider>.value(
        value: icons,
        child: buildChatPageTestApp(chat, app, settingsProvider: settings),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(
      const ValueKey<String>('appbar_project_context_button'),
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Symbols.folder_open)),
      findsOneWidget,
    );
    final bytes = Uint8List.fromList(
      '<svg viewBox="0 0 8 8"><rect width="8" height="8" /></svg>'.codeUnits,
    );
    final key = projectIconKeyFor(first);
    store.icon = ProjectIconData(
      bytes: bytes,
      metadata: ProjectIconMetadata(
        key: key,
        projectId: first.id,
        projectPath: first.path,
        sourcePath: '${first.path}/icon.svg',
        storedPath: '$key.svg',
        sourceFormat: ProjectIconFormat.svg,
        storedFormat: ProjectIconFormat.svg,
        sourceByteLength: bytes.length,
        storedByteLength: bytes.length,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    discovery.candidate = ProjectIconCandidate(
      sourcePath: '${first.path}/icon.svg',
      bytes: bytes,
      sourceFormat: ProjectIconFormat.svg,
      storedFormat: ProjectIconFormat.svg,
      sourceByteLength: bytes.length,
    );
    await icons.discoverIcon(first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    store.icon = null;
    discovery.candidate = null;
    await chat.projectProvider.switchProject(second.id);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProjectIcon>(
            find.descendant(of: button, matching: find.byType(ProjectIcon)),
          )
          .project
          .id,
      second.id,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Symbols.folder_open)),
      findsOneWidget,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('workspace_base_directory_input')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    icons.dispose();
    settings.dispose();
    chat.dispose();
    app.dispose();
  });

  testWidgets('hidden project context uses folder without current project', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final local = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
    disableAutomaticUpdateChecksForTest(local);
    final repository = FakeProjectRepository(projects: [])
      ..currentProjectFailure = const ServerFailure('no project');
    final chat = buildChatPageProvider(
      localDataSource: local,
      projectRepository: repository,
    );
    final app = buildChatPageAppProvider(localDataSource: local);
    final settings = SettingsProvider(
      localDataSource: local,
      dioClient: DioClient(),
      soundService: SoundService(),
    );
    await settings.initialize();
    await settings.setDesktopPaneVisible(DesktopPane.conversations, false);
    await tester.pumpWidget(
      buildChatPageTestApp(chat, app, settingsProvider: settings),
    );
    await tester.pumpAndSettle();
    expect(chat.projectProvider.currentProject, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('appbar_project_context_button')),
        matching: find.byIcon(Symbols.folder_open),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
    chat.dispose();
    app.dispose();
  });

  testWidgets('native JSONC editor highlights and saves comments unchanged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1300, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final local = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
    disableAutomaticUpdateChecksForTest(local);
    final project = _project('jsonc');
    const path = '/repo/jsonc/config.JSONC';
    const source = '{\n // note\n "enabled": true\n}';
    final repository = FakeProjectRepository(
      currentProject: project,
      projects: [project],
    );
    repository.filesByPath['.'] = const [
      FileNode(path: path, name: 'config.JSONC', type: FileNodeType.file),
    ];
    repository.fileContentsByPath[path] = const FileContent(
      path: path,
      content: source,
      isBinary: false,
      mimeType: 'text/plain',
    );
    final operations = FakeWorkspaceFileOperationsService(
      capabilities: const WorkspaceFileOperationsCapabilities(
        shellFileOpsSupported: true,
        message: 'ok',
      ),
    );
    final chat = buildChatPageProvider(
      localDataSource: local,
      projectRepository: repository,
    );
    final app = buildChatPageAppProvider(localDataSource: local);
    await tester.pumpWidget(
      buildChatPageTestApp(chat, app, fileOperationsService: operations),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('file_tree_item_$path')),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<CodeEditor>(
      find.byKey(const ValueKey<String>('file_editor_$path')),
    );
    expect(editor.style!.codeTheme!.languages.keys, ['json']);
    expect(editor.readOnly, isFalse);
    expect(editor.controller!.text, source);
    const edited = '{\n /* updated */\n "enabled": false\n}';
    editor.controller!.text = edited;
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('file_viewer_save_button')),
    );
    await tester.pumpAndSettle();
    expect(operations.lastContent, edited);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    chat.dispose();
    app.dispose();
  });
}
