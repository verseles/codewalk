import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/entities/experience_settings.dart';
import '../../../providers/settings_provider.dart';

class SoundsSettingsSection extends StatelessWidget {
  const SoundsSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            Text('Sounds', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Pick a sound per category. Use preview to test quickly.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SoundTile(
              title: 'Agent updates',
              category: SoundCategory.agent,
              settingsProvider: settingsProvider,
            ),
            const SizedBox(height: 12),
            _SoundTile(
              title: 'Permissions and questions',
              category: SoundCategory.permissions,
              settingsProvider: settingsProvider,
            ),
            const SizedBox(height: 12),
            _SoundTile(
              title: 'Errors',
              category: SoundCategory.errors,
              settingsProvider: settingsProvider,
            ),
          ],
        );
      },
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.title,
    required this.category,
    required this.settingsProvider,
  });

  final String title;
  final SoundCategory category;
  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    final selected = settingsProvider.soundFor(category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SoundOption>(
                    value: selected,
                    items: SoundOption.values
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
                      settingsProvider.setSoundOption(category, value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Sound',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Preview sound',
              onPressed: () => settingsProvider.previewSound(category),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ),
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
