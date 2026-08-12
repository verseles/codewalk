import '../../core/i18n/l10n_bridge.dart';
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
