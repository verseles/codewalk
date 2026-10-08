import 'dart:async';
import 'dart:typed_data';

/// A bounded default for collected HTTP bodies and individual SSE frames.
const defaultTransportByteLimit = 16 * 1024 * 1024;

enum TransportFailure {
  invalidTarget,
  invalidRequest,
  invalidResponse,
  closed,
  cancelled,
  timeout,
  connection,
  bodyTooLarge,
  unexpectedStatus,
  unsupportedContentType,
  bufferOverflow,
}

/// Safe diagnostics deliberately omit URLs, headers, bodies and native causes.
final class TransportException implements Exception {
  const TransportException(this.failure, {this.statusCode});

  final TransportFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'TransportException(${failure.name}'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}

/// Explicit caller cancellation; one signal can cover a request and its body.
final class RequestCancellation {
  final _controller = StreamController<void>.broadcast(sync: true);
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Implementations unsubscribe when an operation settles.
  Stream<void> get onCancel => _controller.stream;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _controller.add(null);
    unawaited(_controller.close());
  }
}

/// Additional headers, evaluated only after the destination has been validated.
/// Credential storage and concrete authentication schemes belong to callers.
typedef EndpointHeaders = FutureOr<Map<String, String>> Function(Uri target);

final class TransportRequest {
  TransportRequest({
    required this.method,
    required this.path,
    Map<String, String> headers = const {},
    List<int>? body,
  }) : headers = Map.unmodifiable(headers),
       body = body == null
           ? null
           : Uint8List.fromList(body).asUnmodifiableView();

  final String method;

  /// Relative route, joined below the endpoint's optional proxy path prefix.
  /// A leading slash is accepted without replacing that prefix.
  final String path;
  final Map<String, String> headers;
  final Uint8List? body;
}

final class TransportResponse {
  TransportResponse({
    required this.statusCode,
    required Map<String, List<String>> headers,
    required this.body,
    required void Function() cancel,
  }) : headers = Map.unmodifiable({
         for (final entry in headers.entries)
           entry.key.toLowerCase(): List<String>.unmodifiable(entry.value),
       }),
       _cancel = cancel;

  final int statusCode;
  final Map<String, List<String>> headers;

  /// A single-subscription entity body. Cancel consumption to release it.
  /// Statuses and payloads remain uninterpreted for the harness adapter.
  final Stream<List<int>> body;
  final void Function() _cancel;

  String? header(String name) => headers[name.toLowerCase()]?.join(', ');

  void cancel() => _cancel();

  /// Collect with a byte cap and a maximum wait between body chunks.
  /// Streaming SSE consumers use [body] directly, without this read timeout.
  Future<Uint8List> readBytes({
    int maxBytes = defaultTransportByteLimit,
    Duration? inactivityTimeout = const Duration(seconds: 30),
  }) async {
    if (maxBytes <= 0 ||
        (inactivityTimeout != null && inactivityTimeout <= Duration.zero)) {
      cancel();
      throw ArgumentError('Body limits and timeouts must be positive.');
    }
    final iterator = StreamIterator(body);
    final bytes = BytesBuilder();
    var length = 0;
    try {
      while (await _next(iterator, inactivityTimeout)) {
        final chunk = iterator.current;
        if (chunk.length > maxBytes - length) {
          throw const TransportException(TransportFailure.bodyTooLarge);
        }
        bytes.add(chunk);
        length += chunk.length;
      }
      return bytes.takeBytes();
    } on TimeoutException {
      throw const TransportException(TransportFailure.timeout);
    } finally {
      cancel();
      await iterator.cancel();
    }
  }

  static Future<bool> _next(
    StreamIterator<List<int>> iterator,
    Duration? timeout,
  ) => timeout == null
      ? iterator.moveNext()
      : iterator.moveNext().timeout(timeout);
}

/// An instance owns exactly one endpoint; no global active endpoint exists.
abstract interface class EndpointHttpTransport {
  Uri get endpoint;
  bool get isClosed;

  Future<TransportResponse> send(
    TransportRequest request, {
    RequestCancellation? cancellation,
  });

  /// Abort owned in-flight operations and release connections. Idempotent.
  void close();
}
