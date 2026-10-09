import 'dart:convert';

import 'package:codewalk/platform/profiles/endpoint_profile_store.dart';
import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/platform/storage/preferences_backend.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class Metadata implements MetadataBackend {
  final values = <String, Object>{};
  String? failWrite;
  bool failAfterWrite = false;
  String? failRemove;
  bool failIndexReadAfterWrite = false;
  bool indexReadsUnavailable = false;
  @override
  Future<Object?> read(String key) async {
    if (indexReadsUnavailable && key == EndpointProfileStore.indexKey) {
      throw StateError('controlled index read failure');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, Object value) async {
    if (failWrite == key && !failAfterWrite) {
      throw StateError('controlled write failure');
    }
    values[key] = value;
    if (failWrite == key && failAfterWrite) {
      if (failIndexReadAfterWrite) indexReadsUnavailable = true;
      throw StateError('controlled post-write failure');
    }
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove == key) throw StateError('controlled removal failure');
    values.remove(key);
  }
}

class Secrets implements EndpointCredentialBackend {
  final values = <String, String>{};
  bool failRemove = false;
  bool failAfterWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    if (failAfterWrite) throw StateError('controlled post-vault-write failure');
  }

  @override
  Future<void> remove(String key) async {
    if (failRemove) throw StateError('controlled vault removal failure');
    values.remove(key);
  }
}

void main() {
  late Metadata backend;
  late Secrets secrets;
  late EndpointProfileStore store;
  EndpointProfile profile(String id, [int port = 4096]) => EndpointProfile(
    id: id,
    label: 'Server',
    endpoint: Uri.parse('http://127.0.0.1:$port/proxy/'),
  );
  EndpointProfileStore openStore(MetadataBackend backend) {
    final metadata = V2MetadataStore(backend: backend);
    return EndpointProfileStore(
      metadata: metadata,
      credentials: EndpointCredentialVault(
        backend: secrets,
        beforeMutation: metadata.ensureSchema,
      ),
    );
  }

  setUp(() {
    backend = Metadata();
    secrets = Secrets();
    store = openStore(backend);
  });

  test(
    'paired credential survives restart without secrets in metadata',
    () async {
      final credential = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'fake-paired-secret',
        expiresAt: DateTime.utc(2026, 11),
      );
      await store.saveCredential(profile('endpoint_one'), credential);
      final reopened = openStore(backend);
      expect(
        (await reopened.readCredential(
          profile('endpoint_one'),
        ))!.matches(credential),
        isTrue,
      );
      expect(
        await reopened.readSecret(profile('endpoint_one')),
        'fake-paired-secret',
      );
      expect(
        backend.values.values.join(),
        isNot(contains('fake-paired-secret')),
      );
      await reopened.remove(profile('endpoint_one'));
      expect(secrets.values, isEmpty);
    },
  );

  test(
    'repair and failed post-write reconciliation retain the same profile and other credentials',
    () async {
      await store.save(profile('endpoint_one'), 'fake-old');
      await store.save(profile('endpoint_two'), 'fake-other');
      final old = (await store.readCredential(profile('endpoint_one')))!;
      final paired = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'fake-new',
      );
      secrets.failAfterWrite = true;
      await store.replaceCredential(
        profile('endpoint_one'),
        paired,
        expected: old,
      );
      expect((await store.load()).map((p) => p.id), [
        'endpoint_one',
        'endpoint_two',
      ]);
      expect(
        (await store.readCredential(profile('endpoint_one')))!.matches(paired),
        isTrue,
      );
      expect(await store.readSecret(profile('endpoint_two')), 'fake-other');
      await expectLater(
        store.replaceCredential(profile('endpoint_one'), old, expected: old),
        throwsFormatException,
      );
      expect(await store.readSecret(profile('endpoint_one')), 'fake-new');
    },
  );

  test(
    'present corrupt or future active record never falls back to the previous password',
    () async {
      await store.save(profile('endpoint_one'), 'fake-old');
      final scope = EndpointCredentialScope(
        endpoint: profile('endpoint_one').endpoint,
        profileId: 'endpoint_one',
      );
      for (final raw in [
        'broken JSON',
        jsonEncode({'version': 99, 'kind': 'paired', 'secret': 'fake-future'}),
      ]) {
        secrets.values[scope.key(EndpointCredentialKind.activeCredential)] =
            raw;
        final before = Map.of(secrets.values);
        await expectLater(
          store.readSecret(profile('endpoint_one')),
          throwsFormatException,
        );
        await expectLater(
          store.replaceCredential(
            profile('endpoint_one'),
            EndpointCredential(
              kind: EndpointAuthKind.password,
              secret: 'fake-repair',
            ),
            expected: null,
          ),
          throwsFormatException,
        );
        expect(secrets.values, before);
        expect((await store.load()).single.id, 'endpoint_one');
      }
    },
  );

  test(
    'catalog persists profiles and ports, but no password in metadata',
    () async {
      backend.values['cw2.profiles.legacy-record'] = 'owned importer record';
      await store.save(profile('endpoint_one'), 'fake-test-secret');
      final loaded = await store.load();
      expect(loaded.single.endpoint.port, 4096);
      expect(await store.readSecret(loaded.single), 'fake-test-secret');
      expect(backend.values.values.join(), isNot(contains('fake-test-secret')));
      expect(
        backend.values['cw2.profiles.legacy-record'],
        'owned importer record',
      );
      expect(await store.readSecret(profile('endpoint_one', 49374)), isNull);
      await store.remove(loaded.single);
      expect(await store.load(), isEmpty);
      expect(secrets.values, isEmpty);
    },
  );

  test('failed index commit rolls back only the newly owned records', () async {
    await store.save(profile('endpoint_old'), 'fake-old-secret');
    backend.failWrite = EndpointProfileStore.indexKey;
    await expectLater(
      store.save(profile('endpoint_new'), 'fake-new-secret'),
      throwsStateError,
    );
    expect((await store.load()).single.id, 'endpoint_old');
    expect(await store.readSecret(profile('endpoint_old')), 'fake-old-secret');
    expect(
      backend.values.containsKey(EndpointProfileStore.itemKey('endpoint_new')),
      isFalse,
    );
    expect(secrets.values.values, ['fake-old-secret']);
  });

  test(
    'post-write failure reconciles visible commit without deleting its credential',
    () async {
      backend.failWrite = EndpointProfileStore.indexKey;
      backend.failAfterWrite = true;
      await store.save(profile('endpoint_one'), 'fake-test-secret');
      expect((await store.load()).single.id, 'endpoint_one');
      expect(
        await store.readSecret(profile('endpoint_one')),
        'fake-test-secret',
      );
    },
  );

  test(
    'corrupt index and future schema stay intact and block new mutation',
    () async {
      backend.values[EndpointProfileStore.indexKey] = 'not a catalog';
      await expectLater(
        store.save(profile('endpoint_one'), 'fake-test-secret'),
        throwsFormatException,
      );
      expect(backend.values[EndpointProfileStore.indexKey], 'not a catalog');
      expect(secrets.values, isEmpty);
      backend.values.remove(EndpointProfileStore.indexKey);
      backend.values['cw2.schema'] = 99;
      await expectLater(
        store.save(profile('endpoint_one'), 'fake-test-secret'),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(backend.values['cw2.schema'], 99);
      expect(secrets.values, isEmpty);
    },
  );

  test(
    'concurrent authored profiles are serialized without lost catalog entries',
    () async {
      await Future.wait([
        store.save(profile('endpoint_one'), 'fake-one'),
        store.save(profile('endpoint_two', 49374), 'fake-two'),
      ]);
      expect((await store.load()).map((p) => p.id), [
        'endpoint_one',
        'endpoint_two',
      ]);
    },
  );

  for (final encodedIndex in ['["endpoint_one"]', '[]']) {
    test(
      'Linux JSON reload accepts catalog $encodedIndex without rewriting',
      () async {
        final original = SharedPreferencesAsyncPlatform.instance;
        addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'cw2.schema': 1,
              EndpointProfileStore.indexKey: jsonDecode(encodedIndex) as Object,
              EndpointProfileStore.itemKey('endpoint_one'): jsonEncode({
                'id': 'endpoint_one',
                'label': 'Saved server',
                'url': 'http://127.0.0.1:4096/proxy/',
              }),
              'legacy.unchanged': 'preserve legacy preferences',
            });
        final preferences = SharedPreferencesAsync();
        final before = await preferences.getAll();
        expect(
          before[EndpointProfileStore.indexKey],
          isNot(isA<List<String>>()),
        );
        final reopened = openStore(
          PreferencesMetadataBackend(preferences: preferences),
        );
        final profiles = await reopened.load();
        expect(profiles.map((p) => p.id), jsonDecode(encodedIndex));
        if (profiles.isNotEmpty) expect(profiles.single.endpoint.port, 4096);
        expect(await preferences.getAll(), before);
      },
    );
  }

  for (final encodedIndex in ['["endpoint_one",7]', '["endpoint_one",null]']) {
    test('Linux JSON corrupt catalog $encodedIndex stays intact', () async {
      final original = SharedPreferencesAsyncPlatform.instance;
      addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'cw2.schema': 1,
            EndpointProfileStore.indexKey: jsonDecode(encodedIndex) as Object,
          });
      final preferences = SharedPreferencesAsync();
      final before = await preferences.getAll();
      final reopened = openStore(
        PreferencesMetadataBackend(preferences: preferences),
      );
      await expectLater(reopened.load(), throwsFormatException);
      await expectLater(
        reopened.save(profile('endpoint_new'), 'fake-new-secret'),
        throwsFormatException,
      );
      expect(await preferences.getAll(), before);
      expect(secrets.values, isEmpty);
    });
  }

  for (final failure in ['index', 'secret', 'item', 'intent']) {
    test(
      'restart retries only the requested deletion after $failure failure',
      () async {
        await store.save(profile('endpoint_one'), 'fake-one');
        await store.save(profile('endpoint_two', 49374), 'fake-two');
        secrets.values['legacy.unchanged'] = 'fake-legacy';
        switch (failure) {
          case 'index':
            backend.failWrite = EndpointProfileStore.indexKey;
          case 'secret':
            secrets.failRemove = true;
          case 'item':
            backend.failRemove = EndpointProfileStore.itemKey('endpoint_one');
          case 'intent':
            backend.failRemove = EndpointProfileStore.removalKey;
        }
        await expectLater(
          store.remove(profile('endpoint_one')),
          throwsStateError,
        );
        expect(backend.values[EndpointProfileStore.removalKey], isNotNull);
        expect(backend.values.values.join(), isNot(contains('fake-one')));
        backend.failWrite = null;
        backend.failRemove = null;
        secrets.failRemove = false;
        final reopened = openStore(backend);
        expect((await reopened.load()).single.id, 'endpoint_two');
        expect(
          await reopened.readSecret(profile('endpoint_two', 49374)),
          'fake-two',
        );
        expect(secrets.values.values, containsAll(['fake-two', 'fake-legacy']));
        expect(secrets.values.values, isNot(contains('fake-one')));
        expect(
          backend.values[EndpointProfileStore.itemKey('endpoint_one')],
          isNull,
        );
        expect(backend.values[EndpointProfileStore.removalKey], isNull);
      },
    );
  }

  test(
    'pending deletion preserves corrupt catalog, future schema and changed origin',
    () async {
      await store.save(profile('endpoint_one'), 'fake-one');
      secrets.failRemove = true;
      await expectLater(
        store.remove(profile('endpoint_one')),
        throwsStateError,
      );
      secrets.failRemove = false;
      backend.values['cw2.schema'] = 99;
      var before = Map.of(backend.values);
      await expectLater(
        openStore(backend).load(),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(backend.values, before);
      expect(secrets.values.values, ['fake-one']);

      backend.values['cw2.schema'] = 1;
      backend.values[EndpointProfileStore.indexKey] = 'corrupt catalog';
      before = Map.of(backend.values);
      await expectLater(openStore(backend).load(), throwsFormatException);
      expect(backend.values, before);
      expect(secrets.values.values, ['fake-one']);

      backend.values[EndpointProfileStore.indexKey] = <String>[];
      backend.values[EndpointProfileStore.itemKey(
        'endpoint_one',
      )] = jsonEncode({
        'id': 'endpoint_one',
        'label': 'Changed origin',
        'url': 'http://127.0.0.1:49374/',
      });
      before = Map.of(backend.values);
      await expectLater(openStore(backend).load(), throwsFormatException);
      expect(backend.values, before);
      expect(secrets.values.values, ['fake-one']);
    },
  );

  test('persisted secret whose write reports failure is rolled back', () async {
    await store.save(profile('endpoint_old'), 'fake-old');
    secrets.failAfterWrite = true;
    await expectLater(
      store.save(profile('endpoint_new'), 'fake-new'),
      throwsStateError,
    );
    expect((await store.load()).single.id, 'endpoint_old');
    expect(secrets.values.values, ['fake-old']);
    expect(
      backend.values[EndpointProfileStore.itemKey('endpoint_new')],
      isNull,
    );
    expect(backend.values[EndpointProfileStore.creationKey], isNull);
  });

  test(
    'failed secret rollback retains intent for targeted restart cleanup',
    () async {
      await store.save(profile('endpoint_old'), 'fake-old');
      secrets.failAfterWrite = true;
      secrets.failRemove = true;
      await expectLater(
        store.save(profile('endpoint_new'), 'fake-new'),
        throwsStateError,
      );
      expect(backend.values[EndpointProfileStore.creationKey], isNotNull);
      expect(backend.values.values.join(), isNot(contains('fake-new')));
      expect(secrets.values.values, containsAll(['fake-old', 'fake-new']));
      secrets.failRemove = false;
      secrets.failAfterWrite = false;
      expect((await openStore(backend).load()).single.id, 'endpoint_old');
      expect(secrets.values.values, ['fake-old']);
      expect(backend.values[EndpointProfileStore.creationKey], isNull);
    },
  );

  test(
    'index publish then failed confirmation is reconciled on restart without deleting secret',
    () async {
      backend.failWrite = EndpointProfileStore.indexKey;
      backend.failAfterWrite = true;
      backend.failIndexReadAfterWrite = true;
      await expectLater(
        store.save(profile('endpoint_one'), 'fake-one'),
        throwsStateError,
      );
      expect(backend.values[EndpointProfileStore.creationKey], isNotNull);
      expect(secrets.values.values, ['fake-one']);
      backend.indexReadsUnavailable = false;
      final reopened = openStore(backend);
      expect((await reopened.load()).single.id, 'endpoint_one');
      expect(await reopened.readSecret(profile('endpoint_one')), 'fake-one');
      expect(backend.values[EndpointProfileStore.creationKey], isNull);
    },
  );

  test(
    'pending creation never bypasses future schema or changed identity',
    () async {
      secrets.failAfterWrite = true;
      secrets.failRemove = true;
      await expectLater(
        store.save(profile('endpoint_one'), 'fake-one'),
        throwsStateError,
      );
      secrets.failRemove = false;
      backend.values['cw2.schema'] = 99;
      var before = Map.of(backend.values);
      await expectLater(
        openStore(backend).load(),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(backend.values, before);
      expect(secrets.values.values, ['fake-one']);
      backend.values['cw2.schema'] = 1;
      backend.values[EndpointProfileStore.itemKey(
        'endpoint_one',
      )] = jsonEncode({
        'id': 'endpoint_one',
        'label': 'Changed server',
        'url': 'http://127.0.0.1:49374/',
      });
      before = Map.of(backend.values);
      await expectLater(openStore(backend).load(), throwsFormatException);
      expect(backend.values, before);
      expect(secrets.values.values, ['fake-one']);
    },
  );
}
