import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_source.dart';

SessionCatalogSource createSessionCatalogSource(
  EndpointProfile profile,
  EndpointCredential credential,
) => _NativeSource(profile, credential);

final class _NativeSource implements SessionCatalogSource {
  _NativeSource(EndpointProfile profile, EndpointCredential credential)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id)) {
    _transport = IoEndpointHttpTransport(
      endpoint: profile.endpoint,
      headers: basicEndpointHeaders(
        endpoint: profile.endpoint,
        username: 'opencode',
        secret: () => credential.secret,
      ),
    );
    _reader = OpenCodeSessionReader(_transport, harness: harness);
  }
  @override
  final HarnessRef harness;
  late final IoEndpointHttpTransport _transport;
  late final OpenCodeSessionReader _reader;
  bool _closed = false;
  @override
  SessionCatalogTask list(SessionQuery query) => _NativeTask(_reader, query);
  @override
  SessionReadTask read(SessionRef ref) => _NativeRead(_reader, ref);

  /// The active map, and the pending lists of [directory]. A part whose read
  /// fails is left unknown; the other part still counts.
  @override
  Future<SessionActivity> activity({String? directory}) async {
    Set<SessionRef> refs(Set<String> ids) => {
      for (final id in ids) SessionRef(harness.host, harness.harness, id),
    };
    Set<SessionRef>? running;
    Set<SessionRef>? waiting;
    if (!_closed) {
      try {
        running = refs(await _reader.readActiveSessions());
      } on Object {
        running = null;
      }
    }
    if (!_closed && directory != null) {
      try {
        waiting = refs(await _reader.readPendingSessions(directory));
      } on Object {
        waiting = null;
      }
    }
    return SessionActivity(
      running: running,
      directory: directory,
      waiting: waiting,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _reader.dispose();
    _transport.close();
  }
}

final class _NativeTask implements SessionCatalogTask {
  _NativeTask(OpenCodeSessionReader reader, SessionQuery query) {
    result = _read(reader, query);
  }
  final _cancellation = RequestCancellation();
  @override
  late final Future<Page<SessionSummary>> result;
  Future<Page<SessionSummary>> _read(
    OpenCodeSessionReader reader,
    SessionQuery query,
  ) async {
    try {
      return await reader.listSessions(query, cancellation: _cancellation);
    } on OpenCodeSessionReadException catch (error) {
      throw SessionCatalogException(_failure(error.failure));
    } on Object {
      throw const SessionCatalogException(SessionCatalogFailure.connection);
    }
  }

  @override
  void cancel() => _cancellation.cancel();
}

final class _NativeRead implements SessionReadTask {
  _NativeRead(OpenCodeSessionReader reader, SessionRef ref) {
    result = _read(reader, ref);
  }
  final _cancellation = RequestCancellation();
  @override
  late final Future<SessionSummary> result;
  Future<SessionSummary> _read(
    OpenCodeSessionReader reader,
    SessionRef ref,
  ) async {
    try {
      return await reader.readSession(ref, cancellation: _cancellation);
    } on OpenCodeSessionReadException catch (error) {
      throw SessionCatalogException(_failure(error.failure, read: true));
    } on Object {
      throw const SessionCatalogException(SessionCatalogFailure.connection);
    }
  }

  @override
  void cancel() => _cancellation.cancel();
}

SessionCatalogFailure _failure(
  OpenCodeSessionReadFailure failure, {
  bool read = false,
}) => switch (failure) {
  OpenCodeSessionReadFailure.authenticationRequired =>
    SessionCatalogFailure.authenticationRequired,
  OpenCodeSessionReadFailure.rateLimited => SessionCatalogFailure.rateLimited,
  OpenCodeSessionReadFailure.timeout => SessionCatalogFailure.timeout,
  OpenCodeSessionReadFailure.invalidCursor =>
    SessionCatalogFailure.invalidCursor,
  OpenCodeSessionReadFailure.cancelled ||
  OpenCodeSessionReadFailure.closed => SessionCatalogFailure.cancelled,
  // A list has no single session to miss; a read names one.
  OpenCodeSessionReadFailure.notFound =>
    read ? SessionCatalogFailure.notFound : SessionCatalogFailure.unavailable,
  OpenCodeSessionReadFailure.unavailable => SessionCatalogFailure.unavailable,
  OpenCodeSessionReadFailure.unsupportedQuery ||
  OpenCodeSessionReadFailure.invalidScope ||
  OpenCodeSessionReadFailure.invalidRequest ||
  OpenCodeSessionReadFailure.incompatibleResponse ||
  OpenCodeSessionReadFailure.bodyTooLarge =>
    SessionCatalogFailure.incompatibleResponse,
  OpenCodeSessionReadFailure.connection => SessionCatalogFailure.connection,
};
