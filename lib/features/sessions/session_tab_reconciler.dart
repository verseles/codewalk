import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';

import '../../platform/sessions/session_tabs_store.dart';

import '../../shared/sessions/session_visibility.dart';

/// What the tabs know of one loaded session of the selected server.
@immutable
final class SessionTabCandidate {
  const SessionTabCandidate({
    required this.row,
    this.pinned = false,
    this.busy,
  });

  final SessionSummary row;

  /// Pinned in its project context.
  final bool pinned;

  /// Running or waiting for the user; null while the endpoint's activity is
  /// not known, which is not idle.
  final bool? busy;

  int? get updatedAtMs => row.updatedAt?.millisecondsSinceEpoch;
}

/// The result of one reconciliation.
@immutable
final class SessionTabReconciliation {
  const SessionTabReconciliation({
    required this.state,
    required this.consumed,
    required this.nextExpiryMs,
  });

  /// The new state, or null when nothing changed.
  final SessionTabsState? state;

  /// The fallback directories this pass settled: their rows were known.
  final Set<String> consumed;

  /// When a tab kept only by its recency leaves next, if any.
  final int? nextExpiryMs;
}

/// How long a session stays among the recent tabs after its last update or
/// its last open.
const sessionTabWindow = Duration(hours: 3);

/// Reconciles the tabs of [host] with its loaded sessions, the [candidates].
///
/// A tab normally holds a recent root session: one updated or opened within
/// [sessionTabWindow]. The selected tab, a busy session and a pinned one stay
/// whatever their age. A closed session is suppressed: it comes back when
/// the user opens it, when it is pinned, or when the server reports an
/// update strictly newer than the one known at its close; the first update
/// seen for a closed session without one only sets it. Child sessions are
/// never added, and a child tab never stays either: it leaves
/// even when selected, pinned, busy or recent, and a dropped selection moves
/// to the next kept tab of its server, in the strip's stored order. A
/// session absent from the rows keeps its tab unless [children] carries
/// direct-read proof of parentage. Tabs keep their order and new ones follow,
/// the most recent first, while [SessionTabsStore.maxTabs] allows: a full
/// strip never drops a tab to make room. Each directory of [fallbacks] whose
/// rows are known and that holds no tab gets its most recent visible
/// session once, which counts as opened now so it stays its window. Tabs of
/// other servers are left as they are. [frozen] protects primary or unproven
/// tabs; a proven child leaves even while frozen.
SessionTabReconciliation reconcileSessionTabs({
  required SessionTabsState state,
  required HostId host,
  required int nowMs,
  required Map<SessionRef, SessionTabCandidate> candidates,
  Set<String> fallbacks = const {},
  Set<String> knownDirectories = const {},
  Set<SessionRef> frozen = const {},
  Set<SessionRef> children = const {},
}) {
  // A session is recent while strictly inside the window, so a tab leaves
  // exactly at its expiry.
  final windowStart = nowMs - sessionTabWindow.inMilliseconds;
  final selected = state.selected[host];
  int? nextExpiry;
  void expiresAt(int ms) {
    final at = ms + sessionTabWindow.inMilliseconds;
    if (nextExpiry == null || at < nextExpiry!) nextExpiry = at;
  }

  int? latest(int? a, int? b) => a == null || (b != null && b > a) ? b : a;

  var changed = false;
  var droppedSelected = false;
  final tabs = <SessionTab>[];
  for (final tab in state.tabs) {
    final candidate = candidates[tab.ref];
    if (tab.ref.host != host) {
      tabs.add(tab);
      continue;
    }
    // A child is visited from its parent, never tabbed: whatever else keeps
    // a tab - the selection, a pin, a busy run, its recency - does not apply.
    if (children.contains(tab.ref) ||
        candidate != null && !isPrimarySummary(candidate.row)) {
      changed = true;
      if (tab.ref == selected) droppedSelected = true;
      continue;
    }
    if (frozen.contains(tab.ref) || candidate == null) {
      tabs.add(tab);
      continue;
    }
    final updated = latest(tab.updatedAtMs, candidate.updatedAtMs);
    final recent = latest(updated, tab.lastOpenedAtMs)!;
    final keep =
        tab.ref == selected ||
        candidate.pinned ||
        candidate.busy != false ||
        recent > windowStart;
    if (!keep) {
      changed = true;
      continue;
    }
    if (tab.ref != selected && !candidate.pinned && candidate.busy == false) {
      expiresAt(recent);
    }
    if (updated != tab.updatedAtMs) {
      changed = true;
      tabs.add(tab.copyWith(updatedAtMs: updated));
    } else {
      tabs.add(tab);
    }
  }

  final open = {for (final tab in tabs) tab.ref};
  final suppressed = {for (final entry in state.suppressed) entry.ref: entry};
  final added = <SessionTab>[];
  final fresh = [
    for (final candidate in candidates.values)
      if (candidate.row.info.ref.host == host &&
          !open.contains(candidate.row.info.ref) &&
          !frozen.contains(candidate.row.info.ref) &&
          !children.contains(candidate.row.info.ref) &&
          candidate.row.info.lineage.parent == null)
        candidate,
  ]..sort(_mostRecentFirst);

  /// Whether [candidate] is free of its close: never closed, pinned, or
  /// updated since. A first update seen sets the close's baseline.
  bool released(SessionTabCandidate candidate) {
    final ref = candidate.row.info.ref;
    final entry = suppressed[ref];
    if (entry == null) return true;
    final updated = candidate.updatedAtMs;
    if (candidate.pinned ||
        (updated != null &&
            entry.updatedAtMs != null &&
            updated > entry.updatedAtMs!)) {
      suppressed.remove(ref);
      changed = true;
      return true;
    }
    if (updated != null && entry.updatedAtMs == null) {
      suppressed[ref] = entry.withUpdatedAt(updated);
      changed = true;
    }
    return false;
  }

  SessionTab tabOf(SessionTabCandidate candidate, {int openedAtMs = 0}) {
    final info = candidate.row.info;
    return SessionTab(
      ref: info.ref,
      project: info.project?.host == host ? info.project : null,
      title: SessionTabsStore.boundTitle(info.title),
      // Unless shown as a project opens, only its update keeps it recent.
      lastOpenedAtMs: openedAtMs,
      updatedAtMs: candidate.updatedAtMs,
    );
  }

  bool room() => tabs.length + added.length < SessionTabsStore.maxTabs;

  for (final candidate in fresh) {
    if (!released(candidate)) continue;
    final updated = candidate.updatedAtMs;
    final eligible =
        candidate.pinned ||
        candidate.busy == true ||
        (updated != null && updated > windowStart);
    if (!eligible || !room()) continue;
    if (!candidate.pinned && candidate.busy != true) expiresAt(updated!);
    added.add(tabOf(candidate));
    open.add(candidate.row.info.ref);
    changed = true;
  }

  final consumed = <String>{};
  for (final directory in fallbacks) {
    if (!knownDirectories.contains(directory)) continue;
    consumed.add(directory);
    bool inDirectory(SessionTabCandidate c) =>
        c.row.info.project?.host == host &&
        c.row.info.project?.canonicalDirectory == directory;
    final present = [...tabs, ...added].any(
      (tab) =>
          tab.ref.host == host && tab.project?.canonicalDirectory == directory,
    );
    if (present || !room()) continue;
    final choice = fresh
        .where(
          (c) =>
              inDirectory(c) &&
              !open.contains(c.row.info.ref) &&
              !suppressed.containsKey(c.row.info.ref),
        )
        .firstOrNull;
    if (choice == null) continue;
    added.add(tabOf(choice, openedAtMs: nowMs));
    if (choice.busy != true) expiresAt(nowMs);
    open.add(choice.row.info.ref);
    changed = true;
  }

  // The dropped child that was the selection hands it to the next kept tab
  // of its server, in the strip's stored order, or clears the selection.
  final nextSelected = <HostId, SessionRef>{...state.selected};
  if (droppedSelected) {
    // The stored order first: a kept tab of the server, else a fresh one.
    SessionRef? next;
    for (final tab in [...tabs, ...added]) {
      if (tab.ref.host == host) {
        next = tab.ref;
        break;
      }
    }
    if (next == null) {
      nextSelected.remove(host);
    } else {
      nextSelected[host] = next;
    }
  }

  return SessionTabReconciliation(
    state: changed
        ? state.copyWith(
            tabs: [...tabs, ...added],
            selected: droppedSelected ? nextSelected : null,
            // A tab open again is not closed.
            suppressed: [
              for (final entry in suppressed.values)
                if (!open.contains(entry.ref)) entry,
            ],
          )
        : null,
    consumed: consumed,
    nextExpiryMs: nextExpiry,
  );
}

/// The most recently updated first; ties, and sessions without an update,
/// by their storage key.
int _mostRecentFirst(SessionTabCandidate a, SessionTabCandidate b) {
  final byUpdate = (b.updatedAtMs ?? -1).compareTo(a.updatedAtMs ?? -1);
  if (byUpdate != 0) return byUpdate;
  return a.row.info.ref.storageKey.compareTo(b.row.info.ref.storageKey);
}
