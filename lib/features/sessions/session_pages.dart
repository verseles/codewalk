import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_catalog_source.dart';

/// One page of the list: the server's rows, or one context's.
SessionQuery sessionPageQuery(
  SessionCatalogSource source,
  String? cursor,
  String? directory,
) => SessionQuery(
  limit: 50,
  cursor: cursor,
  project: directory == null
      ? null
      : ProjectRef(source.harness.host, directory),
);

/// A row of another server, or of another context than the one read.
bool foreignSessionRow(
  SessionSummary row,
  SessionCatalogSource source,
  String? directory,
) =>
    row.info.ref.harnessRef != source.harness ||
    (directory != null && row.info.project?.canonicalDirectory != directory);

/// The rows of a read from the head and the pagination state it observed.
typedef SessionPages = ({
  List<SessionSummary> rows,
  String? cursor,
  Set<String> cursors,
  Set<String> requested,
  int pages,
  bool hasMore,
  bool exhausted,
  bool omitted,
});

/// The pages of [directory] from the head to [depth], or null when [current]
/// says the read was superseded. The traversal is validated exactly like a
/// manual read.
Future<SessionPages?> readSessionPages(
  SessionCatalogSource source, {
  required String? directory,
  required int depth,
  required bool Function() current,
}) async {
  final rows = <SessionSummary>[];
  final refs = <SessionRef>{};
  final cursors = <String>{};
  final requested = <String>{};
  String? cursor;
  var pages = 0;
  var omitted = false;
  var exhausted = false;
  for (var page = 0; page < depth; page++) {
    if (cursor != null) requested.add(cursor);
    final task = source.list(sessionPageQuery(source, cursor, directory));
    final result = await task.result;
    if (!current()) return null;
    if (result.items.length > 50) {
      throw const SessionCatalogException(
        SessionCatalogFailure.incompatibleResponse,
      );
    }
    for (final row in result.items) {
      if (foreignSessionRow(row, source, directory) ||
          !refs.add(row.info.ref)) {
        throw const SessionCatalogException(
          SessionCatalogFailure.incompatibleResponse,
        );
      }
      if (rows.length < 200) {
        rows.add(row);
      } else {
        omitted = true;
      }
    }
    pages++;
    final next = result.nextCursor;
    exhausted = next == null || result.items.length < 50;
    if (next == null) {
      return (
        rows: rows,
        cursor: null,
        cursors: cursors,
        requested: requested,
        pages: pages,
        hasMore: false,
        exhausted: exhausted,
        omitted: omitted,
      );
    }
    if (!cursors.add(next)) {
      throw const SessionCatalogException(SessionCatalogFailure.invalidCursor);
    }
    cursor = next;
  }
  return (
    rows: rows,
    cursor: cursor,
    cursors: cursors,
    requested: requested,
    pages: pages,
    hasMore: true,
    exhausted: exhausted,
    omitted: omitted,
  );
}
