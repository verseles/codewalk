import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:test/test.dart';

import 'fixture_support.dart';

Future<HttpServer> serve(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final subscription = server.listen((request) {
    unawaited(() async {
      try {
        await handler(request);
      } on IOException {
        // Client cancellation closes disposable test sockets intentionally.
      }
    }());
  });
  addTearDown(() async {
    await server.close(force: true);
    await subscription.cancel();
  });
  return server;
}

Uri endpoint(HttpServer server, [String prefix = '/']) =>
    Uri.parse('http://127.0.0.1:${server.port}$prefix');

IoEndpointHttpTransport client(
  Uri uri, {
  EndpointHeaders? headers,
  Duration headerTimeout = const Duration(seconds: 30),
}) {
  final transport = IoEndpointHttpTransport(
    endpoint: uri,
    headers: headers,
    headerTimeout: headerTimeout,
  );
  addTearDown(transport.close);
  return transport;
}

TypeMatcher<TransportException> failure(TransportFailure kind) =>
    isA<TransportException>().having((error) => error.failure, 'failure', kind);

void main() {
  test(
    'two endpoint clients isolate auth, prefixes and request bodies',
    () async {
      final targets = <Uri>[];
      Future<void> echo(HttpRequest request) async {
        final body = await request.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'path': request.uri.toString(),
            'auth': request.headers.value('authorization'),
            'body': body,
          }),
        );
        await request.response.close();
      }

      final firstServer = await serve(echo);
      final secondServer = await serve(echo);
      final first = client(
        endpoint(firstServer, '/proxy/v2'),
        headers: (uri) {
          targets.add(uri);
          return {'Authorization': 'Bearer disposable-first'};
        },
      );
      final second = client(
        endpoint(secondServer),
        headers: (_) => {'Authorization': 'Bearer disposable-second'},
      );
      final original = utf8.encode('Olá');
      final request = TransportRequest(
        method: 'POST',
        path: '/echo/%2Fvalue?x=a%20b',
        headers: {'authorization': 'caller-value'},
        body: original,
      );
      original[0] = 0;
      final replies = await Future.wait([
        first.send(request),
        second.send(TransportRequest(method: 'GET', path: 'echo')),
      ]);
      final a = jsonDecode(utf8.decode(await replies[0].readBytes()));
      final b = jsonDecode(utf8.decode(await replies[1].readBytes()));
      expect(a['path'], '/proxy/v2/echo/%2Fvalue?x=a%20b');
      expect(a['auth'], 'Bearer disposable-first');
      expect(a['body'], utf8.encode('Olá'));
      expect(b['path'], '/echo');
      expect(b['auth'], 'Bearer disposable-second');
      expect(targets.single.origin, endpoint(firstServer).origin);
      expect(targets.single.query, isNot(contains('disposable-first')));
      expect(() => request.body![0] = 1, throwsUnsupportedError);
    },
  );

  test('invalid routes never evaluate auth or connect', () async {
    var requests = 0;
    var authCalls = 0;
    final server = await serve((request) async {
      requests++;
      await request.response.close();
    });
    final transport = client(
      endpoint(server, '/prefix/'),
      headers: (_) {
        authCalls++;
        return {'Authorization': 'private'};
      },
    );
    for (final path in [
      'https://foreign.example/value',
      '//foreign.example/value',
      '../outside',
      '%2e%2e/outside',
      '/value#fragment',
      'http://user:private@foreign.example/',
    ]) {
      await expectLater(
        transport.send(TransportRequest(method: 'GET', path: path)),
        throwsA(failure(TransportFailure.invalidTarget)),
      );
    }
    expect(authCalls, 0);
    expect(requests, 0);
  });

  test('escaped traversal never evaluates auth or connects', () async {
    var requests = 0;
    var authCalls = 0;
    final server = await serve((request) async {
      requests++;
      await request.response.close();
    });
    final transport = client(
      endpoint(server, '/prefix/'),
      headers: (_) {
        authCalls++;
        return {'Authorization': 'private'};
      },
    );
    for (final path in [
      '%2e%2e%2foutside',
      '%2E%2E%2Foutside',
      '%2e%2e%5coutside',
      'safe%2f..%2foutside',
      'safe%5c..%5coutside',
      'safe/%2e%2e%2foutside',
      'safe/%2e%2e%5coutside',
      'safe%2f.%2foutside',
      'safe%5c.%5coutside',
    ]) {
      await expectLater(
        transport.send(TransportRequest(method: 'GET', path: path)),
        throwsA(failure(TransportFailure.invalidTarget)),
        reason: path,
      );
    }
    expect(authCalls, 0);
    expect(requests, 0);
  });

  test(
    'invalid endpoints and Host override cannot change auth origin',
    () async {
      for (final uri in [
        'ftp://host/',
        'http://user:private@host/',
        'http://host/?secret=private',
        'http://host/#fragment',
      ]) {
        expect(
          () => IoEndpointHttpTransport(endpoint: Uri.parse(uri)),
          throwsA(failure(TransportFailure.invalidTarget)),
        );
      }
      var requests = 0;
      final server = await serve((request) async {
        requests++;
        await request.response.close();
      });
      final transport = client(endpoint(server));
      await expectLater(
        transport.send(
          TransportRequest(
            method: 'GET',
            path: '/',
            headers: {'hOsT': 'foreign.example'},
          ),
        ),
        throwsA(failure(TransportFailure.invalidRequest)),
      );
      expect(requests, 0);
    },
  );

  test(
    'redirect returns original status without forwarding credentials',
    () async {
      var foreignRequests = 0;
      final foreign = await serve((request) async {
        foreignRequests++;
        await request.response.close();
      });
      final redirect = await serve((request) async {
        request.response.statusCode = 302;
        request.response.headers.set(
          'location',
          endpoint(foreign).resolve('foreign'),
        );
        await request.response.close();
      });
      final transport = client(
        endpoint(redirect),
        headers: (_) => {'Authorization': 'Bearer disposable-bound-token'},
      );
      final response = await transport.send(
        TransportRequest(method: 'GET', path: 'redirect'),
      );
      expect(response.statusCode, 302);
      expect(
        response.header('location'),
        endpoint(foreign).resolve('foreign').toString(),
      );
      expect(await response.readBytes(), isEmpty);
      expect(foreignRequests, 0);
    },
  );

  test(
    '401 fixture and 503 status/header/body survive without projection',
    () async {
      final auth = jsonDecode(
        File('${captureFixtures().path}/auth-pairing.json').readAsStringSync(),
      );
      final unauthorized = (auth['requests'] as List).firstWhere(
        (entry) => entry['path'] == '/api/info' && entry['status'] == 401,
      )['response'];
      final server = await serve((request) async {
        final starting = request.uri.path == '/starting';
        request.response.statusCode = starting ? 503 : 401;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('retry-after', '1');
        request.response.write(
          starting ? '{"code":"service_starting"}' : jsonEncode(unauthorized),
        );
        await request.response.close();
      });
      final transport = client(endpoint(server));
      final denied = await transport.send(
        TransportRequest(method: 'GET', path: 'denied'),
      );
      expect(denied.statusCode, 401);
      expect(jsonDecode(utf8.decode(await denied.readBytes())), unauthorized);
      final starting = await transport.send(
        TransportRequest(method: 'GET', path: 'starting'),
      );
      expect(starting.statusCode, 503);
      expect(starting.header('Retry-After'), '1');
      expect(
        utf8.decode(await starting.readBytes()),
        '{"code":"service_starting"}',
      );
    },
  );

  test('raw entity bytes are not transparently decompressed', () async {
    final encoded = gzip.encode(utf8.encode('raw compressed entity'));
    final server = await serve((request) async {
      request.response.headers.set('content-encoding', 'gzip');
      request.response.add(encoded);
      await request.response.close();
    });
    final response = await client(
      endpoint(server),
    ).send(TransportRequest(method: 'GET', path: 'gzip'));
    expect(await response.readBytes(), encoded);
  });

  test(
    'body limit rejects bytes before retaining the oversized chunk',
    () async {
      final server = await serve((request) async {
        request.response.write('0123456789');
        await request.response.close();
      });
      final response = await client(
        endpoint(server),
      ).send(TransportRequest(method: 'GET', path: 'large'));
      await expectLater(
        response.readBytes(maxBytes: 9),
        throwsA(failure(TransportFailure.bodyTooLarge)),
      );
    },
  );

  test('cancellation before send invokes neither auth nor HTTP', () async {
    var authCalls = 0;
    final transport = client(
      Uri.parse('http://127.0.0.1:1/'),
      headers: (_) {
        authCalls++;
        return {};
      },
    );
    final signal = RequestCancellation()..cancel();
    await expectLater(
      transport.send(
        TransportRequest(method: 'GET', path: '/'),
        cancellation: signal,
      ),
      throwsA(failure(TransportFailure.cancelled)),
    );
    expect(authCalls, 0);
  });

  test(
    'cancel while auth resolves prevents late header callback from sending',
    () async {
      var requests = 0;
      final authStarted = Completer<void>();
      final authResult = Completer<Map<String, String>>();
      final server = await serve((request) async {
        requests++;
        await request.response.close();
      });
      final transport = client(
        endpoint(server),
        headers: (_) {
          authStarted.complete();
          return authResult.future;
        },
      );
      final signal = RequestCancellation();
      final pending = transport.send(
        TransportRequest(method: 'GET', path: 'slow-auth'),
        cancellation: signal,
      );
      final assertion = expectLater(
        pending,
        throwsA(failure(TransportFailure.cancelled)),
      );
      await authStarted.future;
      signal.cancel();
      await assertion;
      authResult.complete({'Authorization': 'private-late'});
      await Future<void>.delayed(Duration.zero);
      expect(requests, 0);
    },
  );

  test('header timeout aborts a real stalled request', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final server = await serve((request) async {
      entered.complete();
      await release.future;
      await request.response.close();
    });
    final transport = client(
      endpoint(server),
      headerTimeout: const Duration(milliseconds: 100),
    );
    final pending = transport.send(
      TransportRequest(method: 'GET', path: 'stall'),
    );
    final assertion = expectLater(
      pending,
      throwsA(failure(TransportFailure.timeout)),
    );
    await entered.future;
    await assertion;
    release.complete();
  });

  test(
    'cancel during streaming aborts body consumption with typed failure',
    () async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final server = await serve((request) async {
        request.response.bufferOutput = false;
        request.response.add(utf8.encode('first'));
        await request.response.flush();
        await release.future;
        request.response.add(utf8.encode('late'));
        await request.response.close();
      });
      final transport = client(endpoint(server));
      final signal = RequestCancellation();
      final response = await transport.send(
        TransportRequest(method: 'GET', path: 'stream'),
        cancellation: signal,
      );
      final reader = StreamIterator(response.body);
      expect(
        await reader.moveNext().timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw StateError('Initial streaming bytes not delivered'),
        ),
        isTrue,
      );
      expect(utf8.decode(reader.current), 'first');
      signal.cancel();
      await expectLater(
        reader.moveNext().timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw StateError('Cancelled streaming body not settled'),
        ),
        throwsA(failure(TransportFailure.cancelled)),
      );
      await reader.cancel().timeout(const Duration(seconds: 2));
      release.complete();
    },
  );

  test('body inactivity timeout releases stalled entity', () async {
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final server = await serve((request) async {
      request.response.bufferOutput = false;
      request.response.add(utf8.encode('first'));
      await request.response.flush();
      await release.future;
      await request.response.close();
    });
    final response = await client(
      endpoint(server),
    ).send(TransportRequest(method: 'GET', path: 'body-stall'));
    await expectLater(
      response.readBytes(inactivityTimeout: const Duration(milliseconds: 100)),
      throwsA(failure(TransportFailure.timeout)),
    );
    release.complete();
  });

  test(
    'subscription cancellation releases a live body without closing endpoint',
    () async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final server = await serve((request) async {
        request.response.bufferOutput = false;
        request.response.add(utf8.encode('first'));
        await request.response.flush();
        if (request.uri.path == '/stream') await release.future;
        await request.response.close();
      });
      final transport = client(endpoint(server));
      final response = await transport.send(
        TransportRequest(method: 'GET', path: 'stream'),
      );
      final reader = StreamIterator(response.body);
      expect(
        await reader.moveNext().timeout(const Duration(seconds: 2)),
        isTrue,
      );
      await reader.cancel().timeout(const Duration(seconds: 2));
      expect(transport.isClosed, isFalse);
      final next = await transport.send(
        TransportRequest(method: 'GET', path: 'next'),
      );
      expect(utf8.decode(await next.readBytes()), 'first');
      release.complete();
    },
  );

  test('unconsumed body cancellation settles subsequent consumption', () async {
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final server = await serve((request) async {
      request.response.bufferOutput = false;
      request.response.add(utf8.encode('first'));
      await request.response.flush();
      await release.future;
      await request.response.close();
    });
    final response = await client(
      endpoint(server),
    ).send(TransportRequest(method: 'GET', path: 'unread'));
    response.cancel();
    await expectLater(
      response.readBytes().timeout(const Duration(seconds: 2)),
      throwsA(failure(TransportFailure.cancelled)),
    );
    release.complete();
  });

  test(
    'closing one endpoint cannot interrupt another endpoint live body',
    () async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      Future<void> streaming(HttpRequest request) async {
        request.response.bufferOutput = false;
        request.response.add(utf8.encode('first'));
        await request.response.flush();
        await release.future;
        request.response.add(utf8.encode('late'));
        await request.response.close();
      }

      final first = client(endpoint(await serve(streaming)));
      final second = client(endpoint(await serve(streaming)));
      final responses = await Future.wait([
        first.send(TransportRequest(method: 'GET', path: 'stream')),
        second.send(TransportRequest(method: 'GET', path: 'stream')),
      ]);
      final a = StreamIterator(responses[0].body);
      final b = StreamIterator(responses[1].body);
      expect(await a.moveNext().timeout(const Duration(seconds: 2)), isTrue);
      expect(await b.moveNext().timeout(const Duration(seconds: 2)), isTrue);
      first.close();
      await expectLater(
        a.moveNext().timeout(const Duration(seconds: 2)),
        throwsA(failure(TransportFailure.closed)),
      );
      release.complete();
      expect(await b.moveNext().timeout(const Duration(seconds: 2)), isTrue);
      expect(utf8.decode(b.current), 'late');
      expect(await b.moveNext().timeout(const Duration(seconds: 2)), isFalse);
      await a.cancel();
      await b.cancel();
    },
  );

  test(
    'close aborts pending request and prevents reuse; repeated close is safe',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final server = await serve((request) async {
        entered.complete();
        await release.future;
        await request.response.close();
      });
      final transport = client(endpoint(server));
      final pending = transport.send(
        TransportRequest(method: 'GET', path: 'pending'),
      );
      final assertion = expectLater(
        pending,
        throwsA(failure(TransportFailure.closed)),
      );
      await entered.future;
      transport.close();
      transport.close();
      await assertion;
      expect(transport.isClosed, isTrue);
      await expectLater(
        transport.send(TransportRequest(method: 'GET', path: 'next')),
        throwsA(failure(TransportFailure.closed)),
      );
      release.complete();
    },
  );

  test(
    'safe failures do not echo sensitive header callback diagnostics',
    () async {
      final transport = client(
        Uri.parse('http://127.0.0.1:1/'),
        headers: (_) {
          throw StateError('private-sensitive-value');
        },
      );
      await expectLater(
        transport.send(TransportRequest(method: 'GET', path: '/')),
        throwsA(
          failure(TransportFailure.connection).having(
            (error) => error.toString(),
            'diagnostic',
            isNot(contains('private-sensitive-value')),
          ),
        ),
      );
    },
  );

  test(
    'actual local SSE replays observed A frames without native/model calls',
    () async {
      final fixtures = captureFixtures();
      final bytes = File('${fixtures.path}/events.sse').readAsBytesSync();
      final expected = jsonDecode(
        File('${fixtures.path}/events.json').readAsStringSync(),
      );
      final server = await serve((request) async {
        expect(request.headers.value('accept'), 'text/event-stream');
        expect(
          request.headers.value('authorization'),
          'Bearer disposable-stream',
        );
        request.response.headers.set(
          'content-type',
          'text/event-stream; charset=utf-8',
        );
        for (var index = 0; index < bytes.length; index += 13) {
          request.response.add(
            bytes.sublist(
              index,
              index + 13 < bytes.length ? index + 13 : bytes.length,
            ),
          );
          await request.response.flush();
        }
        await request.response.close();
      });
      final transport = client(
        endpoint(server),
        headers: (_) => {'Authorization': 'Bearer disposable-stream'},
      );
      final stream = await openSseStream(transport, 'events');
      final frames = await stream.toList();
      expect(frames.map((frame) => jsonDecode(frame.data)).toList(), expected);
    },
  );

  test(
    'SSE rejects wrong media type and HTTP error without reading as events',
    () async {
      final server = await serve((request) async {
        request.response.statusCode = request.uri.path == '/denied' ? 401 : 200;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html>public shell</html>');
        await request.response.close();
      });
      final transport = client(endpoint(server));
      await expectLater(
        openSseStream(transport, 'html'),
        throwsA(failure(TransportFailure.unsupportedContentType)),
      );
      await expectLater(
        openSseStream(transport, 'denied'),
        throwsA(
          failure(
            TransportFailure.unexpectedStatus,
          ).having((error) => error.statusCode, 'status', 401),
        ),
      );
    },
  );
}
