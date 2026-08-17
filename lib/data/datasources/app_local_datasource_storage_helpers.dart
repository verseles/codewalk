part of 'app_local_datasource.dart';

extension _AppLocalDataSourceStorageHelpers on AppLocalDataSourceImpl {
  String _secureScopedKey(String base, {String? serverId, String? scopeId}) {
    return _scopedKey(
      '${AppConstants.secureStorageNamespace}::$base',
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  String _serverProfileSecureKey({
    required String base,
    required String serverId,
  }) {
    final encodedServer = Uri.encodeComponent(serverId.trim());
    return '${AppConstants.secureStorageNamespace}::$base::$encodedServer';
  }

  Future<String?> _readSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecureValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {
      // Ignore secure storage write failures and keep app functional.
    }
  }

  Future<void> _deleteSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {
      // Ignore secure storage delete failures and keep app functional.
    }
  }

  Future<String?> _readSecureWithLegacyFallback({
    required String secureKey,
    required String legacyKey,
  }) async {
    final secureValue = await _readSecureValue(secureKey);
    if (secureValue != null && secureValue.trim().isNotEmpty) {
      return secureValue;
    }
    final legacyValue = _sharedPreferences.getString(legacyKey);
    if (legacyValue == null || legacyValue.trim().isEmpty) {
      return null;
    }
    await _writeSecureValue(secureKey, legacyValue);
    await _sharedPreferences.remove(legacyKey);
    return legacyValue;
  }

  Future<String?> _readProfileCredential({
    required String serverId,
    required String base,
  }) async {
    final secureKey = _serverProfileSecureKey(base: base, serverId: serverId);
    return _readSecureValue(secureKey);
  }

  Future<void> _writeProfileCredential({
    required String serverId,
    required String base,
    required String value,
  }) async {
    final secureKey = _serverProfileSecureKey(base: base, serverId: serverId);
    if (value.trim().isEmpty) {
      await _deleteSecureValue(secureKey);
      return;
    }
    await _writeSecureValue(secureKey, value);
  }

  String _scopedKey(String base, {String? serverId, String? scopeId}) {
    final scopedServer = serverId?.trim();
    if (scopedServer == null || scopedServer.isEmpty) {
      return base;
    }
    final encodedServer = Uri.encodeComponent(scopedServer);
    final scopedContext = scopeId?.trim();
    if (scopedContext == null || scopedContext.isEmpty) {
      return '$base::$encodedServer';
    }
    final encodedContext = Uri.encodeComponent(scopedContext);
    return '$base::$encodedServer::$encodedContext';
  }

  String _sessionScopedKey(
    String base, {
    required String sessionId,
    String? serverId,
    String? scopeId,
  }) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return _scopedKey(base, serverId: serverId, scopeId: scopeId);
    }
    final encodedSession = Uri.encodeComponent(normalizedSessionId);
    return _scopedKey(
      '$base::$encodedSession',
      serverId: serverId,
      scopeId: scopeId,
    );
  }

  Future<String?> _readLargeCachePayload(String key) async {
    return AppLogger.runPerformanceTask<String?>(
      'cache_read',
      () async {
        final store = _chatCachePayloadStore;
        if (store == null) {
          return _sharedPreferences.getString(key);
        }

        final legacy = _sharedPreferences.getString(key);
        if (legacy != null && legacy.trim().isNotEmpty) {
          final migration = _scheduleLegacyLargeCacheMigration(key, legacy);
          if (migration != null) unawaited(migration);
          return legacy;
        }
        if (legacy != null) {
          unawaited(
            _queueLargeCacheMutation(key, () async {
              try {
                final current = _sharedPreferences.getString(key);
                if (current != null && current.trim().isEmpty) {
                  await _sharedPreferences.remove(key);
                  _migratedLargeCacheKeys.add(key);
                }
              } catch (_) {
                _migratedLargeCacheKeys.remove(key);
              }
            }),
          );
          return null;
        }

        try {
          final stored = await store.read(key);
          if (stored != null) {
            _migratedLargeCacheKeys.add(key);
            return stored;
          }
        } catch (_) {
          // Keep the app functional if the file-backed store is unavailable.
          return null;
        }

        if (_migratedLargeCacheKeys.contains(key)) {
          return null;
        }
        _migratedLargeCacheKeys.add(key);
        return null;
      },
      tags: const <String>{'cache:read'},
      contextBuilder: () => <String, Object?>{
        'keyHash': AppLogger.safeContextId(key),
        'fileStore': _chatCachePayloadStore != null,
      },
    );
  }

  Future<void> _migrateLegacyLargeCachePayloads() async {
    final store = _chatCachePayloadStore;
    if (store == null) {
      return;
    }

    final List<String> keys;
    try {
      keys = _sharedPreferences
          .getKeys()
          .where(_isLargeCachePayloadPreferenceKey)
          .toList(growable: false);
    } catch (_) {
      return;
    }
    if (keys.isEmpty) return;

    return AppLogger.runPerformanceTask<void>(
      'cache_migrate_legacy_payloads',
      () async {
        final migrations = <Future<void>>[];
        for (final key in keys) {
          final legacy = _sharedPreferences.getString(key);
          if (legacy == null) continue;
          if (legacy.trim().isEmpty) {
            migrations.add(
              _queueLargeCacheMutation(key, () async {
                try {
                  await _sharedPreferences.remove(key);
                  _migratedLargeCacheKeys.add(key);
                } catch (_) {
                  _migratedLargeCacheKeys.remove(key);
                }
              }),
            );
            continue;
          }
          final migration = _scheduleLegacyLargeCacheMigration(key, legacy);
          if (migration != null) migrations.add(migration);
          await Future<void>.delayed(Duration.zero);
        }
        if (migrations.isNotEmpty) {
          await Future.wait<void>(migrations);
        }
      },
      tags: const <String>{'cache:migrate'},
      context: <String, Object?>{'keyCount': keys.length},
    );
  }

  Future<void>? _scheduleLegacyLargeCacheMigration(String key, String value) {
    final store = _chatCachePayloadStore;
    if (store == null) return null;
    if (!_pendingLargeCacheMigrationKeys.add(key)) {
      return _largeCacheMutations[key];
    }
    return _queueLargeCacheMutation(key, () async {
      try {
        await AppLogger.runPerformanceTask<void>(
          'cache_migrate_legacy_payload',
          () async {
            if (_sharedPreferences.getString(key) != value) return;
            await store.write(key, value);
            if (_sharedPreferences.getString(key) == value) {
              await _sharedPreferences.remove(key);
            }
          },
          tags: const <String>{'cache:migrate'},
          contextBuilder: () => <String, Object?>{
            'keyHash': AppLogger.safeContextId(key),
            'sizeBytes': value.length,
          },
        );
        if (_sharedPreferences.getString(key) != value) {
          _migratedLargeCacheKeys.add(key);
        }
      } catch (_) {
        _migratedLargeCacheKeys.remove(key);
      } finally {
        _pendingLargeCacheMigrationKeys.remove(key);
      }
    });
  }

  Future<void> _queueLargeCacheMutation(
    String key,
    Future<void> Function() action,
  ) {
    final previous = _largeCacheMutations[key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_largeCacheMutations[key], tracked)) {
        _largeCacheMutations.remove(key);
      }
    });
    _largeCacheMutations[key] = tracked;
    return tracked;
  }

  bool _isLargeCachePayloadPreferenceKey(String key) {
    if (_isScopedLargeCachePayloadKey(key, AppConstants.cachedSessionsKey) ||
        _isScopedLargeCachePayloadKey(
          key,
          AppConstants.lastSessionSnapshotKey,
        )) {
      return true;
    }
    return _isScopedLargeCachePayloadKey(
      key,
      AppConstants.sessionMessagesSnapshotKey,
    );
  }

  bool _isScopedLargeCachePayloadKey(String key, String base) {
    return key == base || key.startsWith('$base::');
  }

  Future<bool> _writeLargeCachePayload(String key, String value) async {
    return AppLogger.runPerformanceTask<bool>(
      'cache_write',
      () async {
        final store = _chatCachePayloadStore;
        if (store == null) {
          if (_sharedPreferences.getString(key) == value) return false;
          await _sharedPreferences.setString(key, value);
          return true;
        }
        var wrote = false;
        await _queueLargeCacheMutation(key, () async {
          try {
            wrote = await store.write(key, value);
            await _sharedPreferences.remove(key);
            _migratedLargeCacheKeys.add(key);
          } catch (_) {
            _migratedLargeCacheKeys.remove(key);
            try {
              await store.remove(key);
            } catch (_) {}
            await _sharedPreferences.setString(key, value);
            wrote = true;
          }
        });
        return wrote;
      },
      tags: const <String>{'cache:write'},
      contextBuilder: () => <String, Object?>{
        'keyHash': AppLogger.safeContextId(key),
        'sizeBytes': value.length,
        'fileStore': _chatCachePayloadStore != null,
      },
    );
  }

  Future<void> _removeLargeCachePayload(String key) async {
    final store = _chatCachePayloadStore;
    if (store != null) {
      try {
        await _queueLargeCacheMutation(key, () async {
          try {
            await store.remove(key);
          } catch (_) {}
          await _sharedPreferences.remove(key);
          _migratedLargeCacheKeys.add(key);
        });
      } catch (_) {
        _migratedLargeCacheKeys.remove(key);
      }
      return;
    }
    await _sharedPreferences.remove(key);
  }

  Future<void> _clearLargeCachePayloads() async {
    final pendingMutations = _largeCacheMutations.values.toList(
      growable: false,
    );
    if (pendingMutations.isNotEmpty) {
      try {
        await Future.wait<void>(pendingMutations);
      } catch (_) {}
    }
    final store = _chatCachePayloadStore;
    if (store != null) {
      try {
        await store.clear();
      } catch (_) {}
    }
    _migratedLargeCacheKeys.clear();
    _pendingLargeCacheMigrationKeys.clear();
  }
}
