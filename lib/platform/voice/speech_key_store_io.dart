import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/voice/read_aloud.dart';

/// The read-aloud API keys, in the device's secure storage under their own
/// names, apart from the server credentials (#541).
final class SecureSpeechKeys implements SpeechKeyStore {
  SecureSpeechKeys({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyFor(SpeechProvider provider) =>
      'cw2.voice.${provider.name}.apiKey';

  @override
  Future<String?> read(SpeechProvider provider) async {
    if (!provider.keyed) return null;
    return _storage.read(key: keyFor(provider));
  }

  @override
  Future<void> write(SpeechProvider provider, String? key) async {
    if (!provider.keyed) return;
    final value = key?.trim();
    if (value == null || value.isEmpty) {
      await _storage.delete(key: keyFor(provider));
    } else {
      await _storage.write(key: keyFor(provider), value: value);
    }
  }
}
