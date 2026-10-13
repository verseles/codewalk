import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';

// Source-shaped inputs, distinct from the immutable observed A/B captures.
Map<String, Object?> textFrame(
  String type, {
  String id = 'evt_a',
  String session = 'ses_a',
  String message = 'msg_a',
  Object? ordinal = 0,
  String content = 'fragment',
}) => {
  'id': id,
  'created': 1000,
  'type': type,
  'data': <String, Object?>{
    'sessionID': session,
    'assistantMessageID': message,
    'ordinal': ordinal,
    if (type.endsWith('.delta')) 'delta': content,
    if (type.endsWith('.ended')) 'text': content,
  },
  if (!type.endsWith('.delta'))
    'durable': <String, Object?>{
      'aggregateID': session,
      'seq': 7,
      'version': 1,
    },
};

Map<String, Object?> frameData(Map<String, Object?> frame) =>
    frame['data']! as Map<String, Object?>;

StreamPosition observedPosition(int seq, {String epoch = 'epoch-a'}) =>
    StreamPosition(id: 'observer-a', epoch: epoch, seq: BigInt.from(seq));

SessionEvent? projectText(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String epoch = 'epoch-a',
  String version = '2.0.22',
}) => projectOpenCodeTextReasoningEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq, epoch: epoch),
  receivedAt: DateTime.utc(2026, 10, 13),
);

SessionState applyText(Object? frame, SessionState current, int seq) {
  final event = projectText(frame, current: current, seq: seq);
  return event == null ? current : reduce(current, event).state;
}

String projectedManifest(SessionEvent event) => jsonEncode({
  'owner': event.meta.owner.scopeKey,
  'position': event.meta.position.toJson(),
  'received': event.meta.receivedAt.toIso8601String(),
  'source': {
    'harness': event.meta.source.harness.toJson(),
    'version': event.meta.source.version,
    'type': event.meta.source.nativeType,
    'nativeId': event.meta.source.nativeEventId,
    'aggregateId': event.meta.source.aggregateId,
    'aggregateSeq': event.meta.source.aggregateSeq?.toString(),
    'cursor': event.meta.source.nativeCursor,
    'durability': event.meta.source.durability.value,
    'extra': event.meta.source.extra?.toJson(),
    'rawRef': event.meta.rawRef?.id,
  },
  ...switch (event) {
    ItemUpserted(:final item) => {'item': semanticItem(item)},
    ItemDelta() => {
      'itemId': event.itemId.value,
      'generation': event.generation,
      'field': event.field.value,
      'text': event.text,
    },
    _ => throw StateError('Unexpected projector event.'),
  },
});
