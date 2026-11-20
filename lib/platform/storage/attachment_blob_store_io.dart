// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../shared/sessions/session_attachments.dart';
import 'attachment_blob_store.dart';
import 'storage_support.dart';

AttachmentBlobRepository createAttachmentBlobStore() =>
    FileAttachmentBlobStore();

/// Content-addressed local disk cache under `<appSupportDir>/cw2_blobs/` with
/// atomic writes, `pins.json` protection for active drafts & unsettled outbox
/// records, and bounded 256 MiB LRU eviction for unpinned cached media.
final class FileAttachmentBlobStore implements AttachmentBlobRepository {
  FileAttachmentBlobStore({
    Future<Directory> Function()? directory,
    this.maxBytes = 256 * 1024 * 1024,
  }) : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  final int maxBytes;
  final _queue = KeySerialExecutor();
  final _rng = Random.secure();
  Map<String, Set<String>>? _pinsCache;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}cw2_blobs');
  }

  Future<Directory> _ensureDir() async {
    final dir = await _directory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _blobPath(Directory dir, String digest) =>
      '${dir.path}${Platform.pathSeparator}${requireBlobDigest(digest)}.bin';

  String _pinsPath(Directory dir) =>
      '${dir.path}${Platform.pathSeparator}pins.json';

  String _tmpSuffix() => List.generate(
    10,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<Map<String, Set<String>>> _loadPins(Directory dir) async {
    if (_pinsCache case final cached?) return cached;
    final file = File(_pinsPath(dir));
    final map = <String, Set<String>>{};
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map<String, Object?>) {
          for (final entry in raw.entries) {
            if (entry.value is List<Object?>) {
              final digests = <String>{};
              for (final item in entry.value! as List<Object?>) {
                if (item is String &&
                    RegExp(r'^[0-9a-f]{64}$').hasMatch(item)) {
                  digests.add(item);
                }
              }
              if (digests.isNotEmpty) map[entry.key] = digests;
            }
          }
        }
      } on Object {
        // Corrupt pins file falls back to empty; active drafts re-pin on load.
      }
    }
    return _pinsCache = map;
  }

  Future<void> _savePins(Directory dir, Map<String, Set<String>> pins) async {
    final payload = jsonEncode({
      for (final entry in pins.entries) entry.key: entry.value.toList(),
    });
    final target = File(_pinsPath(dir));
    final tmp = File('${target.path}.tmp.${_tmpSuffix()}');
    try {
      await tmp.writeAsString(payload, flush: true);
      await tmp.rename(target.path);
    } finally {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<({String sha256, int byteSize, Uint8List head})> putStream(
    Stream<List<int>> stream, {
    required int maxBytes,
  }) async {
    final dir = await _ensureDir();
    final tmp = File('${dir.path}${Platform.pathSeparator}upload.tmp.${_tmpSuffix()}');
    final headBuilder = BytesBuilder(copy: false);
    final digestSink = _DigestAccumulator();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var total = 0;
    IOSink? sink;
    try {
      sink = tmp.openWrite();
      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        total += chunk.length;
        if (total > maxBytes) {
          throw const AttachmentStageException(AttachmentStageFailure.tooLarge);
        }
        sink.add(chunk);
        hashSink.add(chunk);
        if (headBuilder.length < 4096) {
          final take = 4096 - headBuilder.length;
          headBuilder.add(
            chunk.length <= take ? chunk : chunk.sublist(0, take),
          );
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      hashSink.close();
      if (total == 0) {
        throw const AttachmentStageException(AttachmentStageFailure.emptyFile);
      }
      final digest = digestSink.digest.toString();
      await _queue.run('blobs', () async {
        final target = File(_blobPath(dir, digest));
        if (await target.exists()) {
          try {
            await target.setLastModified(DateTime.now());
          } catch (_) {}
          if (await tmp.exists()) await tmp.delete();
        } else {
          await tmp.rename(target.path);
        }
        await _evictLocked(dir, keepDigest: digest);
      });
      return (
        sha256: digest,
        byteSize: total,
        head: headBuilder.takeBytes(),
      );
    } catch (error) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      if (error is AttachmentStageException) rethrow;
      throw const AttachmentStageException(AttachmentStageFailure.storageFailed);
    }
  }

  @override
  Future<({String sha256, int byteSize})> putBytes(Uint8List bytes) async {
    final digest = sha256.convert(bytes).toString();
    final dir = await _ensureDir();
    await _queue.run('blobs', () async {
      final target = File(_blobPath(dir, digest));
      if (await target.exists()) {
        try {
          await target.setLastModified(DateTime.now());
        } catch (_) {}
        return;
      }
      final tmp = File('${target.path}.tmp.${_tmpSuffix()}');
      try {
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(target.path);
      } finally {
        if (await tmp.exists()) {
          try {
            await tmp.delete();
          } catch (_) {}
        }
      }
      await _evictLocked(dir, keepDigest: digest);
    });
    return (sha256: digest, byteSize: bytes.length);
  }

  @override
  Future<Uint8List?> readBytes(String digest, {int? maxBytes}) async {
    requireBlobDigest(digest);
    final dir = await _ensureDir();
    final file = File(_blobPath(dir, digest));
    if (!await file.exists()) return null;
    final length = await file.length();
    if (maxBytes != null && length > maxBytes) {
      throw const AttachmentStageException(AttachmentStageFailure.tooLarge);
    }
    final builder = BytesBuilder(copy: false);
    final cap = maxBytes ?? length;
    await for (final chunk in file.openRead(0, cap + 1)) {
      if (builder.length + chunk.length > cap) {
        throw const AttachmentStageException(AttachmentStageFailure.tooLarge);
      }
      builder.add(chunk);
    }
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {}
    return builder.takeBytes();
  }

  @override
  Stream<List<int>>? openRead(String digest) {
    requireBlobDigest(digest);
    return Stream.fromFuture(_resolveExistingFile(digest)).asyncExpand((file) {
      if (file == null) return const Stream.empty();
      return file.openRead();
    });
  }

  Future<File?> _resolveExistingFile(String digest) async {
    final dir = await _ensureDir();
    final file = File(_blobPath(dir, digest));
    return await file.exists() ? file : null;
  }

  @override
  Future<int?> byteSizeOf(String digest) async {
    requireBlobDigest(digest);
    final dir = await _ensureDir();
    final file = File(_blobPath(dir, digest));
    if (!await file.exists()) return null;
    return file.length();
  }

  @override
  Future<void> pin(String ownerId, Iterable<String> digests) async {
    final valid = {for (final d in digests) requireBlobDigest(d)};
    final dir = await _ensureDir();
    await _queue.run('blobs', () async {
      final pins = await _loadPins(dir);
      final existing = pins[ownerId];
      if (valid.isEmpty) {
        if (existing == null) return;
        pins.remove(ownerId);
      } else {
        if (existing != null &&
            existing.length == valid.length &&
            existing.containsAll(valid)) {
          return;
        }
        pins[ownerId] = valid;
      }
      await _savePins(dir, pins);
      await _evictLocked(dir);
    });
  }

  @override
  Future<void> unpin(String ownerId) async {
    final dir = await _ensureDir();
    await _queue.run('blobs', () async {
      final pins = await _loadPins(dir);
      if (pins.remove(ownerId) != null) {
        await _savePins(dir, pins);
        await _evictLocked(dir);
      }
    });
  }

  Future<void> _evictLocked(Directory dir, {String? keepDigest}) async {
    final pins = await _loadPins(dir);
    final pinned = {for (final set in pins.values) ...set};
    final entries = <({File file, String digest, int size, DateTime mtime})>[];
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.endsWith('.bin')) continue;
      final digest = name.substring(0, name.length - 4);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) continue;
      try {
        final stat = await entity.stat();
        total += stat.size;
        entries.add((
          file: entity,
          digest: digest,
          size: stat.size,
          mtime: stat.modified,
        ));
      } catch (_) {}
    }
    if (total <= maxBytes) return;
    entries.sort((a, b) => a.mtime.compareTo(b.mtime));
    for (final entry in entries) {
      if (total <= maxBytes) break;
      if (entry.digest == keepDigest || pinned.contains(entry.digest)) continue;
      try {
        await entry.file.delete();
        total -= entry.size;
      } catch (_) {}
    }
  }
}

final class _DigestAccumulator implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
