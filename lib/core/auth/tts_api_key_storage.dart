import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/l10n_bridge.dart';
import '../../domain/entities/experience_settings.dart';

class TtsApiKeyStorageException implements Exception {
  const TtsApiKeyStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'TtsApiKeyStorageException: $message'
      : 'TtsApiKeyStorageException: $message ($cause)';
}

abstract class TtsApiKeyStorageBackend {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureTtsApiKeyStorageBackend implements TtsApiKeyStorageBackend {
  const FlutterSecureTtsApiKeyStorageBackend([this._secureStorage]);

  final FlutterSecureStorage? _secureStorage;

  FlutterSecureStorage get _storage =>
      _secureStorage ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}

class TtsApiKeyStorage {
  TtsApiKeyStorage({TtsApiKeyStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTtsApiKeyStorageBackend();

  final TtsApiKeyStorageBackend _backend;

  String get _storageUnavailableMessage =>
      L10nBridge.current?.speechApiKeyStorageUnavailable ??
      'Secure TTS API key storage is unavailable.';

  String _key(ReadAloudProvider provider) {
    return '${AppConstants.secureStorageNamespace}::tts_api_key::'
        '${readAloudProviderKey(provider)}';
  }

  Future<String?> read(ReadAloudProvider provider) async {
    try {
      final raw = await _backend.read(key: _key(provider));
      final trimmed = raw?.trim();
      return trimmed != null && trimmed.isNotEmpty ? trimmed : null;
    } catch (error) {
      throw TtsApiKeyStorageException(_storageUnavailableMessage, error);
    }
  }

  Future<void> write(ReadAloudProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await delete(provider);
      return;
    }
    try {
      await _backend.write(key: _key(provider), value: trimmed);
    } catch (error) {
      throw TtsApiKeyStorageException(_storageUnavailableMessage, error);
    }
  }

  Future<void> delete(ReadAloudProvider provider) async {
    try {
      await _backend.delete(key: _key(provider));
    } catch (error) {
      throw TtsApiKeyStorageException(_storageUnavailableMessage, error);
    }
  }
}
