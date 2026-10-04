@TestOn('vm')
library;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schema_support.dart';

void main() {
  for (final delivery in <OpenValue<Delivery>?>[
    null,
    const OpenValue.known(Delivery.queue),
    const OpenValue.known(Delivery.steer),
    OpenValue<Delivery>.unknown('future-delivery'),
  ]) {
    test('prompt intent preserves optional delivery ${delivery?.value}', () {
      final draft = PromptDraft(text: 'Original input\n');
      final intent = <String, Object?>{
        'draft': {
          'text': draft.text,
          'attachments': draft.attachments.toList(),
          'mentions': draft.mentions.toList(),
        },
        if (delivery != null) 'delivery': delivery.toJson(),
      };
      final frame = cloneObject(loadExample('chp-command-prompt'));
      (frame['command'] as Map)['intent'] = intent;
      expect(isValidDefinition('CanonicalPromptIntent', intent), isTrue);
      expect(isValidDefinition('ChpCommand', frame), isTrue);
      expect(isValidDefinition('ChpFrame', frame), isTrue);
      final projected = (frame['command'] as Map)['intent'] as Map;
      expect((projected['draft'] as Map)['text'], draft.text);
      expect(projected.containsKey('delivery'), delivery != null);
      if (delivery != null) {
        final decoded = OpenValue.parse(
          projected['delivery'] as String,
          Delivery.values,
        );
        expect(decoded, delivery);
      }
    });
  }

  test(
    'old flattened prompt and malformed delivery are not silently accepted',
    () {
      final frame = loadExample('chp-command-prompt');
      final command = frame['command'] as Map;
      final intent = command['intent'] as Map;
      command['intent'] = intent['draft'];
      expect(isValidDefinition('ChpCommand', frame), isFalse);
      command['intent'] = {...intent, 'delivery': 42};
      expect(isValidDefinition('ChpCommand', frame), isFalse);
      command['intent'] = {...intent, 'delivery': null};
      expect(isValidDefinition('ChpCommand', frame), isFalse);
      command['intent'] = {...intent, 'unverifiedReplay': true};
      expect(isValidDefinition('ChpCommand', frame), isFalse);
    },
  );
}
