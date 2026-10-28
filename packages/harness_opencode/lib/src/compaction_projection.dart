import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'error_projection.dart';
import 'item_ids.dart';
import 'version_policy.dart';

enum OpenCodeCompactionProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  identityUnproven,
}

final class OpenCodeCompactionProjectionException implements Exception {
  const OpenCodeCompactionProjectionException(this.failure);
  final OpenCodeCompactionProjectionFailure failure;
  @override
  String toString() => 'OpenCodeCompactionProjectionException(${failure.name})';
}

const _started = 'session.compaction.started';
const _ended = 'session.compaction.ended';
const _failed = 'session.compaction.failed';
const _types = {_started, _ended, _failed};

/// The complete terminal summary replaces any partial text. Opaque provider
/// state/context and the recent-context copy are never retained in a notice.
List<SessionEvent> projectOpenCodeCompactionEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeCompactionProjectionFailure.malformed);
  if (!_types.contains(type)) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeCompactionProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    ref.host.value,
    ref.harness.value,
    ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    if (_text(part, cap: 4096).isEmpty) {
      _fail(OpenCodeCompactionProjectionFailure.malformed);
    }
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > 8640000000000000) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != 1) {
    _fail(OpenCodeCompactionProjectionFailure.unsupportedVersion);
  }
  final seq = BigInt.from(_integer(durable['seq']));
  final input = data.containsKey('inputID')
      ? _id(data['inputID'], 'msg_')
      : null;
  final reason = _text(data['reason'], cap: 32);
  if (reason != 'auto' && reason != 'manual') {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  if (type != _failed) _text(data['recent']);

  Notice? active;
  Notice? duplicate;
  var residentCompaction = false;
  for (final item in current.timeline) {
    if (item is! Notice || item.kind.known != NoticeKind.compaction) continue;
    residentCompaction = true;
    if (item.status.known == ItemStatus.streaming) active = item;
    if (item.meta.source.nativeEventId == nativeId) duplicate = item;
  }
  // The official reference reducer uses inputID on start, then the last
  // running compaction on terminal. Failed frames can retain inputID without
  // a start. A snapshot may already contain a completed notice without its
  // native event ID, or a newer running notice: only a live start proves which
  // running notice a terminal targets. Repair ambiguity instead of guessing.
  if (type != _started &&
      duplicate == null &&
      (active != null
          ? active.meta.source.nativeType != _started ||
                active.meta.source.nativeEventId == null
          : input == null && residentCompaction)) {
    _fail(OpenCodeCompactionProjectionFailure.identityUnproven);
  }
  String residentMessage(Notice item) {
    final message = openCodeMessageIdOf(item.id, ref);
    if (message == null) _fail(OpenCodeCompactionProjectionFailure.malformed);
    return message;
  }

  final messageId = type == _started
      ? input ?? 'msg_${nativeId.substring(4)}'
      : duplicate != null
      ? residentMessage(duplicate)
      : active != null
      ? residentMessage(active)
      : input ?? 'msg_${nativeId.substring(4)}';
  final id = ItemId(jsonEncode([ref.storageKey, messageId, 'notice', 0]));
  for (final item in current.timeline) {
    if (item.id != id) continue;
    if (item is! Notice || item.kind.known != NoticeKind.compaction) {
      _fail(OpenCodeCompactionProjectionFailure.itemKindMismatch);
    }
    if (type == _started && item.status.known != ItemStatus.streaming) {
      return const [];
    }
  }
  final presentation = openCodeCompactionNotice({
    'status': type == _started
        ? 'running'
        : type == _ended
        ? 'completed'
        : 'failed',
    'summary': type == _ended ? data['text'] : '',
    if (type == _failed) 'error': data['error'],
  })!;
  final source = SourceProvenance(
    harness: ref.harnessRef,
    version: sourceVersion,
    nativeType: type,
    nativeEventId: nativeId,
    aggregateId: sessionId,
    aggregateSeq: seq,
    durability: const OpenValue.known(Durability.durable),
    extra: CanonicalValue({
      'nativeCreated': created,
      'nativeDurableVersion': 1,
      'nativeMessageId': messageId,
    }),
  );
  final meta = EventMeta(
    owner: SessionOwner(ref),
    position: position,
    receivedAt: receivedAt,
    source: source,
  );
  return List.unmodifiable([
    ItemUpserted(
      meta: meta,
      item: Notice(
        meta: ItemMeta(
          id: id,
          generation: jsonEncode([
            'live',
            ref.storageKey,
            messageId,
            position.id,
            position.epoch,
          ]),
          status: OpenValue.known(presentation.status),
          source: source,
        ),
        kind: const OpenValue.known(NoticeKind.compaction),
        text: presentation.text,
      ),
    ),
    if (input != null &&
        current.pending.any((p) => openCodeMessageIdOf(p.id, ref) == input))
      PendingInputChanged(
        meta: meta,
        items: [
          for (final pending in current.pending)
            if (openCodeMessageIdOf(pending.id, ref) != input) pending,
        ],
      ),
  ]);
}

/// Shared by hydrated history and live durable frames; null is an unknown
/// status, not a completed compaction. Error text follows the existing bounded
/// credential-redaction policy. All provider fields are deliberately ignored.
({ItemStatus status, String text})? openCodeCompactionNotice(
  Map<String, Object?> data,
) {
  final status = _text(data['status'], cap: 32);
  return switch (status) {
    'running' => (status: ItemStatus.streaming, text: _text(data['summary'])),
    'completed' => (status: ItemStatus.completed, text: _text(data['summary'])),
    'failed' => () {
      final error = _object(data['error']);
      final type = _text(error['type'], cap: 4096);
      final message = error['message'] == null ? null : _text(error['message']);
      return (
        status: ItemStatus.failed,
        text: openCodeErrorInfo(type, message).rawMessage,
      );
    }(),
    _ => null,
  };
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  return value;
}

String _text(Object? value, {int cap = 256 * 1024}) {
  if (value is! String) _fail(OpenCodeCompactionProjectionFailure.malformed);
  if (value.length > cap || utf8.encode(value).length > cap) {
    _fail(OpenCodeCompactionProjectionFailure.limitExceeded);
  }
  if (utf8.decode(utf8.encode(value)) != value) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  return value;
}

String _id(Object? value, String prefix) {
  final id = _text(value, cap: 4096);
  if (!id.startsWith(prefix) || id.length <= prefix.length) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  return id;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > 9007199254740991 ||
      value != value.truncate()) {
    _fail(OpenCodeCompactionProjectionFailure.malformed);
  }
  return value.toInt();
}

Never _fail(OpenCodeCompactionProjectionFailure failure) =>
    throw OpenCodeCompactionProjectionException(failure);
