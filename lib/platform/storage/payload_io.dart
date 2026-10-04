// ignore_for_file: avoid_slow_async_io

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'payload_store.dart';
import 'storage_support.dart';

final class OversizedPayloadFile implements Exception {
  const OversizedPayloadFile();
}

/// The backend must bound bytes while reading, even if a file grows after stat.
/// Atomic replacement must retain the old value when it reports a failure.
abstract interface class PayloadFileBackend {
  Future<Uint8List?> read(String key, {required int maxBytes});
  Future<void> replace(String key, String value);
  Future<void> remove(String key);
}

final class NativePayloadFileBackend implements PayloadFileBackend {
  NativePayloadFileBackend({
    Future<Directory> Function()? directory,
    File Function(String path)? fileFactory,
  }) : _directory = directory ?? _defaultDirectory,
       _fileFactory = fileFactory ?? File.new;

  final Future<Directory> Function() _directory;
  final File Function(String path) _fileFactory;

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}cw2_payloads');
  }

  Future<File> _file(String key) async {
    requireV2Key(key);
    final directory = await _directory();
    final digest = sha256.convert(utf8.encode(key));
    return _fileFactory(
      '${directory.path}${Platform.pathSeparator}$digest.json',
    );
  }

  @override
  Future<Uint8List?> read(String key, {required int maxBytes}) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) throw const OversizedPayloadFile();
    final bytes = BytesBuilder(copy: false);
    // The stream itself has a byte bound, independent of the earlier stat.
    await for (final chunk in file.openRead(0, maxBytes + 1)) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const OversizedPayloadFile();
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  @override
  Future<void> replace(String key, String value) async {
    final target = await _file(key);
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final temporary = _fileFactory('${target.path}.tmp.$suffix');
    try {
      await target.parent.create(recursive: true);
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(target.path);
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } catch (_) {
        // Do not replace the original write/rename error with cleanup failure.
      }
    }
  }

  @override
  Future<void> remove(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }
}

final class FilePayloadStore implements PayloadStore {
  FilePayloadStore({
    required this.beforeMutation,
    PayloadFileBackend? backend,
    this.maxPayloadChars = V2PayloadLimits.maxPayloadChars,
    this.maxReadableBytes = V2PayloadLimits.maxReadableBytes,
    this.maxMemoryChars = V2PayloadLimits.maxMemoryChars,
    this.maxMemoryEntryChars = V2PayloadLimits.maxMemoryEntryChars,
    this.maxMemoryEntries = 24,
  }) : _backend = backend ?? NativePayloadFileBackend() {
    if (maxPayloadChars < 0 ||
        maxPayloadChars > V2PayloadLimits.maxPayloadChars ||
        maxReadableBytes < 1 ||
        maxReadableBytes > V2PayloadLimits.maxReadableBytes ||
        maxMemoryChars < 0 ||
        maxMemoryChars > V2PayloadLimits.maxMemoryChars ||
        maxMemoryEntryChars < 0 ||
        maxMemoryEntryChars > V2PayloadLimits.maxMemoryEntryChars ||
        maxMemoryEntries < 0 ||
        maxMemoryEntries > 24) {
      throw ArgumentError(
        'Payload limits may only narrow the ADR-016 ceilings',
      );
    }
  }

  final Future<void> Function() beforeMutation;
  final PayloadFileBackend _backend;
  final int maxPayloadChars;
  final int maxReadableBytes;
  final int maxMemoryChars;
  final int maxMemoryEntryChars;
  final int maxMemoryEntries;
  final KeySerialExecutor _queue = KeySerialExecutor();
  final LinkedHashMap<String, String> _memory = LinkedHashMap();
  int _memoryChars = 0;

  int get memoryChars => _memoryChars;
  int get memoryEntries => _memory.length;

  @override
  Future<bool> contains(String key) {
    requireV2Key(key);
    return _queue.run(
      key,
      () async =>
          _memory.containsKey(key) ||
          await _backend.read(key, maxBytes: maxReadableBytes) != null,
    );
  }

  @override
  Future<String?> read(String key) {
    requireV2Key(key);
    return _queue.run(key, () async {
      final cached = _touch(key);
      if (cached != null) return cached;
      try {
        final bytes = await _backend.read(key, maxBytes: maxReadableBytes);
        if (bytes == null) return null;
        // Defend against injected/backported implementations ignoring the cap.
        if (bytes.length > maxReadableBytes) {
          throw const OversizedPayloadFile();
        }
        final value = utf8.decode(bytes);
        if (value.length > maxPayloadChars) {
          throw const OversizedPayloadFile();
        }
        _remember(key, value);
        return value;
      } on FormatException {
        await _discardCorrupt(key);
        return null;
      } on OversizedPayloadFile {
        await _discardCorrupt(key);
        return null;
      } catch (_) {
        // Transient directory/stat/read failures preserve the on-disk value.
        return null;
      }
    });
  }

  @override
  Future<PayloadWriteResult> write(String key, String value) {
    requireV2Key(key);
    return _queue.run(key, () async {
      await beforeMutation();
      if (value.length > maxPayloadChars) {
        return PayloadWriteResult.refusedOversized;
      }
      if (_touch(key) == value) return PayloadWriteResult.unchanged;
      // Also guard large entries that intentionally bypass the LRU.
      try {
        final bytes = await _backend.read(key, maxBytes: maxReadableBytes);
        if (bytes != null &&
            bytes.length <= maxReadableBytes &&
            utf8.decode(bytes) == value) {
          _remember(key, value);
          return PayloadWriteResult.unchanged;
        }
      } catch (_) {
        // A missing/unreadable old value does not imply a successful new write.
      }
      // Memory changes only after durable replacement succeeds.
      await _backend.replace(key, value);
      _remember(key, value);
      return PayloadWriteResult.written;
    });
  }

  @override
  Future<void> remove(String key) {
    requireV2Key(key);
    return _queue.run(key, () async {
      await beforeMutation();
      await _backend.remove(key);
      _evict(key);
    });
  }

  Future<void> _discardCorrupt(String key) async {
    try {
      await beforeMutation();
      await _backend.remove(key);
    } catch (_) {
      // Cleanup can be retried later; future-schema data is never deleted.
    }
  }

  String? _touch(String key) {
    final value = _memory.remove(key);
    if (value != null) _memory[key] = value;
    return value;
  }

  void _evict(String key) {
    final old = _memory.remove(key);
    if (old != null) _memoryChars -= old.length;
  }

  void _remember(String key, String value) {
    _evict(key);
    if (value.length > maxMemoryEntryChars) return;
    _memory[key] = value;
    _memoryChars += value.length;
    while (_memoryChars > maxMemoryChars || _memory.length > maxMemoryEntries) {
      _evict(_memory.keys.first);
    }
  }
}
