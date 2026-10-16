import 'package:codewalk_core/codewalk_core.dart';

/// Local action state only; execution remains owned by the live snapshot.
enum SessionStopPhase {
  ready,
  requesting,
  requested,
  idle,
  unconfirmed,
  refused,
}

final class SessionStopState {
  const SessionStopState({this.phase = SessionStopPhase.ready, this.receipt});
  final SessionStopPhase phase;
  final CommandReceipt? receipt;
  bool get busy =>
      phase == SessionStopPhase.requesting ||
      phase == SessionStopPhase.requested;
}
