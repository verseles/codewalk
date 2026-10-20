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
  const SessionRow(
    this.session, {
    this.depth = 0,
    this.parentElsewhere = false,
  });
  final SessionSummary session;

  /// The loaded ancestors the row is drawn under inside its group: 0 for a
  /// top-level row.
  final int depth;

  /// The endpoint named a parent that this group does not show under the
  /// row: the parent is not loaded, sits in another group, or the lineage
  /// loops. The row stays where the server put it.
  final bool parentElsewhere;
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

/// The rows of one group nested under the parent the endpoint named.
///
/// The lineage comes only from the record's parent, never from a fork, a
/// title or an order. The top-level rows keep the server's order and each
/// parent keeps the position the server gave it; its children follow it
/// immediately, recursively, in the server's order among siblings. A child
/// whose parent is not in [groupRows] stays a top-level row where the server
/// put it, and so does every row of a lineage that loops, so every row is
/// emitted exactly once.
List<SessionRow> nestSessionRows(List<SessionSummary> groupRows) {
  final count = groupRows.length;
  final index = <SessionRef, int>{};
  for (var i = 0; i < count; i++) {
    index.putIfAbsent(groupRows[i].info.ref, () => i);
  }
  final up = List<int?>.generate(count, (i) {
    final parent = groupRows[i].info.lineage.parent;
    final at = parent == null ? null : index[parent];
    return at == i ? null : at;
  });
  // A lineage that loops has no top-level row: every row of the loop stays
  // a top-level row where the server put it, and only the rows that hang
  // off the loop nest under it.
  for (var i = 0; i < count; i++) {
    final seen = <int>{};
    int? at = i;
    while (at != null && seen.add(at)) {
      at = up[at];
    }
    if (at != null) {
      final loop = <int>[at];
      for (var node = up[at]!; node != at; node = up[node]!) {
        loop.add(node);
      }
      for (final node in loop) {
        up[node] = null;
      }
    }
  }
  final children = List.generate(count, (_) => <int>[]);
  final roots = <int>[];
  for (var i = 0; i < count; i++) {
    final parent = up[i];
    if (parent == null) {
      roots.add(i);
    } else {
      children[parent].add(i);
    }
  }
  final rows = <SessionRow>[];
  void emit(int i, int depth) {
    final session = groupRows[i];
    rows.add(
      SessionRow(
        session,
        depth: depth,
        parentElsewhere: depth == 0 && session.info.lineage.parent != null,
      ),
    );
    for (final child in children[i]) {
      emit(child, depth + 1);
    }
  }

  for (final root in roots) {
    emit(root, 0);
  }
  return rows;
}

/// The grouped list as the page renders it: a header per group, then its
/// rows nested under their parents.
List<SessionListItem> sessionListItems(List<SessionSummary> sessions) => [
  for (final group in groupSessionsByProject(sessions)) ...[
    SessionGroupHeader(group),
    ...nestSessionRows(group.sessions),
  ],
];
