import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'fake_auth.dart';
import 'fixture_replay.dart';

enum _GateDecision { release, drop }

/// Holds a captured response *after* its exchange has been admitted.
final class ResponseGate {
  final _admission = Completer<bool>();
  final _decision = Completer<_GateDecision>();

  /// False means teardown cancelled this gate before admission.
  Future<bool> get admitted => _admission.future;

  void release() => _settle(_GateDecision.release);
  void drop() => _settle(_GateDecision.drop);

  void _settle(_GateDecision decision) {
    if (!_decision.isCompleted) _decision.complete(decision);
  }

  void _cancel() {
    if (!_admission.isCompleted) _admission.complete(false);
    drop();
  }
}

/// One explicitly recorded connection epoch. Reopening never resets this one.
final class FixtureSseConnection {
  FixtureSseConnection._(this._owner, this._request, this.fixture);

  final FakeOpenCodeServer _owner;
  final HttpRequest _request;
  final FixtureStream fixture;
  Future<void> _writes = Future.value();
  int _cursor = 0;
  bool _closed = false;
  Future<void>? _finishing;

  int get emittedFrames => _cursor;
  bool get isClosed => _closed;

  /// Caller controls publication; no timer or implicit prefix replay exists.
  Future<void> emitNext() {
    if (_closed || _owner.isClosed || _finishing != null) {
      throw StateError('Fake SSE is closed.');
    }
    final next = _writes.then((_) async {
      if (_closed || _owner.isClosed) throw StateError('Fake SSE is closed.');
      if (_cursor >= fixture.frames.length) {
        throw StateError('Recorded SSE epoch exhausted.');
      }
      final frame = fixture.frames[_cursor++];
      _request.response.add(utf8.encode(frame));
      await _request.response.flush();
    });
    // Observe the queue without hiding a failure from its caller or teardown.
    _writes = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!_owner.isClosed) _owner._recordFailure('SSE write', error);
      },
    );
    return next;
  }

  Future<void> emitRemaining() async {
    while (_cursor < fixture.frames.length) {
      await emitNext();
    }
  }

  /// A controlled complete-frame EOF, not a claim of a native TCP reset.
  Future<void> finish() => _finishing ??= _finish();

  Future<void> _finish() async {
    await _writes;
    if (_closed || _owner.isClosed) return;
    _closed = true;
    _owner._intentional.add(_request);
    await _request.response.close();
  }
}

/// VM/loopback-only test support. No imports/exports from production libraries.
final class FakeOpenCodeServer {
  FakeOpenCodeServer._(
    this._server,
    this.scenario,
    this.info,
    this.maxRequestBytes,
    this.maxRequests,
  ) : auth = FakeAuth('fake-test-${_server.port}') {
    _subscription = _server.listen((request) {
      final operation = _handleSafely(request);
      _pending.add(operation);
      unawaited(operation.then((_) => _pending.remove(operation)));
    }, onError: (Object error) => _recordFailure('HTTP listener', error));
  }

  static Future<FakeOpenCodeServer> start({
    required FixtureScenario scenario,
    OpenCodeFixtures? fixtures,
    int maxRequestBytes = 64 * 1024,
    int maxRequests = 256,
  }) async {
    if (maxRequestBytes <= 0 || maxRequests <= 0) {
      throw ArgumentError('Fake request limits must be positive.');
    }
    final input = fixtures ?? OpenCodeFixtures();
    // Validate/load before opening a socket, so invalid inputs cannot leak one.
    final info = freezeJson(input.info);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeOpenCodeServer._(
      server,
      scenario,
      info,
      maxRequestBytes,
      maxRequests,
    );
  }

  final HttpServer _server;
  final FixtureScenario scenario;
  final Object? info;
  final FakeAuth auth;
  final int maxRequestBytes;
  final int maxRequests;
  late final StreamSubscription<HttpRequest> _subscription;
  final _pending = <Future<void>>{};
  final _intentional = <HttpRequest>{};
  final _streams = <FixtureSseConnection>[];
  final _gates = <ResponseGate>[];
  final _failures = <String>[];
  final _observations = <({String kind, int? exchange})>[];
  int _requests = 0;
  int _cursor = 0;
  bool _closed = false;
  bool _failNext = false;
  ResponseGate? _holdNext;
  Future<void>? _closing;

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}');
  bool get isClosed => _closed;
  int get completedExchanges => _cursor;
  List<FixtureSseConnection> get streams => List.unmodifiable(_streams);

  /// Deliberately omits request paths, headers, credentials and bodies.
  List<({String kind, int? exchange})> get observations =>
      List.unmodifiable(_observations);

  void failNextExchange() {
    _checkFaultAvailable();
    _failNext = true;
  }

  ResponseGate holdNextExchange() {
    _checkFaultAvailable();
    final gate = ResponseGate();
    _gates.add(gate);
    return _holdNext = gate;
  }

  void _checkFaultAvailable() {
    if (_closed || _cursor >= scenario.exchanges.length) {
      throw StateError('No remaining open exchange to fault.');
    }
    if (_failNext || _holdNext != null) {
      throw StateError('A one-shot exchange fault is already armed.');
    }
  }

  void assertHealthy() {
    if (_failures.isNotEmpty) {
      throw StateError('Unexpected fake failures: ${_failures.join(', ')}');
    }
  }

  void _recordFailure(String phase, Object error) {
    if (_failures.length < maxRequests) {
      _failures.add('$phase:${error.runtimeType}');
    }
  }

  Future<void> _handleSafely(HttpRequest request) async {
    // Observe response errors immediately, including long-lived SSE responses.
    unawaited(
      request.response.done.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (!_closed && !_intentional.contains(request)) {
            _recordFailure('HTTP response', error);
          }
        },
      ),
    );
    try {
      await _handle(request);
    } catch (error) {
      if (!_closed && !_intentional.contains(request)) {
        _recordFailure('HTTP handler', error);
      }
    }
  }

  Future<void> _json(HttpRequest request, int status, Object? body) async {
    request.response.statusCode = status;
    if (status != 204) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
    }
    await request.response.close();
  }

  Future<void> _synthetic(HttpRequest request, int status, String tag) =>
      _json(request, status, {'_tag': tag, 'synthetic': true});

  Future<void> _unauthorized(HttpRequest request, {bool pairing = false}) =>
      _json(request, 401, {
        '_tag': 'UnauthorizedError',
        'message': pairing
            ? 'Pairing link expired or already used'
            : 'Authentication required',
      });

  Future<void> _handle(HttpRequest request) async {
    if (_closed) return;
    if (++_requests > maxRequests) {
      await _synthetic(request, 429, 'FakeRequestLimit');
      return;
    }
    final uri = request.uri;
    final redeem =
        request.method == 'GET' &&
        uri.pathSegments.length == 3 &&
        uri.pathSegments[0] == 'auth' &&
        uri.pathSegments[1] == 'connect' &&
        !uri.path.endsWith('/') &&
        !uri.hasQuery;
    if (!redeem && !auth.accepts(request.headers.value('authorization'))) {
      _observations.add((kind: 'unauthorized', exchange: null));
      await _unauthorized(request);
      return;
    }
    final bytes = BytesBuilder();
    await for (final chunk in request) {
      if (chunk.length > maxRequestBytes - bytes.length) {
        await _synthetic(request, 413, 'FakeRequestBodyLimit');
        return;
      }
      bytes.add(chunk);
    }
    if (_closed) return;
    final hasBody = bytes.length != 0;
    Object? body;
    if (hasBody) {
      try {
        body = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on FormatException {
        await _synthetic(request, 400, 'FakeMalformedJson');
        return;
      }
    }
    if (redeem && !hasBody) {
      final token = auth.redeem(uri.pathSegments.last);
      if (token == null) {
        await _unauthorized(request, pairing: true);
      } else {
        await _json(request, 200, {'token': token});
      }
      return;
    }
    if (!hasBody && !uri.hasQuery) {
      if (request.method == 'GET' && uri.path == '/api/info') {
        await _json(request, 200, info);
        return;
      }
      if (request.method == 'POST' && uri.path == '/api/pair') {
        await _json(request, 200, auth.issuePairing());
        return;
      }
      if (request.method == 'GET' && uri.path == '/api/event') {
        await _openStream(request);
        return;
      }
    }
    final index = _cursor;
    if (index >= scenario.exchanges.length ||
        !scenario.exchanges[index].matches(
          request.method,
          uri,
          body,
          hasBody,
        )) {
      _observations.add((kind: 'mismatch', exchange: index));
      await _synthetic(request, 409, 'FakeScenarioMismatch');
      return;
    }
    if (_failNext) {
      _failNext = false;
      _observations.add((kind: 'before-admission-fault', exchange: index));
      await _synthetic(request, 503, 'FakeInjectedFailure');
      return;
    }
    final exchange = scenario.exchanges[index];
    final gate = _holdNext;
    _holdNext = null;
    // Reserve synchronously before any await: concurrent requests see admission.
    _cursor++;
    _observations.add((kind: 'admitted', exchange: index));
    if (gate != null) {
      gate._admission.complete(true);
      final decision = await gate._decision.future;
      if (_closed) return;
      if (decision == _GateDecision.drop) {
        _intentional.add(request);
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
    }
    await _json(request, exchange.status, exchange.response);
  }

  Future<void> _openStream(HttpRequest request) async {
    final index = _streams.length;
    if (index >= scenario.streams.length) {
      await _synthetic(request, 409, 'FakeStreamEpochExhausted');
      return;
    }
    request.response
      ..bufferOutput = false
      ..headers.set('content-type', 'text/event-stream; charset=utf-8')
      ..headers.set('cache-control', 'no-cache');
    _streams.add(
      FixtureSseConnection._(this, request, scenario.streams[index]),
    );
    _observations.add((kind: 'stream-open', exchange: null));
    // Synthetic comment flushes headers without publishing a native event.
    request.response.write(': fake-test-ready\n\n');
    await request.response.flush();
  }

  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    _closed = true;
    for (final gate in _gates) {
      gate._cancel();
    }
    for (final stream in _streams) {
      stream._closed = true;
    }
    await _server.close(force: true);
    await _subscription.cancel();
    await Future.wait(_pending.toList());
    await Future.wait(_streams.map((stream) => stream._writes));
    assertHealthy();
  }
}
