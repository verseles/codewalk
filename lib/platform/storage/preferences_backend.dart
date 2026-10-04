import 'package:shared_preferences/shared_preferences.dart';

import 'metadata_store.dart';
import 'storage_support.dart';

/// Filter reads to the requested v2 key; never load or clear the legacy set.
final class PreferencesMetadataBackend implements MetadataBackend {
  PreferencesMetadataBackend({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<Object?> read(String key) async {
    requireV2Key(key);
    return (await _preferences.getAll(allowList: {key}))[key];
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
