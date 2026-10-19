import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

const harness = HarnessRef(HostId('host-a'), HarnessInstanceId('native-a'));
SessionRef ref(String id) => SessionRef(harness.host, harness.harness, id);

// Hand-authored, source-shaped pages; these are not new native recordings.
Map<String, Object?> row(String id, {String? title}) => {
  'id': id,
  'projectID': 'global',
  'time': {'created': 1000, 'updated': 2000},
  'location': {'directory': '/project'},
  'title': ?title,
};
Map<String, Object?> page(List<Object?> rows, {Object? next}) => {
  'data': rows,
  'cursor': {'next': ?next},
};

final class TestTransport implements EndpointHttpTransport {
  TestTransport(this.handle);
  final FutureOr<TransportResponse> Function(
    TransportRequest,
    RequestCancellation?,
  )
  handle;
  final requests = <TransportRequest>[];
  @override
  Uri endpoint = Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    expect(request.method, 'GET');
    expect(request.body, isNull);
    expect(request.headers, {'Accept': 'application/json'});
    return handle(request, cancellation);
  }

  @override
  void close() => isClosed = true;
}

TransportResponse response(
  Object? body, {
  int status = 200,
  String media = 'application/json',
  void Function()? cancel,
}) => TransportResponse(
  statusCode: status,
  headers: {
    'content-type': [media],
  },
  body: Stream.value(utf8.encode(jsonEncode(body))),
  cancel: cancel ?? () {},
);

Matcher failure(OpenCodeSessionReadFailure kind) =>
    isA<OpenCodeSessionReadException>().having(
      (e) => e.failure,
      'failure',
      kind,
    );

void main() {
  test(
    'server order, metadata unknowns and reader-bound opaque paging',
    () async {
      const nativeCursor = 'native+opaque/%?=終';
      var calls = 0;
      final transport = TestTransport((request, _) {
        final query = Uri.parse(request.path).queryParameters;
        expect(query['limit'], '50');
        if (calls++ == 0) {
          expect(query['order'], 'desc');
          expect(query.containsKey('cursor'), isFalse);
          return response(
            page([row('ses_z'), row('ses_a')], next: nativeCursor),
          );
        }
        expect(query['cursor'], nativeCursor);
        expect(query.containsKey('order'), isFalse);
        return response(page([]));
      });
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final first = await reader.listSessions(SessionQuery());
      expect(first.items.map((item) => item.info.ref.nativeId), [
        'ses_z',
        'ses_a',
      ]);
      expect(first.items.first.info.title, '');
      // The server's canonical directory is the project identity; the
      // upstream project id stays an annotation.
      expect(first.items.first.info.project?.canonicalDirectory, '/project');
      expect(first.items.first.info.project?.upstreamProjectId, 'global');
      expect(first.items.first.info.ownership.kind, OwnershipKind.unknown);
      expect(first.items.first.execution, isNull);
      expect(first.boundary, isNull);
      expect(first.nextCursor, isNot(nativeCursor));
      final second = await reader.listSessions(
        SessionQuery(cursor: first.nextCursor),
      );
      expect(second.items, isEmpty);
      expect(second.nextCursor, isNull);
      expect(transport.requests, hasLength(2));
      reader.dispose();
      expect(transport.isClosed, isFalse);
    },
  );

  test(
    'unsupported filters, foreign refs and foreign cursors never send',
    () async {
      final transport = TestTransport(
        (_, _) => response(page([], next: 'next')),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      for (final query in [
        SessionQuery(activeOnly: true),
        SessionQuery(project: const ProjectRef(HostId('host-a'), '/project')),
        SessionQuery(limit: 201),
      ]) {
        await expectLater(
          reader.listSessions(query),
          throwsA(failure(OpenCodeSessionReadFailure.unsupportedQuery)),
        );
      }
      await expectLater(
        reader.readSession(
          const SessionRef(
            HostId('host-b'),
            HarnessInstanceId('native-a'),
            'ses_same',
          ),
        ),
        throwsA(failure(OpenCodeSessionReadFailure.invalidScope)),
      );
      expect(transport.requests, isEmpty);
      final cursor = (await reader.listSessions(SessionQuery())).nextCursor;
      final other = OpenCodeSessionReader(transport, harness: harness);
      await expectLater(
        other.listSessions(SessionQuery(cursor: cursor)),
        throwsA(failure(OpenCodeSessionReadFailure.invalidCursor)),
      );
      expect(transport.requests, hasLength(1));
      reader.dispose();
      other.dispose();
    },
  );

  test(
    'metadata keeps lineage and through boundary without inventing item IDs',
    () async {
      final transport = TestTransport(
        (_, _) => response({
          'data': {
            ...row('ses_child', title: 'child'),
            'parentID': 'ses_parent',
            'fork': {
              'sessionID': 'ses_source',
              'boundary': {'type': 'through', 'messageID': 'msg_native'},
            },
            'metadata': {'apiKey': 'never-retained'},
            'providerState': {'password': 'never-retained'},
          },
        }),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final result = await reader.readSession(ref('ses_child'));
      expect(result.info.lineage.parent, ref('ses_parent'));
      expect(result.info.lineage.fork!.source, ref('ses_source'));
      expect(result.info.lineage.fork!.beforeItem, isNull);
      final metadata = result.info.metadata!.toJson() as Map;
      expect(metadata['nativeForkBoundary'], {
        'type': 'through',
        'messageId': 'msg_native',
      });
      expect(metadata.containsKey('cost'), isFalse);
      expect(jsonEncode(metadata), isNot(contains('never-retained')));
      expect(
        result.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      );
      reader.dispose();
    },
  );

  test('opaque session path is encoded exactly once', () async {
    const id = 'ses_a/b%2F?終';
    final transport = TestTransport((request, _) {
      expect(Uri.parse(request.path).pathSegments, ['api', 'session', id]);
      return response({'data': row(id)});
    });
    final reader = OpenCodeSessionReader(transport, harness: harness);
    expect((await reader.readSession(ref(id))).info.ref, ref(id));
    reader.dispose();
  });

  test(
    'malformed rows, duplicates, limits and identity mismatch fail whole read',
    () async {
      for (final body in [
        page([
          row('ses_a'),
          {'id': 'ses_bad'},
        ]),
        page([row('ses_a'), row('ses_a')]),
        page([
          {...row('ses_a'), 'title': 2},
        ]),
        page([
          {
            ...row('ses_a'),
            'time': {'updated': 1e20},
          },
        ]),
        {
          'data': [],
          'cursor': {'next': 42},
        },
        {'data': []},
      ]) {
        final reader = OpenCodeSessionReader(
          TestTransport((_, _) => response(body)),
          harness: harness,
        );
        await expectLater(
          reader.listSessions(SessionQuery()),
          throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
        );
        reader.dispose();
      }
      final reader = OpenCodeSessionReader(
        TestTransport((_, _) => response({'data': row('ses_other')})),
        harness: harness,
      );
      await expectLater(
        reader.readSession(ref('ses_wanted')),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
      reader.dispose();
    },
  );

  for (final entry in {
    400: OpenCodeSessionReadFailure.invalidRequest,
    401: OpenCodeSessionReadFailure.authenticationRequired,
    403: OpenCodeSessionReadFailure.authenticationRequired,
    404: OpenCodeSessionReadFailure.notFound,
    408: OpenCodeSessionReadFailure.timeout,
    429: OpenCodeSessionReadFailure.rateLimited,
    500: OpenCodeSessionReadFailure.unavailable,
    502: OpenCodeSessionReadFailure.unavailable,
    503: OpenCodeSessionReadFailure.unavailable,
    504: OpenCodeSessionReadFailure.unavailable,
    302: OpenCodeSessionReadFailure.incompatibleResponse,
  }.entries) {
    test(
      'HTTP ${entry.key} is distinct, sanitized and never retried',
      () async {
        final transport = TestTransport(
          (_, _) =>
              response({'error': 'password-private-url'}, status: entry.key),
        );
        final reader = OpenCodeSessionReader(transport, harness: harness);
        try {
          await reader.readSession(ref('ses_a'));
          fail('Expected a typed read failure.');
        } on OpenCodeSessionReadException catch (error) {
          expect(error.failure, entry.value);
          expect(error.statusCode, entry.key);
          expect('$error', isNot(contains('password-private-url')));
        }
        expect(transport.requests, hasLength(1));
        reader.dispose();
      },
    );
  }

  test('official custom session IDs need no generated underscore', () async {
    final data = {
      ...row('sesCustom'),
      'parentID': 'sesParent',
      'fork': {
        'sessionID': 'sesSource',
        'boundary': {'type': 'before', 'messageID': 'msg_native'},
      },
    };
    final transport = TestTransport((request, _) {
      final uri = Uri.parse(request.path);
      return response(
        uri.path == 'api/session' ? page([data]) : {'data': data},
      );
    });
    final reader = OpenCodeSessionReader(transport, harness: harness);
    final listed = (await reader.listSessions(SessionQuery())).items.single;
    final detail = await reader.readSession(ref('sesCustom'));
    for (final summary in [listed, detail]) {
      expect(summary.info.ref, ref('sesCustom'));
      expect(summary.info.lineage.parent, ref('sesParent'));
      expect(summary.info.lineage.fork!.source, ref('sesSource'));
      expect(summary.info.lineage.fork!.beforeItem, isNull);
    }
    reader.dispose();
  });

  test('HTML and oversized bodies are not empty successful pages', () async {
    final html = OpenCodeSessionReader(
      TestTransport((_, _) => response({}, media: 'text/html')),
      harness: harness,
    );
    await expectLater(
      html.listSessions(SessionQuery()),
      throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
    );
    html.dispose();
    final oversized = OpenCodeSessionReader(
      TestTransport((_, _) => response(page([row('ses_a')]))),
      harness: harness,
      maxBodyBytes: 8,
    );
    await expectLater(
      oversized.listSessions(SessionQuery()),
      throwsA(failure(OpenCodeSessionReadFailure.bodyTooLarge)),
    );
    oversized.dispose();
  });

  test(
    'caller cancellation bounds an uncooperative request and cleans late response',
    () async {
      final late = Completer<TransportResponse>();
      final transport = TestTransport((_, _) => late.future);
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final parent = RequestCancellation();
      final result = reader.readSession(ref('ses_a'), cancellation: parent);
      final assertion = expectLater(
        result,
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      parent.cancel();
      await assertion;
      var cancelled = 0;
      late.complete(
        response({'data': row('ses_a')}, cancel: () => cancelled++),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, 1);
      expect(transport.isClosed, isFalse);
      reader.dispose();
    },
  );

  test(
    'dispose cancels only owned operation, not parent or transport',
    () async {
      final late = Completer<TransportResponse>();
      final transport = TestTransport((_, _) => late.future);
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final parent = RequestCancellation();
      final result = reader.readSession(ref('ses_a'), cancellation: parent);
      final assertion = expectLater(
        result,
        throwsA(failure(OpenCodeSessionReadFailure.closed)),
      );
      reader.dispose();
      await assertion;
      expect(parent.isCancelled, isFalse);
      expect(transport.isClosed, isFalse);
      late.completeError(StateError('private-cause'));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('total deadline bounds headers that ignore cancellation', () async {
    final late = Completer<TransportResponse>();
    final transport = TestTransport((_, _) => late.future);
    final parent = RequestCancellation();
    final reader = OpenCodeSessionReader(
      transport,
      harness: harness,
      deadline: const Duration(milliseconds: 20),
    );
    await expectLater(
      reader.readSession(ref('ses_a'), cancellation: parent),
      throwsA(failure(OpenCodeSessionReadFailure.timeout)),
    );
    expect(parent.isCancelled, isFalse);
    late.complete(response({'data': row('ses_a')}));
    await Future<void>.delayed(Duration.zero);
    reader.dispose();
  });

  test(
    'cancellation during body and endpoint switch fence late results',
    () async {
      final body = StreamController<List<int>>();
      final parent = RequestCancellation();
      final transport = TestTransport(
        (_, _) => TransportResponse(
          statusCode: 200,
          headers: {
            'content-type': ['application/json'],
          },
          body: body.stream,
          cancel: () {},
        ),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final result = reader.listSessions(SessionQuery(), cancellation: parent);
      final assertion = expectLater(
        result,
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      await Future<void>.delayed(Duration.zero);
      parent.cancel();
      await assertion;
      body.add(utf8.encode(jsonEncode(page([]))));
      await body.close();
      reader.dispose();
      final switched = TestTransport((_, _) => response(page([])));
      final other = OpenCodeSessionReader(switched, harness: harness);
      switched.endpoint = Uri.parse('http://127.0.0.1/other/');
      await expectLater(
        other.listSessions(SessionQuery()),
        throwsA(failure(OpenCodeSessionReadFailure.invalidScope)),
      );
      expect(switched.requests, isEmpty);
      other.dispose();
    },
  );

  test(
    'pre-cancelled and disposed reads do not contact the transport',
    () async {
      final transport = TestTransport((_, _) => response(page([])));
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final parent = RequestCancellation()..cancel();
      await expectLater(
        reader.listSessions(SessionQuery(), cancellation: parent),
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      reader.dispose();
      await expectLater(
        reader.readSession(ref('ses_a')),
        throwsA(failure(OpenCodeSessionReadFailure.closed)),
      );
      expect(transport.requests, isEmpty);
      expect(transport.isClosed, isFalse);
    },
  );

  test(
    'a successful sibling read does not cancel the shared caller signal',
    () async {
      final late = Completer<TransportResponse>();
      final transport = TestTransport((request, _) {
        if (Uri.parse(request.path).pathSegments.last == 'ses_a') {
          return response({'data': row('ses_a')});
        }
        return late.future;
      });
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final parent = RequestCancellation();
      final first = reader.readSession(ref('ses_a'), cancellation: parent);
      final second = reader.readSession(ref('ses_b'), cancellation: parent);
      expect((await first).info.ref, ref('ses_a'));
      expect(parent.isCancelled, isFalse);
      final assertion = expectLater(
        second,
        throwsA(failure(OpenCodeSessionReadFailure.cancelled)),
      );
      parent.cancel();
      await assertion;
      late.complete(response({'data': row('ses_b')}));
      await Future<void>.delayed(Duration.zero);
      reader.dispose();
    },
  );

  test('total deadline still fires while body bytes keep arriving', () async {
    final body = StreamController<List<int>>();
    late Timer trickle;
    final transport = TestTransport(
      (_, _) => TransportResponse(
        statusCode: 200,
        headers: {
          'content-type': ['application/json'],
        },
        body: body.stream,
        cancel: () {
          trickle.cancel();
          if (!body.isClosed) unawaited(body.close());
        },
      ),
    );
    final reader = OpenCodeSessionReader(
      transport,
      harness: harness,
      deadline: const Duration(milliseconds: 40),
    );
    trickle = Timer.periodic(const Duration(milliseconds: 5), (_) {
      if (!body.isClosed) body.add([32]);
    });
    try {
      await expectLater(
        reader.listSessions(SessionQuery()),
        throwsA(failure(OpenCodeSessionReadFailure.timeout)),
      );
    } finally {
      trickle.cancel();
      reader.dispose();
      if (!body.isClosed) await body.close();
    }
  });

  test(
    'an endpoint switched during a read cannot publish its response',
    () async {
      final late = Completer<TransportResponse>();
      final transport = TestTransport((_, _) => late.future);
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final result = reader.readSession(ref('ses_a'));
      final assertion = expectLater(
        result,
        throwsA(failure(OpenCodeSessionReadFailure.invalidScope)),
      );
      transport.endpoint = Uri.parse('http://127.0.0.1/new-endpoint/');
      late.complete(response({'data': row('ses_a')}));
      await assertion;
      reader.dispose();
    },
  );

  test(
    'repeated native cursors and malformed caller tokens do not restart paging',
    () async {
      final transport = TestTransport(
        (_, _) => response(page([], next: 'same')),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      final next = (await reader.listSessions(SessionQuery())).nextCursor;
      await expectLater(
        reader.listSessions(SessionQuery(cursor: next)),
        throwsA(failure(OpenCodeSessionReadFailure.incompatibleResponse)),
      );
      await expectLater(
        reader.listSessions(SessionQuery(cursor: 'not-a-reader-cursor')),
        throwsA(failure(OpenCodeSessionReadFailure.invalidCursor)),
      );
      expect(transport.requests, hasLength(2));
      reader.dispose();
    },
  );

  test(
    'accepted B metadata GET replays over authenticated native IO transport',
    () async {
      final fixtures = OpenCodeFixtures();
      final exchange = fixtures.reconnect().exchanges.firstWhere(
        (e) =>
            e.method == 'GET' &&
            e.status == 200 &&
            RegExp(r'^/api/session/ses_[^/]+$').hasMatch(e.target.path),
      );
      final server = await FakeOpenCodeServer.start(
        fixtures: fixtures,
        scenario: FixtureScenario(
          'read-only observed B metadata',
          exchanges: [exchange],
        ),
      );
      final transport = IoEndpointHttpTransport(
        endpoint: server.endpoint,
        headers: basicEndpointHeaders(
          endpoint: server.endpoint,
          username: 'opencode',
          secret: () => server.auth.bootstrapPassword,
        ),
      );
      final reader = OpenCodeSessionReader(transport, harness: harness);
      try {
        final native = (exchange.response as Map)['data'] as Map;
        final result = await reader.readSession(ref(native['id'] as String));
        expect(result.info.ref.nativeId, native['id']);
        expect(result.info.title, native['title']);
        expect(result.info.ownership.kind, OwnershipKind.unknown);
        expect(transport.isClosed, isFalse);
      } finally {
        reader.dispose();
        transport.close();
        await server.close();
      }
    },
  );
}
