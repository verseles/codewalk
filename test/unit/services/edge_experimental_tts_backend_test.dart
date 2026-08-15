import 'dart:async';

import 'package:codewalk/presentation/services/tts/edge_experimental_tts_backend.dart';
import 'package:codewalk/presentation/services/tts/edge_tts_protocol.dart';
import 'package:codewalk/presentation/services/tts/edge_tts_websocket.dart';
import 'package:codewalk/presentation/services/tts/tts_backend.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEdgeTtsConnection implements EdgeTtsWebSocketConnection {
  _FakeEdgeTtsConnection({this.readyError});

  final Object? readyError;
  final StreamController<dynamic> _controller = StreamController<dynamic>();
  final List<String> sentTexts = <String>[];
  bool closed = false;

  @override
  Future<void> get ready async {
    final error = readyError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void sendText(String data) {
    sentTexts.add(data);
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void add(dynamic value) {
    _controller.add(value);
  }
}

class _FakeConnector {
  _FakeConnector(this.connections);

  int calls = 0;
  final List<_FakeEdgeTtsConnection> connections;

  EdgeTtsWebSocketConnection call(Uri uri) {
    capturedUris.add(uri);
    return connections[calls++ % connections.length];
  }

  final List<Uri> capturedUris = <Uri>[];
}

class _IdSequence {
  _IdSequence(this.values);

  int _index = 0;
  final List<String> values;

  String next() => values[_index++];
}

Future<void> _waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met within $timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('EdgeExperimentalTtsBackend', () {
    test('parses Edge voice catalog entries', () {
      final voices = parseEdgeTtsVoices(<Map<String, String>>[
        <String, String>{
          'ShortName': 'en-US-AriaNeural',
          'FriendlyName': 'Microsoft Aria Online',
          'Locale': 'en-US',
          'Gender': 'Female',
        },
      ]);

      expect(voices, hasLength(1));
      expect(voices.single.id, 'en-US-AriaNeural');
      expect(voices.single.locale, 'en-US');
      expect(voices.single.label, 'Microsoft Aria Online (en-US)');
      expect(voices.single.providerMetadata['gender'], 'Female');
    });

    test('builds escaped Edge SSML envelope', () {
      final ssml = buildEdgeTtsSsml(
        text: 'Hello <world> & "friends"',
        voice: 'en-US-AriaNeural',
      );

      expect(ssml, contains("<voice name='en-US-AriaNeural'>"));
      expect(ssml, contains('Hello &lt;world&gt; &amp; &quot;friends&quot;'));
      expect(ssml, contains("<prosody pitch='+0Hz' rate='+0%' volume='+0%'>"));
    });

    test(
      'direct synthesis returns generated mp3 audio from websocket frames',
      () async {
        final connection = _FakeEdgeTtsConnection();
        late Uri capturedUri;
        final ids = _IdSequence(<String>[
          '11111111111111111111111111111111',
          '22222222222222222222222222222222',
        ]);
        final backend = EdgeExperimentalTtsBackend(
          connector: (uri) {
            capturedUri = uri;
            return connection;
          },
          nowProvider: () => DateTime.utc(2026, 7, 8, 16),
          idProvider: ids.next,
        );

        expect(await backend.isAvailable, isTrue);

        final resultFuture = backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          capturedUri.queryParameters['TrustedClientToken'],
          kEdgeTtsTrustedClientToken,
        );
        expect(
          capturedUri.queryParameters['ConnectionId'],
          '11111111111111111111111111111111',
        );
        expect(connection.sentTexts, hasLength(2));
        expect(connection.sentTexts.first, contains('Path:speech.config\r\n'));
        expect(connection.sentTexts.last, contains('Path:ssml\r\n'));
        expect(connection.sentTexts.last, contains(kDefaultEdgeTtsVoice));

        connection.add(
          buildEdgeTtsBinaryFrameForTest(
            headers: const <String, String>{
              'Path': 'audio',
              'Content-Type': kEdgeTtsAudioMimeType,
            },
            audioBytes: const <int>[1, 2, 3],
          ),
        );
        connection.add('Path:turn.end\r\n\r\n{}');

        final result = await resultFuture;
        expect(result, isA<GeneratedTtsAudio>());
        final audio = result as GeneratedTtsAudio;
        expect(audio.mimeType, kEdgeTtsAudioMimeType);
        expect(audio.bytes, orderedEquals(<int>[1, 2, 3]));
        expect(connection.closed, isTrue);
      },
    );

    test('maps empty Edge audio response to provider unavailable', () async {
      final connection = _FakeEdgeTtsConnection();
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: (_) => connection,
        idProvider: ids.next,
      );

      final resultFuture = backend.speakOrSynthesize(
        const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await Future<void>.delayed(Duration.zero);
      connection.add('Path:turn.end\r\n\r\n{}');

      await expectLater(
        resultFuture,
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.kind,
            'kind',
            TtsBackendErrorKind.providerUnavailable,
          ),
        ),
      );
    });

    test(
      'rejects partial audio when Edge stream ends before turn end',
      () async {
        final connection = _FakeEdgeTtsConnection();
        final ids = _IdSequence(<String>[
          '11111111111111111111111111111111',
          '22222222222222222222222222222222',
        ]);
        final backend = EdgeExperimentalTtsBackend(
          connector: (_) => connection,
          idProvider: ids.next,
        );

        final resultFuture = backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        );
        await Future<void>.delayed(Duration.zero);
        connection.add(
          buildEdgeTtsBinaryFrameForTest(
            headers: const <String, String>{
              'Path': 'audio',
              'Content-Type': kEdgeTtsAudioMimeType,
            },
            audioBytes: const <int>[1, 2, 3],
          ),
        );
        await connection.close();

        await expectLater(
          resultFuture,
          throwsA(
            isA<TtsBackendException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  TtsBackendErrorKind.providerUnavailable,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Microsoft Edge Speech ended before synthesis completed.',
                ),
          ),
        );
      },
    );

    test('synthesizes long text in chunks and concatenates audio', () async {
      final first = _FakeEdgeTtsConnection();
      final second = _FakeEdgeTtsConnection();
      final connector = _FakeConnector(<_FakeEdgeTtsConnection>[
        first,
        second,
      ]);
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
        '33333333333333333333333333333333',
        '44444444444444444444444444444444',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: connector.call,
        idProvider: ids.next,
      );
      final longText = List<String>.filled(
        kEdgeTtsMaxInputBytes + 100,
        'a',
      ).join();

      final resultFuture = backend.speakOrSynthesize(
        TtsSynthesisRequest(text: longText, rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await _waitFor(() => first.sentTexts.length == 2);

      expect(connector.capturedUris[0].queryParameters['ConnectionId'],
          '11111111111111111111111111111111');
      expect(first.sentTexts.first, contains('Path:speech.config\r\n'));
      expect(first.sentTexts.last, contains('Path:ssml\r\n'));

      first.add(
        buildEdgeTtsBinaryFrameForTest(
          headers: const <String, String>{
            'Path': 'audio',
            'Content-Type': kEdgeTtsAudioMimeType,
          },
          audioBytes: const <int>[1, 2],
        ),
      );
      first.add('Path:turn.end\r\n\r\n{}');
      await _waitFor(() => connector.calls == 2);
      await _waitFor(() => second.sentTexts.length == 2);
      second.add(
        buildEdgeTtsBinaryFrameForTest(
          headers: const <String, String>{
            'Path': 'audio',
            'Content-Type': kEdgeTtsAudioMimeType,
          },
          audioBytes: const <int>[3, 4],
        ),
      );
      second.add('Path:turn.end\r\n\r\n{}');

      final result = await resultFuture;
      expect(result, isA<GeneratedTtsAudio>());
      final audio = result as GeneratedTtsAudio;
      expect(audio.bytes, orderedEquals(<int>[1, 2, 3, 4]));
    });

    test('reports server error frames with the server message', () async {
      final connection = _FakeEdgeTtsConnection();
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: (_) => connection,
        idProvider: ids.next,
      );

      final resultFuture = backend.speakOrSynthesize(
        const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await Future<void>.delayed(Duration.zero);
      connection.add('Path:error\r\n\r\nunsupported voice');

      await expectLater(
        resultFuture,
        throwsA(
          isA<TtsBackendException>()
              .having(
                (error) => error.kind,
                'kind',
                TtsBackendErrorKind.providerUnavailable,
              )
              .having(
                (error) => error.message,
                'message',
                'unsupported voice',
              ),
        ),
      );
    });

    test('surfaces HTTP status when websocket upgrade is rejected', () async {
      final connection = _FakeEdgeTtsConnection(
        readyError: const EdgeTtsWebSocketUpgradeException(
          statusCode: 429,
          reasonPhrase: 'Too Many Requests',
        ),
      );
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: (_) => connection,
        idProvider: ids.next,
      );

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        ),
        throwsA(
          isA<TtsBackendException>()
              .having(
                (error) => error.kind,
                'kind',
                TtsBackendErrorKind.rateLimitedOrQuota,
              )
              .having(
                (error) => error.statusCode,
                'statusCode',
                429,
              )
              .having(
                (error) => error.message,
                'message',
                contains('HTTP 429'),
              ),
        ),
      );
    });

    test(
      'retries handshake once with adjusted clock skew on 403 with Date',
      () async {
        final rejected = _FakeEdgeTtsConnection(
          readyError: const EdgeTtsWebSocketUpgradeException(
            statusCode: 403,
            reasonPhrase: 'Forbidden',
            dateHeader: 'Wed, 08 Jul 2026 17:00:00 GMT',
          ),
        );
        final accepted = _FakeEdgeTtsConnection();
        final connector = _FakeConnector(<_FakeEdgeTtsConnection>[
          rejected,
          accepted,
        ]);
        final ids = _IdSequence(<String>[
          '11111111111111111111111111111111',
          '22222222222222222222222222222222',
        ]);
        final backend = EdgeExperimentalTtsBackend(
          connector: connector.call,
          nowProvider: () => DateTime.utc(2026, 7, 8, 16),
          idProvider: ids.next,
        );

        final resultFuture = backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        );
        await _waitFor(() => connector.calls == 2);

        expect(
          connector.capturedUris[1].queryParameters['Sec-MS-GEC'],
          edgeTtsSecMsGec(DateTime.utc(2026, 7, 8, 17)),
        );

        accepted.add(
          buildEdgeTtsBinaryFrameForTest(
            headers: const <String, String>{
              'Path': 'audio',
              'Content-Type': kEdgeTtsAudioMimeType,
            },
            audioBytes: const <int>[9, 8, 7],
          ),
        );
        accepted.add('Path:turn.end\r\n\r\n{}');

        final result = await resultFuture;
        expect(result, isA<GeneratedTtsAudio>());
        final audio = result as GeneratedTtsAudio;
        expect(audio.bytes, orderedEquals(<int>[9, 8, 7]));
      },
    );

    test('does not retry when 403 lacks a Date header', () async {
      final rejected = _FakeEdgeTtsConnection(
        readyError: const EdgeTtsWebSocketUpgradeException(
          statusCode: 403,
          reasonPhrase: 'Forbidden',
        ),
      );
      final connector = _FakeConnector(<_FakeEdgeTtsConnection>[rejected]);
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: connector.call,
        idProvider: ids.next,
      );

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        ),
        throwsA(
          isA<TtsBackendException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                403,
              )
              .having(
                (error) => error.message,
                'message',
                contains('HTTP 403'),
              ),
        ),
      );
      expect(connector.calls, 1);
      expect(rejected.closed, isTrue);
    });

    test('surfaces final error when the retried handshake also fails',
        () async {
      final first = _FakeEdgeTtsConnection(
        readyError: const EdgeTtsWebSocketUpgradeException(
          statusCode: 403,
          reasonPhrase: 'Forbidden',
          dateHeader: 'Wed, 08 Jul 2026 17:00:00 GMT',
        ),
      );
      final second = _FakeEdgeTtsConnection(
        readyError: const EdgeTtsWebSocketUpgradeException(
          statusCode: 403,
          reasonPhrase: 'Forbidden',
          dateHeader: 'Wed, 08 Jul 2026 17:00:00 GMT',
        ),
      );
      final connector = _FakeConnector(<_FakeEdgeTtsConnection>[
        first,
        second,
      ]);
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: connector.call,
        idProvider: ids.next,
      );

      await expectLater(
        backend.speakOrSynthesize(
          const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
          const TtsBackendCallbacks(),
        ),
        throwsA(
          isA<TtsBackendException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                403,
              )
              .having(
                (error) => error.kind,
                'kind',
                TtsBackendErrorKind.providerUnavailable,
              ),
        ),
      );
      expect(connector.calls, 2);
      expect(first.closed, isTrue);
      expect(second.closed, isTrue);
    });

    test('stop between chunks aborts before opening the next connection',
        () async {
      final first = _FakeEdgeTtsConnection();
      final second = _FakeEdgeTtsConnection();
      final connector = _FakeConnector(<_FakeEdgeTtsConnection>[
        first,
        second,
      ]);
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
        '33333333333333333333333333333333',
        '44444444444444444444444444444444',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: connector.call,
        idProvider: ids.next,
      );
      final longText = List<String>.filled(
        kEdgeTtsMaxInputBytes + 100,
        'a',
      ).join();

      final resultFuture = backend.speakOrSynthesize(
        TtsSynthesisRequest(text: longText, rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await _waitFor(() => first.sentTexts.length == 2);
      first.add(
        buildEdgeTtsBinaryFrameForTest(
          headers: const <String, String>{
            'Path': 'audio',
            'Content-Type': kEdgeTtsAudioMimeType,
          },
          audioBytes: const <int>[1, 2],
        ),
      );
      first.add('Path:turn.end\r\n\r\n{}');
      await backend.stop();

      await expectLater(
        resultFuture,
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.message,
            'message',
            'Microsoft Edge Speech was cancelled.',
          ),
        ),
      );
      expect(connector.calls, 1);
      expect(second.closed, isFalse);
    });

    test('rejects a chunk that ends with turn.end but zero audio', () async {
      final connection = _FakeEdgeTtsConnection();
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: (_) => connection,
        idProvider: ids.next,
      );

      final resultFuture = backend.speakOrSynthesize(
        const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await Future<void>.delayed(Duration.zero);
      connection.add('Path:turn.end\r\n\r\n{}');

      await expectLater(
        resultFuture,
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.message,
            'message',
            'Microsoft Edge Speech returned an empty audio response.',
          ),
        ),
      );
    });

    test('stop closes active Edge websocket connection', () async {
      final connection = _FakeEdgeTtsConnection();
      final ids = _IdSequence(<String>[
        '11111111111111111111111111111111',
        '22222222222222222222222222222222',
      ]);
      final backend = EdgeExperimentalTtsBackend(
        connector: (_) => connection,
        idProvider: ids.next,
      );

      final resultFuture = backend.speakOrSynthesize(
        const TtsSynthesisRequest(text: 'Hello Edge', rate: 0.5, pitch: 1.0),
        const TtsBackendCallbacks(),
      );
      await Future<void>.delayed(Duration.zero);

      await backend.stop();

      expect(connection.closed, isTrue);
      await expectLater(
        resultFuture,
        throwsA(
          isA<TtsBackendException>().having(
            (error) => error.message,
            'message',
            'Microsoft Edge Speech was cancelled.',
          ),
        ),
      );
    });

    test('chunking splits long text at natural boundaries', () {
      final chunks = splitEdgeTtsTextChunks(
        List<String>.filled(kEdgeTtsMaxInputBytes + 500, 'a').join(' '),
      );

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk, isNotEmpty);
        expect(
          edgeTtsEscapedByteLength(chunk),
          lessThanOrEqualTo(kEdgeTtsMaxInputBytes),
        );
      }
      expect(
        chunks.map((chunk) => chunk.replaceAll(' ', '')).join(),
        List<String>.filled(kEdgeTtsMaxInputBytes + 500, 'a').join(),
      );
    });

    test('chunking never splits multibyte characters', () {
      final emoji = '😀' * 1500;
      final chunks = splitEdgeTtsTextChunks(emoji);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.runes.every((rune) => rune > 0xFFFF), isTrue);
        expect(
          edgeTtsEscapedByteLength(chunk),
          lessThanOrEqualTo(kEdgeTtsMaxInputBytes),
        );
      }
    });

    test('parses RFC 7231 HTTP date headers', () {
      expect(
        parseEdgeTtsHttpDate('Wed, 08 Jul 2026 17:00:00 GMT'),
        DateTime.utc(2026, 7, 8, 17),
      );
      expect(parseEdgeTtsHttpDate('garbage'), isNull);
      expect(parseEdgeTtsHttpDate('Wed, 99 Jul 2026 17:00:00 GMT'), isNull);
    });
  });
}
