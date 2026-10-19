import 'package:codewalk_core/codewalk_core.dart';

/// The loaded sessions of one project.
///
/// A group is a projection of what the server returned: the groups appear in
/// the first appearance of their first row and the rows inside a group keep the
/// server's order. Nothing is re-sorted, because the server's order is the
/// authoritative one.
final class SessionGroup {
  const SessionGroup({required this.project, required this.sessions});

  /// The project the server attributed the sessions to, or null when it
  /// attributed none.
  final ProjectRef? project;

  final List<SessionSummary> sessions;
}

/// One item of the grouped list: a group header or a session row.
sealed class SessionListItem {
  const SessionListItem();
}

/// The header of a project group.
final class SessionGroupHeader extends SessionListItem {
  const SessionGroupHeader(this.group);
  final SessionGroup group;
}

/// One session row of a group.
final class SessionRow extends SessionListItem {
  const SessionRow(this.session);
  final SessionSummary session;
}

/// The loaded sessions grouped by the project the server attributed them to.
///
/// The sessions the server did not attribute to a project share one group, and
/// no project is invented for them.
List<SessionGroup> groupSessionsByProject(List<SessionSummary> sessions) {
  final grouped = <ProjectRef?, List<SessionSummary>>{};
  final order = <ProjectRef?>[];
  for (final session in sessions) {
    final project = session.info.project;
    final rows = grouped[project];
    if (rows == null) {
      order.add(project);
      grouped[project] = [session];
    } else {
      rows.add(session);
    }
  }
  return [
    for (final project in order)
      SessionGroup(
        project: project,
        sessions: List.unmodifiable(grouped[project]!),
      ),
  ];
}

/// The grouped list as the page renders it: a header per group, then its
/// rows.
List<SessionListItem> sessionListItems(List<SessionSummary> sessions) => [
  for (final group in groupSessionsByProject(sessions)) ...[
    SessionGroupHeader(group),
    for (final session in group.sessions) SessionRow(session),
  ],
];
