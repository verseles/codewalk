import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'settings/sections/notifications_settings_section.dart';
import 'settings/sections/servers_settings_section.dart';
import 'settings/sections/shortcuts_settings_section.dart';
import 'settings/sections/sounds_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialSectionId = ''});

  final String initialSectionId;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsSection {
  const _SettingsSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final WidgetBuilder builder;
}

class _SettingsPageState extends State<SettingsPage> {
  static const double _splitBreakpoint = 980;

  late final List<_SettingsSection> _sections = <_SettingsSection>[
    _SettingsSection(
      id: 'notifications',
      title: 'Notifications',
      description: 'Category alerts and permission prompts',
      icon: Icons.notifications_active_outlined,
      builder: (_) => const NotificationsSettingsSection(),
    ),
    _SettingsSection(
      id: 'sounds',
      title: 'Sounds',
      description: 'Category sounds and preview',
      icon: Icons.volume_up_outlined,
      builder: (_) => const SoundsSettingsSection(),
    ),
    _SettingsSection(
      id: 'shortcuts',
      title: 'Shortcuts',
      description: 'Search and edit key bindings',
      icon: Icons.keyboard_command_key_rounded,
      builder: (_) => const ShortcutsSettingsSection(),
    ),
    _SettingsSection(
      id: 'servers',
      title: 'Servers',
      description: 'OpenCode servers and health routing',
      icon: Icons.dns_outlined,
      builder: (_) => const ServersSettingsSection(),
    ),
  ];

  String? _selectedSectionId;
  bool _showMobileDetail = false;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = _sections
        .where((section) => section.id == widget.initialSectionId)
        .firstOrNull
        ?.id;
    _selectedSectionId ??= _sections.first.id;
    _showMobileDetail = widget.initialSectionId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final section = _sections
        .where((item) => item.id == _selectedSectionId)
        .firstOrNull;
    final width = MediaQuery.of(context).size.width;
    final isSplit = width >= _splitBreakpoint;

    if (!isSplit) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _showMobileDetail ? (section?.title ?? 'Settings') : 'Settings',
          ),
          leading: _showMobileDetail
              ? IconButton(
                  tooltip: 'Back',
                  onPressed: () {
                    setState(() {
                      _showMobileDetail = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
        ),
        body: _showMobileDetail && section != null
            ? section.builder(context)
            : _buildSectionList(isSplit: false),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Row(
        children: [
          SizedBox(width: 320, child: _buildSectionList(isSplit: true)),
          const VerticalDivider(width: 1),
          Expanded(
            child: section == null
                ? const SizedBox.shrink()
                : section.builder(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList({required bool isSplit}) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        if (!isSplit)
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        if (!isSplit) const SizedBox(height: 8),
        ..._sections.map((section) {
          final selected = section.id == _selectedSectionId;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              selected: selected,
              leading: Icon(section.icon),
              title: Text(section.title),
              subtitle: Text(section.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _selectedSectionId = section.id;
                  _showMobileDetail = true;
                });
              },
            ),
          );
        }),
      ],
    );
  }
}
