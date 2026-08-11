import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/generated/app_localizations.dart';

enum SessionTabIconPreset {
  code('code', Symbols.code),
  terminal('terminal', Symbols.terminal),
  bug('bug', Symbols.bug_report),
  tasks('tasks', Symbols.checklist),
  launch('launch', Symbols.rocket_launch),
  idea('idea', Symbols.lightbulb),
  research('research', Symbols.science),
  design('design', Symbols.palette),
  data('data', Symbols.database),
  cloud('cloud', Symbols.cloud),
  security('security', Symbols.shield),
  tools('tools', Symbols.build);

  const SessionTabIconPreset(this.id, this.icon);

  final String id;
  final IconData icon;

  static SessionTabIconPreset? fromId(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    for (final preset in values) {
      if (preset.id == normalized) return preset;
    }
    return null;
  }
}

String sessionTabIconPresetLabel(
  AppLocalizations l10n,
  SessionTabIconPreset preset,
) {
  return switch (preset) {
    SessionTabIconPreset.code => l10n.sessionTabIconPresetCode,
    SessionTabIconPreset.terminal => l10n.sessionTabIconPresetTerminal,
    SessionTabIconPreset.bug => l10n.sessionTabIconPresetBug,
    SessionTabIconPreset.tasks => l10n.sessionTabIconPresetTasks,
    SessionTabIconPreset.launch => l10n.sessionTabIconPresetLaunch,
    SessionTabIconPreset.idea => l10n.sessionTabIconPresetIdea,
    SessionTabIconPreset.research => l10n.sessionTabIconPresetResearch,
    SessionTabIconPreset.design => l10n.sessionTabIconPresetDesign,
    SessionTabIconPreset.data => l10n.sessionTabIconPresetData,
    SessionTabIconPreset.cloud => l10n.sessionTabIconPresetCloud,
    SessionTabIconPreset.security => l10n.sessionTabIconPresetSecurity,
    SessionTabIconPreset.tools => l10n.sessionTabIconPresetTools,
  };
}
