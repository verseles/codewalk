import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../logs_page.dart';

class LogsSettingsSection extends StatelessWidget {
  const LogsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Logs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open the logs viewer to inspect runtime events, copy output, and clear history.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>('settings_open_logs_button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsPage()),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open App Logs'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
