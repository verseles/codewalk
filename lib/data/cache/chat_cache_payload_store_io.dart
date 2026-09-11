// ignore_for_file: avoid_slow_async_io

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'chat_cache_payload_store_base.dart';

ChatCachePayloadStore? createChatCachePayloadStore() {
  return FileBackedChatCachePayloadStore();
}

class FileBackedChatCachePayloadStore implements ChatCachePayloadStore {
  FileBackedChatCachePayloadStore({
    this.maxWritableChars = ChatCachePayloadLimits.maxPayloadChars,
    this.maxReadableBytes = ChatCachePayloadLimits.maxPayloadChars * 4,
    this.maxMemoryCharsTotal = ChatCachePayloadLimits.maxMemoryCharsTotal,
    this.maxMemoryEntryChars = ChatCachePayloadLimits.maxMemoryEntryChars,
    Directory? testDirectory,
  }) : _testDirectory = testDirectory;

  static const int _maxInMemoryEntries = 24;

  /// Absolute ceiling, in characters, for an accepted payload write.
  final int maxWritableChars;

  /// Absolute ceiling, in on-disk bytes, for a payload file read into
  /// memory. Carries headroom over [maxWritableChars] because UTF-8
  /// expansion (up to 3x per BMP char) means a legitimately written payload
  /// can exceed its character count on disk; without headroom, valid
  /// non-ASCII snapshots would be wrongfully deleted on read. Files above
  /// it are deleted (regenerable via SWR) instead of being read.
  final int maxReadableBytes;

  /// Aggregate budget for the in-memory LRU, in string characters.
  final int maxMemoryCharsTotal;

  /// Single entries above this size are served from disk, never cached.
  final int maxMemoryEntryChars;

  final Directory? _testDirectory;

  final LinkedHashMap<String, String> _memoryCache =
      LinkedHashMap<String, String>();
  int _currentMemoryChars = 0;
  Future<Directory>? _cacheDirectoryFuture;

  /// Current in-memory character count, for tests pinning the byte budget.
  @visibleForTesting
  int get debugMemoryChars => _currentMemoryChars;

  @override
  Future<String?> read(String key) async {
    final inMemory = _touchMemory(key);
    if (inMemory != null) {
      return inMemory;
    }

    final file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }

    try {
      if (await file.length() > maxReadableBytes) {
        await file.delete();
        return null;
      }
    } catch (_) {
      // Transient stat failure: report a miss without destroying the file.
      return null;
    }

    try {
      final bytes = await file.readAsBytes();
      final value = utf8.decode(bytes);
      _storeMemory(key, value);
      return value;
    } on FormatException {
      // Confirmed corruption (invalid encoding, e.g. a torn write): remove
      // it so every later read does not fail the same way. Regenerable
      // via SWR for cache families.
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      return null;
    } catch (_) {
      // Other I/O errors (sharing violations, transient failures) must not
      // destroy a possibly valid file: report a miss and retry later.
      return null;
    }
  }

  @override
  Future<bool> write(String key, String value) async {
    if (value.length > maxWritableChars) {
      return false;
    }
    final inMemory = _touchMemory(key);
    if (inMemory == value) {
      // Payload already persisted with the exact same content; skip the disk
      // write entirely to avoid jank from redundant file I/O (issue #152).
      return false;
    }
    // Resolve the destination before touching memory: a directory-resolution
    // failure must not leave an unpersisted value served from the LRU.
    final file = await _fileForKey(key);
    _storeMemory(key, value);
    // Atomic replace (same pattern as the other file stores): write a unique
    // sibling temp, then rename over the target. rename replaces the
    // destination, so the previous payload stays intact until the new one is
    // fully on disk.
    final suffix = List<int>.generate(
      12,
      (_) => Random.secure().nextInt(256),
      growable: false,
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final temp = File('${file.path}.tmp.$suffix');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsString(value, flush: true);
      await temp.rename(file.path);
      return true;
    } catch (_) {
      // A failed disk write must not leave the value readable from the
      // in-memory LRU: a later migration/read would mistake it for a
      // persisted payload. Roll back memory, then surface the failure.
      _evictMemory(key);
      rethrow;
    } finally {
      try {
        if (await temp.exists()) {
          await temp.delete();
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> remove(String key) async {
    _evictMemory(key);
    final file = await _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> clear() async {
    _memoryCache.clear();
    _currentMemoryChars = 0;
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _cacheDirectoryFuture = null;
  }

  String? _touchMemory(String key) {
    final cached = _memoryCache.remove(key);
    if (cached == null) {
      return null;
    }
    _memoryCache[key] = cached;
    return cached;
  }

  void _evictMemory(String key) {
    final removed = _memoryCache.remove(key);
    if (removed != null) {
      _currentMemoryChars -= removed.length;
      if (_currentMemoryChars < 0) {
        _currentMemoryChars = 0;
      }
    }
  }

  void _storeMemory(String key, String value) {
    // Evict first: replacing an entry with one above the per-entry cap must
    // drop the stale smaller value instead of serving it forever.
    _evictMemory(key);
    if (value.length > maxMemoryEntryChars) {
      return;
    }
    _memoryCache[key] = value;
    _currentMemoryChars += value.length;
    while (_memoryCache.length > _maxInMemoryEntries ||
        _currentMemoryChars > maxMemoryCharsTotal) {
      final oldest = _memoryCache.keys.first;
      _evictMemory(oldest);
    }
  }

  Future<File> _fileForKey(String key) async {
    final directory = await _cacheDirectory();
    final digest = sha1.convert(utf8.encode(key)).toString();
    return File('${directory.path}${Platform.pathSeparator}$digest.json');
  }

  Future<Directory> _cacheDirectory() {
    _cacheDirectoryFuture ??= _resolveCacheDirectory();
    return _cacheDirectoryFuture!;
  }

  Future<Directory> _resolveCacheDirectory() async {
    final testDirectory = _testDirectory;
    if (testDirectory != null) {
      return testDirectory;
    }
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      '${supportDirectory.path}${Platform.pathSeparator}chat_cache_v1',
    );
  }
}
