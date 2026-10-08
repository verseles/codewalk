import 'dart:convert';

import 'package:codewalk_net/codewalk_net.dart';
import 'package:codewalk_net/src/websocket_frames.dart';
import 'package:test/test.dart';

List<int> frame(int opcode, List<int> data, {bool fin = true}) => [
  (fin ? 128 : 0) | opcode,
  data.length,
  ...data,
];

void main() {
  test('split headers and UTF8 fragments survive interleaved ping', () {
    final decoder = ServerWebSocketDecoder(maxMessageBytes: 32);
    final bytes = [
      ...frame(1, [0xf0, 0x9f], fin: false),
      ...frame(9, [42]),
      ...frame(0, [0x98, 0x80]),
      ...frame(2, [1, 2, 3]),
    ];
    final packets = [
      for (final byte in bytes) ...decoder.add([byte]),
    ];
    expect(packets.map((p) => p.opcode), [9, 1, 2]);
    expect(utf8.decode(packets[1].payload), '😀');
    decoder.finish();
  });

  test('huge declaration fails from header alone before payload', () {
    final decoder = ServerWebSocketDecoder(maxMessageBytes: 1024);
    expect(
      () => decoder.add([0x82, 127, 0, 0, 0, 0, 2, 0, 0, 0]).toList(),
      throwsA(
        isA<TransportException>().having(
          (e) => e.failure,
          'cap',
          TransportFailure.bodyTooLarge,
        ),
      ),
    );
  });

  test('fragment total checked before the next payload', () {
    final decoder = ServerWebSocketDecoder(maxMessageBytes: 3);
    expect(decoder.add(frame(2, [1, 2], fin: false)), isEmpty);
    expect(
      () => decoder.add([128, 2]).toList(),
      throwsA(isA<TransportException>()),
    );
  });

  for (final invalid in <List<int>>[
    [0x81, 126, 0, 1], // Non-minimal 16-bit length.
    [0x82, 127, 128, 0, 0, 0, 0, 0, 0, 0],
    [0x81, 128], // Masked server frame.
    [0xc1, 0], // Unsolicited extension.
    [0x83, 0], // Reserved opcode.
    [0x09, 0], // Fragmented control.
    [0x89, 126, 0, 126],
    [0x80, 0], // Continuation without an initial fragment.
    [0x88, 1, 0], // One-byte Close payload.
    [0x88, 2, 3, 237], // Reserved 1005.
    [0x81, 1, 0xff], // Invalid UTF8.
  ]) {
    test('invalid wire rejected ${invalid.join(',')}', () {
      final decoder = ServerWebSocketDecoder(maxMessageBytes: 1024);
      expect(
        () => decoder.add(invalid).toList(),
        throwsA(isA<TransportException>()),
      );
    });
  }

  test('EOF rejects truncated frames and unfinished fragmented message', () {
    for (final bytes in [
      [0x81],
      [0x81, 2, 65],
      [1, 1, 65],
    ]) {
      final decoder = ServerWebSocketDecoder(maxMessageBytes: 32);
      decoder.add(bytes).toList();
      expect(decoder.finish, throwsA(isA<TransportException>()));
    }
  });

  test('client masks data, pong and close and preserves payload', () {
    for (final opcode in [1, 2, 8, 10]) {
      final encoded = encodeClientWebSocketFrame(opcode, [1, 2, 3]);
      expect(encoded[1] & 128, 128);
      expect(
        [for (var i = 0; i < 3; i++) encoded[i + 6] ^ encoded[2 + i % 4]],
        [1, 2, 3],
      );
    }
    expect(
      () => webSocketTextBytes('😀', 3),
      throwsA(isA<TransportException>()),
    );
    for (final invalid in [-1, 256]) {
      expect(
        () => encodeClientWebSocketFrame(2, [invalid]),
        throwsA(
          isA<TransportException>().having(
            (error) => error.failure,
            'range',
            TransportFailure.invalidRequest,
          ),
        ),
      );
    }
  });
}
