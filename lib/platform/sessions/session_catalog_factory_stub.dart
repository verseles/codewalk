import 'package:codewalk_core/codewalk_core.dart';
import '../../shared/sessions/session_activity.dart';
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
  SessionReadTask read(SessionRef ref) => _UnsupportedRead();
  @override
  Future<SessionActivity> activity({String? directory}) async =>
      const SessionActivity();
  @override
  SessionCatalogRead<List<ProjectRef>> projects() => _UnsupportedRequest();
  @override
  SessionCatalogRead<ProjectRef> location({String? directory}) =>
      _UnsupportedRequest();
  @override
  SessionCatalogRead<List<FileEntry>> listDirectory(
    String directory, {
    String? path,
  }) => _UnsupportedRequest();
  @override
  SessionCatalogRead<List<FileEntry>> findDirectories(
    String directory,
    String query,
  ) => _UnsupportedRequest();
  @override
  void close() {}
}

final class _UnsupportedRequest<T> implements SessionCatalogRead<T> {
  @override
  Future<T> get result => Future.error(
    const SessionCatalogException(SessionCatalogFailure.unsupportedPlatform),
  );
  @override
  void cancel() {}
}

final class _UnsupportedTask implements SessionCatalogTask {
  @override
  Future<Page<SessionSummary>> get result => Future.error(
    const SessionCatalogException(SessionCatalogFailure.unsupportedPlatform),
  );
  @override
  void cancel() {}
}

final class _UnsupportedRead implements SessionReadTask {
  @override
  Future<SessionSummary> get result => Future.error(
    const SessionCatalogException(SessionCatalogFailure.unsupportedPlatform),
  );
  @override
  void cancel() {}
}
