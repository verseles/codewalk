import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/session_projection.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'history_test_data.dart';
import 'session_lifecycle_test_data.dart' show infoJson;
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

/// Recorded `GET /api/session/{id}` records anywhere in one capture.
List<Map<String, Object?>> sessionReads(Object? node) {
  final reads = <Map<String, Object?>>[];
  final path = RegExp(r'^/api/session/(ses[^/?]+)(\?.*)?$');
  void walk(Object? value) {
    if (value is Map<String, Object?>) {
      final response = value['response'];
      if (value['method'] == 'GET' &&
          value['path'] is String &&
          path.hasMatch(value['path']! as String) &&
          response is Map<String, Object?> &&
          response['data'] is Map<String, Object?>) {
        reads.add(response['data']! as Map<String, Object?>);
      }
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  walk(node);
  return reads;
}

void main() {
  final fixtures = OpenCodeFixtures();

  test('observed captures: lifecycle frames project like the HTTP records', () {
    // Every tracked 2.0.22 capture; the untracked configured-origin evidence
    // must not shift these exact totals.
    final files =
        fixtures.root
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.json') &&
                  !f.path.contains('/web-configured-origin/'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final outcomes = <String, int>{};
    var matchedReads = 0;
    for (final file in files) {
      final capture = jsonDecode(file.readAsStringSync());
      final name = file.path.substring(fixtures.root.path.length + 1);
      final reads = sessionReads(capture);
      for (final events in eventLists(capture)) {
        final states = <String, SessionState>{};
        for (var i = 0; i < events.length; i++) {
          final frame = events[i];
          final type = frame['type']! as String;
          if (type != 'session.created' &&
              type != 'session.renamed' &&
              type != 'session.deleted') {
            continue;
          }
          final data = frame['data']! as Map<String, Object?>;
          final session = data['sessionID']! as String;
          final state = states[session] ?? SessionState(refOf(session));
          // A frame never changes another session's state.
          final other = SessionState(refOf('ses_other'));
          expect(
            projectOpenCodeSessionLifecycleEvent(
              frame,
              other,
              sourceVersion: '2.0.22',
              position: observedPosition(i + 1),
              receivedAt: DateTime.utc(2026, 10, 14),
            ),
            isEmpty,
          );
          final projected = projectOpenCodeSessionLifecycleEvent(
            frame,
            state,
            sourceVersion: '2.0.22',
            position: observedPosition(i + 1),
            receivedAt: DateTime.utc(2026, 10, 14),
          );
          expect(projected, hasLength(1), reason: '$name $type');
          final event = projected.single;
          final key = switch (event) {
            SessionInfoChanged() => '$type→info',
            ResyncRequired(:final reason) => '$type→$reason',
            _ => fail('Unexpected lifecycle event.'),
          };
          outcomes[key] = (outcomes[key] ?? 0) + 1;
          final result = reduce(state, event);
          states[session] = result.state;
          if (event is SessionInfoChanged && type == 'session.created') {
            final info = infoJson(event.info);
            final parent = data['parentID'];
            expect(info['parent'] != null, parent != null);
            for (final read in reads.where((r) => r['id'] == session)) {
              expect(
                info,
                infoJson(projectOpenCodeSession(read, historyHarness).info),
                reason: name,
              );
              matchedReads++;
            }
          }
        }
      }
    }
    expect(outcomes, {
      'session.created→info': 38,
      'session.renamed→sessionInfoUnproven': 10,
      'session.deleted→sessionDeleted': 5,
    });
    // Every recorded read of a created session, none renamed in between.
    expect(matchedReads, 24);
  });

  test('observed E: renames over hydrated info match each later read', () {
    final capture =
        jsonDecode(
              File(
                '${fixtures.root.path}/e/durable-log.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final calls = (capture['calls']! as List).cast<Map<String, Object?>>();
    Map<String, Object?> record(Map<String, Object?> call) =>
        (call['response']! as Map<String, Object?>)['data']!
            as Map<String, Object?>;
    final created = record(calls.firstWhere((c) => c['method'] == 'POST'));
    final ref = refOf(created['id']! as String);
    var state = reduce(
      SessionState(ref),
      SessionInfoChanged(
        meta: EventMeta(
          owner: SessionOwner(ref),
          position: observedPosition(0),
          receivedAt: DateTime.utc(2026, 10, 14),
          source: SourceProvenance(
            harness: ref.harnessRef,
            version: '2.0.22',
            nativeType: 'seed',
          ),
        ),
        info: projectOpenCodeSession(created, ref.harnessRef).info,
      ),
    ).state;
    final reads = [
      for (final call in calls)
        if (call['method'] == 'GET') record(call),
    ];
    final renames = eventLists(capture)
        .expand((events) => events)
        .where((frame) => frame['type'] == 'session.renamed')
        .toList();
    expect((renames.length, reads.length), (2, 2));
    for (var i = 0; i < renames.length; i++) {
      final events = projectOpenCodeSessionLifecycleEvent(
        renames[i],
        state,
        sourceVersion: '2.0.22',
        position: observedPosition(i + 1),
        receivedAt: DateTime.utc(2026, 10, 14),
      );
      expect(events.single, isA<SessionInfoChanged>());
      final result = reduce(state, events.single);
      expect(result.effects.every((e) => e is Notify), isTrue);
      state = result.state;
      expect(
        infoJson(state.info!),
        infoJson(projectOpenCodeSession(reads[i], ref.harnessRef).info),
      );
    }
    expect(state.info!.title, 'V2-005E log renamed twice');
  });
}
