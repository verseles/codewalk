import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'endpoint_target.dart';
import 'http_transport.dart';
import 'io_network_options.dart';
import 'io_websocket_session.dart';
import 'websocket_transport.dart';

/// A no-redirect, uncompressed RFC6455 client over the SDK's HTTP/TLS upgrade.
/// Its raw frame parser enforces lengths before SDK message assembly occurs.
final class IoEndpointWebSocketTransport implements EndpointWebSocketTransport {
  IoEndpointWebSocketTransport({
    required Uri endpoint,
    EndpointHeaders? headers,
    this.networkOptions = const IoNetworkOptions(),
    this.handshakeTimeout = const Duration(seconds: 30),
    this.writeTimeout = const Duration(seconds: 30),
    this.closeTimeout = const Duration(seconds: 2),
    this.maxMessageBytes = defaultTransportByteLimit,
    this.maxQueuedBytes = 32 * 1024 * 1024,
    this.maxQueuedMessages = 256,
  }) : _target = EndpointTarget(endpoint),
       _headers = headers {
    if (handshakeTimeout <= Duration.zero ||
        writeTimeout <= Duration.zero ||
        closeTimeout <= Duration.zero ||
        maxMessageBytes <= 0 ||
        maxQueuedBytes <= 0 ||
        maxQueuedMessages <= 0) {
      throw ArgumentError('Transport limits must be positive.');
    }
  }

  final EndpointTarget _target;
  final EndpointHeaders? _headers;
  final IoNetworkOptions networkOptions;
  final Duration handshakeTimeout;
  final Duration writeTimeout;
  final Duration closeTimeout;
  final int maxMessageBytes;
  final int maxQueuedBytes;
  final int maxQueuedMessages;
  final _attempts = <_Upgrade>{};
  final _sessions = <IoWebSocketSession>{};
  bool _closed = false;

  @override
  Uri get endpoint => _target.endpoint;
  @override
  bool get isClosed => _closed;

  @override
  Future<EndpointWebSocket> connect(
    String path, {
    Map<String, String> headers = const {},
    RequestCancellation? cancellation,
  }) {
    if (_closed) {
      return Future.error(const TransportException(TransportFailure.closed));
    }
    if (cancellation?.isCancelled ?? false) {
      return Future.error(const TransportException(TransportFailure.cancelled));
    }
    try {
      final target = _target.resolve(path);
      _validateHeaders(headers);
      final attempt = _Upgrade(this, target, Map.of(headers));
      _attempts.add(attempt);
      attempt.start(cancellation);
      return attempt.result.future;
    } on TransportException catch (error) {
      return Future.error(error);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final attempt in _attempts.toList()) {
      attempt.fail(TransportFailure.closed);
    }
    for (final session in _sessions.toList()) {
      session.fail(TransportFailure.closed);
    }
  }
}

void _validateHeaders(Map<String, String> headers) {
  for (final name in headers.keys) {
    final lower = name.toLowerCase();
    if ({
          'host',
          'connection',
          'upgrade',
          'content-length',
          'transfer-encoding',
        }.contains(lower) ||
        lower.startsWith('sec-websocket-')) {
      throw const TransportException(TransportFailure.invalidRequest);
    }
  }
}

final class _Upgrade {
  _Upgrade(this.owner, this.target, this.headers);
  final IoEndpointWebSocketTransport owner;
  final Uri target;
  final Map<String, String> headers;
  final result = Completer<EndpointWebSocket>();
  final client = io.HttpClient();
  io.HttpClientRequest? request;
  io.Socket? socket;
  StreamSubscription<void>? cancel;
  Timer? timer;
  bool done = false;
  RequestCancellation? cancelToken;

  void start(RequestCancellation? cancellation) {
    cancelToken = cancellation;
    timer = Timer(owner.handshakeTimeout, () => fail(TransportFailure.timeout));
    cancel = cancellation?.onCancel.listen(
      (_) => fail(TransportFailure.cancelled),
    );
    unawaited(_run());
  }

  void _settle() {
    done = true;
    timer?.cancel();
    final subscription = cancel;
    if (subscription != null) unawaited(subscription.cancel());
    owner._attempts.remove(this);
  }

  void fail(TransportFailure reason, {int? statusCode}) {
    if (done) return;
    _settle();
    request?.abort();
    client.close(force: true);
    socket?.destroy();
    result.completeError(TransportException(reason, statusCode: statusCode));
  }

  Future<void> _run() async {
    try {
      final bound = await owner._headers?.call(target) ?? const {};
      if (done) return;
      _validateHeaders(bound);
      owner.networkOptions.apply(client);
      client.connectionTimeout = owner.handshakeTimeout;
      client.autoUncompress = false;
      final opened = await client.openUrl('GET', target);
      if (done) {
        opened.abort();
        return;
      }
      request = opened;
      opened.followRedirects = false;
      for (final entry in {...headers, ...bound}.entries) {
        opened.headers.set(entry.key, entry.value);
      }
      final random = Random.secure();
      final key = base64Encode(List.generate(16, (_) => random.nextInt(256)));
      opened.headers.set('connection', 'Upgrade');
      opened.headers.set('upgrade', 'websocket');
      opened.headers.set('sec-websocket-version', '13');
      opened.headers.set('sec-websocket-key', key);
      final response = await opened.close();
      if (done) {
        client.close(force: true);
        return;
      }
      if (response.statusCode != 101) {
        fail(
          TransportFailure.unexpectedStatus,
          statusCode: response.statusCode,
        );
        return;
      }
      const guid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
      final accept = base64Encode(
        sha1.convert(ascii.encode('$key$guid')).bytes,
      );
      final connection = response.headers.value('connection') ?? '';
      if (!connection
              .split(',')
              .any((v) => v.trim().toLowerCase() == 'upgrade') ||
          response.headers.value('upgrade')?.toLowerCase() != 'websocket' ||
          response.headers.value('sec-websocket-accept') != accept ||
          response.headers['sec-websocket-extensions'] != null ||
          response.headers['sec-websocket-protocol'] != null) {
        fail(TransportFailure.invalidResponse);
        return;
      }
      final detached = await response.detachSocket();
      socket = detached;
      if (done) {
        detached.destroy();
        return;
      }
      late final IoWebSocketSession session;
      session = IoWebSocketSession(
        detached,
        maxMessageBytes: owner.maxMessageBytes,
        maxQueuedBytes: owner.maxQueuedBytes,
        maxQueuedMessages: owner.maxQueuedMessages,
        writeTimeout: owner.writeTimeout,
        closeTimeout: owner.closeTimeout,
        onClosed: () {
          owner._sessions.remove(session);
          client.close(force: true);
        },
      );
      owner._sessions.add(session);
      session.attachCancellation(cancelToken);
      _settle();
      result.complete(session);
    } on TransportException catch (error) {
      fail(error.failure);
    } on Object {
      fail(TransportFailure.connection);
    }
  }
}
