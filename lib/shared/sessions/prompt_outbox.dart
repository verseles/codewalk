import 'package:codewalk_core/codewalk_core.dart';

/// One locally recorded prompt. [state] is never `draft`: an entry exists only
/// once its exact payload was durably written, before any POST. `sending`
/// found after a restart is reported as `uncertain`, never as unsent.
final class OutboxEntry {
  const OutboxEntry({
    required this.session,
    required this.commandId,
    required this.messageId,
    required this.text,
    required this.delivery,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.reason,
    this.replays = 0,
    this.fence = CancellationFence.none,
  });
  final SessionRef session;
  final CommandId commandId;
  final String messageId;
  final String text;
  final Delivery delivery;
  final SubmissionKind state;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// A finite category such as `ConflictError` or `timeout`; never server
  /// text.
  final String? reason;

  /// Same-id replays posted after the original send.
  final int replays;

  /// Anything but `none` stops every replay of this entry.
  final CancellationFence fence;
}

/// [entry] is null when nothing was recorded or sent, so the caller keeps the
/// draft; [refusal] then says why. Otherwise the prompt belongs to [entry],
/// whose state decides what happened; [sent] says whether this call posted.
final class OutboxSubmission {
  const OutboxSubmission._({this.entry, this.refusal, this.sent = false});
  const OutboxSubmission.refused(String reason) : this._(refusal: reason);
  const OutboxSubmission.recorded(OutboxEntry entry, {required bool sent})
    : this._(entry: entry, sent: sent);
  final OutboxEntry? entry;
  final String? refusal;
  final bool sent;
}

/// [entry] is null when the outbox is unreadable or does not hold the
/// command ([refusal] says which); otherwise it is the entry after the call
/// and [posts] counts the replays this call sent.
final class OutboxReconciliation {
  const OutboxReconciliation._({this.entry, this.refusal, this.posts = 0});
  const OutboxReconciliation.refused(String reason) : this._(refusal: reason);
  const OutboxReconciliation.recorded(OutboxEntry entry, {required int posts})
    : this._(entry: entry, posts: posts);
  final OutboxEntry? entry;
  final String? refusal;
  final int posts;
}

/// The result of a queue cancel or delivery switch. [entry] is null when
/// nothing was attempted ([refusal] says why); otherwise it is the entry
/// after the call, whose state, delivery and fence tell what the server
/// shows, never the request's status alone.
final class OutboxMutation {
  const OutboxMutation._({this.entry, this.refusal});
  const OutboxMutation.refused(String reason) : this._(refusal: reason);
  const OutboxMutation.recorded(OutboxEntry entry) : this._(entry: entry);
  final OutboxEntry? entry;
  final String? refusal;
}

/// Records each prompt before sending it and keeps the outcome. Only
/// [reconcile] ever sends a prompt again, under its original id.
abstract interface class PromptOutbox {
  /// An optional transient intent is checked again after local persistence,
  /// before the initial POST. Once that request starts, normal reconciliation
  /// still owns its result.
  Future<OutboxSubmission> submit({
    required SessionRef session,
    required CommandId commandId,
    required PromptDraft draft,
    required Delivery delivery,
    bool Function()? isCurrent,
  });

  /// Entries of [session], oldest first, without network access.
  Future<List<OutboxEntry>> entries(SessionRef session);

  /// Forgets an entry the caller resolved or abandoned (an uncertain one only
  /// after reconciling, or when the user gives it up); refuses `sending`. A
  /// forgotten command is never posted again.
  Future<bool> dismiss(SessionRef session, CommandId commandId);

  /// Resolves an uncertain entry from the server's inbox and history by its
  /// native id. Only when that proves the prompt absent, and the verified
  /// contract allows it, the exact recorded payload is posted again under
  /// the same id, a bounded number of times with backoff. An entry whose
  /// cancel is still unsettled is checked the same way, never sent again
  /// (neither its prompt nor its cancel). Any other entry is returned
  /// unchanged, without network access.
  Future<OutboxReconciliation> reconcile(
    SessionRef session,
    CommandId commandId,
  );

  /// Cancels a queued or steered prompt not yet delivered. A cancellation
  /// fence is durable before the request and never cleared, so the prompt is
  /// never sent again; the entry ends `cancelled` only when the server no
  /// longer holds it, `delivered` when it was delivered first, and otherwise
  /// keeps its state with the fence until a later check decides.
  Future<OutboxMutation> cancel(SessionRef session, CommandId commandId);

  /// Changes the delivery of an admitted, still pending prompt (steering
  /// wakes execution). The recorded delivery follows what the server shows
  /// afterwards; the original payload is kept.
  Future<OutboxMutation> switchDelivery(
    SessionRef session,
    CommandId commandId,
    Delivery delivery,
  );
}
