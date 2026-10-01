import 'package:codewalk/presentation/pages/chat_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

const _menuKey = ValueKey<String>('file_editor_desktop_menu');

Widget _editorApp(
  CodeLineEditingController controller, {
  bool readOnly = false,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.linux,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness, platform: platform),
    home: Scaffold(
      body: FileEditorToolbarOwner(
        readOnly: readOnly,
        controller: controller,
        builder: (toolbar, escapeAction) => CodeEditor(
          controller: controller,
          readOnly: readOnly,
          toolbarController: toolbar,
          shortcutOverrideActions: <Type, Action<Intent>>{
            CodeShortcutEscIntent: escapeAction,
          },
        ),
      ),
    ),
  );
}

Future<void> _rightClick(WidgetTester tester) async {
  await tester.tapAt(
    tester.getTopLeft(find.byType(CodeEditor)) + const Offset(30, 12),
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // re_editor caches its platform flags on first use. Keep its gesture path
    // desktop throughout this suite; ThemeData exercises desktop button styles.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> cleanUp(
    WidgetTester tester,
    CodeLineEditingController controller,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  }

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    for (final brightness in Brightness.values) {
      for (final selected in [false, true]) {
        testWidgets(
          'right-click menu $platform $brightness selected=$selected',
          (tester) async {
            final controller = CodeLineEditingController.fromText(
              'hello world',
            );
            await tester.pumpWidget(
              _editorApp(
                controller,
                brightness: brightness,
                platform: platform,
              ),
            );
            await tester.pumpAndSettle();
            if (selected) controller.selectAll();
            await _rightClick(tester);
            expect(tester.takeException(), isNull);
            expect(find.byKey(_menuKey), findsOneWidget);
            expect(find.text('Copy'), selected ? findsOneWidget : findsNothing);
            expect(find.text('Cut'), selected ? findsOneWidget : findsNothing);
            expect(find.text('Paste'), findsOneWidget);
            expect(
              tester.widget<Material>(find.byKey(_menuKey)).color,
              ThemeData(
                brightness: brightness,
                platform: platform,
              ).colorScheme.surfaceContainer,
            );
            final rect = tester.getRect(find.byKey(_menuKey));
            expect(rect.width, lessThan(300));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(
              rect.bottom,
              lessThanOrEqualTo(
                tester.view.physicalSize.height / tester.view.devicePixelRatio,
              ),
            );
            await cleanUp(tester, controller);
          },
        );
      }
    }
  }

  testWidgets('menu refresh, clipboard actions, and read-only gating', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText('hello world');
    var clipboard = 'replacement';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, String>{'text': clipboard};
        }
        if (call.method == 'Clipboard.hasStrings') {
          return <String, bool>{'value': clipboard.isNotEmpty};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_editorApp(controller));
    await tester.pumpAndSettle();
    await _rightClick(tester);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(controller.selectedText, 'hello world');
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(clipboard, 'hello world');
    expect(find.byKey(_menuKey), findsNothing);
    await _rightClick(tester);
    // re_editor uses wall-clock time for repeated pointer selection. Restore
    // the full range so this assertion tests Cut rather than double-clicking.
    controller.selectAll();
    await tester.tap(find.text('Cut'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    await _rightClick(tester);
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(controller.text, 'hello world');
    controller.selectAll();
    await _rightClick(tester);
    await tester.pumpWidget(_editorApp(controller, readOnly: true));
    await tester.pumpAndSettle();
    expect(find.byKey(_menuKey), findsNothing);
    await _rightClick(tester);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Paste'), findsNothing);
    await cleanUp(tester, controller);
  });

  testWidgets(
    'outside click, Escape, repeated show, and disposal remove menu',
    (tester) async {
      final controller = CodeLineEditingController.fromText('hello world');
      await tester.pumpWidget(_editorApp(controller));
      await tester.pumpAndSettle();
      controller.selectAll();
      await _rightClick(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      expect(controller.selectedText, 'hello world');
      await _rightClick(tester);
      await _rightClick(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      await tester.tapAt(const Offset(600, 400), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
      await _rightClick(tester);
      await cleanUp(tester, controller);
      expect(find.byKey(_menuKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile rectangle uses selection-handle toolbar', (tester) async {
    final controller = CodeLineEditingController.fromText('hello world')
      ..selectAll();
    final toolbar = fileEditorSelectionToolbarController(readOnly: true);
    final visibility = ValueNotifier<bool>(true);
    final link = LayerLink();
    late BuildContext editorContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              editorContext = context;
              return CompositedTransformTarget(
                link: link,
                child: const SizedBox(width: 400, height: 200),
              );
            },
          ),
        ),
      ),
    );
    toolbar.show(
      context: editorContext,
      controller: controller,
      anchors: const TextSelectionToolbarAnchors(primaryAnchor: Offset(30, 30)),
      renderRect: const Rect.fromLTWH(0, 0, 400, 200),
      layerLink: link,
      visibility: visibility,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.byKey(_menuKey), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsNothing);
    expect(find.text('Paste'), findsNothing);
    toolbar.hide(editorContext);
    await cleanUp(tester, controller);
    visibility.dispose();
  });
}
