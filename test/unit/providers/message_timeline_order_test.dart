import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/providers/chat_provider/message_timeline_order.dart';
import 'package:flutter_test/flutter_test.dart';

const _sessionId = 'ses_main';

UserMessage _user(String id, int millis) {
  return UserMessage(
    id: id,
    sessionId: _sessionId,
    time: DateTime.fromMillisecondsSinceEpoch(millis),
    parts: const <MessagePart>[],
  );
}

AssistantMessage _assistant(String id, int millis) {
  return AssistantMessage(
    id: id,
    sessionId: _sessionId,
    time: DateTime.fromMillisecondsSinceEpoch(millis),
  );
}

List<String> _ids(List<ChatMessage> messages) =>
    messages.map((message) => message.id).toList();

void main() {
  group('timelineInsertIndexForLocalMessage', () {
    test('inserts before the assistant when the snapshot is assistant-only',
        () {
      // #179 stall shape: visible [local prompt, assistant], server refresh
      // only knows the assistant.
      final local = <ChatMessage>[
        _user('local_user_1_0', 5000),
        _assistant('msg_a1', 4000),
      ];
      final target = <ChatMessage>[_assistant('msg_a1', 4000)];

      final index = timelineInsertIndexForLocalMessage(
        target: target,
        localSnapshot: local,
        localIndex: 0,
      );

      expect(index, 0);
    });

    test('uses the preceding anchor when neighbours survived', () {
      final local = <ChatMessage>[
        _user('msg_u1', 1000),
        _assistant('msg_a1', 2000),
        _user('local_user_2_0', 3000),
      ];
      final target = <ChatMessage>[
        _user('msg_u1', 1000),
        _assistant('msg_a1', 2000),
      ];

      final index = timelineInsertIndexForLocalMessage(
        target: target,
        localSnapshot: local,
        localIndex: 2,
      );

      expect(index, 2);
    });

    test('ignores clock skew: client-ahead optimistic still precedes', () {
      // Device clock far ahead of the server clock.
      final local = <ChatMessage>[_user('local_user_9_0', 999999)];
      final target = <ChatMessage>[_assistant('msg_a9', 1000)];

      final index = timelineInsertIndexForLocalMessage(
        target: target,
        localSnapshot: local,
        localIndex: 0,
      );

      expect(index, 0);
    });

    test('appends a non-user local with no anchors', () {
      final local = <ChatMessage>[_user('local_user_3_0', 1000)];
      final target = <ChatMessage>[_user('msg_u0', 500)];

      final index = timelineInsertIndexForLocalMessage(
        target: target,
        localSnapshot: local,
        localIndex: 0,
      );

      // A user with no assistant ahead appends (genuinely newest send).
      expect(index, 1);
    });

    test('appends when every assistant run already has its prompt', () {
      // Disjoint refresh: the visible prompt shares no IDs with a server
      // tail whose assistants are all prompted. It is newest: append.
      final local = <ChatMessage>[_user('local_user_4_0', 9000)];
      final target = <ChatMessage>[
        _user('msg_u7', 1000),
        _assistant('msg_a7', 2000),
      ];

      final index = timelineInsertIndexForLocalMessage(
        target: target,
        localSnapshot: local,
        localIndex: 0,
      );

      expect(index, 2);
    });
  });

  group('healPersistedTimelineInversions', () {
    test('heals a fresh-session [assistant, local] inversion', () {
      final messages = <ChatMessage>[
        _assistant('msg_a1', 2000),
        _user('local_user_1_0', 5000),
      ];

      final healed = healPersistedTimelineInversions(messages);

      expect(_ids(healed), <String>['local_user_1_0', 'msg_a1']);
    });

    test('leaves a valid in-flight second turn untouched', () {
      final messages = <ChatMessage>[
        _user('msg_u1', 1000),
        _assistant('msg_a1', 2000),
        _user('local_user_2_0', 3000),
      ];

      final healed = healPersistedTimelineInversions(messages);

      expect(identical(healed, messages), isTrue);
      expect(
        _ids(healed),
        <String>['msg_u1', 'msg_a1', 'local_user_2_0'],
      );
    });

    test('leaves an all-optimistic two-turn snapshot untouched', () {
      // Both prompts still await their echoes: the second prompt must not
      // be hoisted above the first assistant reply.
      final messages = <ChatMessage>[
        _user('local_user_1_0', 1000),
        _assistant('msg_a1', 2000),
        _user('local_user_2_0', 3000),
      ];

      final healed = healPersistedTimelineInversions(messages);

      expect(identical(healed, messages), isTrue);
    });

    test('leaves confirmed-only order untouched', () {
      final messages = <ChatMessage>[
        _assistant('msg_a1', 2000),
        _user('msg_u1', 1000),
      ];

      final healed = healPersistedTimelineInversions(messages);

      expect(identical(healed, messages), isTrue);
    });
  });
}
