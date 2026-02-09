import 'package:flutter/material.dart';

import 'chat_page.dart';
import 'logs_page.dart';
import 'server_settings_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  static const double _railBreakpoint = 720;
  int _selectedIndex = 0;

  final List<_AppDestination> _destinations = const <_AppDestination>[
    _AppDestination(
      label: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    _AppDestination(
      label: 'Logs',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _AppDestination(
      label: 'Settings',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _railBreakpoint;
    final body = _buildBody();

    if (isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 1280,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: _destinations
                    .map(
                      (d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_selectedIndex) {
      0 => const ChatPage(),
      1 => const LogsPage(),
      2 => const ServerSettingsPage(),
      _ => const SizedBox.shrink(),
    };
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _AppDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
