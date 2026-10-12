import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';
import 'session_reader_test.dart' show TestTransport, response, failure;
import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

void main() {
  test(
    'actual B HTTP history replay uses captured route/query/auth and leaves borrowed transport open',
    () async {
      final fixtures = OpenCodeFixtures();
      final exchange = fixtures.reconnect().exchanges.lastWhere(
        (e) => e.method == 'GET' && e.target.path.endsWith('/message'),
      );
      expect(exchange.target.queryParameters, {'order': 'asc', 'limit': '200'});
      final server = await FakeOpenCodeServer.start(
        fixtures: fixtures,
        scenario: FixtureScenario('B/recorded-history', exchanges: [exchange]),
      );
      addTearDown(server.close);
      final transport = IoEndpointHttpTransport(
        endpoint: server.endpoint,
        headers: (_) => {'Authorization': server.auth.authorization()},
      );
      addTearDown(transport.close);
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      final ref = SessionRef(
        historyHarness.host,
        historyHarness.harness,
        exchange.target.pathSegments[2],
      );
      final page = await reader.readHistory(
        ref,
        sourceVersion: '2.0.22',
        limit: 200,
      );
      expect(page.items, isNotEmpty);
      expect(page.items.whereType<UserInput>(), isNotEmpty);
      expect(
        page.items.every((i) => i.source.harness == historyHarness),
        isTrue,
      );
      expect(page.boundary, isNull);
      expect(server.completedExchanges, 1);
      reader.dispose();
      expect(transport.isClosed, isFalse);
      server.assertHealthy();
    },
  );

  test(
    'native A body through reader retains real continuation and six-item semantic projection',
    () async {
      final fixture = OpenCodeFixtures().observedAHistory;
      final transport = TestTransport((_, _) => response(fixture));
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      addTearDown(reader.dispose);
      final page = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
      );
      expect(page.items, hasLength(6));
      expect(page.nextCursor, isNotNull);
      expect(page.boundary, isNull);
      expect(
        (page.items.last as TurnOutcome).kind.known,
        OutcomeKind.succeeded,
      );
      expect(Uri.parse(transport.requests.single.path).queryParameters, {
        'limit': '50',
        'order': 'asc',
      });
      // This uses the observed body, not an invented captured A exchange wrapper.
    },
  );

  test(
    'server order and multi-item fanout survive empty/short continuation pages',
    () async {
      var calls = 0;
      final transport = TestTransport((request, _) {
        final query = Uri.parse(request.path).queryParameters;
        if (calls++ == 0) {
          expect(query, {'limit': '2', 'order': 'asc'});
          return response(
            historyPage([
              assistant('z', [
                textBlock('first'),
                {'type': 'reasoning', 'text': 'second'},
              ], completed: true),
              message('a', 'user', {'text': 'third'}),
            ], next: 'opaque+/%?=終'),
          );
        }
        expect(query.containsKey('order'), isFalse);
        if (calls == 2) {
          expect(query['cursor'], 'opaque+/%?=終');
          return response(historyPage([], next: 'empty-but-not-exhausted'));
        }
        expect(query['cursor'], 'empty-but-not-exhausted');
        return response(
          historyPage([
            message('last', 'user', {'text': 'last'}),
          ]),
        );
      });
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      addTearDown(reader.dispose);
      final first = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
        limit: 2,
      );
      expect(first.items.map((i) => semanticItem(i)['text']), [
        'first',
        'second',
        'third',
      ]);
      final empty = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
        limit: 2,
        cursor: first.nextCursor,
      );
      expect(empty.items, isEmpty);
      expect(empty.nextCursor, isNotNull);
      final last = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
        limit: 2,
        cursor: empty.nextCursor,
      );
      expect(last.nextCursor, isNull);
      expect(transport.requests, hasLength(3));
    },
  );

  test(
    'history cursors reject foreign session/reader/version/limit/catalog in both directions before network',
    () async {
      final transport = TestTransport(
        (request, _) => response(
          Uri.parse(request.path).path.endsWith('/message')
              ? historyPage([], next: 'native-history')
              : {
                  'data': [],
                  'cursor': {'next': 'native-catalog'},
                },
        ),
      );
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      final foreignReader = OpenCodeSessionReader(
        transport,
        harness: historyHarness,
      );
      addTearDown(reader.dispose);
      addTearDown(foreignReader.dispose);
      final history = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
      );
      final catalog = await reader.listSessions(SessionQuery());
      for (final request in [
        () => reader.readHistory(
          const SessionRef(
            HostId('host-a'),
            HarnessInstanceId('native-a'),
            'ses_other',
          ),
          sourceVersion: '2.0.22',
          cursor: history.nextCursor,
        ),
        () => foreignReader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          cursor: history.nextCursor,
        ),
        () => reader.readHistory(
          historyRef,
          sourceVersion: '2.0.21',
          cursor: history.nextCursor,
        ),
        () => reader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          limit: 20,
          cursor: history.nextCursor,
        ),
        () => reader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          cursor: catalog.nextCursor,
        ),
        () => reader.listSessions(SessionQuery(cursor: history.nextCursor)),
        () => reader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          cursor: 'invalid%%%',
        ),
      ]) {
        await expectLater(
          request(),
          throwsA(failure(OpenCodeSessionReadFailure.invalidCursor)),
        );
      }
      expect(transport.requests, hasLength(2));
    },
  );

  test(
    'invalid source version, native scope and message limit fail before network',
    () async {
      final transport = TestTransport(
        (_, _) => throw StateError('must not send'),
      );
      final reader = OpenCodeSessionReader(
        transport,
        harness: historyHarness,
        maxPageItems: 250,
      );
      addTearDown(reader.dispose);
      for (final version in ['', 'not-a-version', '1.266.0', '2.0.19']) {
        await expectLater(
          reader.readHistory(historyRef, sourceVersion: version),
          throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
        );
      }
      for (final limit in [0, -1, 201]) {
        await expectLater(
          reader.readHistory(historyRef, sourceVersion: '2.0.22', limit: limit),
          throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
        );
      }
      await expectLater(
        reader.readHistory(
          const SessionRef(
            HostId('host-b'),
            HarnessInstanceId('native-a'),
            'ses_a',
          ),
          sourceVersion: '2.0.22',
        ),
        throwsA(failure(OpenCodeSessionReadFailure.invalidScope)),
      );
      await expectLater(
        reader.readHistory(
          const SessionRef(
            HostId('host-a'),
            HarnessInstanceId('native-a'),
            'wrong_prefix',
          ),
          sourceVersion: '2.0.22',
        ),
        throwsA(failure(OpenCodeSessionReadFailure.invalidRequest)),
      );
      expect(transport.requests, isEmpty);
    },
  );

  for (final invalidPage in [
    {'data': [], 'cursor': 4},
    {'data': []},
    historyPage([
      message('same', 'user', {'text': ''}),
      message('same', 'user', {'text': ''}),
    ]),
    historyPage([
      message('a', 'user', {'text': 'ok'}),
      {
        'id': 'not-msg',
        'type': 'user',
        'time': {'created': 1},
        'text': '',
      },
    ]),
    {
      'data': [],
      'cursor': {'previous': 4},
    },
    historyPage([], next: '\u0000' * (16 * 1024)),
    historyPage([], next: String.fromCharCode(0xd800)),
  ]) {
    test(
      'malformed/ambiguous/unsafe continuation page is rejected atomically (${invalidPage.hashCode})',
      () async {
        final transport = TestTransport((_, _) => response(invalidPage));
        final reader = OpenCodeSessionReader(
          transport,
          harness: historyHarness,
        );
        addTearDown(reader.dispose);
        await expectLater(
          reader.readHistory(historyRef, sourceVersion: '2.0.22'),
          throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
        );
        expect(transport.requests, hasLength(1));
      },
    );
  }

  test(
    'non-advancing native cursor is invalid even on an empty page',
    () async {
      final transport = TestTransport(
        (_, _) => response(historyPage([], next: 'repeat')),
      );
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      addTearDown(reader.dispose);
      final page = await reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
      );
      await expectLater(
        reader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          cursor: page.nextCursor,
        ),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
    },
  );

  test(
    'encoded native session path stays one segment and endpoint mutation invalidates reads',
    () async {
      final native = 'ses_opaque/?%';
      final transport = TestTransport((request, _) {
        expect(Uri.parse(request.path).pathSegments, [
          'api',
          'session',
          native,
          'message',
        ]);
        return response(historyPage([]));
      });
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      addTearDown(reader.dispose);
      await reader.readHistory(
        SessionRef(historyHarness.host, historyHarness.harness, native),
        sourceVersion: '2.0.22',
      );
      transport.endpoint = Uri.parse('http://127.0.0.1/other/');
      await expectLater(
        reader.readHistory(historyRef, sourceVersion: '2.0.22'),
        throwsA(failure(OpenCodeSessionReadFailure.invalidScope)),
      );
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'configured message/body/projection limits stay independent and typed',
    () async {
      final transport = TestTransport(
        (_, _) => response(
          historyPage([
            assistant('a', [
              textBlock('text'),
              {'type': 'reasoning', 'text': 'reason'},
            ]),
          ]),
        ),
      );
      final reader = OpenCodeSessionReader(
        transport,
        harness: historyHarness,
        maxHistoryItems: 1,
      );
      addTearDown(reader.dispose);
      await expectLater(
        reader.readHistory(historyRef, sourceVersion: '2.0.22', limit: 1),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
      final bounded = OpenCodeSessionReader(
        transport,
        harness: historyHarness,
        maxBodyBytes: 32,
      );
      addTearDown(bounded.dispose);
      await expectLater(
        bounded.readHistory(historyRef, sourceVersion: '2.0.22'),
        throwsA(failure(OpenCodeSessionReadFailure.bodyTooLarge)),
      );
      expect(
        () => OpenCodeSessionReader(
          transport,
          harness: historyHarness,
          maxHistoryItems: 0,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'cancellation/dispose settle every owned operation and cancel late responses, not transport or parent',
    () async {
      final replies = <Completer<TransportResponse>>[];
      final transport = TestTransport((_, _) {
        final reply = Completer<TransportResponse>();
        replies.add(reply);
        return reply.future;
      });
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      final parent = RequestCancellation();
      final history = reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
        cancellation: parent,
      );
      final catalog = reader.listSessions(SessionQuery());
      final expectedHistory = expectLater(
        history,
        throwsA(failure(OpenCodeSessionReadFailure.closed)),
      );
      final expectedCatalog = expectLater(
        catalog,
        throwsA(failure(OpenCodeSessionReadFailure.closed)),
      );
      reader.dispose();
      await Future.wait([expectedHistory, expectedCatalog]);
      expect(parent.isCancelled, isFalse);
      expect(transport.isClosed, isFalse);
      var cancellations = 0;
      for (final reply in replies) {
        reply.complete(
          response(historyPage([]), cancel: () => cancellations++),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(cancellations, 2);
      reader.dispose();
      await expectLater(
        reader.readHistory(historyRef, sourceVersion: '2.0.22'),
        throwsA(failure(OpenCodeSessionReadFailure.closed)),
      );
      expect(replies, hasLength(2));
    },
  );

  test(
    'pre-cancelled caller never sends; in-flight cancel does not cancel a sibling read',
    () async {
      final responseGate = Completer<TransportResponse>();
      final transport = TestTransport(
        (request, _) => Uri.parse(request.path).path.endsWith('/message')
            ? responseGate.future
            : response({'data': [], 'cursor': {}}),
      );
      final reader = OpenCodeSessionReader(transport, harness: historyHarness);
      addTearDown(reader.dispose);
      final preCancelled = RequestCancellation()..cancel();
      await expectLater(
        reader.readHistory(
          historyRef,
          sourceVersion: '2.0.22',
          cancellation: preCancelled,
        ),
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      expect(transport.requests, isEmpty);
      final signal = RequestCancellation();
      final read = reader.readHistory(
        historyRef,
        sourceVersion: '2.0.22',
        cancellation: signal,
      );
      final assertion = expectLater(
        read,
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      signal.cancel();
      await assertion;
      expect((await reader.listSessions(SessionQuery())).items, isEmpty);
      responseGate.complete(response(historyPage([])));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'total deadline rejects header wait and closes late response without replay',
    () async {
      final gate = Completer<TransportResponse>();
      final transport = TestTransport((_, _) => gate.future);
      final reader = OpenCodeSessionReader(
        transport,
        harness: historyHarness,
        deadline: const Duration(milliseconds: 15),
      );
      addTearDown(reader.dispose);
      await expectLater(
        reader.readHistory(historyRef, sourceVersion: '2.0.22'),
        throwsA(failure(OpenCodeSessionReadFailure.timeout)),
      );
      var cancelled = false;
      gate.complete(response(historyPage([]), cancel: () => cancelled = true));
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(transport.requests, hasLength(1));
    },
  );
}
