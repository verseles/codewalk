import 'package:codewalk/presentation/widgets/codewalk_terminal_extra_keys.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import '../support/pump_localized_app.dart';

void main() {
  group('CodewalkTerminalExtraKeysController', () {
    test('delegates unmodified keys to the original input handler', () {
      final output = <String>[];
      final original = _InputHandler((event) {
        return event.state.cursorKeysMode ? 'application' : 'normal';
      });
      final terminal = Terminal(inputHandler: original, onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.dispatchKey(TerminalKey.arrowUp);
      terminal.write('\x1b[?1h');
      controller.dispatchKey(TerminalKey.arrowUp);

      expect(output, ['normal', 'application']);
      controller.dispose();
    });

    test('emits exact Escape, Tab, and arrow sequences', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      for (final key in <TerminalKey>[
        TerminalKey.escape,
        TerminalKey.tab,
        TerminalKey.arrowLeft,
        TerminalKey.arrowUp,
        TerminalKey.arrowDown,
        TerminalKey.arrowRight,
      ]) {
        controller.dispatchKey(key);
      }

      expect(output, ['\x1b', '\t', '\x1b[D', '\x1b[A', '\x1b[B', '\x1b[C']);
      controller.dispose();
    });

    test('emits one-shot control characters for letters', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      for (final key in [
        TerminalKey.keyC,
        TerminalKey.keyD,
        TerminalKey.keyL,
      ]) {
        controller.toggleControl();
        controller.dispatchKey(key);
      }

      expect(output, ['\x03', '\x04', '\x0c']);
      expect(controller.controlEnabled, isFalse);
      controller.dispose();
    });

    test('emits exact arrow modifier sequences', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      for (final key in [
        TerminalKey.arrowUp,
        TerminalKey.arrowDown,
        TerminalKey.arrowRight,
        TerminalKey.arrowLeft,
      ]) {
        controller.toggleAlt();
        controller.dispatchKey(key);
      }
      controller.toggleControl();
      controller.dispatchKey(TerminalKey.arrowLeft);
      controller.toggleControl();
      controller.toggleAlt();
      controller.dispatchKey(TerminalKey.arrowRight);

      expect(output, [
        '\x1b[1;3A',
        '\x1b[1;3B',
        '\x1b[1;3C',
        '\x1b[1;3D',
        '\x1b[1;5D',
        '\x1b[1;7C',
      ]);
      controller.dispose();
    });

    test('applies modifiers to the first scalar of an IME commit', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.toggleControl();
      controller.toggleAlt();
      expect(controller.handleRawTextInput('cat'), isTrue);
      expect(controller.handleRawTextInput('dog'), isFalse);
      controller.toggleAlt();
      expect(controller.handleRawTextInput('🙂ok'), isTrue);
      controller.toggleAlt();
      expect(controller.handleRawTextInput('A'), isTrue);
      controller.toggleAlt();
      expect(controller.handleRawTextInput('1'), isTrue);
      controller.toggleAlt();
      expect(controller.handleRawTextInput('!'), isTrue);

      expect(output, ['\x1b\x03at', '\x1b🙂ok', '\x1bA', '\x1b1', '\x1b!']);
      expect(controller.controlEnabled, isFalse);
      expect(controller.altEnabled, isFalse);
      controller.dispose();
    });

    test('emits standard control characters from IME commits', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      for (final text in [' ', '[', r'\', ']', '^', '_']) {
        controller.toggleControl();
        expect(controller.handleRawTextInput(text), isTrue);
      }
      controller.toggleControl();
      controller.toggleAlt();
      expect(controller.handleRawTextInput('['), isTrue);

      expect(output, [
        '\x00',
        '\x1b',
        '\x1c',
        '\x1d',
        '\x1e',
        '\x1f',
        '\x1b\x1b',
      ]);
      controller.dispose();
    });

    test('retains modifiers until printable hardware fallback commits', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.toggleAlt();
      expect(terminal.keyInput(TerminalKey.digit1), isFalse);
      expect(controller.altEnabled, isTrue);
      expect(controller.handleRawTextInput('1'), isTrue);

      controller.toggleAlt();
      expect(terminal.keyInput(TerminalKey.bracketLeft), isFalse);
      expect(controller.altEnabled, isTrue);
      expect(controller.handleRawTextInput('['), isTrue);

      expect(output, ['\x1b1', '\x1b[']);
      controller.dispose();
    });

    test('retains modifiers across empty IME commits', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal)
        ..toggleControl()
        ..toggleAlt();

      expect(controller.handleRawTextInput(''), isFalse);
      expect(controller.controlEnabled, isTrue);
      expect(controller.altEnabled, isTrue);
      expect(controller.handleRawTextInput('c'), isTrue);

      expect(output, ['\x1b\x03']);
      controller.dispose();
    });

    test('leaves pending modifiers armed for modifier key events', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.toggleControl();
      for (final key in [
        TerminalKey.shiftLeft,
        TerminalKey.fn,
        TerminalKey.fnLock,
        TerminalKey.hyper,
        TerminalKey.superKey,
      ]) {
        terminal.keyInput(key);
      }
      terminal.keyInput(TerminalKey.keyC);

      expect(output, ['\x03']);
      controller.dispose();
    });

    test('restores only the input handler installed by the controller', () {
      final original = _InputHandler((_) => 'original');
      final replacement = _InputHandler((_) => 'replacement');
      final terminal = Terminal(inputHandler: original);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.detach();
      expect(terminal.inputHandler, same(original));

      controller.attach(terminal);
      terminal.inputHandler = replacement;
      controller.detach();
      expect(terminal.inputHandler, same(replacement));
      controller.dispose();
    });

    test('transfers input-handler ownership between panel controllers', () {
      final output = <String>[];
      final original = _InputHandler((_) => 'original');
      final terminal = Terminal(inputHandler: original, onOutput: output.add);
      final firstController = CodewalkTerminalExtraKeysController()
        ..attach(terminal);
      final secondController = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      firstController.dispose();
      terminal.keyInput(TerminalKey.arrowUp);

      expect(output, ['original']);
      secondController.dispose();
      expect(terminal.inputHandler, same(original));
    });

    testWidgets('captures the modified sequence for an arrow repeat', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.toggleAlt();
      controller.startArrowRepeat(TerminalKey.arrowUp);
      await tester.pump(codewalkTerminalArrowRepeatInterval * 2);
      controller.stopRepeat();
      final countAfterStop = output.length;
      await tester.pump(codewalkTerminalArrowRepeatInterval * 2);

      expect(output, hasLength(3));
      expect(output, everyElement('\x1b[1;3A'));
      expect(output.length, countAfterStop);
      expect(controller.altEnabled, isFalse);
      controller.dispose();
    });

    testWidgets('reset clears modifiers and cancels arrow repeat', (
      tester,
    ) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);

      controller.toggleControl();
      controller.toggleAlt();
      controller.startArrowRepeat(TerminalKey.arrowDown);
      controller.toggleControl();
      controller.reset();
      final countAfterReset = output.length;
      await tester.pump(codewalkTerminalArrowRepeatInterval * 2);

      expect(controller.controlEnabled, isFalse);
      expect(controller.altEnabled, isFalse);
      expect(output.length, countAfterReset);
      controller.dispose();
    });

    testWidgets('attaching a new terminal resets generation-bound state', (
      tester,
    ) async {
      final firstOutput = <String>[];
      final secondOutput = <String>[];
      final firstTerminal = Terminal(onOutput: firstOutput.add);
      final secondTerminal = Terminal(onOutput: secondOutput.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(firstTerminal)
        ..toggleControl()
        ..startArrowRepeat(TerminalKey.arrowDown)
        ..attach(secondTerminal);
      final firstCountAfterAttach = firstOutput.length;

      await tester.pump(codewalkTerminalArrowRepeatInterval * 2);
      controller.dispatchKey(TerminalKey.arrowDown);

      expect(controller.controlEnabled, isFalse);
      expect(controller.altEnabled, isFalse);
      expect(firstOutput, hasLength(firstCountAfterAttach));
      expect(secondOutput, ['\x1b[B']);
      controller.dispose();
    });
  });

  group('extra-key strip responsiveness', () {
    Future<void> pumpAtWidth(WidgetTester tester, double width) async {
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = CodewalkTerminalExtraKeysController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: width,
                child: CodewalkTerminalExtraKeys(
                  controller: controller,
                  requestTerminalFocus: focusNode.requestFocus,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final width in <double>[320, 360, 390]) {
      testWidgets('every key is reachable without scrolling at $width', (
        tester,
      ) async {
        await pumpAtWidth(tester, width);

        // No horizontal scroller left to hide anything behind.
        expect(
          find.byKey(const ValueKey<String>('terminal_extra_keys_scroll')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        for (final key in <String>[
          'terminal_extra_key_escape',
          'terminal_extra_key_tab',
          'terminal_extra_key_control',
          'terminal_extra_key_alt',
          'terminal_extra_key_arrow_left',
          'terminal_extra_key_arrow_up',
          'terminal_extra_key_arrow_down',
          'terminal_extra_key_arrow_right',
        ]) {
          final finder = find.byKey(ValueKey<String>(key));
          expect(finder, findsOneWidget, reason: '$key missing at $width');
          final rect = tester.getRect(finder);
          expect(
            rect.left,
            greaterThanOrEqualTo(-0.5),
            reason: '$key starts off-screen at $width',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(width + 0.5),
            reason: '$key overflows at $width',
          );
        }
      });
    }

    testWidgets('narrow widths shrink to fit a single row at 320', (
      tester,
    ) async {
      await pumpAtWidth(tester, 320);

      expect(
        find.byKey(const ValueKey<String>('terminal_extra_keys_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('terminal_extra_keys_wrap')),
        findsNothing,
      );
      final escape = tester.getRect(
        find.byKey(const ValueKey<String>('terminal_extra_key_escape')),
      );
      expect(escape.width, moreOrLessEquals(34.5, epsilon: 0.5));
      expect(escape.height, moreOrLessEquals(48, epsilon: 0.5));
    });

    testWidgets('very narrow widths wrap as a safety fallback', (tester) async {
      await pumpAtWidth(tester, 220);

      expect(
        find.byKey(const ValueKey<String>('terminal_extra_keys_wrap')),
        findsOneWidget,
      );
      final escape = tester.getRect(
        find.byKey(const ValueKey<String>('terminal_extra_key_escape')),
      );
      expect(escape.width, moreOrLessEquals(48, epsilon: 0.5));
    });

    testWidgets('roomy widths keep a single row', (tester) async {
      await pumpAtWidth(tester, 600);

      expect(
        find.byKey(const ValueKey<String>('terminal_extra_keys_row')),
        findsOneWidget,
      );
    });
  });

  group('mobile terminal extra-key strip', () {
    test('shows only for an active Android or iOS terminal above the IME', () {
      expect(
        shouldShowCodewalkTerminalExtraKeys(
          isWeb: false,
          platform: TargetPlatform.android,
          hasActiveTerminal: true,
          keyboardInset: 280,
        ),
        isTrue,
      );
      expect(
        shouldShowCodewalkTerminalExtraKeys(
          isWeb: false,
          platform: TargetPlatform.iOS,
          hasActiveTerminal: true,
          keyboardInset: 280,
        ),
        isTrue,
      );

      for (final hiddenCase
          in <
            ({
              bool isWeb,
              TargetPlatform platform,
              bool hasActiveTerminal,
              double keyboardInset,
            })
          >[
            (
              isWeb: true,
              platform: TargetPlatform.android,
              hasActiveTerminal: true,
              keyboardInset: 280,
            ),
            (
              isWeb: false,
              platform: TargetPlatform.linux,
              hasActiveTerminal: true,
              keyboardInset: 280,
            ),
            (
              isWeb: false,
              platform: TargetPlatform.android,
              hasActiveTerminal: false,
              keyboardInset: 280,
            ),
            (
              isWeb: false,
              platform: TargetPlatform.android,
              hasActiveTerminal: true,
              keyboardInset: 0,
            ),
          ]) {
        expect(
          shouldShowCodewalkTerminalExtraKeys(
            isWeb: hiddenCase.isWeb,
            platform: hiddenCase.platform,
            hasActiveTerminal: hiddenCase.hasActiveTerminal,
            keyboardInset: hiddenCase.keyboardInset,
          ),
          isFalse,
        );
      }
    });

    testWidgets(
      'keeps accessible controls laid out and terminal focus on narrow screens',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 180));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final output = <String>[];
        final terminal = Terminal(onOutput: output.add);
        final controller = CodewalkTerminalExtraKeysController()
          ..attach(terminal);
        final terminalFocusNode = FocusNode(debugLabel: 'test_terminal');
        addTearDown(controller.dispose);
        addTearDown(terminalFocusNode.dispose);

        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Focus(
                  focusNode: terminalFocusNode,
                  child: CodewalkTerminalExtraKeys(
                    controller: controller,
                    requestTerminalFocus: terminalFocusNode.requestFocus,
                  ),
                ),
              ),
            ),
          ),
        );
        terminalFocusNode.requestFocus();
        await tester.pump();

        // #123 replaced the horizontal scroller with an adaptive layout, so
        // every key is laid out on screen rather than parked off-view.
        expect(
          find.byKey(const ValueKey<String>('terminal_extra_keys_scroll')),
          findsNothing,
        );
        expect(find.bySemanticsLabel('Terminal extra keys'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final controlFinder = find.byKey(
          const ValueKey<String>('terminal_extra_key_control'),
        );
        Semantics controlSemantics() => tester.widget<Semantics>(
          find
              .descendant(of: controlFinder, matching: find.byType(Semantics))
              .first,
        );

        expect(controlSemantics().properties.toggled, isFalse);
        expect(controlSemantics().properties.onTap, isNotNull);
        await tester.tap(controlFinder);
        await tester.pump();
        expect(controller.controlEnabled, isTrue);
        expect(controlSemantics().properties.toggled, isTrue);
        expect(terminalFocusNode.hasFocus, isTrue);

        await tester.tap(controlFinder);
        await tester.tap(
          find.byKey(const ValueKey<String>('terminal_extra_key_escape')),
        );
        await tester.pump();
        expect(output, ['\x1b']);
        expect(terminalFocusNode.hasFocus, isTrue);

        final rightArrowFinder = find.byKey(
          const ValueKey<String>('terminal_extra_key_arrow_right'),
        );
        await tester.ensureVisible(rightArrowFinder);
        final rightArrowSize = tester.getSize(rightArrowFinder);
        expect(rightArrowSize.width, moreOrLessEquals(34.5, epsilon: 0.5));
        expect(rightArrowSize.height, moreOrLessEquals(48, epsilon: 0.5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('arrow tap emits once while hold repeats until release', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 180));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      final controller = CodewalkTerminalExtraKeysController()
        ..attach(terminal);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CodewalkTerminalExtraKeys(
                controller: controller,
                requestTerminalFocus: () {},
              ),
            ),
          ),
        ),
      );

      final leftArrowFinder = find.byKey(
        const ValueKey<String>('terminal_extra_key_arrow_left'),
      );
      await tester.tap(leftArrowFinder);
      expect(output, ['\x1b[D']);

      final gesture = await tester.startGesture(
        tester.getCenter(leftArrowFinder),
      );
      await tester.pump(
        kLongPressTimeout + codewalkTerminalArrowRepeatInterval,
      );
      expect(output.length, greaterThan(1));
      expect(output, everyElement('\x1b[D'));
      await gesture.up();
      final countAfterRelease = output.length;
      await tester.pump(codewalkTerminalArrowRepeatInterval * 2);

      expect(output, hasLength(countAfterRelease));
    });
  });
}

class _InputHandler implements TerminalInputHandler {
  const _InputHandler(this.handler);

  final String? Function(TerminalKeyboardEvent event) handler;

  @override
  String? call(TerminalKeyboardEvent event) => handler(event);
}
