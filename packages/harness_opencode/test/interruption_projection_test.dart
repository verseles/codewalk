import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'step_usage_test_data.dart';

void main() {
  const aborted = {'type': 'aborted', 'message': 'private interruption text'};

  for (final blocks in <List<Object?>>[
    [],
    [textBlock('partial')],
  ]) {
    test('aborted history step is visible without idle: $blocks', () {
      final items = projectOpenCodeHistory(
        [
          assistant(
            'step',
            blocks,
            completed: true,
            fields: {'error': aborted},
          ),
        ],
        historyRef,
        sourceVersion: '2.0.22',
      );
      final notice = items.whereType<Notice>().single;
      final events = projectStepUsage(
        stepFrame('failed', fields: {'error': aborted}),
      );
      final live = events.whereType<ItemUpserted>().single.item as Notice;
      expect(notice.kind.known, NoticeKind.interruption);
      expect(notice.status.known, ItemStatus.interrupted);
      expect(notice.text, isEmpty);
      expect(notice.id, live.id);
      expect(notice.meta.anchor, live.meta.anchor);
      expect(live.kind, notice.kind);
      expect(live.status, notice.status);
      expect(live.text, isEmpty);
      expect(items.whereType<TurnOutcome>(), isEmpty);
      expect(events.whereType<ExecutionChanged>(), isEmpty);
    });
  }

  test('duplicate step failures upsert one informational notice', () {
    var state = SessionState(historyRef);
    for (final seq in [1, 2]) {
      for (final event in projectStepUsage(
        stepFrame('failed', fields: {'error': aborted}),
        current: state,
        seq: seq,
      )) {
        state = reduce(state, event).state;
      }
    }
    expect(state.timeline.whereType<Notice>(), hasLength(1));
    expect(state.timeline.whereType<TurnOutcome>(), isEmpty);
    expect(state.execution, isNull);
  });

  test('non-aborted failures never become interruption notices', () {
    for (final type in ['provider.auth', 'future.aborted']) {
      final error = {'type': type, 'message': 'not an interruption'};
      final history = projectOpenCodeHistory(
        [
          assistant('step', [], completed: true, fields: {'error': error}),
        ],
        historyRef,
        sourceVersion: '2.0.22',
      );
      expect(history.whereType<Notice>(), isEmpty);
      expect(
        projectStepUsage(
          stepFrame('failed', fields: {'error': error}),
        ).whereType<ItemUpserted>(),
        isEmpty,
      );
    }
  });
}
