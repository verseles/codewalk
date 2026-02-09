import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/data/models/chat_message_model.dart';
import 'package:codewalk/domain/entities/chat_message.dart';

void main() {
  group('ChatMessageModel', () {
    test('synthesizes user text from summary object when parts are empty', () {
      final model = ChatMessageModel.fromJson(<String, dynamic>{
        'id': 'msg_user_1',
        'sessionID': 'ses_1',
        'role': 'user',
        'time': <String, dynamic>{'created': 1000, 'completed': 1000},
        'summary': <String, dynamic>{
          'title': 'Refactor',
          'body': 'Improve provider parsing',
          'diffs': <dynamic>[
            <String, dynamic>{
              'file': 'lib/provider.dart',
              'after': 'new content',
            },
          ],
        },
        'parts': <dynamic>[],
      });

      final message = model.toDomain();
      expect(message, isA<UserMessage>());
      expect(message.parts, hasLength(1));
      final textPart = message.parts.single as TextPart;
      expect(textPart.text, contains('Refactor'));
      expect(textPart.text, contains('Improve provider parsing'));
      expect(textPart.text, contains('File: lib/provider.dart'));
      expect(textPart.text, contains('new content'));
    });

    test('parses assistant completion timestamp and summary flag', () {
      final model = ChatMessageModel.fromJson(<String, dynamic>{
        'id': 'msg_ai_1',
        'sessionID': 'ses_1',
        'role': 'assistant',
        'time': <String, dynamic>{'created': 2000, 'completed': 3000},
        'summary': true,
        'parts': <dynamic>[
          <String, dynamic>{
            'id': 'prt_1',
            'messageID': 'msg_ai_1',
            'sessionID': 'ses_1',
            'type': 'text',
            'text': 'done',
          },
        ],
      });

      final message = model.toDomain() as AssistantMessage;
      expect(message.completedTime, DateTime.fromMillisecondsSinceEpoch(3000));
      expect(message.isCompleted, isTrue);
      expect(message.summary, isTrue);
      expect((message.parts.single as TextPart).text, 'done');
    });

    test('parses extended part taxonomy without data loss', () {
      final model = ChatMessageModel.fromJson(<String, dynamic>{
        'id': 'msg_ai_parts',
        'sessionID': 'ses_1',
        'role': 'assistant',
        'time': <String, dynamic>{'created': 1000, 'completed': 1100},
        'parts': <dynamic>[
          <String, dynamic>{
            'id': 'prt_agent',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'agent',
            'name': 'planner',
            'source': <String, dynamic>{
              'value': 'agent prompt',
              'start': 0,
              'end': 12,
            },
          },
          <String, dynamic>{
            'id': 'prt_step_start',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'step-start',
            'snapshot': 'snap_a',
          },
          <String, dynamic>{
            'id': 'prt_step_finish',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'step-finish',
            'reason': 'completed',
            'cost': 0.42,
            'tokens': <String, dynamic>{
              'input': 10,
              'output': 20,
              'reasoning': 5,
              'cache': <String, dynamic>{'read': 1, 'write': 2},
            },
          },
          <String, dynamic>{
            'id': 'prt_subtask',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'subtask',
            'prompt': 'run tests',
            'description': 'execute test suite',
            'agent': 'tester',
            'model': <String, dynamic>{
              'providerID': 'openai',
              'modelID': 'gpt-4.1',
            },
          },
          <String, dynamic>{
            'id': 'prt_retry',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'retry',
            'attempt': 2,
            'error': <String, dynamic>{
              'name': 'APIError',
              'data': <String, dynamic>{
                'message': 'rate limited',
                'isRetryable': true,
                'statusCode': 429,
              },
            },
            'time': <String, dynamic>{'created': 1050},
          },
          <String, dynamic>{
            'id': 'prt_compaction',
            'messageID': 'msg_ai_parts',
            'sessionID': 'ses_1',
            'type': 'compaction',
            'auto': true,
          },
        ],
      });

      final message = model.toDomain() as AssistantMessage;
      expect(message.parts.whereType<AgentPart>().single.name, 'planner');
      expect(
        message.parts.whereType<StepStartPart>().single.snapshot,
        'snap_a',
      );
      expect(message.parts.whereType<StepFinishPart>().single.tokens.total, 35);
      expect(
        message.parts.whereType<SubtaskPart>().single.model?.providerId,
        'openai',
      );
      expect(message.parts.whereType<RetryPart>().single.attempt, 2);
      expect(message.parts.whereType<CompactionPart>().single.auto, isTrue);
    });
  });
}
