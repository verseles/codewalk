import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeStepUsageProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeStepUsageProjectionException implements Exception {
  const OpenCodeStepUsageProjectionException(this.failure);

  final OpenCodeStepUsageProjectionFailure failure;

  @override
  String toString() => 'OpenCodeStepUsageProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _listLimit = 4096;
const _safeInteger = 9007199254740991;
const _maxEpochMillis = 8640000000000000;
const _started = 'session.step.started';
const _streamed = 'session.step.streamed';
const _ended = 'session.step.ended';
const _failed = 'session.step.failed';
const _usage = 'session.usage.updated';
const _types = {_started, _streamed, _ended, _failed, _usage};
const _finishes = {
  'stop',
  'length',
  'tool-calls',
  'content-filter',
  'error',
  'unknown',
};

/// Projects the four 2.0.22 step lifecycle events and the session usage event
/// without owning a stream or clock.
///
/// Returns an unmodifiable list to reduce in order against the latest
/// [current] state; unrelated types and foreign sessions return an empty list.
/// `started` and `streamed` are validated and emit nothing: Core has no step
/// state and execution lifecycle belongs to the execution producer.
///
/// `ended` emits a per-step [UsageObserved] (turn scope, partial, identified
/// and keyed by the assistant message). `failed` emits the history-identical
/// `assistantErrorNotProjected` marker, plus step usage only when the frame
/// carries both cost and tokens. The ephemeral `usage.updated` emits the
/// cumulative session total, which replaces earlier readings and must never be
/// added to step observations. Observed zeros stay zeros; absent values stay
/// absent.
///
/// Error `message`, `status` and `response` and the frame location are never
/// read; provider state, snapshots, file paths, model and agent are validated
/// but never copied.
///
/// Known limit: Core has no single-item removal, so if a failed step restarts
/// under the same assistant message ID its error marker stays until the next
/// history read (the reference client clears it). No capture shows a restart
/// after a failure.
List<SessionEvent> projectOpenCodeStepUsageEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeStepUsageProjectionFailure.malformed);
  if (!_types.contains(type)) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeStepUsageProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    ref.host.value,
    ref.harness.value,
    ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > _maxEpochMillis) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  final step = type != _usage;
  BigInt? aggregateSeq;
  if (step) {
    final durable = _object(frame['durable']);
    if (_id(durable['aggregateID'], 'ses') != sessionId) {
      _fail(OpenCodeStepUsageProjectionFailure.malformed);
    }
    if (_integer(durable['version']) != 1) {
      _fail(OpenCodeStepUsageProjectionFailure.unsupportedVersion);
    }
    aggregateSeq = BigInt.from(_integer(durable['seq']));
  } else if (frame.containsKey('durable')) {
    // Ephemeral by the pinned schema, like the text/reasoning deltas.
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  final messageId = step ? _id(data['assistantMessageID'], 'msg_') : null;

  String? finish;
  String? errorType;
  _Usage? usage;
  switch (type) {
    case _started:
      _text(data['agent']);
      final model = _object(data['model']);
      _text(model['id']);
      _text(model['providerID']);
      if (model.containsKey('variant')) _text(model['variant']);
      _optionalText(data, 'snapshot');
      _integer(data['started']);
    case _streamed:
      break;
    case _ended:
      finish = _text(data['finish']);
      if (!_finishes.contains(finish)) {
        _fail(OpenCodeStepUsageProjectionFailure.unsupportedValue);
      }
      _stepTail(data);
      usage = _Usage(_amount(data['cost']), _tokens(data['tokens']));
    case _failed:
      final error = _object(data['error']);
      errorType = _text(error['type']);
      // Schema.String allows empty; the history marker requires a type.
      if (errorType.isEmpty) {
        _fail(OpenCodeStepUsageProjectionFailure.unsupportedValue);
      }
      if (data.containsKey('finish')) {
        finish = _text(data['finish']);
        if (finish != 'content-filter') {
          _fail(OpenCodeStepUsageProjectionFailure.unsupportedValue);
        }
      }
      _stepTail(data);
      final cost = data.containsKey('cost') ? _amount(data['cost']) : null;
      final tokens = data.containsKey('tokens')
          ? _tokens(data['tokens'])
          : null;
      // The reference client records failed-step usage only when both exist.
      if (cost != null && tokens != null) usage = _Usage(cost, tokens);
    case _usage:
      usage = _Usage(_amount(data['cost']), _tokens(data['tokens']));
  }

  final markerId = errorType == null
      ? null
      : ItemId(
          jsonEncode([
            ref.storageKey,
            messageId,
            'unknown',
            ['error', errorType, 0],
          ]),
        );
  if (markerId != null) {
    for (final item in current.timeline) {
      if (item.id == markerId && item is! UnknownItem) {
        _fail(OpenCodeStepUsageProjectionFailure.itemKindMismatch);
      }
    }
  }
  if (usage == null && markerId == null) return const [];

  final source = SourceProvenance(
    harness: ref.harnessRef,
    version: sourceVersion,
    nativeType: type,
    nativeEventId: nativeId,
    aggregateId: step ? sessionId : null,
    aggregateSeq: aggregateSeq,
    durability: OpenValue.known(
      step ? Durability.durable : Durability.ephemeral,
    ),
    extra: CanonicalValue({
      'nativeCreated': created,
      if (step) 'nativeDurableVersion': 1,
      'nativeMessageId': ?messageId,
      'finish': ?finish,
      if (errorType != null) 'errorContentNotProjected': true,
    }),
  );
  final eventMeta = EventMeta(
    owner: SessionOwner(ref),
    position: position,
    receivedAt: receivedAt,
    source: source,
  );
  return List.unmodifiable(<SessionEvent>[
    if (markerId != null)
      ItemUpserted(
        meta: eventMeta,
        item: UnknownItem(
          meta: ItemMeta(
            id: markerId,
            generation: jsonEncode([
              'live',
              ref.storageKey,
              messageId,
              position.id,
              position.epoch,
            ]),
            status: OpenValue<ItemStatus>.unknown('completionUnverified'),
            source: source,
          ),
          rawType: errorType!,
          raw: CanonicalValue({
            'type': errorType,
            'reason': 'assistantErrorNotProjected',
          }),
        ),
      ),
    if (usage != null)
      UsageObserved(
        meta: eventMeta,
        observation: _observation(
          usage,
          // A restarted step reuses its assistant message ID, so its new
          // terminal reading replaces the old one instead of adding to it.
          id: messageId == null ? nativeId : 'step:$messageId',
          owner: SessionOwner(ref),
          step: messageId,
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            // `created` is `Schema.Finite`; DateTime keeps milliseconds.
            created.floor(),
            isUtc: true,
          ),
          provenance: source,
        ),
      ),
  ]);
}

final class _Usage {
  const _Usage(this.cost, this.tokens);

  final num cost;
  final TokenBreakdown tokens;
}

/// Mirrors Core's accepted A convention: a step is a partial observation
/// within its turn; `usage.updated` is the cumulative session series.
UsageObservation _observation(
  _Usage usage, {
  required String id,
  required DomainOwner owner,
  required String? step,
  required DateTime observedAt,
  required SourceProvenance provenance,
}) {
  final cumulative = step == null;
  return UsageObservation(
    id: id,
    owner: owner,
    scope: OpenValue.known(cumulative ? UsageScope.session : UsageScope.turn),
    source: const OpenValue.known(UsageSource.native),
    observedAt: observedAt,
    tokens: usage.tokens,
    // The pinned schema brands every amount as `Money.USD`.
    cost: Cost(
      amount: usage.cost,
      currency: 'USD',
      partial: !cumulative,
      cumulative: cumulative,
    ),
    partial: !cumulative,
    cumulative: cumulative,
    aggregationKey: cumulative ? 'session-total' : 'step:$step',
    provenance: provenance,
  );
}

/// Validates the optional step tail fields without retaining them.
void _stepTail(Map<String, Object?> data) {
  _optionalText(data, 'rawFinish');
  _optionalText(data, 'snapshot');
  if (data.containsKey('providerState')) _object(data['providerState']);
  if (data.containsKey('files')) {
    final files = data['files'];
    if (files is! List<Object?>) {
      _fail(OpenCodeStepUsageProjectionFailure.malformed);
    }
    if (files.length > _listLimit) {
      _fail(OpenCodeStepUsageProjectionFailure.limitExceeded);
    }
    for (final file in files) {
      _text(file);
    }
  }
}

TokenBreakdown _tokens(Object? value) {
  final tokens = _object(value);
  final cache = _object(tokens['cache']);
  return TokenBreakdown(
    input: _amount(tokens['input']),
    output: _amount(tokens['output']),
    reasoning: _amount(tokens['reasoning']),
    cacheRead: _amount(cache['read']),
    cacheWrite: _amount(cache['write']),
  );
}

/// Finite native numbers; Core usage values cannot be negative.
num _amount(Object? value) {
  if (value is! num || !value.isFinite) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  if (value < 0) _fail(OpenCodeStepUsageProjectionFailure.unsupportedValue);
  return value;
}

void _optionalText(Map<String, Object?> data, String key) {
  if (data.containsKey(key)) _text(data[key]);
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeStepUsageProjectionFailure.malformed);
  }
  _bytes(value, _idLimit);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeStepUsageProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeStepUsageProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeStepUsageProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeStepUsageProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeStepUsageProjectionFailure.limitExceeded);
  }
}

Never _fail(OpenCodeStepUsageProjectionFailure failure) =>
    throw OpenCodeStepUsageProjectionException(failure);
