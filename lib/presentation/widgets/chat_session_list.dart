import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/i18n/l10n_context.dart';
import '../../domain/entities/chat_session.dart';
import '../providers/chat_provider.dart';
import '../theme/app_visual_style_tokens.dart';
import '../utils/session_title_formatter.dart';
import 'session_context_menu.dart';
import 'sidebar_selection_indicator.dart';

/// Chat session list widget
class ChatSessionList extends StatefulWidget {
  const ChatSessionList({
    super.key,
    required this.sessions,
    this.currentSession,
    this.isSessionActive,
    this.sessionAttentionFor,
    this.isMobileLayout = false,
    this.onSessionSelected,
    this.onSessionDeleted,
    this.onSessionRenamed,
    this.onSessionShareToggled,
    this.onSessionArchiveToggled,
    this.onSessionPinToggled,
    this.onSessionForked,
    this.pinnedSessionIds = const <String>{},
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(8, 0, 8, 8),
    this.verticalTilePadding = 3,
  });

  final List<ChatSession> sessions;
  final ChatSession? currentSession;
  final bool Function(String sessionId)? isSessionActive;
  final SessionAttentionState Function(String sessionId)? sessionAttentionFor;
  final bool isMobileLayout;
  final Future<void> Function(ChatSession session)? onSessionSelected;
  final Future<void> Function(ChatSession session)? onSessionDeleted;
  final Future<bool> Function(ChatSession session, String title)?
  onSessionRenamed;
  final Future<bool> Function(ChatSession session)? onSessionShareToggled;
  final Future<bool> Function(ChatSession session, bool archived)?
  onSessionArchiveToggled;
  final Future<void> Function(ChatSession session)? onSessionPinToggled;
  final Future<void> Function(ChatSession session)? onSessionForked;
  final Set<String> pinnedSessionIds;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final double verticalTilePadding;

  @override
  State<ChatSessionList> createState() => _ChatSessionListState();
}

class _ChatSessionListState extends State<ChatSessionList> {
  static final RegExp _pseudoSummaryPattern = RegExp(
    r'^\s*(additions|deletions)\s*:\s*\d+(\s*,\s*(additions|deletions)\s*:\s*\d+)*\s*$',
    caseSensitive: false,
  );

  final Set<String> _expandedParentIds = <String>{};
  String? _cachedTreeSignature;
  List<_SessionTreeRow> _cachedVisibleRows = const <_SessionTreeRow>[];
  bool _isSessionSelectionInFlight = false;
  String? _activeSessionSelectionId;
  ChatSession? _pendingSessionSelection;

  @override
  void initState() {
    super.initState();
    final sessionById = <String, ChatSession>{
      for (final session in widget.sessions) session.id: session,
    };
    _expandCurrentSessionAncestors(sessionById);
  }

  @override
  void didUpdateWidget(covariant ChatSessionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionIds = widget.sessions.map((session) => session.id).toSet();
    _expandedParentIds.removeWhere((id) => !sessionIds.contains(id));
    final sessionById = <String, ChatSession>{
      for (final session in widget.sessions) session.id: session,
    };
    _expandCurrentSessionAncestors(sessionById);
    _invalidateTreeCache();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatSessionConversations,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.chatSessionCreateConversationStart,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final sessionById = <String, ChatSession>{
      for (final session in widget.sessions) session.id: session,
    };
    final childrenByParent = <String, List<ChatSession>>{};
    final roots = <ChatSession>[];

    for (final session in widget.sessions) {
      final parentId = session.parentId;
      if (parentId == null ||
          parentId.isEmpty ||
          !sessionById.containsKey(parentId) ||
          parentId == session.id) {
        roots.add(session);
        continue;
      }
      childrenByParent
          .putIfAbsent(parentId, () => <ChatSession>[])
          .add(session);
    }

    final pinnedRoots = <ChatSession>[];
    final unpinnedRoots = <ChatSession>[];
    for (final root in roots) {
      if (widget.pinnedSessionIds.contains(root.id)) {
        pinnedRoots.add(root);
      } else {
        unpinnedRoots.add(root);
      }
    }
    roots.clear();
    roots.addAll(pinnedRoots);
    roots.addAll(unpinnedRoots);

    final signature = _createTreeSignature(
      sessions: widget.sessions,
      roots: roots,
      expandedParentIds: _expandedParentIds,
      pinnedSessionIds: widget.pinnedSessionIds,
    );
    if (_cachedTreeSignature != signature) {
      _cachedTreeSignature = signature;
      final visited = <String>{};
      final rows = <_SessionTreeRow>[];
      for (final root in roots) {
        rows.addAll(
          _buildSessionRows(
            session: root,
            childrenByParent: childrenByParent,
            depth: 0,
            visited: visited,
          ),
        );
      }
      _cachedVisibleRows = rows;
    }

    return ListView.builder(
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: _cachedVisibleRows.length,
      itemBuilder: (context, index) {
        final row = _cachedVisibleRows[index];
        return _buildSessionTile(
          context,
          session: row.session,
          depth: row.depth,
          hasChildren: row.hasChildren,
          childCount: row.childCount,
          expanded: row.expanded,
        );
      },
    );
  }

  bool _expandCurrentSessionAncestors(Map<String, ChatSession> sessionById) {
    final current = widget.currentSession;
    if (current == null) {
      return false;
    }
    var changed = false;
    var parentId = current.parentId;
    while (parentId != null && parentId.isNotEmpty) {
      final inserted = _expandedParentIds.add(parentId);
      changed = changed || inserted;
      final parent = sessionById[parentId];
      if (parent == null || parent.parentId == parentId) {
        break;
      }
      parentId = parent.parentId;
    }
    return changed;
  }

  List<_SessionTreeRow> _buildSessionRows({
    required ChatSession session,
    required Map<String, List<ChatSession>> childrenByParent,
    required int depth,
    required Set<String> visited,
  }) {
    if (!visited.add(session.id)) {
      return const <_SessionTreeRow>[];
    }

    final children = childrenByParent[session.id] ?? const <ChatSession>[];
    final hasChildren = children.isNotEmpty;
    final expanded = hasChildren && _expandedParentIds.contains(session.id);
    final rows = <_SessionTreeRow>[
      _SessionTreeRow(
        session: session,
        depth: depth,
        hasChildren: hasChildren,
        childCount: children.length,
        expanded: expanded,
      ),
    ];

    if (!expanded) {
      return rows;
    }

    for (final child in children) {
      rows.addAll(
        _buildSessionRows(
          session: child,
          childrenByParent: childrenByParent,
          depth: depth + 1,
          visited: visited,
        ),
      );
    }

    return rows;
  }

  String _createTreeSignature({
    required List<ChatSession> sessions,
    required List<ChatSession> roots,
    required Set<String> expandedParentIds,
    required Set<String> pinnedSessionIds,
  }) {
    final expanded = expandedParentIds.toList(growable: false)..sort();
    final buffer = StringBuffer()
      ..write('sessions:${sessions.length};')
      ..write('roots:${roots.map((session) => session.id).join(',')};')
      ..write('expanded:${expanded.join(',')};')
      ..write('current:${widget.currentSession?.id ?? ''};');
    for (final session in sessions) {
      final attention = widget.sessionAttentionFor?.call(session.id);
      buffer
        ..write(session.id)
        ..write(':')
        ..write(session.parentId ?? '')
        ..write(':')
        ..write(session.time.millisecondsSinceEpoch)
        ..write(':')
        ..write(session.archived)
        ..write(':')
        ..write(session.shared)
        ..write(':')
        ..write(attention?.unreadCompletionAt?.millisecondsSinceEpoch ?? 0)
        ..write(':')
        ..write(attention?.isActive == true)
        ..write(':')
        ..write(attention?.hasPendingInteraction == true)
        ..write(':')
        ..write(attention?.hasError == true)
        ..write(':')
        ..write(attention?.hasUnreadCompletion == true)
        ..write(':')
        ..write(pinnedSessionIds.contains(session.id))
        ..write(';');
    }
    return buffer.toString();
  }

  String? _sidebarSummary(String? summary) {
    final trimmed = summary?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (_pseudoSummaryPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  Widget _buildCompactMetaRow(
    BuildContext context, {
    required ChatSession session,
    required bool isSelected,
    required bool hasChildren,
    required String childLabel,
    required bool isPinned,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metaColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: metaColor);

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        Text(_formatTime(session.time), style: textStyle, maxLines: 1),
        if (hasChildren) Text(childLabel, style: textStyle, maxLines: 1),
        if (session.shared) Icon(Symbols.share, size: 12, color: metaColor),
        if (isPinned) Icon(Symbols.push_pin, size: 12, color: metaColor),
        if (session.archived) Icon(Symbols.archive, size: 12, color: metaColor),
      ],
    );
  }

  void _invalidateTreeCache() {
    _cachedTreeSignature = null;
    _cachedVisibleRows = const <_SessionTreeRow>[];
  }

  Future<void> _handleSessionSelected(ChatSession session) async {
    final callback = widget.onSessionSelected;
    if (callback == null) {
      return;
    }
    if (_isSessionSelectionInFlight) {
      final pendingSessionId = _pendingSessionSelection?.id;
      if (pendingSessionId == session.id) {
        return;
      }
      if (_activeSessionSelectionId == session.id) {
        _pendingSessionSelection = null;
        return;
      }
      _pendingSessionSelection = session;
      return;
    }

    _pendingSessionSelection = session;
    _isSessionSelectionInFlight = true;
    try {
      while (true) {
        final pendingSession = _pendingSessionSelection;
        _pendingSessionSelection = null;
        if (pendingSession == null) {
          return;
        }
        _activeSessionSelectionId = pendingSession.id;
        await callback(pendingSession);
      }
    } finally {
      _activeSessionSelectionId = null;
      _isSessionSelectionInFlight = false;
    }
  }

  Widget _buildSessionTile(
    BuildContext context, {
    required ChatSession session,
    required int depth,
    required bool hasChildren,
    required int childCount,
    required bool expanded,
  }) {
    final isSelected = widget.currentSession?.id == session.id;
    final isSessionActive = widget.isSessionActive?.call(session.id) ?? false;
    final sessionAttention =
        widget.sessionAttentionFor?.call(session.id) ??
        SessionAttentionState(isActive: isSessionActive);
    final isRootSession =
        session.parentId == null || session.parentId!.trim().isEmpty;
    final floatingBadgeKind = _resolveFloatingBadgeKind(
      attention: sessionAttention,
      allowUnreadCompletion: isRootSession,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final visualTokens = Theme.of(context).visualStyleTokens;
    final tileRadius = visualTokens.isRefined
        ? visualTokens.controlRadius
        : BorderRadius.circular(18);
    final toggleRadius = visualTokens.isRefined
        ? visualTokens.controlRadius
        : BorderRadius.circular(10);
    final isPinned = widget.pinnedSessionIds.contains(session.id);
    final childLabel =
        L10nBridge.current?.chatSessionSubConversationCount(childCount) ??
        (childCount == 1
            ? '1 sub-conversation'
            : '$childCount sub-conversations');
    final hasRecentUnreadHighlight =
        sessionAttention.hasRecentUnreadCompletion && isRootSession;
    final subtitleText = _sidebarSummary(session.summary);
    final selectedForeground = colorScheme.primary;
    final primaryTextColor = isSelected || hasRecentUnreadHighlight
        ? selectedForeground
        : null;
    final secondaryTextColor = isSelected
        ? selectedForeground.withValues(alpha: 0.8)
        : colorScheme.onSurfaceVariant;
    final compactMeta = _buildCompactMetaRow(
      context,
      session: session,
      isSelected: isSelected,
      hasChildren: hasChildren,
      childLabel: childLabel,
      isPinned: isPinned,
    );
    final menuActions = SessionContextMenuActions(
      onSessionDeleted: widget.onSessionDeleted,
      onSessionRenamed: widget.onSessionRenamed,
      onSessionShareToggled: widget.onSessionShareToggled,
      onSessionArchiveToggled: widget.onSessionArchiveToggled,
      onSessionPinToggled: widget.onSessionPinToggled,
      onSessionForked: widget.onSessionForked,
      pinnedSessionIds: widget.pinnedSessionIds,
    );

    return Padding(
      key: ValueKey<String>('chat_session_tile_${session.id}'),
      padding: EdgeInsets.symmetric(vertical: widget.verticalTilePadding),
      child: Semantics(
        label: context.l10n.chatSessionChatSessionSession(session.title ?? ''),
        selected: isSelected,
        child: SidebarSelectionIndicator(
          selected: isSelected,
          child: SessionContextMenuRegion(
            session: session,
            actions: menuActions,
            surface: 'main',
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: tileRadius),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ListTile(
                    mouseCursor: SystemMouseCursors.click,
                    shape: RoundedRectangleBorder(borderRadius: tileRadius),
                    contentPadding: EdgeInsets.fromLTRB(
                      10 + (depth * 16.0),
                      0,
                      4,
                      0,
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    minVerticalPadding: 0,
                    title: Row(
                      children: [
                        if (hasChildren)
                          InkWell(
                            key: ValueKey<String>(
                              'chat_session_toggle_${session.id}',
                            ),
                            onTap: () {
                              setState(() {
                                if (expanded) {
                                  _expandedParentIds.remove(session.id);
                                } else {
                                  _expandedParentIds.add(session.id);
                                }
                                _invalidateTreeCache();
                              });
                            },
                            borderRadius: toggleRadius,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                expanded
                                    ? Symbols.expand_more
                                    : Symbols.chevron_right,
                                size: 18,
                                color: isSelected
                                    ? selectedForeground
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else if (depth > 0)
                          const SizedBox(width: 22),
                        Expanded(
                          child: Text(
                            SessionTitleFormatter.displayTitle(
                              time: session.time,
                              title: session.title,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: primaryTextColor,
                                  decoration: session.archived
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitleText != null) ...[
                          Text(
                            subtitleText,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: secondaryTextColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        compactMeta,
                      ],
                    ),
                    trailing: SessionContextMenuButton(
                      session: session,
                      actions: menuActions,
                      surface: 'main',
                      compact: !widget.isMobileLayout,
                      iconColor: isSelected
                          ? selectedForeground
                          : colorScheme.onSurfaceVariant,
                    ),
                    onTap: () async {
                      await _handleSessionSelected(session);
                    },
                  ),
                  if (floatingBadgeKind != SessionAttentionKind.none)
                    Positioned(
                      top: 8,
                      right: 46,
                      child: _buildFloatingAttentionBadge(
                        context,
                        sessionId: session.id,
                        kind: floatingBadgeKind,
                        isSelected: isSelected,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  SessionAttentionKind _resolveFloatingBadgeKind({
    required SessionAttentionState attention,
    required bool allowUnreadCompletion,
  }) {
    final primaryKind = attention.primaryKind;
    if (primaryKind == SessionAttentionKind.none) {
      return SessionAttentionKind.none;
    }
    if (primaryKind == SessionAttentionKind.unreadCompletion &&
        !allowUnreadCompletion) {
      return SessionAttentionKind.none;
    }
    return primaryKind;
  }

  Widget _buildFloatingAttentionBadge(
    BuildContext context, {
    required String sessionId,
    required SessionAttentionKind kind,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = _attentionBadgeColor(
      colorScheme: colorScheme,
      kind: kind,
      isSelected: isSelected,
    );
    final badgeKey = ValueKey<String>(
      'chat_session_attention_badge_${kind.name}_$sessionId',
    );

    if (kind == SessionAttentionKind.unreadCompletion) {
      return Container(
        key: badgeKey,
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      );
    }

    final badgeIcon = switch (kind) {
      SessionAttentionKind.active => Symbols.sync_rounded,
      SessionAttentionKind.pendingInteraction => Symbols.help,
      SessionAttentionKind.error => Symbols.error,
      SessionAttentionKind.none => Symbols.circle,
      SessionAttentionKind.unreadCompletion => Symbols.circle,
    };
    final iconColor = switch (kind) {
      SessionAttentionKind.error => colorScheme.onError,
      SessionAttentionKind.pendingInteraction => colorScheme.onTertiary,
      SessionAttentionKind.active => colorScheme.onPrimary,
      SessionAttentionKind.none => colorScheme.onSurface,
      SessionAttentionKind.unreadCompletion => colorScheme.onSurface,
    };

    return AnimatedContainer(
      key: badgeKey,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(badgeIcon, size: 11, color: iconColor),
    );
  }

  Color _attentionBadgeColor({
    required ColorScheme colorScheme,
    required SessionAttentionKind kind,
    required bool isSelected,
  }) {
    return switch (kind) {
      SessionAttentionKind.error => colorScheme.error,
      SessionAttentionKind.pendingInteraction => colorScheme.tertiary,
      SessionAttentionKind.unreadCompletion => colorScheme.primary,
      SessionAttentionKind.active => colorScheme.primary,
      SessionAttentionKind.none => colorScheme.onSurface,
    };
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return L10nBridge.current?.chatMessageJustNow ?? 'Just now';
    } else if (difference.inHours < 1) {
      return L10nBridge.current?.chatMessageMinutesAgo(difference.inMinutes) ??
          '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return L10nBridge.current?.chatMessageHoursAgo(difference.inHours) ??
          '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return L10nBridge.current?.chatMessageDaysAgo(difference.inDays) ??
          '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return L10nBridge.current?.chatMessageWeeksAgo(
            (difference.inDays / 7).floor(),
          ) ??
          '${(difference.inDays / 7).floor()}w ago';
    } else {
      return L10nBridge.current?.chatMessageShortDate(time.day, time.month) ??
          '${time.month}/${time.day}';
    }
  }
}

class _SessionTreeRow {
  const _SessionTreeRow({
    required this.session,
    required this.depth,
    required this.hasChildren,
    required this.childCount,
    required this.expanded,
  });

  final ChatSession session;
  final int depth;
  final bool hasChildren;
  final int childCount;
  final bool expanded;
}
