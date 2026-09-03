import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class TailscaleHttpAdapter implements HttpClientAdapter {
  TailscaleHttpAdapter(this._client);

  final http.Client _client;

  /// Fallback bound for time-to-response-head when the request carries no
  /// explicit connect timeout. Dio enforces timeouts only in its default
  /// IO adapter — custom adapters await `fetch()` unbounded — so without
  /// this a stalled native call would hang health probes and API requests
  /// forever (and wedge the shared health-check gate).
  ///
  /// Only the response head is bounded, never the body stream: SSE and
  /// long assistant responses keep streaming once headers arrive.
  static const Duration fallbackHeadTimeout = Duration(seconds: 15);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    DioException cancelled() => DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      error: 'Tailscale request cancelled',
    );

    final request = http.StreamedRequest(options.method, options.uri);
    request.followRedirects = options.followRedirects;
    request.maxRedirects = options.maxRedirects;
    request.persistentConnection = options.persistentConnection;
    request.headers.addAll(
      options.headers.map(
        (key, value) => MapEntry(key, value == null ? '' : value.toString()),
      ),
    );
    final contentLength = options.headers[Headers.contentLengthHeader];
    if (contentLength is int) {
      request.contentLength = contentLength;
    } else if (contentLength is String) {
      request.contentLength = int.tryParse(contentLength) ?? -1;
    }

    final bodyDone = Completer<void>();
    var sinkClosed = false;
    var isCancelled = false;
    Future<void> closeSink() {
      if (sinkClosed) return Future<void>.value();
      sinkClosed = true;
      return request.sink.close();
    }

    final subscription = requestStream?.listen(
      request.sink.add,
      onError: (Object error, StackTrace stackTrace) {
        request.sink.addError(error, stackTrace);
        if (!bodyDone.isCompleted) {
          bodyDone.completeError(error, stackTrace);
        }
      },
      onDone: () {
        unawaited(closeSink());
        if (!bodyDone.isCompleted) {
          bodyDone.complete();
        }
      },
      cancelOnError: true,
    );
    if (requestStream == null) {
      // Bodyless request (e.g. GET): close the sink WITHOUT awaiting it,
      // then mark the body complete so send() can run. Two traps avoided:
      // 1. Awaiting close() here deadlocks — with no listener attached yet
      //    (the native client only finalizes inside send(), below),
      //    StreamedRequest.sink.close() never completes and send() never
      //    runs.
      // 2. Never closing starves the body — without request EOF the server
      //    withholds response bytes after the head (observed: head 200
      //    arrives, zero body events follow). The pending close resolves as
      //    soon as the native finalizer drain attaches inside send().
      unawaited(closeSink());
      bodyDone.complete();
    }

    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then((_) async {
          isCancelled = true;
          await subscription?.cancel();
          await closeSink();
          if (!bodyDone.isCompleted) {
            bodyDone.completeError(cancelled());
          }
        }),
      );
    }

    await bodyDone.future;
    final sendFuture = _client.send(request).then((response) {
      if (isCancelled) {
        unawaited(response.stream.listen((_) {}).cancel());
      }
      return response;
    });
    final pending = cancelFuture == null
        ? sendFuture
        : Future.any<http.StreamedResponse>(<Future<http.StreamedResponse>>[
            sendFuture,
            cancelFuture.then<http.StreamedResponse>((_) => throw cancelled()),
          ]);
    final configured = options.connectTimeout;
    final headTimeout =
        configured != null && configured > Duration.zero
        ? configured
        : fallbackHeadTimeout;
    late final http.StreamedResponse response;
    try {
      response = await pending.timeout(
        headTimeout,
        onTimeout: () => throw DioException.connectionTimeout(
          timeout: headTimeout,
          requestOptions: options,
        ),
      );
    } catch (_) {
      // Any failure (timeout, cancellation, native transport error) marks
      // the request cancelled so a late native response stream is drained
      // instead of lingering unconsumed, then best-effort cleanup runs
      // before the original error propagates to Dio.
      isCancelled = true;
      unawaited(subscription?.cancel());
      unawaited(closeSink());
      rethrow;
    }
    final headers = response.headers.map(
      (key, value) => MapEntry(key, <String>[value]),
    );

    // Keep the response stream live for SSE and long assistant responses.
    return ResponseBody(
      response.stream.map(Uint8List.fromList),
      response.statusCode,
      headers: headers,
      statusMessage: response.reasonPhrase,
      isRedirect: response.isRedirect,
    );
  }

  @override
  void close({bool force = false}) {}
}
