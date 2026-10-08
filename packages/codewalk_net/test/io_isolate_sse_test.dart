import 'dart:async';
import 'dart:convert';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:test/test.dart';

void main() {
  test(
    'idle input cancellation wakes the bridge without waiting for EOF',
    () async {
      final input = StreamController<List<int>>();
      final sub = parseSseInIsolate(input.stream).listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub.cancel().timeout(const Duration(seconds: 3));
      await input.close();
    },
  );
  for (final fragment in [': heartbeat\n\n', 'data: incomplete']) {
    test('pause stops input even without emitted frames $fragment', () async {
      var chunksRead = 0;
      Stream<List<int>> input() async* {
        for (var i = 0; i < 60; i++) {
          chunksRead++;
          yield utf8.encode(fragment);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }

      final sub = parseSseInIsolate(input()).listen((_) {});
      addTearDown(() => sub.cancel().timeout(const Duration(seconds: 3)));
      while (chunksRead < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      sub.pause();
      final pausedAt = chunksRead;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(chunksRead, lessThanOrEqualTo(pausedAt + 1));
      sub.resume();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(chunksRead, greaterThan(pausedAt + 1));
    });
  }
  test(
    'failed upstream cancellation still releases ports and later parser works',
    () async {
      final input = StreamController<List<int>>(
        onCancel: () {
          throw StateError('disposable cleanup failed');
        },
      );
      final iterator = StreamIterator(parseSseInIsolate(input.stream));
      final first = iterator.moveNext();
      input.add(utf8.encode('data: one\n\n'));
      expect(await first, isTrue);
      await expectLater(iterator.cancel(), throwsA(isA<TransportException>()));
      final next = await parseSseInIsolate(
        Stream.value(utf8.encode('data: two\n\n')),
      ).toList();
      expect(next.single.single.data, 'two');
    },
  );
  test(
    'isolate preserves split UTF8, comments, multiline and strict EOF',
    () async {
      final bytes = utf8.encode(
        ': keepalive\r\n\r\ndata: olá\r\ndata: 😀\r\n\r\ndata: incomplete',
      );
      final batches = await parseSseInIsolate(
        Stream.fromIterable([
          for (final byte in bytes) [byte],
        ]),
        maxChunkBytes: 2,
      ).toList();
      expect(batches.expand((b) => b).map((frame) => frame.data), ['olá\n😀']);
    },
  );

  test('output credits bound batches and stop upstream when paused', () async {
    var chunksRead = 0;
    Stream<List<int>> input() async* {
      for (var i = 0; i < 20; i++) {
        chunksRead++;
        yield utf8.encode('data: $i\n\n');
      }
    }

    final iterator = StreamIterator(
      parseSseInIsolate(input(), maxBatchFrames: 1),
    );
    expect(await iterator.moveNext(), isTrue);
    final read = chunksRead;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(chunksRead, read);
    expect(read, lessThanOrEqualTo(2));
    await iterator.cancel().timeout(const Duration(seconds: 3));
  });

  test('worker failures preserve safe typed frame limits', () async {
    await expectLater(
      parseSseInIsolate(
        Stream.value(utf8.encode('data: 123456789\n\n')),
        maxFrameBytes: 8,
      ).toList(),
      throwsA(
        isA<SseException>().having(
          (e) => e.failure,
          'limit',
          SseFailure.frameTooLarge,
        ),
      ),
    );
    await expectLater(
      parseSseInIsolate(
        Stream.value([100, 97, 116, 97, 58, 32, 0xff, 10, 10]),
      ).toList(),
      throwsA(
        isA<SseException>().having(
          (e) => e.failure,
          'utf8',
          SseFailure.malformedUtf8,
        ),
      ),
    );
  });

  test(
    'one input with many events obeys count and byte output limits',
    () async {
      final batches = await parseSseInIsolate(
        Stream.value(
          utf8.encode(List.generate(40, (i) => 'data: $i\n\n').join()),
        ),
        maxBatchFrames: 3,
        maxBatchBytes: 6,
      ).toList();
      expect(batches.expand((b) => b).length, 40);
      expect(
        batches.every(
          (b) =>
              b.length <= 3 &&
              b.fold<int>(0, (sum, f) => sum + sseFrameBytes(f)) <= 6,
        ),
        isTrue,
      );
    },
  );
}
