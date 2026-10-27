import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/chat_appearance.dart';

/// How the chat behaves, like the retained reference's Behavior section:
/// whether assistant responses render live or each block once finished.
class BehaviorSettingsPage extends StatelessWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppPreferencesController>();
    final l = context.v2L10n;
    final mode = p.chatRenderMode;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const ValueKey('behavior_settings_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.settingsBehaviorTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.settingsBehaviorChatRenderMode,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.settingsBehaviorChatRenderModeDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ChatRenderMode>(
                      key: const ValueKey('settings_chat_render_mode'),
                      segments: [
                        ButtonSegment(
                          value: ChatRenderMode.live,
                          label: Text(l.settingsBehaviorChatRenderModeLive),
                        ),
                        ButtonSegment(
                          value: ChatRenderMode.block,
                          label: Text(l.settingsBehaviorChatRenderModeBlock),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (selection) =>
                          p.setChatRenderMode(selection.single),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (mode) {
                        ChatRenderMode.live =>
                          l.settingsBehaviorChatRenderModeLiveDescription,
                        ChatRenderMode.block =>
                          l.settingsBehaviorChatRenderModeBlockDescription,
                      },
                      key: const ValueKey('settings_chat_render_mode_detail'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
