@TestOn('vm')
library;

import 'package:codewalk/platform/migration/legacy_readers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native secure bridge reads the original exact key and never writes/deletes source',
    () async {
      const original = {
        'codewalk.secure::server_profile_basic_auth_password::srv':
            'disposable-password',
        'codewalk.secure::stt_api_key::openai': 'disposable-voice-key',
        'unrelated': 'preserved',
      };
      FlutterSecureStorage.setMockInitialValues(original);
      addTearDown(() => FlutterSecureStorage.setMockInitialValues({}));
      final reader = RawLegacySecureReader();
      expect(
        await reader.read(
          'codewalk.secure::server_profile_basic_auth_password::srv',
        ),
        'disposable-password',
      );
      expect(
        await reader.read('codewalk.secure::stt_api_key::openai'),
        'disposable-voice-key',
      );
      expect(await const FlutterSecureStorage().readAll(), original);
      await expectLater(
        reader.read('cw2.auth.unsupported'),
        throwsArgumentError,
      );
    },
  );
}
