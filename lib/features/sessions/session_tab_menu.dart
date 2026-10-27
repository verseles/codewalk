import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../platform/sessions/session_tabs_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'project_contexts_controller.dart';
import 'session_actions_menu.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_tab_icon_picker.dart';
import 'session_tabs_controller.dart';
import 'sessions_controller.dart';

/// The sidebar's session actions, opened from the tab body without selecting
/// it, plus its local glyph and project actions.
class SessionTabMenu extends StatefulWidget {
  const SessionTabMenu({
    super.key,
    required this.tabs,
    required this.tab,
    required this.child,
  });
  final SessionTabsController tabs;
  final SessionTab tab;
  final Widget child;
  @override
  State<SessionTabMenu> createState() => _SessionTabMenuState();
}

class _SessionTabMenuState extends State<SessionTabMenu> {
  final _menu = GlobalKey<PopupMenuButtonState>();
  final _anchor = GlobalKey();
  Offset _offset = Offset.zero;
  bool _openingHistory = false;

  void _open({Offset? point, bool haptic = false}) {
    if (haptic) unawaited(HapticFeedback.selectionClick());
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(
      () => _offset = point == null
          ? Offset.zero
          : point - box.localToGlobal(Offset.zero),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _menu.currentState?.showButtonMenu();
    });
  }

  void _notice(String text) {
    if (!mounted) return;
    showAppSnackBar(ScaffoldMessenger.maybeOf(context), text);
  }

  Future<void> _icon() async {
    final tabs = widget.tabs;
    final tab = widget.tab;
    final result = await showSessionTabIconPicker(
      context,
      currentPresetId: tabs.iconFor(tab.ref),
    );
    if (result == null || !mounted) return;
    final contexts = context.read<ProjectContextsController?>();
    final directory = tab.project?.canonicalDirectory;
    final allowed =
        !tabs.deleted(tab.ref) &&
        (directory == null || contexts?.open.contains(directory) == true);
    if (!allowed || !await tabs.setIcon(tab, result.presetId)) {
      if (mounted) _notice(context.v2L10n.sessionTabIconSaveFailed);
    }
  }

  Future<void> _closeProject() async {
    final contexts = context.read<ProjectContextsController?>();
    final directory = widget.tab.project?.canonicalDirectory;
    if (contexts == null ||
        directory == null ||
        contexts.busy ||
        contexts.open.length <= 1) {
      return;
    }
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.v2L10n.projectsUnavailable;
    final before = router.routeInformationProvider.value.uri;
    final shown = contexts.active == directory;
    final saved = await contexts.close(directory);
    // This menu leaves with the project's tabs; the router and messenger it
    // captured still finish the close.
    if (!saved) {
      if (messenger?.mounted ?? false) {
        showAppSnackBar(messenger, failed);
      }
    } else if (shown && router.routeInformationProvider.value.uri == before) {
      final next = contexts.active;
      final view = next == null ? null : contexts.viewOf(next);
      router.go(
        view == null
            ? '/sessions'
            : Uri(
                pathSegments: ['', 's', view.host.value, view.nativeId],
              ).toString(),
      );
    }
  }

  Future<void> _history(SessionsController catalog, SessionSummary row) async {
    final factory = context.read<SessionHistoryFactory?>();
    final profile = catalog.selectedProfile;
    if (_openingHistory ||
        factory == null ||
        profile == null ||
        catalog.loading ||
        catalog.hosts.loading ||
        catalog.hosts.storageError ||
        profile.id != row.info.ref.host.value ||
        catalog.findSession(row.info.ref) == null) {
      return;
    }
    setState(() => _openingHistory = true);
    final history = SessionHistoryController(
      hosts: catalog.hosts,
      profile: profile,
      summary: row,
      sourceFactory: factory,
    );
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => SessionHistoryPage(controller: history),
        ),
      );
    } finally {
      history.dispose();
      if (mounted) setState(() => _openingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final catalog = context.watch<SessionsController?>();
    final contexts = context.watch<ProjectContextsController?>();
    final row = catalog?.findSession(widget.tab.ref);
    final directory = widget.tab.project?.canonicalDirectory;
    final open =
        contexts != null &&
        directory != null &&
        contexts.open.contains(directory);
    final closeLabel = open
        ? l10n.chatCloseProject(serverPathName(directory))
        : null;
    final closeReason = contexts?.open.length == 1
        ? l10n.projectProviderErrorAtLeastOneContext
        : contexts?.busy == true
        ? l10n.sessionsActionUnavailableBusy
        : null;
    final history =
        context.watch<SessionHistoryFactory?>() != null &&
        context.watch<SessionLiveDirectory?>() != null;
    final control = row != null && catalog != null
        ? SessionActionsMenu(
            controller: catalog,
            row: row,
            menuKey: _menu,
            pinned: widget.tabs.isPinned(widget.tab),
            commands: catalog.lists(row.info.ref),
            onPin: open
                ? (pin) => unawaited(contexts.setPinned(row, pinned: pin))
                : null,
            onHistory: history ? () => unawaited(_history(catalog, row)) : null,
            historyEnabled:
                !_openingHistory &&
                !catalog.loading &&
                !catalog.hosts.loading &&
                !catalog.hosts.storageError,
            onChangeIcon: () => unawaited(_icon()),
            onCloseProject: open ? () => unawaited(_closeProject()) : null,
            closeProjectLabel: closeLabel,
            closeProjectReason: closeReason,
            offset: _offset,
            child: const SizedBox(width: 1, height: 1),
          )
        : PopupMenuButton<SessionRowAction>(
            key: _menu,
            offset: _offset,
            onSelected: (value) {
              if (value == SessionRowAction.changeIcon) unawaited(_icon());
              if (value == SessionRowAction.closeProject) {
                unawaited(_closeProject());
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: SessionRowAction.changeIcon,
                child: Text(l10n.sessionTabChangeIconAction),
              ),
              if (closeLabel != null)
                PopupMenuItem(
                  value: SessionRowAction.closeProject,
                  enabled: closeReason == null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        closeLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (closeReason != null) Text(closeReason),
                    ],
                  ),
                ),
            ],
            child: const SizedBox(width: 1, height: 1),
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => _open(point: details.globalPosition),
      onLongPress: () => _open(haptic: true),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): _open,
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): _open,
        },
        child: Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(label: l10n.sessionsActionsMenu): () =>
                _open(haptic: true),
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      key: _anchor,
                      width: 1,
                      height: 1,
                      child: ExcludeSemantics(child: control),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
