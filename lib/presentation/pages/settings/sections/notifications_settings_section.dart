import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';

class NotificationsSettingsSection extends StatelessWidget {
  const NotificationsSettingsSection({super.key});

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
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: settingsProvider.isNotificationEnabled(
                      NotificationCategory.agent,
                    ),
                    onChanged: (value) =>
                        settingsProvider.setNotificationEnabled(
                          NotificationCategory.agent,
                          value,
                        ),
                    title: const Text('Agent updates'),
                    subtitle: const Text('When an agent response is finished'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settingsProvider.isNotificationEnabled(
                      NotificationCategory.permissions,
                    ),
                    onChanged: (value) =>
                        settingsProvider.setNotificationEnabled(
                          NotificationCategory.permissions,
                          value,
                        ),
                    title: const Text('Permissions and questions'),
                    subtitle: const Text('When a tool asks for your input'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settingsProvider.isNotificationEnabled(
                      NotificationCategory.errors,
                    ),
                    onChanged: (value) =>
                        settingsProvider.setNotificationEnabled(
                          NotificationCategory.errors,
                          value,
                        ),
                    title: const Text('Errors'),
                    subtitle: const Text('When a session error is received'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
