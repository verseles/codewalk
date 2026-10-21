import 'package:codewalk_core/codewalk_core.dart';

typedef SessionCatalogFactory =
    SessionCatalogSource Function(
      EndpointProfile profile,
      EndpointCredential credential,
    );

enum SessionCatalogFailure {
  authenticationRequired,
  unavailable,
  rateLimited,
  timeout,
  incompatibleResponse,
  invalidCursor,
  cancelled,
  unsupportedPlatform,
  connection,

  /// The server holds no session under the read identity.
  notFound,
}

final class SessionCatalogException implements Exception {
  const SessionCatalogException(this.failure);
  final SessionCatalogFailure failure;
  @override
  String toString() => failure.name;
}

abstract interface class SessionCatalogSource {
  HarnessRef get harness;
  SessionCatalogTask list(SessionQuery query);

  /// Reads one session of this server, for a link to a session outside the
  /// loaded rows.
  SessionReadTask read(SessionRef ref);
  void close();
}

abstract interface class SessionCatalogTask {
  Future<Page<SessionSummary>> get result;
  void cancel();
}

abstract interface class SessionReadTask {
  Future<SessionSummary> get result;
  void cancel();
}
