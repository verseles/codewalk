import 'package:codewalk_core/codewalk_core.dart';

import '../../platform/sessions/project_workspace_store.dart';
import '../../shared/sessions/session_actions.dart';
import 'session_grouping.dart';

/// How long a root session's unread reply is emphasized after it went idle.
const unreadEmphasis = Duration(hours: 1);

/// The sessions hidden in effect: a hidden session and every loaded
/// descendant of one, so hiding a parent hides its nested children too.
/// Only the explicit hides are kept; the descendants follow them.
Set<SessionRef> effectivelyHidden(
  Iterable<SessionSummary> rows,
  bool Function(SessionSummary row) hidden,
) {
  final byRef = {for (final row in rows) row.info.ref: row};
  final result = <SessionRef>{};
  final known = <SessionRef, bool>{};
  bool walk(SessionSummary row) {
    final cached = known[row.info.ref];
    if (cached != null) return cached;
    // A lineage that loops stops at the first repeated row.
    known[row.info.ref] = false;
    final parent = row.info.lineage.parent;
    final parentRow = parent == null ? null : byRef[parent];
    final value = hidden(row) || (parentRow != null && walk(parentRow));
    known[row.info.ref] = value;
    return value;
  }

  for (final row in byRef.values) {
    if (walk(row)) result.add(row.info.ref);
  }
  return result;
}

/// The rows the filter keeps: the visible ones, the hidden ones, or all.
List<SessionSummary> filterSessions(
  List<SessionSummary> rows,
  Set<SessionRef> hidden,
  SessionActionFilter filter,
) => switch (filter) {
  SessionActionFilter.all => rows,
  SessionActionFilter.active => [
    for (final row in rows)
      if (!hidden.contains(row.info.ref)) row,
  ],
  SessionActionFilter.hidden => [
    for (final row in rows)
      if (hidden.contains(row.info.ref)) row,
  ],
};

/// The list of one project context as the drawer shows it: the search keeps
/// the rows whose title contains the query, ignoring case; pinned rows come
/// first, then the rest; each band is ordered by [sort] and nests children
/// under their loaded parent.
///
/// A missing time keeps the server's order among the rows that miss it,
/// after the rows that have one, so the order is stable.
List<SessionRow> projectSessionList(
  List<SessionSummary> rows, {
  required String query,
  required SessionListSort sort,
  required bool Function(SessionSummary row) pinned,
}) {
  final needle = query.trim().toLowerCase();
  final matching = needle.isEmpty
      ? rows
      : [
          for (final row in rows)
            if (row.info.title.toLowerCase().contains(needle)) row,
        ];
  final ordered = sortSessions(matching, sort);
  return [
    ...nestSessionRows([
      for (final row in ordered)
        if (pinned(row)) row,
    ]),
    ...nestSessionRows([
      for (final row in ordered)
        if (!pinned(row)) row,
    ]),
  ];
}

/// [rows] ordered by [sort], stably.
List<SessionSummary> sortSessions(
  List<SessionSummary> rows,
  SessionListSort sort,
) {
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  int byTime(DateTime? a, DateTime? b, {required bool newest}) {
    // A missing time sorts after every known one.
    if (a == null || b == null) {
      return (a == null ? 1 : 0) - (b == null ? 1 : 0);
    }
    return newest ? b.compareTo(a) : a.compareTo(b);
  }

  indexed.sort((x, y) {
    final a = x.$2;
    final b = y.$2;
    final order = switch (sort) {
      SessionListSort.recent => byTime(a.updatedAt, b.updatedAt, newest: true),
      SessionListSort.oldest => byTime(a.createdAt, b.createdAt, newest: false),
      SessionListSort.title => a.info.title.toLowerCase().compareTo(
        b.info.title.toLowerCase(),
      ),
    };
    return order != 0 ? order : x.$1.compareTo(y.$1);
  });
  return [for (final (_, row) in indexed) row];
}

/// The recent root sessions across the open contexts: the [limit] most
/// recently updated roots that are not hidden in effect.
List<SessionSummary> recentSessions(
  Iterable<SessionSummary> rows,
  Set<SessionRef> hidden, {
  int limit = 5,
}) {
  final roots = [
    for (final row in rows)
      if (row.info.lineage.parent == null &&
          row.updatedAt != null &&
          !hidden.contains(row.info.ref))
        row,
  ];
  roots.sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
  final seen = <SessionRef>{};
  return [
    for (final row in roots)
      if (seen.add(row.info.ref)) row,
  ].take(limit).toList();
}

/// Whether a root session's unread reply is emphasized now: a completed run
/// the user has not seen, for one hour after it went idle. The session in
/// view and a child are never emphasized.
bool unreadEmphasized(
  SessionSummary row, {
  required DateTime now,
  SessionRef? current,
}) {
  final view = row.view;
  return row.info.lineage.parent == null &&
      row.info.ref != current &&
      row.outcome == SessionOutcome.succeeded &&
      view != null &&
      view.unread &&
      now.isBefore(view.idleAt.add(unreadEmphasis));
}

/// When the next unread emphasis among [rows] ends, so the list rebuilds
/// without reading the clock on its own.
Duration? nextEmphasisEnd(
  Iterable<SessionSummary> rows, {
  required DateTime now,
  SessionRef? current,
}) {
  Duration? next;
  for (final row in rows) {
    if (!unreadEmphasized(row, now: now, current: current)) continue;
    final left = row.view!.idleAt.add(unreadEmphasis).difference(now);
    if (next == null || left < next) next = left;
  }
  return next;
}
