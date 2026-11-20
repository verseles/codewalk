import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';

import '../../shared/sessions/session_attachments.dart';

/// Descriptor stored in the prompt outbox ledger when a sealed prompt body
/// exceeds [PromptPayloadStore.inlineThresholdBytes] (32 KiB) so the JSON
/// outbox ledger stays well below its 1 MiB ceiling even with 20 MiB inline
/// image/PDF attachments.
final class PromptPayloadRef {
  const PromptPayloadRef({required this.sha256, required this.byteLength});

  final String sha256;
  final int byteLength;

  Map<String, Object?> toJson() => {
    'sha256': sha256,
    'byteLength': byteLength,
  };

  static PromptPayloadRef? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final sha = value['sha256'];
    final length = value['byteLength'];
    if (sha is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
        length is! int ||
        length <= 0 ||
        length > PromptPayloadStore.maxPayloadBytes) {
      return null;
    }
    return PromptPayloadRef(sha256: sha, byteLength: length);
  }
}

/// Atomic out-of-band storage for sealed prompt wire payloads, backed by
/// [AttachmentBlobRepository] with SHA-256 + exact byte-length verification
/// and per-command pin protection.
final class PromptPayloadStore {
  PromptPayloadStore(this.blobs);

  static const inlineThresholdBytes = 32 * 1024;
  static const maxPayloadBytes = 32 * 1024 * 1024;

  final AttachmentBlobRepository blobs;

  static String _pinOwner(CommandId commandId) =>
      'outbox-payload:${commandId.value}';

  /// Persists [payload] atomically and pins it under [commandId].
  Future<PromptPayloadRef?> write(CommandId commandId, String payload) async {
    final encoded = Uint8List.fromList(utf8.encode(payload));
    if (encoded.isEmpty || encoded.length > maxPayloadBytes) return null;
    try {
      final stored = await blobs.putBytes(encoded);
      await blobs.pin(_pinOwner(commandId), [stored.sha256]);
      return PromptPayloadRef(sha256: stored.sha256, byteLength: encoded.length);
    } on Object {
      return null;
    }
  }

  /// Reads and cryptographically verifies the sealed payload for [ref].
  Future<String?> read(PromptPayloadRef ref) async {
    try {
      final bytes = await blobs.readBytes(
        ref.sha256,
        maxBytes: maxPayloadBytes,
      );
      if (bytes == null || bytes.length != ref.byteLength) return null;
      if (sha256.convert(bytes).toString() != ref.sha256) return null;
      return utf8.decode(bytes);
    } on Object {
      return null;
    }
  }

  /// Releases the pin once an outbox record is dismissed or evicted.
  Future<void> release(CommandId commandId) async {
    try {
      await blobs.unpin(_pinOwner(commandId));
    } on Object {
      // Best-effort cleanup.
    }
  }
}
