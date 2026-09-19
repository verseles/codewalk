import '../../core/utils/path_utils.dart';
import '../providers/chat_provider.dart';

/// Canonical project-group key for a session tab.
///
/// Directory-first (already normalized in [SessionTabIdentity]); falls back
/// to `projectId` for root (`/`), placeholder (`-`) or empty directories,
/// matching the close-project canonicalization. Server-scoped so tabs from
/// different servers never merge.
String sessionTabProjectGroupKey(SessionTabRecord tab) {
  final directory = normalizeOptionalFilePath(tab.identity.directory);
  if (directory != null && directory != '/') {
    return '${tab.identity.serverId}::$directory';
  }
  final projectId = tab.projectId?.trim();
  if (projectId != null && projectId.isNotEmpty) {
    return '${tab.identity.serverId}::project::$projectId';
  }
  return '${tab.identity.serverId}::dir::${tab.identity.directory}';
}

/// Display-only project grouping for the session tab strip.
///
/// Pinned tabs keep their original order and stay first (the strip renders
/// them in a separate leading region). Regular tabs are grouped by canonical
/// project key in first-appearance order, preserving internal order.
/// Provider/persisted order is never mutated by this helper.
List<SessionTabRecord> groupSessionTabsByProject(List<SessionTabRecord> tabs) {
  final pinned = <SessionTabRecord>[];
  final groups = <String, List<SessionTabRecord>>{};
  final order = <String>[];
  for (final tab in tabs) {
    if (tab.isPinned) {
      pinned.add(tab);
      continue;
    }
    final key = sessionTabProjectGroupKey(tab);
    final group = groups.putIfAbsent(key, () {
      order.add(key);
      return <SessionTabRecord>[];
    });
    group.add(tab);
  }
  return <SessionTabRecord>[
    for (final tab in pinned) tab,
    for (final key in order) ...groups[key]!,
  ];
}

/// Identities of the last regular tab of each project group.
///
/// The caller renders one `+` accessory after each of these tabs. Groups
/// containing a local draft (`sessionId` empty) are skipped so the `+` does
/// not invite a duplicate draft. Pin-only groups contribute no anchor
/// (decision 2A: no action-only `+`).
Set<SessionTabIdentity> projectNewChatAnchors(
  List<SessionTabRecord> orderedTabs,
) {
  final anchors = <SessionTabIdentity>{};
  final regular = orderedTabs
      .where((tab) => !tab.isPinned)
      .toList(growable: false);
  if (regular.isEmpty) {
    return anchors;
  }
  final groupHasDraft = <String, bool>{};
  for (final tab in regular) {
    final key = sessionTabProjectGroupKey(tab);
    groupHasDraft[key] =
        (groupHasDraft[key] ?? false) || tab.identity.sessionId.isEmpty;
  }
  for (var i = 0; i < regular.length; i++) {
    final tab = regular[i];
    final key = sessionTabProjectGroupKey(tab);
    final isLast =
        i == regular.length - 1 ||
        sessionTabProjectGroupKey(regular[i + 1]) != key;
    if (isLast && groupHasDraft[key] != true) {
      anchors.add(tab.identity);
    }
  }
  return anchors;
}
