import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/sessions/session_catalog_source.dart';

/// The bounds of one child lookup: pages of 50, at most 10 pages and 500
/// children, all within 20 seconds including the final verification.
const subconversationPageSize = 50;
const subconversationMaxPages = 10;
const subconversationTimeout = Duration(seconds: 20);

/// The sub-conversation a tapped subagent call opens: a direct child of
/// [parent], or null when none can be told apart, which is better than
/// opening the wrong one.
///
/// The call's own observation wins, and a refused one never falls back.
/// Without one, the only child of a complete child list opens; otherwise the
/// call's position among the subagent calls of [timeline] pairs with the
/// children by creation time, only when [anchorsComplete] holds the whole
/// history, both counts match and nothing contradicts the pairing. The choice
/// is read directly and opens only as an exact direct child. [current] is
/// asked after every wait: a tap overtaken by another one or by navigation
/// resolves to null.
Future<SessionRef?> resolveSubconversation({
  required ToolCall tool,
  required SessionRef parent,
  required List<TimelineItem> timeline,
  required bool anchorsComplete,
  required SessionCatalogSource source,
  required bool Function() current,
}) async {
  final tasks = <void Function()>[];
  Future<T> wait<T>(Future<T> future, void Function() cancel) {
    tasks.add(cancel);
    return future;
  }

  Future<SessionRef?> resolve() async {
    if (tool.childEvidence?.kind == ToolChildEvidenceKind.rejected) {
      return null;
    }
    var candidate = tool.child;
    if (candidate == null) {
      final children = <SessionSummary>[];
      String? cursor;
      for (var page = 0; ; page++) {
        if (page == subconversationMaxPages) return null;
        final task = source.list(
          SessionQuery(
            parent: parent,
            cursor: cursor,
            limit: subconversationPageSize,
          ),
        );
        final result = await wait(task.result, task.cancel);
        if (!current()) return null;
        children.addAll(result.items);
        cursor = result.nextCursor;
        if (cursor == null) break;
      }
      candidate = chooseSubconversation(
        tool: tool,
        timeline: timeline,
        anchorsComplete: anchorsComplete,
        children: children,
      );
    }
    if (candidate == null || candidate.harnessRef != parent.harnessRef) {
      return null;
    }
    final read = source.read(candidate);
    final row = await wait(read.result, read.cancel);
    if (!current()) return null;
    return row.info.ref == candidate && row.info.lineage.parent == parent
        ? candidate
        : null;
  }

  try {
    return await resolve().timeout(subconversationTimeout);
  } on Object {
    // A failed, cancelled or overdue read opens nothing.
    for (final cancel in tasks) {
      cancel();
    }
    return null;
  }
}

/// The child of a complete [children] list that [tool] pairs with, or null.
SessionRef? chooseSubconversation({
  required ToolCall tool,
  required List<TimelineItem> timeline,
  required bool anchorsComplete,
  required List<SessionSummary> children,
}) {
  if (children.map((row) => row.info.ref).toSet().length != children.length) {
    return null;
  }
  if (children.length == 1) return children.single.info.ref;
  if (!anchorsComplete || children.isEmpty) return null;
  final anchors = [
    for (final item in timeline)
      if (item is ToolCall && item.kind.known == ToolKind.subagent) item,
  ];
  final at = anchors.indexWhere((anchor) => anchor.id == tool.id);
  if (at < 0 || anchors.length != children.length) return null;
  final times = [for (final row in children) row.createdAt];
  if (times.contains(null) || times.toSet().length != times.length) {
    return null;
  }
  final sorted = [...children]
    ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  for (final (i, anchor) in anchors.indexed) {
    final evidence = anchor.childEvidence;
    // A refused or differently observed call contradicts the pairing.
    if (evidence?.kind == ToolChildEvidenceKind.rejected ||
        (anchor.child != null && anchor.child != sorted[i].info.ref)) {
      return null;
    }
  }
  return sorted[at].info.ref;
}
