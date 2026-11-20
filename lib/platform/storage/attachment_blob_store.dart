import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../shared/sessions/session_attachments.dart';

final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// Validates a 64-character lowercase hexadecimal SHA-256 digest before it can
/// be used as a content-addressed key or filename.
String requireBlobDigest(String sha256Hex) {
  if (!_sha256Pattern.hasMatch(sha256Hex)) {
    throw ArgumentError.value(sha256Hex, 'sha256', 'Invalid SHA-256 digest.');
  }
  return sha256Hex;
}

/// Pure in-memory content-addressed blob repository with LRU eviction and pin
/// protection. Used on Web and in unit/widget tests.
final class MemoryAttachmentBlobStore implements AttachmentBlobRepository {
  MemoryAttachmentBlobStore({this.maxBytes = 256 * 1024 * 1024});

  final int maxBytes;
  final _entries = <String, Uint8List>{};
  final _pins = <String, Set<String>>{};
  int _totalBytes = 0;

  Set<String> get _allPinned => {
    for (final set in _pins.values) ...set,
  };

  @override
  Future<({String sha256, int byteSize, Uint8List head})> putStream(
    Stream<List<int>> stream, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    final headBuilder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in stream) {
      if (chunk.isEmpty) continue;
      total += chunk.length;
      if (total > maxBytes) {
        throw const AttachmentStageException(AttachmentStageFailure.tooLarge);
      }
      builder.add(chunk);
      if (headBuilder.length < 4096) {
        final take = 4096 - headBuilder.length;
        headBuilder.add(chunk.length <= take ? chunk : chunk.sublist(0, take));
      }
    }
    if (total == 0) {
      throw const AttachmentStageException(AttachmentStageFailure.emptyFile);
    }
    final bytes = builder.takeBytes();
    final stored = await putBytes(bytes);
    return (
      sha256: stored.sha256,
      byteSize: stored.byteSize,
      head: headBuilder.takeBytes(),
    );
  }

  @override
  Future<({String sha256, int byteSize})> putBytes(Uint8List bytes) async {
    final digest = sha256.convert(bytes).toString();
    final existing = _entries.remove(digest);
    if (existing != null) {
      _entries[digest] = existing;
      return (sha256: digest, byteSize: existing.length);
    }
    final copy = Uint8List.fromList(bytes);
    _entries[digest] = copy;
    _totalBytes += copy.length;
    _evictIfNeeded(keepDigest: digest);
    return (sha256: digest, byteSize: copy.length);
  }

  @override
  Future<Uint8List?> readBytes(String digest, {int? maxBytes}) async {
    requireBlobDigest(digest);
    final existing = _entries.remove(digest);
    if (existing == null) return null;
    _entries[digest] = existing;
    if (maxBytes != null && existing.length > maxBytes) {
      throw const AttachmentStageException(AttachmentStageFailure.tooLarge);
    }
    return Uint8List.fromList(existing);
  }

  @override
  Stream<List<int>>? openRead(String digest) {
    requireBlobDigest(digest);
    final existing = _entries[digest];
    if (existing == null) return null;
    return Stream.value(Uint8List.fromList(existing));
  }

  @override
  Future<int?> byteSizeOf(String digest) async {
    requireBlobDigest(digest);
    return _entries[digest]?.length;
  }

  @override
  Future<void> pin(String ownerId, Iterable<String> digests) async {
    final valid = {for (final d in digests) requireBlobDigest(d)};
    final existing = _pins[ownerId];
    if (valid.isEmpty) {
      if (existing == null) return;
      _pins.remove(ownerId);
    } else {
      if (existing != null &&
          existing.length == valid.length &&
          existing.containsAll(valid)) {
        return;
      }
      _pins[ownerId] = valid;
    }
    _evictIfNeeded();
  }

  @override
  Future<void> unpin(String ownerId) async {
    _pins.remove(ownerId);
    _evictIfNeeded();
  }

  void _evictIfNeeded({String? keepDigest}) {
    if (_totalBytes <= maxBytes) return;
    final pinned = _allPinned;
    for (final key in _entries.keys.toList()) {
      if (_totalBytes <= maxBytes) break;
      if (key == keepDigest || pinned.contains(key)) continue;
      final removed = _entries.remove(key);
      if (removed != null) _totalBytes -= removed.length;
    }
  }
}
