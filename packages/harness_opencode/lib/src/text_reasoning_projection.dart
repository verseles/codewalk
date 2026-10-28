import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'item_ids.dart';
import 'message_context.dart';
import 'version_policy.dart';

enum OpenCodeTextProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
}

/// Contains only a finite failure category, never native input or identifiers.
final class OpenCodeTextProjectionException implements Exception {
  const OpenCodeTextProjectionException(this.failure);

  final OpenCodeTextProjectionFailure failure;

  @override
  String toString() => 'OpenCodeTextProjectionException(${failure.name})';
}

const _textLimit = 256 * 1024;
const _idLimit = 4096;
const _safeInteger = 9007199254740991;
const _types = {
  'session.text.started',
  'session.text.delta',
  'session.text.ended',
  'session.reasoning.started',
  'session.reasoning.delta',
  'session.reasoning.ended',
};

/// Projects the verified 2.0.22 text/reasoning subset without owning a stream.
///
/// Project and reduce each observation against the latest [current] state;
/// mapping an entire batch against an old state defeats the content bounds.
/// Returns null for unrelated types, foreign sessions and starts for an already
/// resident item. Malformed selected fields and limits produce sanitized errors.
///
/// IDs are capped at 4 KiB UTF-8 and text at 256 KiB per field/open block.
/// The cumulative check precedes reducer deduplication: an otherwise over-limit
/// duplicate may be rejected conservatively without changing the prefix.
/// These selected-content bounds do not bound upstream decoding/process memory.
/// Provider state and arbitrary metadata are never read, copied or captured.
SessionEvent? projectOpenCodeTextReasoningEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeTextProjectionFailure.malformed);
  if (!_types.contains(type)) return null;
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  // /api/event is global; an unrelated session must not trigger recovery here.
  if (sessionId != current.ref.nativeId) return null;

  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeTextProjectionFailure.unsupportedVersion);
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
  final messageId = _id(data['assistantMessageID'], 'msg_');
  final ordinal = _integer(data['ordinal']);
  final created = frame['created'];
  if (created is! num || !created.isFinite) {
    _fail(OpenCodeTextProjectionFailure.malformed);
  }
  final delta = type.endsWith('.delta');
  final started = type.endsWith('.started');
  final reasoning = type.startsWith('session.reasoning.');
  String? aggregateId;
  BigInt? aggregateSeq;
  int? durableVersion;
  if (delta) {
    if (frame.containsKey('durable')) {
      _fail(OpenCodeTextProjectionFailure.malformed);
    }
  } else {
    final durable = _object(frame['durable']);
    aggregateId = _id(durable['aggregateID'], 'ses');
    if (aggregateId != sessionId) {
      _fail(OpenCodeTextProjectionFailure.malformed);
    }
    durableVersion = _integer(durable['version']);
    if (durableVersion != 1) {
      _fail(OpenCodeTextProjectionFailure.unsupportedVersion);
    }
    aggregateSeq = BigInt.from(_integer(durable['seq']));
  }
  final text = started
      ? ''
      : _text(data[delta ? 'delta' : 'text'], cap: _textLimit);
  final kind = reasoning ? 'reasoning' : 'text';
  final id = ItemId(
    jsonEncode([current.ref.storageKey, messageId, kind, ordinal]),
  );
  // Receipt identity scopes a live generation, not a native attempt or turn.
  final generation = jsonEncode([
    'live',
    current.ref.storageKey,
    messageId,
    position.id,
    position.epoch,
  ]);
  TimelineItem? existing;
  for (final item in current.timeline) {
    if (item.id == id) {
      existing = item;
      break;
    }
  }
  if (existing != null &&
      (reasoning ? existing is! Reasoning : existing is! AssistantText)) {
    _fail(OpenCodeTextProjectionFailure.itemKindMismatch);
  }
  // A distinct repeated start must not reset an observed prefix or history row.
  if (started && existing != null) return null;
  if (delta &&
      existing != null &&
      existing.generation == generation &&
      existing.status.known == ItemStatus.streaming) {
    final (prefix, complete) = switch (existing) {
      AssistantText v => (v.text, v.complete),
      Reasoning v => (v.text, v.complete),
      _ => throw StateError('Unreachable text projection item kind.'),
    };
    if (!complete &&
        _bytes(prefix, _textLimit) + _bytes(text, _textLimit) > _textLimit) {
      _fail(OpenCodeTextProjectionFailure.limitExceeded);
    }
  }

  final source = SourceProvenance(
    harness: current.ref.harnessRef,
    version: sourceVersion,
    nativeType: type,
    nativeEventId: nativeId,
    aggregateId: aggregateId,
    aggregateSeq: aggregateSeq,
    durability: OpenValue.known(
      delta ? Durability.ephemeral : Durability.durable,
    ),
    extra: CanonicalValue({
      'nativeCreated': created,
      'nativeMessageId': messageId,
      'ordinal': ordinal,
      'nativeDurableVersion': ?durableVersion,
    }),
  );
  final meta = EventMeta(
    owner: SessionOwner(current.ref),
    position: position,
    receivedAt: receivedAt,
    source: source,
  );
  if (delta) {
    return ItemDelta(
      meta: meta,
      itemId: id,
      field: OpenValue.known(
        reasoning ? DeltaField.reasoning : DeltaField.text,
      ),
      text: text,
      generation: generation,
    );
  }
  final itemMeta = ItemMeta(
    id: id,
    anchor: openCodeMessageAnchor(messageId),
    generation: generation,
    status: OpenValue.known(
      started ? ItemStatus.streaming : ItemStatus.completed,
    ),
    ordinal: ordinal,
    source: source,
    message: liveMessageContext(current, id, messageId),
  );
  return ItemUpserted(
    meta: meta,
    item: reasoning
        ? Reasoning(meta: itemMeta, text: text, complete: !started)
        : AssistantText(meta: itemMeta, text: text, complete: !started),
  );
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeTextProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeTextProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeTextProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeTextProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

int _bytes(String value, int cap) {
  if (value.length > cap) _fail(OpenCodeTextProjectionFailure.limitExceeded);
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) _fail(OpenCodeTextProjectionFailure.malformed);
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeTextProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeTextProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeTextProjectionFailure.limitExceeded);
  }
  return bytes;
}

Never _fail(OpenCodeTextProjectionFailure failure) =>
    throw OpenCodeTextProjectionException(failure);
