import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk/core/tailscale/tailscale_tcp_connection.dart';
import 'package:codewalk/presentation/services/codewalk_terminal_socket.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTailscaleTcpConnection implements TailscaleTcpConnection {
  final StreamController<Uint8List> peerToClient =
      StreamController<Uint8List>();
  final BytesBuilder clientToServer = BytesBuilder(copy: false);
  final Completer<void> _done = Completer<void>();
  bool closed = false;
  bool hangWrites = false;

  @override
  Stream<Uint8List> get input => peerToClient.stream;

  @override
  Future<void> write(List<int> bytes) async {
    if (hangWrites) await Completer<void>().future;
    clientToServer.add(bytes);
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    if (!peerToClient.isClosed) await peerToClient.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

String _extractKey(Uint8List requestBytes) {
  final request = ascii.decode(requestBytes);
  return RegExp(r'Sec-WebSocket-Key: (\S+)').firstMatch(request)!.group(1)!;
}

Uint8List _acceptResponse(String key) {
  final accept = base64Encode(
    sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
        .bytes,
  );
  return Uint8List.fromList(
    ascii.encode(
      'HTTP/1.1 101 Switching Protocols\r\n'
      'Upgrade: websocket\r\n'
      'Connection: Upgrade\r\n'
      'Sec-WebSocket-Accept: $accept\r\n\r\n',
    ),
  );
}

/// Unmasked server-to-client frame.
Uint8List _serverFrame(int opcode, List<int> payload, {bool fin = true}) {
  final builder = BytesBuilder(copy: false)
    ..add([(fin ? 0x80 : 0x00) | opcode]);
  if (payload.length < 126) {
    builder.add([payload.length]);
  } else {
    builder.add([126, (payload.length >> 8) & 0xFF, payload.length & 0xFF]);
  }
  builder.add(payload);
  return builder.toBytes();
}

({int opcode, List<int> payload, bool masked}) _parseClientFrame(
  Uint8List bytes,
  int offset,
) {
  final opcode = bytes[offset] & 0x0F;
  final masked = bytes[offset + 1] & 0x80 != 0;
  var length = bytes[offset + 1] & 0x7F;
  var header = 2;
  if (length == 126) {
    length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    header = 4;
  }
  final start = offset + header + 4;
  final mask = bytes.sublist(offset + header, start);
  final payload = List<int>.generate(
    length,
    (i) => bytes[start + i] ^ mask[i % 4],
  );
  return (opcode: opcode, payload: payload, masked: masked);
}

int _requestEnd(Uint8List written) {
  final bytes = written;
  for (var i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i + 4;
    }
  }
  throw StateError('No HTTP head terminator in client bytes.');
}

void main() {
  group('Terminal WebSocket over Tailscale', () {
    late _FakeTailscaleTcpConnection connection;
    late String dialHost;
    late int dialPort;

    setUp(() {
      connection = _FakeTailscaleTcpConnection();
      dialHost = '';
      dialPort = 0;
    });

    Future<TailscaleTcpConnection> dial(
      String host,
      int port, {
      Duration? timeout,
    }) async {
      dialHost = host;
      dialPort = port;
      return connection;
    }

    Future<CodewalkTerminalSocketConnection> openConnected({
      Map<String, String>? headers,
      List<int>? trailingBytes,
      int? maxBytes,
    }) async {
      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse(
          'ws://100.64.0.5:4096/pty/pty_1/connect?directory=%2Fproj',
        ),
        headers: headers,
        dial: dial,
        maxIncomingFrameBytes: maxBytes,
      );
      await _pump();
      await _pump();
      await _pump();
      final key = _extractKey(connection.clientToServer.toBytes());
      final response = BytesBuilder(copy: false)..add(_acceptResponse(key));
      if (trailingBytes != null) response.add(trailingBytes);
      connection.peerToClient.add(response.toBytes());
      return pending.timeout(const Duration(seconds: 5));
    }

    test('dials the tailnet host and sends an RFC 6455 handshake', () async {
      final socket = await openConnected(
        headers: const {'Authorization': 'Bearer cached-token'},
      );

      expect(dialHost, '100.64.0.5');
      expect(dialPort, 4096);
      final request = ascii.decode(connection.clientToServer.toBytes());
      expect(
        request,
        startsWith(
          'GET /pty/pty_1/connect?directory=%2Fproj HTTP/1.1\r\n',
        ),
      );
      expect(request, contains('Host: 100.64.0.5:4096\r\n'));
      expect(request, contains('Upgrade: websocket\r\n'));
      expect(request, contains('Connection: Upgrade\r\n'));
      expect(request, contains('Sec-WebSocket-Version: 13\r\n'));
      expect(request, contains('Authorization: Bearer cached-token\r\n'));
      await socket.close();
    });

    test('delivers server binary messages', () async {
      final socket = await openConnected();
      final received = <List<int>>[];
      final subscription = socket.messages.listen(received.add);

      connection.peerToClient.add(_serverFrame(0x2, utf8.encode('hello')));
      await _pump();
      await _pump();

      expect(received, hasLength(1));
      expect(utf8.decode(received.single), 'hello');
      await subscription.cancel();
      await socket.close();
    });

    test('reassembles fragmented messages', () async {
      final socket = await openConnected();
      final received = <List<int>>[];
      final subscription = socket.messages.listen(received.add);

      connection.peerToClient.add(_serverFrame(0x2, utf8.encode('hel'), fin: false));
      await _pump();
      expect(received, isEmpty);
      connection.peerToClient.add(_serverFrame(0x0, utf8.encode('lo')));
      await _pump();
      await _pump();

      expect(received, hasLength(1));
      expect(utf8.decode(received.single), 'hello');
      await subscription.cancel();
      await socket.close();
    });

    test('answers pings with masked pongs', () async {
      final socket = await openConnected();
      final subscription = socket.messages.listen((_) {});

      connection.peerToClient.add(_serverFrame(0x9, [1, 2, 3]));
      await _pump();
      await _pump();

      final written = connection.clientToServer.toBytes();
      final frame = _parseClientFrame(written, _requestEnd(written));
      expect(frame.opcode, 0xA);
      expect(frame.masked, isTrue);
      expect(frame.payload, [1, 2, 3]);
      await subscription.cancel();
      await socket.close();
    });

    test('masks outbound binary sends', () async {
      final socket = await openConnected();

      socket.send(utf8.encode('ls\n'));
      await _pump();
      await _pump();

      final written = connection.clientToServer.toBytes();
      final frame = _parseClientFrame(written, _requestEnd(written));
      expect(frame.opcode, 0x2);
      expect(frame.masked, isTrue);
      expect(utf8.decode(frame.payload), 'ls\n');
      await socket.close();
    });

    test('rejects non-101 handshake responses', () async {
      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse('ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa'),
        dial: dial,
      );
      await _pump();
      await _pump();

      connection.peerToClient.add(
        Uint8List.fromList(
          ascii.encode('HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\n\r\n'),
        ),
      );

      await expectLater(
        pending,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('401'),
          ),
        ),
      );
    });

    test('rejects handshake accept mismatches', () async {
      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse('ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa'),
        dial: dial,
      );
      await _pump();
      await _pump();

      connection.peerToClient.add(
        Uint8List.fromList(
          ascii.encode(
            'HTTP/1.1 101 Switching Protocols\r\n'
            'Upgrade: websocket\r\n'
            'Connection: Upgrade\r\n'
            'Sec-WebSocket-Accept: bogus\r\n\r\n',
          ),
        ),
      );

      await expectLater(pending, throwsA(isA<StateError>()));
    });

    test('supports only ws URLs over the tailnet', () async {
      var dialCalls = 0;
      Future<TailscaleTcpConnection> countingDial(
        String host,
        int port, {
        Duration? timeout,
      }) async {
        dialCalls++;
        return connection;
      }

      await expectLater(
        openCodewalkTerminalSocketViaTailscale(
          url: Uri.parse('wss://100.64.0.5:4096/pty/x/connect?directory=%2Fa'),
          dial: countingDial,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(dialCalls, 0);
    });

    test('close sends a close frame and completes done on echo', () async {
      final socket = await openConnected();

      final closing = socket.close();
      await _pump();
      await _pump();

      final written = connection.clientToServer.toBytes();
      final frame = _parseClientFrame(written, _requestEnd(written));
      expect(frame.opcode, 0x8);
      expect(frame.masked, isTrue);

      connection.peerToClient.add(_serverFrame(0x8, [0x03, 0xE8]));
      await closing.timeout(const Duration(seconds: 5));
      await socket.done.timeout(const Duration(seconds: 5));
    });

    test('peer-initiated close is echoed and completes done', () async {
      final socket = await openConnected();
      final subscription = socket.messages.listen((_) {});

      connection.peerToClient.add(_serverFrame(0x8, [0x03, 0xE8]));
      await socket.done.timeout(const Duration(seconds: 5));

      final written = connection.clientToServer.toBytes();
      final frame = _parseClientFrame(written, _requestEnd(written));
      expect(frame.opcode, 0x8);
      await subscription.cancel();
    });

    test('pumps frames coalesced with the handshake response', () async {
      final socket = await openConnected(
        trailingBytes: _serverFrame(0x2, utf8.encode('hi')),
      );
      final received = <List<int>>[];
      final subscription = socket.messages.listen(received.add);
      await _pump();
      await _pump();

      expect(received, hasLength(1));
      expect(utf8.decode(received.single), 'hi');
      await subscription.cancel();
      await socket.close();
    });

    test('drops pong frames instead of emitting them as data', () async {
      final socket = await openConnected();
      final received = <List<int>>[];
      final subscription = socket.messages.listen(received.add);

      connection.peerToClient.add(_serverFrame(0xA, [9, 9]));
      await _pump();
      await _pump();

      expect(received, isEmpty);
      await subscription.cancel();
      await socket.close();
    });

    test('rejects fragmented messages exceeding the size cap', () async {
      final socket = await openConnected(maxBytes: 10);
      final errors = <Object>[];
      final subscription = socket.messages.listen(
        (_) {},
        onError: errors.add,
      );

      connection.peerToClient.add(_serverFrame(0x2, [1, 2, 3, 4], fin: false));
      await _pump();
      connection.peerToClient.add(
        _serverFrame(0x0, [5, 6, 7, 8, 9, 10], fin: false),
      );
      await _pump();
      connection.peerToClient.add(_serverFrame(0x0, [11]));
      await _pump();
      await _pump();

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      await subscription.cancel();
    });

    test('brackets ipv6 hosts in the handshake Host header', () async {
      final ipv6Connection = _FakeTailscaleTcpConnection();
      String? dialedHost;
      int? dialedPort;
      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse('ws://[fd7a::1]:4096/pty/x/connect?directory=%2Fa'),
        dial: (host, port, {timeout}) async {
          dialedHost = host;
          dialedPort = port;
          return ipv6Connection;
        },
      );
      await _pump();
      await _pump();
      await _pump();
      final key = _extractKey(ipv6Connection.clientToServer.toBytes());
      ipv6Connection.peerToClient.add(_acceptResponse(key));
      final socket = await pending.timeout(const Duration(seconds: 5));

      expect(dialedHost, 'fd7a::1');
      expect(dialedPort, 4096);
      expect(
        ascii.decode(ipv6Connection.clientToServer.toBytes()),
        contains('Host: [fd7a::1]:4096\r\n'),
      );
      await socket.close();
    });

    test('accepts case-insensitive upgrade headers', () async {
      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse('ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa'),
        dial: dial,
      );
      await _pump();
      await _pump();
      await _pump();
      final key = _extractKey(connection.clientToServer.toBytes());
      final accept = base64Encode(
        sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
            .bytes,
      );
      connection.peerToClient.add(
        Uint8List.fromList(
          ascii.encode(
            'HTTP/1.1 101 Switching Protocols\r\n'
            'Upgrade: WebSocket\r\n'
            'Connection: Upgrade\r\n'
            'Sec-WebSocket-Accept: $accept\r\n\r\n',
          ),
        ),
      );

      final socket = await pending.timeout(const Duration(seconds: 5));
      await socket.close();
    });

    test('rejects handshakes missing the connection header', () async {      final pending = openCodewalkTerminalSocketViaTailscale(
        url: Uri.parse('ws://100.64.0.5:4096/pty/x/connect?directory=%2Fa'),
        dial: dial,
      );
      await _pump();
      await _pump();
      await _pump();
      final key = _extractKey(connection.clientToServer.toBytes());
      final accept = base64Encode(
        sha1.convert(utf8.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
            .bytes,
      );
      connection.peerToClient.add(
        Uint8List.fromList(
          ascii.encode(
            'HTTP/1.1 101 Switching Protocols\r\n'
            'Upgrade: websocket\r\n'
            'Sec-WebSocket-Accept: $accept\r\n\r\n',
          ),
        ),
      );

      await expectLater(pending, throwsA(isA<StateError>()));
    });

    test('drops buffered frames after a protocol error', () async {
      final socket = await openConnected();
      final received = <List<int>>[];
      final errors = <Object>[];
      final subscription = socket.messages.listen(
        received.add,
        onError: errors.add,
      );

      final combined = BytesBuilder(copy: false)
        ..add(_serverFrame(0x3, [1]))
        ..add(_serverFrame(0x2, utf8.encode('hi')));
      connection.peerToClient.add(combined.toBytes());
      await _pump();
      await _pump();

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(received, isEmpty);
      await subscription.cancel();
    });

    test('stalled peer-close echo still completes done via grace', () async {
      final socket = await openConnected();
      final subscription = socket.messages.listen((_) {});
      connection.hangWrites = true;

      connection.peerToClient.add(_serverFrame(0x8, [0x03, 0xE8]));
      await socket.done.timeout(const Duration(seconds: 10));

      expect(connection.closed, isTrue);
      await subscription.cancel();
    });

    test('drops data frames buffered after a peer close', () async {
      final socket = await openConnected();
      final received = <List<int>>[];
      final errors = <Object>[];
      final subscription = socket.messages.listen(
        received.add,
        onError: errors.add,
      );

      final combined = BytesBuilder(copy: false)
        ..add(_serverFrame(0x8, [0x03, 0xE8]))
        ..add(_serverFrame(0x2, utf8.encode('hi')));
      connection.peerToClient.add(combined.toBytes());
      await socket.done.timeout(const Duration(seconds: 10));

      expect(errors, isEmpty);
      expect(received, isEmpty);
      await subscription.cancel();
    });
  });
}
