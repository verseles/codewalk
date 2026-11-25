import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'support/scripted_harness_scenarios.dart';

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

MessageContext _step(
  String id, {
  int? createdMs = 1000,
  int? firstTokenMs,
  int? streamedMs,
  int? completedMs,
  num? output,
  num? reasoning,
  bool omitTokens = false,
}) => MessageContext(
  message: MessageRef(id),
  created: createdMs == null ? null : _ms(createdMs),
  firstToken: firstTokenMs == null ? null : _ms(firstTokenMs),
  streamed: streamedMs == null ? null : _ms(streamedMs),
  completed: completedMs == null ? null : _ms(completedMs),
  tokens: omitTokens
      ? null
      : TokenBreakdown(input: 100, output: output, reasoning: reasoning),
);

ItemMeta _meta(
  String id, {
  MessageContext? message,
  ItemStatus status = ItemStatus.completed,
}) => ItemMeta(
  id: ItemId(id),
  generation: 'g1',
  status: OpenValue.known(status),
  source: SourceProvenance(
    harness: ownedRef.harnessRef,
    version: '2.3.2',
    nativeType: 'assistant',
  ),
  message: message,
);

UserInput _user(
  String id, {
  DeliveryState delivery = DeliveryState.delivered,
  bool confirmed = true,
}) => UserInput(
  meta: _meta(id),
  text: 'Prompt $id',
  delivery: OpenValue.known(delivery),
  confirmed: confirmed,
);

AssistantText _answer(
  String id,
  String text, {
  MessageContext? message,
  bool complete = true,
  ItemStatus status = ItemStatus.completed,
}) => AssistantText(
  meta: _meta(id, message: message, status: status),
  text: text,
  complete: complete,
);

void main() {
  group('computeTurnTokensPerSecond', () {
    test('uses output + reasoning over streamed - firstToken', () {
      final tps = computeTurnTokensPerSecond([
        _step(
          'msg_1',
          createdMs: 1000,
          firstTokenMs: 2000,
          streamedMs: 4000,
          completedMs: 6000,
          output: 60,
          reasoning: 40,
        ),
      ]);
      // 100 tokens over 2000 ms (4000 - 2000) = 50.0 tok/s (ignores completed).
      expect(tps, closeTo(50.0, 1e-9));
    });

    test('falls back to created when firstToken is absent', () {
      final tps = computeTurnTokensPerSecond([
        _step('msg_1', createdMs: 1000, streamedMs: 3500, output: 50),
      ]);
      // 50 tokens over 2500 ms = 20.0 tok/s.
      expect(tps, closeTo(20.0, 1e-9));
    });

    test('aggregates multiple distinct steps and deduplicates parts', () {
      final step1a = _step(
        'msg_1',
        createdMs: 1000,
        firstTokenMs: 1500,
        streamedMs: 3500,
        output: 40,
        reasoning: 20,
      );
      final step1b = MessageContext(
        message: MessageRef('msg_1'),
        created: _ms(1000),
      );
      final step2 = _step(
        'msg_2',
        createdMs: 4000,
        firstTokenMs: 5000,
        streamedMs: 8000,
        output: 90,
      );
      // Total tokens: (40 + 20) + 90 = 150; total ms: 2000 + 3000 = 5000 ms -> 30.0.
      final tps = computeTurnTokensPerSecond([step1a, step1b, step2]);
      expect(tps, closeTo(30.0, 1e-9));
    });

    test('returns null when any step lacks streamed, start, or tokens', () {
      // Never fabricates from completed - created.
      expect(
        computeTurnTokensPerSecond([
          _step('msg_1', createdMs: 1000, completedMs: 3000, output: 100),
        ]),
        isNull,
      );
      // Multi-step turn missing streamed on one step returns null.
      expect(
        computeTurnTokensPerSecond([
          _step(
            'msg_1',
            createdMs: 1000,
            firstTokenMs: 1500,
            streamedMs: 2500,
            output: 50,
          ),
          _step('msg_2', createdMs: 3000, completedMs: 5000, output: 50),
        ]),
        isNull,
      );
      // Missing start time.
      expect(
        computeTurnTokensPerSecond([
          _step('msg_1', createdMs: null, streamedMs: 2500, output: 50),
        ]),
        isNull,
      );
      // Missing token breakdown or both output & reasoning null.
      expect(
        computeTurnTokensPerSecond([
          _step('msg_1', createdMs: 1000, streamedMs: 2500, omitTokens: true),
        ]),
        isNull,
      );
      expect(
        computeTurnTokensPerSecond([
          _step('msg_1', createdMs: 1000, streamedMs: 2500),
        ]),
        isNull,
      );
      // Zero tokens or zero/negative elapsed time.
      expect(
        computeTurnTokensPerSecond([
          _step('msg_1', createdMs: 1000, streamedMs: 2500, output: 0),
        ]),
        isNull,
      );
      expect(
        computeTurnTokensPerSecond([
          _step(
            'msg_1',
            createdMs: 1000,
            firstTokenMs: 3000,
            streamedMs: 2500,
            output: 50,
          ),
        ]),
        isNull,
      );
      expect(computeTurnTokensPerSecond(const []), isNull);
    });
  });

  group('resolveTurnTokensPerSecondByAnswer', () {
    test('maps only the final completed non-empty answer of each turn', () {
      final t1s1 = _step(
        'm1',
        createdMs: 1000,
        firstTokenMs: 1200,
        streamedMs: 2200,
        output: 20,
        reasoning: 10,
      );
      final t1s2 = _step(
        'm2',
        createdMs: 3000,
        firstTokenMs: 3500,
        streamedMs: 5500,
        output: 90,
      );
      final t2s1 = _step(
        'm3',
        createdMs: 7000,
        firstTokenMs: 7500,
        streamedMs: 9500,
        output: 80,
      );

      final items = <TimelineItem>[
        _user('u1'),
        Reasoning(
          meta: _meta('r1', message: t1s1),
          text: 'think',
          complete: true,
        ),
        _answer('a1', 'Intermediate', message: t1s1),
        ToolCall(
          meta: _meta('tc1', message: t1s1),
          kind: const OpenValue.known(ToolKind.read),
          rawName: 'read',
        ),
        _answer('a2', 'Final answer 1', message: t1s2),
        _answer('a2_blank', '   ', message: t1s2),
        // Draft / unconfirmed user message does not split the turn.
        _user('u_draft', delivery: DeliveryState.draft, confirmed: false),
        _user('u2'),
        _answer('a3', 'Final answer 2', message: t2s1),
      ];

      final map = resolveTurnTokensPerSecondByAnswer(items);
      expect(
        map.keys,
        unorderedEquals([const ItemId('a2'), const ItemId('a3')]),
      );
      // Turn 1: (30 + 90) / (1.0 + 2.0) = 40.0 tok/s.
      expect(map[const ItemId('a2')], closeTo(40.0, 1e-9));
      // Turn 2: 80 / 2.0 = 40.0 tok/s.
      expect(map[const ItemId('a3')], closeTo(40.0, 1e-9));
    });

    test('skips streaming, failed, interrupted, and aborted-notice turns', () {
      final good = _step(
        'm_ok',
        createdMs: 1000,
        firstTokenMs: 1500,
        streamedMs: 2500,
        output: 40,
      );

      final streamingTurn = <TimelineItem>[
        _user('u1'),
        _answer(
          'a_stream',
          'Halfway',
          message: good,
          complete: false,
          status: ItemStatus.streaming,
        ),
      ];
      expect(resolveTurnTokensPerSecondByAnswer(streamingTurn), isEmpty);

      final streamingToolTurn = <TimelineItem>[
        _user('u1'),
        _answer('a_prev', 'Step 1 answer', message: good),
        ToolCall(
          meta: _meta('tc_run', status: ItemStatus.streaming),
          kind: const OpenValue.known(ToolKind.read),
          rawName: 'read',
        ),
      ];
      expect(resolveTurnTokensPerSecondByAnswer(streamingToolTurn), isEmpty);

      final failedTurn = <TimelineItem>[
        _user('u1'),
        _answer('a_fail', 'Partial', message: good),
        TurnOutcome(
          meta: _meta('out_fail'),
          kind: const OpenValue.known(OutcomeKind.failed),
        ),
      ];
      expect(resolveTurnTokensPerSecondByAnswer(failedTurn), isEmpty);

      final interruptedNoticeTurn = <TimelineItem>[
        _user('u1'),
        _answer('a_abort', 'Partial', message: good),
        Notice(
          meta: _meta('n_abort', status: ItemStatus.interrupted),
          kind: const OpenValue.known(NoticeKind.interruption),
          text: '',
        ),
      ];
      expect(
        resolveTurnTokensPerSecondByAnswer(interruptedNoticeTurn),
        isEmpty,
      );
    });

    test('an open trailing turn and a cut leading turn are not whole', () {
      final step1 = _step(
        'm1',
        createdMs: 1000,
        firstTokenMs: 1500,
        streamedMs: 2500,
        output: 40,
      );
      final step2 = _step(
        'm2',
        createdMs: 3000,
        firstTokenMs: 3500,
        streamedMs: 4500,
        output: 60,
      );
      // Between two steps of a running turn every resident item is done.
      final running = <TimelineItem>[
        _user('u1'),
        _answer('a1', 'First turn', message: step1),
        _user('u2'),
        _answer('a2', 'Step 1 of a running turn', message: step2),
      ];
      final open = resolveTurnTokensPerSecondByAnswer(
        running,
        trailingTurnClosed: false,
      );
      expect(open.keys, [const ItemId('a1')]);
      expect(
        resolveTurnTokensPerSecondByAnswer(running).keys,
        unorderedEquals([const ItemId('a1'), const ItemId('a2')]),
      );

      // A window that begins mid-turn skips that leading turn.
      final cut = <TimelineItem>[
        _answer('a0', 'Tail of an evicted turn', message: step1),
        _user('u2'),
        _answer('a2', 'Whole turn', message: step2),
      ];
      expect(resolveTurnTokensPerSecondByAnswer(cut).keys, [
        const ItemId('a2'),
      ]);
      expect(resolveTurnTokensPerSecondByAnswer([cut.first]), isEmpty);
    });

    test('an unknown assistant part is a step of its turn', () {
      final timed = _step(
        'm1',
        createdMs: 1000,
        firstTokenMs: 1500,
        streamedMs: 2500,
        output: 40,
      );
      UnknownItem unknown(MessageContext context) => UnknownItem(
        meta: _meta('unk_${context.message.value}', message: context),
        rawType: 'assistant',
        raw: CanonicalValue({'reason': 'emptyAssistantContent'}),
      );
      // The unknown step has no streamed time, so the turn is not whole.
      final untimed = _step('m0', createdMs: 500, output: 10);
      expect(
        resolveTurnTokensPerSecondByAnswer([
          _user('u1'),
          unknown(untimed),
          _answer('a1', 'Answer', message: timed),
        ]),
        isEmpty,
      );
      // A timed unknown step joins the sums: (10 + 40) / 2.0 s = 25.0.
      final timedUnknown = _step(
        'm0',
        createdMs: 0,
        firstTokenMs: 500,
        streamedMs: 1500,
        output: 10,
      );
      final map = resolveTurnTokensPerSecondByAnswer([
        _user('u1'),
        unknown(timedUnknown),
        _answer('a1', 'Answer', message: timed),
      ]);
      expect(map[const ItemId('a1')], closeTo(25.0, 1e-9));
    });
  });
}
