import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeExecutionProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeExecutionProjectionException implements Exception {
  const OpenCodeExecutionProjectionException(this.failure);

  final OpenCodeExecutionProjectionFailure failure;

  @override
  String toString() => 'OpenCodeExecutionProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _safeInteger = 9007199254740991;
const _started = 'session.execution.started';
const _succeeded = 'session.execution.succeeded';
const _failed = 'session.execution.failed';
const _interrupted = 'session.execution.interrupted';
const _retry = 'session.retry.scheduled';
const _types = {_started, _succeeded, _failed, _interrupted};
const _maxEpochMillis = 8640000000000000;
const _reasons = {'user', 'shutdown', 'superseded', 'inactivity'};

/// Projects the four 2.0.22 execution lifecycle events without owning a stream
/// or clock.
///
/// Returns an unmodifiable list to reduce in order against the latest
/// [current] state: empty for unrelated types and foreign sessions, one
/// [ExecutionChanged] for `started` and `interrupted(shutdown)`, otherwise an
/// [ExecutionChanged] followed by an [ItemUpserted] [TurnOutcome] whose ID
/// matches the history `idle` row. A shutdown keeps the server's execution
/// claim for resumption, so it records no outcome and keeps the previous one.
///
/// Failure `message`, `status` and `response` are never read; the error kind
/// stays unknown and no retry is inferred. Reference-client refetches (open
/// tool parts, missing session info) belong to the stream owner.
List<SessionEvent> projectOpenCodeExecutionEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final header = _header(value, current, _types, sourceVersion, position);
  if (header == null) return const [];
  final (:type, :data, :nativeId, :created, :aggregateId, :aggregateSeq) =
      header;

  ErrorInfo? error;
  String? reason;
  if (type == _failed) error = _error(data['error']);
  if (type == _interrupted) {
    reason = _text(data['reason'], cap: _idLimit);
    if (!_reasons.contains(reason)) {
      _fail(OpenCodeExecutionProjectionFailure.unsupportedValue);
    }
  }
  final shutdown = reason == 'shutdown';
  final records = type != _started && !shutdown;
  final messageId = records ? 'msg_${nativeId.substring(4)}' : null;
  final eventMeta = EventMeta(
    owner: SessionOwner(current.ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: current.ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      aggregateId: aggregateId,
      aggregateSeq: aggregateSeq,
      durability: const OpenValue.known(Durability.durable),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeDurableVersion': 1,
        'nativeMessageId': ?messageId,
        'interruptReason': ?reason,
        if (error != null) 'errorContentNotProjected': true,
      }),
    ),
  );

  final previous = current.execution?.lastOutcome;
  if (type == _started || shutdown) {
    return List.unmodifiable([
      ExecutionChanged(
        meta: eventMeta,
        state: ExecutionState(
          kind: OpenValue.known(
            shutdown
                ? ExecutionKind.interruptedPendingResume
                : ExecutionKind.running,
          ),
          lastOutcome: previous,
        ),
      ),
    ]);
  }

  final (executionKind, outcomeKind) = switch (type) {
    _succeeded => (ExecutionOutcomeKind.succeeded, OutcomeKind.succeeded),
    _failed => (ExecutionOutcomeKind.failed, OutcomeKind.failed),
    _ => (ExecutionOutcomeKind.interrupted, OutcomeKind.interrupted),
  };
  final id = ItemId(
    jsonEncode([current.ref.storageKey, messageId, 'outcome', 0]),
  );
  for (final item in current.timeline) {
    if (item.id == id && item is! TurnOutcome) {
      _fail(OpenCodeExecutionProjectionFailure.itemKindMismatch);
    }
  }
  return List.unmodifiable([
    ExecutionChanged(
      meta: eventMeta,
      state: ExecutionState(
        kind: const OpenValue.known(ExecutionKind.idle),
        lastOutcome: ExecutionOutcome(
          OpenValue.known(executionKind),
          error: error,
          reason: reason,
        ),
      ),
    ),
    ItemUpserted(
      meta: eventMeta,
      // History idle rows carry only the outcome; error and reason stay on
      // the execution state so live and history items remain identical.
      item: TurnOutcome(
        meta: ItemMeta(
          id: id,
          generation: jsonEncode([
            'live',
            current.ref.storageKey,
            messageId,
            position.id,
            position.epoch,
          ]),
          status: const OpenValue.known(ItemStatus.completed),
          source: eventMeta.source,
        ),
        kind: OpenValue.known(outcomeKind),
      ),
    ),
  ]);
}

/// Projects the 2.0.22 `session.retry.scheduled` event without owning a
/// stream or clock: one [RetryScheduled] that holds the execution in
/// retrying until the next `session.step.started` or the execution's end,
/// which the step and execution producers observe.
///
/// `at` is the next attempt on the server's clock. The deadline is the
/// earlier of `at` and the server's own delay (`at - created`) counted from
/// [receivedAt]: a device clock behind the server's keeps that delay, while a
/// late delivery or a device clock ahead keeps `at`, which can shorten the
/// wait but never lengthen it. A deadline already past becomes [receivedAt]
/// so no wait is shown. The native values stay in the provenance.
///
/// Error `message`, `status` and `response` are never read; the error kind
/// stays unknown.
List<SessionEvent> projectOpenCodeRetryEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final header = _header(value, current, {_retry}, sourceVersion, position);
  if (header == null) return const [];
  final (:type, :data, :nativeId, :created, :aggregateId, :aggregateSeq) =
      header;
  final messageId = _id(data['assistantMessageID'], 'msg_');
  final attempt = _integer(data['attempt']);
  // The reference client counts attempts from one, like the history row.
  if (attempt < 1) _fail(OpenCodeExecutionProjectionFailure.malformed);
  final at = data['at'];
  if (at is! num || !at.isFinite || at < 0 || at > _maxEpochMillis) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  if (created < 0 || created > _maxEpochMillis) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  final error = _error(data['error']);
  final received = receivedAt.millisecondsSinceEpoch;
  final deadline = max(received, min(at, received + (at - created)));
  final retryAt = DateTime.fromMillisecondsSinceEpoch(
    deadline.round(),
    isUtc: true,
  );
  return List.unmodifiable([
    RetryScheduled(
      meta: EventMeta(
        owner: SessionOwner(current.ref),
        position: position,
        receivedAt: receivedAt,
        source: SourceProvenance(
          harness: current.ref.harnessRef,
          version: sourceVersion,
          nativeType: type,
          nativeEventId: nativeId,
          aggregateId: aggregateId,
          aggregateSeq: aggregateSeq,
          durability: const OpenValue.known(Durability.durable),
          extra: CanonicalValue({
            'nativeCreated': created,
            'nativeDurableVersion': 1,
            'nativeMessageId': messageId,
            'nativeRetryAt': at,
            'errorContentNotProjected': true,
          }),
        ),
      ),
      attempt: attempt,
      at: retryAt,
      error: error,
    ),
  ]);
}

/// The validated durable v1 frame of one of [types] for this session, or
/// null for another type or session.
({
  String type,
  Map<String, Object?> data,
  String nativeId,
  num created,
  String aggregateId,
  BigInt aggregateSeq,
})?
_header(
  Object? value,
  SessionState current,
  Set<String> types,
  String sourceVersion,
  StreamPosition position,
) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeExecutionProjectionFailure.malformed);
  if (!types.contains(type)) return null;
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  if (sessionId != current.ref.nativeId) return null;
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeExecutionProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    current.ref.host.value,
    current.ref.harness.value,
    current.ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, cap: _idLimit, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num || !created.isFinite) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  final aggregateId = _id(durable['aggregateID'], 'ses');
  if (aggregateId != sessionId) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != 1) {
    _fail(OpenCodeExecutionProjectionFailure.unsupportedVersion);
  }
  return (
    type: type,
    data: data,
    nativeId: nativeId,
    created: created,
    aggregateId: aggregateId,
    aggregateSeq: BigInt.from(_integer(durable['seq'])),
  );
}

ErrorInfo _error(Object? value) {
  final errorType = _text(_object(value)['type'], cap: _idLimit);
  // Schema.String allows empty; Core ErrorInfo requires a nonempty rawType.
  if (errorType.isEmpty) {
    _fail(OpenCodeExecutionProjectionFailure.unsupportedValue);
  }
  return ErrorInfo(
    kind: const OpenValue.known(ErrorKind.unknown),
    rawType: errorType,
    rawMessage: '',
  );
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeExecutionProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeExecutionProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeExecutionProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeExecutionProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeExecutionProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeExecutionProjectionFailure.limitExceeded);
  }
}

Never _fail(OpenCodeExecutionProjectionFailure failure) =>
    throw OpenCodeExecutionProjectionException(failure);
