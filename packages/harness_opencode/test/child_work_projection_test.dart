import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_test_data.dart';
import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

Matcher failsWith(OpenCodeExecutionProjectionFailure failure) => throwsA(
  isA<OpenCodeExecutionProjectionException>().having(
    (e) => e.failure,
    'failure',
    failure,
  ),
);

void main() {
  final received = DateTime.utc(2026, 10, 13);
  final child = SessionRef(historyRef.host, historyRef.harness, 'ses_child');
  final other = SessionRef(historyRef.host, historyRef.harness, 'ses_other');

  WorkChanged? project(
    Object? frame,
    SessionState parent, {
    SessionRef? of,
    int seq = 1,
  }) => projectOpenCodeChildExecutionEvent(
    frame,
    parent,
    child: of ?? child,
    sourceVersion: '2.0.22',
    position: observedPosition(seq),
    receivedAt: received,
  );

  SessionState apply(
    SessionState parent,
    Object? frame,
    int seq, {
    SessionRef? of,
  }) {
    final event = project(frame, parent, of: of, seq: seq);
    return event == null ? parent : reduce(parent, event).state;
  }

  List<SessionRef?> running(SessionState parent) => [
    for (final item in parent.work)
      if (item.status.known == WorkStatus.running) item.child,
  ];

  test('a child start is counted on the parent until the child ends', () {
    final parent = SessionState(historyRef);
    var state = apply(
      parent,
      executionFrame('started', session: 'ses_child'),
      1,
    );
    expect(running(state), [child]);
    final item = state.work.single;
    expect(item.parent, historyRef);
    expect(item.completionScope.known, CompletionScope.child);
    expect(item.owner, SessionOwner(child, origin: historyRef));
    // The parent's own execution is never touched.
    expect(state.execution, isNull);
    // A repeated start changes nothing.
    expect(
      project(executionFrame('started', session: 'ses_child'), state, seq: 2),
      isNull,
    );
    state = apply(
      state,
      executionFrame('started', id: 'evt_other', session: 'ses_other'),
      2,
      of: other,
    );
    expect(running(state), [child, other]);
    for (final (phase, reason) in [
      ('succeeded', null),
      ('failed', null),
      ('interrupted', 'user'),
      ('interrupted', 'shutdown'),
    ]) {
      final ended = apply(
        state,
        executionFrame(
          phase,
          id: 'evt_end',
          session: 'ses_child',
          reason: reason,
        ),
        3,
      );
      expect(running(ended), [other], reason: '$phase $reason');
    }
  });

  test('frames of another session or type are not projected', () {
    final parent = SessionState(historyRef);
    expect(project(executionFrame('started'), parent), isNull);
    expect(project(retryFrame(session: 'ses_child'), parent), isNull);
    expect(
      project(executionFrame('succeeded', session: 'ses_child'), parent),
      isNull,
    );
  });

  test('malformed child frames fail by category', () {
    final parent = SessionState(historyRef);
    expect(
      () => project(
        executionFrame('interrupted', session: 'ses_child', reason: 'future'),
        parent,
      ),
      failsWith(OpenCodeExecutionProjectionFailure.unsupportedValue),
    );
    expect(
      () => project(
        executionFrame('failed', session: 'ses_child', error: {'type': ''}),
        parent,
      ),
      failsWith(OpenCodeExecutionProjectionFailure.unsupportedValue),
    );
    expect(
      () => project({'type': 'session.execution.started'}, parent),
      failsWith(OpenCodeExecutionProjectionFailure.malformed),
    );
  });

  test('observed D: the parent goes idle while its background child runs', () {
    final capture =
        jsonDecode(
              File(
                '${OpenCodeFixtures().root.path}/d/background-interrupt.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final summary = capture['summary']! as Map<String, Object?>;
    final root = summary['rootSessionID']! as String;
    final childId = summary['childSessionID']! as String;
    final parentRef = SessionRef(historyRef.host, historyRef.harness, root);
    final childRef = SessionRef(historyRef.host, historyRef.harness, childId);
    var state = SessionState(parentRef);
    var seq = 0;
    final seen = <String>[];
    for (final frame
        in (capture['events']! as List).cast<Map<String, Object?>>()) {
      final session = (frame['data'] as Map?)?['sessionID'];
      final type = frame['type']! as String;
      if (!type.startsWith('session.execution.')) continue;
      final events = session == root
          ? projectOpenCodeEvent(
              frame,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(++seq),
              receivedAt: received,
            )
          : [
              ?projectOpenCodeChildExecutionEvent(
                frame,
                state,
                child: childRef,
                sourceVersion: '2.0.22',
                position: observedPosition(++seq),
                receivedAt: received,
              ),
            ];
      for (final event in events) {
        state = reduce(state, event).state;
      }
      seen.add(
        '${session == root ? 'parent' : 'child'} ${type.split('.').last}: '
        '${state.execution?.kind.known?.name} '
        '${running(state).length}',
      );
    }
    expect(seen, [
      'parent started: running 0',
      'child started: running 1',
      // The parent finishes while its background child still runs.
      'parent succeeded: idle 1',
      'child interrupted: idle 0',
      'parent started: running 0',
      'parent succeeded: idle 0',
    ]);
  });
}
