import 'package:codewalk/core/constants/api_constants.dart';
import 'package:codewalk/core/tailscale/tailscale_peer.dart';
import 'package:flutter_test/flutter_test.dart';

TailscalePeer _peer(List<String> ips) => TailscalePeer(
  stableId: 'n1',
  hostName: 'mercury',
  dnsName: 'mercury.uaru-nase.ts.net.',
  tailscaleIPs: ips,
  online: true,
);

void main() {
  group('TailscalePeer.defaultUrl', () {
    test('uses the default OpenCode port', () {
      expect(
        _peer(const ['100.123.123.1']).defaultUrl,
        'http://100.123.123.1:${ApiConstants.defaultPort}',
      );
    });

    test('brackets IPv6 addresses', () {
      expect(
        _peer(const ['fd7a:115c:a1e0::1']).defaultUrl,
        'http://[fd7a:115c:a1e0::1]:${ApiConstants.defaultPort}',
      );
    });
  });
}
