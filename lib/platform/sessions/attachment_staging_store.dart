import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../shared/media/attachment_sniff.dart';
import '../../shared/sessions/session_attachments.dart';
import '../storage/payload_store.dart';

/// Persists per-draft staged attachments (<=8 items, <=32 KiB JSON) in
/// [PayloadStore] and synchronizes blob pins with [AttachmentBlobRepository].
/// Draft JSON stores only metadata + SHA-256 digests, never raw base64.
final class AttachmentStagingStore {
  AttachmentStagingStore({required this.payloads, required this.blobs});

  static const maxManifestChars = 32 * 1024;

  final PayloadStore payloads;
  final AttachmentBlobRepository blobs;

  static String keyFor(String scopeKey) =>
      'cw2.attachments.v1.${sha256.convert(utf8.encode(scopeKey))}';

  static String _pinOwner(String scopeKey) => 'draft-attach:$scopeKey';

  Future<List<StagedAttachment>> load(String scopeKey) async {
    try {
      final raw = await payloads.readJson(keyFor(scopeKey));
      if (raw is! Map<String, Object?> || raw['schema'] != 1) {
        return const [];
      }
      final items = raw['items'];
      if (items is! List<Object?>) return const [];
      final loaded = <StagedAttachment>[];
      for (final entry in items) {
        if (loaded.length >= maxComposerAttachments) break;
        final staged = StagedAttachment.fromJson(entry);
        if (staged == null) continue;
        // Drop orphaned binary items whose local blob no longer exists.
        if (staged.sha256 case final digest?) {
          if (await blobs.byteSizeOf(digest) == null) continue;
        }
        loaded.add(staged);
      }
      await _syncPins(scopeKey, loaded);
      return List<StagedAttachment>.unmodifiable(loaded);
    } on Object {
      return const [];
    }
  }

  Future<bool> save(String scopeKey, List<StagedAttachment> items) async {
    final bounded = items.take(maxComposerAttachments).toList(growable: false);
    if (bounded.isEmpty) {
      await clear(scopeKey);
      return true;
    }
    final encoded = jsonEncode({
      'schema': 1,
      'items': [for (final item in bounded) item.toJson()],
    });
    if (encoded.length > maxManifestChars) return false;
    try {
      await _syncPins(scopeKey, bounded);
      final result = await payloads.write(keyFor(scopeKey), encoded);
      return result != PayloadWriteResult.refusedOversized;
    } on Object {
      return false;
    }
  }

  Future<void> clear(String scopeKey) async {
    try {
      await payloads.remove(keyFor(scopeKey));
    } on Object {
      // Best-effort clear.
    }
    try {
      await blobs.unpin(_pinOwner(scopeKey));
    } on Object {
      // Best-effort unpin.
    }
  }

  Future<void> _syncPins(String scopeKey, List<StagedAttachment> items) async {
    final digests = [for (final item in items) ?item.sha256];
    if (digests.isEmpty) {
      await blobs.unpin(_pinOwner(scopeKey));
    } else {
      await blobs.pin(_pinOwner(scopeKey), digests);
    }
  }
}
