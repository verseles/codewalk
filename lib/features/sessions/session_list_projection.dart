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

/// The recent root sessions across the open contexts: at most
/// [perProjectLimit] root sessions per project, with no global cap. Roots that
/// [needsAttention] names come first, each band by its last update.
List<SessionSummary> recentSessions(
  Iterable<SessionSummary> rows, {
  int perProjectLimit = 2,
  bool Function(SessionSummary row)? needsAttention,
}) {
  if (perProjectLimit <= 0) return const [];
  final roots = <(int, SessionSummary)>[];
  var index = 0;
  for (final row in rows) {
    if (row.info.lineage.parent == null && row.updatedAt != null) {
      roots.add((index++, row));
    }
  }
  bool attention(SessionSummary row) => needsAttention?.call(row) ?? false;
  roots.sort((a, b) {
    final band = (attention(b.$2) ? 1 : 0).compareTo(attention(a.$2) ? 1 : 0);
    if (band != 0) return band;
    final byTime = b.$2.updatedAt!.compareTo(a.$2.updatedAt!);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  final seen = <SessionRef>{};
  final perProject = <(HostId, String?), int>{};
  final result = <SessionSummary>[];
  for (final (_, row) in roots) {
    if (!seen.add(row.info.ref)) continue;
    final bucket = (row.info.ref.host, row.info.project?.canonicalDirectory);
    final count = perProject[bucket] ?? 0;
    if (count >= perProjectLimit) continue;
    perProject[bucket] = count + 1;
    result.add(row);
  }
  return result;
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
