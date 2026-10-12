import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';

import 'history_projection.dart';
import 'session_projection.dart';
import 'version_policy.dart';

enum OpenCodeSessionReadFailure {
  closed,
  cancelled,
  unsupportedQuery,
  invalidScope,
  invalidCursor,
  invalidRequest,
  authenticationRequired,
  notFound,
  rateLimited,
  unavailable,
  incompatibleResponse,
  timeout,
  bodyTooLarge,
  connection,
}

/// Contains no native error message, identifier, URL, body or credential.
final class OpenCodeSessionReadException implements Exception {
  const OpenCodeSessionReadException(this.failure, {this.statusCode});

  final OpenCodeSessionReadFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'OpenCodeSessionReadException(${failure.name}'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}

/// Read-only metadata and flat history; borrows an authenticated transport.
/// Continuation tokens belong to this reader and are not durable credentials.
final class OpenCodeSessionReader {
  OpenCodeSessionReader(
    this.transport, {
    required this.harness,
    this.deadline = const Duration(seconds: 20),
    this.maxBodyBytes = 1024 * 1024,
    this.maxPageItems = 200,
    this.maxHistoryItems = 2000,
  }) : _endpoint = transport.endpoint,
       _cursorScope = List.generate(
         4,
         (_) => Random.secure().nextInt(1 << 32),
       ).join('-') {
    if (deadline <= Duration.zero ||
        maxBodyBytes <= 0 ||
        maxPageItems <= 0 ||
        maxHistoryItems <= 0 ||
        harness.host.value.isEmpty ||
        harness.harness.value.isEmpty) {
      throw ArgumentError('Session read limits must be positive.');
    }
  }

  final EndpointHttpTransport transport;
  final HarnessRef harness;
  final Duration deadline;
  final int maxBodyBytes;
  final int maxPageItems;
  final int maxHistoryItems;
  final Uri _endpoint;
  final String _cursorScope;
  final _active = <_ReadOperation>{};
  bool _disposed = false;

  Future<Page<SessionSummary>> listSessions(
    SessionQuery query, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (query.project != null ||
        query.activeOnly ||
        query.limit > maxPageItems) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.unsupportedQuery,
      );
    }
    final cursor = query.cursor == null ? null : _decodeCursor(query.cursor!);
    final path = Uri(
      path: 'api/session',
      queryParameters: {
        'limit': '${query.limit}',
        if (cursor == null) 'order': 'desc' else 'cursor': cursor,
      },
    ).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?> ||
          value['data'] is! List ||
          value['cursor'] is! Map<String, Object?>) {
        throw const FormatException('Malformed OpenCode session page.');
      }
      final rows = value['data'] as List;
      if (rows.length > query.limit || rows.length > maxPageItems) {
        throw const FormatException('Session page exceeds its item limit.');
      }
      final items = rows
          .map((row) => projectOpenCodeSession(row, harness))
          .toList();
      if (items.map((row) => row.info.ref).toSet().length != items.length) {
        throw const FormatException('Duplicate session in one page.');
      }
      final cursors = value['cursor'] as Map<String, Object?>;
      _nativeCursor(cursors['previous']);
      final next = _nativeCursor(cursors['next']);
      if (next != null && next == cursor) {
        throw const FormatException('Session cursor did not advance.');
      }
      return Page(
        items: items,
        nextCursor: next == null ? null : _encodeCursor(next),
      );
    }, cancellation);
  }

  Future<SessionSummary> readSession(
    SessionRef ref, {
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(ref.nativeId);
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final path = Uri(pathSegments: ['api', 'session', ref.nativeId]).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?>) {
        throw const FormatException('Malformed OpenCode session response.');
      }
      final result = projectOpenCodeSession(value['data'], harness);
      if (result.info.ref != ref) {
        throw const FormatException('Session response has another identity.');
      }
      return result;
    }, cancellation);
  }

  /// Reads one ascending history page without assigning causal read barriers.
  /// [sourceVersion] must be observed for this endpoint by the caller; native
  /// message count and projected-item count have independent bounds.
  Future<Page<TimelineItem>> readHistory(
    SessionRef ref, {
    required String sourceVersion,
    int limit = 50,
    String? cursor,
    RequestCancellation? cancellation,
  }) async {
    _checkOpen();
    if (ref.harnessRef != harness) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
    try {
      openCodeSessionId(ref.nativeId);
      if (limit < 1 ||
          limit > min(200, maxPageItems) ||
          OpenCodeCompatibility.parse(sourceVersion) == null ||
          !OpenCodeCompatibility.assess(sourceVersion).canUse) {
        throw const FormatException();
      }
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidRequest,
      );
    }
    final native = cursor == null
        ? null
        : _decodeHistoryCursor(cursor, ref, limit, sourceVersion);
    final path = Uri(
      pathSegments: ['api', 'session', ref.nativeId, 'message'],
      queryParameters: {
        'limit': '$limit',
        if (native == null) 'order': 'asc' else 'cursor': native,
      },
    ).toString();
    return _read(path, (value) {
      if (value is! Map<String, Object?> ||
          value['data'] is! List ||
          value['cursor'] is! Map<String, Object?>) {
        throw const FormatException('Malformed history page.');
      }
      final rows = value['data'] as List;
      if (rows.length > limit) {
        throw const FormatException('History row limit.');
      }
      final cursors = value['cursor'] as Map<String, Object?>;
      _nativeCursor(cursors['previous']);
      final next = _nativeCursor(cursors['next']);
      if (next != null && next == native) {
        throw const FormatException('History cursor did not advance.');
      }
      final items = projectOpenCodeHistory(
        rows.cast<Object?>(),
        ref,
        sourceVersion: sourceVersion,
        maxItems: maxHistoryItems,
      );
      return Page<TimelineItem>(
        items: items,
        nextCursor: next == null
            ? null
            : _encodeHistoryCursor(next, ref, limit, sourceVersion),
      );
    }, cancellation);
  }

  String _encodeHistoryCursor(
    String native,
    SessionRef ref,
    int limit,
    String sourceVersion,
  ) {
    if (utf8.decode(utf8.encode(native)) != native) {
      throw const FormatException('Malformed history continuation.');
    }
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'version': 2,
          'kind': 'history',
          'scope': _cursorScope,
          'ref': ref.storageKey,
          'order': 'asc',
          'limit': limit,
          'sourceVersion': sourceVersion,
          'native': native,
        }),
      ),
    );
    if (encoded.length > 32 * 1024) {
      throw const FormatException('History continuation exceeds its limit.');
    }
    return encoded;
  }

  String _decodeHistoryCursor(
    String value,
    SessionRef ref,
    int limit,
    String sourceVersion,
  ) {
    try {
      if (value.length > 32 * 1024) throw const FormatException();
      final data = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (data is! Map<String, Object?> ||
          data['version'] != 2 ||
          data['kind'] != 'history' ||
          data['scope'] != _cursorScope ||
          data['ref'] != ref.storageKey ||
          data['order'] != 'asc' ||
          data['limit'] != limit ||
          data['sourceVersion'] != sourceVersion) {
        throw const FormatException();
      }
      return _nativeCursor(data['native']) ?? (throw const FormatException());
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidCursor,
      );
    }
  }

  /// Disposes owned reads, never the borrowed transport or caller signal.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final operation in _active.toList()) {
      operation.stop(OpenCodeSessionReadFailure.closed);
    }
  }

  void _checkOpen() {
    if (_disposed || transport.isClosed) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.closed,
      );
    }
    if (transport.endpoint != _endpoint) {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidScope,
      );
    }
  }

  Future<T> _read<T>(
    String path,
    T Function(Object?) project,
    RequestCancellation? parent,
  ) async {
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
        _collect(path, project, operation),
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
      maxBytes: maxBodyBytes,
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

  String _encodeCursor(String native) => base64Url.encode(
    utf8.encode(
      jsonEncode({'version': 1, 'scope': _cursorScope, 'native': native}),
    ),
  );

  String _decodeCursor(String value) {
    try {
      if (value.length > 32 * 1024) throw const FormatException();
      final data = jsonDecode(utf8.decode(base64Url.decode(value)));
      if (data is! Map<String, Object?> ||
          data['version'] != 1 ||
          data['scope'] != _cursorScope) {
        throw const FormatException();
      }
      return _nativeCursor(data['native']) ?? (throw const FormatException());
    } on FormatException {
      throw const OpenCodeSessionReadException(
        OpenCodeSessionReadFailure.invalidCursor,
      );
    }
  }

  String? _nativeCursor(Object? value) {
    if (value == null) return null;
    if (value is! String ||
        value.isEmpty ||
        utf8.encode(value).length > 16 * 1024) {
      throw const FormatException('Malformed OpenCode cursor.');
    }
    return value;
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
