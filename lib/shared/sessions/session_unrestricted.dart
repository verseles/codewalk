import 'package:codewalk_core/codewalk_core.dart';

/// What the session's own permission rules say about Unrestricted (ADR-059
/// §7). It is a server rule, independent of the local Ask / Allow all mode,
/// and every phase comes from a read of the rules, never from a request.
enum SessionUnrestrictedPhase {
  /// Not read yet for this lease.
  unknown,

  /// The rules or CodeWalk's ownership record cannot be read or understood,
  /// so nothing may be written.
  unavailable,
  off,

  /// The trailing allow-everything rule is the one CodeWalk added.
  on,

  /// A trailing allow-everything rule CodeWalk did not add; never removed.
  elsewhere,

  /// CodeWalk's record no longer matches the rules: another client changed
  /// them. Nothing is written until the rules match again.
  conflict,
}

/// The outcome of the last explicit action, shown once beside the phase.
enum SessionUnrestrictedNotice { none, refused, unconfirmed, changedElsewhere }

final class SessionUnrestrictedState {
  const SessionUnrestrictedState({
    this.phase = SessionUnrestrictedPhase.unknown,
    this.inEffect = false,
    this.busy = false,
    this.notice = SessionUnrestrictedNotice.none,
    this.receipt,
  });
  final SessionUnrestrictedPhase phase;

  /// The last recognized read ended with the allow-everything rule, whoever
  /// added it; a failed read carries the last known value forward.
  final bool inEffect;

  /// A read or write is in flight for this session.
  final bool busy;
  final SessionUnrestrictedNotice notice;
  final CommandReceipt? receipt;
}

/// Which step of CodeWalk's own insertion a record describes. The stage is
/// stored before each write, so an interrupted write is still recognized.
enum UnrestrictedStage { applying, owned, removing }

/// Fingerprints of the rules without and with CodeWalk's insertion. Rule
/// contents are never stored.
final class UnrestrictedOwnership {
  const UnrestrictedOwnership({
    required this.stage,
    required this.base,
    required this.owned,
  });
  final UnrestrictedStage stage;
  final String base;
  final String owned;

  UnrestrictedOwnership at(UnrestrictedStage next) =>
      UnrestrictedOwnership(stage: next, base: base, owned: owned);
}

/// The server binding an insertion was made through: an opaque digest of
/// the profile, its full endpoint and its binding revision. A record is only
/// ever read or changed through the binding that wrote it.
final class UnrestrictedBinding {
  UnrestrictedBinding(this.digest) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      throw ArgumentError.value(digest, 'digest');
    }
  }
  final String digest;

  @override
  bool operator ==(Object other) =>
      other is UnrestrictedBinding && other.digest == digest;

  @override
  int get hashCode => digest.hashCode;
}

/// Durable record of the insertions CodeWalk owns, one per session and
/// binding.
abstract interface class UnrestrictedOwnershipLedger {
  bool get loaded;

  /// Stored records could not be read, or a write's outcome could not be
  /// established; every write is refused so they are never overwritten.
  bool get unreadable;
  UnrestrictedOwnership? recordFor(
    UnrestrictedBinding binding,
    SessionRef session,
  );

  /// Persists before applying; false means the record was not stored. [when]
  /// is checked again right before persisting, after earlier writes ran.
  Future<bool> put(
    UnrestrictedBinding binding,
    SessionRef session,
    UnrestrictedOwnership record, {
    bool Function()? when,
  });
  Future<bool> remove(
    UnrestrictedBinding binding,
    SessionRef session, {
    bool Function()? when,
  });
}
