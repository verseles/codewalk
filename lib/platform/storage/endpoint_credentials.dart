import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'storage_support.dart';

enum EndpointCredentialKind { endpointPassword, pairingToken, activeCredential }

/// A profile is deliberately separate from an origin: aliases are not merged
/// and a changed port is never rewritten to the native service default.
final class EndpointCredentialScope {
  EndpointCredentialScope({required Uri endpoint, required this.profileId})
    : origin = _canonicalOrigin(endpoint) {
    if (profileId.trim().isEmpty || profileId.contains('\u0000')) {
      throw ArgumentError('A nonempty profile identity is required');
    }
  }

  final Uri origin;
  final String profileId;

  static Uri _canonicalOrigin(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535) {
      // Do not echo a rejected URI that could contain an embedded secret.
      throw ArgumentError(
        'Expected an HTTP(S) endpoint without URL credentials',
      );
    }
    final defaultPort = scheme == 'https' ? 443 : 80;
    return Uri(
      scheme: scheme,
      host: uri.host.toLowerCase(),
      port: uri.port == defaultPort ? null : uri.port,
    );
  }

  String key(EndpointCredentialKind kind) {
    final tuple = jsonEncode([origin.toString(), profileId, kind.name]);
    return 'cw2.auth.${sha256.convert(utf8.encode(tuple))}';
  }
}

abstract interface class EndpointCredentialBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Instance-local browser memory. A new page/vault does not retain credentials;
/// no localStorage, preferences or secure-storage Web plugin is involved.
final class MemoryEndpointCredentialBackend
    implements EndpointCredentialBackend {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async {
    requireEndpointCredentialKey(key);
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    requireEndpointCredentialKey(key);
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    requireEndpointCredentialKey(key);
    _values.remove(key);
  }
}

void requireEndpointCredentialKey(String key) {
  if (!RegExp(r'^cw2\.auth\.[a-f0-9]{64}$').hasMatch(key)) {
    throw ArgumentError('Expected a v2 endpoint credential key');
  }
}

final class EndpointCredentialVault {
  EndpointCredentialVault({
    required EndpointCredentialBackend backend,
    required this.beforeMutation,
    // Public injection name; retain the backend as private implementation state.
    // ignore: prefer_initializing_formals
  }) : _backend = backend;

  final EndpointCredentialBackend _backend;
  final Future<void> Function() beforeMutation;
  final KeySerialExecutor _queue = KeySerialExecutor();

  Future<String?> read(
    EndpointCredentialScope scope,
    EndpointCredentialKind kind,
  ) {
    final key = scope.key(kind);
    return _queue.run(key, () => _backend.read(key));
  }

  Future<bool> write(
    EndpointCredentialScope scope,
    EndpointCredentialKind kind,
    String value,
  ) {
    if (value.isEmpty) {
      throw ArgumentError('Use remove for an empty credential');
    }
    final key = scope.key(kind);
    return _queue.run(key, () async {
      await beforeMutation();
      if (await _backend.read(key) == value) return false;
      await _backend.write(key, value);
      return true;
    });
  }

  Future<bool> remove(
    EndpointCredentialScope scope,
    EndpointCredentialKind kind,
  ) {
    final key = scope.key(kind);
    return _queue.run(key, () async {
      await beforeMutation();
      if (await _backend.read(key) == null) return false;
      await _backend.remove(key);
      return true;
    });
  }

  Future<void> flush() => _queue.drain();
}
