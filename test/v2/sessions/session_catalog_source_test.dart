import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codewalk/platform/sessions/session_catalog_factory_io.dart';
import 'package:codewalk/platform/sessions/session_catalog_factory_stub.dart'
    as stub;
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in EndpointAuthKind.values) {
    test(
      'native bridge authenticates $kind and preserves proxy/port/opaque paging',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var requests = 0;
        server.listen((request) async {
          expect(request.method, 'GET');
          expect(request.uri.path, '/proxy/api/session');
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Basic ${base64Encode(utf8.encode('opencode:fake-secret'))}',
          );
          expect(request.uri.queryParameters['limit'], '50');
          if (requests++ == 0) {
            expect(request.uri.queryParameters['order'], 'desc');
          } else {
            expect(request.uri.queryParameters['cursor'], 'opaque+/%?=終');
            expect(request.uri.queryParameters.containsKey('order'), isFalse);
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': requests == 1
                  ? [
                      {
                        'id': 'ses_one',
                        'title': 'Real bridge',
                        'time': {'created': 1000, 'updated': 2000},
                        'location': {'directory': '/not-a-canonical-project'},
                      },
                    ]
                  : [],
              'cursor': requests == 1 ? {'next': 'opaque+/%?=終'} : {},
            }),
          );
          await request.response.close();
        });
        final profile = EndpointProfile(
          id: 'profile_a',
          label: 'Native',
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/proxy/'),
        );
        final source = createSessionCatalogSource(
          profile,
          EndpointCredential(kind: kind, secret: 'fake-secret'),
        );
        addTearDown(source.close);
        final first = await source.list(SessionQuery()).result;
        expect(first.items.single.info.ref.harnessRef, source.harness);
        // The server's canonical directory is the project identity.
        expect(
          first.items.single.info.project?.canonicalDirectory,
          '/not-a-canonical-project',
        );
        expect(first.items.single.execution, isNull);
        final next = await source
            .list(SessionQuery(cursor: first.nextCursor))
            .result;
        expect(next.items, isEmpty);
        expect(requests, 2);
        source.close();
        source.close();
        await expectLater(
          source.list(SessionQuery()).result,
          throwsA(
            isA<SessionCatalogException>().having(
              (e) => e.failure,
              'failure',
              SessionCatalogFailure.cancelled,
            ),
          ),
        );
        expect(requests, 2);
      },
    );
  }

  for (final entry in {
    401: SessionCatalogFailure.authenticationRequired,
    429: SessionCatalogFailure.rateLimited,
    502: SessionCatalogFailure.unavailable,
  }.entries) {
    test(
      'status ${entry.key} maps safely without replay or raw response',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var calls = 0;
        server.listen((request) async {
          calls++;
          request.response.statusCode = entry.key;
          request.response.write('private native error body');
          await request.response.close();
        });
        final source = createSessionCatalogSource(
          EndpointProfile(
            id: 'profile_a',
            label: 'Native',
            endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
          ),
          EndpointCredential(
            kind: EndpointAuthKind.password,
            secret: 'fake-secret',
          ),
        );
        addTearDown(source.close);
        await expectLater(
          source.list(SessionQuery()).result,
          throwsA(
            isA<SessionCatalogException>()
                .having((e) => e.failure, 'failure', entry.value)
                .having(
                  (e) => e.toString(),
                  'safe text',
                  isNot(contains('private')),
                ),
          ),
        );
        expect(calls, 1);
      },
    );
  }

  test(
    'cancel and close settle owned reads without waiting for server response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<void>();
      server.listen((request) => received.complete());
      final source = createSessionCatalogSource(
        EndpointProfile(
          id: 'profile_a',
          label: 'Native',
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
        ),
        EndpointCredential(
          kind: EndpointAuthKind.password,
          secret: 'fake-secret',
        ),
      );
      addTearDown(source.close);
      final task = source.list(SessionQuery());
      final assertion = expectLater(
        task.result,
        throwsA(
          isA<SessionCatalogException>().having(
            (e) => e.failure,
            'failure',
            SessionCatalogFailure.cancelled,
          ),
        ),
      );
      await received.future;
      task.cancel();
      await assertion.timeout(const Duration(seconds: 2));
    },
  );

  test('unsupported source opens no transport', () async {
    final source = stub.createSessionCatalogSource(
      EndpointProfile(
        id: 'profile_a',
        label: 'Unsupported',
        endpoint: Uri.parse('https://example.invalid/'),
      ),
      EndpointCredential(
        kind: EndpointAuthKind.password,
        secret: 'fake-secret',
      ),
    );
    await expectLater(
      source.list(SessionQuery()).result,
      throwsA(
        isA<SessionCatalogException>().having(
          (e) => e.failure,
          'failure',
          SessionCatalogFailure.unsupportedPlatform,
        ),
      ),
    );
    source.close();
  });
}
