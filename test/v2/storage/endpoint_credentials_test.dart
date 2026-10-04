import 'package:codewalk/platform/storage/endpoint_credentials.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fakes.dart';

Future<void> ready() async {}

EndpointCredentialScope scope(String url, [String profile = 'profile-a']) =>
    EndpointCredentialScope(endpoint: Uri.parse(url), profileId: profile);

void main() {
  const password = EndpointCredentialKind.endpointPassword;
  const token = EndpointCredentialKind.pairingToken;

  test(
    'origin normalization and profile/type scope prevent credential crossing',
    () async {
      final backend = FakeCredentialBackend()
        ..values['legacy.secret'] = 'v1-secret';
      final vault = EndpointCredentialVault(
        backend: backend,
        beforeMutation: ready,
      );
      final first = scope('https://EXAMPLE.com:443/api');
      await vault.write(first, password, 'endpoint-secret');
      expect(
        await vault.read(scope('https://example.com/other'), password),
        'endpoint-secret',
      );
      for (final other in [
        scope('http://example.com'),
        scope('https://example.com:49374'),
        scope('https://other.example'),
        scope('https://example.com', 'profile-b'),
      ]) {
        expect(await vault.read(other, password), isNull);
      }
      expect(await vault.read(first, token), isNull);
      await vault.write(first, token, 'pair-secret');
      await vault.remove(first, password);
      expect(await vault.read(first, token), 'pair-secret');
      expect(backend.values['legacy.secret'], 'v1-secret');
      expect(first.key(token), matches(r'^cw2\.auth\.[a-f0-9]{64}$'));
      expect(first.key(token), isNot(contains('example')));
      expect(first.key(token), isNot(contains('pair-secret')));
    },
  );

  for (final url in [
    'ftp://example.com',
    '/relative',
    'https://user:secret@example.com',
    'https://example.com?token=secret',
    'https://example.com#fragment',
    'http://example.com:0',
  ]) {
    test('rejects unsafe origin $url without disclosing URL', () {
      try {
        scope(url);
        fail('expected rejection');
      } on ArgumentError catch (error) {
        expect(error.toString(), isNot(contains('secret')));
      }
    });
  }

  test('IPv6 and tuple delimiters do not collide', () {
    expect(
      scope('http://[::1]:49374/api').origin.toString(),
      'http://[::1]:49374',
    );
    expect(
      scope('https://a', 'b:c').key(password),
      isNot(scope('https://a', 'b').key(token)),
    );
    expect(() => scope('https://a', ''), throwsArgumentError);
  });

  test('no-op and backend read/write/delete failures propagate', () async {
    final backend = FakeCredentialBackend();
    final vault = EndpointCredentialVault(
      backend: backend,
      beforeMutation: ready,
    );
    final target = scope('https://a');
    expect(await vault.remove(target, password), isFalse);
    expect(await vault.write(target, password, 'old'), isTrue);
    expect(await vault.write(target, password, 'old'), isFalse);
    expect(backend.writes, 1);
    backend.failWrite = true;
    await expectLater(vault.write(target, password, 'new'), throwsStateError);
    backend.failWrite = false;
    expect(await vault.read(target, password), 'old');
    backend.failRead = true;
    await expectLater(vault.read(target, password), throwsStateError);
    backend.failRead = false;
    backend.failRemove = true;
    await expectLater(vault.remove(target, password), throwsStateError);
    backend.failRemove = false;
    expect(await vault.read(target, password), 'old');
    await vault.flush();
  });

  test(
    'future schema blocks new credentials and delete without leaking to prefs',
    () async {
      final preferences = FakeMetadataBackend()..values['cw2.schema'] = 99;
      final metadata = V2MetadataStore(backend: preferences);
      final secrets = FakeCredentialBackend();
      final vault = EndpointCredentialVault(
        backend: secrets,
        beforeMutation: metadata.ensureSchema,
      );
      final target = scope('https://a');
      secrets.values[target.key(password)] = 'old';
      await expectLater(
        vault.write(target, password, 'new'),
        throwsA(isA<StorageSchemaException>()),
      );
      await expectLater(
        vault.remove(target, password),
        throwsA(isA<StorageSchemaException>()),
      );
      expect(secrets.values[target.key(password)], 'old');
      expect(preferences.values, {'cw2.schema': 99});
    },
  );

  test(
    'browser memory backend isolates instances and restricts namespace',
    () async {
      final first = MemoryEndpointCredentialBackend();
      final second = MemoryEndpointCredentialBackend();
      final key = scope('https://a').key(token);
      await first.write(key, 'memory-secret');
      expect(await first.read(key), 'memory-secret');
      expect(await second.read(key), isNull);
      await expectLater(first.write('legacy', 'secret'), throwsArgumentError);
      await first.remove(key);
      expect(await first.read(key), isNull);
    },
  );
}
