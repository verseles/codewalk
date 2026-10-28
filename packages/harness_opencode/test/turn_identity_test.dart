import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:harness_opencode/src/revert_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'inbox_test_data.dart';
import 'revert_test_data.dart';

void main() {
  test(
    'history confirms persisted user identity without presentation metadata',
    () {
      final items = projectOpenCodeHistory(
        [
          message('a', 'user', {'text': 'question'}),
          assistant('c', [textBlock('answer')], completed: true),
        ],
        historyRef,
        sourceVersion: '2.0.22',
      );
      final user = items.first as UserInput;
      expect(user.confirmed, isTrue);
      expect(
        user.delivery.known,
        isNull,
        reason: 'confirmation is independent of unknown historical delivery',
      );
      expect(
        user.meta.message,
        isNull,
        reason: 'no assistant details chip appears on a user message',
      );
      expect(user.meta.anchor!.message, MessageRef('msg_a'));
      expect(user.meta.anchor!.compareTo(items.last.meta.anchor!), lessThan(0));
    },
  );

  test('a native-looking pending echo is not a confirmed undo target', () {
    var state = SessionState(historyRef);
    state = applyInbox(inboxFrame('enqueued', inbox: 'msg_a'), state, 1);
    final pendingUser = state.timeline.single as UserInput;
    expect(pendingUser.confirmed, isFalse);
    expect(pendingUser.meta.anchor, state.pending.single.anchor);
    state = applyInbox(
      inboxFrame('delivered', id: 'evt_delivered', inbox: 'msg_a'),
      state,
      2,
    );
    final delivered = state.timeline.single as UserInput;
    expect(delivered.confirmed, isTrue);
    expect(delivered.meta.anchor, pendingUser.meta.anchor);
    expect(state.pending, isEmpty);
  });

  test('live and hydrated nonresident revert keep the same typed cut', () {
    final state = seededState(
      messages: [
        message('c', 'user', {'text': 'later'}),
      ],
      pending: ['msg_d'],
    );
    final staged = projectRevert(
      revertFrame('staged'),
      current: state,
    ).whereType<RevertChanged>().single.state;
    final hydrated = openCodeStagedRevert(
      revertData(),
      historyRef,
      state.timeline,
    );
    expect(staged.boundary, isNull);
    expect(hydrated.boundary, isNull);
    expect(staged.anchor, hydrated.anchor);
    expect(staged.anchor!.message, MessageRef('msg_b'));
    expect(
      staged.anchor!.compareTo(state.timeline.single.meta.anchor!),
      lessThan(0),
    );
    expect(staged.anchor!.compareTo(state.pending.single.anchor!), lessThan(0));
    final clear = projectRevert(
      revertFrame('cleared'),
      current: state,
    ).whereType<RevertChanged>().single.state;
    expect(clear.anchor, isNull);
  });
}
