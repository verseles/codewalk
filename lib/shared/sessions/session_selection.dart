import 'package:codewalk_core/codewalk_core.dart';

/// Why one half of a session's selection (its model or its agent) is not
/// offered: what the catalog read of the session's location observed.
enum SessionSelectionUnavailable {
  /// The session names no location, so no catalog is read for it.
  locationUnknown,

  /// The server does not serve the catalog.
  routeAbsent,
  authenticationRequired,

  /// The read failed for now; a later read may succeed.
  serviceUnavailable,

  /// The answer could not be understood.
  catalogUnreadable,

  /// The location offers nothing to pick.
  emptyCatalog,
}

/// The session's last explicit change.
enum SessionSelectionPhase {
  idle,

  /// A switch is in flight; this session's sends wait for it.
  pending,

  /// The switch's outcome is unknown and one read could not settle it. Sends
  /// wait until a read, a fresh hydration or a new pick does.
  unconfirmed,
}

/// The outcome of the last explicit change, shown once beside the selection.
enum SessionSelectionNotice { none, refused, notApplied, changedElsewhere }

/// The model and agent of one session and what can be picked for it.
final class SessionSelectionState {
  const SessionSelectionState({
    this.selection,
    this.models = const [],
    this.agents = const [],
    this.loading = false,
    this.modelUnavailable,
    this.agentUnavailable,
    this.phase = SessionSelectionPhase.idle,
    this.notice = SessionSelectionNotice.none,
    this.receipt,
  });

  /// The server's selection, or a change it accepted and has not echoed yet;
  /// null until the session is hydrated. A null field is the server default.
  final Selection? selection;
  final List<ModelEntry> models;
  final List<CatalogEntry> agents;

  /// The catalog is being read and nothing was read before.
  final bool loading;
  final SessionSelectionUnavailable? modelUnavailable;
  final SessionSelectionUnavailable? agentUnavailable;
  final SessionSelectionPhase phase;
  final SessionSelectionNotice notice;
  final CommandReceipt? receipt;

  /// A change of this session is in flight or unconfirmed.
  bool get holdsSend => phase != SessionSelectionPhase.idle;
}
