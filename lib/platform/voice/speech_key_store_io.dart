import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/voice/read_aloud.dart';

/// The read-aloud API keys, in the device's secure storage under their own
/// names, apart from the server credentials, one per service and origin
/// (#541).
final class SecureSpeechKeys implements SpeechKeyStore {
  SecureSpeechKeys({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyFor(String scope) =>
      'cw2.voice.${base64Url.encode(utf8.encode(scope)).replaceAll('=', '')}'
      '.apiKey';

  @override
  Future<String?> read(String scope) => _storage.read(key: keyFor(scope));

  @override
  Future<void> write(String scope, String? key) async {
    final value = key?.trim();
    if (value == null || value.isEmpty) {
      await _storage.delete(key: keyFor(scope));
    } else {
      await _storage.write(key: keyFor(scope), value: value);
    }
  }
}
