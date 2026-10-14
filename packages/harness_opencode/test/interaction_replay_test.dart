import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'interaction_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

void main() {
  final fixtures = OpenCodeFixtures();

  test(
    'observed C/D captures: every recorded ask opens and its reply settles it',
    () {
      // Pinned interaction-evidence units; a new capture here must update the
      // exact totals below deliberately.
      final files =
          ['c', 'd']
              .map((unit) => Directory('${fixtures.root.path}/$unit'))
              .expand((d) => d.listSync().whereType<File>())
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final phases = <String, int>{};
      var settled = 0;
      var stillOpen = 0;
      var orphans = 0;
      for (final file in files) {
        final capture = jsonDecode(file.readAsStringSync());
        final name = file.path.substring(fixtures.root.path.length + 1);
        for (final events in eventLists(capture)) {
          final states = <String, SessionState>{};
          final open = <String, Set<String>>{};
          for (var i = 0; i < events.length; i++) {
            final frame = events[i];
            final type = frame['type']! as String;
            if (!type.startsWith('permission.') && !type.startsWith('form.')) {
              continue;
            }
            phases[type] = (phases[type] ?? 0) + 1;
            final data = frame['data']! as Map;
            final session =
                ((data['form'] as Map?)?['sessionID'] ?? data['sessionID'])!
                    as String;
            expect(session, isNot('global'), reason: name);
            var state = states[session] ?? SessionState(refOf(session));
            final event = projectOpenCodeInteractionEvent(
              frame,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(i + 1),
              receivedAt: DateTime.utc(2026, 10, 14),
            );
            expect(event, isNotNull, reason: '$name $type');
            final manifest = interactionManifest(event!);
            final metadata =
                (data['metadata'] ?? (data['form'] as Map?)?['metadata'])
                    as Map?;
            for (final value in [
              ...?metadata?.values.whereType<String>(),
              ?data['message'],
              ...?((data['answer'] as Map?)?.values.whereType<String>()),
              ?(frame['location'] as Map?)?['directory'],
            ]) {
              if (value is String && value.length > 3) {
                expect(manifest, isNot(contains(value)), reason: name);
              }
            }
            final result = reduce(state, event);
            expect(result.effects.every((e) => e is Notify), isTrue);
            state = result.state;
            states[session] = state;
            final ids = open.putIfAbsent(session, () => {});
            switch (event) {
              case InteractionOpened(:final request):
                ids.add(request.id.value);
              case InteractionResolved(:final resolution):
                // A resolution whose ask precedes the recorded log still
                // tombstones the identity in Core.
                if (ids.remove(resolution.id.value)) {
                  settled++;
                } else {
                  orphans++;
                }
              default:
                fail('Unexpected interaction producer event.');
            }
            expect(
              state.interactions.map((r) => r.id.value).toSet(),
              ids,
              reason: name,
            );
          }
          stillOpen += open.values.fold(0, (a, s) => a + s.length);
        }
      }
      expect(phases, {
        'permission.asked': 35,
        'permission.replied': 31,
        'form.created': 6,
        'form.replied': 3,
        'form.cancelled': 4,
      });
      // 41 opens: 37 settled in-log, 4 still pending when the log ends; one
      // resolution (post-restart recovery) settles an ask from before the log.
      expect((settled, stillOpen, orphans), (37, 4, 1));
    },
  );
}
