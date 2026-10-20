import 'package:codewalk_core/codewalk_core.dart';

typedef SessionActionFactory =
    SessionActionSource Function(
      EndpointProfile profile,
      EndpointCredential credential,
    );

/// Why an action is not available for the loaded rows.
enum SessionActionReason {
  /// The action is available.
  none,

  /// The endpoint's version was not verified yet, or it is not the version
  /// whose command paths were observed.
  versionUnverified,

  /// The platform has no transport to the endpoint.
  unsupportedPlatform,

  /// The profile's credential was refused by the endpoint.
  authenticationRequired,

  /// The loaded rows are not the endpoint's current answer.
  listNotCurrent,

  /// A command for that row is already in flight.
  commandInFlight,

  /// The row carries no idle transition to mark as seen.
  noIdleMarker,
}

/// The unread marker of one row.
enum SessionViewState { unknown, unread, read }

/// Which sessions the catalog shows.
enum SessionActionFilter {
  /// The sessions that are not hidden in CodeWalk.
  active,

  /// The sessions hidden in CodeWalk.
  hidden,

  /// Every session the endpoint returned.
  all,
}

/// The endpoint's support for the session actions.
///
/// The support is probed once per profile: a capability is never discovered by
/// trying a mutation.
final class SessionActionSupport {
  const SessionActionSupport(this.reason);
  final SessionActionReason reason;

  /// The endpoint's own commands are available.
  bool get available => reason == SessionActionReason.none;
}

/// The outcome of one session action.
enum SessionActionOutcome {
  /// The endpoint answered with the command's success status. The effect is
  /// observed by the next authoritative read, not by this receipt.
  accepted,

  /// The endpoint refused the command.
  rejected,

  /// The command may already have been applied; it is reconciled and never
  /// replayed.
  uncertain,

  /// Nothing was sent.
  unavailable,
}

/// The actions the platform can perform on the loaded session rows.
///
/// The ownership of a session is not consulted: it is evidence, not
/// permission, and the OpenCode endpoint reports it as unknown. The
/// authorization is the endpoint's own contract, the profile's credential and
/// the currency of the loaded rows.
abstract interface class SessionActionSource {
  HarnessRef get harness;

  /// The endpoint's support for the actions.
  ///
  /// The version is the one the profile's own probe observed, so the
  /// capability is never discovered by trying a mutation.
  Future<SessionActionSupport> support();

  /// The unread marker of one row, from the endpoint's own epochs.
  SessionViewState viewState(SessionSummary row);

  /// The direct children of one row, for the cascade warning. Null when the
  /// count could not be read.
  Future<int?> childCount(SessionSummary row);

  /// Creates a session at the given canonical directory.
  ///
  /// The body carries the directory and, when the caller supplies one, the
  /// title. The identifier is the endpoint's, and the effect is observed by
  /// the authoritative read.
  Future<SessionActionOutcome> create({
    required String directory,
    String? title,
  });

  /// Renames the session.
  Future<SessionActionOutcome> rename(SessionSummary row, String title);

  /// Deletes the session and its children.
  Future<SessionActionOutcome> delete(SessionSummary row);

  /// Copies the session's history into a new root session.
  Future<SessionActionOutcome> fork(SessionSummary row);

  /// Marks the row's idle transition as viewed.
  Future<SessionActionOutcome> markViewed(SessionSummary row);

  /// Hides the session in CodeWalk, or shows it again. False when the local
  /// state could not be written.
  Future<bool> setHidden(SessionSummary row, {required bool hidden});

  /// Whether the session is hidden in CodeWalk.
  bool isHidden(SessionSummary row);

  /// Whether the local hide state can be read and written.
  bool get hideAvailable;

  /// Whether the local hide state could not be read. Its content is unknown,
  /// so it is never overwritten and the list says so.
  bool get hideUnreadable;

  void close();
}
