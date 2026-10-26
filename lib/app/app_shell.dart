import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/hosts/endpoint_health_view.dart';
import '../features/hosts/server_switcher.dart';
import '../features/sessions/session_tab_strip.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/sessions_page.dart';
import '../features/sessions/workspace_draft_controller.dart';
import '../features/sessions/workspace_draft_page.dart';
import '../shared/l10n/l10n_context.dart';
import '../shared/layout/window_size_class.dart';
import '../shared/shortcuts/shortcut_action.dart';
import 'app_keyboard_shortcuts.dart';
import 'workspace_chrome.dart';
import 'workspace_controller.dart';

/// The workspace of the legacy client: the projects and their sessions on the
/// start side, the chat beside them.
///
/// A compact window gives the chat the whole window, the open session or the
/// workspace home, and keeps the list in a drawer; from 600 dp the list stays
/// beside the chat in a fixed pane, 260 dp wide below 840 dp and 300 dp from
/// there, which leaves the chat at least 339 dp. Servers, settings and
/// pairing are secondary pages with a way back to the workspace.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static bool isWorkspace(String location) =>
      location == '/' || location == '/sessions' || location.startsWith('/s/');

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    if (!isWorkspace(location)) {
      // A launch on another page spends the return to the last tab, so a
      // later visit to the list stays there.
      context.read<SessionTabsController?>()?.takeLaunchTab();
      final title = switch (location) {
        '/settings' => l10n.settingsTitle,
        '/hosts' || '/pair' => l10n.settingsServersTitle,
        _ => 'CodeWalk',
      };
      return Scaffold(
        appBar: AppBar(
          // A page opened from the list returns to it; one opened by a link
          // has nothing under it and goes to the list.
          leading: BackButton(
            key: const ValueKey('workspace-back'),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/sessions'),
          ),
          title: Text(title),
        ),
        body: child,
      );
    }
    final home = location == '/' || location == '/sessions';
    final hasServer =
        context.watch<SessionsController?>()?.selectedProfile != null;
    final tabs = context.read<SessionTabsController?>();
    final workspace = KeyboardActionScope(
      handlers: {ShortcutAction.newChat: () => _create(context)},
      // Keeps the keyboard inside the workspace when nothing in it has the
      // focus, so its shortcuts reach this scope.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final size = WindowSizeClass.fromWidth(width);
            if (size.isCompact) {
              // The chat takes the window; the list is a drawer. An open
              // session brings its own bar.
              return Scaffold(
                appBar: home
                    ? AppBar(
                        leading: Builder(
                          builder: (context) => WorkspaceMenuButton(
                            openDrawer: Scaffold.of(context).openDrawer,
                          ),
                        ),
                        title: hasServer
                            ? const ServerSwitcher(
                                controlKey: ValueKey('workspace-server'),
                              )
                            : const Text('CodeWalk'),
                        actions: const [WorkspaceAppBarActions()],
                      )
                    : null,
                drawer: const Drawer(child: SafeArea(child: SessionsPage())),
                body: _WorkspaceBack(child: child),
              );
            }
            final pane = size == WindowSizeClass.medium ? 260.0 : 300.0;
            return Scaffold(
              appBar: AppBar(
                title: hasServer
                    ? const ServerSwitcher(
                        controlKey: ValueKey('workspace-server'),
                      )
                    : const Text('CodeWalk'),
                actions: const [WorkspaceAppBarActions()],
              ),
              body: Row(
                children: [
                  SizedBox(
                    key: const ValueKey('workspace-sidebar'),
                    width: pane,
                    child: const SessionsPage(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _WorkspaceBack(child: child)),
                ],
              ),
            );
          },
        ),
      ),
    );
    final observed = WorkspaceWarningObserver(child: workspace);
    if (tabs == null) return observed;
    return SessionTabsWatcher(
      tabs: tabs,
      catalog: context.read<SessionsController?>(),
      home: home,
      child: observed,
    );
  }

  /// Opens the local draft without sending a session command.
  void _create(BuildContext context) {
    final controller = context.read<SessionsController?>();
    if (controller == null || !canCreate(controller)) return;
    openWorkspaceDraft(context);
  }

  /// Whether the workspace can open a local draft for the selected server.
  static bool canCreate(SessionsController controller) =>
      canOpenWorkspaceDraft(controller);
}

/// The system back at the root of the workspace, as in the legacy client: it
/// opens the list drawer while it is closed, and once it is open it sends
/// the app to the background. Without a drawer it goes straight there.
class _WorkspaceBack extends StatelessWidget {
  const _WorkspaceBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final shell = Scaffold.maybeOf(context);
      if (shell != null && shell.hasDrawer && !shell.isDrawerOpen) {
        shell.openDrawer();
      } else {
        unawaited(SystemNavigator.pop());
      }
    },
    child: child,
  );
}

/// The chat of the workspace when no session is open: the way to start one,
/// or what keeps it from starting and the way out.
///
/// It asks the workspace for its server when it first shows, so a saved
/// server opens without being chosen.
class WorkspaceHome extends StatefulWidget {
  const WorkspaceHome({super.key});

  @override
  State<WorkspaceHome> createState() => _WorkspaceHomeState();
}

class _WorkspaceHomeState extends State<WorkspaceHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WorkspaceController?>()?.restoreServer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final catalog = context.watch<SessionsController?>();
    final health = context.watch<EndpointHealthController?>();
    final drafts = context.watch<WorkspaceDraftController?>();
    if (drafts != null && drafts.isDraftActive) {
      return WorkspaceDraftPage(controller: drafts);
    }
    if (catalog == null) {
      return _HomeState(
        icon: Icons.chat_bubble_outline,
        title: l10n.sessionsUnavailable,
      );
    }
    final hosts = catalog.hosts;
    void openServers() => context.push('/hosts');
    if (hosts.storageError) {
      return _HomeState(
        icon: Icons.error_outline,
        title: l10n.hostsProfileStorageError,
        actions: [
          FilledButton(
            key: const ValueKey('workspace-open-servers'),
            onPressed: openServers,
            child: Text(l10n.liveErrorOpenServers),
          ),
        ],
      );
    }
    if (hosts.loading || !hosts.loaded) return const _HomeLoading();
    // No server, no chat: the home says so and leads to the setup.
    if (hosts.profiles.isEmpty) {
      return _HomeState(
        icon: Icons.dns_outlined,
        title: l10n.chatNoServerYet,
        body: l10n.chatAddServerToStart,
        actions: [
          FilledButton.icon(
            key: const ValueKey('workspace-set-up-server'),
            onPressed: openServers,
            icon: const Icon(Icons.add),
            label: Text(l10n.chatSetUpServer),
          ),
        ],
      );
    }
    final profile = catalog.selectedProfile;
    if (profile == null) return const _HomeLoading();
    if (health?.view(profile).status == EndpointHealthStatus.offline) {
      return _HomeState(
        icon: Icons.cloud_off_outlined,
        title: profile.label,
        actions: [
          if (AppShell.canCreate(catalog))
            FilledButton.icon(
              key: const ValueKey('workspace-new-chat'),
              onPressed: () => openWorkspaceDraft(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.chatNewChat),
            ),
          EndpointHealthRecovery(profile: profile, health: health!),
        ],
      );
    }
    // A saved server that does not answer limits the chat, and the home
    // keeps the ways out of it.
    if (catalog.failure case final failure?) {
      return _HomeState(
        icon: Icons.cloud_off_outlined,
        title: profile.label,
        body: sessionCatalogFailureText(l10n, failure),
        actions: [
          if (AppShell.canCreate(catalog))
            FilledButton.icon(
              key: const ValueKey('workspace-new-chat'),
              onPressed: () => openWorkspaceDraft(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.chatNewChat),
            ),
          FilledButton(
            key: const ValueKey('workspace-retry'),
            onPressed: catalog.loading ? null : catalog.refresh,
            child: Text(l10n.chatRetry),
          ),
          OutlinedButton(
            key: const ValueKey('workspace-open-servers'),
            onPressed: openServers,
            child: Text(l10n.liveErrorOpenServers),
          ),
        ],
      );
    }
    final create = AppShell.canCreate(catalog);
    return _HomeState(
      icon: Icons.chat_bubble_outline,
      title: l10n.chatSelectOrCreate,
      actions: [
        FilledButton.icon(
          key: const ValueKey('workspace-new-chat'),
          onPressed: create ? () => openWorkspaceDraft(context) : null,
          icon: const Icon(Icons.add),
          label: Text(l10n.chatNewChat),
        ),
      ],
    );
  }
}

/// The home while the saved servers load or one is being chosen: a short
/// local wait that shows nothing rather than a flicker.
class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('workspace-loading'));
}

class _HomeState extends StatelessWidget {
  const _HomeState({
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('workspace-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body case final body?) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
