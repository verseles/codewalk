import 'dart:async';
import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

Map<String, Object> info(String version) => {
  'version': version,
  'pid': 0,
  'urls': ['http://not-an-adopted-target/'],
  'paths': {'tmp': '/tmp/observed'},
};

final class ScriptedTransport implements EndpointHttpTransport {
  ScriptedTransport(this.replies);
  final List<({int status, Object? body, String media, String? retry})> replies;
  final paths = <String>[];
  int cancelled = 0;
  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1/proxy/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    paths.add(request.path);
    expect(request.method, 'GET');
    expect(request.headers['Accept'], 'application/json');
    if (cancellation?.isCancelled ?? false) {
      throw const TransportException(TransportFailure.cancelled);
    }
    final reply = replies.removeAt(0);
    return TransportResponse(
      statusCode: reply.status,
      headers: {
        'content-type': [reply.media],
        if (reply.retry != null) 'retry-after': [reply.retry!],
      },
      body: Stream.value(
        utf8.encode(
          reply.media == 'text/html' ? '${reply.body}' : jsonEncode(reply.body),
        ),
      ),
      cancel: () {
        cancelled++;
      },
    );
  }

  @override
  void close() {
    isClosed = true;
  }
}

({int status, Object? body, String media, String? retry}) reply(
  Object? body, {
  int status = 200,
  String media = 'application/json',
  String? retry,
}) => (status: status, body: body, media: media, retry: retry);

void main() {
  test(
    'bounded body and deadline reject responses without extra probes',
    () async {
      final oversized = ScriptedTransport([reply(info('2.0.22'))]);
      expect(
        (await OpenCodeEndpointProbe(
          oversized,
          maxBodyBytes: 8,
        ).detect()).canUse,
        isFalse,
      );
      expect(oversized.paths, ['/api/info']);
      final stalled = StalledTransport();
      final result = await OpenCodeEndpointProbe(
        stalled,
        deadline: const Duration(milliseconds: 30),
      ).detect();
      expect(result.status, EndpointStatus.unreachable);
      expect(stalled.cancelled, isTrue);
      expect(stalled.requests, 1);
    },
  );
  for (final entry in {
    '2.0.19': EndpointStatus.belowMinimum,
    '2.0.20-rc.1': EndpointStatus.belowMinimum,
    '2.0.20': EndpointStatus.untested,
    '2.0.21-rc.1': EndpointStatus.untested,
    '2.0.21': EndpointStatus.compatible,
    '2.0.22+build.999': EndpointStatus.compatible,
    '2.0.22+001': EndpointStatus.compatible,
    '2.0.22+..': EndpointStatus.unrecognized,
    '2.0.22+build..999': EndpointStatus.unrecognized,
    '2.0.22+': EndpointStatus.unrecognized,
    '02.0.22': EndpointStatus.unrecognized,
    '2.0.22-rc.01': EndpointStatus.unrecognized,
    '2.0.22-rc..1': EndpointStatus.unrecognized,
    '2.0.22-rc.1+build.999': EndpointStatus.untested,
    '2.0.23': EndpointStatus.untested,
    '3.0.0': EndpointStatus.untested,
    'invalid-private-url': EndpointStatus.unrecognized,
  }.entries) {
    test('version ${entry.key}: support and test evidence differ', () async {
      final transport = ScriptedTransport([reply(info(entry.key))]);
      final result = await OpenCodeEndpointProbe(transport).detect();
      expect(result.status, entry.value);
      expect(transport.paths, ['/api/info']);
      expect(transport.isClosed, isFalse);
    });
  }

  test(
    'HTML on info does not succeed, health must prove healthy 1.x JSON',
    () async {
      for (final health in [
        reply({'healthy': true, 'version': '1.2.3'}),
        reply({'healthy': true, 'version': '2.0.22'}),
        reply({'healthy': false, 'version': '1.2.3'}),
        reply('<html/>', media: 'text/html'),
      ]) {
        final transport = ScriptedTransport([
          reply('<html/>', media: 'text/html'),
          health,
        ]);
        final result = await OpenCodeEndpointProbe(transport).detect();
        expect(
          result.status,
          health.body is Map &&
                  (health.body as Map)['healthy'] == true &&
                  (health.body as Map)['version'] == '1.2.3'
              ? EndpointStatus.legacyServer
              : EndpointStatus.unrecognized,
        );
        expect(transport.paths, ['/api/info', '/global/health']);
      }
    },
  );

  test(
    '401, redirects and malformed valid JSON never invoke legacy fallback',
    () async {
      for (final response in [
        reply({}, status: 401),
        reply({}, status: 302),
        reply({'version': '2.0.22'}),
      ]) {
        final transport = ScriptedTransport([response]);
        final result = await OpenCodeEndpointProbe(transport).detect();
        expect(
          result.status,
          response.status == 401
              ? EndpointStatus.authenticationRequired
              : EndpointStatus.unrecognized,
        );
        expect(transport.paths, ['/api/info']);
      }
    },
  );

  test(
    'actual not-ready ServerInfo bodies and service-code envelopes remain distinct',
    () async {
      final now = DateTime.utc(2026, 10, 8);
      for (final response in [
        reply(info('2.0.22'), status: 503, retry: '1'),
        reply(info('2.0.22'), status: 500),
        reply({'code': 'service_starting'}, status: 503, retry: '0'),
        reply({'code': 'service_stopping'}, status: 503, retry: '1'),
        reply({'code': 'service_failed'}, status: 503),
      ]) {
        final transport = ScriptedTransport([response]);
        final result = await OpenCodeEndpointProbe(
          transport,
          now: () => now,
        ).detect();
        expect(result.canUse, isFalse);
        expect(transport.paths, ['/api/info']);
        if (response.body is Map &&
            (response.body as Map)['code'] == 'service_starting') {
          expect(result.status, EndpointStatus.serviceStarting);
          expect(result.retryAt, now);
        } else if (response.status == 500) {
          expect(result.status, EndpointStatus.serviceFailed);
        } else if ((response.body as Map)['code'] == null) {
          expect(result.status, EndpointStatus.serviceUnavailable);
        }
      }
    },
  );

  test(
    'Retry-After hint handles dates, range, malformed and no automatic replay',
    () {
      final now = DateTime.utc(2026, 10, 8, 10);
      expect(RetryAfterHint.parse('0', now).at, now);
      expect(
        RetryAfterHint.parse('1', now).at,
        now.add(const Duration(seconds: 1)),
      );
      expect(
        RetryAfterHint.parse('9999999999999999999999999', now).deferred,
        isTrue,
      );
      expect(RetryAfterHint.parse('9' * 500, now).deferred, isTrue);
      expect(RetryAfterHint.parse('0' * 500, now).at, now);
      expect(
        RetryAfterHint.parse('${'0' * 500}1', now).at,
        now.add(const Duration(seconds: 1)),
      );
      expect(RetryAfterHint.parse('${'0' * 500}86401', now).deferred, isTrue);
      expect(RetryAfterHint.parse('${'0' * 500}bad', now).at, isNull);
      expect(RetryAfterHint.parse('-1', now).at, isNull);
      expect(RetryAfterHint.parse('bad', now).at, isNull);
      expect(
        RetryAfterHint.parse('Thu, 08 Oct 2026 10:00:01 GMT', now).at,
        now.add(const Duration(seconds: 1)),
      );
      expect(
        RetryAfterHint.parse('Thursday, 08-Oct-26 10:00:01 GMT', now).at,
        now.add(const Duration(seconds: 1)),
      );
      expect(
        RetryAfterHint.parse('Thu Oct  8 10:00:01 2026', now).at,
        now.add(const Duration(seconds: 1)),
      );
      expect(
        RetryAfterHint.parse('Thu, 08 Oct 2026 09:00:00 GMT', now).at,
        now,
      );
    },
  );

  test('pre-cancelled detection cannot be used or identify a server', () async {
    final token = RequestCancellation()..cancel();
    final transport = ScriptedTransport([]);
    final result = await OpenCodeEndpointProbe(
      transport,
    ).detect(cancellation: token);
    expect(result.status, EndpointStatus.cancelled);
  });

  test(
    'fixture-backed loopback info authenticates without adopting captured URLs',
    () async {
      final fixtures = OpenCodeFixtures();
      final server = await FakeOpenCodeServer.start(
        fixtures: fixtures,
        scenario: fixtures.observedA(),
      );
      final transport = IoEndpointHttpTransport(
        endpoint: server.endpoint,
        headers: basicEndpointHeaders(
          endpoint: server.endpoint,
          username: 'opencode',
          secret: () => server.auth.bootstrapPassword,
        ),
      );
      try {
        final result = await OpenCodeEndpointProbe(transport).detect();
        expect(result.status, EndpointStatus.compatible);
        expect(result.version, '2.0.22');
        expect(transport.endpoint.origin, server.endpoint.origin);
        expect(transport.endpoint.path, '/');
      } finally {
        transport.close();
        await server.close();
      }
    },
  );
}

class StalledTransport implements EndpointHttpTransport {
  int requests = 0;
  bool cancelled = false;
  @override
  final endpoint = Uri.parse('http://127.0.0.1/');
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) {
    requests++;
    final pending = Completer<TransportResponse>();
    cancellation!.onCancel.listen((_) {
      cancelled = true;
      pending.completeError(
        const TransportException(TransportFailure.cancelled),
      );
    });
    return pending.future;
  }

  @override
  void close() {
    isClosed = true;
  }
}
