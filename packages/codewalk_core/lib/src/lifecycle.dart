import 'errors.dart';
import 'identity.dart';
import 'values.dart';

enum ConnectionKind {
  unpaired,
  authenticating,
  connecting,
  hydrating,
  live,
  degraded,
  reconnecting,
  authRequired,
  incompatible,
  unknown,
}

final class ConnectionState {
  const ConnectionState({required this.kind, this.reason, this.error});
  final OpenValue<ConnectionKind> kind;
  final String? reason;
  final ErrorInfo? error;
}

enum ExecutionKind {
  unknown,
  idle,
  running,
  waitingForApproval,
  waitingForInput,
  retrying,
  interrupting,
  interruptedPendingResume,
}

enum ExecutionOutcomeKind { succeeded, failed, interrupted, unknown }

final class ExecutionOutcome {
  const ExecutionOutcome(this.kind, {this.error, this.reason});
  final OpenValue<ExecutionOutcomeKind> kind;
  final ErrorInfo? error;
  final String? reason;
}

/// Connection confidence and child outcomes are not derived from this state.
final class ExecutionState {
  const ExecutionState({
    required this.kind,
    this.retryAt,
    this.error,
    this.lastOutcome,
  });
  final OpenValue<ExecutionKind> kind;
  final DateTime? retryAt;
  final ErrorInfo? error;
  final ExecutionOutcome? lastOutcome;
}

enum SubmissionKind {
  draft,
  sending,
  admitted,
  delivered,
  settled,
  rejected,
  uncertain,
  cancelled,
  unknown,
}

enum Delivery { steer, queue, immediate, unknown }

final class SubmissionState {
  const SubmissionState({required this.kind, this.delivery, this.error});
  final OpenValue<SubmissionKind> kind;
  final OpenValue<Delivery>? delivery;
  final ErrorInfo? error;
}

enum InteractionStateKind { pending, submitting, resolved, failed, unknown }

final class InteractionState {
  const InteractionState({required this.kind, this.error});
  final OpenValue<InteractionStateKind> kind;
  final ErrorInfo? error;
}

enum RevertKind { none, staged, committed, cleared, unknown }

final class RevertState {
  const RevertState({required this.kind, this.boundary, this.details});
  final OpenValue<RevertKind> kind;
  final ItemId? boundary;
  final CanonicalValue? details;
}
