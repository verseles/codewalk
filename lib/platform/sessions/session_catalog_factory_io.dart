import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net_io.dart';
import 'package:harness_opencode/harness_opencode.dart';
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
      throw SessionCatalogException(switch (error.failure) {
        OpenCodeSessionReadFailure.authenticationRequired =>
          SessionCatalogFailure.authenticationRequired,
        OpenCodeSessionReadFailure.rateLimited =>
          SessionCatalogFailure.rateLimited,
        OpenCodeSessionReadFailure.timeout => SessionCatalogFailure.timeout,
        OpenCodeSessionReadFailure.invalidCursor =>
          SessionCatalogFailure.invalidCursor,
        OpenCodeSessionReadFailure.cancelled ||
        OpenCodeSessionReadFailure.closed => SessionCatalogFailure.cancelled,
        OpenCodeSessionReadFailure.notFound ||
        OpenCodeSessionReadFailure.unavailable =>
          SessionCatalogFailure.unavailable,
        OpenCodeSessionReadFailure.unsupportedQuery ||
        OpenCodeSessionReadFailure.invalidScope ||
        OpenCodeSessionReadFailure.invalidRequest ||
        OpenCodeSessionReadFailure.incompatibleResponse ||
        OpenCodeSessionReadFailure.bodyTooLarge =>
          SessionCatalogFailure.incompatibleResponse,
        OpenCodeSessionReadFailure.connection =>
          SessionCatalogFailure.connection,
      });
    } on Object {
      throw const SessionCatalogException(SessionCatalogFailure.connection);
    }
  }

  @override
  void cancel() => _cancellation.cancel();
}
