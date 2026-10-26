import 'dart:async';
import 'dart:convert';

import 'package:codewalk_net/codewalk_net.dart';

import 'session_reader.dart';

/// One endpoint's bounded JSON reads: each GET has a total deadline, a body
/// limit and the caller's cancellation, and ends in a finite read failure.
///
/// The transport and the caller's signal are borrowed: disposing stops the
/// owned reads only.
final class OpenCodeJsonReads {
  OpenCodeJsonReads(
    this.transport, {
    required this.deadline,
    required this.maxBodyBytes,
    required void Function() checkOpen,
  }) : _checkOpen = checkOpen;

  final EndpointHttpTransport transport;
  final Duration deadline;
  final int maxBodyBytes;

  /// Throws when the owning reader is closed or its endpoint changed.
  final void Function() _checkOpen;
  final _active = <_ReadOperation>{};

  /// Stops the reads in flight; each fails as closed.
  void dispose() {
    for (final operation in _active.toList()) {
      operation.stop(OpenCodeSessionReadFailure.closed);
    }
  }

  Future<T> read<T>(
    String path,
    T Function(Object?) project,
    RequestCancellation? parent, {
    int? maxBytes,
  }) async {
    if (parent?.isCancelled ?? false) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    final operation = _ReadOperation(deadline);
    _active.add(operation);
    final subscription = parent?.onCancel.listen(
      (_) => operation.stop(OpenCodeSessionReadFailure.cancelled),
    );
    T result;
    try {
      result = await Future.any([
        _collect(path, project, operation, maxBytes ?? maxBodyBytes),
        operation.stopped.future.then<T>((_) => throw operation.failure!),
      ]);
    } on OpenCodeSessionReadException {
      rethrow;
    } on TransportException catch (error) {
      throw _transportError(error);
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    } on Object {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.connection,
      );
    } finally {
      operation.finish();
      _active.remove(operation);
      await subscription?.cancel();
    }
    _checkOpen();
    if (operation.cleanupFailed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.connection,
      );
    }
    if (parent?.isCancelled ?? false) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    if (operation.clock.elapsed >= deadline) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.timeout,
      );
    }
    return result;
  }

  Future<T> _collect<T>(
    String path,
    T Function(Object?) project,
    _ReadOperation operation,
    int maxBytes,
  ) async {
    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        path: path,
        headers: const {'Accept': 'application/json'},
      ),
      cancellation: operation.cancellation,
    );
    if (operation.finished || operation.failure != null) {
      operation.cancelResponse(response);
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.cancelled,
      );
    }
    operation.response = response;
    if (response.statusCode != 200) throw _statusError(response.statusCode);
    final media = response
        .header('content-type')
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (media != 'application/json' &&
        !(media?.startsWith('application/') == true &&
            media!.endsWith('+json'))) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.incompatibleResponse,
      );
    }
    final bytes = await response.readBytes(
      maxBytes: maxBytes,
      inactivityTimeout: deadline,
    );
    if (operation.failure != null) throw operation.failure!;
    _checkOpen();
    if (operation.clock.elapsed >= deadline) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.timeout,
      );
    }
    return project(jsonDecode(utf8.decode(bytes)));
  }
}

final class _ReadOperation {
  _ReadOperation(Duration deadline) {
    timer = Timer(deadline, () => stop(OpenCodeSessionReadFailure.timeout));
  }

  final clock = Stopwatch()..start();
  final cancellation = RequestCancellation();
  final stopped = Completer<void>();
  late final Timer timer;
  TransportResponse? response;
  OpenCodeSessionReadException? failure;
  bool finished = false;
  bool cleanupFailed = false;

  void stop(OpenCodeSessionReadFailure reason) {
    if (finished || failure != null) return;
    failure = OpenCodeSessionReadException(reason);
    stopped.complete();
    cancellation.cancel();
    cancelResponse(response);
  }

  void finish() {
    finished = true;
    timer.cancel();
    cancellation.cancel();
    cancelResponse(response);
  }

  void cancelResponse(TransportResponse? value) {
    try {
      value?.cancel();
    } on Object {
      // A late response cannot replace an already reported cancellation.
      cleanupFailed = true;
    }
  }
}

OpenCodeSessionReadException _statusError(int status) =>
    OpenCodeSessionReadException(switch (status) {
      400 => OpenCodeSessionReadFailure.invalidRequest,
      401 || 403 => OpenCodeSessionReadFailure.authenticationRequired,
      404 => OpenCodeSessionReadFailure.notFound,
      408 => OpenCodeSessionReadFailure.timeout,
      429 => OpenCodeSessionReadFailure.rateLimited,
      500 || 502 || 503 || 504 => OpenCodeSessionReadFailure.unavailable,
      _ => OpenCodeSessionReadFailure.incompatibleResponse,
    }, statusCode: status);

OpenCodeSessionReadException _transportError(TransportException error) =>
    OpenCodeSessionReadException(switch (error.failure) {
      TransportFailure.closed => OpenCodeSessionReadFailure.closed,
      TransportFailure.cancelled => OpenCodeSessionReadFailure.cancelled,
      TransportFailure.timeout => OpenCodeSessionReadFailure.timeout,
      TransportFailure.bodyTooLarge => OpenCodeSessionReadFailure.bodyTooLarge,
      TransportFailure.invalidTarget || TransportFailure.invalidRequest =>
        OpenCodeSessionReadFailure.invalidRequest,
      _ => OpenCodeSessionReadFailure.connection,
    }, statusCode: error.statusCode);
