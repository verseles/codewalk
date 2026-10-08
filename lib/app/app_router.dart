import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/settings_shell_page.dart';
import '../shared/l10n/l10n_context.dart';
import 'app_navigation_controller.dart';
import 'app_shell.dart';

GoRouter createAppRouter({
  required AppNavigationController navigation,
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: true,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.toString() == '/unsupported') return null;
      // Preserve an already captured pairing link when its sanitized route mounts.
      if (uri.toString() == '/pair' &&
          navigation.pendingIntent is PairingNavigationIntent) {
        return null;
      }
      final route = navigation.prepareLink(uri);
      return route == uri.toString() ? null : route;
    },
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text(context.v2L10n.unsupportedLink))),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: _sessions),
          GoRoute(path: '/sessions', builder: _sessions),
          GoRoute(
            path: '/hosts',
            builder: (context, state) => _Placeholder(
              title: context.v2L10n.settingsServersTitle,
              message: context.v2L10n.chatAddServerToStart,
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsShellPage(),
          ),
          GoRoute(
            path: '/pair',
            builder: (context, state) => _Placeholder(
              title: context.v2L10n.onboardingConnectRunningServer,
              message: context.v2L10n.chatAddServerToStart,
            ),
          ),
          GoRoute(
            path: '/s/:host/:session',
            builder: (context, state) => _Placeholder(
              title: context.v2L10n.chatConversation,
              message: context.v2L10n.chatAddServerToStart,
            ),
          ),
          GoRoute(
            path: '/unsupported',
            builder: (context, state) =>
                _Placeholder(title: context.v2L10n.unsupportedLink),
          ),
        ],
      ),
    ],
  );
}

Widget _sessions(BuildContext context, GoRouterState state) => _Placeholder(
  title: context.v2L10n.chatConversations,
  message: context.v2L10n.chatAddServerToStart,
  actionLabel: context.v2L10n.onboardingConnectRunningServer,
  onAction: () => context.go('/hosts'),
);

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
