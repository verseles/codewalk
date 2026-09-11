import '../providers/chat_provider.dart';

/// Pure MRU ordering for the browser-style session tab switcher (issue #171).
///
/// MRU contract (decision 1B):
/// - When a tab is selected, it anchors index 0 and the rest follow by
///   [SessionTabRecord.lastOpenedAtMs] descending.
/// - With no selection (e.g. New Chat draft active), every candidate is
///   ordered by recency with no anchor.
/// - Ties preserve the incoming visual order (stable sort).
/// - Tabs with invalid identities (e.g. local `New Chat` draft with an empty
///   session id) are excluded; the switcher only cycles real sessions.
List<SessionTabRecord> orderTabsForSwitcher(List<SessionTabRecord> tabs) {
  final valid = <SessionTabRecord>[];
  final visualIndexByIdentity = <SessionTabIdentity, int>{};
  for (var i = 0; i < tabs.length; i++) {
    final tab = tabs[i];
    if (!tab.identity.isValid) continue;
    visualIndexByIdentity.putIfAbsent(tab.identity, () => valid.length);
    valid.add(tab);
  }
  if (valid.length < 2) return List<SessionTabRecord>.unmodifiable(valid);

  int recencyThenVisual(SessionTabRecord a, SessionTabRecord b) {
    final recency = b.lastOpenedAtMs.compareTo(a.lastOpenedAtMs);
    if (recency != 0) return recency;
    return visualIndexByIdentity[a.identity]!.compareTo(
      visualIndexByIdentity[b.identity]!,
    );
  }

  SessionTabRecord? current;
  for (final tab in valid) {
    if (tab.isSelected) {
      current = tab;
      break;
    }
  }
  if (current == null) {
    final ordered = List<SessionTabRecord>.of(valid)..sort(recencyThenVisual);
    return List<SessionTabRecord>.unmodifiable(ordered);
  }

  final rest = valid.where((tab) => tab.identity != current!.identity).toList();
  rest.sort(recencyThenVisual);
  return List<SessionTabRecord>.unmodifiable(<SessionTabRecord>[current, ...rest]);
}

/// Initial highlight: forward starts at the most recent other tab (index 1),
/// reverse starts at the least recent tab (last index).
int switcherInitialIndex(int length, {required bool reverse}) {
  if (length <= 0) return 0;
  if (length == 1) return 0;
  return reverse ? length - 1 : 1;
}

/// Circular step with wrap-around.
int switcherStepIndex(int index, int length, {required bool reverse}) {
  if (length <= 0) return 0;
  if (length == 1) return 0;
  if (reverse) return (index - 1 + length) % length;
  return (index + 1) % length;
}
