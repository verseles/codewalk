import 'dart:async';
import 'dart:convert';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:test/test.dart';

import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

final fixtures = OpenCodeFixtures();

Future<(FakeOpenCodeServer, IoEndpointHttpTransport)> serve(
  FixtureScenario scenario, {
  int maxRequestBytes = 64 * 1024,
  int maxRequests = 256,
}) async {
  final server = await FakeOpenCodeServer.start(
    scenario: scenario,
    fixtures: fixtures,
    maxRequestBytes: maxRequestBytes,
    maxRequests: maxRequests,
  );
  final client = IoEndpointHttpTransport(
    endpoint: server.endpoint,
    headers: (_) => {'Authorization': server.auth.authorization()},
  );
  addTearDown(() async {
    try {
      await server.close();
    } finally {
      client.close();
    }
  });
  return (server, client);
}

TransportRequest requestFor(FixtureExchange exchange) => TransportRequest(
  method: exchange.method,
  path: exchange.target.toString(),
  headers: {'content-type': 'application/json'},
  body: exchange.request == null
      ? null
      : utf8.encode(jsonEncode(exchange.request)),
);

Future<({int status, String text})> send(
  EndpointHttpTransport client,
  TransportRequest request,
) async {
  final response = await client.send(request);
  return (
    status: response.statusCode,
    text: utf8.decode(await response.readBytes()),
  );
}

Future<Object?> replay(
  EndpointHttpTransport client,
  FixtureExchange exchange,
) async {
  final result = await send(client, requestFor(exchange));
  expect(result.status, exchange.status, reason: exchange.source);
  if (exchange.status == 204) {
    expect(result.text, isEmpty, reason: exchange.source);
    return null;
  }
  final decoded = jsonDecode(result.text);
  expect(decoded, exchange.response, reason: exchange.source);
  return decoded;
}

void main() {
  test(
    'authenticated info preserves the native payload, not the fake URL',
    () async {
      final (server, client) = await serve(FixtureScenario('info'));
      final result = await send(
        client,
        TransportRequest(method: 'GET', path: '/api/info'),
      );
      expect(result.status, 200);
      expect(jsonDecode(result.text), fixtures.info);
      expect(server.endpoint.host, '127.0.0.1');
      expect(server.endpoint.port, greaterThan(0));
      expect(server.completedExchanges, 0);
    },
  );

  test(
    'missing, redacted, Bearer and wrong-user credentials are rejected',
    () async {
      final (server, _) = await serve(FixtureScenario('auth'));
      final client = IoEndpointHttpTransport(endpoint: server.endpoint);
      addTearDown(client.close);
      for (final auth in <String?>[
        null,
        server.auth.authorization('[REDACTED]'),
        'Bearer ${server.auth.bootstrapPassword}',
        'Basic ${base64Encode(utf8.encode('other:${server.auth.bootstrapPassword}'))}',
      ]) {
        final response = await send(
          client,
          TransportRequest(
            method: 'GET',
            path: '/api/info',
            headers: {'authorization': ?auth},
          ),
        );
        expect(response.status, 401);
        expect(jsonDecode(response.text), {
          '_tag': 'UnauthorizedError',
          'message': 'Authentication required',
        });
      }
    },
  );

  test(
    'pairing is single-use; renewed tokens coexist and remain instance-local',
    () async {
      final (first, client) = await serve(FixtureScenario('pairing'));
      final (second, _) = await serve(FixtureScenario('other'));
      final anonymous = IoEndpointHttpTransport(endpoint: first.endpoint);
      final other = IoEndpointHttpTransport(endpoint: second.endpoint);
      addTearDown(anonymous.close);
      addTearDown(other.close);
      final tokens = <String>[];
      for (var index = 0; index < 2; index++) {
        final pair = await send(
          index == 0 ? client : anonymous,
          TransportRequest(
            method: 'POST',
            path: '/api/pair',
            headers: {
              if (index != 0)
                'authorization': first.auth.authorization(tokens.first),
            },
          ),
        );
        expect(pair.status, 200);
        final body = jsonDecode(pair.text) as Map;
        expect(body['expires_in'], 300);
        expect(body['code'], startsWith('fake-test-'));
        final redemption = TransportRequest(
          method: 'GET',
          path: '/auth/connect/${body['code']}',
        );
        final results = await Future.wait([
          send(anonymous, redemption),
          send(anonymous, redemption),
        ]);
        expect(
          results.map((result) => result.status),
          unorderedEquals([200, 401]),
        );
        tokens.add(
          (jsonDecode(results.singleWhere((r) => r.status == 200).text)
                  as Map)['token']
              as String,
        );
      }
      expect(tokens[0], isNot(tokens[1]));
      for (final token in tokens) {
        final request = TransportRequest(
          method: 'GET',
          path: '/api/info',
          headers: {'authorization': first.auth.authorization(token)},
        );
        expect((await send(anonymous, request)).status, 200);
        expect((await send(other, request)).status, 401);
      }
    },
  );

  test('pairing expiry uses the exact five-minute manual boundary', () async {
    final (server, client) = await serve(FixtureScenario('expiry'));
    final anonymous = IoEndpointHttpTransport(endpoint: server.endpoint);
    addTearDown(anonymous.close);
    Future<TransportRequest> pair() async {
      final response = await send(
        client,
        TransportRequest(method: 'POST', path: '/api/pair'),
      );
      return TransportRequest(
        method: 'GET',
        path: '/auth/connect/${(jsonDecode(response.text) as Map)['code']}',
      );
    }

    final nearExpiry = await pair();
    server.auth.advance(
      const Duration(minutes: 5) - const Duration(microseconds: 1),
    );
    expect((await send(anonymous, nearExpiry)).status, 200);
    final expired = await pair();
    server.auth.advance(const Duration(minutes: 5));
    expect((await send(anonymous, expired)).status, 401);
    expect((await send(anonymous, expired)).status, 401);
  });

  test(
    'B replay is deterministic, correlated and independent on two fresh servers',
    () async {
      final scenario = fixtures.admission();
      final firstTrace = <Object?>[];
      for (var run = 0; run < 2; run++) {
        final (server, client) = await serve(scenario);
        final trace = <Object?>[];
        for (final exchange in scenario.exchanges) {
          trace.add(await replay(client, exchange));
        }
        expect(server.completedExchanges, 13);
        expect(trace[0], trace[1]);
        expect(trace[0], trace[2]);
        expect(trace[3], trace[4]);
        expect(trace[3], trace[5]);
        expect(trace[3], trace[6]);
        expect(scenario.exchanges[8].status, 409);
        expect(((trace[11] as Map)['data'] as List), hasLength(2));
        expect((trace[12] as Map)['data'], isEmpty);
        if (run == 0) {
          firstTrace.addAll(trace);
        } else {
          expect(trace, firstTrace);
        }
        expect(
          (await send(client, requestFor(scenario.exchanges.last))).status,
          409,
        );
      }
    },
  );

  test(
    'mismatches cannot consume a pending before-admission fault or exchange',
    () async {
      final scenario = fixtures.lostCreate();
      final (server, client) = await serve(scenario);
      final first = scenario.exchanges.first;
      server.failNextExchange();
      for (final request in [
        TransportRequest(method: 'GET', path: first.target.toString()),
        TransportRequest(method: 'POST', path: '/api/session/unknown'),
        TransportRequest(
          method: first.method,
          path: '${first.target}?extra=1',
          body: utf8.encode(jsonEncode(first.request)),
        ),
        TransportRequest(
          method: first.method,
          path: first.target.toString(),
          body: utf8.encode(
            jsonEncode({...first.request as Map, 'extra': null}),
          ),
        ),
      ]) {
        final response = await send(client, request);
        expect(response.status, 409);
        expect(jsonDecode(response.text), {
          '_tag': 'FakeScenarioMismatch',
          'synthetic': true,
        });
        expect(server.completedExchanges, 0);
      }
      expect((await send(client, requestFor(first))).status, 503);
      expect(server.completedExchanges, 0);
      for (final exchange in scenario.exchanges) {
        await replay(client, exchange);
      }
      expect(server.completedExchanges, 3);
      expect(
        server.observations.where((o) => o.kind == 'before-admission-fault'),
        hasLength(1),
      );
    },
  );

  test(
    'JSON key order is irrelevant but missing and null fields remain distinct',
    () async {
      final scenario = fixtures.lostCreate();
      final (server, client) = await serve(scenario);
      final exchange = scenario.exchanges.first;
      final reversed = Map.fromEntries(
        (exchange.request as Map).entries.toList().reversed,
      );
      final response = await send(
        client,
        TransportRequest(
          method: exchange.method,
          path: exchange.target.toString(),
          body: utf8.encode(jsonEncode(reversed)),
        ),
      );
      expect(response.status, 200);
      expect(jsonDecode(response.text), exchange.response);
      final lookup = scenario.exchanges[1];
      expect(
        (await send(
          client,
          TransportRequest(
            method: 'GET',
            path: lookup.target.toString(),
            body: utf8.encode('null'),
          ),
        )).status,
        409,
      );
      expect(server.completedExchanges, 1);
      await replay(client, lookup);
    },
  );

  test(
    'query order is irrelevant; extra and duplicated values fail strictly',
    () async {
      final scenario = fixtures.admission();
      final (server, client) = await serve(scenario);
      for (final exchange in scenario.exchanges.take(12)) {
        await replay(client, exchange);
      }
      final last = scenario.exchanges.last;
      for (final query in [
        'order=asc',
        'limit=200&order=asc&limit=200',
        'order=asc&limit=200&extra=1',
      ]) {
        expect(
          (await send(
            client,
            TransportRequest(method: 'GET', path: '${last.target.path}?$query'),
          )).status,
          409,
        );
        expect(server.completedExchanges, 12);
      }
      final response = await send(
        client,
        TransportRequest(
          method: 'GET',
          path: '${last.target.path}?limit=200&order=asc',
        ),
      );
      expect(response.status, 200);
      expect(jsonDecode(response.text), last.response);
    },
  );

  test(
    'admission occurs before a held response; later reads can reconcile',
    () async {
      final scenario = fixtures.lostCreate();
      final (server, client) = await serve(scenario);
      final gate = server.holdNextExchange();
      final creation = send(client, requestFor(scenario.exchanges.first));
      expect(await gate.admitted, isTrue);
      expect(server.completedExchanges, 1);
      await replay(client, scenario.exchanges[1]);
      gate.release();
      final result = await creation;
      expect(result.status, 200);
      expect(jsonDecode(result.text), scenario.exchanges.first.response);
      await replay(client, scenario.exchanges.last);
    },
  );

  test(
    'cancelled/lost admitted response does not erase captured state',
    () async {
      final scenario = fixtures.lostCreate();
      final (server, client) = await serve(scenario);
      final gate = server.holdNextExchange();
      final cancellation = RequestCancellation();
      final creation = client.send(
        requestFor(scenario.exchanges.first),
        cancellation: cancellation,
      );
      final checked = expectLater(
        creation,
        throwsA(
          isA<TransportException>().having(
            (e) => e.failure,
            'failure',
            TransportFailure.cancelled,
          ),
        ),
      );
      expect(await gate.admitted, isTrue);
      cancellation.cancel();
      await checked;
      gate.drop();
      for (final exchange in scenario.exchanges.skip(1)) {
        await replay(client, exchange);
      }
      expect(server.completedExchanges, 3);
    },
  );

  for (final scenario in [
    fixtures.permissionOnce(),
    fixtures.formReply(),
    fixtures.formDismiss(),
  ]) {
    test(
      '${scenario.name} preserves native interactions and empty 204 replies',
      () async {
        final (server, client) = await serve(scenario);
        for (final exchange in scenario.exchanges) {
          await replay(client, exchange);
        }
        expect(server.completedExchanges, scenario.exchanges.length);
      },
    );
  }

  test('typed form answers are not coerced or accepted out of order', () async {
    final scenario = fixtures.formReply();
    final (server, client) = await serve(scenario);
    final reply = scenario.exchanges[3];
    expect((await send(client, requestFor(reply))).status, 409);
    for (final exchange in scenario.exchanges.take(3)) {
      await replay(client, exchange);
    }
    expect(
      (await send(
        client,
        TransportRequest(
          method: reply.method,
          path: reply.target.toString(),
          body: utf8.encode(
            jsonEncode({
              'answer': {'choice': 'alpha', 'count': 2.0, 'confirmed': true},
            }),
          ),
        ),
      )).status,
      409,
    );
    expect(server.completedExchanges, 3);
    await replay(client, reply);
  });

  test(
    'malformed and oversized bodies fail without admission or payload logging',
    () async {
      final scenario = fixtures.lostCreate();
      final (server, client) = await serve(scenario, maxRequestBytes: 32);
      for (final input in [
        '{',
        jsonEncode({'secret': 'private-value-never-log-1234567890'}),
      ]) {
        final response = await send(
          client,
          TransportRequest(
            method: 'POST',
            path: '/api/session',
            body: utf8.encode(input),
          ),
        );
        expect(response.status, input == '{' ? 400 : 413);
        expect(response.text, isNot(contains('private-value')));
      }
      expect(server.completedExchanges, 0);
      expect(
        server.observations.toString(),
        isNot(contains(server.auth.bootstrapPassword)),
      );
    },
  );

  test(
    'request count is bounded and teardown cancels an unadmitted gate',
    () async {
      final (server, client) = await serve(
        fixtures.lostCreate(),
        maxRequests: 2,
      );
      final gate = server.holdNextExchange();
      final info = TransportRequest(method: 'GET', path: '/api/info');
      expect((await send(client, info)).status, 200);
      expect((await send(client, info)).status, 200);
      expect((await send(client, info)).status, 429);
      await server.close();
      expect(await gate.admitted, isFalse);
      await server.close();
    },
  );

  test('teardown unblocks an admitted response and is idempotent', () async {
    final scenario = fixtures.lostCreate();
    final (server, client) = await serve(scenario);
    final gate = server.holdNextExchange();
    final request = client.send(requestFor(scenario.exchanges.first));
    final checked = expectLater(request, throwsA(isA<TransportException>()));
    expect(await gate.admitted, isTrue);
    await server.close();
    await checked;
    expect(server.isClosed, isTrue);
    await server.close();
    expect(server.holdNextExchange, throwsStateError);
  });
}
