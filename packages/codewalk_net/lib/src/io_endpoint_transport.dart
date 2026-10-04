import 'dart:async';
import 'dart:io' as io;

import 'http_transport.dart';

/// Per-endpoint raw HTTP on the Dart VM. It never follows redirects or retries.
/// TLS uses the system defaults; no certificate-verification bypass is exposed.
final class IoEndpointHttpTransport implements EndpointHttpTransport {
  IoEndpointHttpTransport({
    required Uri endpoint,
    EndpointHeaders? headers,
    Duration headerTimeout = const Duration(seconds: 30),
    Duration connectionTimeout = const Duration(seconds: 15),
  }) : endpoint = _validateEndpoint(endpoint),
       _headers = headers,
       _headerTimeout = headerTimeout {
    if (headerTimeout <= Duration.zero || connectionTimeout <= Duration.zero) {
      throw ArgumentError('Transport timeouts must be positive.');
    }
    _client.connectionTimeout = connectionTimeout;
    _client.autoUncompress = false;
  }

  @override
  final Uri endpoint;
  final EndpointHeaders? _headers;
  final Duration _headerTimeout;
  final _client = io.HttpClient();
  final _operations = <_Operation>{};
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  static Uri _validateEndpoint(Uri endpoint) {
    if (!{'http', 'https'}.contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.port <= 0 ||
        endpoint.port > 65535) {
      throw const TransportException(TransportFailure.invalidTarget);
    }
    return endpoint.replace(
      path: endpoint.path.endsWith('/') ? endpoint.path : '${endpoint.path}/',
    );
  }

  Uri _target(String path) {
    try {
      final route = Uri.parse(path);
      if (route.hasScheme ||
          route.hasAuthority ||
          route.hasFragment ||
          route.pathSegments.any(
            // pathSegments decodes percent escapes. A proxy may then treat
            // decoded slash/backslash as a separator before normalizing dots.
            (part) => part
                .split(RegExp(r'[/\\]'))
                .any(
                  (decodedPart) => decodedPart == '.' || decodedPart == '..',
                ),
          )) {
        throw const TransportException(TransportFailure.invalidTarget);
      }
      final relative = route.path.startsWith('/')
          ? route.replace(path: route.path.substring(1))
          : route;
      final target = endpoint.resolveUri(relative);
      if (target.scheme != endpoint.scheme ||
          target.host != endpoint.host ||
          target.port != endpoint.port ||
          target.userInfo.isNotEmpty ||
          !target.path.startsWith(endpoint.path)) {
        throw const TransportException(TransportFailure.invalidTarget);
      }
      return target;
    } on FormatException {
      throw const TransportException(TransportFailure.invalidTarget);
    }
  }

  @override
  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  }) {
    if (_closed) {
      return Future.error(const TransportException(TransportFailure.closed));
    }
    if (cancellation?.isCancelled ?? false) {
      return Future.error(const TransportException(TransportFailure.cancelled));
    }
    try {
      final operation = _Operation(this, request, _target(request.path));
      _operations.add(operation);
      operation.start(cancellation);
      return operation.result.future;
    } on TransportException catch (error) {
      return Future.error(error);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final operation in _operations.toList()) {
      operation.finish(const TransportException(TransportFailure.closed));
    }
    _client.close(force: true);
  }
}

final class _Operation {
  _Operation(this.owner, this.input, this.target);

  final IoEndpointHttpTransport owner;
  final TransportRequest input;
  final Uri target;
  final result = Completer<TransportResponse>();
  io.HttpClientRequest? _request;
  io.HttpClientResponse? _response;
  StreamSubscription<void>? _cancellation;
  StreamSubscription<List<int>>? _upstream;
  StreamController<List<int>>? _body;
  Timer? _timer;
  bool _finished = false;

  void start(RequestCancellation? cancellation) {
    _timer = Timer(
      owner._headerTimeout,
      () => finish(const TransportException(TransportFailure.timeout)),
    );
    _cancellation = cancellation?.onCancel.listen(
      (_) => finish(const TransportException(TransportFailure.cancelled)),
    );
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final boundHeaders = await owner._headers?.call(target) ?? const {};
      if (_finished) return;
      // Host is derived from the validated endpoint, never a caller override.
      if ([
        ...input.headers.keys,
        ...boundHeaders.keys,
      ].any((key) => key.toLowerCase() == 'host')) {
        finish(const TransportException(TransportFailure.invalidRequest));
        return;
      }
      final request = await owner._client.openUrl(input.method, target);
      if (_finished) {
        request.abort();
        return;
      }
      _request = request;
      request.followRedirects = false;
      for (final entry in input.headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      for (final entry in boundHeaders.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (input.body != null) {
        request.contentLength = input.body!.length;
        request.add(input.body!);
      }
      final response = await request.close();
      if (_finished) {
        unawaited(response.listen((_) {}).cancel());
        return;
      }
      _response = response;
      _timer?.cancel();
      final headers = <String, List<String>>{};
      response.headers.forEach((name, values) {
        headers[name] = List.of(values);
      });
      final body = StreamController<List<int>>(
        onListen: () {
          if (_finished) return;
          _upstream = response.listen(
            (chunk) => _body!.add(chunk),
            onError: (Object error, StackTrace stack) =>
                finish(const TransportException(TransportFailure.connection)),
            onDone: () => finish(),
          );
        },
        onPause: () => _upstream?.pause(),
        onResume: () => _upstream?.resume(),
        onCancel: () => finish(),
      );
      _body = body;
      result.complete(
        TransportResponse(
          statusCode: response.statusCode,
          headers: headers,
          body: body.stream,
          cancel: () =>
              finish(const TransportException(TransportFailure.cancelled)),
        ),
      );
    } on Object {
      // Native errors can include a sensitive URL, header or argument value.
      finish(const TransportException(TransportFailure.connection));
    }
  }

  void finish([TransportException? error]) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    if (_cancellation != null) unawaited(_cancellation!.cancel());
    if (_upstream != null) unawaited(_upstream!.cancel());
    if (_upstream == null && _response != null) {
      unawaited(_response!.listen((_) {}).cancel());
    }
    if (error != null) {
      _request?.abort(error);
      if (!result.isCompleted) {
        result.completeError(error);
      } else {
        _body?.addError(error);
      }
    } else {
      // Subscription cancellation also releases an unread/paused HTTP body.
      _request?.abort();
    }
    if (_body != null) unawaited(_body!.close());
    owner._operations.remove(this);
  }
}
