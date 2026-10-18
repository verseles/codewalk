import 'package:codewalk_core/codewalk_core.dart';

import 'prompt_outbox.dart';
import 'session_permission_reply.dart';
import 'session_stop.dart';
import 'session_unrestricted.dart';

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

  /// The only way this lease sends: null when it cannot (no ledger storage,
  /// closed lease). The lease itself never sends on its own.
  PromptOutbox? get outbox;

  /// Explicit control of this session, independent of prompt-ledger storage.
  /// The state and single-flight fence are shared by its open leases.
  SessionStopState get stopState;
  bool get canStop;
  Future<void> stop({required CommandId id});

  /// Whether this lease can send permission replies at all, independent of the
  /// current phase: a card for a resident request stays mounted (disabled)
  /// while the lease is not current, so no typed note is lost.
  bool get supportsReplies;

  /// Explicit permission replies for this session's interactions, independent
  /// of prompt-ledger storage. The per-request state and single-flight fence
  /// are shared by its open leases; closing never replies.
  SessionPermissionReplyState replyState(InteractionId id);
  bool canReply(InteractionRequest request);
  Future<void> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  });

  /// Unrestricted, the session's own server rule (ADR-059 §7): absent when
  /// the lease has no rules client or ownership ledger. The state and the
  /// single-flight fence are shared by its open leases; closing never writes.
  bool get supportsUnrestricted;
  SessionUnrestrictedState get unrestrictedState;
  bool get canEnableUnrestricted;
  bool get canDisableUnrestricted;
  bool get canRefreshUnrestricted;
  Future<void> enableUnrestricted({required CommandId id});
  Future<void> disableUnrestricted({required CommandId id});
  Future<void> refreshUnrestricted();

  /// The native message id [id] was projected from, so a pending row can be
  /// matched to an outbox entry; null for any other item.
  String? nativeMessageOf(ItemId id);
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
