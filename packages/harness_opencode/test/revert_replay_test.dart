import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'revert_test_data.dart' show messageOf;
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;
import 'tool_test_data.dart';

void main() {
  final fixtures = OpenCodeFixtures();

  test(
    'observed D: staged, cleared and committed reverts match the server',
    () {
      final capture =
          jsonDecode(
                File(
                  '${fixtures.root.path}/d/revert-file-effects.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final summary = capture['summary']! as Map<String, Object?>;
      final session = summary['rootSessionID']! as String;
      final boundary = summary['boundaryMessageID']! as String;
      final ref = refOf(session);
      final events = eventLists(capture).single;
      final receivedAt = DateTime.utc(2026, 10, 14);

      var state = SessionState(ref);
      final kinds = <RevertKind?>[];
      final files = <int?>[];
      final batches = <List<SessionEvent>>[];
      for (var i = 0; i < events.length; i++) {
        final frame = events[i];
        final position = observedPosition(i + 1);
        List<SessionEvent> project(
          List<SessionEvent> Function(
            Object?,
            SessionState, {
            required String sourceVersion,
            required StreamPosition position,
            required DateTime receivedAt,
          })
          producer,
        ) => producer(
          frame,
          state,
          sourceVersion: '2.0.22',
          position: position,
          receivedAt: receivedAt,
        );
        final revert = project(projectOpenCodeRevertEvent);
        final batch = <SessionEvent>[
          ...project(projectOpenCodeInboxEvent),
          ...project(projectOpenCodeExecutionEvent),
          ...project(projectOpenCodeStepUsageEvent),
          ...revert,
          ?projectOpenCodeTextReasoningEvent(
            frame,
            state,
            sourceVersion: '2.0.22',
            position: position,
            receivedAt: receivedAt,
          ),
          ?projectTool(frame, current: state, seq: i + 1),
          ?projectOpenCodeInteractionEvent(
            frame,
            state,
            sourceVersion: '2.0.22',
            position: position,
            receivedAt: receivedAt,
          ),
        ];
        for (final event in batch) {
          final result = reduce(state, event);
          expect(result.effects.every((e) => e is Notify), isTrue);
          state = result.state;
        }
        if (revert.isEmpty) continue;
        batches.add(revert);
        final current = state.revert!;
        kinds.add(current.kind.known);
        if (current.kind.known == RevertKind.staged) {
          // The boundary is the admitted steer prompt, resident from its inbox
          // event with the history ID.
          expect(messageOf(current.boundary!), boundary);
          expect(current.boundary, state.timeline.first.id);
          final details = current.details!.value as Map<String, Object?>;
          expect(details['messageId'], boundary);
          expect(details['hasSnapshot'], isTrue);
          files.add((details['files'] as List?)?.length);
          expect(jsonEncode(details), isNot(contains('D_REVERT')));
        } else {
          expect(current.boundary, isNull);
        }
      }
      expect(kinds, [
        RevertKind.staged,
        RevertKind.cleared,
        RevertKind.staged,
        RevertKind.cleared,
        RevertKind.staged,
        RevertKind.committed,
      ]);
      expect(files, [1, 0, 1]);
      expect(batches.last.map((e) => e.runtimeType), [
        RevertChanged,
        ItemsRemoved,
      ]);

      // The last recorded reads follow the commit: no history, no inbox.
      Map<String, Object?> lastRead(String suffix) =>
          (capture['calls']! as List).cast<Map<String, Object?>>().lastWhere(
                (c) => (c['path']! as String).contains(suffix),
              )['response']!
              as Map<String, Object?>;
      final history = projectOpenCodeHistory(
        lastRead('/message?')['data']! as List<Object?>,
        ref,
        sourceVersion: '2.0.22',
      );
      expect(history, isEmpty);
      expect(lastRead('/inbox')['data'], isEmpty);
      expect(state.timeline, isEmpty);
      expect(state.pending, isEmpty);
    },
  );
}
