import 'package:codewalk/domain/entities/chat_message.dart';
import 'package:codewalk/presentation/providers/chat_provider/message_reconciliation.dart';
import 'package:flutter_test/flutter_test.dart';

const _sessionId = 'ses_main';

ChatMessage _msg(String id, int millis, {String sessionId = _sessionId}) {
  return UserMessage(
    id: id,
    sessionId: sessionId,
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

UserMessage _textUser(
  String id,
  int millis,
  String text, {
  String sessionId = _sessionId,
}) {
  return UserMessage(
    id: id,
    sessionId: sessionId,
    time: DateTime.fromMillisecondsSinceEpoch(millis),
    parts: <MessagePart>[
      TextPart(
        id: 'prt_$id',
        messageId: id,
        sessionId: sessionId,
        text: text,
      ),
    ],
  );
}

List<String> _ids(List<ChatMessage> messages) =>
    messages.map((message) => message.id).toList();

void main() {
  group('non-regressive reconciliation', () {
    test('a stale snapshot cannot drop a newer message already on screen', () {
      final previous = <ChatMessage>[_msg('old', 1000), _msg('recent', 3000)];
      // A delayed payload that only knows about the old message.
      final next = <ChatMessage>[_msg('old', 1000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );

      expect(outcome.decision, MessageUpdateDecision.mergedNonRegressive);
      expect(_ids(outcome.messages), <String>['old', 'recent']);
      expect(outcome.preservedIds, <String>['recent']);
    });

    test('a partial delta does not erase the rest of the conversation', () {
      final previous = <ChatMessage>[
        _msg('a', 1000),
        _msg('b', 2000),
        _msg('c', 3000),
      ];
      final next = <ChatMessage>[_msg('b', 2000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.partialDelta,
        sessionId: _sessionId,
      );

      expect(outcome.decision, MessageUpdateDecision.mergedNonRegressive);
      expect(_ids(outcome.messages), <String>['a', 'b', 'c']);
      expect(outcome.preservedIds, <String>['a', 'c']);
    });

    test('preserved messages are reinserted in timeline order', () {
      final previous = <ChatMessage>[
        _msg('a', 1000),
        _msg('b', 2000),
        _msg('z', 9000),
      ];
      final next = <ChatMessage>[_msg('a', 1000), _msg('b', 2000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );

      expect(_ids(outcome.messages), <String>['a', 'b', 'z']);
    });

    test(
      'a newer snapshot may drop messages older than everything it carries',
      () {
        final previous = <ChatMessage>[_msg('gone', 1000), _msg('kept', 2000)];
        // Server dropped an old message and reports newer state alongside it.
        final next = <ChatMessage>[_msg('kept', 2000), _msg('fresh', 4000)];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(outcome.decision, MessageUpdateDecision.applied);
        expect(_ids(outcome.messages), <String>['kept', 'fresh']);
      },
    );

    test('an authoritative removal still removes the newest message', () {
      final previous = <ChatMessage>[_msg('old', 1000), _msg('newest', 5000)];
      final next = <ChatMessage>[_msg('old', 1000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.authoritativeRemoval,
        sessionId: _sessionId,
      );

      expect(outcome.decision, MessageUpdateDecision.applied);
      expect(_ids(outcome.messages), <String>['old']);
    });

    test('a reset may empty the collection', () {
      final previous = <ChatMessage>[_msg('a', 1000), _msg('b', 2000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: const <ChatMessage>[],
        kind: MessageUpdateKind.reset,
        sessionId: _sessionId,
      );

      expect(outcome.decision, MessageUpdateDecision.applied);
      expect(outcome.messages, isEmpty);
    });

    test('an empty stale payload never wipes a live conversation', () {
      final previous = <ChatMessage>[_msg('a', 1000), _msg('b', 2000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: const <ChatMessage>[],
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );

      expect(outcome.decision, MessageUpdateDecision.mergedNonRegressive);
      expect(_ids(outcome.messages), <String>['a', 'b']);
    });

    test('other sessions in the collection are not judged', () {
      final previous = <ChatMessage>[
        _msg('main_a', 1000),
        _msg('child_a', 5000, sessionId: 'ses_child'),
      ];
      final next = <ChatMessage>[_msg('main_a', 1000)];

      final outcome = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );

      // The child message was out of scope, so its absence is not a regression.
      expect(outcome.decision, MessageUpdateDecision.applied);
      expect(_ids(outcome.messages), <String>['main_a']);
    });

    test('applying the same payload twice is stable', () {
      final previous = <ChatMessage>[_msg('a', 1000), _msg('b', 2000)];
      final next = <ChatMessage>[_msg('a', 1000), _msg('b', 2000)];

      final first = reconcileMessages(
        previous: previous,
        next: next,
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );
      final second = reconcileMessages(
        previous: first.messages,
        next: next,
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      );

      expect(_ids(second.messages), _ids(first.messages));
      expect(second.decision, MessageUpdateDecision.applied);
    });

    test('out-of-order arrivals converge to the union, in order', () {      // Simulates: fresh state on screen, then a late fallback, then a refresh.
      var state = <ChatMessage>[_msg('a', 1000), _msg('newest', 4000)];

      state = reconcileMessages(
        previous: state,
        next: <ChatMessage>[_msg('a', 1000)],
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      ).messages;

      state = reconcileMessages(
        previous: state,
        next: <ChatMessage>[_msg('a', 1000), _msg('b', 2000)],
        kind: MessageUpdateKind.fullSnapshot,
        sessionId: _sessionId,
      ).messages;

      expect(_ids(state), <String>['a', 'b', 'newest']);
    });

    test(
      'an optimistic local survives an assistant-only snapshot '
      'regardless of clock skew (issue #179)',
      () {
        // Device clock ahead of the server clock: the local bubble looks
        // "newer" than everything the payload carries.
        final previous = <ChatMessage>[
          _msg('local_user_1_0', 999999),
          _assistant('msg_assistant_1', 2000),
        ];
        final next = <ChatMessage>[_assistant('msg_assistant_1', 2000)];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(outcome.decision, MessageUpdateDecision.mergedNonRegressive);
        expect(
          _ids(outcome.messages),
          <String>['local_user_1_0', 'msg_assistant_1'],
        );
        expect(outcome.preservedIds, <String>['local_user_1_0']);
      },
    );

    test(
      'a reconciled optimistic is not resurrected when its echo is present',
      () {
        final echo = UserMessage(
          id: 'msg_user_2',
          sessionId: _sessionId,
          time: DateTime.fromMillisecondsSinceEpoch(2900),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_echo',
              messageId: 'msg_user_2',
              sessionId: _sessionId,
              text: 'hello',
            ),
          ],
        );
        final local = UserMessage(
          id: 'local_user_2_0',
          sessionId: _sessionId,
          time: DateTime.fromMillisecondsSinceEpoch(3000),
          parts: const <MessagePart>[
            TextPart(
              id: 'prt_local',
              messageId: 'local_user_2_0',
              sessionId: _sessionId,
              text: 'hello',
            ),
          ],
        );
        final next = <ChatMessage>[
          echo,
          _assistant('msg_assistant_2', 3100),
        ];

        final outcome = reconcileMessages(
          previous: <ChatMessage>[local, _assistant('msg_assistant_2', 3100)],
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(outcome.decision, MessageUpdateDecision.applied);
        expect(_ids(outcome.messages), <String>['msg_user_2', 'msg_assistant_2']);
      },
    );

    test(
      'a shell-mode echo without the bang prefix reconciles the optimistic',
      () {
        final previous = <ChatMessage>[
          _textUser('local_user_3_0', 3000, '!ls -la'),
          _assistant('msg_assistant_3', 3100),
        ];
        final next = <ChatMessage>[
          _textUser('msg_user_3', 2900, 'ls -la'),
          _assistant('msg_assistant_3', 3100),
        ];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(outcome.decision, MessageUpdateDecision.applied);
        expect(
          _ids(outcome.messages),
          <String>['msg_user_3', 'msg_assistant_3'],
        );
      },
    );

    test(
      'a stale snapshot cannot drop a newer server message beside a '
      'clock-skewed optimistic',
      () {
        // Device clock ahead: newestInNext must ignore the optimistic bubble
        // or the live server message looks stale and is discarded (#111).
        final previous = <ChatMessage>[
          _msg('server_user', 1000),
          _msg('server_new', 5000),
          _msg('local_user_4_0', 999999),
        ];
        final next = <ChatMessage>[
          _msg('server_user', 1000),
          _msg('local_user_4_0', 999999),
        ];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(outcome.decision, MessageUpdateDecision.mergedNonRegressive);
        expect(
          _ids(outcome.messages),
          <String>['server_user', 'server_new', 'local_user_4_0'],
        );
      },
    );

    test(
      'an anchorless optimistic prompt splices before a prompt-less reply',
      () {
        final previous = <ChatMessage>[_msg('local_user_5_0', 9000)];
        final next = <ChatMessage>[_assistant('msg_assistant_5', 1000)];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        expect(
          _ids(outcome.messages),
          <String>['local_user_5_0', 'msg_assistant_5'],
        );
      },
    );

    test(
      'preserved messages keep previous relative order even when '
      'timestamps disagree',
      () {
        final previous = <ChatMessage>[
          _msg('a', 1000),
          _msg('mid', 5000),
          _msg('new', 2000),
        ];
        final next = <ChatMessage>[_msg('a', 1000)];

        final outcome = reconcileMessages(
          previous: previous,
          next: next,
          kind: MessageUpdateKind.fullSnapshot,
          sessionId: _sessionId,
        );

        // Previous relative order wins over wall-clock sorting.
        expect(_ids(outcome.messages), <String>['a', 'mid', 'new']);
      },
    );
  });
}
