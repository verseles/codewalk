import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/sessions/session_create_dialog.dart';
import '../features/sessions/session_tab_strip.dart';
import '../features/sessions/session_tabs_controller.dart';
import '../features/sessions/sessions_controller.dart';
import '../features/sessions/sessions_page.dart';
import '../shared/l10n/l10n_context.dart';
import '../shared/layout/window_size_class.dart';
import '../shared/sessions/session_actions.dart';
import '../shared/shortcuts/shortcut_action.dart';
import 'app_keyboard_shortcuts.dart';

/// The workspace of the legacy client: the projects and their sessions on the
/// start side, the open session beside them.
///
/// A compact window shows the list on its own; from 600 dp the list stays
/// beside the detail in a fixed pane, 260 dp wide below 840 dp and 300 dp
/// from there, which leaves the detail at least 339 dp. Servers, settings and
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
              if (home) {
                return Scaffold(
                  appBar: AppBar(title: const Text('CodeWalk')),
                  body: const SessionsPage(),
                );
              }
              // The open session takes the window; the list is a drawer.
              return Scaffold(
                drawer: const Drawer(child: SafeArea(child: SessionsPage())),
                body: _BackToList(child: child),
              );
            }
            final pane = size == WindowSizeClass.medium ? 260.0 : 300.0;
            return Scaffold(
              appBar: AppBar(title: const Text('CodeWalk')),
              body: Row(
                children: [
                  SizedBox(
                    key: const ValueKey('workspace-sidebar'),
                    width: pane,
                    child: const SessionsPage(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: home ? child : _BackToList(child: child)),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (tabs == null) return workspace;
    return SessionTabsWatcher(
      tabs: tabs,
      catalog: context.read<SessionsController?>(),
      home: home,
      child: workspace,
    );
  }

  /// Opens the create of the list, when the list offers it.
  void _create(BuildContext context) {
    final controller = context.read<SessionsController?>();
    if (controller == null ||
        controller.hosts.loading ||
        controller.hosts.storageError ||
        controller.selectedProfile == null ||
        controller.creating ||
        controller.createReason != SessionActionReason.none) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => SessionCreateDialog(controller: controller),
    );
  }
}

/// The system back from an open session: it closes the list drawer when
/// open, otherwise returns to the list instead of leaving the app.
class _BackToList extends StatelessWidget {
  const _BackToList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      final shell = Scaffold.maybeOf(context);
      if (shell != null && shell.isDrawerOpen) {
        shell.closeDrawer();
      } else {
        context.go('/sessions');
      }
    },
    child: child,
  );
}

/// The detail of the workspace when no session is open.
class WorkspaceHome extends StatelessWidget {
  const WorkspaceHome({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        context.v2L10n.workspaceSelectSession,
        key: const ValueKey('workspace-empty'),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
