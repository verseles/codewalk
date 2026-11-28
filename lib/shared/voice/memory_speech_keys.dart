import 'read_aloud.dart';

/// Keys kept in memory only, where no secure storage exists (Web, tests).
final class MemorySpeechKeys implements SpeechKeyStore {
  final _keys = <SpeechProvider, String>{};

  @override
  Future<String?> read(SpeechProvider provider) async => _keys[provider];

  @override
  Future<void> write(SpeechProvider provider, String? key) async {
    final value = key?.trim();
    if (value == null || value.isEmpty) {
      _keys.remove(provider);
    } else {
      _keys[provider] = value;
    }
  }
}
