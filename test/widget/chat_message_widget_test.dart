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

    expect(find.byType(SelectableText), findsWidgets);
    expect(find.byTooltip('Copy'), findsNothing);
  });

  testWidgets('user text keeps copy button', (WidgetTester tester) async {
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

    expect(find.byTooltip('Copy'), findsOneWidget);
  });
}
