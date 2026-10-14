import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:harness_opencode/src/history_projection.dart';

import 'history_test_data.dart';
import 'inbox_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from the immutable observed D capture.
Map<String, Object?> revertFrame(
  String phase, {
  String id = 'evt_revert',
  String session = 'ses_a',
  Map<String, Object?>? revert,
  String to = 'msg_b',
  Object? seq = 3,
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.revert.$phase',
  'location': {'directory': '/fake-private-location'},
  'data': <String, Object?>{
    'sessionID': session,
    if (phase == 'staged') 'revert': revert ?? revertData(),
    if (phase == 'committed') 'to': to,
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': seq,
    'version': 1,
  },
};

Map<String, Object?> revertData({
  String message = 'msg_b',
  Object? files = const [],
  bool withFiles = true,
  Map<String, Object?> fields = const {},
}) => {
  'messageID': message,
  'snapshot': 'fake-private-snapshot',
  if (withFiles) 'files': files == const [] ? [fileDiff('src/a.txt')] : files,
  ...fields,
};

Map<String, Object?> fileDiff(
  String file, {
  String status = 'modified',
  Object? additions = 1,
  Object? deletions = 2,
}) => {
  'file': file,
  'patch': 'fake-private-patch',
  'additions': additions,
  'deletions': deletions,
  'status': status,
};

EventMeta seedMeta(int seq) => EventMeta(
  owner: SessionOwner(historyRef),
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
  source: SourceProvenance(
    harness: historyRef.harnessRef,
    version: '2.0.22',
    nativeType: 'seed',
  ),
);

/// Resident history items for messages `a` (user), `b` (user) and `c`
/// (assistant), then queued prompts `msg_a5` and `msg_c5` left pending.
SessionState seededState({
  List<Map<String, Object?>>? messages,
  List<String> pending = const ['msg_a5', 'msg_c5'],
}) {
  var state = SessionState(historyRef);
  final items = projectOpenCodeHistory(
    messages ??
        [
          message('a', 'user', {'text': 'first'}),
          message('b', 'user', {'text': 'second'}),
          assistant('c', [textBlock('answer')], completed: true),
        ],
    historyRef,
    sourceVersion: '2.0.22',
  );
  var seq = 1;
  for (final item in items) {
    state = reduce(
      state,
      ItemUpserted(meta: seedMeta(seq++), item: item),
    ).state;
  }
  for (final inbox in pending) {
    for (final event in projectInbox(
      inboxFrame(
        'enqueued',
        id: 'evt_$inbox',
        inbox: inbox,
        item: userItem('later', delivery: 'queue'),
      ),
      current: state,
      seq: seq++,
    )) {
      state = reduce(state, event).state;
    }
  }
  return state;
}

List<SessionEvent> projectRevert(
  Object? frame, {
  SessionState? current,
  int seq = 100,
  String version = '2.0.22',
}) => projectOpenCodeRevertEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: DateTime.utc(2026, 10, 14),
);

String? messageOf(ItemId id) => (jsonDecode(id.value) as List)[1] as String?;

String revertManifest(SessionEvent event) => jsonEncode({
  'type': event.runtimeType.toString(),
  'source': {
    'type': event.meta.source.nativeType,
    'event': event.meta.source.nativeEventId,
    'aggregate': event.meta.source.aggregateId,
    'seq': event.meta.source.aggregateSeq?.toString(),
    'durability': event.meta.source.durability.value,
    'extra': event.meta.source.extra?.value,
  },
  ...switch (event) {
    RevertChanged(:final state) => {
      'kind': state.kind.value,
      'boundary': state.boundary?.value,
      'details': state.details?.value,
    },
    ItemsRemoved(:final fromItemId) => {'from': fromItemId.value},
    PendingInputChanged(:final items) => {
      'pending': [for (final item in items) item.id.value],
    },
    ResyncRequired(:final reason) => {'reason': reason},
    _ => throw StateError('Unexpected revert producer event.'),
  },
});
