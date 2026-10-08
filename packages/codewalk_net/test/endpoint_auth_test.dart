import 'dart:convert';

import 'package:codewalk_net/codewalk_net.dart';
import 'package:test/test.dart';

void main() {
  final endpoint = Uri.parse('https://example.test/proxy/');
  test('Basic binds password or pairing secret to one target', () async {
    var calls = 0;
    for (final secret in ['password', 'pairing-token', 'sénha:with-colon']) {
      final headers = basicEndpointHeaders(
        endpoint: endpoint,
        username: 'opencode',
        secret: () {
          calls++;
          return secret;
        },
      );
      final bound = await headers(endpoint.resolve('api/info'));
      expect(
        utf8.decode(base64Decode(bound['authorization']!.substring(6))),
        'opencode:$secret',
      );
      for (final invalid in [
        'https://sub.example.test/proxy/info',
        'http://example.test/proxy/info',
        'https://example.test:444/proxy/info',
        'https://example.test/outside',
        'https://example.test/proxy/safe%2f..%2foutside',
        'https://example.test/proxy/%252e%252e%252foutside',
        'https://example.test/proxy/safe%25252f..%25252foutside',
      ]) {
        expect(
          () => headers(Uri.parse(invalid)),
          throwsA(isA<TransportException>()),
        );
      }
    }
    expect(calls, 3);
  });

  test('invalid credentials are rejected without secret diagnostics', () async {
    expect(
      () => basicEndpointHeaders(
        endpoint: endpoint,
        username: 'invalid:name',
        secret: () => 'private',
      ),
      throwsArgumentError,
    );
    final headers = basicEndpointHeaders(
      endpoint: endpoint,
      username: 'user',
      secret: () => 'private\nvalue',
    );
    await expectLater(
      headers(endpoint),
      throwsA(
        isA<TransportException>().having(
          (e) => e.toString(),
          'safe',
          isNot(contains('private')),
        ),
      ),
    );
  });

  test('gateway headers compose with auth case-insensitively', () async {
    final auth = bearerEndpointHeaders(
      endpoint: endpoint,
      token: () => 'token',
    );
    final headers = composeEndpointHeaders([
      (_) => {'Authorization': 'old', 'Gateway-Identity': 'gateway'},
      auth,
    ]);
    expect(await headers(endpoint), {
      'authorization': 'Bearer token',
      'gateway-identity': 'gateway',
    });
  });
}
