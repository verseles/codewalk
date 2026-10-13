import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'version_policy.dart';

enum OpenCodeInboxProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeInboxProjectionException implements Exception {
  const OpenCodeInboxProjectionException(this.failure);

  final OpenCodeInboxProjectionFailure failure;

  @override
  String toString() => 'OpenCodeInboxProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _textLimit = 256 * 1024;
const _contextLimit = 1024;
// Matches the history producer's per-field selected-content budget.
const _manifestLimit = 64 * 1024;
const _safeInteger = 9007199254740991;
const _enqueued = 'session.inbox.enqueued';
const _delivered = 'session.inbox.delivered';
const _cancelled = 'session.inbox.cancelled';
const _deliveryChanged = 'session.inbox.delivery.changed';
const _types = {_enqueued, _delivered, _cancelled, _deliveryChanged};
const _itemTypes = {'user', 'synthetic', 'compaction', 'move'};

/// Projects the four 2.0.22 inbox events without owning a stream or clock.
///
/// Returns an unmodifiable list to reduce in order against the latest
/// [current] state: item upserts first, then a level-set
/// [PendingInputChanged] only when the pending collection changes. Unrelated
/// types, foreign sessions and inbox IDs unknown to [current] return an empty
/// list; nothing is invented from an ID-only frame.
///
/// Following the composer model, a `steer` user prompt becomes a timeline
/// [UserInput] at admission, while queued prompts and synthetic continuations
/// stay pending until delivered (or switched to steer). Native history orders
/// user rows by delivery and never contains cancelled input, so this keeps the
/// live order and contents equal to history without moving or deleting rows.
/// Item IDs equal the history projection's IDs. Compaction and move control
/// items are validated and not projected.
///
/// Attachment data, names, URIs, mention text, metadata, synthetic
/// descriptions, move targets and the frame location are never read or copied.
List<SessionEvent> projectOpenCodeInboxEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeInboxProjectionFailure.malformed);
  if (!_types.contains(type)) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeInboxProjectionFailure.unsupportedVersion);
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
  if (created is! num || !created.isFinite) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != 1) {
    _fail(OpenCodeInboxProjectionFailure.unsupportedVersion);
  }
  final aggregateSeq = BigInt.from(_integer(durable['seq']));
  final inboxId = _id(data['inboxID'], 'msg_');

  String? itemType;
  String? delivery;
  var text = '';
  Map<String, Object?>? context;
  if (type == _enqueued) {
    final item = _object(data['item']);
    itemType = _text(item['type'], cap: _idLimit);
    if (!_itemTypes.contains(itemType)) {
      _fail(OpenCodeInboxProjectionFailure.unsupportedValue);
    }
    delivery = _delivery(item['delivery']);
    final payload = _object(item['payload']);
    switch (itemType) {
      case 'user':
        text = _text(payload['text'], cap: _textLimit);
        context = _contextManifest(payload);
      case 'synthetic':
        text = _text(payload['text'], cap: _textLimit);
      case 'move':
        // Validated as declared, then discarded: the target is not projected.
        _object(payload['location']);
        _text(payload['projectID'], cap: _idLimit);
        if (payload.containsKey('subpath')) {
          _text(payload['subpath'], cap: _idLimit);
        }
    }
  } else if (type == _deliveryChanged) {
    delivery = _delivery(data['delivery']);
  }

  ItemId itemId(String kind, Object discriminator) =>
      ItemId(jsonEncode([ref.storageKey, inboxId, kind, discriminator]));
  final userId = itemId('user', 0);
  final noticeId = itemId('notice', 0);
  final contextId = itemId('unknown', ['context', 'user-context-manifest', 0]);
  TimelineItem? resident(ItemId id) {
    for (final item in current.timeline) {
      if (item.id == id) return item;
    }
    return null;
  }

  final user = resident(userId);
  final notice = resident(noticeId);
  final contextItem = resident(contextId);
  if ((user != null && user is! UserInput) ||
      (notice != null && notice is! Notice) ||
      (contextItem != null && contextItem is! UnknownItem)) {
    _fail(OpenCodeInboxProjectionFailure.itemKindMismatch);
  }
  final residentUser = user as UserInput?;
  PendingInput? pendingEntry;
  for (final entry in current.pending) {
    if (entry.id == userId || entry.id == noticeId) pendingEntry = entry;
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
      'nativeDurableVersion': 1,
      'nativeInboxId': inboxId,
      'inboxItemType': ?itemType,
      'nativeDelivery': ?delivery,
      if (context != null) 'contextNotProjected': true,
    }),
  );
  final eventMeta = EventMeta(
    owner: SessionOwner(ref),
    position: position,
    receivedAt: receivedAt,
    source: source,
  );
  String liveGeneration() => jsonEncode([
    'live',
    ref.storageKey,
    inboxId,
    nativeId,
    position.id,
    position.epoch,
  ]);
  ItemMeta meta(ItemId id, String generation, ItemStatus status) => ItemMeta(
    id: id,
    generation: generation,
    status: OpenValue.known(status),
    source: source,
  );
  UserInput userInput(String text, DeliveryState state, {String? generation}) =>
      UserInput(
        meta: meta(
          userId,
          generation ?? liveGeneration(),
          state == DeliveryState.accepted || state == DeliveryState.queued
              ? ItemStatus.pending
              : ItemStatus.completed,
        ),
        text: text,
        delivery: OpenValue.known(state),
      );
  // Only live admissions are open. History rows (delivery unknown) and
  // delivered input are settled and never regress; a cancelled row is
  // replaced by a same-ID re-admission.
  final open = {DeliveryState.accepted, DeliveryState.queued};
  final residentOpen =
      residentUser != null && open.contains(residentUser.delivery.known);
  final residentCancelled =
      residentUser?.delivery.known == DeliveryState.cancelled;

  final items = <TimelineItem>[];
  var pending = List<PendingInput>.of(current.pending);
  void removePending() =>
      pending.removeWhere((e) => e.id == userId || e.id == noticeId);
  void putPending(ItemId id, String text, String mode) {
    final entry = PendingInput(
      id: id,
      text: text,
      delivery: OpenValue.known(
        mode == 'steer' ? Delivery.steer : Delivery.queue,
      ),
    );
    final at = pending.indexWhere((e) => e.id == id);
    if (at < 0) {
      pending.add(entry);
    } else {
      pending[at] = entry;
    }
  }

  DeliveryState admitted(String mode) =>
      mode == 'steer' ? DeliveryState.accepted : DeliveryState.queued;

  switch (type) {
    case _enqueued:
      if (itemType == 'compaction' || itemType == 'move') return const [];
      if (itemType == 'synthetic') {
        if (notice != null) {
          removePending();
        } else {
          putPending(noticeId, text, delivery!);
        }
      } else if (residentUser != null && !residentOpen && !residentCancelled) {
        // A replayed admission never regresses settled input.
        removePending();
      } else {
        if (delivery == 'steer' || residentOpen || residentCancelled) {
          items.add(userInput(text, admitted(delivery!)));
          if (context != null) {
            items.add(
              UnknownItem(
                meta: ItemMeta(
                  id: contextId,
                  generation: liveGeneration(),
                  status: OpenValue<ItemStatus>.unknown('completionUnverified'),
                  source: source,
                ),
                rawType: 'user-context-manifest',
                raw: CanonicalValue(context),
              ),
            );
          }
        }
        putPending(userId, text, delivery!);
      }
    case _deliveryChanged:
      if (pendingEntry == null) return const [];
      putPending(pendingEntry.id, pendingEntry.text, delivery!);
      if (pendingEntry.id == userId) {
        if (residentOpen) {
          if (residentUser.delivery.known != admitted(delivery)) {
            items.add(
              userInput(
                residentUser.text,
                admitted(delivery),
                generation: residentUser.generation,
              ),
            );
          }
        } else if (residentUser == null && delivery == 'steer') {
          items.add(userInput(pendingEntry.text, DeliveryState.accepted));
        }
      }
    case _delivered:
      if (residentOpen) {
        items.add(
          userInput(
            residentUser.text,
            DeliveryState.delivered,
            generation: residentUser.generation,
          ),
        );
      } else if (residentUser == null && notice == null) {
        if (pendingEntry == null) return const [];
        items.add(
          pendingEntry.id == userId
              ? userInput(pendingEntry.text, DeliveryState.delivered)
              : Notice(
                  meta: meta(noticeId, liveGeneration(), ItemStatus.completed),
                  kind: const OpenValue.known(NoticeKind.continuation),
                  text: pendingEntry.text,
                ),
        );
      }
      removePending();
    case _cancelled:
      if (residentOpen) {
        items.add(
          userInput(
            residentUser.text,
            DeliveryState.cancelled,
            generation: residentUser.generation,
          ),
        );
      }
      removePending();
  }

  final events = <SessionEvent>[
    for (final item in items) ItemUpserted(meta: eventMeta, item: item),
    if (!_samePending(pending, current.pending))
      PendingInputChanged(meta: eventMeta, items: pending),
  ];
  return List.unmodifiable(events);
}

bool _samePending(List<PendingInput> a, List<PendingInput> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i]) &&
        (a[i].id != b[i].id ||
            a[i].text != b[i].text ||
            a[i].delivery.value != b[i].delivery.value ||
            a[i].commandId != b[i].commandId)) {
      return false;
    }
  }
  return true;
}

String _delivery(Object? value) {
  final result = _text(value, cap: _idLimit);
  if (result != 'steer' && result != 'queue') {
    _fail(OpenCodeInboxProjectionFailure.unsupportedValue);
  }
  return result;
}

/// Mirrors the history `user-context-manifest`: counts and file MIME/source
/// kinds only; content stays unresolved. Null when no context is attached.
Map<String, Object?>? _contextManifest(Map<String, Object?> payload) {
  final counts = <String, Object?>{};
  final files = <Object?>[];
  var bytes = 0;
  for (final key in ['files', 'agents', 'skills']) {
    if (!payload.containsKey(key)) continue;
    final entries = payload[key];
    if (entries is! List<Object?>) {
      _fail(OpenCodeInboxProjectionFailure.malformed);
    }
    if (entries.length > _contextLimit) {
      _fail(OpenCodeInboxProjectionFailure.limitExceeded);
    }
    counts[key] = entries.length;
    for (final entry in entries) {
      final attachment = _object(entry);
      if (key == 'files') {
        final source = _object(attachment['source']);
        final mime = _text(attachment['mime'], cap: _idLimit);
        final kind = _text(source['type'], cap: _idLimit, nonempty: true);
        bytes += utf8.encode(mime).length + utf8.encode(kind).length;
        if (bytes > _manifestLimit) {
          _fail(OpenCodeInboxProjectionFailure.limitExceeded);
        }
        files.add({'mime': mime, 'sourceKind': kind});
      }
      if (attachment.containsKey('mention')) {
        final mention = _object(attachment['mention']);
        for (final bound in ['start', 'end']) {
          final v = mention[bound];
          if (v is! num || !v.isFinite) {
            _fail(OpenCodeInboxProjectionFailure.malformed);
          }
        }
      }
    }
  }
  if (!counts.values.any((v) => (v! as int) > 0)) return null;
  return {
    'type': 'user-context-manifest',
    'reason': 'contentResolutionUnavailable',
    'counts': counts,
    'files': files,
    'contextNotProjected': true,
  };
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeInboxProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

void _bytes(String value, int cap) {
  if (value.length > cap) {
    _fail(OpenCodeInboxProjectionFailure.limitExceeded);
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        _fail(OpenCodeInboxProjectionFailure.malformed);
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeInboxProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeInboxProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeInboxProjectionFailure.limitExceeded);
  }
}

Never _fail(OpenCodeInboxProjectionFailure failure) =>
    throw OpenCodeInboxProjectionException(failure);
