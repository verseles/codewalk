// ignore_for_file: avoid_slow_async_io

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'chat_cache_payload_store_base.dart';

ChatCachePayloadStore? createChatCachePayloadStore() {
  return FileBackedChatCachePayloadStore();
}

class FileBackedChatCachePayloadStore implements ChatCachePayloadStore {
  FileBackedChatCachePayloadStore({
    this.maxReadableBytes = ChatCachePayloadLimits.maxPayloadChars,
    this.maxMemoryCharsTotal = ChatCachePayloadLimits.maxMemoryCharsTotal,
    this.maxMemoryEntryChars = ChatCachePayloadLimits.maxMemoryEntryChars,
    Directory? testDirectory,
  }) : _testDirectory = testDirectory;

  static const int _maxInMemoryEntries = 24;

  /// Absolute ceiling for a payload file read into memory. Files above it
  /// are deleted (regenerable via SWR) instead of being read.
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
      return null;
    }

    final value = await file.readAsString();
    _storeMemory(key, value);
    return value;
  }

  @override
  Future<bool> write(String key, String value) async {
    if (value.length > maxReadableBytes) {
      return false;
    }
    final inMemory = _touchMemory(key);
    if (inMemory == value) {
      // Payload already persisted with the exact same content; skip the disk
      // write entirely to avoid jank from redundant file I/O (issue #152).
      return false;
    }
    _storeMemory(key, value);
    final file = await _fileForKey(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
    return true;
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
    if (value.length > maxMemoryEntryChars) {
      return;
    }
    _evictMemory(key);
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
