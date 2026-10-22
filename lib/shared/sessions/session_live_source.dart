import 'package:codewalk_core/codewalk_core.dart';

import 'prompt_outbox.dart';
import 'session_catalog_changes.dart';
import 'session_permission_reply.dart';
import 'session_selection.dart';
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

/// The paging of older history into the live window: local action state only;
/// the window itself is the live snapshot. [failure] is the last read's.
final class SessionOlderHistoryState {
  const SessionOlderHistoryState({
    this.loading = false,
    this.failure,
    this.trimmed = false,
  });
  final bool loading;
  final SessionLiveFailure? failure;

  /// The window lost rows in front of the oldest one paged in: they exist
  /// and are no longer resident, so only the history viewer reaches them.
  final bool trimmed;
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
  /// [owner] is the request's owning session when it is a child's request
  /// shown in this lease's session; the fence is keyed by the owner.
  SessionPermissionReplyState replyState(InteractionId id, {SessionRef? owner});
  bool canReply(InteractionRequest request);
  Future<void> reply({
    required InteractionRequest request,
    required ApprovalResponse response,
    required CommandId id,
  });

  /// Explicit form replies and dismissals for this session's interactions.
  bool canReplyForm(InteractionRequest request);
  Future<void> replyForm({
    required InteractionRequest request,
    required FormResponse response,
    required CommandId id,
  });
  Future<void> dismissForm({
    required InteractionRequest request,
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

  /// The session's model and agent: absent when the lease cannot switch
  /// them. The state and the single-flight fence are shared by its open
  /// leases, and a pending or unconfirmed change holds this session's sends.
  /// A switch is never repeated on its own; closing never switches.
  bool get supportsSelection;
  SessionSelectionState get selectionState;
  bool get canChangeSelection;

  /// Switches the whole model reference; a null [variant] clears it.
  Future<void> selectModel({
    required String modelId,
    required String providerId,
    String? variant,
    required CommandId id,
  });
  Future<void> selectAgent({required String agentId, required CommandId id});

  /// Reads the catalog again and, for an unconfirmed change, the session's
  /// record, which settles it.
  Future<void> refreshSelection();

  /// Older history, one page at a time, prepended to the resident window.
  /// The state and the single-flight fence are shared by the session's open
  /// leases. Loading is refused when no older page exists, when the window is
  /// full, or when the window lost rows in front; the history viewer is the
  /// fallback then.
  SessionOlderHistoryState get olderHistory;
  bool get canLoadOlderHistory;
  Future<void> loadOlderHistory();

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

  /// The session lifecycle feed of one selected profile, sharing the
  /// endpoint's single event stream with its live sessions. Acquiring it
  /// never opens a second subscription.
  Future<SessionCatalogChanges> catalogChanges({
    required EndpointProfile profile,
    required EndpointCredential credential,
  });

  Future<void> close();
}
