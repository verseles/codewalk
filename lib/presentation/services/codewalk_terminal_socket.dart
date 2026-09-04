import 'dart:async';

import '../../core/tailscale/tailscale_tcp_connection.dart';
import 'codewalk_terminal_socket_stub.dart'
    if (dart.library.io) 'codewalk_terminal_socket_io.dart';

abstract class CodewalkTerminalSocketConnection {
  Stream<List<int>> get messages;

  Future<void> get done;

  void send(List<int> data);

  Future<void> close();
}

Future<CodewalkTerminalSocketConnection> openCodewalkTerminalSocket({
  required Uri url,
  Map<String, String>? headers,
}) {
  return openCodewalkTerminalSocketImpl(url: url, headers: headers);
}

/// Opens the terminal WebSocket over a TCP connection dialed through the
/// embedded Tailscale node.
///
/// Unlike [openCodewalkTerminalSocket], which uses the platform network
/// stack directly, the RFC 6455 handshake and framing run over `dial`, so
/// tailnet-only destinations (MagicDNS names, `100.x` IPs) stay reachable
/// without a system VPN. The wire bytes and URL are identical — only the
/// route changes (ADR-023: transport-only, no server contract change).
Future<CodewalkTerminalSocketConnection>
openCodewalkTerminalSocketViaTailscale({
  required Uri url,
  Map<String, String>? headers,
  required TailscaleTcpDial dial,
  Duration timeout = const Duration(seconds: 15),
  int? maxIncomingFrameBytes,
}) {
  return openCodewalkTerminalSocketViaTailscaleImpl(
    url: url,
    headers: headers,
    dial: dial,
    timeout: timeout,
    maxIncomingFrameBytes: maxIncomingFrameBytes,
  );
}
