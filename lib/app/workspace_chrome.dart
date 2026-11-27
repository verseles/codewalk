import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../features/hosts/endpoint_health_view.dart';
import '../features/sessions/session_context_usage.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/workspace_draft_page.dart';
import '../shared/l10n/generated/v2_localizations.dart';
import '../shared/l10n/l10n_context.dart';
import '../shared/widgets/app_indeterminate_progress.dart';
import '../shared/widgets/app_snack_bar.dart';
import 'app_preferences_controller.dart';
import 'workspace_chrome_controller.dart';

String workspaceBadgeText(V2Localizations l, WorkspaceBadge badge) =>
    switch (badge.kind) {
      WorkspaceBadgeKind.none => '',
      WorkspaceBadgeKind.serverAlert => l.chatBadgeServerNeedsAttention,
      WorkspaceBadgeKind.error => l.chatBadgeConversationError(badge.title),
      WorkspaceBadgeKind.needsInput => l.chatBadgeConversationNeedsInput(
        badge.title,
      ),
      WorkspaceBadgeKind.updateReady => l.updatesCachedInstall,
      WorkspaceBadgeKind.updateAvailable => l.settingsAboutUpdateAvailable(
        badge.title,
      ),
      WorkspaceBadgeKind.unread => l.chatBadgeConversationNewReply(badge.title),
      WorkspaceBadgeKind.syncing ||
      WorkspaceBadgeKind.syncAlert => l.chatBadgeSyncing,
    };

class WorkspaceMenuButton extends StatelessWidget {
  const WorkspaceMenuButton({required this.openDrawer, super.key});
  final VoidCallback openDrawer;
  @override
  Widget build(BuildContext context) {
    final badge =
        context.watch<WorkspaceChromeController?>()?.badge ??
        const WorkspaceBadge(WorkspaceBadgeKind.none);
    final isUpdateBadge =
        badge.kind == WorkspaceBadgeKind.updateReady ||
        badge.kind == WorkspaceBadgeKind.updateAvailable;
    return IconButton(
      key: const ValueKey('workspace-drawer'),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: openDrawer,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Symbols.menu),
          if (badge.kind != WorkspaceBadgeKind.none)
            PositionedDirectional(
              end: -5,
              top: -5,
              child: Semantics(
                label: workspaceBadgeText(context.v2L10n, badge),
                child: badge.kind == WorkspaceBadgeKind.syncing
                    ? const AppIndeterminateRing(size: 12, strokeWidth: 2)
                    : Icon(
                        isUpdateBadge ? Symbols.download : Symbols.circle,
                        key: ValueKey('workspace-badge-${badge.kind.name}'),
                        size: isUpdateBadge ? 12 : 10,
                        fill: 1,
                        color: switch (badge.kind) {
                          WorkspaceBadgeKind.serverAlert ||
                          WorkspaceBadgeKind.syncAlert ||
                          WorkspaceBadgeKind.error => Theme.of(
                            context,
                          ).colorScheme.error,
                          WorkspaceBadgeKind.needsInput => Theme.of(
                            context,
                          ).colorScheme.tertiary,
                          _ => Theme.of(context).colorScheme.primary,
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class WorkspaceDrawerNotice extends StatelessWidget {
  const WorkspaceDrawerNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<WorkspaceChromeController?>();
    if (chrome == null) return const SizedBox.shrink();
    final badge = chrome.badge;
    final showSecondaryUpdateTile =
        chrome.hasPendingCachedUpdate &&
        badge.kind != WorkspaceBadgeKind.updateReady;
    if (badge.kind == WorkspaceBadgeKind.none && !showSecondaryUpdateTile) {
      return const SizedBox.shrink();
    }
    final l = context.v2L10n;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final tiles = <Widget>[
      if (showSecondaryUpdateTile)
        ListTile(
          key: const ValueKey('workspace-update-notice'),
          dense: true,
          leading: Icon(Symbols.download, color: primaryColor),
          title: Text(l.updatesCachedInstall),
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            unawaited(chrome.installPendingCachedUpdate());
          },
        ),
      if (badge.kind != WorkspaceBadgeKind.none)
        ListTile(
          key: const ValueKey('workspace-drawer-notice'),
          dense: true,
          leading: Icon(
            switch (badge.kind) {
              WorkspaceBadgeKind.syncing => Symbols.sync,
              WorkspaceBadgeKind.updateReady ||
              WorkspaceBadgeKind.updateAvailable => Symbols.download,
              _ => Symbols.info,
            },
            color:
                badge.kind == WorkspaceBadgeKind.updateReady ||
                    badge.kind == WorkspaceBadgeKind.updateAvailable
                ? primaryColor
                : null,
          ),
          title: Text(workspaceBadgeText(l, badge)),
          onTap: switch (badge.kind) {
            WorkspaceBadgeKind.updateReady => () {
              Scaffold.maybeOf(context)?.closeDrawer();
              unawaited(chrome.installPendingCachedUpdate());
            },
            WorkspaceBadgeKind.updateAvailable => () {
              Scaffold.maybeOf(context)?.closeDrawer();
              context.push('/settings');
            },
            _ =>
              badge.session == null &&
                      badge.kind != WorkspaceBadgeKind.serverAlert
                  ? null
                  : () {
                      Scaffold.maybeOf(context)?.closeDrawer();
                      if (badge.session case final ref?) {
                        context.go(
                          Uri(
                            pathSegments: [
                              '',
                              's',
                              ref.host.value,
                              ref.nativeId,
                            ],
                          ).path,
                        );
                      } else {
                        context.push('/hosts');
                      }
                    },
          },
        ),
    ];
    if (tiles.length == 1) return tiles.single;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
    );
  }
}

class WorkspaceAppBarActions extends StatelessWidget {
  const WorkspaceAppBarActions({required this.compact, super.key});

  final bool compact;

  String _label(V2Localizations l, WorkspacePinnedAction action) =>
      switch (action) {
        WorkspacePinnedAction.contextUsage => l.contextUsageTitle,
        WorkspacePinnedAction.newChat => l.chatNewChat,
        WorkspacePinnedAction.servers => l.settingsServersTitle,
        WorkspacePinnedAction.settings => l.settingsTitle,
      };
  IconData _icon(WorkspacePinnedAction action) => switch (action) {
    WorkspacePinnedAction.contextUsage => Symbols.donut_large,
    WorkspacePinnedAction.newChat => Symbols.add_comment,
    WorkspacePinnedAction.servers => Symbols.dns,
    WorkspacePinnedAction.settings => Symbols.settings,
  };
  VoidCallback? _run(
    BuildContext context,
    WorkspacePinnedAction action, {
    required bool showUsageControl,
    required WorkspaceChromeController? chrome,
  }) {
    final catalog = context.read<SessionsController?>();
    final live = chrome?.activeLive;
    return switch (action) {
      WorkspacePinnedAction.contextUsage =>
        showUsageControl && live != null
            ? () => unawaited(
                showContextUsageFromOverflow(context, live, compact: compact),
              )
            : null,
      WorkspacePinnedAction.newChat =>
        catalog == null || !canOpenWorkspaceDraft(catalog)
            ? null
            : () => openWorkspaceDraft(context),
      WorkspacePinnedAction.servers => () => context.push('/hosts'),
      WorkspacePinnedAction.settings => () => context.push('/settings'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesController?>();
    context.watch<SessionsController?>();
    final chrome = context.watch<WorkspaceChromeController?>();
    final live = chrome?.activeLive;
    final l = context.v2L10n;
    final wide = !compact;
    final pins =
        preferences?.appBarPins ?? AppPreferencesController.defaultAppBarPins;
    // A Settings pin saved on a wide layout must not duplicate the fixed
    // drawer-header action when the compact bar renders.
    final shownPins = wide
        ? pins
        : [
            for (final action in pins)
              if (action != WorkspacePinnedAction.settings) action,
          ];
    const order = [
      WorkspacePinnedAction.contextUsage,
      WorkspacePinnedAction.newChat,
      WorkspacePinnedAction.settings,
      WorkspacePinnedAction.servers,
    ];
    final menuOrder = wide
        ? order
        : [
            for (final action in order)
              if (action != WorkspacePinnedAction.settings) action,
          ];
    Widget menu(bool showUsageControl) {
      final firstEnabled = menuOrder.firstWhere(
        (action) =>
            _run(
              context,
              action,
              showUsageControl: showUsageControl,
              chrome: chrome,
            ) !=
            null,
        orElse: () => WorkspacePinnedAction.servers,
      );
      return MenuAnchor(
        builder: (context, controller, child) => IconButton(
          key: const ValueKey('workspace-actions'),
          icon: const Icon(Symbols.more_vert),
          tooltip: l.chatAppBarMoreActions,
          onPressed: controller.isOpen ? controller.close : controller.open,
        ),
        menuChildren: [
          // v1: chat_page_mobile_overflow.dart:230-265 (items and dividers).
          for (final action in order)
            if (wide || action != WorkspacePinnedAction.settings) ...[
              MenuItemButton(
                key: action == WorkspacePinnedAction.contextUsage
                    ? const ValueKey('workspace-menu-contextUsage')
                    : null,
                // Pointer opening must also transfer keyboard focus into the menu.
                autofocus: action == firstEnabled,
                leadingIcon: Icon(_icon(action)),
                onPressed: _run(
                  context,
                  action,
                  showUsageControl: showUsageControl,
                  chrome: chrome,
                ),
                trailingIcon: preferences == null
                    ? null
                    : ListenableBuilder(
                        listenable: preferences,
                        builder: (context, _) {
                          final pinned = preferences.appBarPins.contains(
                            action,
                          );
                          return IconButton(
                            key: ValueKey('workspace-pin-${action.name}'),
                            tooltip: pinned
                                ? l.chatAppBarUnpinAction
                                : l.chatAppBarPinAction,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(
                              minWidth: 34,
                              minHeight: 34,
                            ),
                            iconSize: 18,
                            icon: Icon(
                              Symbols.push_pin,
                              color: pinned
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: preferences.canEditAppBarPins
                                ? () => preferences.setAppBarPinned(
                                    action,
                                    !pinned,
                                  )
                                : null,
                          );
                        },
                      ),
                child: Text(_label(l, action)),
              ),
              if (action != WorkspacePinnedAction.servers || !wide)
                const Divider(height: 1),
            ],
          const Divider(height: 1),
          MenuItemButton(
            key: const ValueKey('workspace-display-menu'),
            leadingIcon: const Icon(Symbols.tune),
            onPressed: preferences == null
                ? null
                : () => showWorkspaceDisplayMenu(context),
            child: Text(l.chatDisplayMenu),
          ),
          // v1: chat_page_mobile_overflow.dart:140, the search (#462); a wide
          // window has it on the toolbar.
          if (!wide) ...[
            const Divider(height: 1),
            MenuItemButton(
              key: const ValueKey('workspace-search'),
              leadingIcon: const Icon(Symbols.search),
              onPressed: live?.search.show,
              child: Text(l.liveSearch),
            ),
            const Divider(height: 1),
          ],
          // v1: chat_page_mobile_overflow.dart:112-123. Undo is always listed and
          // disabled without a turn to undo; redo and compact need a live session.
          if (!wide) ...[
            MenuItemButton(
              key: const ValueKey('turn-menu-undo'),
              leadingIcon: const Icon(Symbols.undo_rounded),
              onPressed: live != null && live.turn.canUndo
                  ? () => unawaited(live.turn.undoLast(context: context))
                  : null,
              child: Text(l.chatUndoLastTurn),
            ),
            if (live != null) ...[
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('turn-menu-redo-next'),
                leadingIcon: const Icon(Symbols.redo_rounded),
                onPressed: live.turn.canRedoNext
                    ? () => unawaited(live.turn.redoNext(context: context))
                    : null,
                child: Text(l.chatRedoLastTurn),
              ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('turn-menu-redo-all'),
                leadingIcon: const Icon(Symbols.fast_forward),
                onPressed: live.turn.canRedoAll
                    ? () => unawaited(live.turn.redoAll(context: context))
                    : null,
                child: Text(l.chatRedoAll),
              ),
              const Divider(height: 1),
              MenuItemButton(
                key: const ValueKey('turn-menu-compact'),
                leadingIcon: const Icon(Symbols.compress),
                onPressed: live.turn.canCompact
                    ? () => unawaited(live.turn.compact(context: context))
                    : null,
                child: Text(l.chatCompactContext),
              ),
            ],
          ],
        ],
      );
    }

    Widget actions() {
      final showUsageControl = live != null && live.usageView.supportsAny;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in shownPins)
            if (action == WorkspacePinnedAction.contextUsage) ...[
              if (showUsageControl)
                ContextUsageButton(
                  key: const ValueKey('workspace-pinned-contextUsage'),
                  live: live,
                  compact: compact,
                ),
            ] else
              IconButton(
                key: ValueKey('workspace-pinned-${action.name}'),
                tooltip: _label(l, action),
                onPressed: _run(
                  context,
                  action,
                  showUsageControl: showUsageControl,
                  chrome: chrome,
                ),
                icon: Icon(_icon(action)),
              ),
          if (wide)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // v1: chat_page_chrome.dart:983 (#462).
                IconButton(
                  key: const ValueKey('workspace-search'),
                  tooltip: l.liveSearch,
                  icon: const Icon(Symbols.search),
                  onPressed: live?.search.show,
                ),
                IconButton(
                  key: const ValueKey('turn-menu-undo'),
                  tooltip: l.chatUndoLastTurn,
                  icon: const Icon(Symbols.undo_rounded),
                  onPressed: live != null && live.turn.canUndo
                      ? () => unawaited(live.turn.undoLast(context: context))
                      : null,
                ),
                if (live != null) ...[
                  IconButton(
                    key: const ValueKey('turn-menu-redo-next'),
                    tooltip: l.chatRedoLastTurn,
                    icon: const Icon(Symbols.redo_rounded),
                    onPressed: live.turn.canRedoNext
                        ? () => unawaited(live.turn.redoNext(context: context))
                        : null,
                  ),
                  IconButton(
                    key: const ValueKey('turn-menu-redo-all'),
                    tooltip: l.chatRedoAll,
                    icon: const Icon(Symbols.fast_forward),
                    onPressed: live.turn.canRedoAll
                        ? () => unawaited(live.turn.redoAll(context: context))
                        : null,
                  ),
                  IconButton(
                    key: const ValueKey('turn-menu-compact'),
                    tooltip: l.chatCompactContext,
                    icon: const Icon(Symbols.compress),
                    onPressed: live.turn.canCompact
                        ? () => unawaited(live.turn.compact(context: context))
                        : null,
                  ),
                ],
              ],
            ),
          menu(showUsageControl),
        ],
      );
    }

    return live == null
        ? actions()
        : ListenableBuilder(
            listenable: Listenable.merge([live, live.turn]),
            builder: (context, _) => actions(),
          );
  }
}

/// Delivers a controller-confirmed warning only while its workspace is mounted.
class WorkspaceWarningObserver extends StatefulWidget {
  const WorkspaceWarningObserver({required this.child, super.key});
  final Widget child;
  @override
  State<WorkspaceWarningObserver> createState() =>
      _WorkspaceWarningObserverState();
}

class _WorkspaceWarningObserverState extends State<WorkspaceWarningObserver> {
  WorkspaceChromeController? _controller;
  int _seen = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.watch<WorkspaceChromeController?>();
    if (identical(next, _controller)) return;
    _controller?.removeListener(_changed);
    _controller = next;
    _seen = 0;
    next?.addListener(_changed);
    _changed();
  }

  void _changed() {
    final controller = _controller;
    if (controller == null || controller.warningRevision == _seen) return;
    _seen = controller.warningRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(controller, _controller)) return;
      final profile = controller.takeWarning();
      if (profile == null) return;
      final l = context.v2L10n;
      final reason = endpointHealthReason(l, controller.health.view(profile));
      if (reason == null) return;
      showAppSnackBar(
        ScaffoldMessenger.maybeOf(context),
        reason,
        action: SnackBarAction(
          label: l.settingsServersTitle,
          onPressed: () => context.push('/hosts'),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The display choices that shape the workspace in place, reachable from the
/// chat without opening Settings.
Future<void> showWorkspaceDisplayMenu(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _WorkspaceDisplaySheet(),
    );

class _WorkspaceDisplaySheet extends StatelessWidget {
  const _WorkspaceDisplaySheet();

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesController?>();
    final l = context.v2L10n;
    if (preferences == null) return const SizedBox.shrink();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('workspace-display-sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l.chatDisplayMenu)),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-thinking'),
                title: Text(l.settingsAppearanceThinkingBubbles),
                value: preferences.showReasoning,
                onChanged: preferences.setShowReasoning,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-tool-calls'),
                title: Text(l.settingsAppearanceToolCallBubbles),
                value: preferences.showToolCalls,
                onChanged: preferences.setShowToolCalls,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-task-list'),
                title: Text(l.settingsAppearanceTaskList),
                value: preferences.showTaskList,
                onChanged: preferences.setShowTaskList,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-tps'),
                title: Text(l.settingsAppearanceTokensPerSecond),
                value: preferences.showTokensPerSecond,
                onChanged: preferences.setShowTokensPerSecond,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-composer-tips'),
                title: Text(l.settingsAppearanceComposerTips),
                value: preferences.composerTips,
                onChanged: preferences.setComposerTips,
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('display-toggle-session-tabs'),
                title: Text(l.settingsAppearanceSessionTabs),
                value: preferences.showSessionTabs,
                onChanged: preferences.setShowSessionTabs,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
