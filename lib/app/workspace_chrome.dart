import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/hosts/endpoint_health_view.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/workspace_draft_page.dart';
import '../shared/l10n/generated/v2_localizations.dart';
import '../shared/l10n/l10n_context.dart';
import '../shared/sessions/session_live_source.dart';
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
    return IconButton(
      key: const ValueKey('workspace-drawer'),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: openDrawer,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.menu),
          if (badge.kind != WorkspaceBadgeKind.none)
            PositionedDirectional(
              end: -5,
              top: -5,
              child: Semantics(
                label: workspaceBadgeText(context.v2L10n, badge),
                child: badge.kind == WorkspaceBadgeKind.syncing
                    ? const SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.circle,
                        key: ValueKey('workspace-badge-${badge.kind.name}'),
                        size: 10,
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
    final badge = context.watch<WorkspaceChromeController?>()?.badge;
    if (badge == null || badge.kind == WorkspaceBadgeKind.none) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const ValueKey('workspace-drawer-notice'),
      dense: true,
      leading: Icon(
        badge.kind == WorkspaceBadgeKind.syncing
            ? Icons.sync
            : Icons.info_outline,
      ),
      title: Text(workspaceBadgeText(context.v2L10n, badge)),
      onTap:
          badge.session == null && badge.kind != WorkspaceBadgeKind.serverAlert
          ? null
          : () {
              Scaffold.maybeOf(context)?.closeDrawer();
              if (badge.session case final ref?) {
                context.go(
                  Uri(
                    pathSegments: ['', 's', ref.host.value, ref.nativeId],
                  ).path,
                );
              } else {
                context.push('/hosts');
              }
            },
    );
  }
}

class WorkspaceAppBarActions extends StatelessWidget {
  const WorkspaceAppBarActions({super.key});

  String _label(V2Localizations l, WorkspacePinnedAction action) =>
      switch (action) {
        WorkspacePinnedAction.newChat => l.chatNewChat,
        WorkspacePinnedAction.refresh => l.chatRefresh,
        WorkspacePinnedAction.servers => l.settingsServersTitle,
        WorkspacePinnedAction.settings => l.settingsTitle,
      };
  IconData _icon(WorkspacePinnedAction action) => switch (action) {
    WorkspacePinnedAction.newChat => Icons.add,
    WorkspacePinnedAction.refresh => Icons.refresh,
    WorkspacePinnedAction.servers => Icons.dns_outlined,
    WorkspacePinnedAction.settings => Icons.settings_outlined,
  };
  VoidCallback? _run(BuildContext context, WorkspacePinnedAction action) {
    final catalog = context.read<SessionsController?>();
    return switch (action) {
      WorkspacePinnedAction.newChat =>
        catalog == null || !canOpenWorkspaceDraft(catalog)
            ? null
            : () => openWorkspaceDraft(context),
      WorkspacePinnedAction.refresh =>
        catalog == null || catalog.loading
            ? null
            : () {
                context.read<SessionLiveDirectory?>()?.wake();
                unawaited(catalog.refresh());
              },
      WorkspacePinnedAction.servers => () => context.push('/hosts'),
      WorkspacePinnedAction.settings => () => context.push('/settings'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<AppPreferencesController?>();
    context.watch<SessionsController?>();
    final l = context.v2L10n;
    final pins = preferences?.appBarPins ?? [WorkspacePinnedAction.newChat];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in pins)
          IconButton(
            key: ValueKey('workspace-pinned-${action.name}'),
            tooltip: _label(l, action),
            onPressed: _run(context, action),
            icon: Icon(_icon(action)),
          ),
        PopupMenuButton<WorkspacePinnedAction>(
          key: const ValueKey('workspace-actions'),
          tooltip: l.chatAppBarMoreActions,
          onSelected: (action) => _run(context, action)?.call(),
          itemBuilder: (context) => [
            for (final action in WorkspacePinnedAction.values)
              PopupMenuItem(
                value: action,
                enabled: _run(context, action) != null,
                child: Row(
                  children: [
                    Icon(_icon(action)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_label(l, action))),
                    if (preferences != null)
                      ListenableBuilder(
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
                            icon: Icon(
                              pinned ? Icons.push_pin : Icons.push_pin_outlined,
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
                  ],
                ),
              ),
          ],
        ),
      ],
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
