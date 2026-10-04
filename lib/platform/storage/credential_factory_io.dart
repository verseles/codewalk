import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'endpoint_credentials.dart';
import 'metadata_store.dart';

final class SecureEndpointCredentialBackend
    implements EndpointCredentialBackend {
  SecureEndpointCredentialBackend({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    requireEndpointCredentialKey(key);
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    requireEndpointCredentialKey(key);
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> remove(String key) {
    requireEndpointCredentialKey(key);
    return _storage.delete(key: key);
  }
}

EndpointCredentialVault createEndpointCredentials(V2MetadataStore metadata) =>
    EndpointCredentialVault(
      backend: SecureEndpointCredentialBackend(),
      beforeMutation: metadata.ensureSchema,
    );
