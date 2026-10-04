import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/l10n/l10n_context.dart';
import '../shared/layout/window_size_class.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.v2L10n.chatConversations,
      context.v2L10n.settingsServersTitle,
      context.v2L10n.settingsTitle,
    ];
    const routes = ['/sessions', '/hosts', '/settings'];
    final selected = location == '/settings'
        ? 2
        : location == '/hosts' || location == '/pair'
        ? 1
        : 0;
    final wide = context.windowSizeClass.isAtLeastExpanded;
    void navigate(int index) => context.go(routes[index]);

    return Scaffold(
      appBar: AppBar(title: const Text('CodeWalk')),
      body: Row(
        children: [
          if (wide) ...[
            NavigationRail(
              selectedIndex: selected,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: navigate,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(labels[0]),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.dns_outlined),
                  label: Text(labels[1]),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(labels[2]),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: navigate,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: labels[0],
                ),
                NavigationDestination(
                  icon: const Icon(Icons.dns_outlined),
                  label: labels[1],
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: labels[2],
                ),
              ],
            ),
    );
  }
}
