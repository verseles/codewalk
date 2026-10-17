import 'package:codewalk_core/codewalk_core.dart';

/// Local action state only; canonical interactions remain owned by the live
/// snapshot, which alone removes a card when its request settles.
enum SessionPermissionReplyPhase {
  ready,
  requesting,
  requested,
  idle,
  unconfirmed,
  refused,
}

final class SessionPermissionReplyState {
  const SessionPermissionReplyState({
    this.phase = SessionPermissionReplyPhase.ready,
    this.receipt,
  });
  final SessionPermissionReplyPhase phase;
  final CommandReceipt? receipt;
  bool get busy =>
      phase == SessionPermissionReplyPhase.requesting ||
      phase == SessionPermissionReplyPhase.requested;
}
