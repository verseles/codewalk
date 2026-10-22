import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_test_data.dart';
import 'history_test_data.dart';
import 'inbox_replay_test.dart' show historyLists;
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;
import 'tool_test_data.dart';

/// Every recorded event list, in file order, from one immutable capture.
List<List<Map<String, Object?>>> eventLists(Object? node) {
  final lists = <List<Map<String, Object?>>>[];
  void walk(Object? value) {
    if (value is List) {
      // Native frames: every entry has an `evt_` ID and a string type.
      final frames = value.whereType<Map<String, Object?>>().where(
        (f) =>
            f['type'] is String &&
            (f['id'] is String) &&
            (f['id']! as String).startsWith('evt_'),
      );
      if (frames.isNotEmpty && frames.length == value.length) {
        lists.add(frames.toList());
        return;
      }
      value.forEach(walk);
    } else if (value is Map) {
      value.values.forEach(walk);
    }
  }

  walk(node);
  return lists;
}

/// Native `idle` history rows recorded anywhere in one capture, by message ID.
Map<String, Map<String, Object?>> idleRows(Object? node) {
  final rows = <String, Map<String, Object?>>{};
  void walk(Object? value) {
    if (value is Map<String, Object?>) {
      if (value['type'] == 'idle' && value['id'] is String) {
        rows[value['id']! as String] = value;
      }
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  walk(node);
  return rows;
}

SessionRef refOf(String session) =>
    SessionRef(historyRef.host, historyRef.harness, session);

void main() {
  final fixtures = OpenCodeFixtures();

  test('observed A: combined replay ends with the history idle outcome', () {
    final parser = SseFrameParser();
    final events = [
      for (final chunk in fixtures.observedAStream.frames)
        for (final frame in parser.add(utf8.encode(chunk)))
          jsonDecode(frame.data) as Map<String, Object?>,
    ];
    expect(parser.finish(), isNull);
    final session =
        (events.firstWhere(
                  (f) => f['type'] == 'session.execution.started',
                )['data']!
                as Map)['sessionID']!
            as String;
    final ref = refOf(session);
    var state = SessionState(ref);
    final executions = <List<SessionEvent>>[];
    for (var i = 0; i < events.length; i++) {
      final position = observedPosition(i + 1);
      final batch = <SessionEvent>[
        ...projectOpenCodeExecutionEvent(
          events[i],
          state,
          sourceVersion: '2.0.22',
          position: position,
          receivedAt: DateTime.utc(2026, 10, 13),
        ),
      ];
      if (batch.isNotEmpty) executions.add(batch);
      final other =
          projectOpenCodeTextReasoningEvent(
            events[i],
            state,
            sourceVersion: '2.0.22',
            position: position,
            receivedAt: DateTime.utc(2026, 10, 13),
          ) ??
          projectTool(events[i], current: state, seq: i + 1);
      if (other != null) batch.add(other);
      for (final event in batch) {
        final result = reduce(state, event);
        expect(result.effects.every((e) => e is Notify), isTrue);
        state = result.state;
      }
    }
    expect(executions.map((b) => b.length), [1, 2]);
    expect(state.execution!.kind.known, ExecutionKind.idle);
    expect(
      state.execution!.lastOutcome!.kind.known,
      ExecutionOutcomeKind.succeeded,
    );
    expect(state.timeline.map((i) => i.runtimeType), [
      Reasoning,
      ToolCall,
      Reasoning,
      AssistantText,
      TurnOutcome,
    ]);
    final history = projectOpenCodeHistory(
      fixtures.observedAHistory['data']! as List<Object?>,
      ref,
      sourceVersion: '2.0.22',
    ).whereType<TurnOutcome>().single;
    final live = state.timeline.last as TurnOutcome;
    expect(live.id, history.id);
    expect(live.status, history.status);
    expect(live.kind, history.kind);
    expect(live.generation, isNot(history.generation));
  });

  test(
    'observed B–E captures: every terminal matches its recorded idle row',
    () {
      // Pinned execution-evidence units; unrelated captures in the shared
      // root must not shift these exact totals.
      final files =
          ['b', 'c', 'd', 'd-retry-quota', 'e']
              .map((unit) => Directory('${fixtures.root.path}/$unit'))
              .expand((d) => d.listSync().whereType<File>())
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      var outcomes = 0;
      var shutdowns = 0;
      var failures = 0;
      var parity = 0;
      for (final file in files) {
        final capture = jsonDecode(file.readAsStringSync());
        final idle = idleRows(capture);
        final name = file.path.substring(fixtures.root.path.length + 1);
        for (final events in eventLists(capture)) {
          final states = <String, SessionState>{};
          for (var i = 0; i < events.length; i++) {
            final frame = events[i];
            if (!(frame['type']! as String).startsWith('session.execution.')) {
              continue;
            }
            final session = (frame['data']! as Map)['sessionID']! as String;
            var state = states[session] ?? SessionState(refOf(session));
            final projected = projectOpenCodeExecutionEvent(
              frame,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(i + 1),
              receivedAt: DateTime.utc(2026, 10, 13),
            );
            for (final other in states.values.where((s) => s != state)) {
              expect(
                projectOpenCodeExecutionEvent(
                  frame,
                  other,
                  sourceVersion: '2.0.22',
                  position: observedPosition(i + 1),
                  receivedAt: DateTime.utc(2026, 10, 13),
                ),
                isEmpty,
              );
            }
            for (final event in projected) {
              final result = reduce(state, event);
              expect(result.effects.every((e) => e is Notify), isTrue);
              state = result.state;
            }
            states[session] = state;
            final type = frame['type']! as String;
            final messageId = 'msg_${(frame['id']! as String).substring(4)}';
            final reason = (frame['data']! as Map)['reason'];
            if (type == 'session.execution.started') {
              expect(state.execution!.kind.known, ExecutionKind.running);
            } else if (reason == 'shutdown') {
              shutdowns++;
              expect(projected, hasLength(1), reason: name);
              expect(
                state.execution!.kind.known,
                ExecutionKind.interruptedPendingResume,
              );
              expect(idle.containsKey(messageId), isFalse, reason: name);
            } else {
              outcomes++;
              final item = (projected.last as ItemUpserted).item as TurnOutcome;
              expect(state.execution!.kind.known, ExecutionKind.idle);
              expect(state.execution!.lastOutcome!.kind.value, item.kind.value);
              final row = idle[messageId];
              if (row == null) {
                // The retry ledger records events without history snapshots.
                expect(name, 'd-retry-quota/execution-ledger.json');
                continue;
              }
              final history = projectOpenCodeHistory(
                [row],
                refOf(session),
                sourceVersion: '2.0.22',
              ).single;
              expect(item.id, history.id, reason: name);
              expect(item.status, history.status, reason: name);
              expect(item.kind, (history as TurnOutcome).kind, reason: name);
              if (type == 'session.execution.failed') {
                failures++;
                final error = (frame['data']! as Map)['error']! as Map;
                // The captured failures are typed and keep their message;
                // the status and the response body are never read.
                expect(
                  errorJson(item.error),
                  errorJson(
                    openCodeErrorInfo(
                      error['type']! as String,
                      error['message'] as String?,
                    ),
                  ),
                  reason: name,
                );
                expect(item.error!.kind.known, isNot(ErrorKind.unknown));
                // The history carries the same error on its idle row, from
                // the turn's last assistant message, in chronological order.
                // Client and server message IDs differ in shape, so a page's
                // order is told by its creation times.
                num created(Map<String, Object?> row) =>
                    (row['time']! as Map)['created']! as num;
                final matches = [
                  for (final list in historyLists(capture))
                    if (list.any((r) => r['id'] == messageId))
                      ...projectOpenCodeHistory(
                        created(list.first) > created(list.last)
                            ? list.reversed.toList()
                            : list,
                        refOf(session),
                        sourceVersion: '2.0.22',
                      ).whereType<TurnOutcome>().where((o) => o.id == item.id),
                ];
                expect(matches, isNotEmpty, reason: name);
                for (final history in matches) {
                  expect(
                    errorJson(history.error),
                    errorJson(item.error),
                    reason: name,
                  );
                }
                parity++;
                for (final event in projected) {
                  final manifest = executionManifest(event);
                  final body = (error['response'] as Map?)?['body'];
                  if (body is String && body.isNotEmpty) {
                    expect(manifest, isNot(contains(jsonEncode(body))));
                  }
                }
              }
            }
          }
        }
      }
      expect(shutdowns, 3);
      expect(failures, 4);
      expect(parity, 4);
      expect(outcomes, 36);
    },
  );
}
