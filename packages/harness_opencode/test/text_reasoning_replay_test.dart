import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart';

void main() {
  final fixtures = OpenCodeFixtures();

  test(
    'observed A replay: ten updates produce three canonical content blocks',
    () {
      final parser = SseFrameParser();
      final frames = [
        for (final frame in fixtures.observedAStream.frames)
          ...parser.add(utf8.encode(frame)),
      ];
      expect(parser.finish(), isNull);
      final events = frames
          .map((f) => jsonDecode(f.data) as Map<String, Object?>)
          .toList();
      expect(events.length, 27);
      expect(
        events,
        jsonDecode(
          File('${fixtures.root.path}/events.json').readAsStringSync(),
        ),
      );
      final native = (events.first['data']! as Map)['sessionID']! as String;
      final ref = SessionRef(historyRef.host, historyRef.harness, native);
      var state = SessionState(ref);
      final projected = <SessionEvent>[];
      for (var i = 0; i < events.length; i++) {
        final event = projectText(events[i], current: state, seq: i + 1);
        if (event == null) continue;
        projected.add(event);
        final result = reduce(state, event);
        expect(
          result.effects.every(
            (effect) => effect is Notify && effect.ref == ref,
          ),
          isTrue,
          reason: events[i]['type']! as String,
        );
        state = result.state;
      }
      expect(projected.length, 10);
      expect(state.timeline.length, 3);
      expect(state.timeline.whereType<Reasoning>().length, 2);
      expect(state.timeline.whereType<AssistantText>().length, 1);
      final history = projectOpenCodeHistory(
        fixtures.observedAHistory['data']! as List<Object?>,
        ref,
        sourceVersion: '2.0.22',
      ).where((i) => i is Reasoning || i is AssistantText).toList();
      expect(history.length, 3);
      for (var i = 0; i < history.length; i++) {
        final live = state.timeline[i];
        expect(live.id, history[i].id);
        expect(live.generation, isNot(history[i].generation));
        expect(live.meta.ordinal, history[i].meta.ordinal);
        expect(semanticItem(live)['text'], semanticItem(history[i])['text']);
        expect(semanticItem(live)['complete'], isTrue);
        expect(switch (live) {
          AssistantText v => v.prefixMissing,
          Reasoning v => v.prefixMissing,
          _ => throw StateError('Expected a text or reasoning item.'),
        }, isFalse);
        expect(live.turnId, isNull);
      }
      for (final event in projected) {
        final manifest = projectedManifest(event);
        for (final forbidden in [
          '_redacted',
          'opaque provider state omitted',
          '/workspace/.cloud-runtime',
        ]) {
          expect(manifest, isNot(contains(forbidden)));
        }
        expect(event.meta.source.nativeCursor, isNull);
        expect(event.meta.rawRef, isNull);
      }
      expect(state.execution, isNull);
      expect(state.interactions, isEmpty);
      expect(state.pending, isEmpty);
      expect(state.work, isEmpty);
      expect(state.usage, isEmpty);
      // A second offline pass must not duplicate content or reopen completed rows.
      final beforeReplay = state.timeline.map(semanticItem).toList();
      for (var i = 0; i < events.length; i++) {
        state = applyText(events[i], state, events.length + i + 1);
      }
      expect(state.timeline.map(semanticItem).toList(), beforeReplay);
      expect(state.timeline.length, 3);
      expect(
        state.timeline.map((i) => semanticItem(i)['text']),
        history.map((i) => semanticItem(i)['text']),
      );
    },
  );

  test('observed B replay: reconnect does not invent the missing text end', () {
    final capture =
        jsonDecode(
              File(
                '${fixtures.root.path}/b/disconnect-reconnect.json',
              ).readAsStringSync(),
            )
            as Map;
    final partial = ((capture['partialStream'] as Map)['events'] as List)
        .cast<Map<String, Object?>>();
    final textFrames = partial
        .where((e) => (e['type']! as String).startsWith('session.text.'))
        .toList();
    expect(textFrames.length, 2);
    final native = (textFrames.first['data']! as Map)['sessionID']! as String;
    final ref = SessionRef(historyRef.host, historyRef.harness, native);
    var state = SessionState(ref);
    for (var i = 0; i < partial.length; i++) {
      state = applyText(partial[i], state, i + 1);
    }
    final before = state.timeline.single as AssistantText;
    expect(before.text, (textFrames.last['data']! as Map)['delta']);
    expect(before.complete, isFalse);
    final reconnected = (capture['reconnectedStream'] as Map)['events'] as List;
    expect(reconnected.map((e) => (e as Map)['type']), [
      'server.connected',
      'session.renamed',
    ]);
    for (final frame in reconnected) {
      expect(projectText(frame, current: state, seq: 100), isNull);
    }
    expect(identical(state.timeline.single, before), isTrue);
    expect(state.execution, isNull);
  });
}
