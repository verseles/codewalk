import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_catalog_source.dart';

SessionCatalogSource createSessionCatalogSource(
  EndpointProfile profile,
  EndpointCredential credential,
) => _UnsupportedSource(profile);

final class _UnsupportedSource implements SessionCatalogSource {
  _UnsupportedSource(EndpointProfile profile)
    : harness = HarnessRef(HostId(profile.id), HarnessInstanceId(profile.id));
  @override
  final HarnessRef harness;
  @override
  SessionCatalogTask list(SessionQuery query) => _UnsupportedTask();
  @override
  void close() {}
}

final class _UnsupportedTask implements SessionCatalogTask {
  @override
  Future<Page<SessionSummary>> get result => Future.error(
    const SessionCatalogException(SessionCatalogFailure.unsupportedPlatform),
  );
  @override
  void cancel() {}
}
