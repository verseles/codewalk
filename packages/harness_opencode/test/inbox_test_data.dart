import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from immutable observed A–E captures.
Map<String, Object?> inboxFrame(
  String phase, {
  String id = 'evt_inbox',
  String session = 'ses_a',
  String inbox = 'msg_in',
  Object? item,
  String? delivery,
  Object? seq = 0.0,
  Object? version = 1.0,
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.inbox.$phase',
  'location': {'directory': '/fake-private-location'},
  'data': <String, Object?>{
    'sessionID': session,
    'inboxID': inbox,
    if (phase == 'enqueued') 'item': item ?? userItem('hello'),
    if (phase == 'delivery.changed') 'delivery': delivery ?? 'steer',
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': seq,
    'version': version,
  },
};

Map<String, Object?> userItem(
  String text, {
  String delivery = 'steer',
  Map<String, Object?> fields = const {},
}) => {
  'type': 'user',
  'payload': {
    'text': text,
    'metadata': {'secret': 'fake-private-metadata'},
    ...fields,
  },
  'delivery': delivery,
};

Map<String, Object?> syntheticItem(String text, {String delivery = 'steer'}) =>
    {
      'type': 'synthetic',
      'payload': {
        'text': text,
        'description': 'fake-private-description',
        'metadata': {'secret': 'fake-private-metadata'},
      },
      'delivery': delivery,
    };

/// Every private value an attached context may carry; none may be projected.
const privateContext = <String, Object?>{
  'files': [
    {
      'data': 'ZmFrZS1wcml2YXRlLWRhdGE=',
      'mime': 'image/png',
      'source': {'type': 'uri', 'uri': 'file:///fake-private-uri'},
      'name': 'fake-private-name.png',
      'description': 'fake-private-file-description',
      'mention': {'start': 0, 'end': 4, 'text': 'fake-private-mention'},
    },
  ],
  'agents': [
    {'name': 'fake-private-agent'},
  ],
  'skills': [
    {'id': 'fake-private-skill', 'name': 'skill', 'text': 'fake-private-text'},
  ],
};

ItemId inboxItemId(String inbox, String kind, [Object discriminator = 0]) =>
    ItemId(jsonEncode([historyRef.storageKey, inbox, kind, discriminator]));

List<SessionEvent> projectInbox(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String epoch = 'epoch-a',
  String version = '2.0.22',
}) => projectOpenCodeInboxEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq, epoch: epoch),
  receivedAt: DateTime.utc(2026, 10, 13),
);

/// Projects then reduces every returned event in order.
SessionState applyInbox(Object? frame, SessionState current, int seq) {
  var state = current;
  for (final event in projectInbox(frame, current: current, seq: seq)) {
    state = reduce(state, event).state;
  }
  return state;
}

Map<String, Object?> pendingJson(PendingInput input) => {
  'id': input.id.value,
  'text': input.text,
  'delivery': input.delivery.value,
  'command': input.commandId?.value,
};

String inboxManifest(SessionEvent event) => jsonEncode({
  'owner': event.meta.owner.scopeKey,
  'position': event.meta.position.toJson(),
  'source': {
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'aggregate': event.meta.source.aggregateId,
    'seq': event.meta.source.aggregateSeq?.toString(),
    'extra': event.meta.source.extra?.value,
  },
  ...switch (event) {
    ItemUpserted(:final item) => {'item': semanticItem(item)},
    PendingInputChanged(:final items) => {
      'pending': items.map(pendingJson).toList(),
    },
    _ => throw StateError('Unexpected inbox producer event.'),
  },
});
