import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/utils/path_utils.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/project.dart';
import '../providers/chat_provider.dart';
import '../services/session_tab_icon_presets.dart';
import 'app_tab_strip.dart';
import 'project_icon.dart';

/// Height of the tab strip, also used by the integrated window chrome so the
/// title bar band and the strip stay aligned.
const double kSessionTabStripHeight = kAppTabStripHeight;
const double kSessionTabStripHeightCompact = kAppTabStripHeightCompact;

typedef SessionTabContextMenuCallback =
    Future<void> Function(
      SessionTabRecord tab,
      Offset globalPosition, {
      required bool haptic,
    });

/// Builds the trailing control (for example the context-usage button) of the
/// selected tab. Invoked only for the selected regular tab and the expanded
/// selected pinned tab; inactive tabs never show a trailing control.
typedef SessionTabTrailingBuilder =
    Widget? Function(BuildContext context, SessionTabRecord tab);

String sessionTabIdentityKey(SessionTabIdentity identity) {
  return '${identity.serverId}::${identity.directory}::${identity.sessionId}';
}

/// Session-tab adapter over the generic [AppTabStrip].
///
/// State ownership (provider, activation, persistence, navigation) stays in
/// `chat_page_session_tabs.dart`; this widget only maps [SessionTabRecord] to
/// [AppTab] and keeps every session-specific visual (leading, semantics,
/// trailing, pins, context menu) plus the historical `session_tab_*` keys.
class SessionTabStrip extends StatelessWidget {
  const SessionTabStrip({
    super.key,
    required this.tabs,
    required this.projects,
    required this.openProjectIds,
    required this.isCompact,
    required this.onActivate,
    required this.onClose,
    required this.onContextMenu,
    required this.trailingBuilder,
    this.fillWidth = true,
    this.transparentBackground = false,
  });

  final List<SessionTabRecord> tabs;
  final List<Project> projects;
  final Set<String> openProjectIds;
  final bool isCompact;

  /// When false the strip sizes itself to its tabs instead of expanding, so the
  /// integrated window chrome can use the leftover space as a drag region.
  final bool fillWidth;

  /// When true the strip paints no band of its own, so it blends into the
  /// surface behind it. The integrated window chrome already paints that band;
  /// standing alone under the app bar the strip still needs its own.
  final bool transparentBackground;
  final ValueChanged<SessionTabRecord> onActivate;
  final ValueChanged<SessionTabRecord> onClose;
  final SessionTabContextMenuCallback onContextMenu;
  final SessionTabTrailingBuilder trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final appTabs = <AppTab<SessionTabRecord>>[
      for (final tab in tabs)
        AppTab<SessionTabRecord>(
          id: sessionTabIdentityKey(tab.identity),
          value: tab,
          title: _displayTitle(context, tab),
          tooltip: _displayTitle(context, tab),
          semanticLabel: _semanticLabel(context, tab, _displayTitle(context, tab)),
          isSelected: tab.isSelected,
          isPinned: tab.isPinned,
          canClose: tab.identity.isValid,
          canOpenContextMenu: tab.identity.isValid,
        ),
    ];
    return AppTabStrip<SessionTabRecord>(
      tabs: appTabs,
      isCompact: isCompact,
      fillWidth: fillWidth,
      transparentBackground: transparentBackground,
      keyPrefix: 'session_tab_',
      trailingExtentBuilder: (context, tab) => isCompact ? 40.0 : 32.0,
      contextMenuActionLabel: context.l10n.chatSessionActions,
      leadingBuilder: (context, appTab) =>
          _buildLeading(context, appTab.value, _projectForTab(appTab.value)),
      trailingBuilder: (context, appTab) => trailingBuilder(context, appTab.value),
      onActivate: (appTab) => onActivate(appTab.value),
      onClose: (appTab) => onClose(appTab.value),
      onContextMenu: (appTab, position, {required bool haptic}) =>
          onContextMenu(appTab.value, position, haptic: haptic),
      closeFocusResolver: (tabIds, closedId) {
        final recordById = <String, SessionTabRecord>{
          for (final tab in tabs) sessionTabIdentityKey(tab.identity): tab,
        };
        final closed = recordById[closedId];
        if (closed == null) {
          return null;
        }
        final fallback = sessionTabCloseFallback(tabs, closed.identity);
        if (fallback == null) {
          return null;
        }
        return sessionTabIdentityKey(fallback.identity);
      },
    );
  }

  String _displayTitle(BuildContext context, SessionTabRecord tab) {
    final trimmed = tab.title.trim();
    return trimmed.isEmpty ? context.l10n.sessionExportUntitled : trimmed;
  }

  Widget _buildLeading(BuildContext context, SessionTabRecord tab, Project? project) {
    final colorScheme = Theme.of(context).colorScheme;
    final key = sessionTabIdentityKey(tab.identity);
    late final Widget leading;
    if (tab.hasUnseenError) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_error_$key'),
        icon: Symbols.error,
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    } else if (tab.hasUnseenQuestion) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_question_$key'),
        icon: Symbols.help,
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    } else if (tab.hasUnseenCompletion) {
      leading = _attentionIcon(
        key: ValueKey<String>('session_tab_leading_completion_$key'),
        icon: Symbols.notifications_active,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    } else {
      final preset = SessionTabIconPreset.fromId(tab.iconPresetId);
      if (preset != null) {
        leading = Tooltip(
          message: sessionTabIconPresetLabel(context.l10n, preset),
          child: Icon(
            preset.icon,
            key: ValueKey<String>('session_tab_custom_icon_$key'),
            size: 20,
            color: tab.isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        );
      } else {
        final resolvedProject = project ?? _fallbackProject(tab);
        final projectLabel = resolvedProject.name.trim().isEmpty
            ? fileBasename(tab.identity.directory)
            : resolvedProject.name.trim();
        leading = Tooltip(
          message: projectLabel,
          child: ProjectIcon(
            key: ValueKey<String>('session_tab_project_icon_$key'),
            project: resolvedProject,
            size: 20,
            color: tab.isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            autoDiscover: project != null && openProjectIds.contains(project.id),
          ),
        );
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        leading,
        if (tab.isBusy)
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              key: ValueKey<String>('session_tab_busy_${tab.status.name}_$key'),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tab.status == SessionStatusType.retry
                    ? colorScheme.tertiary
                    : colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.sync_rounded,
                size: 9,
                color: tab.status == SessionStatusType.retry
                    ? colorScheme.onTertiary
                    : colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _attentionIcon({
    required Key key,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      key: key,
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: foreground),
    );
  }

  String _semanticLabel(BuildContext context, SessionTabRecord tab, String title) {
    final base = switch ((
      tab.hasUnseenError,
      tab.hasUnseenQuestion,
      tab.hasUnseenCompletion,
    )) {
      (true, _, _) => context.l10n.sessionHasError(title),
      (false, true, _) => context.l10n.sessionNeedsInput(title),
      (false, false, true) => context.l10n.sessionHasNewReply(title),
      _ => context.l10n.chatSessionChatSessionSession(title),
    };
    if (tab.status == SessionStatusType.retry) {
      return '$base ${context.l10n.chatStatusRetry}';
    }
    if (tab.status == SessionStatusType.busy) {
      return '$base ${context.l10n.chatStatusBusy}';
    }
    return base;
  }

  Project? _projectForTab(SessionTabRecord tab) {
    for (final project in projects) {
      if (areEquivalentFilePaths(project.path, tab.identity.directory)) {
        return project;
      }
    }
    final projectId = tab.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      return null;
    }
    for (final project in projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  Project _fallbackProject(SessionTabRecord tab) {
    final directoryLabel = fileBasename(tab.identity.directory);
    return Project(
      id: tab.projectId?.trim().isNotEmpty ?? false
          ? tab.projectId!.trim()
          : tab.identity.directory,
      name: directoryLabel,
      path: tab.identity.directory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
