import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/payload_store.dart';
import 'legacy_source.dart';

bool isLegacyImportKey(String key) {
  if (key.contains('\u0000')) return false;
  const globals = {
    'experience_settings',
    'theme_mode',
    'locale_code',
    'server_profiles',
    'server_host',
    'server_port',
    'active_server_id',
    'default_server_id',
  };
  const scoped = {
    'session_composer_draft',
    'canned_answers',
    'basic_auth_enabled',
    'basic_auth_username',
    'basic_auth_password',
    'api_key',
  };
  return globals.contains(key) ||
      scoped.any((base) => key == base || key.startsWith('$base::'));
}

/// The caller must select the original backend, not Async's default DataStore.
/// For Android classic v1: SharedPreferences backend, fileName
/// FlutterSharedPreferences, physicalPrefix flutter. Async does not strip that
/// prefix. Other raw bridges may expose unprefixed keys; choose '' explicitly.
/// Backend selection/native startup remain external integration prerequisites.
final class RawLegacyPreferencesReader implements LegacyPreferencesReader {
  RawLegacyPreferencesReader({
    required SharedPreferencesAsync preferences,
    required this.physicalPrefix,
    this.maxValueChars = V2PayloadLimits.maxPayloadChars,
  }) : _preferences = preferences {
    if (physicalPrefix != '' && physicalPrefix != 'flutter.') {
      throw ArgumentError('Expected an explicit classic preference prefix');
    }
    if (maxValueChars < 0 || maxValueChars > V2PayloadLimits.maxPayloadChars) {
      throw ArgumentError('Legacy preference limits may only narrow ceilings');
    }
  }

  final SharedPreferencesAsync _preferences;
  final String physicalPrefix;
  final int maxValueChars;

  @override
  Future<Set<String>> keys() async {
    try {
      final physical = await _preferences.getKeys();
      return Set.unmodifiable({
        for (final key in physical)
          if (key.startsWith(physicalPrefix))
            if (isLegacyImportKey(key.substring(physicalPrefix.length)))
              key.substring(physicalPrefix.length),
      });
    } catch (_) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }

  @override
  Future<Object?> read(String key) async {
    if (!isLegacyImportKey(key)) throw ArgumentError('Unsupported legacy key');
    try {
      final physical = '$physicalPrefix$key';
      final value = (await _preferences.getAll(
        allowList: {physical},
      ))[physical];
      if (value is String && value.length > maxValueChars) {
        throw const LegacyReadException(LegacyReadFailure.oversized);
      }
      return value;
    } on LegacyReadException {
      rethrow;
    } catch (_) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }
}

/// Never readAll, write, delete or use a mutating legacy fallback.
final class RawLegacySecureReader implements LegacySecureReader {
  RawLegacySecureReader({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    if (!key.startsWith('codewalk.secure::') || key.contains('\u0000')) {
      throw ArgumentError('Unsupported legacy secure key');
    }
    try {
      return await _storage.read(key: key);
    } catch (_) {
      throw const LegacyReadException(LegacyReadFailure.unavailable);
    }
  }
}
