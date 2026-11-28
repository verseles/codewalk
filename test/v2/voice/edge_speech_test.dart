import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/platform/voice/edge_speech_io.dart';
import 'package:codewalk/platform/voice/edge_token.dart';
import 'package:flutter_test/flutter_test.dart';

// #541: Microsoft Edge's read-aloud protocol, as edge-tts 7.3.1 speaks it.

void main() {
  test('the v2 token matches edge-tts', () {
    // The vector edge-tts ships, and one more from its own code.
    expect(
      edgeSecMsGec(1791888000),
      '492D7694A183A45E-'
      '56E821F95D4579C5B7C7E33DC7303FF379EC36D510213555BBBB9EB17EF15876',
    );
    expect(
      edgeSecMsGec(1700000123),
      '0919602B5750900A-'
      'EC9DD394F23CB5635CF62A0E8E24136DCD32B26D10C543B10082E482D7516397',
    );
    // Five-minute windows share a token.
    expect(edgeSecMsGec(1791888000), edgeSecMsGec(1791888299));
    expect(edgeSecMsGec(1791888000), isNot(edgeSecMsGec(1791888300)));
  });

  test('voice names expand as the service wants them', () {
    expect(
      edgeVoiceName('en-US-EmmaMultilingualNeural'),
      'Microsoft Server Speech Text to Speech Voice '
      '(en-US, EmmaMultilingualNeural)',
    );
    // A dash in the name moves into the region.
    expect(
      edgeVoiceName('zh-CN-liaoning-XiaobeiNeural'),
      'Microsoft Server Speech Text to Speech Voice '
      '(zh-CN-liaoning, XiaobeiNeural)',
    );
    expect(edgeVoiceName('custom'), 'custom');
  });

  test('text is escaped and cut into whole pieces', () {
    expect(edgeEscape('a < b & c > d\u0001'), 'a &lt; b &amp; c &gt; d ');
    final words = List.filled(1200, 'word').join(' ');
    final chunks = edgeChunks(words);
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(utf8.encode(chunk).length, lessThanOrEqualTo(4096));
      expect(chunk.startsWith('word') && chunk.endsWith('word'), isTrue);
    }
    expect(chunks.join(' '), words);
    // No space at all: cut between whole characters, never mid-rune.
    final cjk = '字' * 3000;
    final pieces = edgeChunks(cjk);
    expect(pieces.join(), cjk);
    for (final piece in pieces) {
      expect(utf8.encode(piece).length, lessThanOrEqualTo(4096));
    }
    // Never inside an entity.
    final entities = '${'a' * 4093}&amp;b';
    final split = edgeChunks(entities);
    expect(split.first.length, 4093);
    expect(split.last, '&amp;b');
  });

  test('the SSML carries the voice and the speed', () {
    final normal = edgeSsml('hi', voice: 'en-US-AriaNeural', rate: 0.5);
    expect(normal, contains("rate='+0%'"));
    expect(normal, contains('(en-US, AriaNeural)'));
    expect(edgeSsml('hi', voice: 'x', rate: 0), contains("rate='-50%'"));
    expect(edgeSsml('hi', voice: 'x', rate: 1), contains("rate='+100%'"));
  });

  test('frames are read as the service sends them', () {
    expect(
      edgeHeader('X-RequestId:1\r\nPath:turn.end\r\n\r\n{}', 'Path'),
      'turn.end',
    );
    Uint8List frame(String headers, List<int> audio) {
      final head = latin1.encode(headers);
      return Uint8List.fromList([
        head.length >> 8,
        head.length & 0xFF,
        ...head,
        ...audio,
      ]);
    }

    expect(
      edgeAudioFrame(
        frame('Content-Type:audio/mpeg\r\nPath:audio\r\n', [9, 8]),
      ),
      [9, 8],
    );
    // The end marker has no audio; another path is not audio.
    expect(edgeAudioFrame(frame('Path:audio\r\n', [])), isNull);
    expect(edgeAudioFrame(frame('Path:other\r\n', [1])), isNull);
    expect(edgeAudioFrame(Uint8List.fromList([0])), isNull);
  });

  test('the voice list is sorted and labelled', () {
    final voices = edgeVoices(
      jsonEncode([
        {
          'ShortName': 'pt-BR-FranciscaNeural',
          'Locale': 'pt-BR',
          'Gender': 'Female',
        },
        {
          'ShortName': 'en-US-AriaNeural',
          'Locale': 'en-US',
          'Gender': 'Female',
        },
        {'Locale': 'xx'},
      ]),
    );
    expect(voices.map((v) => v.id), [
      'en-US-AriaNeural',
      'pt-BR-FranciscaNeural',
    ]);
    expect(voices.first.label, 'Aria (Female)');
  });

  test('dates and default voices', () {
    expect(
      edgeDate(DateTime.utc(2026, 11, 28, 3, 4, 5)),
      'Sat Nov 28 2026 03:04:05 GMT+0000 (Coordinated Universal Time)',
    );
    expect(EdgeSpeech.defaultVoice('pt-BR'), 'pt-BR-FranciscaNeural');
    expect(EdgeSpeech.defaultVoice('xx'), 'en-US-EmmaMultilingualNeural');
  });
}
