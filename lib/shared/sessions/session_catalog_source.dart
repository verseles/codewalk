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
  void close();
}

abstract interface class SessionCatalogTask {
  Future<Page<SessionSummary>> get result;
  void cancel();
}
