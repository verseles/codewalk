import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_visibility.dart';

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

/// The grouped list as the page renders it: a header per group, then the
/// primary rows of the group the server ordered, in the server's order. With
/// [open], only that group shows its rows; the other groups show their header
/// alone. A session the endpoint attributes to a parent is never a row, and a
/// group left with no primary row is not shown at all.
List<SessionListItem> sessionListItems(
  List<SessionSummary> sessions, {
  ({ProjectRef? project})? open,
}) {
  final items = <SessionListItem>[];
  for (final group in groupSessionsByProject(sessions)) {
    final roots = group.sessions.where(isPrimarySummary).toList();
    if (roots.isEmpty) continue;
    items.add(
      SessionGroupHeader(SessionGroup(project: group.project, sessions: roots)),
    );
    if (open == null || open.project == group.project) {
      items.addAll(roots.map(SessionRow.new));
    }
  }
  return items;
}
