import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_actions.dart';
import 'sessions_controller.dart';

/// The actions one session row offers.
enum SessionRowAction {
  history,
  pin,
  unpin,
  markViewed,
  rename,
  fork,
  hide,
  unhide,
  delete,
  changeIcon,
  closeProject,
}

/// The overflow control of a session row.
///
/// The native entries follow the endpoint's own support: an entry that the
/// endpoint did not define, or that the current rows cannot answer for, is
/// disabled with its reason. The local hide does not depend on the endpoint.
class SessionActionsMenu extends StatefulWidget {
  const SessionActionsMenu({
    required this.controller,
    required this.row,
    required this.menuKey,
    this.onHistory,
    this.historyEnabled = true,
    this.pinned = false,
    this.onPin,
    this.onChangeIcon,
    this.onCloseProject,
    this.closeProjectLabel,
    this.closeProjectReason,
    this.child,
    this.offset = Offset.zero,
    super.key,
  });

  final SessionsController controller;
  final SessionSummary row;

  /// The key of the popup, so the row's own gestures open the same menu.
  final GlobalKey<PopupMenuButtonState> menuKey;

  /// Opens the session's read-only history, the entry the row offers beside
  /// opening the session itself. Null leaves the entry out.
  final VoidCallback? onHistory;
  final bool historyEnabled;

  /// Whether the row is pinned in its project, and the local pin toggle;
  /// a null [onPin] leaves the entry out, as a row outside a project
  /// context has nothing to be pinned in.
  final bool pinned;
  final ValueChanged<bool>? onPin;
  final VoidCallback? onChangeIcon;
  final VoidCallback? onCloseProject;
  final String? closeProjectLabel;
  final String? closeProjectReason;
  final Widget? child;
  final Offset offset;

  @override
  State<SessionActionsMenu> createState() => _SessionActionsMenuState();
}

class _SessionActionsMenuState extends State<SessionActionsMenu> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final controller = widget.controller;
    final row = widget.row;
    final support = controller.actionSupport;
    final pending = controller.actionPending(row.info.ref);
    final listCurrent = !controller.stale && !controller.behind;
    // The menu stays usable while a re-read is pending; the dispatch refuses
    // a row that a pending change may have outdated.
    final enabled = support.available && listCurrent && !pending;
    final reason = _reasonText(
      l10n,
      support.reason,
      listCurrent: listCurrent,
      pending: pending,
    );
    final hidden = controller.isHidden(row);
    final unread = controller.viewState(row) == SessionViewState.unread;
    return KeyedSubtree(
      key: ValueKey('session-actions-${row.info.ref.storageKey}'),
      child: PopupMenuButton<SessionRowAction>(
        key: widget.menuKey,
        icon: widget.child == null ? const Icon(Icons.more_vert) : null,
        offset: widget.offset,
        tooltip: l10n.sessionsActionsMenu,
        enabled: !pending || widget.onChangeIcon != null,
        onSelected: (action) => _run(context, action),
        itemBuilder: (context) => [
          if (widget.onHistory != null)
            PopupMenuItem<SessionRowAction>(
              key: ValueKey('history-open-${row.info.ref.storageKey}'),
              value: SessionRowAction.history,
              enabled: widget.historyEnabled,
              child: Text(l10n.historyOpen),
            ),
          if (widget.onPin != null)
            PopupMenuItem<SessionRowAction>(
              key: ValueKey('session-pin-${row.info.ref.storageKey}'),
              value: widget.pinned
                  ? SessionRowAction.unpin
                  : SessionRowAction.pin,
              child: Text(widget.pinned ? l10n.sessionUnpin : l10n.sessionPin),
            ),
          if (unread)
            PopupMenuItem<SessionRowAction>(
              value: SessionRowAction.markViewed,
              enabled: enabled,
              child: _label(l10n.sessionsActionMarkViewed, reason),
            ),
          PopupMenuItem<SessionRowAction>(
            value: SessionRowAction.rename,
            enabled: enabled,
            child: _label(l10n.sessionsActionRename, reason),
          ),
          PopupMenuItem<SessionRowAction>(
            value: SessionRowAction.fork,
            enabled: enabled,
            child: _label(l10n.sessionsActionFork, reason),
          ),
          PopupMenuItem<SessionRowAction>(
            value: hidden ? SessionRowAction.unhide : SessionRowAction.hide,
            enabled: controller.hideAvailable,
            child: _label(
              hidden ? l10n.sessionsActionUnhide : l10n.sessionsActionHide,
              controller.hideAvailable
                  ? null
                  : l10n.sessionsActionUnavailableStore,
            ),
          ),
          PopupMenuItem<SessionRowAction>(
            value: SessionRowAction.delete,
            enabled: enabled,
            child: _label(l10n.sessionsActionDelete, reason, destructive: true),
          ),
          if (widget.onChangeIcon != null) ...[
            const PopupMenuDivider(),
            PopupMenuItem<SessionRowAction>(
              value: SessionRowAction.changeIcon,
              child: Text(l10n.sessionTabChangeIconAction),
            ),
          ],
          if (widget.closeProjectLabel case final label?)
            PopupMenuItem<SessionRowAction>(
              value: SessionRowAction.closeProject,
              enabled:
                  widget.onCloseProject != null &&
                  widget.closeProjectReason == null,
              child: _label(
                label,
                widget.closeProjectReason,
                destructive: true,
              ),
            ),
        ],
        child: widget.child,
      ),
    );
  }

  /// The reason an entry is not available, as the plan's controls say.
  String? _reasonText(
    V2Localizations l10n,
    SessionActionReason reason, {
    required bool listCurrent,
    required bool pending,
  }) {
    if (!listCurrent) return l10n.sessionsActionUnavailableList;
    if (pending) return l10n.sessionsActionUnavailableBusy;
    return switch (reason) {
      SessionActionReason.none => null,
      SessionActionReason.versionUnverified =>
        l10n.sessionsActionUnavailableVersion,
      SessionActionReason.unsupportedPlatform =>
        l10n.sessionsActionUnavailablePlatform,
      SessionActionReason.authenticationRequired =>
        l10n.sessionsActionUnavailableAuth,
      SessionActionReason.listNotCurrent => l10n.sessionsActionUnavailableList,
      SessionActionReason.commandInFlight => l10n.sessionsActionUnavailableBusy,
      SessionActionReason.noIdleMarker => l10n.sessionsActionUnavailableMarker,
    };
  }

  Widget _label(String title, String? reason, {bool destructive = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: destructive
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  )
                : null,
          ),
          if (reason != null)
            Text(
              reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );

  Future<void> _run(BuildContext context, SessionRowAction action) async {
    final controller = widget.controller;
    final row = widget.row;
    switch (action) {
      case SessionRowAction.history:
        widget.onHistory?.call();
      case SessionRowAction.pin:
        widget.onPin?.call(true);
      case SessionRowAction.unpin:
        widget.onPin?.call(false);
      case SessionRowAction.markViewed:
        await controller.markViewed(row);
      case SessionRowAction.rename:
        final title = await _askTitle(context);
        if (title == null) return;
        await controller.rename(row, title);
      case SessionRowAction.fork:
        await controller.fork(row);
      case SessionRowAction.hide:
        await controller.setHidden(row, hidden: true);
      case SessionRowAction.unhide:
        await controller.setHidden(row, hidden: false);
      case SessionRowAction.delete:
        final confirmed = await _confirmDelete(context);
        if (!confirmed) return;
        await controller.delete(row);
      case SessionRowAction.changeIcon:
        widget.onChangeIcon?.call();
      case SessionRowAction.closeProject:
        widget.onCloseProject?.call();
    }
  }

  /// Asks for the new title. An empty or whitespace title is refused
  /// locally: the endpoint would only answer a refusal.
  Future<String?> _askTitle(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(row: widget.row),
    );
    return title;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DeleteDialog(controller: widget.controller, row: widget.row),
    );
    return confirmed ?? false;
  }
}

/// The dialog that asks for a session's new title.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.row});

  final SessionSummary row;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.row.info.title.trim().isEmpty ? '' : widget.row.info.title,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _text.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.sessionsActionRenameTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.sessionsActionRenameLabel),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(l10n.sessionsActionRenameSave),
        ),
      ],
    );
  }
}

/// The confirmation of a delete.
///
/// The cascade warning carries the real number of direct children, and the
/// delete stays disabled until the count is known: the count is not a lock,
/// but the user is told what the endpoint will delete.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.controller, required this.row});

  final SessionsController controller;
  final SessionSummary row;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  int? _children;
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _count();
  }

  Future<void> _count() async {
    final count = await widget.controller.childCount(widget.row);
    if (!mounted) return;
    setState(() {
      _children = count;
      _counted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final title = widget.row.info.title.trim().isEmpty
        ? l10n.sessionExportUntitled
        : widget.row.info.title;
    final children = _children;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.sessionsActionDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sessionsActionDeleteBody(title)),
          const SizedBox(height: 8),
          if (!_counted)
            Text(l10n.sessionsActionDeleteCounting)
          else if (children == null)
            Text(l10n.sessionsActionDeleteChildrenUnknown)
          else if (children > 0)
            Text(
              children >= 50
                  ? l10n.sessionsActionDeleteChildrenAtLeast(children)
                  : l10n.sessionsActionDeleteChildren(children),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          // The delete waits for a known count: the count is not a lock, but
          // the user is told what the endpoint will delete.
          onPressed: _counted && children != null
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(l10n.commonDelete),
        ),
        if (_counted && children == null)
          TextButton(
            onPressed: () {
              setState(() {
                _counted = false;
                _children = null;
              });
              _count();
            },
            child: Text(l10n.chatRetry),
          ),
      ],
    );
  }
}
