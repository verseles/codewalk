import 'dart:convert';

import 'package:codewalk/domain/entities/experience_settings.dart';
import 'package:codewalk/presentation/services/tts/elevenlabs_tts_backend.dart';
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
      expect(elevenLabsSpeedFromReadAloudRate(0.0), 0.7);
      expect(elevenLabsSpeedFromReadAloudRate(0.5), 0.95);
      expect(elevenLabsSpeedFromReadAloudRate(1.0), 1.2);
      for (final rate in <double>[0.0, 0.25, 0.5, 0.75, 1.0]) {
        final speed = elevenLabsSpeedFromReadAloudRate(rate);
        expect(speed, greaterThanOrEqualTo(0.7));
        expect(speed, lessThanOrEqualTo(1.2));
      }
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

    test('parses the models envelope and filters non-TTS models', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(
          _jsonBody(200, jsonEncode(<dynamic>[
            <String, dynamic>{
              'model_id': 'eleven_flash_v2_5',
              'name': 'Eleven Flash v2.5',
              'max_characters_request': 40000,
              'can_do_text_to_speech': true,
            },
            <String, dynamic>{
              'model_id': 'eleven_v3',
              'name': 'Eleven v3',
              'max_characters_request': 5000,
              'can_do_text_to_speech': true,
            },
            <String, dynamic>{
              'model_id': 'eleven_voice_generation',
              'name': 'Voice Generation',
              'can_do_text_to_speech': false,
            },
            <String, dynamic>{'name': 'Missing id entry'},
          ])),
        );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      final models = await backend.getModels(apiKey: 'xi-test');

      expect(models.map((model) => model.id), <String>[
        'eleven_flash_v2_5',
        'eleven_v3',
      ]);
      expect(models.first.maxCharacters, 40000);
      expect(models.last.maxCharacters, 5000);
      expect(
        adapter.capturedRequests.single.uri.toString(),
        'https://api.elevenlabs.io/v1/models',
      );
    });

    test('returns empty models without an API key', () async {
      final adapter = _MockDioAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      final models = await backend.getModels();

      expect(models, isEmpty);
      expect(adapter.capturedRequests, isEmpty);
    });

    test('uses the provider-reported character limit for preflight', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(
          _jsonBody(200, jsonEncode(<dynamic>[
            <String, dynamic>{
              'model_id': 'custom-lite',
              'name': 'Custom Lite',
              'max_characters_request': 500,
              'can_do_text_to_speech': true,
            },
          ])),
        );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await backend.getModels(apiKey: 'xi-test');

      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 501,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
            voiceId: 'voice-a',
            model: 'custom-lite',
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
      // Only the model list fetch was performed; the oversized synthesis was
      // rejected before any HTTP request.
      expect(adapter.capturedRequests, hasLength(1));
    });

    test('clears cached character limits when a new fetch has no models', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(
          _jsonBody(200, jsonEncode(<dynamic>[
            <String, dynamic>{
              'model_id': 'custom-lite',
              'name': 'Custom Lite',
              'max_characters_request': 500,
              'can_do_text_to_speech': true,
            },
          ])),
        );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await backend.getModels(apiKey: 'xi-test');
      // A subsequent empty fetch (e.g. another account without the model)
      // must not keep applying the previously learned limit.
      await backend.getModels(apiKey: 'other-key');

      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 501,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'other-key',
            voiceId: 'voice-a',
            model: 'custom-lite',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            isNot(TtsBackendErrorKind.invalidRequest),
          ),
        ),
      );
    });

    test('scopes cached character limits to the fetched base URL', () async {
      final adapter = _MockDioAdapter()
        ..responses.add(
          _jsonBody(200, jsonEncode(<dynamic>[
            <String, dynamic>{
              'model_id': 'custom-lite',
              'name': 'Custom Lite',
              'max_characters_request': 500,
              'can_do_text_to_speech': true,
            },
          ])),
        );
      final dio = Dio()..httpClientAdapter = adapter;
      final backend = ElevenLabsTtsBackend(dio: dio);

      await backend.getModels(
        apiKey: 'xi-test',
        baseUrl: 'https://api.elevenlabs.io/v1',
      );

      // A request against a different base URL must not use the limit learned
      // from the first endpoint, so an oversized text is not rejected locally.
      await expectLater(
        backend.speakOrSynthesize(
          TtsSynthesisRequest(
            text: 'a' * 501,
            rate: 0.5,
            pitch: 1.0,
            apiKey: 'xi-test',
            baseUrl: 'https://other.elevenlabs.example/v1',
            voiceId: 'voice-a',
            model: 'custom-lite',
          ),
          _callbacks,
        ),
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            isNot(TtsBackendErrorKind.invalidRequest),
          ),
        ),
      );
      // The synthesis reached HTTP (the preflight did not reject it).
      expect(adapter.capturedRequests.length, greaterThanOrEqualTo(2));
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
      expect(settings['speed'], 0.95);
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

      test('parses the standard voices envelope with category labels', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(
            _jsonBody(
              200,
              '{"voices":[{"voice_id":"v1","name":"Aria",'
              '"labels":{"category":"premium"}},'
              '{"voice_id":"v2","name":"Roger","labels":{}}]}',
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

      test('still accepts a bare list response', () async {
        final adapter = _MockDioAdapter()
          ..responses.add(
            _jsonBody(200, '[{"voice_id":"v1","name":"Aria"}]'),
          );
        final dio = Dio()..httpClientAdapter = adapter;
        final backend = ElevenLabsTtsBackend(dio: dio);

        final voices = await backend.getVoices(
          apiKey: 'xi-test',
          baseUrl: 'https://api.elevenlabs.io/v1',
        );

        expect(voices.single.id, 'v1');
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