import 'dart:collection';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from immutable observed A/B captures.
Map<String, Object?> toolFrame(
  String phase, {
  String id = 'evt_tool',
  String session = 'ses_a',
  String message = 'msg_a',
  String call = 'functions.read:0',
  String name = 'read',
  Object? input = const {'path': 'file.txt'},
  List<Object?> content = const [
    {'type': 'text', 'text': 'result'},
  ],
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.tool.$phase',
  'data': <String, Object?>{
    'sessionID': session,
    'assistantMessageID': message,
    'id': call,
    if (phase == 'input.started') 'name': name,
    if (phase == 'input.delta') 'delta': '{"token":',
    if (phase == 'input.ended') 'text': '{not guaranteed JSON',
    if (phase == 'called') 'input': input,
    if (['called', 'success', 'failed'].contains(phase)) 'executed': false,
    if (phase == 'progress')
      'metadata': <String, Object?>{'shellID': 'fake-private'},
    if (phase == 'success') 'content': content,
    if (phase == 'failed')
      'error': <String, Object?>{'type': 'aborted', 'message': 'fake-private'},
  },
  if (!['input.delta', 'progress'].contains(phase))
    'durable': <String, Object?>{
      'aggregateID': session,
      'seq': 0.0,
      'version': ['success', 'failed'].contains(phase) ? 2.0 : 1.0,
    },
};

Map<String, Object?> toolData(Map<String, Object?> frame) =>
    frame['data']! as Map<String, Object?>;
SessionEvent? projectTool(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String epoch = 'epoch-a',
  String version = '2.0.22',
}) => projectOpenCodeToolEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq, epoch: epoch),
  receivedAt: DateTime.utc(2026, 10, 13),
);
SessionState applyTool(Object? frame, SessionState current, int seq) {
  final event = projectTool(frame, current: current, seq: seq);
  return event == null ? current : reduce(current, event).state;
}

SessionState startedTool() =>
    applyTool(toolFrame('input.started'), SessionState(historyRef), 1);
SessionState residentState(TimelineItem item) => reduce(
  SessionState(historyRef),
  ItemUpserted(
    meta: EventMeta(
      owner: SessionOwner(historyRef),
      position: observedPosition(1),
      receivedAt: DateTime.utc(2026, 10, 13),
      source: item.source,
    ),
    item: item,
  ),
).state;

String toolManifest(SessionEvent event) => jsonEncode({
  'owner': event.meta.owner.scopeKey,
  'position': event.meta.position.toJson(),
  'received': event.meta.receivedAt.toIso8601String(),
  'source': {
    'harness': event.meta.source.harness.toJson(),
    'version': event.meta.source.version,
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'aggregate': event.meta.source.aggregateId,
    'seq': event.meta.source.aggregateSeq?.toString(),
    'durability': event.meta.source.durability.value,
    'cursor': event.meta.source.nativeCursor,
    'extra': event.meta.source.extra?.value,
    'rawRef': event.meta.rawRef?.id,
  },
  ...switch (event) {
    ItemUpserted(:final item) => {'item': semanticItem(item)},
    ResyncRequired(:final reason) => {'reason': reason},
    _ => throw StateError('Unexpected tool producer event.'),
  },
});

/// Fails when an explicitly unselected field is even read, before serialization.
final class PrivateToolFields extends MapBase<String, Object?> {
  PrivateToolFields(this.fields, this.forbidden);
  final Map<String, Object?> fields;
  final Set<String> forbidden;
  @override
  Object? operator [](Object? key) {
    if (forbidden.contains(key)) throw StateError('Unselected field read.');
    return fields[key];
  }

  @override
  bool containsKey(Object? key) => fields.containsKey(key);
  @override
  Iterable<String> get keys => fields.keys;
  @override
  void operator []=(String key, Object? value) =>
      throw UnsupportedError('Read only.');
  @override
  void clear() => throw UnsupportedError('Read only.');
  @override
  Object? remove(Object? key) => throw UnsupportedError('Read only.');
}
