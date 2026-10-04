import 'dart:convert';

import 'metadata_store.dart';
import 'storage_support.dart';

abstract final class V2PayloadLimits {
  static const maxPayloadChars = 2 * 1024 * 1024;
  static const maxPreferenceChars = 1024 * 1024;
  static const maxReadableBytes = 8 * 1024 * 1024;
  static const maxMemoryChars = 2 * 1024 * 1024;
  static const maxMemoryEntryChars = 512 * 1024;
}

enum PayloadWriteResult { written, unchanged, refusedOversized }

abstract interface class PayloadStore {
  Future<String?> read(String key);

  /// Non-destructive presence check. Only confirmed absence returns false;
  /// failures propagate so an importer cannot overwrite an unreadable value.
  Future<bool> contains(String key);
  Future<PayloadWriteResult> write(String key, String value);
  Future<void> remove(String key);
}

extension JsonPayloadStore on PayloadStore {
  Future<Object?> readJson(String key) async {
    final raw = await read(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      // The read's snapshot may have been replaced by a valid concurrent write.
      // Without compare-and-delete at the store boundary, preserve the value.
      return null;
    }
  }

  Future<PayloadWriteResult> writeJson(String key, Object? value) =>
      write(key, jsonEncode(value));
}

/// Web/test fallback. The metadata boundary supplies schema and no-op guards.
final class PreferencesPayloadStore implements PayloadStore {
  PreferencesPayloadStore(this.metadata);
  final V2MetadataStore metadata;
  final KeySerialExecutor _queue = KeySerialExecutor();

  @override
  Future<bool> contains(String key) {
    requireV2Key(key);
    return _queue.run(key, () async => await metadata.read(key) != null);
  }

  @override
  Future<String?> read(String key) {
    requireV2Key(key);
    return _queue.run(key, () async {
      final value = await metadata.read(key);
      if (value is! String ||
          value.length > V2PayloadLimits.maxPreferenceChars) {
        return null;
      }
      return value;
    });
  }

  @override
  Future<PayloadWriteResult> write(String key, String value) {
    requireV2Key(key);
    return _queue.run(key, () async {
      await metadata.ensureSchema();
      if (value.length > V2PayloadLimits.maxPreferenceChars) {
        return PayloadWriteResult.refusedOversized;
      }
      return await metadata.write(key, value)
          ? PayloadWriteResult.written
          : PayloadWriteResult.unchanged;
    });
  }

  @override
  Future<void> remove(String key) {
    requireV2Key(key);
    return _queue.run(key, () async {
      await metadata.remove(key);
    });
  }
}
