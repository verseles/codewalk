import 'dart:convert';
import 'dart:io';

import 'package:codewalk_net/codewalk_net.dart';
import 'package:test/test.dart';

import 'fixture_support.dart';

Future<List<SseFrame>> decode(
  String source, {
  SseDecoder? decoder,
  int chunkSize = 1,
}) {
  final bytes = utf8.encode(source);
  final chunks = <List<int>>[
    for (var index = 0; index < bytes.length; index += chunkSize)
      bytes.sublist(
        index,
        index + chunkSize < bytes.length ? index + chunkSize : bytes.length,
      ),
  ];
  return Stream.fromIterable(
    chunks,
  ).transform(decoder ?? SseDecoder()).toList();
}

TypeMatcher<SseException> sseFailure(SseFailure failure) =>
    isA<SseException>().having((error) => error.failure, 'failure', failure);

void main() {
  test(
    'split UTF-8, initial BOM and split CRLF retain literal content',
    () async {
      final frames = await decode('\ufeff: heartbeat\r\ndata: Olá 🐱\r\n\r\n');
      expect(frames.single.data, 'Olá 🐱');
    },
  );

  test(
    'LF, bare CR and CRLF delimiters agree across chunk boundaries',
    () async {
      for (final ending in ['\n', '\r', '\r\n']) {
        final frames = await decode(
          'data: one$ending$ending'
          'data: two$ending$ending',
        );
        expect(frames.map((frame) => frame.data), ['one', 'two']);
      }
    },
  );

  test(
    'multiline data strips exactly one ASCII space and keeps tabs',
    () async {
      final frames = await decode('data:  first\ndata:\tsecond\ndata\n\n');
      expect(frames.single.data, ' first\n\tsecond\n');
    },
  );

  test('comments and unknown fields do not invent data', () async {
    final frames = await decode(
      ': comment\nunknown: value\nevent: ignored\n\n'
      'data:\n\n',
    );
    expect(frames, hasLength(1));
    expect(frames.single.data, '');
    expect(frames.single.event, isNull);
  });

  test(
    'generic metadata is per frame; invalid id and retry are ignored',
    () async {
      final frames = await decode(
        'event: update\nid: first\nid: bad\u0000id\n'
        'retry: 123\nretry: -1\ndata: value\n\n'
        'data: next\n\n',
      );
      expect(frames.first.event, 'update');
      expect(frames.first.id, 'first');
      expect(frames.first.retryMilliseconds, 123);
      expect(frames.last.id, isNull);
      expect(frames.last.event, isNull);
      expect(frames.last.retryMilliseconds, isNull);
    },
  );

  test('data is never interpreted as JSON', () async {
    expect((await decode('data: not-json\n\n')).single.data, 'not-json');
  });

  test('large aggregate chunk of bounded frames is accepted', () async {
    final frames = await decode(
      List.filled(30, 'data: x\n\n').join(),
      decoder: SseDecoder(maxFrameBytes: 9, maxLineBytes: 7),
      chunkSize: 1000,
    );
    expect(frames, hasLength(30));
  });

  test('one frame cap includes all wire bytes through its delimiter', () async {
    await expectLater(
      decode('data: x\n\n', decoder: SseDecoder(maxFrameBytes: 8)),
      throwsA(sseFailure(SseFailure.frameTooLarge)),
    );
  });

  test('line cap is enforced independently of a larger frame cap', () async {
    await expectLater(
      decode('data: x\n\n', decoder: SseDecoder(maxLineBytes: 6)),
      throwsA(sseFailure(SseFailure.lineTooLarge)),
    );
  });

  test('limits count UTF-8 bytes rather than decoded characters', () async {
    await expectLater(
      decode('data: é\n\n', decoder: SseDecoder(maxFrameBytes: 9)),
      throwsA(sseFailure(SseFailure.frameTooLarge)),
    );
    expect(
      (await decode(
        'data: é\n\n',
        decoder: SseDecoder(maxFrameBytes: 10),
      )).single.data,
      'é',
    );
  });

  test(
    'multiline comments and unknown fields share the frame budget',
    () async {
      await expectLater(
        decode(
          ':1234\nunknown: value\ndata: x\n\n',
          decoder: SseDecoder(maxFrameBytes: 20),
        ),
        throwsA(sseFailure(SseFailure.frameTooLarge)),
      );
    },
  );

  test('default caps are 16 MiB for both frame and line', () {
    expect(SseDecoder().maxFrameBytes, 16 * 1024 * 1024);
    expect(SseDecoder().maxLineBytes, 16 * 1024 * 1024);
    expect(() => SseDecoder(maxFrameBytes: 0), throwsArgumentError);
    expect(() => SseDecoder(maxLineBytes: -1), throwsArgumentError);
  });

  test('default EOF discards valid undelimited fragments', () async {
    for (final partial in ['data: partial', 'data: partial\n']) {
      final frames = await decode('data: complete\n\n$partial');
      expect(frames.map((frame) => frame.data), ['complete']);
    }
  });

  test('explicit EOF dispatch flushes valid final fields', () async {
    for (final partial in [
      'data: partial',
      'data: partial\n',
      'data: partial\r',
    ]) {
      final frames = await decode(
        'data: complete\n\n$partial',
        decoder: SseDecoder(eofPolicy: SseEofPolicy.dispatch),
      );
      expect(frames.map((frame) => frame.data), ['complete', 'partial']);
    }
  });

  test('complete CR boundary at EOF dispatches even in discard mode', () async {
    expect((await decode('data: complete\r\r')).single.data, 'complete');
  });

  test('truncated UTF-8 is typed failure under both EOF policies', () async {
    for (final policy in SseEofPolicy.values) {
      await expectLater(
        Stream.value([
          ...utf8.encode('data: '),
          0xf0,
          0x9f,
        ]).transform(SseDecoder(eofPolicy: policy)).toList(),
        throwsA(sseFailure(SseFailure.malformedUtf8)),
      );
    }
  });

  test('invalid UTF-8 is rejected without leaking source content', () async {
    await expectLater(
      Stream.value([
        ...utf8.encode('data: private-value'),
        0xc3,
        0x28,
        10,
        10,
      ]).transform(SseDecoder()).toList(),
      throwsA(
        sseFailure(SseFailure.malformedUtf8).having(
          (error) => error.toString(),
          'diagnostic',
          isNot(contains('private-value')),
        ),
      ),
    );
  });

  test('decoder instances can frame separate streams independently', () async {
    final decoder = SseDecoder();
    expect(
      (await decode('data: first\n\n', decoder: decoder)).single.data,
      'first',
    );
    expect(
      (await decode('data: second\n\n', decoder: decoder)).single.data,
      'second',
    );
  });

  test(
    'observed A frames survive single-byte and irregular chunking',
    () async {
      final fixtures = captureFixtures();
      final source = File('${fixtures.path}/events.sse').readAsStringSync();
      final expected = jsonDecode(
        File('${fixtures.path}/events.json').readAsStringSync(),
      );
      for (final chunkSize in [1, 7, 127, 65536]) {
        final frames = await decode(source, chunkSize: chunkSize);
        expect(frames, hasLength(27));
        expect(
          frames.map((frame) => jsonDecode(frame.data)).toList(),
          expected,
        );
      }
    },
  );
}
