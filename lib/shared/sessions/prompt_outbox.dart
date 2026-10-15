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

/// Records each prompt before sending it and keeps the outcome; it never
/// resends on its own.
abstract interface class PromptOutbox {
  Future<OutboxSubmission> submit({
    required SessionRef session,
    required CommandId commandId,
    required PromptDraft draft,
    required Delivery delivery,
  });

  /// Entries of [session], oldest first, without network access.
  Future<List<OutboxEntry>> entries(SessionRef session);

  /// Forgets an entry the caller resolved or abandoned (an uncertain one only
  /// after reconciling, or when the user gives it up); refuses `sending`. A
  /// forgotten command is never posted again.
  Future<bool> dismiss(SessionRef session, CommandId commandId);
}
