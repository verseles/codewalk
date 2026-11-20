import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../platform/sessions/attachment_staging_store.dart';
import '../../shared/media/attachment_picker.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/sessions/session_attachments.dart';

/// Manages staged attachments for one composer (a live session or workspace
/// draft). Raw file bytes live in [AttachmentBlobRepository]; this controller
/// keeps only lightweight metadata + SHA-256 digests and persists manifests
/// through [AttachmentStagingStore].
class ComposerAttachmentsController extends ChangeNotifier {
  ComposerAttachmentsController({AttachmentStagingStore? store})
    : _store = store;

  final AttachmentStagingStore? _store;
  final _rng = Random.secure();
  List<StagedAttachment> _items = const [];
  String? _scopeKey;
  bool _picking = false;
  bool _edited = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  List<StagedAttachment> get items => _items;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get picking => _picking;

  String _mintId() =>
      'att_${List.generate(8, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Loads persisted staged attachments for [scopeKey], replacing the current
  /// list only when switching scopes or if the user has not edited yet.
  Future<void> bindScope(
    String? scopeKey, {
    AttachmentStagingStore? storeOverride,
  }) async {
    final effectiveStore = storeOverride ?? _store;
    if (_scopeKey == scopeKey && _edited) return;
    _scopeKey = scopeKey;
    final generation = ++_loadGeneration;
    _edited = false;
    _picking = false;
    if (scopeKey == null || effectiveStore == null) {
      if (_items.isNotEmpty) {
        _items = const [];
      }
      _notify();
      return;
    }
    // Clear previous scope's items immediately so they cannot flash or leak
    // while the new scope's persisted manifest loads.
    if (_items.isNotEmpty) {
      _items = const [];
      _notify();
    }
    final loaded = await effectiveStore.load(scopeKey);
    if (_disposed || generation != _loadGeneration || _edited) return;
    _items = loaded;
    _notify();
  }

  /// Stages one or more picked files into [blobs], sniffing magic bytes and
  /// image dimensions without buffering oversized payloads in RAM. Returns the
  /// first failure encountered (if any) so the caller can show localized copy.
  Future<AttachmentStageFailure?> stagePickedFiles(
    List<PickedAttachmentFile> files,
    AttachmentBlobRepository blobs, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_disposed || files.isEmpty) return null;
    final startGeneration = _loadGeneration;
    final startScope = _scopeKey;
    _picking = true;
    _notify();
    AttachmentStageFailure? failure;
    final added = <StagedAttachment>[];
    try {
      for (final file in files) {
        if (_disposed ||
            startGeneration != _loadGeneration ||
            startScope != _scopeKey) {
          break;
        }
        if (_items.length + added.length >= maxComposerAttachments) {
          failure ??= AttachmentStageFailure.tooMany;
          break;
        }
        final declared = file.byteSize;
        if (declared != null && declared > maxAttachmentFileBytes) {
          failure ??= AttachmentStageFailure.tooLarge;
          continue;
        }
        if (declared != null && declared == 0) {
          failure ??= AttachmentStageFailure.emptyFile;
          continue;
        }
        try {
          final stored = await blobs.putStream(
            file.openRead(),
            maxBytes: maxAttachmentFileBytes,
          );
          if (_disposed ||
              startGeneration != _loadGeneration ||
              startScope != _scopeKey) {
            break;
          }
          final safeName = sanitizeAttachmentFilename(file.name);
          final mime = sniffAttachmentMime(
            stored.head,
            byteSize: stored.byteSize,
            filename: safeName,
            hintMime: file.mimeHint,
          );
          final kind = attachmentKindForMime(mime);
          final dims = kind == AttachmentKind.image
              ? probeImageDimensions(stored.head, mime)
              : null;
          added.add(
            StagedAttachment(
              id: _mintId(),
              kind: kind,
              name: safeName,
              mimeType: mime,
              byteSize: stored.byteSize,
              sha256: stored.sha256,
              width: dims?.width,
              height: dims?.height,
            ),
          );
        } on AttachmentStageException catch (e) {
          failure ??= e.failure;
        } on Object {
          failure ??= AttachmentStageFailure.readFailed;
        }
      }
      if (!_disposed &&
          startGeneration == _loadGeneration &&
          startScope == _scopeKey &&
          added.isNotEmpty) {
        final room = maxComposerAttachments - _items.length;
        if (room <= 0) {
          failure ??= AttachmentStageFailure.tooMany;
        } else {
          final accepted = added.length > room
              ? added.sublist(0, room)
              : added;
          if (accepted.length < added.length) {
            failure ??= AttachmentStageFailure.tooMany;
          }
          _edited = true;
          _items = List<StagedAttachment>.unmodifiable([..._items, ...accepted]);
          await _persist(
            storeOverride: storeOverride,
            expectedGeneration: startGeneration,
          );
        }
      }
      return failure;
    } finally {
      if (startGeneration == _loadGeneration) {
        _picking = false;
        _notify();
      }
    }
  }

  /// Stages a validated geographic pin.
  Future<AttachmentStageFailure?> addLocation(
    GeoPoint point, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_disposed) return null;
    if (_items.length >= maxComposerAttachments) {
      return AttachmentStageFailure.tooMany;
    }
    _edited = true;
    _items = List<StagedAttachment>.unmodifiable([
      ..._items,
      StagedAttachment.location(id: _mintId(), location: point),
    ]);
    await _persist(storeOverride: storeOverride);
    _notify();
    return null;
  }

  /// Removes a single staged attachment by [id].
  Future<void> remove(
    String id, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_disposed) return;
    final next = _items.where((item) => item.id != id).toList(growable: false);
    if (next.length == _items.length) return;
    _edited = true;
    _items = List<StagedAttachment>.unmodifiable(next);
    await _persist(storeOverride: storeOverride);
    _notify();
  }

  /// Restores attachments taken back from a cancelled pending prompt (#486),
  /// merging them before any newer items without exceeding the cap. Returns
  /// `true` once the restored manifest (and its blob pins) are durably saved,
  /// or `false` if persistence failed so the outbox pin can be kept.
  Future<bool> restoreFromRefs(
    List<AttachmentRef> refs, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_disposed || refs.isEmpty) return true;
    final restored = <StagedAttachment>[];
    final existingIds = {for (final item in _items) item.id};
    for (final ref in refs) {
      final staged = StagedAttachment.fromAttachmentRef(ref);
      if (staged == null || existingIds.contains(staged.id)) continue;
      restored.add(staged);
      existingIds.add(staged.id);
    }
    if (restored.isEmpty) return true;
    _edited = true;
    _items = List<StagedAttachment>.unmodifiable(
      [...restored, ..._items].take(maxComposerAttachments),
    );
    _notify();
    try {
      await _persist(storeOverride: storeOverride);
      return true;
    } on Object {
      return false;
    }
  }

  /// Canonical [AttachmentRef] snapshot for [PromptDraft.attachments].
  List<AttachmentRef> toAttachmentRefs() => List<AttachmentRef>.unmodifiable([
    for (final item in _items) item.toAttachmentRef(),
  ]);

  /// Removes only the items included in [sent], keeping anything staged while
  /// the send was in flight.
  Future<void> clearSent(
    List<StagedAttachment> sent, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_disposed || sent.isEmpty) return;
    final sentIds = {for (final item in sent) item.id};
    final remaining = _items
        .where((item) => !sentIds.contains(item.id))
        .toList(growable: false);
    if (remaining.length == _items.length) return;
    _edited = true;
    _items = List<StagedAttachment>.unmodifiable(remaining);
    await _persist(storeOverride: storeOverride);
    _notify();
  }

  Future<void> clear({AttachmentStagingStore? storeOverride}) async {
    if (_disposed) return;
    if (_items.isEmpty && !_edited) return;
    _edited = true;
    _items = const [];
    await _persist(storeOverride: storeOverride);
    _notify();
  }

  /// Clears a specific [scopeKey] without mutating [_items] when the controller
  /// has already been rebound to another scope.
  Future<void> clearScope(
    String scopeKey, {
    AttachmentStagingStore? storeOverride,
  }) async {
    if (_scopeKey == scopeKey) {
      await clear(storeOverride: storeOverride);
      return;
    }
    await (storeOverride ?? _store)?.clear(scopeKey);
  }

  Future<void> _persist({
    AttachmentStagingStore? storeOverride,
    int? expectedGeneration,
  }) async {
    if (_disposed ||
        (expectedGeneration != null && expectedGeneration != _loadGeneration)) {
      return;
    }
    final key = _scopeKey;
    final store = storeOverride ?? _store;
    if (key == null || store == null) return;
    final snapshot = _items;
    if (snapshot.isEmpty) {
      await store.clear(key);
    } else {
      await store.save(key, snapshot);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
