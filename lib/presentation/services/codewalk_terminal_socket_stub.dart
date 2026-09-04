import '../../core/i18n/l10n_bridge.dart';
import '../../core/tailscale/tailscale_tcp_connection.dart';
import 'codewalk_terminal_socket.dart';

Future<CodewalkTerminalSocketConnection> openCodewalkTerminalSocketImpl({
  required Uri url,
  Map<String, String>? headers,
}) {
  throw UnsupportedError(
    L10nBridge.current?.terminalWebsocketUnavailable ??
        'Terminal websocket is not available here.',
  );
}

Future<CodewalkTerminalSocketConnection>
openCodewalkTerminalSocketViaTailscaleImpl({
  required Uri url,
  Map<String, String>? headers,
  required TailscaleTcpDial dial,
  required Duration timeout,
  int? maxIncomingFrameBytes,
}) {
  throw UnsupportedError(
    L10nBridge.current?.terminalWebsocketUnavailable ??
        'Terminal websocket is not available here.',
  );
}
