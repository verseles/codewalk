import 'read_aloud.dart';

/// Keys kept in memory only, where no secure storage exists (Web, tests).
final class MemorySpeechKeys implements SpeechKeyStore {
  final _keys = <String, String>{};

  @override
  Future<String?> read(String scope) async => _keys[scope];

  @override
  Future<void> write(String scope, String? key) async {
    final value = key?.trim();
    if (value == null || value.isEmpty) {
      _keys.remove(scope);
    } else {
      _keys[scope] = value;
    }
  }
}
