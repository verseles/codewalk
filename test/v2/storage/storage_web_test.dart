import 'package:codewalk/platform/storage/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'storage_fakes.dart';

void main() {
  test(
    'Web factory persists only capped v2 metadata, credentials stay in memory',
    () async {
      // VM runs validate the portable memory backend; Chrome additionally proves
      // the actual conditional factories compile and select the Web adapters.
      final backend = FakeMetadataBackend()..values['legacy.flag'] = false;
      final metadata = V2MetadataStore(backend: backend);
      final credentials = kIsWeb
          ? createV2EndpointCredentials(metadata)
          : EndpointCredentialVault(
              backend: MemoryEndpointCredentialBackend(),
              beforeMutation: metadata.ensureSchema,
            );
      final endpoint = EndpointCredentialScope(
        endpoint: Uri.parse('https://example.com:49374/api'),
        profileId: 'profile',
      );
      await credentials.write(
        endpoint,
        EndpointCredentialKind.pairingToken,
        'browser-memory-secret',
      );
      expect(
        await credentials.read(endpoint, EndpointCredentialKind.pairingToken),
        'browser-memory-secret',
      );
      final fresh = kIsWeb
          ? createV2EndpointCredentials(metadata)
          : EndpointCredentialVault(
              backend: MemoryEndpointCredentialBackend(),
              beforeMutation: metadata.ensureSchema,
            );
      expect(
        await fresh.read(endpoint, EndpointCredentialKind.pairingToken),
        isNull,
      );
      expect(backend.values, {'legacy.flag': false, 'cw2.schema': 1});
      expect(backend.values.values, isNot(contains('browser-memory-secret')));
      if (kIsWeb) {
        final payload = createV2PayloadStore(metadata);
        expect(payload, isA<PreferencesPayloadStore>());
        await payload.writeJson('cw2.web.payload', {'text': 'browser'});
        expect(await payload.readJson('cw2.web.payload'), {'text': 'browser'});
      }
    },
  );
}
