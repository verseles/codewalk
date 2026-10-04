import 'errors.dart';
import 'identity.dart';
import 'values.dart';

enum MutationOperation {
  create,
  prompt,
  interrupt,
  respond,
  selection,
  cancelQueued,
  editQueued,
  reorderQueued,
  revertStage,
  revertClear,
  revertCommit,
  fork,
  archive,
  delete,
  resume,
  background,
  childInput,
  filesWrite,
  terminalOpen,
  terminalInput,
  terminalResize,
  terminalClose,
  unknown,
}

enum OperationPhase { initial, pending, promoted, cancelled, settled, unknown }

enum ReplayPolicy { reconcileOnly, verifiedUnresolvedAdmission }

enum AdmissionKnowledge {
  unresolved,
  admitted,
  rejected,
  cancelled,
  settled,
  unknown,
}

enum CancellationFence {
  none,
  requested,
  submitting,
  uncertain,
  cancelled,
  settled,
  unknown,
}

/// Original canonical intent is immutable. Its exact native encoding is retained
/// by adapter persistence and supplied for equality checking at replay time.
final class OriginalCommand {
  OriginalCommand({
    required this.id,
    required this.harness,
    required this.owner,
    required this.operation,
    required String connectedVersion,
    required this.intent,
  }) : connectedVersion = requireText(connectedVersion, 'connectedVersion') {
    if (owner.isKnown && owner.harness != harness) {
      throw ArgumentError('Command owner belongs to another harness');
    }
  }
  final CommandId id;
  final HarnessRef harness;
  final DomainOwner owner;
  final OpenValue<MutationOperation> operation;
  final String connectedVersion;
  final CanonicalValue intent;
}

final class ReplayDecision {
  const ReplayDecision._(this.allowed, this.reason);
  final bool allowed;
  final String reason;
}

/// No guarantee is inferred from a command ID, an error, or another operation.
final class OperationContract {
  OperationContract({
    required this.harness,
    required this.operation,
    required String connectedVersion,
    required this.phase,
    this.replay = ReplayPolicy.reconcileOnly,
    this.evidence,
  }) : connectedVersion = requireText(connectedVersion, 'connectedVersion') {
    if (replay == ReplayPolicy.verifiedUnresolvedAdmission &&
        (evidence == null || evidence!.isEmpty)) {
      throw ArgumentError(
        'Verified replay requires operation-specific evidence',
      );
    }
  }
  final HarnessRef harness;
  final OpenValue<MutationOperation> operation;
  final String connectedVersion;
  final OpenValue<OperationPhase> phase;
  final ReplayPolicy replay;
  final String? evidence;

  ReplayDecision evaluate({
    required OriginalCommand original,
    required OriginalCommand candidate,
    required String persistedOriginalPayload,
    required String candidatePayload,
    required AdmissionKnowledge admission,
    required OpenValue<OperationPhase> currentPhase,
    required OpenValue<CancellationFence> cancellation,
    required bool reconciled,
  }) {
    ReplayDecision deny(String reason) => ReplayDecision._(false, reason);
    if (replay != ReplayPolicy.verifiedUnresolvedAdmission) {
      return deny('reconcileOnly');
    }
    if (!reconciled) return deny('reconciliationRequired');
    if (admission != AdmissionKnowledge.unresolved) {
      return deny('admissionResolved');
    }
    if (cancellation.known != CancellationFence.none) {
      return deny('cancellationFence');
    }
    if (!original.owner.isKnown || !candidate.owner.isKnown) {
      return deny('unknownOwner');
    }
    if (operation.known == null ||
        operation.known == MutationOperation.unknown ||
        phase.known == null ||
        phase.known == OperationPhase.unknown ||
        phase.known == OperationPhase.promoted ||
        phase.known == OperationPhase.cancelled ||
        phase.known == OperationPhase.settled) {
      return deny('unknownOrTerminalContract');
    }
    if (harness != original.harness ||
        harness != candidate.harness ||
        operation != original.operation ||
        operation != candidate.operation ||
        connectedVersion != original.connectedVersion ||
        connectedVersion != candidate.connectedVersion ||
        phase != currentPhase) {
      return deny('operationVersionPhaseMismatch');
    }
    if (original.id != candidate.id ||
        original.harness != candidate.harness ||
        !original.owner.hasSameScope(candidate.owner)) {
      return deny('scopeMismatch');
    }
    if (original.intent != candidate.intent ||
        persistedOriginalPayload.isEmpty ||
        persistedOriginalPayload != candidatePayload) {
      return deny('payloadMismatch');
    }
    return const ReplayDecision._(true, 'verifiedUnresolvedAdmission');
  }
}

enum ReceiptState {
  accepted,
  rejected,
  duplicate,
  uncertain,
  unavailable,
  unknown,
}

final class CommandReceipt {
  CommandReceipt.accepted({
    required this.id,
    required this.owner,
    this.nativeRef,
  }) : state = const OpenValue.known(ReceiptState.accepted),
       admissionKnown = true,
       error = null,
       unavailable = null,
       reason = null,
       details = null;
  CommandReceipt.duplicate({
    required this.id,
    required this.owner,
    required CommandReceipt original,
  }) : state = const OpenValue.known(ReceiptState.duplicate),
       admissionKnown = original.admissionKnown,
       nativeRef = original.nativeRef,
       error = original.error,
       unavailable = original.unavailable,
       reason = original.reason,
       details = original.details {
    if (id != original.id || !owner.hasSameScope(original.owner)) {
      throw ArgumentError(
        'Duplicate receipt does not match original command scope',
      );
    }
  }
  CommandReceipt.rejected({
    required this.id,
    required this.owner,
    required this.error,
  }) : state = const OpenValue.known(ReceiptState.rejected),
       admissionKnown = false,
       nativeRef = null,
       unavailable = null,
       reason = null,
       details = null;
  CommandReceipt.uncertain({
    required this.id,
    required this.owner,
    required String reason,
    this.error,
  }) : state = const OpenValue.known(ReceiptState.uncertain),
       admissionKnown = false,
       nativeRef = null,
       unavailable = null,
       reason = requireText(reason),
       details = null;
  CommandReceipt.unavailable({
    required this.id,
    required this.owner,
    required CapabilityUnavailable this.unavailable,
  }) : state = const OpenValue.known(ReceiptState.unavailable),
       admissionKnown = false,
       nativeRef = null,
       error = null,
       reason = unavailable.reason,
       details = null;
  CommandReceipt.unknown({
    required this.id,
    required this.owner,
    required String rawState,
    this.details,
  }) : state = OpenValue.unknown(rawState),
       admissionKnown = false,
       nativeRef = null,
       error = null,
       unavailable = null,
       reason = 'unknownReceipt';
  final CommandId id;
  final DomainOwner owner;
  final OpenValue<ReceiptState> state;
  final bool admissionKnown;
  final String? nativeRef;
  final ErrorInfo? error;
  final CapabilityUnavailable? unavailable;
  final String? reason;
  final CanonicalValue? details;
}
