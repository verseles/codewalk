import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/utils/chat_assistant_settlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasCompletedRevealableAssistantMessage', () {
    test('does not search past the current user turn boundary', () {
      final messages = <ChatMessage>[
        AssistantMessage(
          id: 'assistant_previous',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_previous',
              messageId: 'assistant_previous',
              sessionId: 'ses_1',
              text: 'Previous final answer',
            ),
          ],
        ),
        UserMessage(
          id: 'user_next',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_next',
              messageId: 'user_next',
              sessionId: 'ses_1',
              text: 'Next turn',
            ),
          ],
        ),
      ];

      expect(
        hasCompletedRevealableAssistantMessage(messages, 'ses_1'),
        isFalse,
      );
    });

    test('accepts revealable text before a completed tool-only tail', () {
      final messages = <ChatMessage>[
        UserMessage(
          id: 'user_current',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_current',
              messageId: 'user_current',
              sessionId: 'ses_1',
              text: 'Current turn',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_final_text',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_final_text',
              messageId: 'assistant_final_text',
              sessionId: 'ses_1',
              text: 'Final answer',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_tool_tail',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2200),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2300),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_tool_tail',
              messageId: 'assistant_tool_tail',
              sessionId: 'ses_1',
              callId: 'call_tool_tail',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/tmp/project',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2200),
                  end: DateTime.fromMillisecondsSinceEpoch(2250),
                ),
              ),
            ),
          ],
        ),
      ];

      expect(hasCompletedRevealableAssistantMessage(messages, 'ses_1'), isTrue);
    });

    test('ignores structural step parts in completed tool-only tails', () {
      final messages = <ChatMessage>[
        UserMessage(
          id: 'user_tool_only',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_tool_only',
              messageId: 'user_tool_only',
              sessionId: 'ses_1',
              text: 'Run tool only',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_tool_only',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2300),
          parts: <MessagePart>[
            const StepFinishPart(
              id: 'part_step_finish',
              messageId: 'assistant_tool_only',
              sessionId: 'ses_1',
              reason: 'completed',
              cost: 0,
              tokens: MessageTokens(input: 0, output: 0),
            ),
            ToolPart(
              id: 'part_tool_only',
              messageId: 'assistant_tool_only',
              sessionId: 'ses_1',
              callId: 'call_tool_only',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/tmp/project',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2100),
                  end: DateTime.fromMillisecondsSinceEpoch(2200),
                ),
              ),
            ),
          ],
        ),
      ];

      expect(
        hasCompletedRevealableAssistantMessage(messages, 'ses_1'),
        isFalse,
      );
    });
  });

  group('isLatestTailSettledRevealable', () {
    test('latest completed revealable tail settles without navigation', () {
      final messages = <ChatMessage>[
        UserMessage(
          id: 'user_current',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_current',
              messageId: 'user_current',
              sessionId: 'ses_1',
              text: 'Current turn',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_final',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_final',
              messageId: 'assistant_final',
              sessionId: 'ses_1',
              text: 'Final answer',
            ),
          ],
        ),
      ];

      expect(isLatestTailSettledRevealable(messages, 'ses_1'), isTrue);
    });

    test('completed tool-only latest tail keeps progress visible', () {
      final messages = <ChatMessage>[
        UserMessage(
          id: 'user_current',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_current',
              messageId: 'user_current',
              sessionId: 'ses_1',
              text: 'Current turn',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_final_text',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_final_text',
              messageId: 'assistant_final_text',
              sessionId: 'ses_1',
              text: 'Final answer',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_tool_tail',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2200),
          completedTime: DateTime.fromMillisecondsSinceEpoch(2300),
          parts: <MessagePart>[
            ToolPart(
              id: 'part_tool_tail',
              messageId: 'assistant_tool_tail',
              sessionId: 'ses_1',
              callId: 'call_tool_tail',
              tool: 'bash',
              state: ToolStateCompleted(
                input: const <String, dynamic>{'command': 'pwd'},
                output: '/tmp/project',
                time: ToolTime(
                  start: DateTime.fromMillisecondsSinceEpoch(2200),
                  end: DateTime.fromMillisecondsSinceEpoch(2250),
                ),
              ),
            ),
          ],
        ),
      ];

      expect(isLatestTailSettledRevealable(messages, 'ses_1'), isFalse);
    });

    test('incomplete latest tail with text is not settled', () {
      final messages = <ChatMessage>[
        UserMessage(
          id: 'user_current',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_current',
              messageId: 'user_current',
              sessionId: 'ses_1',
              text: 'Current turn',
            ),
          ],
        ),
        AssistantMessage(
          id: 'assistant_streaming',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_streaming',
              messageId: 'assistant_streaming',
              sessionId: 'ses_1',
              text: 'Partial answer',
            ),
          ],
        ),
      ];

      expect(isLatestTailSettledRevealable(messages, 'ses_1'), isFalse);
    });

    test('latest user message is not settled', () {
      final messages = <ChatMessage>[
        AssistantMessage(
          id: 'assistant_previous',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(1000),
          completedTime: DateTime.fromMillisecondsSinceEpoch(1100),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_previous',
              messageId: 'assistant_previous',
              sessionId: 'ses_1',
              text: 'Previous final answer',
            ),
          ],
        ),
        UserMessage(
          id: 'user_next',
          sessionId: 'ses_1',
          time: DateTime.fromMillisecondsSinceEpoch(2000),
          parts: const <MessagePart>[
            TextPart(
              id: 'part_user_next',
              messageId: 'user_next',
              sessionId: 'ses_1',
              text: 'Next turn',
            ),
          ],
        ),
      ];

      expect(isLatestTailSettledRevealable(messages, 'ses_1'), isFalse);
    });
  });
}
