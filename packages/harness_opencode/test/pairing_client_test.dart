import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'support/fake_opencode_server.dart';
import 'support/fixture_replay.dart';

final class _Script implements EndpointHttpTransport {
  _Script(this.endpoint, this.queue, this.requests);
  @override
  final Uri endpoint;
  final List<({int status, Object body, String media})> queue;
  final List<TransportRequest> requests;
  @override
  bool isClosed = false;
  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) async {
    requests.add(request);
    if (cancellation?.isCancelled == true) {
      throw const TransportException(TransportFailure.cancelled);
    }
    final reply = queue.removeAt(0);
    return TransportResponse(
      statusCode: reply.status,
      headers: {
        'content-type': [reply.media],
      },
      body: Stream.value(
        utf8.encode(
          reply.media == 'text/html'
              ? reply.body.toString()
              : jsonEncode(reply.body),
        ),
      ),
      cancel: () {},
    );
  }

  @override
  void close() {
    isClosed = true;
  }
}

Map<String, Object> _info([String version = '2.0.22']) => {
  'version': version,
  'pid': 0,
  'urls': ['http://untrusted.invalid'],
  'paths': {'tmp': '/tmp/fake-test'},
};
({int status, Object body, String media}) _reply(
  Object body, {
  int status = 200,
  String media = 'application/json',
}) => (status: status, body: body, media: media);

void main() {
  test(
    'strict private wrapper and explicit proxy retain the chosen endpoint',
    () {
      final pairing = OpenCodePairing(
        (_, _) => throw StateError('parser must not use network'),
      );
      const raw = 'http://[::1]:4096/proxy/auth/connect/fake-test-code';
      final candidate = pairing.parse(raw)!;
      expect(candidate.endpoint.toString(), 'http://[::1]:4096/proxy/');
      expect(candidate.toString(), isNot(contains('fake-test-code')));
      final wrapped = Uri(
        scheme: 'codewalk',
        host: 'pair',
        queryParameters: {'url': raw},
      );
      expect(pairing.parse(wrapped.toString())!.endpoint, candidate.endpoint);
      for (final invalid in [
        'http://user:password@example.invalid/auth/connect/code',
        'http://example.invalid/auth/connect/code?extra=value',
        'http://example.invalid/auth/connect/code#fragment',
        'http://example.invalid/%252e%252e/auth/connect/code',
        'http://example.invalid/auth/connect/%2fcode',
        'http://example.invalid/auth/connect/code/extra',
        'codewalk://pair?token=fake-token',
        'codewalk://pair?url=${Uri.encodeComponent(raw)}&url=${Uri.encodeComponent(raw)}',
        'codewalk://pair?url=${Uri.encodeComponent(raw)}&unknown=1',
        'codewalk://pair/extra?url=${Uri.encodeComponent(raw)}',
        'codewalk://pair',
        'x' * 4097,
      ]) {
        expect(pairing.parse(invalid), isNull);
      }
    },
  );

  test(
    'redemption is anonymous JSON, verifies token and never adopts response URL',
    () async {
      final queue = [
        _reply({'token': 'fake-test-token'}),
        _reply(_info()),
      ];
      final requests = <TransportRequest>[];
      final secrets = <String?>[];
      final transports = <_Script>[];
      final pairing = OpenCodePairing((endpoint, secret) {
        secrets.add(secret);
        final transport = _Script(endpoint, queue, requests);
        transports.add(transport);
        return transport;
      });
      final candidate = pairing.parse(
        'http://127.0.0.1:4096/proxy/auth/connect/fake-test-code',
      )!;
      final result = await pairing.redeem(candidate).result;
      expect(result.canSave, isTrue);
      expect(secrets, [null, 'fake-test-token']);
      expect(requests.map((r) => r.path), [
        '/auth/connect/fake-test-code',
        '/api/info',
      ]);
      expect(
        requests.every((r) => r.headers['Accept'] == 'application/json'),
        isTrue,
      );
      expect(
        transports.every((t) => t.endpoint == candidate.endpoint && t.isClosed),
        isTrue,
      );
      expect(result.credential!.expiresAt, isNull);
      expect(result.toString(), isNot(contains('fake-test-token')));
    },
  );

  for (final entry in [
    (_reply({}, status: 401), PairingStatus.rejected),
    (_reply({}, status: 403), PairingStatus.rejected),
    (_reply({}, status: 302), PairingStatus.uncertain),
    (_reply('<html/>', media: 'text/html'), PairingStatus.uncertain),
    (_reply({'notToken': 'fake-test'}), PairingStatus.uncertain),
  ]) {
    test(
      'response ${entry.$1.status}/${entry.$1.media} never retries or persists',
      () async {
        final requests = <TransportRequest>[];
        final pairing = OpenCodePairing(
          (endpoint, _) => _Script(endpoint, [entry.$1], requests),
        );
        final result = await pairing
            .redeem(
              pairing.parse('http://127.0.0.1/auth/connect/fake-test-code')!,
            )
            .result;
        expect(result.status, entry.$2);
        expect(result.credential, isNull);
        expect(requests, hasLength(1));
      },
    );
  }

  test(
    'received token survives a failed read-only verification for a save recheck',
    () async {
      final requests = <TransportRequest>[];
      final queue = [
        _reply({'token': 'fake-test-token'}),
        _reply({}, status: 503),
      ];
      final pairing = OpenCodePairing(
        (endpoint, _) => _Script(endpoint, queue, requests),
      );
      final result = await pairing
          .redeem(
            pairing.parse('http://127.0.0.1/auth/connect/fake-test-code')!,
          )
          .result;
      expect(result.status, PairingStatus.verificationFailed);
      expect(result.credential!.secret == 'fake-test-token', isTrue);
      expect(result.canSave, isFalse);
      expect(requests, hasLength(2));
    },
  );

  test(
    'source-scoped expiry is advisory and newer opaque versions do not invent a date',
    () async {
      final token = '1795000000.${'a' * 43}';
      for (final version in ['2.0.22', '2.0.23']) {
        final queue = [
          _reply({'token': token}),
          _reply(_info(version)),
        ];
        final pairing = OpenCodePairing(
          (endpoint, _) => _Script(endpoint, queue, []),
        );
        final result = await pairing
            .redeem(
              pairing.parse('http://127.0.0.1/auth/connect/fake-test-code')!,
            )
            .result;
        expect(result.canSave, isTrue);
        expect(
          result.credential!.expiresAt,
          version == '2.0.22'
              ? DateTime.fromMillisecondsSinceEpoch(1795000000000, isUtc: true)
              : null,
        );
      }
    },
  );

  test(
    'renewal validates the connected version before issuing any mutation',
    () async {
      final credential = EndpointCredential(
        kind: EndpointAuthKind.paired,
        secret: 'fake-old',
      );
      final requests = <TransportRequest>[];
      final pairing = OpenCodePairing(
        (endpoint, _) => _Script(endpoint, [_reply(_info('2.0.23'))], requests),
      );
      expect(
        (await pairing.renew(Uri.parse('http://127.0.0.1/'), credential).result)
            .status,
        PairingStatus.renewalUnavailable,
      );
      expect(requests.single.method, 'GET');
    },
  );

  test(
    'fixture server exercises single-use redemption and explicit successor renewal',
    () async {
      final fixtures = OpenCodeFixtures();
      final server = await FakeOpenCodeServer.start(
        fixtures: fixtures,
        scenario: fixtures.observedA(),
      );
      final pairing = OpenCodePairing(
        (endpoint, secret) => IoEndpointHttpTransport(
          endpoint: endpoint,
          headers: secret == null
              ? null
              : basicEndpointHeaders(
                  endpoint: endpoint,
                  username: 'opencode',
                  secret: () => secret,
                ),
        ),
      );
      try {
        final issued = server.auth.issuePairing();
        final candidate = PairingCandidate(
          endpoint: server.endpoint,
          challenge: issued['code'] as String,
        );
        final first = await pairing.redeem(candidate).result;
        expect(first.canSave, isTrue);
        expect(
          (await pairing.redeem(candidate).result).status,
          PairingStatus.rejected,
        );
        final successor = await pairing
            .renew(server.endpoint, first.credential!)
            .result;
        expect(successor.canSave, isTrue);
        expect(
          successor.credential!.secret != first.credential!.secret,
          isTrue,
        );
        expect(
          server.auth.accepts(
            server.auth.authorization(first.credential!.secret),
          ),
          isTrue,
        );
      } finally {
        await server.close();
      }
    },
  );
}
