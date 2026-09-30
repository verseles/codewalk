import 'dart:async';

import 'package:codewalk/core/di/injection_container.dart' as di;
import 'package:codewalk/domain/entities/file_node.dart';
import 'package:codewalk/domain/entities/project.dart';
import 'package:codewalk/presentation/services/workspace_file_operations_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import '../support/chat_page_test_harness.dart';
import '../support/fakes.dart';

void main() {
  tearDown(() async => di.sl.reset());

  for (final fullscreen in [false, true]) {
    testWidgets(
      'file editor dialog shortcuts respect focus and save gates fullscreen=$fullscreen',
      (tester) async {
        await tester.binding.setSurfaceSize(
          fullscreen ? const Size(390, 844) : const Size(1300, 900),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final local = InMemoryAppLocalDataSource()..activeServerId = 'srv_test';
        disableAutomaticUpdateChecksForTest(local);
        final project = Project(
          id: 'shortcuts',
          name: 'Shortcuts',
          path: '/repo/shortcuts',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
        const path = '/repo/shortcuts/main.dart';
        const node = FileNode(
          path: path,
          name: 'main.dart',
          type: FileNodeType.file,
        );
        const secondPath = '/repo/shortcuts/second.dart';
        const secondNode = FileNode(
          path: secondPath,
          name: 'second.dart',
          type: FileNodeType.file,
        );
        final repository = FakeProjectRepository(
          currentProject: project,
          projects: [project],
        );
        repository.filesByPath['.'] = const [node, secondNode];
        repository.searchResultsByQuery['main'] = const [node];
        repository.searchResultsByQuery['second'] = const [secondNode];
        repository.fileContentsByPath[path] = const FileContent(
          path: path,
          content: 'before',
          isBinary: false,
        );
        repository.fileContentsByPath[secondPath] = const FileContent(
          path: secondPath,
          content: 'second before',
          isBinary: false,
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

        Future<void> saveChord({bool meta = false}) async {
          final modifier = meta
              ? LogicalKeyboardKey.metaLeft
              : LogicalKeyboardKey.controlLeft;
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
          await tester.sendKeyUpEvent(modifier);
          await tester.pump();
        }

        // A chord outside the file dialog must never write a file.
        await saveChord();
        expect(operations.writeFileCallCount, 0);
        if (fullscreen) {
          await tester.tap(
            find.byKey(const ValueKey<String>('mobile_appbar_overflow_button')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(
              const ValueKey<String>('mobile_overflow_item_quickOpen'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey<String>('file_tree_quick_open_button')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey<String>('quick_open_input')),
            'main',
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey<String>('quick_open_result_$path')),
          );
        } else {
          await tester.tap(
            find.byKey(const ValueKey<String>('file_tree_item_$path')),
          );
        }
        await tester.pumpAndSettle();
        final dialog = find.byKey(
          ValueKey<String>(
            fullscreen
                ? 'open_files_dialog_fullscreen'
                : 'open_files_dialog_centered',
          ),
        );
        final editorFinder = find.byKey(
          const ValueKey<String>('file_editor_$path'),
        );
        final controller = tester.widget<CodeEditor>(editorFinder).controller!;
        final close = find.descendant(
          of: dialog,
          matching: find.byTooltip('Close'),
        );
        final icon = find.descendant(of: close, matching: find.byType(Icon));
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await saveChord();
        expect(operations.writeFileCallCount, 0); // Clean draft.

        controller.text = 'after control';
        await tester.pump();
        final pending = Completer<void>();
        operations.onWriteFile =
            ({required rootDirectory, required path, required content}) =>
                pending.future;
        await saveChord();
        expect(operations.writeFileCallCount, 1);
        expect(operations.lastContent, 'after control');
        await saveChord(meta: true);
        expect(operations.writeFileCallCount, 1); // In-flight gate.
        pending.complete();
        await tester.pumpAndSettle();
        operations.onWriteFile = null;
        expect(
          find.byKey(const ValueKey<String>('file_viewer_tab_dirty_$path')),
          findsNothing,
        );

        controller.text = 'after meta';
        await tester.pump();
        final autosave = find.byKey(
          const ValueKey<String>('file_viewer_autosave_toggle'),
        );
        Focus.of(
          tester.element(
            find.descendant(of: autosave, matching: find.byType(Icon)),
          ),
        ).requestFocus();
        await tester.pump();
        await saveChord(meta: true);
        await tester.pumpAndSettle();
        expect(operations.writeFileCallCount, 2);
        expect(operations.lastPath, path);
        expect(operations.lastContent, 'after meta');

        // Repeats cannot save a newer draft while S remains held.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
        controller.text = 'pending under modal';
        await tester.pump();
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(operations.writeFileCallCount, 2);

        final dialogContext = tester.element(dialog);
        unawaited(
          showDialog<void>(
            context: dialogContext,
            builder: (_) =>
                const AlertDialog(content: TextField(autofocus: true)),
          ),
        );
        await tester.pumpAndSettle();
        await saveChord();
        expect(operations.writeFileCallCount, 2);
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await saveChord();
        await tester.pumpAndSettle();
        expect(operations.writeFileCallCount, 3);
        expect(operations.lastContent, 'pending under modal');

        // An oversized draft uses the same read-only save gate as the button.
        controller.text = 'x' * (64 * 1024 + 1);
        await tester.pump();
        await saveChord();
        expect(operations.writeFileCallCount, 3);
        controller.text = 'pending under modal';
        await tester.pump();
        await tester.tap(close);
        await tester.pumpAndSettle();
        if (fullscreen) {
          await tester.tap(
            find.byKey(const ValueKey<String>('file_tree_quick_open_button')),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey<String>('quick_open_input')),
            'second',
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey<String>('quick_open_result_$secondPath')),
          );
        } else {
          await tester.tap(
            find.byKey(const ValueKey<String>('file_tree_item_$secondPath')),
          );
        }
        await tester.pumpAndSettle();
        final secondController = tester
            .widget<CodeEditor>(
              find.byKey(const ValueKey<String>('file_editor_$secondPath')),
            )
            .controller!;
        secondController.text = 'second after';
        await tester.pump();
        Focus.of(tester.element(icon)).requestFocus();
        await tester.pump();
        await saveChord();
        await tester.pumpAndSettle();
        expect(operations.writeFileCallCount, 4);
        expect(operations.lastPath, secondPath);
        expect(operations.lastContent, 'second after');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        chat.dispose();
        app.dispose();
      },
    );
  }
}
