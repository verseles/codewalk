import 'dart:convert';
import 'dart:io';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'support/fixture_replay.dart';
import 'text_reasoning_test_data.dart' show observedPosition;
import 'tool_test_data.dart';

void main() {
  final fixtures = OpenCodeFixtures();
  SessionEvent? project(
    Map<String, Object?> frame,
    SessionState state,
    int seq,
  ) =>
      projectOpenCodeTextReasoningEvent(
        frame,
        state,
        sourceVersion: '2.0.22',
        position: observedPosition(seq),
        receivedAt: DateTime.utc(2026, 10, 13),
      ) ??
      projectTool(frame, current: state, seq: seq);
  SessionRef refFor(List<Map<String, Object?>> events) {
    final frame = events.firstWhere(
      (f) => (f['data'] as Map?)?.containsKey('sessionID') ?? false,
    );
    return SessionRef(
      historyRef.host,
      historyRef.harness,
      (frame['data']! as Map)['sessionID']! as String,
    );
  }

  Map<String, Object?> readB(String name) =>
      jsonDecode(File('${fixtures.root.path}/b/$name.json').readAsStringSync())
          as Map<String, Object?>;
  List<Map<String, Object?>> stream(Map<String, Object?> capture, String key) =>
      ((capture[key]! as Map)['events']! as List).cast<Map<String, Object?>>();

  test(
    'observed A: combined 27-frame replay equals four history content items',
    () {
      final parser = SseFrameParser();
      final frames = [
        for (final chunk in fixtures.observedAStream.frames)
          ...parser.add(utf8.encode(chunk)),
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
      final ref = refFor(events);
      var state = SessionState(ref);
      final projected = <SessionEvent>[];
      for (var i = 0; i < events.length; i++) {
        final event = project(events[i], state, i + 1);
        if (event == null) continue;
        projected.add(event);
        final result = reduce(state, event);
        expect(
          result.effects.every((e) => e is Notify && e.ref == ref),
          isTrue,
        );
        state = result.state;
      }
      expect(
        projected.length,
        13,
      ); // 10 text/reasoning + started/called/success.
      expect(state.timeline.length, 4);
      expect(state.timeline.map((i) => i.runtimeType), [
        Reasoning,
        ToolCall,
        Reasoning,
        AssistantText,
      ]);
      final history =
          projectOpenCodeHistory(
                fixtures.observedAHistory['data']! as List<Object?>,
                ref,
                sourceVersion: '2.0.22',
              )
              .where(
                (i) => i is Reasoning || i is AssistantText || i is ToolCall,
              )
              .toList();
      expect(history.length, 4);
      for (var i = 0; i < history.length; i++) {
        final live = state.timeline[i];
        expect(live.id, history[i].id);
        expect(live.generation, isNot(history[i].generation));
        expect(live.meta.ordinal, history[i].meta.ordinal);
        expect(live.turnId, isNull);
        final actual = semanticItem(live)
          ..remove('generation')
          ..remove('source');
        final expected = semanticItem(history[i])
          ..remove('generation')
          ..remove('source');
        expect(actual, expected);
      }
      final tool = state.timeline.whereType<ToolCall>().single;
      final historyTool = history.whereType<ToolCall>().single;
      expect(tool.rawName, 'read');
      expect(tool.kind, historyTool.kind);
      expect(tool.kind.known, ToolKind.read);
      expect(tool.meta.ordinal, isNull);
      expect(tool.output, historyTool.output);
      expect(tool.source.extra!.value, containsPair('executed', false));
      expect(tool.source.extra!.value, containsPair('truncated', false));
      for (final event in projected.where(
        (e) => e.meta.source.nativeType.startsWith('session.tool.'),
      )) {
        final manifest = toolManifest(event);
        for (final forbidden in [
          '_redacted',
          'opaque provider state omitted',
          'shellID',
        ]) {
          expect(manifest, isNot(contains(forbidden)));
        }
        expect(event.meta.source.nativeCursor, isNull);
        expect(event.meta.rawRef, isNull);
        expect(
          (event.meta.source.extra!.value as Map).containsKey('location'),
          isFalse,
        );
      }
      final before = state.timeline.map(semanticItem).toList();
      for (var i = 0; i < events.length; i++) {
        final event = project(events[i], state, 100 + i);
        if (event != null) state = reduce(state, event).state;
      }
      expect(state.timeline.map(semanticItem).toList(), before);
      expect(state.execution, isNull);
      expect(state.interactions, isEmpty);
      expect(state.pending, isEmpty);
      expect(state.work, isEmpty);
      expect(state.usage, isEmpty);
    },
  );

  for (final name in [
    'interrupt-resume',
    'shell-probe-space-bunny',
    'queue-steer-space-bunny',
  ]) {
    test(
      'observed B $name: progress does not supply terminal content or metadata',
      () {
        final events = stream(readB(name), 'stream');
        var state = SessionState(refFor(events));
        final tools = events
            .where((f) => (f['type']! as String).startsWith('session.tool.'))
            .toList();
        final projected = <SessionEvent>[];
        for (var i = 0; i < tools.length; i++) {
          final event = projectTool(tools[i], current: state, seq: i + 1);
          if (event == null) continue;
          projected.add(event);
          final result = reduce(state, event);
          expect(result.effects.every((e) => e is Notify), isTrue);
          state = result.state;
        }
        expect(projected.length, 3);
        final tool = state.timeline.single as ToolCall;
        expect(tool.rawName, 'shell');
        expect(tool.kind.known, ToolKind.other);
        final terminal = toolData(tools.last);
        expect(
          tool.source.extra!.value,
          containsPair('executed', terminal['executed']),
        );
        if (name == 'interrupt-resume') {
          expect(tool.status.known, ItemStatus.interrupted);
          expect(tool.error!.rawType, 'aborted');
          expect(tool.error!.rawMessage, 'Tool execution interrupted');
          expect(tool.output, isNull);
        } else {
          expect(tool.status.known, ItemStatus.completed);
          expect(tool.output!.value, terminal['content']);
          expect(tool.source.extra!.value, containsPair('truncated', false));
        }
        for (final event in projected) {
          final manifest = toolManifest(event);
          for (final forbidden in [
            'shellID',
            'Tool execution interrupted',
            'opaque provider state omitted',
            '"exit"',
            '"resultState"',
          ]) {
            expect(manifest, isNot(contains(forbidden)));
          }
          expect(event.meta.source.nativeCursor, isNull);
          expect(event.meta.rawRef, isNull);
        }
        expect(state.execution, isNull);
      },
    );
  }

  test(
    'observed B reconnect: completed tool and incomplete text stay observed',
    () {
      final capture = readB('disconnect-reconnect');
      final events = stream(capture, 'partialStream');
      var state = SessionState(refFor(events));
      for (var i = 0; i < events.length; i++) {
        final event = project(events[i], state, i + 1);
        if (event != null) state = reduce(state, event).state;
      }
      expect(
        state.timeline.whereType<ToolCall>().single.status.known,
        ItemStatus.completed,
      );
      expect(
        state.timeline.whereType<AssistantText>().single.complete,
        isFalse,
      );
      final before = state;
      final reconnected = stream(capture, 'reconnectedStream');
      expect(reconnected.map((e) => e['type']), [
        'server.connected',
        'session.renamed',
      ]);
      for (final frame in reconnected) {
        expect(project(frame, state, 100), isNull);
      }
      expect(state, same(before));
      expect(state.execution, isNull);
    },
  );
}
