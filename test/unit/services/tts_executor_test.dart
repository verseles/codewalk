import 'dart:async';

import 'package:codewalk/core/auth/tts_api_key_storage.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:codewalk/presentation/services/tts/tts_executor.dart';
import 'package:flutter_test/flutter_test.dart';

class _KeyBackend implements TtsApiKeyStorageBackend {
  final Map<String, String> values = <String, String>{};
  Completer<void>? readGate;
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async {
    await readGate?.future;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _Backend implements TtsBackend {
  _Backend(this.provider);

  @override
  final ReadAloudProvider provider;
  final List<TtsSynthesisRequest> requests = <TtsSynthesisRequest>[];
  int stopCount = 0;
  Completer<void>? stopGate;

  @override
  Future<bool> get isAvailable async => true;
  @override
  TtsPlaybackMode get playbackMode => TtsPlaybackMode.nativeEngine;
  @override
  Future<List<String>> getLanguages() async => const <String>[];
  @override
  Future<List<TtsVoiceOption>> getVoices({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) async => const <TtsVoiceOption>[];
  @override
  Future<void> pause() async {}
  @override
  Future<TtsSynthesisResult> speakOrSynthesize(
    TtsSynthesisRequest request,
    TtsBackendCallbacks callbacks,
  ) async {
    requests.add(request);
    return const NativeTtsStarted();
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
    await stopGate?.future;
  }

  @override
  void dispose() {}
}

SpeechJob _job(TtsConfiguration configuration, String id) {
  return SpeechJob(
    jobId: id,
    snapshotId: 'snapshot-$id',
    textDigest: 'digest-$id',
    speechText: 'Speak $id',
    configurationRevision: configuration.revision,
    configuration: configuration,
  );
}

void main() {
  test('resolves cloud API key only inside the executor', () async {
    final keyBackend = _KeyBackend();
    final keyStorage = TtsApiKeyStorage(backend: keyBackend);
    await keyStorage.write(ReadAloudProvider.openAiCompatible, 'secret-key');
    final native = _Backend(ReadAloudProvider.native);
    final cloud = _Backend(ReadAloudProvider.openAiCompatible);
    final executor = TtsExecutor(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: native,
        ReadAloudProvider.openAiCompatible: cloud,
      },
      apiKeyStorage: keyStorage,
    );
    const configuration = TtsConfiguration(
      provider: ReadAloudProvider.openAiCompatible,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );

    await executor.play(_job(configuration, 'a'), const TtsBackendCallbacks());

    expect(cloud.requests.single.apiKey, 'secret-key');
  });

  test('resolves keys for ElevenLabs and NIM but not for Edge', () async {
    final keyBackend = _KeyBackend();
    final keyStorage = TtsApiKeyStorage(backend: keyBackend);
    await keyStorage.write(ReadAloudProvider.elevenLabs, 'xi-key');
    await keyStorage.write(ReadAloudProvider.nim, 'nv-key');
    final elevenLabs = _Backend(ReadAloudProvider.elevenLabs);
    final nim = _Backend(ReadAloudProvider.nim);
    final edge = _Backend(ReadAloudProvider.edgeExperimental);
    final executor = TtsExecutor(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.elevenLabs: elevenLabs,
        ReadAloudProvider.nim: nim,
        ReadAloudProvider.edgeExperimental: edge,
      },
      apiKeyStorage: keyStorage,
    );

    const elevenLabsConfig = TtsConfiguration(
      provider: ReadAloudProvider.elevenLabs,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );
    const nimConfig = TtsConfiguration(
      provider: ReadAloudProvider.nim,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );
    const edgeConfig = TtsConfiguration(
      provider: ReadAloudProvider.edgeExperimental,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );

    await executor.play(
      _job(elevenLabsConfig, 'xi'),
      const TtsBackendCallbacks(),
    );
    expect(elevenLabs.requests.single.apiKey, 'xi-key');

    await executor.play(_job(nimConfig, 'nv'), const TtsBackendCallbacks());
    expect(nim.requests.single.apiKey, 'nv-key');

    await executor.play(
      _job(edgeConfig, 'edge'),
      const TtsBackendCallbacks(),
    );
    expect(edge.requests.single.apiKey, isNull);
  });

  test('a new job stops the previous active backend', () async {
    final backend = _Backend(ReadAloudProvider.native);
    final executor = TtsExecutor(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: backend,
      },
    );
    const configuration = TtsConfiguration(
      provider: ReadAloudProvider.native,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );

    await executor.play(_job(configuration, 'a'), const TtsBackendCallbacks());
    await executor.play(_job(configuration, 'b'), const TtsBackendCallbacks());

    expect(backend.stopCount, 1);
    expect(executor.activeJob?.jobId, 'b');
  });

  test(
    'a replaced job cannot synthesize after delayed key resolution',
    () async {
      final keyBackend = _KeyBackend();
      final keyStorage = TtsApiKeyStorage(backend: keyBackend);
      await keyStorage.write(ReadAloudProvider.openAiCompatible, 'secret');
      keyBackend.readGate = Completer<void>();
      final native = _Backend(ReadAloudProvider.native);
      final cloud = _Backend(ReadAloudProvider.openAiCompatible);
      final executor = TtsExecutor(
        backends: <ReadAloudProvider, TtsBackend>{
          ReadAloudProvider.native: native,
          ReadAloudProvider.openAiCompatible: cloud,
        },
        apiKeyStorage: keyStorage,
      );
      const cloudConfiguration = TtsConfiguration(
        provider: ReadAloudProvider.openAiCompatible,
        rate: 0.5,
        pitch: 1,
        responseFormat: 'mp3',
      );
      const nativeConfiguration = TtsConfiguration(
        provider: ReadAloudProvider.native,
        rate: 0.5,
        pitch: 1,
        responseFormat: 'mp3',
      );
      final stale = executor.play(
        _job(cloudConfiguration, 'stale'),
        const TtsBackendCallbacks(),
      );
      await Future<void>.delayed(Duration.zero);

      final current = executor.play(
        _job(nativeConfiguration, 'current'),
        const TtsBackendCallbacks(),
      );
      keyBackend.readGate!.complete();

      await expectLater(stale, throwsA(isA<TtsBackendException>()));
      await current;
      expect(cloud.requests, isEmpty);
      expect(native.requests, hasLength(1));
    },
  );

  test('new synthesis waits for an in-flight backend stop', () async {
    final backend = _Backend(ReadAloudProvider.native);
    final executor = TtsExecutor(
      backends: <ReadAloudProvider, TtsBackend>{
        ReadAloudProvider.native: backend,
      },
    );
    const configuration = TtsConfiguration(
      provider: ReadAloudProvider.native,
      rate: 0.5,
      pitch: 1,
      responseFormat: 'mp3',
    );
    await executor.play(
      _job(configuration, 'first'),
      const TtsBackendCallbacks(),
    );
    backend.stopGate = Completer<void>();
    final stopping = executor.stop();
    final next = executor.play(
      _job(configuration, 'next'),
      const TtsBackendCallbacks(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.requests, hasLength(1));
    backend.stopGate!.complete();
    await stopping;
    await next;
    expect(backend.requests, hasLength(2));
  });

  test('configuration is derived without secrets from settings', () {
    final settings = ExperienceSettings.defaults().copyWith(
      readAloudProvider: ReadAloudProvider.edgeExperimental,
      readAloudRate: 0.8,
      readAloudVoiceId: () => 'voice-a',
    );

    final configuration = TtsConfiguration.fromSettings(settings);

    expect(configuration.provider, ReadAloudProvider.edgeExperimental);
    expect(configuration.rate, 0.8);
    expect(configuration.voiceId, 'voice-a');
  });
}
