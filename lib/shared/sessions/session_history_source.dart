import 'package:codewalk_core/codewalk_core.dart';

typedef SessionHistoryFactory =
    SessionHistorySource Function(
      EndpointProfile profile,
      EndpointCredential credential,
      SessionRef session,
    );

enum SessionHistoryFailure {
  authenticationRequired,
  unavailable,
  notFound,
  rateLimited,
  timeout,
  incompatibleResponse,
  invalidCursor,
  sourceChanged,
  cancelled,
  unsupportedPlatform,
  connection,
}

final class SessionHistoryException implements Exception {
  const SessionHistoryException(this.failure);
  final SessionHistoryFailure failure;
  @override
  String toString() => failure.name;
}

final class SessionHistoryPageResult {
  const SessionHistoryPageResult(this.session, this.version, this.page);
  final SessionRef session;
  final String version;
  final Page<TimelineItem> page;
}

abstract interface class SessionHistorySource {
  SessionRef get session;
  SessionHistoryTask read({String? cursor});
  void close();
}

abstract interface class SessionHistoryTask {
  Future<SessionHistoryPageResult> get result;
  void cancel();
}
