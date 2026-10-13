import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'execution_replay_test.dart' show eventLists, refOf;
import 'inbox_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

/// Native history message lists recorded anywhere in one capture, excluding
/// pending `/inbox` reads.
List<List<Map<String, Object?>>> historyLists(Object? node) {
  const types = {'user', 'assistant', 'idle', 'synthetic', 'system'};
  final lists = <List<Map<String, Object?>>>[];
  void walk(Object? value) {
    if (value is List) {
      final rows = value.whereType<Map<String, Object?>>().where(
        (r) =>
            types.contains(r['type']) &&
            r['id'] is String &&
            (r['id']! as String).startsWith('msg_') &&
            // `/inbox` rows carry payload/delivery; they are not history.
            !r.containsKey('payload') &&
            !r.containsKey('delivery'),
      );
      if (rows.isNotEmpty && rows.length == value.length) {
        lists.add(rows.toList());
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

void main() {
  final fixtures = OpenCodeFixtures();

  test('observed A: the steer prompt matches its history user row', () {
    final parser = SseFrameParser();
    final events = [
      for (final chunk in fixtures.observedAStream.frames)
        for (final frame in parser.add(utf8.encode(chunk)))
          jsonDecode(frame.data) as Map<String, Object?>,
    ];
    expect(parser.finish(), isNull);
    final session =
        (events.firstWhere(
                  (f) => f['type'] == 'session.inbox.enqueued',
                )['data']!
                as Map)['sessionID']!
            as String;
    var state = SessionState(refOf(session));
    for (var i = 0; i < events.length; i++) {
      for (final event in projectOpenCodeInboxEvent(
        events[i],
        state,
        sourceVersion: '2.0.22',
        position: observedPosition(i + 1),
        receivedAt: DateTime.utc(2026, 10, 13),
      )) {
        state = reduce(state, event).state;
      }
    }
    final live = state.timeline.single as UserInput;
    final history = projectOpenCodeHistory(
      fixtures.observedAHistory['data']! as List<Object?>,
      refOf(session),
      sourceVersion: '2.0.22',
    ).whereType<UserInput>().single;
    expect(live.id, history.id);
    expect(live.text, history.text);
    expect(live.status, history.status);
    expect(live.delivery.known, DeliveryState.delivered);
    expect(state.pending, isEmpty);
  });

  test(
    'observed B–E captures: delivered input matches history rows and order',
    () {
      // Pinned inbox-evidence units; unrelated captures in the shared root
      // must not shift these exact totals.
      final files =
          ['b', 'c', 'd', 'd-retry-quota', 'e']
              .map((unit) => Directory('${fixtures.root.path}/$unit'))
              .expand((d) => d.listSync().whereType<File>())
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final phases = <String, int>{};
      var matched = 0;
      var ordered = 0;
      for (final file in files) {
        final capture = jsonDecode(file.readAsStringSync());
        final name = file.path.substring(fixtures.root.path.length + 1);
        final histories = historyLists(capture);
        final rows = <String, Map<String, Object?>>{
          for (final list in histories)
            for (final row in list)
              if (row['type'] == 'user') row['id']! as String: row,
        };
        for (final events in eventLists(capture)) {
          final states = <String, SessionState>{};
          final cancelled = <String>{};
          for (var i = 0; i < events.length; i++) {
            final frame = events[i];
            final type = frame['type']! as String;
            if (!type.startsWith('session.inbox.')) continue;
            phases[type] = (phases[type] ?? 0) + 1;
            final data = frame['data']! as Map;
            final session = data['sessionID']! as String;
            if (type == 'session.inbox.cancelled') {
              cancelled.add(data['inboxID']! as String);
            }
            var state = states[session] ?? SessionState(refOf(session));
            final projected = projectOpenCodeInboxEvent(
              frame,
              state,
              sourceVersion: '2.0.22',
              position: observedPosition(i + 1),
              receivedAt: DateTime.utc(2026, 10, 13),
            );
            for (final event in projected) {
              final manifest = inboxManifest(event);
              for (final secret in ['"data"', 'metadata', 'location']) {
                expect(manifest, isNot(contains(secret)), reason: name);
              }
              final result = reduce(state, event);
              expect(result.effects.every((e) => e is Notify), isTrue);
              state = result.state;
            }
            states[session] = state;
          }
          for (final MapEntry(key: session, value: state) in states.entries) {
            final live = state.timeline.whereType<UserInput>().toList();
            final delivered = [
              for (final user in live)
                if (user.delivery.known == DeliveryState.delivered) user,
            ];
            for (final user in delivered) {
              final inbox = (jsonDecode(user.id.value) as List)[1] as String;
              expect(cancelled.contains(inbox), isFalse, reason: name);
              final row = rows[inbox];
              if (row == null) continue;
              final history =
                  projectOpenCodeHistory(
                        [row],
                        refOf(session),
                        sourceVersion: '2.0.22',
                      ).first
                      as UserInput;
              expect(user.id, history.id, reason: name);
              expect(user.text, history.text, reason: name);
              expect(user.status, history.status, reason: name);
              matched++;
            }
            // Every recorded history list orders delivered prompts like live.
            final liveOrder = [for (final user in delivered) user.id];
            for (final list in histories) {
              final historyOrder = [
                for (final row in list)
                  if (row['type'] == 'user')
                    ItemId(
                      jsonEncode([
                        refOf(session).storageKey,
                        row['id'],
                        'user',
                        0,
                      ]),
                    ),
              ].where(liveOrder.contains).toList();
              if (historyOrder.length < 2) continue;
              expect(
                liveOrder.where(historyOrder.contains).toList(),
                historyOrder,
                reason: name,
              );
              ordered++;
            }
          }
        }
      }
      expect(phases, {
        'session.inbox.enqueued': 48,
        'session.inbox.delivered': 40,
        'session.inbox.cancelled': 8,
        'session.inbox.delivery.changed': 2,
      });
      // 38 delivered prompts have recorded history rows; six recorded lists
      // pin relative order, including queue-steer's late queued delivery.
      expect((matched, ordered), (38, 6));
    },
  );
}
