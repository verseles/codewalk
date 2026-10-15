import 'package:codewalk_core/codewalk_core.dart';

enum SessionLiveFailure {
  authenticationRequired,
  unavailable,
  notFound,
  rateLimited,
  timeout,
  incompatibleResponse,
  sourceChanged,
  cancelled,
  unsupportedPlatform,
  connection,
  capacity,
}

final class SessionLiveException implements Exception {
  const SessionLiveException(this.failure);
  final SessionLiveFailure failure;
  @override
  String toString() => failure.name;
}

enum SessionLivePhase {
  probing,
  connecting,
  hydrating,
  live,
  reconnecting,
  degraded,
  evicted,
  authRequired,
  incompatible,
  closed,
}

/// One observer's view of a watched session. [lastSyncedAt] is local observer
/// time, never a server clock; [stale] marks a resident state that is no
/// longer kept current.
final class SessionLiveView {
  const SessionLiveView({
    required this.session,
    required this.phase,
    this.failure,
    this.version,
    this.lastSyncedAt,
    this.stale = false,
    this.state,
  });
  final SessionRef session;
  final SessionLivePhase phase;
  final SessionLiveFailure? failure;
  final String? version;
  final DateTime? lastSyncedAt;
  final bool stale;
  final SessionState? state;
}

/// One screen's lease on a live session. Closing it never mutates the server.
abstract interface class SessionLiveHandle {
  SessionRef get session;
  SessionLiveView get current;

  /// Emits the current view on listen, then every change.
  Stream<SessionLiveView> get updates;
  void close();
}

/// Shares one event stream per endpoint profile across every open handle.
abstract interface class SessionLiveDirectory {
  Future<SessionLiveHandle> open({
    required EndpointProfile profile,
    required EndpointCredential credential,
    required SessionRef session,
  });
  Future<void> close();
}
