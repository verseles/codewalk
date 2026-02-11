import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';

class NotificationsSettingsSection extends StatefulWidget {
  const NotificationsSettingsSection({super.key});

  @override
  State<NotificationsSettingsSection> createState() =>
      _NotificationsSettingsSectionState();
}

class _NotificationsSettingsSectionState
    extends State<NotificationsSettingsSection> {
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_synced) {
      return;
    }
    _synced = true;
    unawaited(
      context.read<SettingsProvider>().syncNotificationsFromServerConfig(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which events can trigger system notifications.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              settingsProvider.hasAnyServerBackedNotificationCategory
                  ? 'Some categories are synced from /config on the active server.'
                  : 'Current server does not expose notification toggles in /config; local fallback is active.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _toggleTile(
                    context: context,
                    settingsProvider: settingsProvider,
                    category: NotificationCategory.agent,
                    title: 'Agent updates',
                    subtitle: 'When an agent response is finished',
                  ),
                  const Divider(height: 1),
                  _toggleTile(
                    context: context,
                    settingsProvider: settingsProvider,
                    category: NotificationCategory.permissions,
                    title: 'Permissions and questions',
                    subtitle: 'When a tool asks for your input',
                  ),
                  const Divider(height: 1),
                  _toggleTile(
                    context: context,
                    settingsProvider: settingsProvider,
                    category: NotificationCategory.errors,
                    title: 'Errors',
                    subtitle: 'When a session error is received',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _toggleTile({
    required BuildContext context,
    required SettingsProvider settingsProvider,
    required NotificationCategory category,
    required String title,
    required String subtitle,
  }) {
    final serverBacked = settingsProvider.isServerBackedNotification(category);
    return SwitchListTile(
      value: settingsProvider.isNotificationEnabled(category),
      onChanged: (value) =>
          settingsProvider.setNotificationEnabled(category, value),
      title: Row(
        children: [
          Expanded(child: Text(title)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: serverBacked
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              serverBacked ? 'Server' : 'Local',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
      subtitle: Text(subtitle),
    );
  }
}
