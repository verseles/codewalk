import 'dart:convert';

import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/tts/elevenlabs_tts_backend.dart';
import 'package:codewalk/presentation/services/tts/openai_compatible_tts_backend.dart';
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

ResponseBody _audioBody(int status, List<int> bytes) {
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: <String, List<String>>{
      'content-type': <String>['audio/mpeg'],
    },
  );
}

const TtsBackendCallbacks _callbacks = TtsBackendCallbacks();

void main() {
  group('ElevenLabsTtsBackend', () {
    test('exposes provider and generated-audio playback mode', () {
      final backend = ElevenLabsTtsBackend();
      expect(backend.provider, ReadAloudProvider.elevenLabs);
      expect(backend.playbackMode, TtsPlaybackMode.generatedAudio);
    });

    test('maps rate to voice speed within the ElevenLabs range', () {
      expect(openAiSpeedFromReadAloudRate(0.0), 0.5);
      expect(openAiSpeedFromReadAloudRate(0.5), 1.25);
      expect(openAiSpeedFromReadAloudRate(1.0), 2.0);
    });

    test('throws missing key before making any request', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello', rate: 0.5, pitch: 1.0),
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

    test('requires a voice and non-empty text', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
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
            text: '   ',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
            voiceId: 'voice-a',
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
      final backend = ElevenLabsTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 5001,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
            voiceId: 'voice-a',
            model: 'eleven_v3',
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

    test('posts text-to-speech request with xi-api-key and returns audio', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_audioBody(200, <int>[1, 2, 3]));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      final result = await backend.speakOrSynthesize(
        const TtsSynthesisRequest(
          text: 'Hello world',
          rate: 0.5,
          pitch: 1.0,
          apiKey: 'xi-test',
          baseUrl: 'https://api.elevenlabs.io/v1///',
          model: 'eleven_flash_v2_5',
          voiceId: 'voice-a',
        ),
        _callbacks,
      );

      expect(result, isA<GeneratedTtsAudio>());
      final audio = result as GeneratedTtsAudio;
      expect(audio.bytes, orderedEquals(<int>[1, 2, 3]));
      expect(audio.mimeType, 'audio/mpeg');

      final request = adapter.capturedRequests.single;
      expect(
        request.uri.toString(),
        'https://api.elevenlabs.io/v1/text-to-speech/voice-a',
      );
      expect(request.headers['xi-api-key'], 'xi-test');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers['Accept'], 'audio/mpeg');
      final body = request.data as Map<String, dynamic>;
      expect(body['text'], 'Hello world');
      expect(body['model_id'], 'eleven_flash_v2_5');
      expect(body['output_format'], 'mp3');
      final settings = body['voice_settings'] as Map<String, dynamic>;
      expect(settings['speed'], 1.25);
      expect(jsonEncode(body), isNot(contains('xi-test')));
    });

    test('url-encodes the voice id in the path', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_audioBody(200, <int>[1]));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await backend.speakOrSynthesize(
        const TtsSynthesisRequest(
          text: 'Hi',
          rate: 0.5,
          pitch: 1.0,
          apiKey: 'xi-test',
          voiceId: 'v o i c e',
        ),
        _callbacks,
      );

      expect(
        adapter.capturedRequests.single.uri.path,
        '/v1/text-to-speech/v%20o%20i%20c%20e',
      );
    });

    test('maps provider status errors', () async {
      final adapter = _MockDioAdapter()
        ..responses.addAll(<ResponseBody>[
          _jsonBody(401, '{"detail":{"message":"Invalid API key"}}'),
          _jsonBody(422, '{"detail":"Model not supported"}'),
          _jsonBody(
            429,
            '{"detail":{"type":"rate_limit_exceeded","message":"Too many"}}',
          ),
          _jsonBody(500, '{"detail":{"message":"Boom"}}'),
        ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      Future<TtsBackendException> failOnce() async {
        try {
          await backend.speakOrSynthesize(
            const TtsSynthesisRequest(
              text: 'Hello',
              rate: 0.5,
              pitch: 1.0,
              apiKey: 'xi-test',
              voiceId: 'voice-a',
            ),
            _callbacks,
          );
        } on TtsBackendException catch (error) {
          return error;
        }
        fail('Expected TtsBackendException');
      }

      expect((await failOnce()).kind, TtsBackendErrorKind.invalidApiKey);
      expect((await failOnce()).message, 'Model not supported');
      expect((await failOnce()).kind, TtsBackendErrorKind.rateLimitedOrQuota);
      expect((await failOnce()).kind, TtsBackendErrorKind.providerUnavailable);
    });

    test('surfaces a string detail message for network failures', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_jsonBody(429, 'Rate limit hit'));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      try {
        await backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
            voiceId: 'voice-a',
          ),
          _callbacks,
        );
      } on TtsBackendException catch (error) {
        expect(error.kind, TtsBackendErrorKind.rateLimitedOrQuota);
        expect(error.message, 'Rate limit hit');
        return;
      }
      fail('Expected TtsBackendException');
    });

    test('returns empty audio as providerUnavailable', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(_audioBody(200, const <int>[]));
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(
            text: 'Hello',
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
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
      test('returns empty list without an api key', () async {
        final adapter = _MockDioAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = ElevenLabsTtsBackend(dio: dio);

        expect(await backend.getVoices(apiKey: null), isEmpty);
        expect(adapter.capturedRequests, isEmpty);
      });

      test('parses the voices list with category labels', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(
            _jsonBody(
              200,
              '[{"voice_id":"v1","name":"Aria","labels":{"category":"premium"}},'
              '{"voice_id":"v2","name":"Roger","labels":{}}]',
            ),
          );
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = ElevenLabsTtsBackend(dio: dio);

        final voices = await backend.getVoices(
          apiKey: 'xi-test',
          baseUrl: 'https://api.elevenlabs.io/v1',
        );

        expect(voices, hasLength(2));
        expect(voices[0].id, 'v1');
        expect(voices[0].label, 'Aria');
        expect(voices[0].providerMetadata['category'], 'premium');
        expect(
          adapter.capturedRequests.single.uri.toString(),
          'https://api.elevenlabs.io/v1/voices',
        );
        expect(adapter.capturedRequests.single.headers['xi-api-key'], 'xi-test');
      });

      test('returns empty list when the request fails', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(_jsonBody(401, '{"detail":"No"}'));
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = ElevenLabsTtsBackend(dio: dio);

        expect(
          await backend.getVoices(apiKey: 'xi-test'),
          isEmpty,
        );
      });
    });
  });
}