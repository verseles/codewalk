import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_visibility.dart';
import 'session_grouping.dart';

/// The canonical directories [rows] report, in the order they first appear.
List<String> knownSessionDirectories(Iterable<SessionSummary> rows) {
  final seen = <String>{};
  return [
    for (final row in rows)
      if (row.info.project?.canonicalDirectory case final directory?
          when seen.add(directory))
        directory,
  ];
}

/// How long a root session's unread reply is emphasized after it went idle.
const unreadEmphasis = Duration(hours: 1);

/// The list of one project context as the drawer shows it: the search keeps
/// the rows whose title contains the query, ignoring case; pinned rows come
/// first, then the rest; each band is ordered by most recent update. Only
/// primary sessions are listed: a child is reached from its parent, never from
/// here.
///
/// A missing time keeps the server's order among the rows that miss it,
/// after the rows that have one, so the order is stable.
List<SessionRow> projectSessionList(
  List<SessionSummary> rows, {
  required String query,
  required bool Function(SessionSummary row) pinned,
}) {
  final listed = [
    for (final row in rows)
      if (isPrimarySummary(row)) row,
  ];
  final needle = query.trim().toLowerCase();
  final matching = needle.isEmpty
      ? listed
      : [
          for (final row in listed)
            if (row.info.title.toLowerCase().contains(needle)) row,
        ];
  final ordered = sortSessionsByRecent(matching);
  return [
    for (final row in ordered)
      if (pinned(row)) SessionRow(row),
    for (final row in ordered)
      if (!pinned(row)) SessionRow(row),
  ];
}

/// [rows] ordered by most recent update, stably; rows without an update time
/// keep their order after the rows that have one.
List<SessionSummary> sortSessionsByRecent(List<SessionSummary> rows) {
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((x, y) {
    final a = x.$2.updatedAt;
    final b = y.$2.updatedAt;
    final order = a == null || b == null
        ? (a == null ? 1 : 0) - (b == null ? 1 : 0)
        : b.compareTo(a);
    return order != 0 ? order : x.$1.compareTo(y.$1);
  });
  return [for (final (_, row) in indexed) row];
}

/// How many conversations the active project lists before its "Show more"
/// (#534).
const activeProjectSessions = 5;

/// The latest update among [rows], children included, or null when none
/// has one: a child at work is activity in its project even when a harness
/// does not move its parent's time (#534). Lists still never show a child.
DateTime? latestSessionUpdate(Iterable<SessionSummary> rows) {
  DateTime? latest;
  for (final row in rows) {
    final at = row.updatedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// The open projects in the drawer's order (#534): [active] first, then the
/// others by their latest [activity], the most recent first. A project with
/// no known activity comes after them; ties keep the order of [open], which
/// is never changed.
List<String> projectDrawerOrder(
  List<String> open, {
  required String? active,
  required DateTime? Function(String directory) activity,
}) {
  final others = [
    for (var i = 0; i < open.length; i++)
      if (open[i] != active) (i, open[i], activity(open[i])),
  ];
  others.sort((x, y) {
    final a = x.$3;
    final b = y.$3;
    final order = a == null || b == null
        ? (a == null ? 1 : 0) - (b == null ? 1 : 0)
        : b.compareTo(a);
    return order != 0 ? order : x.$1.compareTo(y.$1);
  });
  return [
    if (active != null && open.contains(active)) active,
    for (final (_, directory, _) in others) directory,
  ];
}

/// The rows the active project shows before "Show more" (#534): the first
/// [limit] of [listed], pins leading as they already do there. The
/// conversation on screen is always among them: when it falls outside, it
/// takes the last place. [hidden] counts the [listed] rows left out.
({List<SessionRow> shown, int hidden}) activeProjectWindow(
  List<SessionRow> listed, {
  SessionRef? current,
  int limit = activeProjectSessions,
}) {
  if (listed.length <= limit) return (shown: listed, hidden: 0);
  final shown = listed.take(limit).toList();
  if (current != null &&
      !shown.any((row) => row.session.info.ref == current)) {
    final outside = listed
        .skip(limit)
        .where((row) => row.session.info.ref == current)
        .firstOrNull;
    if (outside != null) shown[limit - 1] = outside;
  }
  return (shown: shown, hidden: listed.length - shown.length);
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
