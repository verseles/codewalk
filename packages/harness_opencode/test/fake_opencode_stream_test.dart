import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:test/test.dart';

import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

final fixtures = OpenCodeFixtures();

Future<(FakeOpenCodeServer, IoEndpointHttpTransport)> serve(
  FixtureScenario scenario,
) async {
  final server = await FakeOpenCodeServer.start(
    scenario: scenario,
    fixtures: fixtures,
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

Future<void> replay(
  EndpointHttpTransport client,
  FixtureExchange exchange,
) async {
  final response = await client.send(
    TransportRequest(
      method: exchange.method,
      path: exchange.target.toString(),
      body: exchange.request == null
          ? null
          : utf8.encode(jsonEncode(exchange.request)),
    ),
  );
  expect(response.statusCode, exchange.status, reason: exchange.source);
  final text = utf8.decode(await response.readBytes());
  if (exchange.status == 204) {
    expect(text, isEmpty);
  } else {
    expect(jsonDecode(text), exchange.response, reason: exchange.source);
  }
}

void main() {
  test(
    'A SSE is manually published and preserves every accepted event',
    () async {
      final (server, client) = await serve(fixtures.observedA());
      final stream = await openSseStream(client, '/api/event');
      final received = stream.toList();
      final connection = server.streams.single;
      expect(connection.emittedFrames, 0);
      await connection.emitRemaining();
      await connection.finish();
      final frames = await received;
      final expected = jsonDecode(
        File('${fixtures.root.path}/events.json').readAsStringSync(),
      );
      expect(frames.map((frame) => jsonDecode(frame.data)).toList(), expected);
      expect(frames.every((frame) => frame.id == null), isTrue);
      expect(connection.emitNext, throwsStateError);
      final next = await client.send(
        TransportRequest(
          method: 'GET',
          path: '/api/event',
          headers: {'Last-Event-ID': 'not-a-replay-cursor'},
        ),
      );
      expect(next.statusCode, 409);
      await next.readBytes();
    },
  );

  test(
    'B delta EOF, disconnected hydration and new live epoch do not replay missed events',
    () async {
      final scenario = fixtures.reconnect();
      final (server, client) = await serve(scenario);
      final capture =
          jsonDecode(
                File(
                  '${fixtures.root.path}/b/disconnect-reconnect.json',
                ).readAsStringSync(),
              )
              as Map;
      for (final exchange in scenario.exchanges.take(2)) {
        await replay(client, exchange);
      }
      final first = await openSseStream(client, '/api/event');
      final partialResult = first.toList();
      await server.streams[0].emitRemaining();
      await server.streams[0].finish();
      final partial = (await partialResult)
          .map((frame) => jsonDecode(frame.data))
          .toList();
      expect(partial, (capture['partialStream'] as Map)['events']);
      expect((partial.last as Map)['type'], 'session.text.delta');
      for (final exchange in scenario.exchanges.sublist(2, 8)) {
        await replay(client, exchange);
      }
      final reconnected = await openSseStream(
        client,
        '/api/event',
        headers: {'Last-Event-ID': (partial.last as Map)['id'] as String},
      );
      final events = <Object?>[];
      final connected = Completer<void>();
      final done = Completer<void>();
      final subscription = reconnected.listen(
        (frame) {
          events.add(jsonDecode(frame.data));
          if (!connected.isCompleted) connected.complete();
        },
        onError: done.completeError,
        onDone: done.complete,
      );
      final settled = done.future;
      await server.streams[1].emitNext();
      await connected.future;
      expect(events, capture['eventsBeforeNewMutation']);
      await replay(client, scenario.exchanges[8]);
      await server.streams[1].emitRemaining();
      for (final exchange in scenario.exchanges.skip(9)) {
        await replay(client, exchange);
      }
      await server.streams[1].finish();
      await settled;
      await subscription.cancel();
      expect(events, (capture['reconnectedStream'] as Map)['events']);
      expect(events.map((event) => (event as Map)['type']), [
        'server.connected',
        'session.renamed',
      ]);
      expect(server.completedExchanges, 13);
    },
  );

  for (final scenario in [
    fixtures.permissionOnce(),
    fixtures.formReply(),
    fixtures.formDismiss(),
  ]) {
    test(
      '${scenario.name} streams only its observed native interaction identity',
      () async {
        final (server, client) = await serve(scenario);
        final stream = await openSseStream(client, '/api/event');
        final received = stream.toList();
        for (final exchange in scenario.exchanges) {
          await replay(client, exchange);
        }
        await server.streams.single.emitRemaining();
        await server.streams.single.finish();
        final events = (await received)
            .map((frame) => jsonDecode(frame.data) as Map)
            .toList();
        expect(events, hasLength(2));
        if (scenario.name.contains('permission')) {
          expect(events.map((event) => event['type']), [
            'permission.asked',
            'permission.replied',
          ]);
          expect((events.last['data'] as Map)['reply'], 'once');
        } else {
          expect(events.first['type'], 'form.created');
          expect(
            events.last['type'],
            scenario.name.endsWith('reply') ? 'form.replied' : 'form.cancelled',
          );
          final nativeForm =
              ((scenario.exchanges[1].response as Map)['data'] as Map);
          expect((events.first['data'] as Map)['form'], nativeForm);
        }
      },
    );
  }

  test(
    'targeted EOF on one connection leaves another recorded epoch writable',
    () async {
      final (server, client) = await serve(fixtures.reconnect());
      final firstStream = await openSseStream(client, '/api/event');
      final first = firstStream.toList();
      final secondStream = await openSseStream(client, '/api/event');
      final second = secondStream.toList();
      await server.streams[0].emitNext();
      await server.streams[0].finish();
      expect(await first, hasLength(1));
      expect(server.streams[1].isClosed, isFalse);
      await server.streams[1].emitRemaining();
      await server.streams[1].finish();
      expect(await second, hasLength(2));
    },
  );

  test(
    'teardown settles a suspended stream without a background failure',
    () async {
      final (server, client) = await serve(fixtures.observedA());
      final stream = await openSseStream(client, '/api/event');
      final consumed = stream.toList().then<void>(
        (_) {},
        onError: (Object error) {
          expect(error, isA<TransportException>());
        },
      );
      await server.close();
      await consumed;
      await server.close();
      server.assertHealthy();
    },
  );
}
