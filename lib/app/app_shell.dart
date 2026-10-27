import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/hosts/endpoint_health_controller.dart';
import '../features/hosts/endpoint_health_view.dart';
import '../features/hosts/server_switcher.dart';
import '../features/sessions/project_contexts_controller.dart';
import '../features/sessions/project_picker_dialog.dart';
import '../features/sessions/session_tab_strip.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/sessions_page.dart';
import '../features/sessions/workspace_draft_controller.dart';
import '../features/sessions/workspace_draft_page.dart';
import '../shared/l10n/l10n_context.dart';
import '../shared/layout/window_size_class.dart';
import '../shared/sessions/session_live_source.dart';
import '../shared/shortcuts/shortcut_action.dart';
import 'app_keyboard_shortcuts.dart';
import 'app_preferences_controller.dart';
import 'resizable_session_pane.dart';
import 'workspace_actions.dart';
import 'workspace_chrome.dart';
import 'workspace_controller.dart';

/// The workspace of the legacy client: the projects and their sessions on the
/// start side, the chat beside them.
///
/// A compact window gives the chat the whole window, the open session or the
/// workspace home, and keeps the list in a drawer; from 600 dp the list stays
/// beside the chat in a pane that can be hidden, its project and settings
/// then reached from the bar. A medium window keeps the pane at 260 dp; from
/// 840 dp it is resizable (160–500 dp, 300 by default) and leaves the chat
/// at least 320 dp. Servers, settings and pairing are
/// secondary pages with a way back to the workspace.
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
      handlers: {
        ShortcutAction.newChat: () => _create(context),
        ShortcutAction.focusInput: () => _focusComposer(context),
        ShortcutAction.refresh: () => _refresh(context),
        ShortcutAction.closeApp: () {
          if (!(context.read<WorkspaceActions?>()?.closeTab() ?? false)) {
            _closeWindow();
          }
        },
        if (_desktop) ShortcutAction.quitApp: _quit,
      },
      // Keeps the keyboard inside the workspace when nothing in it has the
      // focus, or a field in it lets the focus go, so its shortcuts reach
      // this scope.
      child: FocusScope(
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
                    ? _WorkspaceAppBar(
                        bar: AppBar(
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
                        ),
                      )
                    : null,
                drawer: const Drawer(
                  child: _WorkspaceEscape(
                    child: SafeArea(child: SessionsPage()),
                  ),
                ),
                body: _WorkspaceEscape(
                  child: _WorkspaceBack(child: _homeTabs(context, tabs, home)),
                ),
              );
            }
            final preferences = context.watch<AppPreferencesController?>();
            final hidden = preferences?.sessionPaneHidden ?? false;
            final chat = _WorkspaceBack(child: _homeTabs(context, tabs, home));
            return Scaffold(
              appBar: _WorkspaceAppBar(
                bar: AppBar(
                  leading: IconButton(
                    key: const ValueKey('workspace-pane-toggle'),
                    tooltip: hidden
                        ? l10n.chatOpenSidebar
                        : l10n.chatHideConversationsSidebar,
                    icon: Icon(hidden ? Icons.menu : Icons.menu_open),
                    onPressed: preferences == null
                        ? null
                        : () => preferences.setSessionPaneHidden(!hidden),
                  ),
                  title: hasServer
                      ? const ServerSwitcher(
                          controlKey: ValueKey('workspace-server'),
                        )
                      : const Text('CodeWalk'),
                  actions: [
                    if (hidden) ..._hiddenPaneActions(context, preferences),
                    const WorkspaceAppBarActions(),
                  ],
                ),
              ),
              body: _WorkspaceEscape(
                child: hidden
                    ? chat
                    : ResizableSessionPane(
                        preferences: preferences,
                        resizable: size.isAtLeastExpanded,
                        pane: const SessionsPage(),
                        chat: chat,
                      ),
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
  Widget _homeTabs(
    BuildContext context,
    SessionTabsController? tabs,
    bool home,
  ) {
    final catalog = context.watch<SessionsController?>();
    if (!home || tabs == null || catalog?.selectedProfile == null) return child;
    return SessionTabsFrame(
      tabs: tabs,
      current: null,
      project: catalog?.selectedProject?.project,
      child: child,
    );
  }

  /// With the pane hidden, its project and the settings stay one tap away.
  List<Widget> _hiddenPaneActions(
    BuildContext context,
    AppPreferencesController? preferences,
  ) {
    final l10n = context.v2L10n;
    final catalog = context.read<SessionsController?>();
    final contexts = context.read<ProjectContextsController?>();
    final pins = preferences?.appBarPins ?? const [];
    return [
      if (catalog != null && contexts != null && contexts.available)
        IconButton(
          key: const ValueKey('workspace-project-context'),
          tooltip: l10n.chatProjectContext,
          icon: const Icon(Icons.folder_open_outlined),
          onPressed: () => unawaited(
            pickWorkspaceProject(context, catalog: catalog, contexts: contexts),
          ),
        ),
      if (!pins.contains(WorkspacePinnedAction.settings))
        IconButton(
          key: const ValueKey('workspace-settings'),
          tooltip: l10n.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
    ];
  }

  /// Focuses the shown session's composer, else the New Chat draft's.
  static void _focusComposer(BuildContext context) {
    if (context.read<WorkspaceActions?>()?.focusComposer() ?? false) return;
    context.read<WorkspaceDraftController?>()?.focusComposer();
  }

  /// Reads the list and wakes the live views again, keeping what is open.
  static void _refresh(BuildContext context) {
    final catalog = context.read<SessionsController?>();
    if (catalog == null || catalog.loading) return;
    context.read<SessionLiveDirectory?>()?.wake();
    unawaited(catalog.refresh());
  }

  static bool get _desktop =>
      !kIsWeb &&
      const {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  /// How a shortcut asks the platform to exit; tests stand in for it.
  @visibleForTesting
  static Future<void> Function(AppExitType type) exitApp = (type) =>
      ServicesBinding.instance.exitApplication(type);

  /// mod+W without a tab to close: the window's ordinary close.
  static void _closeWindow() => unawaited(
    _desktop ? exitApp(AppExitType.cancelable) : SystemNavigator.pop(),
  );

  /// mod+Q on a desktop: the app quits.
  static void _quit() => unawaited(exitApp(AppExitType.required));

  void _create(BuildContext context) {
    final controller = context.read<SessionsController?>();
    if (controller == null || !canCreate(controller)) return;
    openWorkspaceDraft(context);
  }

  /// Whether the workspace can open a local draft for the selected server.
  static bool canCreate(SessionsController controller) =>
      canOpenWorkspaceDraft(controller);
}

/// The bar shares the workspace Escape policy, including an open drawer.
class _WorkspaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _WorkspaceAppBar({required this.bar});

  final AppBar bar;

  @override
  Size get preferredSize => bar.preferredSize;

  @override
  Widget build(BuildContext context) => _WorkspaceEscape(child: bar);
}

/// A single Escape in the workspace: it closes the list drawer when it is
/// open, else it focuses the composer. Overlays, dialogs and a focused
/// composer keep their own Escape; a field inside that lets the focus go
/// leaves it in this scope, so Escape still arrives.
class _WorkspaceEscape extends StatelessWidget {
  const _WorkspaceEscape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => KeyboardActionScope(
    handlers: {
      ShortcutAction.escape: () {
        final shell = Scaffold.maybeOf(context);
        if (shell != null && shell.isDrawerOpen) {
          shell.closeDrawer();
        } else {
          AppShell._focusComposer(context);
        }
      },
    },
    child: FocusScope(child: child),
  );
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
      final drawerOpen = shell?.isDrawerOpen ?? false;
      // A sub-conversation goes back to its immediate parent first.
      final parent = drawerOpen ? null : _shownParent(context);
      if (parent != null) {
        context.go(sessionTabLocation(parent));
      } else if (shell != null && shell.hasDrawer && !drawerOpen) {
        shell.openDrawer();
      } else {
        unawaited(SystemNavigator.pop());
      }
    },
    child: child,
  );

  /// The parent of the session the route shows, when its view knows one.
  static SessionRef? _shownParent(BuildContext context) {
    final path = GoRouter.of(context).routeInformationProvider.value.uri;
    final segments = path.pathSegments;
    if (segments.length != 3 || segments.first != 's') return null;
    final views = context.read<SessionTabsController?>()?.warmViews ?? [];
    for (final view in views) {
      final shown = view.session;
      if (shown.host.value == segments[1] && shown.nativeId == segments[2]) {
        return view.summary.info.lineage.parent;
      }
    }
    return null;
  }
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
