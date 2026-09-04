import 'dart:async';
import 'dart:typed_data';

/// Raw full-duplex byte stream over the tailnet.
///
/// Decouples upper layers (e.g. the terminal WebSocket transport) from the
/// vendored Tailscale package: `TailscaleService` adapts its native
/// connection to this contract, so presentation code never imports
/// `package:tailscale` directly.
abstract interface class TailscaleTcpConnection {
  /// Single-subscription inbound bytes from the remote node.
  Stream<Uint8List> get input;

  /// Writes one chunk. Completion means accepted by the local transport,
  /// not that the remote node received it.
  Future<void> write(List<int> bytes);

  /// Application-level close of the whole connection.
  Future<void> close();

  /// Completes when the connection is terminal.
  Future<void> get done;
}

/// Dials `host:port` on the tailnet and returns the raw byte stream.
///
/// `host` may be a tailnet IP or a MagicDNS name. `timeout` bounds the
/// native dial only, not the lifetime of the returned connection.
typedef TailscaleTcpDial =
    Future<TailscaleTcpConnection> Function(
      String host,
      int port, {
      Duration? timeout,
    });
