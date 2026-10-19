import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:codewalk_net/codewalk_net_io.dart';

/// Prints one machine-readable marker line for the launcher to collect.
/// Only native ids and statuses are printed; never secrets.
void qaMark(
  String phase,
  String status, [
  Map<String, Object?> extra = const {},
]) {
  stdout.writeln(
    'CODEWALK_LIVE_QA ${jsonEncode({...extra, 'phase': phase, 'status': status})}',
  );
}

/// A loopback TCP relay owned by the test: the client stack talks to
/// [endpoint] while every byte is piped to [upstream]. [cut] destroys the
/// active pipes and refuses new connections until [restore], so the client
/// observes a real transport drop without touching the server process.
///
/// The relay lives in its own isolate because widget tests run in a
/// fake-async zone where socket events of this isolate never dispatch; the
/// isolate runs on the root zone with real async. Control messages are
/// fire-and-forget; only [bind] awaits.
final class IsolateRelay {
  IsolateRelay._(this._isolate, this._control, this.endpoint);

  final Isolate _isolate;
  final SendPort _control;
  final Uri endpoint;

  static Future<IsolateRelay> bind(Uri upstream) async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(
      _relayEntry,
      [ready.sendPort, upstream.toString()],
    );
    final greeting = await ready.first as List;
    ready.close();
    final port = greeting[0] as int;
    return IsolateRelay._(
      isolate,
      greeting[1] as SendPort,
      Uri.parse('http://127.0.0.1:$port'),
    );
  }

  /// Destroys every active pipe and refuses new connections. Completes
  /// only when the isolate acknowledges, so a dead relay fails loudly
  /// instead of hanging the smoke.
  Future<void> cut() => _command('cut');

  Future<void> restore() => _command('restore');

  Future<void> _command(String message) async {
    final ack = ReceivePort();
    _control.send([message, ack.sendPort]);
    await ack.first.timeout(const Duration(seconds: 10));
    ack.close();
  }

  void close() {
    try {
      final ack = ReceivePort();
      _control.send([
        'close',
        ack.sendPort,
      ]);
      ack.close();
    } catch (_) {}
    _isolate.kill(priority: Isolate.immediate);
  }
}

Future<void> _pipeSockets(Socket client, Uri upstream, Set<Socket> open) async {
  late Socket serverSide;
  try {
    serverSide = await Socket.connect(upstream.host, upstream.port);
  } catch (_) {
    client.destroy();
    return;
  }
  open.add(client);
  open.add(serverSide);
  var closed = false;
  void done(Socket a, Socket b) {
    if (closed) return;
    closed = true;
    open.remove(a);
    open.remove(b);
    try {
      b.destroy();
    } catch (_) {}
  }

  client.listen(
    serverSide.add,
    onError: (_) => done(client, serverSide),
    onDone: () => done(client, serverSide),
    cancelOnError: true,
  );
  serverSide.listen(
    client.add,
    onError: (_) => done(serverSide, client),
    onDone: () => done(serverSide, client),
    cancelOnError: true,
  );
}

void _relayEntry(List<Object?> args) {
  final ready = args[0] as SendPort;
  final upstream = Uri.parse(args[1] as String);
  final control = ReceivePort();
  final open = <Socket>{};
  var cut = false;
  unawaited(
    ServerSocket.bind(InternetAddress.loopbackIPv4, 0).then((server) {
      ready.send([server.port, control.sendPort]);
      server.listen((client) {
        if (cut) {
          client.destroy();
          return;
        }
        unawaited(_pipeSockets(client, upstream, open));
      });
      control.listen((message) {
        final parts = message as List;
        final command = parts[0] as String;
        final replyTo = parts[1] as SendPort;
        if (command == 'cut') {
          cut = true;
          for (final socket in open.toList()) {
            try {
              socket.destroy();
            } catch (_) {}
          }
        } else if (command == 'restore') {
          cut = false;
        } else if (command == 'close') {
          control.close();
          unawaited(server.close());
          for (final socket in open.toList()) {
            try {
              socket.destroy();
            } catch (_) {}
          }
        }
        replyTo.send(true);
      });
    }),
  );
}

/// Minimal test-owned driver for native setup/teardown calls. The product
/// client stack (directory, outbox, controller, screens) is exercised by the
/// test itself; this probe only creates/selects/deletes sessions and reads
/// authoritative wire state for assertions.
final class NativeProbe {
  NativeProbe({required Uri endpoint, required String secret})
    : _transport = IoEndpointHttpTransport(
        endpoint: endpoint,
        headers: basicEndpointHeaders(
          endpoint: endpoint,
          username: 'opencode',
          secret: () => secret,
        ),
      );

  final IoEndpointHttpTransport _transport;

  Future<Map<String, Object?>> _call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final response = await _transport.send(
      TransportRequest(
        method: method,
        path: path,
        headers: const {'Accept': 'application/json'},
        body: body == null
            ? null
            : utf8.encode(jsonEncode(body)).toList(),
      ),
    );
    try {
      final raw = await response.readBytes(maxBytes: 4 * 1024 * 1024);
      // Large native bodies arrive gzipped; the transport hands over raw
      // bytes, so detect the gzip magic instead of trusting headers.
      final bytes = raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b
          ? GZipCodec().decode(raw)
          : raw;
      // 204 No Content (model/agent select, deletes) carries no body.
      final text = utf8.decode(bytes);
      return {
        'status': response.statusCode,
        'body': text.isEmpty ? null : jsonDecode(text),
      };
    } finally {
      response.cancel();
    }
  }

  Future<String> createSession({
    required String title,
    required String directory,
  }) async {
    final result = await _call('POST', '/api/session', {
      'title': title,
      'location': {
        'directory': directory,
      },
      // Without an explicit ask rule the native create evaluates to
      // deny (verified live); the rules below yield ask for the smoke
      // marker and for the stub's tool-call reads, mirroring Ask mode.
      'permissions': [
        {'action': 'read', 'resource': '*', 'effect': 'ask'},
        {'action': 'cw060b_smoke', 'resource': '*', 'effect': 'ask'},
      ],
    });
    if (result['status'] != 200) {
      throw StateError('session create HTTP ${result['status']}');
    }
    final data = (result['body'] as Map)['data'] as Map;
    return data['id'] as String;
  }

  Future<void> selectModel(String sessionId) async {
    final result = await _call('POST', '/api/session/$sessionId/model', {
      'model': {'providerID': 'cw060b', 'id': 'stub'},
    });
    if (result['status'] != 204 && result['status'] != 200) {
      throw StateError('model select HTTP ${result['status']}');
    }
  }

  Future<void> selectAgent(String sessionId, String agent) async {
    final result = await _call('POST', '/api/session/$sessionId/agent', {
      'agent': agent,
    });
    if (result['status'] != 204 && result['status'] != 200) {
      throw StateError('agent select HTTP ${result['status']}');
    }
  }

  Future<(String, String)> createPermission(
    String sessionId,
    String resource,
  ) async {
    // A real native action, so the client projects the same request shape a
    // tool call produces (a synthetic action is not auto-approvable).
    final result = await _call('POST', '/api/session/$sessionId/permission', {
      'action': 'read',
      'resources': [resource],
      'save': [resource],
    });
    if (result['status'] != 200) {
      throw StateError('permission create HTTP ${result['status']}');
    }
    final data = (result['body'] as Map)['data'] as Map;
    return (data['id'] as String, data['effect'] as String);
  }

  Future<List<Map>> listPermissions(String sessionId) async {
    final result = await _call('GET', '/api/session/$sessionId/permission');
    if (result['status'] != 200) {
      throw StateError('permission list HTTP ${result['status']}');
    }
    return ((result['body'] as Map)['data'] as List).cast<Map>();
  }

  /// The persistent approvals the server kept; an `always` reply would show
  /// here, and the smoke asserts it stays empty.
  Future<List<Map>> listSavedPermissions() async {
    final result = await _call('GET', '/api/permission/saved');
    if (result['status'] != 200) {
      throw StateError('saved permission list HTTP ${result['status']}');
    }
    final body = result['body'];
    final data = body is Map ? body['data'] : null;
    return (data is List ? data : const []).cast<Map>();
  }

  Future<List<Map>> listMessages(String sessionId) async {
    final result = await _call('GET', '/api/session/$sessionId/message');
    if (result['status'] != 200) {
      throw StateError('message list HTTP ${result['status']}');
    }
    return ((result['body'] as Map)['data'] as List).cast<Map>();
  }

  Future<bool> interrupt(String sessionId) async {
    final result = await _call('POST', '/api/session/$sessionId/interrupt');
    if (result['status'] != 200) {
      throw StateError('interrupt HTTP ${result['status']}');
    }
    final body = result['body'] as Map;
    final data = body['data'];
    if (data is Map && data['interrupted'] is bool) {
      return data['interrupted'] as bool;
    }
    return body['interrupted'] == true;
  }

  Future<void> deleteSession(String sessionId) async {
    final result = await _call('DELETE', '/api/session/$sessionId');
    if (result['status'] != 204 && result['status'] != 200) {
      throw StateError('session delete HTTP ${result['status']}');
    }
  }

  void close() => _transport.close();
}
