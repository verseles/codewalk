import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeRevertProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeRevertProjectionException implements Exception {
  const OpenCodeRevertProjectionException(this.failure);

  final OpenCodeRevertProjectionFailure failure;

  @override
  String toString() => 'OpenCodeRevertProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _listLimit = 4096;
const _manifestLimit = 64 * 1024;
const _safeInteger = 9007199254740991;
const _maxEpochMillis = 8640000000000000;
const _staged = 'session.revert.staged';
const _cleared = 'session.revert.cleared';
const _committed = 'session.revert.committed';
const _types = {_staged, _cleared, _committed};
const _statuses = {'added', 'deleted', 'modified'};

/// Projects the three durable 2.0.22 revert events without owning a stream or
/// clock.
///
/// Returns an unmodifiable list to reduce in order against the latest
/// [current] state, empty for unrelated types and foreign sessions. Each
/// event yields a [RevertChanged] with its own transition kind: the server
/// nulls its revert on both `cleared` and `committed`, but the canonical
/// machine keeps the terminal kind, so only `staged` means a pending revert.
///
/// The boundary is the first resident timeline item of the native message,
/// recovered from the canonical item IDs every sibling producer shares; it is
/// null when that message is not resident. A commit deletes the boundary
/// message and everything after it, plus the inbox entries enqueued from it on.
/// It removes resident items from the boundary only when the whole resident
/// timeline proves that cut, and keeps pending entries whose IDs order before
/// the boundary like the reference client; otherwise one [ResyncRequired]
/// replaces the unproven mutation instead of a guessed removal.
///
/// File diffs keep only path, status and counts: patches carry workspace
/// contents and are never read. Snapshot and legacy part IDs are validated and
/// not copied, and the frame location is never read.
List<SessionEvent> projectOpenCodeRevertEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeRevertProjectionFailure.malformed);
  if (!_types.contains(type)) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeRevertProjectionFailure.unsupportedVersion);
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
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != 1) {
    _fail(OpenCodeRevertProjectionFailure.unsupportedVersion);
  }
  final aggregateSeq = BigInt.from(_integer(durable['seq']));

  String? messageId;
  Map<String, Object?>? details;
  var patchOmitted = false;
  switch (type) {
    case _staged:
      final revert = _object(data['revert']);
      messageId = _id(revert['messageID'], 'msg_');
      if (revert.containsKey('partID')) _text(revert['partID']);
      final hasSnapshot = revert.containsKey('snapshot');
      if (hasSnapshot) _text(revert['snapshot'], nonempty: true);
      List<Map<String, Object?>>? files;
      if (revert.containsKey('files')) {
        final raw = revert['files'];
        if (raw is! List<Object?>) {
          _fail(OpenCodeRevertProjectionFailure.malformed);
        }
        if (raw.length > _listLimit) {
          _fail(OpenCodeRevertProjectionFailure.limitExceeded);
        }
        files = [
          for (final entry in raw)
            () {
              final file = _object(entry);
              final path = _text(file['file'], nonempty: true);
              final status = _text(file['status']);
              if (!_statuses.contains(status)) {
                _fail(OpenCodeRevertProjectionFailure.unsupportedValue);
              }
              // Required by FileDiff.Info; carries file contents, so it is
              // type-checked and never measured or copied.
              if (file['patch'] is! String) {
                _fail(OpenCodeRevertProjectionFailure.malformed);
              }
              return {
                'file': path,
                'status': status,
                'additions': _integer(file['additions']),
                'deletions': _integer(file['deletions']),
              };
            }(),
        ];
        patchOmitted = files.isNotEmpty;
      }
      details = {
        'messageId': messageId,
        'hasSnapshot': hasSnapshot,
        'files': ?files,
        if (patchOmitted) 'patchNotProjected': true,
      };
      if (utf8.encode(jsonEncode(details)).length > _manifestLimit) {
        _fail(OpenCodeRevertProjectionFailure.limitExceeded);
      }
    case _cleared:
      break;
    case _committed:
      messageId = _id(data['to'], 'msg_');
      details = {'messageId': messageId};
  }

  final eventMeta = EventMeta(
    owner: SessionOwner(ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      aggregateId: sessionId,
      aggregateSeq: aggregateSeq,
      durability: const OpenValue.known(Durability.durable),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeDurableVersion': 1,
        'nativeMessageId': ?messageId,
        if (patchOmitted) 'patchNotProjected': true,
      }),
    ),
  );

  final kind = switch (type) {
    _staged => RevertKind.staged,
    _cleared => RevertKind.cleared,
    _ => RevertKind.committed,
  };
  ItemId? boundary;
  if (type == _staged) {
    for (final item in current.timeline) {
      if (_messageOf(item.id, ref) == messageId) {
        boundary = item.id;
        break;
      }
    }
  }
  final events = <SessionEvent>[
    RevertChanged(
      meta: eventMeta,
      state: RevertState(
        kind: OpenValue.known(kind),
        boundary: boundary,
        details: details == null ? null : CanonicalValue(details),
      ),
    ),
  ];
  if (type != _committed) return List.unmodifiable(events);

  final to = messageId!;
  String? resync;
  final ids = [for (final item in current.timeline) _messageOf(item.id, ref)];
  if (ids.contains(null)) {
    resync = 'revertMembershipUnproven';
  } else {
    final cut = ids.indexWhere((id) => id!.compareTo(to) >= 0);
    if (cut < 0 || ids[cut] != to) {
      resync = 'revertBoundaryMissing';
    } else if (ids.skip(cut).any((id) => id!.compareTo(to) < 0)) {
      resync = 'revertOrderMismatch';
    } else {
      events.add(
        ItemsRemoved(meta: eventMeta, fromItemId: current.timeline[cut].id),
      );
    }
  }

  final pendingIds = [
    for (final entry in current.pending) _messageOf(entry.id, ref),
  ];
  if (pendingIds.contains(null)) {
    resync ??= 'revertPendingUnproven';
  } else {
    final kept = [
      for (var i = 0; i < current.pending.length; i++)
        if (pendingIds[i]!.compareTo(to) < 0) current.pending[i],
    ];
    if (kept.length != current.pending.length) {
      events.add(PendingInputChanged(meta: eventMeta, items: kept));
    }
  }
  if (resync != null) {
    events.add(ResyncRequired(meta: eventMeta, reason: resync));
  }
  return List.unmodifiable(events);
}

/// The native message of a canonical `[storageKey, messageId, kind, …]` ID, or
/// null when the ID has another shape or belongs to another session.
String? _messageOf(ItemId id, SessionRef ref) {
  if (id.value.length > _manifestLimit) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(id.value);
  } on FormatException {
    return null;
  }
  if (decoded is! List<Object?> ||
      decoded.length != 4 ||
      decoded[0] != ref.storageKey ||
      decoded[2] is! String) {
    return null;
  }
  final message = decoded[1];
  return message is String && message.startsWith('msg_') ? message : null;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeRevertProjectionFailure.malformed);
  }
  _bytes(value, _idLimit);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeRevertProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeRevertProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeRevertProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeRevertProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeRevertProjectionFailure.limitExceeded);
  }
}

Never _fail(OpenCodeRevertProjectionFailure failure) =>
    throw OpenCodeRevertProjectionException(failure);
