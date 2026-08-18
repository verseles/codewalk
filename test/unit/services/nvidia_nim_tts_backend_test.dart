import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/tts/nvidia_nim_tts_backend.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockDioAdapter implements HttpClientAdapter {
  final List<ResponseBody> responses = <ResponseBody>[];
  final List<RequestOptions> capturedRequests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    if (responses.isEmpty) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(int status, String body) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

ResponseBody _wavBody(int status, List<int> bytes) {
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['audio/wav'],
    },
  );
}

const List<int> _kMinimalWav = <int>[
  0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
  0x01, 0x02, 0x03, 0x04,
];

const TtsBackendCallbacks _callbacks = TtsBackendCallbacks();

void main() {
  group('NvidiaNimTtsBackend', () {
    test('exposes provider and generated-audio playback mode', () {
      final backend = NvidiaNimTtsBackend();
      expect(backend.provider, ReadAloudProvider.nim);
      expect(backend.playbackMode, TtsPlaybackMode.generatedAudio);
    });

    test('throws missing key before making any request', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            baseUrl: 'https://ai.api.nvidia.com/v1',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.missingApiKey,
          ),
        ),
      );
      expect(adapter.capturedRequests, isEmpty);
    });

    test('requires a non-empty base URL and voice', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'nv-test',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.invalidRequest,
          ),
        ),
      );
      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'nv-test',
            baseUrl: 'https://ai.api.nvidia.com/v1',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.invalidRequest,
          ),
        ),
      );
      expect(adapter.capturedRequests, isEmpty);
    });

    test('rejects text over the model character limit before HTTP', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 501,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'nv-test',
            baseUrl: 'https://ai.api.nvidia.com/v1',
            voiceId: 'voice-a',
            model: 'chatterbox-tts-multilingual:1.1.0',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.invalidRequest,
          ),
        ),
      );
      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 2001,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'nv-test',
            baseUrl: 'https://ai.api.nvidia.com/v1',
            voiceId: 'voice-a',
            model: 'magpie-tts-multilingual:1.10.0',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.invalidRequest,
          ),
        ),
      );
      expect(adapter.capturedRequests, isEmpty);
    });

    test('posts a multipart synthesize request and returns wav audio', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_wavBody(200, _kMinimalWav));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      final result = await backend.speakOrSynthesize(
        const TtsSynthesisRequest(
          text: 'Hello world',
          rate: 0.5,
          pitch: 1.0,
          apiKey: 'nv-test',
          baseUrl: 'https://ai.api.nvidia.com/v1///',
          model: 'magpie-tts-multilingual:1.10.0',
          voiceId: 'voice-a',
          voiceLocale: 'pt-BR',
        ),
        _callbacks,
      );

      expect(result, isA<GeneratedTtsAudio>());
      final audio = result as GeneratedTtsAudio;
      expect(audio.bytes, orderedEquals(_kMinimalWav));
      expect(audio.mimeType, 'audio/wav');

      final request = adapter.capturedRequests.single;
      expect(
        request.uri.toString(),
        'https://ai.api.nvidia.com/v1/audio/synthesize',
      );
      expect(request.headers['Authorization'], 'Bearer nv-test');
      final form = request.data as FormData;
      expect(form.fields.any((f) => f.key == 'text' && f.value == 'Hello world'),
          isTrue);
      expect(form.fields.any((f) => f.key == 'voice' && f.value == 'voice-a'),
          isTrue);
      expect(form.fields.any((f) => f.key == 'language' && f.value == 'pt-br'),
          isTrue);
      expect(
        form.fields.any(
          (f) => f.key == 'model' && f.value == 'magpie-tts-multilingual:1.10.0',
        ),
        isTrue,
      );
    });

    test('defaults language to en when no voice locale is present', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_wavBody(200, _kMinimalWav));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      await backend.speakOrSynthesize(
        const TtsSynthesisRequest(
          text: 'Hello',
          rate: 0.5,
          pitch: 1.0,
          apiKey: 'nv-test',
          baseUrl: 'https://ai.api.nvidia.com/v1',
          voiceId: 'voice-a',
        ),
        _callbacks,
      );

      final form = adapter.capturedRequests.single.data as FormData;
      expect(
        form.fields.any((f) => f.key == 'language' && f.value == 'en'),
        isTrue,
      );
    });

    test('maps provider status errors', () async {
      final adapter = _MockDioAdapter()
        ..responses.addAll(<ResponseBody>[
          _jsonBody(400, '{"detail":"Bad request"}'),
          _jsonBody(401, '{"detail":"Unauthorized"}'),
          _jsonBody(404, '{"detail":"Not found"}'),
          _jsonBody(429, '{"detail":"Quota exceeded"}'),
          _jsonBody(503, '{"detail":"Unavailable"}'),
        ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      Future<TtsBackendException> failOnce() async {
        try {
          await backend.speakOrSynthesize(
            const TtsSynthesisRequest(
              text: 'Hello',
              rate: 0.5,
              pitch: 1.0,
              apiKey: 'nv-test',
              baseUrl: 'https://ai.api.nvidia.com/v1',
              voiceId: 'voice-a',
            ),
            _callbacks,
          );
        } on TtsBackendException catch (error) {
          return error;
        }
        fail('Expected TtsBackendException');
      }

      expect((await failOnce()).kind, TtsBackendErrorKind.invalidRequest);
      expect((await failOnce()).kind, TtsBackendErrorKind.invalidApiKey);
      expect((await failOnce()).kind, TtsBackendErrorKind.invalidRequest);
      expect((await failOnce()).kind, TtsBackendErrorKind.rateLimitedOrQuota);
      expect((await failOnce()).kind, TtsBackendErrorKind.providerUnavailable);
    });

    test('rejects non-wav audio as providerUnavailable', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_wavBody(200, <int>[1, 2, 3]));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = NvidiaNimTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'nv-test',
            baseUrl: 'https://ai.api.nvidia.com/v1',
            voiceId: 'voice-a',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.providerUnavailable,
          ),
        ),
      );
    });

    group('getVoices', () {
      test('returns empty list without key or base URL', () async {
        final adapter = _MockDioAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = NvidiaNimTtsBackend(dio: dio);

        expect(await backend.getVoices(apiKey: null, baseUrl: null), isEmpty);
        expect(await backend.getVoices(apiKey: 'nv-test', baseUrl: ''), isEmpty);
        expect(adapter.capturedRequests, isEmpty);
      });

      test('parses a plain list response', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(
            _jsonBody(
              200,
              '[{"voice_id":"v1","name":"Aria","language":"pt-BR"},'
              '{"voice_id":"v2","name":"Roger"}]',
            ),
          );
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = NvidiaNimTtsBackend(dio: dio);

        final voices = await backend.getVoices(
          apiKey: 'nv-test',
          baseUrl: 'https://ai.api.nvidia.com/v1',
        );

        expect(voices, hasLength(2));
        expect(voices[0].id, 'v1');
        expect(voices[0].label, 'Aria');
        expect(voices[0].locale, 'pt-BR');
        expect(
          adapter.capturedRequests.single.uri.toString(),
          'https://ai.api.nvidia.com/v1/audio/list_voices',
        );
        expect(
          adapter.capturedRequests.single.headers['Authorization'],
          'Bearer nv-test',
        );
      });

      test('parses wrapped and map-shaped responses', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(
            _jsonBody(
              200,
              '{"voices":[{"voice_id":"v1","name":"Aria"}]}',
            ),
          )
          ..responses.add(_jsonBody(200, '{"v2":"Roger"}'));
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = NvidiaNimTtsBackend(dio: dio);

        final wrapped = await backend.getVoices(
          apiKey: 'nv-test',
          baseUrl: 'https://ai.api.nvidia.com/v1',
        );
        expect(wrapped.single.id, 'v1');

        final mapped = await backend.getVoices(
          apiKey: 'nv-test',
          baseUrl: 'https://ai.api.nvidia.com/v1',
        );
        expect(mapped.single.id, 'v2');
        expect(mapped.single.label, 'Roger');
      });

      test('returns empty list when the request fails', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(_jsonBody(401, '{"detail":"No"}'));
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = NvidiaNimTtsBackend(dio: dio);

        expect(await backend.getVoices(apiKey: 'nv-test'), isEmpty);
      });
    });
  });
}