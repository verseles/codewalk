import 'dart:convert';

import 'package:codewalk/presentation/services/tts/edge_tts_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Edge TTS protocol', () {
    final fixedTime = DateTime.utc(2026, 7, 8, 16);

    test('generates deterministic Sec-MS-GEC token', () {
      expect(
        edgeTtsSecMsGec(fixedTime),
        'EC12D56DAF7ABE6A80207487E1DFA5CACC791EE85037FB52FFC31A5E191DBB78',
      );
    });

    test('builds websocket URI with Edge Read Aloud query parameters', () {
      final uri = edgeTtsWebSocketUri(
        connectionId: '12345678-1234-1234-1234-123456789abc',
        nowUtc: fixedTime,
      );

      expect(uri.scheme, 'wss');
      expect(uri.host, 'speech.platform.bing.com');
      expect(uri.path, '/consumer/speech/synthesize/readaloud/edge/v1');
      expect(
        uri.queryParameters['TrustedClientToken'],
        kEdgeTtsTrustedClientToken,
      );
      expect(
        uri.queryParameters['ConnectionId'],
        '12345678123412341234123456789abc',
      );
      expect(uri.queryParameters['Sec-MS-GEC'], edgeTtsSecMsGec(fixedTime));
      expect(
        uri.queryParameters['Sec-MS-GEC-Version'],
        kEdgeTtsSecMsGecVersion,
      );
    });

    test('serializes speech config and SSML frames with CRLF separator', () {
      final speechConfig = edgeTtsSpeechConfigFrame(nowUtc: fixedTime);
      final ssml = edgeTtsSsmlFrame(
        requestId: 'abcdefab-cdef-abcd-efab-cdefabcdefab',
        ssml: '<speak>Hello</speak>',
        nowUtc: fixedTime,
      );

      expect(speechConfig, contains('Path:speech.config\r\n'));
      expect(speechConfig, contains('Wed Jul 08 2026 16:00:00 GMT+0000'));
      expect(speechConfig, contains('\r\n\r\n'));
      expect(speechConfig, contains(kEdgeTtsAudioOutputFormat));
      expect(speechConfig, contains('"sentenceBoundaryEnabled":"false"'));
      expect(speechConfig.endsWith('\r\n'), isTrue);
      expect(ssml, contains('Path:ssml\r\n'));
      expect(ssml, contains('(Coordinated Universal Time)Z\r\n'));
      expect(
        ssml,
        contains('X-RequestId:abcdefabcdefabcdefabcdefabcdefab\r\n'),
      );
      expect(ssml.endsWith('<speak>Hello</speak>'), isTrue);
    });

    test('builds escaped SSML and strips unsupported control characters', () {
      final ssml = buildEdgeTtsSsml(
        text: 'Hello <world> & "friends"\u0001',
        voice: 'en-US-AriaNeural',
        locale: 'en-US',
        rate: '+10%',
        pitch: '-5Hz',
      );

      expect(ssml, isNot(contains('xmlns:mstts=')));
      expect(ssml, contains("<voice name='en-US-AriaNeural'>"));
      expect(ssml, contains("rate='+10%'"));
      expect(ssml, contains("pitch='-5Hz'"));
      expect(ssml, contains("volume='+0%'"));
      expect(ssml, contains('Hello &lt;world&gt; &amp; &quot;friends&quot;'));
      expect(ssml, isNot(contains('\u0001')));
    });

    test('maps CodeWalk rate and pitch to Edge prosody attributes', () {
      expect(edgeTtsRateAttribute(0.0), '-50%');
      expect(edgeTtsRateAttribute(0.5), '+0%');
      expect(edgeTtsRateAttribute(1.0), '+50%');
      expect(edgeTtsPitchAttribute(0.5), '-25Hz');
      expect(edgeTtsPitchAttribute(1.0), '+0Hz');
      expect(edgeTtsPitchAttribute(2.0), '+50Hz');
    });

    test('parses text frames and turn.end path', () {
      final frame = parseEdgeTtsTextFrame(
        'Path:turn.end\r\nX-RequestId:req_1\r\n\r\n{}',
      );

      expect(frame.path, 'turn.end');
      expect(frame.headers['X-RequestId'], 'req_1');
      expect(frame.body, '{}');
    });

    test('parses binary audio frames with two-byte header length', () {
      final binary = buildEdgeTtsBinaryFrameForTest(
        headers: const <String, String>{
          'Path': 'audio',
          'Content-Type': kEdgeTtsAudioMimeType,
        },
        audioBytes: const <int>[1, 2, 3, 4],
      );

      final frame = parseEdgeTtsBinaryFrame(binary);

      expect(frame.path, 'audio');
      expect(frame.contentType, kEdgeTtsAudioMimeType);
      expect(frame.audioBytes, orderedEquals(<int>[1, 2, 3, 4]));
    });

    test('rejects truncated binary frames', () {
      expect(
        () => parseEdgeTtsBinaryFrame(const <int>[0]),
        throwsFormatException,
      );
      expect(
        () => parseEdgeTtsBinaryFrame(utf8.encode('\x00\x10short')),
        throwsFormatException,
      );
    });

    test('checks Edge input byte limit after control char cleanup', () {
      final maxLengthText = List<String>.filled(
        kEdgeTtsMaxInputBytes,
        'a',
      ).join();

      expect(splitEdgeTtsTextChunks(maxLengthText), hasLength(1));
      expect(
        splitEdgeTtsTextChunks('$maxLengthText a'),
        hasLength(2),
      );
      expect(edgeTtsEscapedByteLength('abc'), 3);
      expect(edgeTtsEscapedByteLength('a&b'), 7);
    });

    test('splits by escaped byte length, not raw characters', () {
      // '&' escapes to '&amp;' (5 bytes each), so 1200 ampersands are
      // ~6000 escaped bytes and must span multiple chunks.
      final chunks = splitEdgeTtsTextChunks('&' * 1200);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(
          edgeTtsEscapedByteLength(chunk),
          lessThanOrEqualTo(kEdgeTtsMaxInputBytes),
        );
      }
      expect(chunks.join().length, 1200);
    });

    test('rejects impossible HTTP dates like February 31', () {
      expect(parseEdgeTtsHttpDate('Tue, 31 Feb 2026 17:00:00 GMT'), isNull);
      expect(parseEdgeTtsHttpDate('Tue, 31 Apr 2026 17:00:00 GMT'), isNull);
      expect(parseEdgeTtsHttpDate('Wed, 08 Jul 2026 25:00:00 GMT'), isNull);
    });
  });
}
