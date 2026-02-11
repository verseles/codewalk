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
              'Configure notification and sound behavior per event type.',
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
                  _categoryTile(
                    context: context,
                    settingsProvider: settingsProvider,
                    category: NotificationCategory.agent,
                    title: 'Agent updates',
                    subtitle: 'When an agent response is finished',
                  ),
                  const Divider(height: 1),
                  _categoryTile(
                    context: context,
                    settingsProvider: settingsProvider,
                    category: NotificationCategory.permissions,
                    title: 'Permissions and questions',
                    subtitle: 'When a tool asks for your input',
                  ),
                  const Divider(height: 1),
                  _categoryTile(
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

  Widget _categoryTile({
    required BuildContext context,
    required SettingsProvider settingsProvider,
    required NotificationCategory category,
    required String title,
    required String subtitle,
  }) {
    final serverBacked = settingsProvider.isServerBackedNotification(category);
    final notifyEnabled = settingsProvider.isNotificationEnabled(category);
    final soundCategory = settingsProvider.soundCategoryForNotification(
      category,
    );
    final soundEnabled = settingsProvider.isSoundEnabledForNotification(
      category,
    );
    final selectedSound = settingsProvider.soundFor(soundCategory);
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SwitchPill(
                label: 'Notify',
                value: notifyEnabled,
                onChanged: (value) =>
                    settingsProvider.setNotificationEnabled(category, value),
              ),
              _SwitchPill(
                label: 'Sound',
                value: soundEnabled,
                onChanged: (value) => settingsProvider
                    .setSoundEnabledForNotification(category, value),
              ),
              if (soundEnabled)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<SoundOption>(
                    value: selectedSound,
                    items: SoundOption.values
                        .where((option) => option != SoundOption.off)
                        .map(
                          (option) => DropdownMenuItem<SoundOption>(
                            value: option,
                            child: Text(_soundLabel(option)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      settingsProvider.setSoundOption(soundCategory, value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Sound type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              if (soundEnabled)
                IconButton.filledTonal(
                  tooltip: 'Preview sound',
                  onPressed: () => settingsProvider.previewSound(soundCategory),
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _soundLabel(SoundOption option) {
    return switch (option) {
      SoundOption.off => 'Off',
      SoundOption.click => 'Click',
      SoundOption.alert => 'Alert',
    };
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 4),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
