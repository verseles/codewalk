import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/widgets/chat_message_widget.dart';

void main() {
  testWidgets('hides step blocks from assistant message body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_1',
              sessionId: 'ses_1',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                StepStartPart(
                  id: 'part_step_start',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  snapshot: 'snap-1',
                ),
                StepFinishPart(
                  id: 'part_step_finish',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  reason: 'stop',
                  cost: 0.0012,
                  tokens: MessageTokens(input: 3, output: 4),
                ),
                TextPart(
                  id: 'part_text',
                  messageId: 'msg_1',
                  sessionId: 'ses_1',
                  text: 'Final answer',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Step started'), findsNothing);
    expect(find.text('Step finished'), findsNothing);
    expect(find.text('Final answer'), findsOneWidget);
  });

  testWidgets('shows step metadata in assistant info popup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_2',
              sessionId: 'ses_2',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              providerId: 'openai',
              modelId: 'gpt-4.1',
              parts: const <MessagePart>[
                StepStartPart(
                  id: 'part_step_start_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  snapshot: 'snap-abc',
                ),
                StepFinishPart(
                  id: 'part_step_finish_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  reason: 'stop',
                  cost: 0.0012,
                  tokens: MessageTokens(input: 3, output: 4),
                ),
                TextPart(
                  id: 'part_text_2',
                  messageId: 'msg_2',
                  sessionId: 'ses_2',
                  text: 'Done',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Message Info'));
    await tester.pumpAndSettle();

    expect(find.text('Model: gpt-4.1'), findsOneWidget);
    expect(find.text('Provider: openai'), findsOneWidget);
    expect(find.text('Step started #1: snap-abc'), findsOneWidget);
    expect(
      find.text('Step finished #1: stop • tokens 7 • \$0.001200'),
      findsOneWidget,
    );
  });

  testWidgets('assistant text is selectable and does not show copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_3',
              sessionId: 'ses_3',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_3',
                  messageId: 'msg_3',
                  sessionId: 'ses_3',
                  text: 'Selectable assistant text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('user text also does not show copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_4',
              sessionId: 'ses_4',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_4',
                  messageId: 'msg_4',
                  sessionId: 'ses_4',
                  text: 'User text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('user text is not selectable and has no copy button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_6',
              sessionId: 'ses_6',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_6',
                  messageId: 'msg_6',
                  sessionId: 'ses_6',
                  text: 'User selectable text',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('background copy handler shows feedback on non-android', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_7',
              sessionId: 'ses_7',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_7a',
                  messageId: 'msg_7',
                  sessionId: 'ses_7',
                  text: 'First line',
                ),
                TextPart(
                  id: 'part_text_7b',
                  messageId: 'msg_7',
                  sessionId: 'ses_7',
                  text: 'Second line',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final backgroundDetectorFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.behavior == HitTestBehavior.opaque &&
          widget.onDoubleTap != null,
    );
    final detector = tester.widget<GestureDetector>(backgroundDetectorFinder);
    detector.onDoubleTap?.call();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('background copy handler does not show feedback on android', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: ChatMessageWidget(
            message: UserMessage(
              id: 'msg_9',
              sessionId: 'ses_9',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_9',
                  messageId: 'msg_9',
                  sessionId: 'ses_9',
                  text: 'Android native clipboard feedback',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final backgroundDetectorFinder = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.behavior == HitTestBehavior.opaque &&
          widget.onDoubleTap != null,
    );
    final detector = tester.widget<GestureDetector>(backgroundDetectorFinder);
    detector.onDoubleTap?.call();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('double tap on text does not trigger background copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_8',
              sessionId: 'ses_8',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: const <MessagePart>[
                TextPart(
                  id: 'part_text_8',
                  messageId: 'msg_8',
                  sessionId: 'ses_8',
                  text: 'Word selection should win',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final textFinder = find.text('Word selection should win');
    await tester.tap(textFinder);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(textFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Copied to clipboard'), findsNothing);
  });

  testWidgets('tool completed output starts collapsed and can expand', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_completed',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_completed',
                  messageId: 'msg_tool_completed',
                  sessionId: 'ses_tool',
                  callId: 'call_1',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'cmd': 'ls -la'},
                    output: 'line 1\nline 2\nline 3\nline 4',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tool Call: bash'), findsNothing);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: ls -la'),
      ),
      findsOneWidget,
    );

    Text outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, 2);
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('tool_content_toggle_button')),
    );
    await tester.pumpAndSettle();

    outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, isNull);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('tool error output starts collapsed and can expand', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_error',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_error',
                  messageId: 'msg_tool_error',
                  sessionId: 'ses_tool',
                  callId: 'call_2',
                  tool: 'bash',
                  state: ToolStateError(
                    input: const <String, dynamic>{'cmd': 'cat missing.txt'},
                    error: 'error line 1\nerror line 2\nerror line 3',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tool Call: bash'), findsNothing);
    expect(find.text('bash'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: cat missing.txt'),
      ),
      findsOneWidget,
    );

    Text outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, 2);
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('tool_content_toggle_button')),
    );
    await tester.pumpAndSettle();

    outputText = tester.widget<Text>(
      find.byKey(const ValueKey<String>('tool_content_text')),
    );
    expect(outputText.maxLines, isNull);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('mobile tool status chip shows icon without label text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_tool_mobile_status',
              sessionId: 'ses_tool',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'part_tool_mobile_status',
                  messageId: 'msg_tool_mobile_status',
                  sessionId: 'ses_tool',
                  callId: 'call_mobile_1',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'pwd'},
                    output: '/tmp',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Completed'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.key == const ValueKey<String>('tool_command_text') &&
            widget.text.toPlainText().contains('Command: pwd'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'latest thinking stays expanded and previous thinking collapses on new block',
    (WidgetTester tester) async {
      AssistantMessage buildMessage(List<MessagePart> parts) {
        return AssistantMessage(
          id: 'msg_thinking',
          sessionId: 'ses_thinking',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: parts,
        );
      }

      Widget buildWidget(AssistantMessage message) {
        return MaterialApp(
          home: Scaffold(body: ChatMessageWidget(message: message)),
        );
      }

      const reasoningOne = ReasoningPart(
        id: 'thinking_1',
        messageId: 'msg_thinking',
        sessionId: 'ses_thinking',
        text: 'line 1\nline 2\nline 3\nline 4',
      );
      const reasoningTwo = ReasoningPart(
        id: 'thinking_2',
        messageId: 'msg_thinking',
        sessionId: 'ses_thinking',
        text: 'step 1\nstep 2\nstep 3\nstep 4',
      );

      await tester.pumpWidget(
        buildWidget(buildMessage(const <MessagePart>[reasoningOne])),
      );

      Text firstThinking = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_text_msg_thinking::thinking_1',
          ),
        ),
      );
      expect(firstThinking.maxLines, isNull);
      expect(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_toggle_msg_thinking::thinking_1',
          ),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(
        buildWidget(
          buildMessage(const <MessagePart>[reasoningOne, reasoningTwo]),
        ),
      );
      await tester.pumpAndSettle();

      firstThinking = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_text_msg_thinking::thinking_1',
          ),
        ),
      );
      final secondThinking = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_text_msg_thinking::thinking_2',
          ),
        ),
      );

      expect(firstThinking.maxLines, 2);
      expect(secondThinking.maxLines, isNull);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_toggle_msg_thinking::thinking_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      firstThinking = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>(
            'thinking_content_text_msg_thinking::thinking_1',
          ),
        ),
      );
      expect(firstThinking.maxLines, isNull);
    },
  );

  testWidgets(
    'thinking auto-collapses when latest reasoning moves to another message',
    (WidgetTester tester) async {
      final message = AssistantMessage(
        id: 'msg_a',
        sessionId: 'ses_thinking',
        time: DateTime.fromMillisecondsSinceEpoch(1000),
        parts: const <MessagePart>[
          ReasoningPart(
            id: 'thinking_a',
            messageId: 'msg_a',
            sessionId: 'ses_thinking',
            text: 'line 1\nline 2\nline 3\nline 4',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              activeReasoningPartKey: 'msg_a::thinking_a',
            ),
          ),
        ),
      );

      Text thinkingText = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>('thinking_content_text_msg_a::thinking_a'),
        ),
      );
      expect(thinkingText.maxLines, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: message,
              activeReasoningPartKey: 'msg_b::thinking_b',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      thinkingText = tester.widget<Text>(
        find.byKey(
          const ValueKey<String>('thinking_content_text_msg_a::thinking_a'),
        ),
      );
      expect(thinkingText.maxLines, 2);
    },
  );

  testWidgets('renders colorized diff for apply_patch tool', (tester) async {
    const diffOutput = '''--- file.dart
+++ file.dart
@@ -1,2 +1,3 @@
 context
-old line
+new line''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_1',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_1',
                  messageId: 'msg_diff_1',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_1',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Expandir para ver diff colorizado
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    // RichText deve estar presente (colorizado)
    expect(find.byType(RichText), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'renders colorized diff from apply_patch input when output is empty',
    (tester) async {
      const patchInput = '''*** Begin Patch
*** Update File: lib/main.dart
@@
-old line
+new line
*** End Patch''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageWidget(
              message: AssistantMessage(
                id: 'msg_diff_input_1',
                sessionId: 'ses_diff',
                time: DateTime.fromMillisecondsSinceEpoch(1000),
                parts: <MessagePart>[
                  ToolPart(
                    id: 'tool_diff_input_1',
                    messageId: 'msg_diff_input_1',
                    sessionId: 'ses_diff',
                    callId: 'call_diff_input_1',
                    tool: 'apply_patch',
                    state: ToolStateCompleted(
                      input: const <String, dynamic>{'patch': patchInput},
                      output: '',
                      time: ToolTime(
                        start: DateTime.fromMillisecondsSinceEpoch(1000),
                        end: DateTime.fromMillisecondsSinceEpoch(1100),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();

      expect(find.byType(RichText), findsAtLeastNWidgets(1));
    },
  );

  testWidgets('uses MediaQuery textScaler in expanded colorized diff', (
    tester,
  ) async {
    const diffOutput = '''--- file.dart
+++ file.dart
@@ -1,2 +1,3 @@
 context
-old line
+new line''';
    const expectedScaler = TextScaler.linear(1.2);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(
            context,
          ).copyWith(textScaler: expectedScaler);
          return MediaQuery(data: mediaQuery, child: child!);
        },
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_scaler',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_scaler',
                  messageId: 'msg_diff_scaler',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_scaler',
                  tool: 'apply_patch',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diffOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final diffRichText = richTexts.firstWhere(
      (richText) => richText.text.toPlainText().contains('+new line'),
    );

    expect(diffRichText.textScaler, isNotNull);
    expect(diffRichText.textScaler!.scale(10), expectedScaler.scale(10));
  });

  testWidgets('detects diff in bash git diff via heuristic', (tester) async {
    const gitDiff = '''diff --git a/lib/main.dart b/lib/main.dart
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,1 +1,2 @@
-old
+new''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_2',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_2',
                  messageId: 'msg_diff_2',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_2',
                  tool: 'bash', // Não é apply_patch, detecta via heurística
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'git diff'},
                    output: gitDiff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1150),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    // Deve colorizar mesmo sendo bash
    expect(find.byType(RichText), findsAtLeastNWidgets(1));
  });

  testWidgets('does not colorize normal bash output', (tester) async {
    const plainOutput = 'file1.txt\nfile2.txt';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_3',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_3',
                  messageId: 'msg_diff_3',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_3',
                  tool: 'bash',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{'command': 'ls'},
                    output: plainOutput,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1050),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Texto plano, sem expansão necessária (2 linhas)
    expect(find.text(plainOutput), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('preserves content when collapsing and expanding diff', (
    tester,
  ) async {
    const diff = '@@ -1,1 +1,2 @@\n-old\n+new';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_4',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_4',
                  messageId: 'msg_diff_4',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_4',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: diff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1080),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Expandir
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);

    // Colapsar
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsOneWidget);
  });

  testWidgets('renders colorized diff for edit tool', (tester) async {
    const editDiff = '''diff --git a/test.dart b/test.dart
index abc123..def456 100644
--- a/test.dart
+++ b/test.dart
@@ -10,5 +10,6 @@
 normal line
-removed line
+added line
 another normal line''';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_diff_5',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_diff_5',
                  messageId: 'msg_diff_5',
                  sessionId: 'ses_diff',
                  callId: 'call_diff_5',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{},
                    output: editDiff,
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1120),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Expandir
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    // RichText colorizado deve estar presente
    expect(find.byType(RichText), findsAtLeastNWidgets(1));
  });

  testWidgets('builds synthetic diff for edit tool when output is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageWidget(
            message: AssistantMessage(
              id: 'msg_edit_input',
              sessionId: 'ses_diff',
              time: DateTime.fromMillisecondsSinceEpoch(1000),
              parts: <MessagePart>[
                ToolPart(
                  id: 'tool_edit_input',
                  messageId: 'msg_edit_input',
                  sessionId: 'ses_diff',
                  callId: 'call_edit_input',
                  tool: 'edit',
                  state: ToolStateCompleted(
                    input: const <String, dynamic>{
                      'file_path': 'lib/sample.dart',
                      'old_string': 'line old',
                      'new_string': 'line new',
                    },
                    output: '',
                    time: ToolTime(
                      start: DateTime.fromMillisecondsSinceEpoch(1000),
                      end: DateTime.fromMillisecondsSinceEpoch(1100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    expect(find.byType(RichText), findsAtLeastNWidgets(1));
  });
}
