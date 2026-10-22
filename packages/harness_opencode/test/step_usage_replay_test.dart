import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'inbox_replay_test.dart' show historyLists;
import 'step_usage_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

void main() {
  final fixtures = OpenCodeFixtures();

  test(
    'observed A–E captures: failures match history and usage totals add up',
    () {
      // Pinned set: root A plus units B–E. A new capture in these units must
      // update the exact totals below deliberately.
      final files =
          ['b', 'c', 'd', 'd-retry-quota', 'e']
              .map((unit) => Directory('${fixtures.root.path}/$unit'))
              .expand((d) => d.listSync().whereType<File>())
              .where((f) => f.path.endsWith('.json'))
              .followedBy([File('${fixtures.root.path}/events.json')])
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      // Restart captures start after earlier steps of the same session.
      const partialLogs = {
        'b/service-restart.json',
        'c/post-restart-question-recovery.json',
      };
      final phases = <String, int>{};
      var failures = 0;
      var totals = 0;
      for (final file in files) {
        final capture = jsonDecode(file.readAsStringSync());
        final name = file.path.substring(fixtures.root.path.length + 1);
        final rows = <String, Map<String, Object?>>{
          for (final list in historyLists(capture))
            for (final row in list)
              if (row['type'] == 'assistant') row['id']! as String: row,
        };
        for (final events in eventLists(capture)) {
          final states = <String, SessionState>{};
          for (var i = 0; i < events.length; i++) {
            final frame = events[i];
            final type = frame['type']! as String;
            if (!type.startsWith('session.step.') &&
                type != 'session.usage.updated') {
              continue;
            }
            phases[type] = (phases[type] ?? 0) + 1;
            final data = frame['data']! as Map;
            final session = data['sessionID']! as String;
            var state = states[session] ?? SessionState(refOf(session));
            final projected = projectOpenCodeStepUsageEvent(
              frame,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(i + 1),
              receivedAt: DateTime.utc(2026, 10, 14),
            );
            // Every private native value of this frame stays out of Core.
            final error = data['error'] as Map?;
            final secrets = [
              ?error?['message'],
              ?(error?['response'] as Map?)?['body'],
              ?data['snapshot'],
              ...?(data['files'] as List?),
              ?(frame['location'] as Map?)?['directory'],
              if (data['providerState'] case final Map state
                  when state.isNotEmpty)
                jsonEncode(state),
            ].whereType<String>().where((v) => v.length > 3);
            for (final event in projected) {
              final manifest = stepUsageManifest(event);
              for (final secret in secrets) {
                expect(manifest, isNot(contains(secret)), reason: name);
              }
              final result = reduce(state, event);
              expect(result.effects.every((e) => e is Notify), isTrue);
              state = result.state;
            }
            states[session] = state;
            if (type == 'session.step.failed') {
              // The step emits no item: the turn's outcome carries the error,
              // and the history row it matches shows no marker for it.
              expect(projected.whereType<ItemUpserted>(), isEmpty);
              final row = rows[data['assistantMessageID']];
              expect(row, isNotNull, reason: name);
              expect(
                (row!['error']! as Map)['type'],
                error!['type'],
                reason: name,
              );
              final history = projectOpenCodeHistory(
                [row],
                refOf(session),
                sourceVersion: '2.0.22',
              );
              expect(history.whereType<UnknownItem>(), isEmpty, reason: name);
              failures++;
            }
            if (type == 'session.usage.updated' &&
                !partialLogs.contains(name)) {
              final session = state.usage.singleWhere((u) => u.cumulative);
              final steps = state.usage.where((u) => u.partial);
              num sum(num? Function(UsageObservation u) pick) =>
                  steps.fold<num>(0, (a, u) => a + pick(u)!);
              expect(session.cost!.amount, sum((u) => u.cost!.amount));
              for (final pick in <num? Function(UsageObservation)>[
                (u) => u.tokens!.input,
                (u) => u.tokens!.output,
                (u) => u.tokens!.reasoning,
                (u) => u.tokens!.cacheRead,
                (u) => u.tokens!.cacheWrite,
              ]) {
                expect(pick(session), sum(pick), reason: name);
              }
              totals++;
            }
          }
        }
      }
      expect(phases, {
        'session.step.started': 56,
        'session.step.streamed': 51,
        'session.step.ended': 44,
        'session.step.failed': 11,
        'session.usage.updated': 51,
      });
      // Every failed step matches its history row; four readings in the
      // restart captures follow steps that precede the recorded log.
      expect((failures, totals), (11, 47));
    },
  );
}
