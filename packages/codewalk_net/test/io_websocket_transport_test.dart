import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

Future<HttpServer> server(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) {
    unawaited(handler(request).catchError((Object _) {}));
  });
  addTearDown(() async {
    await server.close(force: true);
    await subscription.cancel();
  });
  return server;
}

Uri base(HttpServer server) => Uri.parse('http://127.0.0.1:${server.port}/');

IoEndpointWebSocketTransport client(
  Uri uri, {
  EndpointHeaders? headers,
  Duration timeout = const Duration(seconds: 2),
  int maxBytes = 1024,
}) {
  final transport = IoEndpointWebSocketTransport(
    endpoint: uri,
    headers: headers,
    handshakeTimeout: timeout,
    maxMessageBytes: maxBytes,
  );
  addTearDown(transport.close);
  return transport;
}

void main() {
  test('authenticated text/binary echo, prefix and explicit cleanup', () async {
    String? authorization;
    String? path;
    final host = await server((request) async {
      authorization = request.headers.value('authorization');
      path = request.uri.path;
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen(socket.add);
    });
    final endpoint = base(host).resolve('proxy/');
    final transport = client(
      endpoint,
      headers: basicEndpointHeaders(
        endpoint: endpoint,
        username: 'opencode',
        secret: () => 'pair-token',
      ),
    );
    final socket = await transport.connect('/api/pty');
    final events = StreamIterator(socket.messages);
    await socket.sendText('olá 😀');
    expect(await events.moveNext(), isTrue);
    expect((events.current as WebSocketText).text, 'olá 😀');
    await socket.sendBytes([1, 2, 3]);
    expect(await events.moveNext(), isTrue);
    expect((events.current as WebSocketBinary).bytes, [1, 2, 3]);
    expect(path, '/proxy/api/pty');
    expect(
      authorization,
      'Basic ${base64Encode(utf8.encode('opencode:pair-token'))}',
    );
    await socket.close();
    await events.cancel();
    expect(socket.isClosed, isTrue);
  });

  test(
    'redirect never contacts foreign target and invalid route never looks up auth',
    () async {
      var foreignRequests = 0;
      var auth = 0;
      final foreign = await server((request) async {
        foreignRequests++;
        await request.response.close();
      });
      final host = await server((request) async {
        request.response.statusCode = 302;
        request.response.headers.set('location', base(foreign));
        await request.response.close();
      });
      final transport = client(
        base(host),
        headers: (_) {
          auth++;
          return {'authorization': 'private'};
        },
      );
      await expectLater(
        transport.connect('%2e%2e%2foutside'),
        throwsA(isA<TransportException>()),
      );
      await expectLater(
        transport.connect('%252e%252e%252foutside'),
        throwsA(isA<TransportException>()),
      );
      expect(auth, 0);
      await expectLater(
        transport.connect('ws'),
        throwsA(
          isA<TransportException>().having((e) => e.statusCode, 'status', 302),
        ),
      );
      expect(auth, 1);
      expect(foreignRequests, 0);
    },
  );

  test(
    'deadline includes slow credential lookup and no late request occurs',
    () async {
      var requests = 0;
      final host = await server((request) async {
        requests++;
        await request.response.close();
      });
      final secret = Completer<Map<String, String>>();
      final transport = client(
        base(host),
        headers: (_) => secret.future,
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        transport.connect('ws'),
        throwsA(
          isA<TransportException>().having(
            (e) => e.failure,
            'failure',
            TransportFailure.timeout,
          ),
        ),
      );
      secret.complete({'authorization': 'private'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, 0);
    },
  );

  test(
    'cancellation aborts a pending upgrade and an established socket',
    () async {
      final arrived = Completer<void>();
      final host = await server((request) async {
        arrived.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await request.response.close();
      });
      final token = RequestCancellation();
      final transport = client(base(host));
      final attempt = transport.connect('ws', cancellation: token);
      final expectation = expectLater(
        attempt,
        throwsA(
          isA<TransportException>().having(
            (e) => e.failure,
            'failure',
            TransportFailure.cancelled,
          ),
        ),
      );
      await arrived.future;
      token.cancel();
      await expectation;

      final echo = await server((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(socket.add);
      });
      final liveToken = RequestCancellation();
      final live = await client(
        base(echo),
      ).connect('ws', cancellation: liveToken);
      final streamError = expectLater(
        live.messages,
        emitsError(isA<TransportException>()),
      );
      liveToken.cancel();
      await streamError;
      expect(live.isClosed, isTrue);
    },
  );

  test(
    'coalesced 101 and first frame survive public detachSocket handoff',
    () async {
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      raw.listen((socket) {
        sockets.add(socket);
        var headers = '';
        var upgraded = false;
        socket.listen((bytes) {
          if (upgraded) return;
          headers += ascii.decode(bytes);
          if (!headers.contains('\r\n\r\n')) return;
          upgraded = true;
          final key = RegExp(
            r'sec-websocket-key: ([^\r]+)',
            caseSensitive: false,
          ).firstMatch(headers)!.group(1)!;
          final accept = base64Encode(
            sha1
                .convert(
                  ascii.encode('${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11'),
                )
                .bytes,
          );
          socket.add([
            ...ascii.encode(
              'HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Accept: $accept\r\n\r\n',
            ),
            0x81,
            2,
            104,
            105,
          ]);
        }, onError: (Object _) {});
      });
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await raw.close();
      });
      final socket = await client(
        Uri.parse('http://127.0.0.1:${raw.port}/'),
      ).connect('ws');
      expect((await socket.messages.first as WebSocketText).text, 'hi');
      await socket.close();
    },
  );
}
