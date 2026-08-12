import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/experience_settings.dart';
import '../constants/app_constants.dart';

class SttApiKeyStorageException implements Exception {
  const SttApiKeyStorageException(this.cause);

  final Object cause;
}

abstract class SttApiKeyStorageBackend {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

class FlutterSecureSttApiKeyStorageBackend implements SttApiKeyStorageBackend {
  const FlutterSecureSttApiKeyStorageBackend([this._secureStorage]);

  final FlutterSecureStorage? _secureStorage;

  FlutterSecureStorage get _storage =>
      _secureStorage ?? const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class SttApiKeyStorage {
  SttApiKeyStorage({SttApiKeyStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureSttApiKeyStorageBackend();

  final SttApiKeyStorageBackend _backend;

  String _key(SpeechApiProvider provider) {
    return '${AppConstants.secureStorageNamespace}::stt_api_key::'
        '${speechApiProviderKey(provider)}';
  }

  Future<String?> read(SpeechApiProvider provider) async {
    try {
      final value = (await _backend.read(key: _key(provider)))?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (error) {
      throw SttApiKeyStorageException(error);
    }
  }

  Future<void> write(SpeechApiProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await delete(provider);
      return;
    }
    try {
      await _backend.write(key: _key(provider), value: trimmed);
    } catch (error) {
      throw SttApiKeyStorageException(error);
    }
  }

  Future<void> delete(SpeechApiProvider provider) async {
    try {
      await _backend.delete(key: _key(provider));
    } catch (error) {
      throw SttApiKeyStorageException(error);
    }
  }
}
