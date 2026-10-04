import 'storage_support.dart';

abstract interface class MetadataBackend {
  Future<Object?> read(String key);
  Future<void> write(String key, Object value);
  Future<void> remove(String key);
}

/// The V2-076 importer supplies this read-only interface. No legacy writer or
/// cleanup operation is available to migration hooks here.
abstract interface class LegacyStorageReader {
  Future<Object?> read(String key);
}

typedef SchemaUpgrade = Future<void> Function(SchemaMigrationContext context);

final class StorageSchemaException implements Exception {
  const StorageSchemaException(this.message);
  final String message;

  @override
  String toString() => 'StorageSchemaException: $message';
}

/// Upgrade callbacks must be idempotent: a crash after their writes but before
/// the marker advances runs the same callback again. This is a storage hook,
/// not the product's v1 importer or installed-upgrade acceptance.
final class SchemaMigrationContext {
  SchemaMigrationContext._(this._store, this.legacy);

  final V2MetadataStore _store;
  final LegacyStorageReader? legacy;
  final KeySerialExecutor _queue = KeySerialExecutor();
  final List<Future<void>> _pending = [];
  bool _active = true;
  Object? _failure;
  StackTrace? _failureTrace;

  Future<Object?> read(String key) =>
      _start(key, () => _store._readDirect(key));
  Future<bool> write(String key, Object value) =>
      _start(key, () => _store._writeDirect(key, value));
  Future<bool> remove(String key) =>
      _start(key, () => _store._removeDirect(key));

  Future<T> _start<T>(String key, Future<T> Function() operation) {
    if (!_active) {
      return Future.error(StateError('The migration context has been revoked'));
    }
    final result = _queue.run(key, operation);
    // Attach the error handler immediately, including for an unawaited hook
    // operation. Its error remains visible through both result and _finish.
    _pending.add(
      result.then<void>(
        (_) {},
        onError: (Object error, StackTrace trace) {
          _failure ??= error;
          _failureTrace ??= trace;
        },
      ),
    );
    return result;
  }

  Future<void> _finish() async {
    _active = false;
    await Future.wait(_pending);
    final failure = _failure;
    if (failure != null) {
      Error.throwWithStackTrace(failure, _failureTrace!);
    }
  }
}

final class V2MetadataStore {
  V2MetadataStore({
    required MetadataBackend backend,
    this.currentSchema = 1,
    Map<int, SchemaUpgrade> upgrades = const {},
    this.legacy,
    // Public injection name; the raw backend is not a consumer mutation API.
    // ignore: prefer_initializing_formals
  }) : _backend = backend,
       _upgrades = Map.unmodifiable(upgrades) {
    if (currentSchema < 1) throw ArgumentError.value(currentSchema);
  }

  static const schemaKey = 'cw2.schema';
  static const maxPreferenceChars = 1024 * 1024;
  final MetadataBackend _backend;
  final int currentSchema;
  final Map<int, SchemaUpgrade> _upgrades;
  final LegacyStorageReader? legacy;
  final KeySerialExecutor _queue = KeySerialExecutor();
  Future<void>? _initialization;

  Future<void> ensureSchema() {
    final existing = _initialization;
    if (existing != null) return existing;
    final future = _upgradeSchema();
    _initialization = future;
    // Coalesce only an in-flight check. Revalidate every later mutation in case
    // another engine upgraded or corrupted the marker while this store lives.
    future.then<void>(
      (_) {
        if (identical(_initialization, future)) _initialization = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_initialization, future)) _initialization = null;
      },
    );
    return future;
  }

  Future<void> _upgradeSchema() async {
    final saved = await _backend.read(schemaKey);
    if (saved != null && (saved is! int || saved < 0)) {
      throw const StorageSchemaException(
        'Invalid schema marker; data preserved',
      );
    }
    var version = saved as int? ?? 0;
    if (version > currentSchema) {
      throw const StorageSchemaException(
        'Future schema; mutations unavailable',
      );
    }
    while (version < currentSchema) {
      final next = version + 1;
      final upgrade = _upgrades[next];
      if (upgrade == null && next != 1) {
        throw StorageSchemaException('Missing upgrade to schema $next');
      }
      if (upgrade != null) {
        final context = SchemaMigrationContext._(this, legacy);
        try {
          await upgrade(context);
        } catch (_) {
          // Revoke and drain before a caller can retry this step. Keep the
          // original hook error if a pending operation also failed.
          try {
            await context._finish();
          } catch (_) {}
          rethrow;
        }
        await context._finish();
      }
      await _backend.write(schemaKey, next);
      version = next;
    }
  }

  Future<Object?> read(String key) {
    requireV2Key(key);
    return _queue.run(key, () async {
      final initializing = _initialization;
      if (initializing != null) await initializing;
      return _readDirect(key);
    });
  }

  Future<Object?> _readDirect(String key) async {
    requireV2Key(key);
    final value = await _backend.read(key);
    return value is List<String> ? List<String>.unmodifiable(value) : value;
  }

  Future<bool> write(String key, Object value) async {
    _requireOrdinaryKey(key);
    final snapshot = _validatedSnapshot(value);
    // Reserve the key immediately, before initialization awaits. A read called
    // directly after write therefore cannot overtake the pending mutation.
    return _queue.run(key, () async {
      await ensureSchema();
      return _writeDirect(key, snapshot);
    });
  }

  Future<bool> _writeDirect(String key, Object value) async {
    _requireOrdinaryKey(key);
    final snapshot = _validatedSnapshot(value);
    if (_sameValue(await _backend.read(key), snapshot)) return false;
    await _backend.write(key, snapshot);
    return true;
  }

  Future<bool> remove(String key) async {
    _requireOrdinaryKey(key);
    return _queue.run(key, () async {
      await ensureSchema();
      return _removeDirect(key);
    });
  }

  Future<bool> _removeDirect(String key) async {
    _requireOrdinaryKey(key);
    if (await _backend.read(key) == null) return false;
    await _backend.remove(key);
    return true;
  }

  Future<void> flush() => _queue.drain();

  static void _requireOrdinaryKey(String key) {
    requireV2Key(key);
    if (key == schemaKey) throw ArgumentError('The schema marker is reserved');
  }

  static Object _validatedSnapshot(Object value) {
    if (value is bool || value is int || value is double) return value;
    if (value is String && value.length <= maxPreferenceChars) return value;
    if (value is List<String> &&
        value.fold<int>(0, (sum, item) => sum + item.length) <=
            maxPreferenceChars) {
      return List<String>.unmodifiable(value);
    }
    throw ArgumentError('Unsupported or oversized preference value');
  }

  static bool _sameValue(Object? first, Object second) {
    if (first is List<String> && second is List<String>) {
      if (first.length != second.length) return false;
      for (var i = 0; i < first.length; i++) {
        if (first[i] != second[i]) return false;
      }
      return true;
    }
    return first == second;
  }
}
