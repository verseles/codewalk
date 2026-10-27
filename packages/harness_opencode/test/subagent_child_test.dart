import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'tool_test_data.dart';

const _call = 'call_subagent:0';
final _child = SessionRef(historyRef.host, historyRef.harness, 'ses_child');

/// One frame of a subagent call; [metadata] replaces the progress or
/// terminal metadata.
Map<String, Object?> _frame(
  String phase,
  String id, {
  Map<String, Object?>? metadata,
}) {
  final frame = toolFrame(phase, id: id, call: _call, name: 'subagent');
  if (metadata != null) toolData(frame)['metadata'] = metadata;
  return frame;
}

/// A started and called subagent call.
SessionState _running() {
  var state = applyTool(
    _frame('input.started', 'evt_1'),
    SessionState(historyRef),
    1,
  );
  state = applyTool(_frame('called', 'evt_2'), state, 2);
  return state;
}

ToolCall _tool(SessionState state) =>
    state.timeline.whereType<ToolCall>().single;

void main() {
  test('progress names the child without replacing the row source', () {
    final state = applyTool(
      _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
      _running(),
      3,
    );
    final tool = _tool(state);
    expect(tool.kind.known, ToolKind.subagent);
    expect(tool.child, _child);
    expect(tool.childEvidence!.kind, ToolChildEvidenceKind.observed);
    expect(tool.childEvidence!.origin.durability.known, Durability.ephemeral);
    expect(tool.childEvidence!.origin.nativeType, 'session.tool.progress');
    // The row keeps its durable called source for the next durable event.
    expect(tool.source.nativeType, 'session.tool.called');
    expect(tool.source.durability.known, Durability.durable);
    expect(tool.childEvidenceValid, isTrue);
  });

  test('a terminal without an id keeps the observed child and its origin', () {
    var state = applyTool(
      _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
      _running(),
      3,
    );
    state = applyTool(_frame('success', 'evt_4', metadata: {}), state, 4);
    final tool = _tool(state);
    expect(tool.status.known, ItemStatus.completed);
    expect(tool.child, _child);
    expect(tool.childEvidence!.origin.nativeType, 'session.tool.progress');
    expect(tool.source.nativeType, 'session.tool.success');
  });

  test('a failed terminal without metadata keeps the observed child', () {
    var state = applyTool(
      _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
      _running(),
      3,
    );
    state = applyTool(_frame('failed', 'evt_4'), state, 4);
    expect(_tool(state).child, _child);
    expect(_tool(state).status.known, ItemStatus.interrupted);
  });

  test('a terminal that names the child is its own durable observation', () {
    final state = applyTool(
      _frame(
        'success',
        'evt_4',
        metadata: {'sessionID': 'ses_child', 'status': 'completed'},
      ),
      _running(),
      4,
    );
    final evidence = _tool(state).childEvidence!;
    expect(_tool(state).child, _child);
    expect(evidence.origin.durability.known, Durability.durable);
    expect(evidence.origin.nativeType, 'session.tool.success');
  });

  test('an unusable or contradictory id is refused for the generation', () {
    for (final first in ['ses_a', 'not-a-session', 42, null]) {
      var state = applyTool(
        _frame('progress', 'evt_3', metadata: {'sessionID': first}),
        _running(),
        3,
      );
      expect(_tool(state).child, isNull, reason: '$first');
      expect(_tool(state).childEvidence!.kind, ToolChildEvidenceKind.rejected);
      // A later valid id never revives the refused call.
      state = applyTool(
        _frame('success', 'evt_4', metadata: {'sessionID': 'ses_child'}),
        state,
        4,
      );
      expect(_tool(state).child, isNull, reason: '$first');
    }

    var state = applyTool(
      _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
      _running(),
      3,
    );
    state = applyTool(
      _frame('progress', 'evt_4', metadata: {'sessionID': 'ses_other'}),
      state,
      4,
    );
    expect(_tool(state).child, isNull);
    expect(_tool(state).childEvidence!.kind, ToolChildEvidenceKind.rejected);
  });

  test('progress of other tools, unknown or settled calls is ignored', () {
    final read = applyTool(
      toolFrame('called', id: 'evt_2'),
      applyTool(toolFrame('input.started'), SessionState(historyRef), 1),
      2,
    );
    final readProgress = toolFrame('progress', id: 'evt_3');
    toolData(readProgress)['metadata'] = {'sessionID': 'ses_child'};
    expect(projectTool(readProgress, current: read, seq: 3), isNull);

    expect(
      projectTool(
        _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
        current: SessionState(historyRef),
        seq: 3,
      ),
      isNull,
    );

    final settled = applyTool(_frame('success', 'evt_4'), _running(), 4);
    expect(
      projectTool(
        _frame('progress', 'evt_5', metadata: {'sessionID': 'ses_child'}),
        current: settled,
        seq: 5,
      ),
      isNull,
    );
    // Progress without a child names nothing.
    expect(
      projectTool(
        _frame('progress', 'evt_3', metadata: {'shellID': 'x'}),
        current: _running(),
        seq: 3,
      ),
      isNull,
    );
  });

  test('recovery forgets a live-only child, settled or not', () {
    var state = applyTool(
      _frame('progress', 'evt_3', metadata: {'sessionID': 'ses_child'}),
      _running(),
      3,
    );
    expect(_tool(disconnect(state)).child, isNull);
    expect(_tool(disconnect(state)).childEvidence, isNull);
    state = applyTool(_frame('success', 'evt_4'), state, 4);
    final restarted = beginHydration(
      state,
      generation: 'hydration-b',
      readStart: state.lastPosition!,
    );
    expect(_tool(restarted).child, isNull);
    expect(_tool(restarted).status.known, ItemStatus.completed);

    // A durable observation outlives the stream.
    final durable = applyTool(
      _frame('success', 'evt_4', metadata: {'sessionID': 'ses_child'}),
      _running(),
      4,
    );
    expect(_tool(disconnect(durable)).child, _child);
  });

  test('history names only the child its own read carries', () {
    List<TimelineItem> project(Map<String, Object?> metadata) =>
        projectOpenCodeHistory(
          [
            assistant('m', [
              {
                ...toolBlock('call_1', 'completed', name: 'subagent'),
                'state': <String, Object?>{
                  ...toolBlock('call_1', 'completed')['state']!
                      as Map<String, Object?>,
                  'metadata': metadata,
                },
              },
            ], completed: true),
          ],
          historyRef,
          sourceVersion: '2.0.22',
          maxItems: 2000,
        );
    final named = project({
      'sessionID': 'ses_child',
    }).whereType<ToolCall>().single;
    expect(named.kind.known, ToolKind.subagent);
    expect(named.child, _child);
    expect(named.childEvidence!.kind, ToolChildEvidenceKind.observed);
    expect(named.childEvidence!.origin.durability.known, Durability.unknown);
    expect(named.childEvidenceValid, isTrue);

    final refused = project({
      'sessionID': 'ses_a',
    }).whereType<ToolCall>().single;
    expect(refused.child, isNull);
    expect(refused.childEvidence!.kind, ToolChildEvidenceKind.rejected);

    final absent = project({}).whereType<ToolCall>().single;
    expect(absent.child, isNull);
    expect(absent.childEvidence, isNull);
  });
}
