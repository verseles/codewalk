import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'item_ids.dart';
import 'version_policy.dart';

enum OpenCodeNoticeProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeNoticeProjectionException implements Exception {
  const OpenCodeNoticeProjectionException(this.failure);

  final OpenCodeNoticeProjectionFailure failure;

  @override
  String toString() => 'OpenCodeNoticeProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _listLimit = 4096;
const _textLimit = 256 * 1024;
const _safeInteger = 9007199254740991;
const _maxEpochMillis = 8640000000000000;
const _instructions = 'session.instructions.updated';
const _synthetic = 'session.synthetic';
const _durableVersions = {_instructions: 2, _synthetic: 1};

/// Projects the durable 2.0.22 instruction-update and synthetic events into
/// [Notice] items without owning a stream or clock.
///
/// Returns an unmodifiable list to reduce against the latest [current] state,
/// empty for unrelated types, other sessions and instruction updates without
/// rendered text (the baseline observation and deltas that render empty),
/// which add no transcript message. Otherwise it holds one [ItemUpserted]
/// whose ID equals the history `system`/`synthetic` row: the server derives
/// that message ID from the event ID.
///
/// Instruction sources, synthetic descriptions, native metadata and the frame
/// location are validated where declared and never copied.
List<SessionEvent> projectOpenCodeNoticeEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeNoticeProjectionFailure.malformed);
  final durableVersion = _durableVersions[type];
  if (durableVersion == null) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeNoticeProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    ref.host.value,
    ref.harness.value,
    ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, cap: _idLimit, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > _maxEpochMillis) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != durableVersion) {
    _fail(OpenCodeNoticeProjectionFailure.unsupportedVersion);
  }
  final aggregateSeq = BigInt.from(_integer(durable['seq']));

  final String? text;
  final NoticeKind kind;
  if (type == _instructions) {
    final delta = _object(data['delta']);
    if (delta.length > _listLimit) {
      _fail(OpenCodeNoticeProjectionFailure.limitExceeded);
    }
    for (final MapEntry(:key, :value) in delta.entries) {
      _text(key, cap: _idLimit, nonempty: true);
      _text(value, cap: _idLimit);
    }
    text = data.containsKey('text')
        ? _text(data['text'], cap: _textLimit)
        : null;
    kind = NoticeKind.system;
  } else {
    text = _text(data['text'], cap: _textLimit);
    if (data.containsKey('description')) {
      _text(data['description'], cap: _textLimit);
    }
    if (data.containsKey('metadata')) _object(data['metadata']);
    kind = NoticeKind.continuation;
  }
  if (text == null) return const [];

  final messageId = 'msg_${nativeId.substring(4)}';
  final id = ItemId(jsonEncode([ref.storageKey, messageId, 'notice', 0]));
  for (final item in current.timeline) {
    if (item.id == id && item is! Notice) {
      _fail(OpenCodeNoticeProjectionFailure.itemKindMismatch);
    }
  }
  final source = SourceProvenance(
    harness: ref.harnessRef,
    version: sourceVersion,
    nativeType: type,
    nativeEventId: nativeId,
    aggregateId: sessionId,
    aggregateSeq: aggregateSeq,
    durability: const OpenValue.known(Durability.durable),
    extra: CanonicalValue({
      'nativeCreated': created,
      'nativeDurableVersion': durableVersion,
      'nativeMessageId': messageId,
    }),
  );
  return List.unmodifiable([
    ItemUpserted(
      meta: EventMeta(
        owner: SessionOwner(ref),
        position: position,
        receivedAt: receivedAt,
        source: source,
      ),
      item: Notice(
        meta: ItemMeta(
          id: id,
          anchor: openCodeMessageAnchor(messageId),
          generation: jsonEncode([
            'live',
            ref.storageKey,
            messageId,
            position.id,
            position.epoch,
          ]),
          status: const OpenValue.known(ItemStatus.completed),
          source: source,
        ),
        kind: OpenValue.known(kind),
        text: text,
      ),
    ),
  ]);
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeNoticeProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeNoticeProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeNoticeProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeNoticeProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeNoticeProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeNoticeProjectionFailure.limitExceeded);
  }
}

Never _fail(OpenCodeNoticeProjectionFailure failure) =>
    throw OpenCodeNoticeProjectionException(failure);
