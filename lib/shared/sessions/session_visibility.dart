import 'package:codewalk_core/codewalk_core.dart';

/// Whether [info] is a primary session: a root one, not a session the
/// endpoint attributed to a parent.
///
/// This is the single canonical rule that keeps subagent sessions out of the
/// primary navigation: the lists, the previews, the counts and the tabs all
/// read it. It judges only the canonical lineage, never the harness name, so
/// every adapter answers alike: one that never names a parent has no
/// children, and a parentage nobody proved is never treated as a child.
bool isPrimarySession(SessionInfo info) => info.lineage.parent == null;

/// Whether [row] is a primary session, by its canonical lineage.
bool isPrimarySummary(SessionSummary row) => isPrimarySession(row.info);
