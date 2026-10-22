import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';

import 'history_test_data.dart';
import 'text_reasoning_test_data.dart' show observedPosition;

// Source-shaped inputs, distinct from immutable observed A–E captures.
Map<String, Object?> executionFrame(
  String phase, {
  String id = 'evt_exec',
  String session = 'ses_a',
  String? reason,
  Object? error = const {
    'type': 'provider.auth',
    'message': 'fake-private-message',
    'status': 401,
    'response': {'body': 'fake-private-body'},
  },
  Object? seq = 0.0,
  Object? version = 1.0,
}) => {
  'id': id,
  'created': 1000,
  'type': 'session.execution.$phase',
  'data': <String, Object?>{
    'sessionID': session,
    if (phase == 'failed') 'error': error,
    if (phase == 'interrupted') 'reason': reason ?? 'user',
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': seq,
    'version': version,
  },
};

/// Contract-derived (`plan/12` §5): no 2.0.22 capture holds a retry (#243).
Map<String, Object?> retryFrame({
  String id = 'evt_retry',
  String session = 'ses_a',
  String message = 'msg_step',
  Object? attempt = 1,
  // The server's clock: 30 s after 2026-10-13T00:00:00Z.
  Object? at = 1791849630000,
  Object? created = 1791849600000,
  Object? error = const {
    'type': 'provider.rate-limit',
    'message': 'fake-private-message',
    'status': 429,
    'response': {'body': 'fake-private-body'},
  },
  Object? version = 1,
}) => {
  'id': id,
  'created': created,
  'type': 'session.retry.scheduled',
  'data': <String, Object?>{
    'sessionID': session,
    'assistantMessageID': message,
    'attempt': attempt,
    'at': at,
    'error': error,
  },
  'durable': <String, Object?>{
    'aggregateID': session,
    'seq': 0,
    'version': version,
  },
};

List<SessionEvent> projectRetry(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  DateTime? receivedAt,
  String version = '2.0.22',
}) => projectOpenCodeRetryEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq),
  receivedAt: receivedAt ?? DateTime.utc(2026, 10, 13),
);

List<SessionEvent> projectExecution(
  Object? frame, {
  SessionState? current,
  int seq = 1,
  String epoch = 'epoch-a',
  String version = '2.0.22',
}) => projectOpenCodeExecutionEvent(
  frame,
  current ?? SessionState(historyRef),
  sourceVersion: version,
  position: observedPosition(seq, epoch: epoch),
  receivedAt: DateTime.utc(2026, 10, 13),
);

/// Projects then reduces every returned event in order.
SessionState applyExecution(Object? frame, SessionState current, int seq) {
  var state = current;
  for (final event in projectExecution(frame, current: current, seq: seq)) {
    state = reduce(state, event).state;
  }
  return state;
}

Map<String, Object?>? outcomeJson(ExecutionOutcome? outcome) => outcome == null
    ? null
    : {
        'kind': outcome.kind.value,
        'reason': outcome.reason,
        'error': errorJson(outcome.error),
      };

Map<String, Object?>? errorJson(ErrorInfo? error) => error == null
    ? null
    : {
        'kind': error.kind.value,
        'rawType': error.rawType,
        'rawMessage': error.rawMessage,
        'retryable': error.retryable,
        'retryAt': error.retryAt?.toIso8601String(),
        'action': error.action?.value,
        'details': error.details?.value,
      };

Map<String, Object?> executionJson(ExecutionState state) => {
  'kind': state.kind.value,
  'retryAt': state.retryAt?.toIso8601String(),
  'error': errorJson(state.error),
  'lastOutcome': outcomeJson(state.lastOutcome),
};

String executionManifest(SessionEvent event) => jsonEncode({
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
    ExecutionChanged(:final state) => {'execution': executionJson(state)},
    ItemUpserted(:final item) => {'item': semanticItem(item)},
    _ => throw StateError('Unexpected execution producer event.'),
  },
});
