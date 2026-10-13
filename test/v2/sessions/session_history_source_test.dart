@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:codewalk/platform/sessions/session_history_factory_io.dart';
import 'package:codewalk/shared/sessions/session_history_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in EndpointAuthKind.values) {
    test(
      'native $kind probes actual version before each scoped read; drift rejects cursor',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var version = '2.0.22';
        var reads = 0;
        final paths = <String>[];
        server.listen((r) async {
          expect(r.method, 'GET');
          expect(
            r.headers.value('authorization'),
            'Basic ${base64Encode(utf8.encode('opencode:fake-secret'))}',
          );
          paths.add(r.uri.path);
          r.response.headers.contentType = ContentType.json;
          if (r.uri.path == '/proxy/api/info') {
            r.response.write(
              jsonEncode({
                'version': version,
                'pid': 1,
                'urls': [],
                'paths': {'tmp': '/tmp'},
              }),
            );
          } else {
            expect(r.uri.path, '/proxy/api/session/ses_one/message');
            expect(r.uri.queryParameters['limit'], '50');
            expect(r.uri.queryParameters['order'], reads == 0 ? 'asc' : null);
            if (reads > 0) {
              expect(r.uri.queryParameters['cursor'], 'opaque+/?=終');
            }
            reads++;
            r.response.write(
              jsonEncode({
                'data': [
                  {
                    'id': 'msg_$reads',
                    'type': 'user',
                    'time': {'created': 1000},
                    'text': 'record $reads',
                  },
                ],
                'cursor': {'next': reads == 1 ? 'opaque+/?=終' : 'later'},
              }),
            );
          }
          await r.response.close();
        });
        final p = EndpointProfile(
          id: 'profile_one',
          label: 'One',
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/proxy/'),
        );
        const ref = SessionRef(
          HostId('profile_one'),
          HarnessInstanceId('profile_one'),
          'ses_one',
        );
        final source = createSessionHistorySource(
          p,
          EndpointCredential(kind: kind, secret: 'fake-secret'),
          ref,
        );
        addTearDown(source.close);
        final first = await source.read().result;
        expect(first.version, version);
        expect(first.page.items.single.source.version, version);
        await source.read(cursor: first.page.nextCursor).result;
        version = '2.0.23';
        await expectLater(
          source.read(cursor: first.page.nextCursor).result,
          throwsA(
            isA<SessionHistoryException>().having(
              (e) => e.failure,
              'failure',
              SessionHistoryFailure.sourceChanged,
            ),
          ),
        );
        expect(reads, 2);
        expect(paths.last, '/proxy/api/info');
      },
    );
  }
  test(
    'cancellation aborts a hanging info probe without any history GET',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final arrived = Completer<void>();
      server.listen((r) {
        expect(r.uri.path, '/api/info');
        arrived.complete();
      });
      final p = EndpointProfile(
        id: 'profile_one',
        label: 'One',
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final source = createSessionHistorySource(
        p,
        EndpointCredential(kind: EndpointAuthKind.password, secret: 'fake'),
        const SessionRef(
          HostId('profile_one'),
          HarnessInstanceId('profile_one'),
          'ses_one',
        ),
      );
      addTearDown(source.close);
      final task = source.read();
      final result = expectLater(
        task.result,
        throwsA(
          isA<SessionHistoryException>().having(
            (e) => e.failure,
            'failure',
            SessionHistoryFailure.cancelled,
          ),
        ),
      );
      await arrived.future;
      task.cancel();
      await result;
    },
  );
  test(
    'probe deadline remains timeout rather than explicit cancellation',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((r) {
        expect(r.uri.path, '/api/info');
      });
      final p = EndpointProfile(
        id: 'profile_one',
        label: 'One',
        endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      );
      final source = createSessionHistorySource(
        p,
        EndpointCredential(kind: EndpointAuthKind.password, secret: 'fake'),
        const SessionRef(
          HostId('profile_one'),
          HarnessInstanceId('profile_one'),
          'ses_one',
        ),
      );
      addTearDown(source.close);
      await expectLater(
        source.read().result,
        throwsA(
          isA<SessionHistoryException>().having(
            (e) => e.failure,
            'failure',
            SessionHistoryFailure.timeout,
          ),
        ),
      );
    },
  );
}
