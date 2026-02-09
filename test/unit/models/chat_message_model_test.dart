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
  });
}
