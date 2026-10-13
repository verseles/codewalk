import 'dart:convert';

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
const _types = {_started, _succeeded, _failed, _interrupted};
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
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeExecutionProjectionFailure.malformed);
  if (!_types.contains(type)) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  if (sessionId != current.ref.nativeId) return const [];
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
  final aggregateSeq = BigInt.from(_integer(durable['seq']));

  ErrorInfo? error;
  String? reason;
  if (type == _failed) {
    final rawError = _object(data['error']);
    final errorType = _text(rawError['type'], cap: _idLimit);
    // Schema.String allows empty; Core ErrorInfo requires a nonempty rawType.
    if (errorType.isEmpty) {
      _fail(OpenCodeExecutionProjectionFailure.unsupportedValue);
    }
    error = ErrorInfo(
      kind: const OpenValue.known(ErrorKind.unknown),
      rawType: errorType,
      rawMessage: '',
    );
  }
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
