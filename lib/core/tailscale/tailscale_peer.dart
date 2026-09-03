import 'package:equatable/equatable.dart';

import '../constants/api_constants.dart';

/// A discoverable Tailscale tailnet peer, exposed by [TailscaleService].
///
/// This is a domain-level projection of the upstream [TailscaleNode] from
/// `package:tailscale`. Only fields relevant to server selection are surfaced
/// so that UI code never depends on the vendored package directly.
class TailscalePeer extends Equatable {
  const TailscalePeer({
    required this.stableId,
    required this.hostName,
    required this.dnsName,
    required this.tailscaleIPs,
    required this.online,
    this.os = '',
  });

  /// Stable node identifier (e.g. `n1234AbCd`), survives key rotation.
  final String stableId;

  /// MagicDNS label (e.g. `my-server`).
  final String hostName;

  /// Full MagicDNS FQDN (e.g. `my-server.tailnet.ts.net.`).
  final String dnsName;

  /// Assigned Tailscale IP addresses (IPv4 then IPv6).
  final List<String> tailscaleIPs;

  /// Whether the peer is currently online (control-plane signal).
  final bool online;

  /// Operating system of the peer (e.g. `linux`, `android`).
  final String os;

  /// The first IPv4 address, or null if none assigned.
  String? get ipv4 {
    for (final ip in tailscaleIPs) {
      if (!ip.contains(':')) return ip;
    }
    return null;
  }

  /// A human-readable display label: `hostName (dnsName)` when both differ,
  /// otherwise whichever is non-empty.
  String get displayLabel {
    final host = hostName.trim();
    final dns = dnsName.replaceAll(RegExp(r'\.$'), '').trim();
    if (host.isEmpty) return dns;
    if (dns.isEmpty) return host;
    if (host == dns.split('.').first) return dns;
    return '$host ($dns)';
  }

  /// A URL suitable for the server URL field, using the first IPv4 address
  /// with the default OpenCode port. IPv6 addresses are bracketed.
  String get defaultUrl {
    final ip = ipv4 ?? (tailscaleIPs.isNotEmpty ? tailscaleIPs.first : '');
    // IPv6 addresses in URLs must be enclosed in brackets.
    final formattedIp = ip.contains(':') ? '[$ip]' : ip;
    return 'http://$formattedIp:${ApiConstants.defaultPort}';
  }

  @override
  List<Object?> get props =>
      <Object?>[stableId, hostName, dnsName, tailscaleIPs, online, os];
}
