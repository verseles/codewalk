import 'dart:async';

import 'package:codewalk/core/auth/stt_api_key_storage.dart';
import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/speech_audio_capture.dart';
import 'package:codewalk/presentation/services/speech_input_service_api.dart';
import 'package:codewalk/presentation/services/windows_microphone_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBackend implements SttApiKeyStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _Capture extends SpeechAudioCapture {
  _Capture(this.controller)
    : super(windowsMicrophoneService: _AllowedWindowsMicrophoneService());

  final StreamController<Uint8List> controller;
  int stopCount = 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async => controller.stream;

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _DelayedCapture extends SpeechAudioCapture {
  _DelayedCapture(this.stream)
    : super(windowsMicrophoneService: _AllowedWindowsMicrophoneService());

  final Stream<Uint8List> stream;
  final Completer<void> started = Completer<void>();
  int stopCount = 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> startPcmStream({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    await started.future;
    return stream;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _AllowedWindowsMicrophoneService extends WindowsMicrophoneService {
  @override
  Future<WindowsMicrophoneAccessStatus> probe() async =>
      WindowsMicrophoneAccessStatus.allowed;
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('encodes PCM16 as a valid mono 16 kHz WAV', () {
    final wav = encodePcm16Wav(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      sampleRate: 16000,
      channels: 1,
    );
    final data = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 16000);
    expect(data.getUint32(40, Endian.little), 4);
    expect(wav.sublist(44), <int>[1, 2, 3, 4]);
  });

  test(
    'requires keys for OpenAI and permits keyless custom endpoints',
    () async {
      final storage = SttApiKeyStorage(backend: _MemoryBackend());
      final service = ApiSpeechInputService(
        apiKeyStorage: storage,
        audioCapture: _Capture(StreamController<Uint8List>()),
      );
      service.configure(
        provider: SpeechApiProvider.openAi,
        baseUrl: kDefaultOpenAiSttBaseUrl,
        model: kDefaultOpenAiSttModel,
      );

      expect(await service.initialize(), isFalse);
      expect(service.unavailableReasonKey, 'apiKeyMissing');
      var startFailed = false;
      await service.startListening(
        onResult: (_, _) {},
        onStatus: (_) {},
        onError: () => startFailed = true,
      );
      expect(startFailed, isTrue);

      service.configure(
        provider: SpeechApiProvider.custom,
        baseUrl: 'http://localhost:8080/v1',
        model: 'whisper',
      );
      expect(await service.initialize(), isTrue);
    },
  );

  test('uploads WAV multipart and returns final transcription', () async {
    final backend = _MemoryBackend();
    final storage = SttApiKeyStorage(backend: backend);
    await storage.write(SpeechApiProvider.groq, 'secret');
    final controller = StreamController<Uint8List>();
    final capture = _Capture(controller);
    FormData? sentForm;
    RequestOptions? sentOptions;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            sentForm = options.data as FormData;
            sentOptions = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'text': 'hello world'},
              ),
            );
          },
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: storage,
      dio: dio,
      audioCapture: capture,
    );
    service.configure(
      provider: SpeechApiProvider.groq,
      baseUrl: kDefaultGroqSttBaseUrl,
      model: kDefaultGroqSttModel,
    );
    expect(await service.initialize(), isTrue);
    String? result;
    final statuses = <String>[];
    await service.startListening(
      onResult: (text, isFinal) => result = '$text:$isFinal',
      onStatus: statuses.add,
      onError: () => fail('unexpected error'),
      localeId: 'pt-BR',
    );
    controller.add(Uint8List.fromList(<int>[0, 10, 0, 10]));
    await Future<void>.delayed(Duration.zero);

    await service.stopListening();

    expect(result, 'hello world:true');
    expect(
      statuses,
      containsAllInOrder(<String>['listening', 'processing', 'done']),
    );
    expect(sentOptions?.path, '$kDefaultGroqSttBaseUrl/audio/transcriptions');
    expect(sentOptions?.headers['Authorization'], 'Bearer secret');
    expect(
      sentForm?.fields.where((entry) => entry.key == 'model').single.value,
      kDefaultGroqSttModel,
    );
    expect(
      sentForm?.fields.where((entry) => entry.key == 'language').single.value,
      'pt',
    );
    expect(sentForm?.files.single.value.filename, 'speech.wav');
    expect(sentForm?.files.single.value.contentType.toString(), 'audio/wav');
    expect(capture.stopCount, 1);
    await controller.close();
  });

  test('maps rejected credentials without exposing response details', () async {
    final storage = SttApiKeyStorage(backend: _MemoryBackend());
    await storage.write(SpeechApiProvider.openAi, 'secret');
    final controller = StreamController<Uint8List>();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 401,
                data: 'secret provider body',
              ),
            ),
          ),
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: storage,
      dio: dio,
      audioCapture: _Capture(controller),
    );
    service.configure(
      provider: SpeechApiProvider.openAi,
      baseUrl: kDefaultOpenAiSttBaseUrl,
      model: kDefaultOpenAiSttModel,
    );
    await service.initialize();
    var failed = false;
    await service.startListening(
      onResult: (_, _) {},
      onStatus: (_) {},
      onError: () => failed = true,
    );
    controller.add(Uint8List.fromList(<int>[1, 2]));
    await Future<void>.delayed(Duration.zero);

    await service.stopListening();

    expect(failed, isTrue);
    expect(service.unavailableReasonKey, 'apiKeyRejected');
    expect(service.unavailableReason, isNot(contains('secret provider body')));
    await controller.close();
  });

  test('does not upload silence-only capture', () async {
    final storage = SttApiKeyStorage(backend: _MemoryBackend());
    final controller = StreamController<Uint8List>();
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.next(options);
          },
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: storage,
      dio: dio,
      audioCapture: _Capture(controller),
    );
    service.configure(
      provider: SpeechApiProvider.custom,
      baseUrl: 'http://localhost:8080/v1',
      model: 'whisper',
    );
    await service.initialize();
    var failed = false;
    await service.startListening(
      onResult: (_, _) => fail('unexpected result'),
      onStatus: (_) {},
      onError: () => failed = true,
    );
    controller.add(Uint8List.fromList(<int>[0, 0, 1, 0]));
    await Future<void>.delayed(Duration.zero);

    await service.stopListening();

    expect(failed, isTrue);
    expect(service.unavailableReasonKey, 'emptyAudio');
    expect(requests, 0);
    await controller.close();
  });

  test('rejects insecure remote custom endpoints before capture', () async {
    final service = ApiSpeechInputService(
      apiKeyStorage: SttApiKeyStorage(backend: _MemoryBackend()),
      audioCapture: _Capture(StreamController<Uint8List>()),
    );
    service.configure(
      provider: SpeechApiProvider.custom,
      baseUrl: 'http://remote.example/v1',
      model: 'whisper',
    );

    expect(await service.initialize(), isFalse);
    expect(service.unavailableReasonKey, 'apiConfigInvalid');
  });

  test('presets ignore persisted custom base URLs', () async {
    final storage = SttApiKeyStorage(backend: _MemoryBackend());
    await storage.write(SpeechApiProvider.openAi, 'secret');
    final controller = StreamController<Uint8List>();
    String? requestedPath;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedPath = options.path;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{'text': 'safe'},
              ),
            );
          },
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: storage,
      dio: dio,
      audioCapture: _Capture(controller),
    );
    service.configure(
      provider: SpeechApiProvider.openAi,
      baseUrl: 'https://attacker.example/v1',
      model: kDefaultOpenAiSttModel,
    );
    await service.initialize();
    await service.startListening(
      onResult: (_, _) {},
      onStatus: (_) {},
      onError: () => fail('unexpected error'),
    );
    controller.add(Uint8List.fromList(<int>[0, 10]));
    await Future<void>.delayed(Duration.zero);

    await service.stopListening();

    expect(requestedPath, '$kDefaultOpenAiSttBaseUrl/audio/transcriptions');
    await controller.close();
  });

  test(
    'capture error followed by done finalizes once without upload',
    () async {
      final controller = StreamController<Uint8List>();
      final capture = _Capture(controller);
      var requests = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests++;
              handler.next(options);
            },
          ),
        );
      final service = ApiSpeechInputService(
        apiKeyStorage: SttApiKeyStorage(backend: _MemoryBackend()),
        dio: dio,
        audioCapture: capture,
      );
      service.configure(
        provider: SpeechApiProvider.custom,
        baseUrl: 'http://localhost:8080/v1',
        model: 'whisper',
      );
      await service.initialize();
      var errors = 0;
      await service.startListening(
        onResult: (_, _) => fail('unexpected result'),
        onStatus: (_) {},
        onError: () => errors++,
      );
      controller.add(Uint8List.fromList(<int>[0, 10]));
      controller.addError(StateError('capture failed'));
      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(errors, 1);
      expect(requests, 0);
      expect(capture.stopCount, 1);
    },
  );

  test('restart during upload cannot replace the active callbacks', () async {
    final storage = SttApiKeyStorage(backend: _MemoryBackend());
    final controller = StreamController<Uint8List>();
    final response = Completer<Response<dynamic>>();
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final resolved = await response.future;
            handler.resolve(resolved);
          },
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: storage,
      dio: dio,
      audioCapture: _Capture(controller),
    );
    service.configure(
      provider: SpeechApiProvider.custom,
      baseUrl: 'http://localhost:8080/v1',
      model: 'whisper',
    );
    await service.initialize();
    String? firstResult;
    var secondErrors = 0;
    await service.startListening(
      onResult: (text, _) => firstResult = text,
      onStatus: (_) {},
      onError: () => fail('unexpected first error'),
    );
    controller.add(Uint8List.fromList(<int>[0, 10]));
    await Future<void>.delayed(Duration.zero);
    final stop = service.stopListening();
    await Future<void>.delayed(Duration.zero);
    expect(service.isListening, isTrue);

    await service.startListening(
      onResult: (_, _) => fail('unexpected second result'),
      onStatus: (_) {},
      onError: () => secondErrors++,
    );
    response.complete(
      Response<dynamic>(
        requestOptions: RequestOptions(path: 'test'),
        statusCode: 200,
        data: <String, dynamic>{'text': 'first session'},
      ),
    );
    await stop;

    expect(secondErrors, 1);
    expect(firstResult, 'first session');
    expect(service.isListening, isFalse);
    await controller.close();
  });

  test('cancel stops capture and discards audio without upload', () async {
    final controller = StreamController<Uint8List>();
    final capture = _Capture(controller);
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.next(options);
          },
        ),
      );
    final service = ApiSpeechInputService(
      apiKeyStorage: SttApiKeyStorage(backend: _MemoryBackend()),
      dio: dio,
      audioCapture: capture,
    );
    service.configure(
      provider: SpeechApiProvider.custom,
      baseUrl: 'http://localhost:8080/v1',
      model: 'whisper',
    );
    await service.initialize();
    var callbacks = 0;
    await service.startListening(
      onResult: (_, _) => callbacks++,
      onStatus: (_) {},
      onError: () => callbacks++,
    );
    controller.add(Uint8List.fromList(<int>[0, 10]));
    await Future<void>.delayed(Duration.zero);

    await service.cancelSession();

    expect(requests, 0);
    expect(callbacks, 0);
    expect(capture.stopCount, 1);
    expect(service.isListening, isFalse);
    await controller.close();
  });

  test(
    'cancel during startup blocks restart until stale capture settles',
    () async {
      final controller = StreamController<Uint8List>();
      final capture = _DelayedCapture(controller.stream);
      final service = ApiSpeechInputService(
        apiKeyStorage: SttApiKeyStorage(backend: _MemoryBackend()),
        audioCapture: capture,
      );
      service.configure(
        provider: SpeechApiProvider.custom,
        baseUrl: 'http://localhost:8080/v1',
        model: 'whisper',
      );
      await service.initialize();
      var callbacks = 0;
      final start = service.startListening(
        onResult: (_, _) => callbacks++,
        onStatus: (_) => callbacks++,
        onError: () => callbacks++,
      );

      await service.cancelSession();
      var restartErrors = 0;
      await service.startListening(
        onResult: (_, _) => callbacks++,
        onStatus: (_) => callbacks++,
        onError: () => restartErrors++,
      );
      expect(restartErrors, 1);

      capture.started.complete();
      await start;

      expect(callbacks, 0);
      expect(service.isListening, isFalse);
      expect(capture.stopCount, 2);
      unawaited(controller.close());
    },
  );
}
