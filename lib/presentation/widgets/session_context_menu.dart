import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/chat_session.dart';
import '../providers/chat_provider.dart' show SessionTabIdentity;
import '../utils/session_title_formatter.dart';
import 'modal_primary_action_shortcuts.dart';

const String sessionMenuPin = 'pin';
const String sessionMenuRename = 'rename';
const String sessionMenuShare = 'share';
const String sessionMenuCopyLink = 'copy-link';
const String sessionMenuArchive = 'archive';
const String sessionMenuFork = 'fork';
const String sessionMenuDelete = 'delete';

enum SessionMenuAction {
  pin,
  rename,
  share,
  copyLink,
  archive,
  fork,
  delete,
  changeIcon,
  closeProject,
  exportMarkdown,
  exportJson,
  viewTasks,
  reviewChanges,
  undo,
  redo,
  compact,
}

class SessionContextMenuActions {
  const SessionContextMenuActions({
    this.onSessionDeleted,
    this.onSessionRenamed,
    this.onSessionShareToggled,
    this.onSessionArchiveToggled,
    this.onSessionPinToggled,
    this.onSessionForked,
    this.pinnedSessionIds = const <String>{},
  });

  final Future<void> Function(ChatSession session)? onSessionDeleted;
  final Future<bool> Function(ChatSession session, String title)?
  onSessionRenamed;
  final Future<bool> Function(ChatSession session)? onSessionShareToggled;
  final Future<bool> Function(ChatSession session, bool archived)?
  onSessionArchiveToggled;
  final Future<void> Function(ChatSession session)? onSessionPinToggled;
  final Future<void> Function(ChatSession session)? onSessionForked;
  final Set<String> pinnedSessionIds;

  bool isPinned(ChatSession session) => pinnedSessionIds.contains(session.id);
}

class SessionContextMenuButton extends StatelessWidget {
  const SessionContextMenuButton({
    super.key,
    required this.session,
    required this.actions,
    required this.surface,
    this.iconColor,
    this.compact = false,
  });

  final ChatSession session;
  final SessionContextMenuActions actions;
  final String surface;
  final Color? iconColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.chatSessionActions,
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
      icon: compact ? null : Icon(Symbols.more_vert, color: iconColor),
      child: compact
          ? Semantics(
              button: true,
              label: context.l10n.chatSessionActions,
              child: SizedBox.square(
                dimension: 32,
                child: Icon(Symbols.more_vert, size: 18, color: iconColor),
              ),
            )
          : null,
      onOpened: () =>
          logSessionContextMenuOpen(surface: surface, sessionId: session.id),
      onSelected: (value) => unawaited(
        handleSessionContextMenuSelection(
          context,
          session: session,
          value: value,
          actions: actions,
        ),
      ),
      itemBuilder: (context) => buildSessionContextMenuEntries(
        context,
        session: session,
        isPinned: actions.isPinned(session),
      ),
    );
  }
}

class SessionContextMenuRegion extends StatelessWidget {
  const SessionContextMenuRegion({
    super.key,
    required this.session,
    required this.actions,
    required this.surface,
    required this.child,
  });

  final ChatSession session;
  final SessionContextMenuActions actions;
  final String surface;
  final Widget child;

  Offset _centerPosition(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (innerContext) {
        void openAtCenter({required bool haptic}) {
          final pos = _centerPosition(innerContext);
          unawaited(
            showSessionContextMenu(
              innerContext,
              session: session,
              actions: actions,
              surface: surface,
              globalPosition: pos,
              haptic: haptic,
            ),
          );
        }

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.contextMenu): () => openAtCenter(haptic: false),
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): () => openAtCenter(haptic: false),
          },
          child: Semantics(
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: innerContext.l10n.chatSessionActions): () => openAtCenter(haptic: false),
            },
            onLongPress: () => openAtCenter(haptic: true),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapUp: (details) => unawaited(
                showSessionContextMenu(
                  innerContext,
                  session: session,
                  actions: actions,
                  surface: surface,
                  globalPosition: details.globalPosition,
                ),
              ),
              onLongPressStart: (details) => unawaited(
                showSessionContextMenu(
                  innerContext,
                  session: session,
                  actions: actions,
                  surface: surface,
                  globalPosition: details.globalPosition,
                  haptic: true,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

List<PopupMenuEntry<String>> buildSessionContextMenuEntries(
  BuildContext context, {
  required ChatSession session,
  required bool isPinned,
}) {
  final errorColor = Theme.of(context).colorScheme.error;
  return [
    PopupMenuItem(
      value: sessionMenuPin,
      child: Row(
        children: [
          const Icon(Symbols.push_pin),
          const SizedBox(width: 8),
          Text(isPinned ? context.l10n.sessionUnpin : context.l10n.sessionPin),
        ],
      ),
    ),
    PopupMenuItem(
      value: sessionMenuRename,
      child: Row(
        children: [
          const Icon(Symbols.edit),
          const SizedBox(width: 8),
          Text(context.l10n.sessionRename),
        ],
      ),
    ),
    PopupMenuItem(
      value: sessionMenuShare,
      child: Row(
        children: [
          Icon(session.shared ? Symbols.link_off : Symbols.link),
          const SizedBox(width: 8),
          Text(
            session.shared
                ? context.l10n.sessionUnshareAction
                : context.l10n.sessionShareAction,
          ),
        ],
      ),
    ),
    if (session.shareUrl != null && session.shareUrl!.isNotEmpty)
      PopupMenuItem(
        value: sessionMenuCopyLink,
        child: Row(
          children: [
            const Icon(Symbols.content_copy),
            const SizedBox(width: 8),
            Text(context.l10n.sessionCopyLink),
          ],
        ),
      ),
    PopupMenuItem(
      value: sessionMenuArchive,
      child: Row(
        children: [
          Icon(session.archived ? Symbols.unarchive : Symbols.archive),
          const SizedBox(width: 8),
          Text(
            session.archived
                ? context.l10n.sessionUnarchive
                : context.l10n.sessionArchive,
          ),
        ],
      ),
    ),
    PopupMenuItem(
      value: sessionMenuFork,
      child: Row(
        children: [
          const Icon(Symbols.call_split),
          const SizedBox(width: 8),
          Text(context.l10n.sessionFork),
        ],
      ),
    ),
    PopupMenuItem(
      value: sessionMenuDelete,
      child: Row(
        children: [
          Icon(Symbols.delete, color: errorColor),
          const SizedBox(width: 8),
          Text(context.l10n.sessionDelete, style: TextStyle(color: errorColor)),
        ],
      ),
    ),
  ];
}

List<PopupMenuEntry<SessionMenuAction>> buildUnifiedSessionMenuEntries(
  BuildContext context, {
  ChatSession? session,
  required bool isPinned,
  SessionTabIdentity? tabIdentity,
  bool includeTabLocal = false,
  bool includeActiveOnly = false,
  bool isActive = true,
  bool canUndo = false,
  bool canRedo = false,
  bool canCompact = true,
  bool canCloseProject = false,
  String? closeProjectLabel,
}) {
  final errorColor = Theme.of(context).colorScheme.error;
  final entries = <PopupMenuEntry<SessionMenuAction>>[];

  PopupMenuItem<SessionMenuAction> item(
    SessionMenuAction action, {
    required IconData icon,
    required String label,
    Color? color,
    bool enabled = true,
  }) {
    return PopupMenuItem<SessionMenuAction>(
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: color != null ? TextStyle(color: color) : null,
            ),
          ),
        ],
      ),
    );
  }

  // Entity actions.
  if (session != null) {
    entries.add(
      item(
        SessionMenuAction.pin,
        icon: Symbols.push_pin,
        label: isPinned ? context.l10n.sessionUnpin : context.l10n.sessionPin,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.rename,
        icon: Symbols.edit,
        label: tabIdentity != null ? context.l10n.sessionTabRenameAction : context.l10n.sessionRename,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.share,
        icon: session.shared ? Symbols.link_off : Symbols.link,
        label: tabIdentity != null
            ? (session.shared ? context.l10n.sessionUnshare : context.l10n.sessionShare)
            : (session.shared ? context.l10n.sessionUnshareAction : context.l10n.sessionShareAction),
      ),
    );
    if (session.shareUrl != null && session.shareUrl!.isNotEmpty) {
      entries.add(
        item(
          SessionMenuAction.copyLink,
          icon: Symbols.content_copy,
          label: context.l10n.sessionCopyLink,
        ),
      );
    }
    entries.add(
      item(
        SessionMenuAction.archive,
        icon: session.archived ? Symbols.unarchive : Symbols.archive,
        label: session.archived
            ? context.l10n.sessionUnarchive
            : context.l10n.sessionArchive,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.fork,
        icon: Symbols.call_split,
        label: context.l10n.sessionFork,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.delete,
        icon: Symbols.delete,
        label: context.l10n.sessionDelete,
        color: errorColor,
      ),
    );
  } else {
    entries.add(
      item(
        SessionMenuAction.pin,
        icon: Symbols.push_pin,
        label: isPinned ? context.l10n.sessionUnpin : context.l10n.sessionPin,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.rename,
        icon: Symbols.edit,
        label: context.l10n.sessionRename,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.fork,
        icon: Symbols.call_split,
        label: context.l10n.sessionFork,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.delete,
        icon: Symbols.delete,
        label: context.l10n.sessionDelete,
        color: errorColor,
      ),
    );
  }

  if (includeTabLocal && tabIdentity != null) {
    entries.add(
      item(
        SessionMenuAction.changeIcon,
        icon: Symbols.category,
        label: context.l10n.sessionTabChangeIconAction,
      ),
    );
  }

  if (includeActiveOnly) {
    entries.add(const PopupMenuDivider());
    entries.add(
      item(
        SessionMenuAction.exportMarkdown,
        icon: Symbols.description,
        label: context.l10n.sessionExportMarkdown,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.exportJson,
        icon: Symbols.data_object,
        label: context.l10n.sessionExportDebugJson,
      ),
    );
    entries.add(const PopupMenuDivider());
    entries.add(
      item(
        SessionMenuAction.viewTasks,
        icon: Symbols.checklist,
        label: context.l10n.sessionViewTasks,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.reviewChanges,
        icon: Symbols.preview,
        label: context.l10n.chatReviewChanges,
      ),
    );
    entries.add(const PopupMenuDivider());
    entries.add(
      item(
        SessionMenuAction.undo,
        icon: Symbols.undo_rounded,
        label: context.l10n.chatUndoLastTurn,
        enabled: isActive ? canUndo : true,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.redo,
        icon: Symbols.redo_rounded,
        label: context.l10n.chatRedoLastTurn,
        enabled: isActive ? canRedo : true,
      ),
    );
    entries.add(
      item(
        SessionMenuAction.compact,
        icon: Symbols.compress,
        label: context.l10n.sessionCompactContext,
        enabled: isActive ? canCompact : true,
      ),
    );
  }

  if (canCloseProject && closeProjectLabel != null) {
    entries.add(const PopupMenuDivider());
    entries.add(
      item(
        SessionMenuAction.closeProject,
        icon: Symbols.close,
        label: closeProjectLabel,
        color: errorColor,
      ),
    );
  }

  return entries;
}

Future<void> showSessionContextMenu(
  BuildContext context, {
  required ChatSession session,
  required SessionContextMenuActions actions,
  required String surface,
  required Offset globalPosition,
  bool haptic = false,
}) async {
  if (haptic) {
    unawaited(HapticFeedback.mediumImpact());
  }
  logSessionContextMenuOpen(surface: surface, sessionId: session.id);

  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) {
    return;
  }
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    items: buildSessionContextMenuEntries(
      context,
      session: session,
      isPinned: actions.isPinned(session),
    ),
  );
  if (!context.mounted || selected == null) {
    return;
  }
  await handleSessionContextMenuSelection(
    context,
    session: session,
    value: selected,
    actions: actions,
  );
}

Future<void> handleSessionContextMenuSelection(
  BuildContext context, {
  required ChatSession session,
  required String value,
  required SessionContextMenuActions actions,
}) async {
  switch (value) {
    case sessionMenuRename:
      showSessionRenameDialog(context, session, actions);
      return;
    case sessionMenuShare:
      await _toggleShare(context, session, actions);
      return;
    case sessionMenuCopyLink:
      await _copyShareLink(context, session);
      return;
    case sessionMenuArchive:
      await _toggleArchive(context, session, actions);
      return;
    case sessionMenuPin:
      await _togglePinned(context, session, actions);
      return;
    case sessionMenuFork:
      await _forkSession(session, actions);
      return;
    case sessionMenuDelete:
      _showDeleteDialog(context, session, actions);
      return;
  }
}

void logSessionContextMenuOpen({
  required String surface,
  required String sessionId,
}) {
  AppLogger.debug('session_context_menu_open surface=$surface id=$sessionId');
}

void showSessionRenameDialog(
  BuildContext context,
  ChatSession session,
  SessionContextMenuActions actions,
) {
  final callback = actions.onSessionRenamed;
  if (callback == null) {
    return;
  }

  unawaited(
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _SessionRenameDialog(
        initialTitle: session.title ?? '',
        onSubmitted: (newTitle) async {
          Navigator.of(dialogContext).pop();
          final ok = await callback(session, newTitle);
          if (!context.mounted) {
            return;
          }
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.sessionFailedRename)),
            );
          }
        },
      ),
    ),
  );
}

class _SessionRenameDialog extends StatefulWidget {
  const _SessionRenameDialog({
    required this.initialTitle,
    required this.onSubmitted,
  });

  final String initialTitle;
  final Future<void> Function(String title) onSubmitted;

  @override
  State<_SessionRenameDialog> createState() => _SessionRenameDialogState();
}

class _SessionRenameDialogState extends State<_SessionRenameDialog> {
  late final TextEditingController _controller;
  var _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitRename() async {
    final newTitle = _controller.text.trim();
    if (_submitted || newTitle.isEmpty) {
      return;
    }
    _submitted = true;
    await widget.onSubmitted(newTitle);
  }

  @override
  Widget build(BuildContext context) {
    return ModalPrimaryActionShortcuts(
      onPrimaryAction: () => unawaited(_submitRename()),
      child: AlertDialog(
        title: Text(context.l10n.sessionRenameTitle),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.sessionRenameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => unawaited(_submitRename()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

String _sessionActionSnackBarText(
  BuildContext context, {
  required String action,
}) {
  return context.l10n.chatSessionConversationNextAction(action);
}

String _sessionActionPinned(BuildContext context, {required bool pinned}) {
  return pinned
      ? context.l10n.sessionActionPinned
      : context.l10n.sessionActionUnpinned;
}

String _sessionActionArchived(BuildContext context, {required bool archived}) {
  return archived
      ? context.l10n.sessionActionArchived
      : context.l10n.sessionActionUnarchived;
}

Future<void> _toggleShare(
  BuildContext context,
  ChatSession session,
  SessionContextMenuActions actions,
) async {
  final callback = actions.onSessionShareToggled;
  if (callback == null) {
    return;
  }

  final ok = await callback(session);
  if (!context.mounted) {
    return;
  }
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.sessionFailedUpdateSharing)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        session.shared
            ? context.l10n.sessionUnshared
            : context.l10n.sessionShared,
      ),
    ),
  );
}

Future<void> _copyShareLink(BuildContext context, ChatSession session) async {
  final link = session.shareUrl;
  if (link == null || link.isEmpty) {
    return;
  }
  await Clipboard.setData(ClipboardData(text: link));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.sessionShareLinkCopied)));
}

Future<void> _toggleArchive(
  BuildContext context,
  ChatSession session,
  SessionContextMenuActions actions,
) async {
  final callback = actions.onSessionArchiveToggled;
  if (callback == null) {
    return;
  }

  final archive = !session.archived;
  final ok = await callback(session, archive);
  if (!context.mounted) {
    return;
  }
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.sessionFailedUpdateArchive)),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _sessionActionSnackBarText(
          context,
          action: _sessionActionArchived(context, archived: archive),
        ),
      ),
    ),
  );
}

Future<void> _togglePinned(
  BuildContext context,
  ChatSession session,
  SessionContextMenuActions actions,
) async {
  final callback = actions.onSessionPinToggled;
  if (callback == null) {
    return;
  }

  final wasPinned = actions.isPinned(session);
  await callback(session);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        _sessionActionSnackBarText(
          context,
          action: _sessionActionPinned(context, pinned: !wasPinned),
        ),
      ),
    ),
  );
}

Future<void> _forkSession(
  ChatSession session,
  SessionContextMenuActions actions,
) async {
  final callback = actions.onSessionForked;
  if (callback == null) {
    return;
  }
  await callback(session);
}

void _showDeleteDialog(
  BuildContext context,
  ChatSession session,
  SessionContextMenuActions actions,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.sessionDeleteTitle),
      content: Text(
        context.l10n.sessionDeleteConfirm(
          SessionTitleFormatter.displayTitle(
            time: session.time,
            title: session.title,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            final callback = actions.onSessionDeleted;
            if (callback != null) {
              unawaited(callback(session));
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.l10n.sessionDelete),
        ),
      ],
    ),
  );
}
