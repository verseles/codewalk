import 'package:codewalk_core/codewalk_core.dart';

import '../../platform/sessions/session_tabs_store.dart';

/// Render-only grouping. Neither grouping nor pinning rewrites saved tab order.
final class SessionTabProjection {
  SessionTabProjection({
    required Iterable<SessionTab> tabs,
    required HostId host,
    required bool Function(SessionTab) isPinned,
  }) {
    for (final tab in tabs) {
      if (tab.ref.host != host) continue;
      if (isPinned(tab)) {
        pinned.add(tab);
      } else {
        groups.putIfAbsent(tab.project, () => []).add(tab);
      }
    }
  }

  final pinned = <SessionTab>[];
  final groups = <ProjectRef?, List<SessionTab>>{};
  List<SessionTab> get ordered => [
    ...pinned,
    ...groups.values.expand((v) => v),
  ];

  SessionRef? neighbour(SessionRef ref) {
    final tabs = ordered;
    final index = tabs.indexWhere((tab) => tab.ref == ref);
    if (index < 0) return null;
    if (index + 1 < tabs.length) return tabs[index + 1].ref;
    return index > 0 ? tabs[index - 1].ref : null;
  }
}
