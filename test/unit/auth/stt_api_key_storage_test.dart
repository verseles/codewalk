import 'package:codewalk/core/auth/stt_api_key_storage.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements SttApiKeyStorageBackend {
  final Map<String, String> values = <String, String>{};
  bool fail = false;

  @override
  Future<void> write({required String key, required String value}) async {
    if (fail) throw StateError('unavailable');
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    if (fail) throw StateError('unavailable');
    return values[key];
  }

  @override
  Future<void> delete({required String key}) async {
    if (fail) throw StateError('unavailable');
    values.remove(key);
  }
}

void main() {
  test('stores STT keys separately by API provider', () async {
    final backend = _FakeBackend();
    final storage = SttApiKeyStorage(backend: backend);

    await storage.write(SpeechApiProvider.openAi, ' openai-secret ');
    await storage.write(SpeechApiProvider.groq, 'groq-secret');

    expect(await storage.read(SpeechApiProvider.openAi), 'openai-secret');
    expect(await storage.read(SpeechApiProvider.groq), 'groq-secret');
    expect(await storage.read(SpeechApiProvider.custom), isNull);
    expect(backend.values.keys, everyElement(contains('stt_api_key')));
  });

  test('empty writes remove only the selected provider key', () async {
    final backend = _FakeBackend();
    final storage = SttApiKeyStorage(backend: backend);
    await storage.write(SpeechApiProvider.openAi, 'one');
    await storage.write(SpeechApiProvider.groq, 'two');

    await storage.write(SpeechApiProvider.openAi, ' ');

    expect(await storage.read(SpeechApiProvider.openAi), isNull);
    expect(await storage.read(SpeechApiProvider.groq), 'two');
  });

  test('fails closed when secure storage is unavailable', () async {
    final storage = SttApiKeyStorage(backend: _FakeBackend()..fail = true);

    expect(
      () => storage.read(SpeechApiProvider.openAi),
      throwsA(isA<SttApiKeyStorageException>()),
    );
    expect(
      () => storage.write(SpeechApiProvider.openAi, 'secret'),
      throwsA(isA<SttApiKeyStorageException>()),
    );
  });
}
