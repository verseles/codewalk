@TestOn('vm')
library;

import 'package:codewalk/platform/storage/credential_factory_io.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/preferences_backend.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class RecordingPreferences implements SharedPreferencesAsync {
  final Map<String, Object> values = {'legacy.large': 'preserved'};
  final List<Set<String>?> reads = [];
  final List<String> removals = [];

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    reads.add(allowList);
    return {
      for (final entry in values.entries)
        if (allowList?.contains(entry.key) ?? true) entry.key: entry.value,
    };
  }

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> setInt(String key, int value) async => values[key] = value;
  @override
  Future<void> setDouble(String key, double value) async => values[key] = value;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      values[key] = value;
  @override
  Future<void> remove(String key) async {
    removals.add(key);
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'preferences bridge uses per-key allowlists and typed writes, no global clear',
    () async {
      final plugin = RecordingPreferences();
      final backend = PreferencesMetadataBackend(preferences: plugin);
      final metadata = V2MetadataStore(backend: backend);
      final values = <String, Object>{
        'cw2.bool': false,
        'cw2.int': 7,
        'cw2.double': 1.5,
        'cw2.string': 'text',
        'cw2.list': ['a', 'b'],
      };
      for (final entry in values.entries) {
        await metadata.write(entry.key, entry.value);
        expect(await metadata.read(entry.key), entry.value);
      }
      await metadata.remove('cw2.string');
      expect(plugin.removals, ['cw2.string']);
      expect(plugin.values['legacy.large'], 'preserved');
      expect(
        plugin.reads.every(
          (keys) =>
              keys != null &&
              keys.length == 1 &&
              keys.single.startsWith('cw2.'),
        ),
        isTrue,
      );
      await expectLater(backend.read('legacy.large'), throwsArgumentError);
      expect(() => backend.write('legacy.large', 'bad'), throwsArgumentError);
    },
  );

  test(
    'native secure bridge scopes read/write/delete using plugin mock only',
    () async {
      FlutterSecureStorage.setMockInitialValues({'legacy.auth': 'untouched'});
      addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
      final backend = SecureEndpointCredentialBackend();
      final scope = EndpointCredentialScope(
        endpoint: Uri.parse('http://localhost:49374'),
        profileId: 'local',
      );
      final key = scope.key(EndpointCredentialKind.endpointPassword);
      await backend.write(key, 'disposable-password');
      expect(await backend.read(key), 'disposable-password');
      await backend.remove(key);
      expect(await backend.read(key), isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'legacy.auth'),
        'untouched',
      );
      expect(() => backend.write('legacy.auth', 'bad'), throwsArgumentError);
      expect(() => backend.remove('legacy.auth'), throwsArgumentError);
    },
  );
}
