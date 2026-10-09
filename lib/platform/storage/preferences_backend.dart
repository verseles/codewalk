import 'package:shared_preferences/shared_preferences.dart';

import 'metadata_store.dart';
import 'storage_support.dart';

/// Filter reads to the requested v2 key; never load or clear the legacy set.
final class PreferencesMetadataBackend implements MetadataBackend {
  PreferencesMetadataBackend({SharedPreferencesAsync? preferences})
    : _providedPreferences = preferences;

  final SharedPreferencesAsync? _providedPreferences;
  // Building an injected graph does not access a platform plugin. Actual reads
  // still require registration and surface failures through the storage caller.
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();

  @override
  Future<Object?> read(String key) async {
    requireV2Key(key);
    final value = (await _preferences.getAll(allowList: {key}))[key];
    // Linux JSON reloads erase list type arguments. Preserve malformed values
    // for the caller's corruption guard instead of dropping invalid elements.
    return value is List && value.every((item) => item is String)
        ? List<String>.unmodifiable(value)
        : value;
  }

  @override
  Future<void> write(String key, Object value) {
    requireV2Key(key);
    return switch (value) {
      final bool value => _preferences.setBool(key, value),
      final int value => _preferences.setInt(key, value),
      final double value => _preferences.setDouble(key, value),
      final String value => _preferences.setString(key, value),
      final List<String> value => _preferences.setStringList(key, value),
      _ => throw ArgumentError('Unsupported preference type'),
    };
  }

  @override
  Future<void> remove(String key) {
    requireV2Key(key);
    return _preferences.remove(key);
  }
}
