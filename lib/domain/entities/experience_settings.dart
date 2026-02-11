enum NotificationCategory { agent, permissions, errors }

enum SoundCategory { agent, permissions, errors }

enum SoundOption { off, click, alert }

enum ShortcutAction {
  newChat,
  refresh,
  focusInput,
  quickOpen,
  escape,
  cycleAgentForward,
  cycleAgentBackward,
}

class ShortcutDefinition {
  const ShortcutDefinition({
    required this.action,
    required this.group,
    required this.label,
    required this.description,
    required this.defaultBinding,
  });

  final ShortcutAction action;
  final String group;
  final String label;
  final String description;
  final String defaultBinding;
}

const List<ShortcutDefinition> kShortcutDefinitions = <ShortcutDefinition>[
  ShortcutDefinition(
    action: ShortcutAction.newChat,
    group: 'Session',
    label: 'New conversation',
    description: 'Create a new chat session',
    defaultBinding: 'mod+n',
  ),
  ShortcutDefinition(
    action: ShortcutAction.refresh,
    group: 'General',
    label: 'Refresh data',
    description: 'Refresh current chat data',
    defaultBinding: 'mod+r',
  ),
  ShortcutDefinition(
    action: ShortcutAction.focusInput,
    group: 'Prompt',
    label: 'Focus input',
    description: 'Move focus to the prompt input',
    defaultBinding: 'mod+l',
  ),
  ShortcutDefinition(
    action: ShortcutAction.quickOpen,
    group: 'Navigation',
    label: 'Quick open files',
    description: 'Open file quick search',
    defaultBinding: 'mod+p',
  ),
  ShortcutDefinition(
    action: ShortcutAction.escape,
    group: 'Navigation',
    label: 'Close/unfocus',
    description: 'Close drawer or unfocus input',
    defaultBinding: 'escape',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleAgentForward,
    group: 'Model and agent',
    label: 'Next agent',
    description: 'Cycle to next available agent',
    defaultBinding: 'mod+j',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleAgentBackward,
    group: 'Model and agent',
    label: 'Previous agent',
    description: 'Cycle to previous available agent',
    defaultBinding: 'mod+shift+j',
  ),
];

String notificationCategoryKey(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.agent => 'agent',
    NotificationCategory.permissions => 'permissions',
    NotificationCategory.errors => 'errors',
  };
}

NotificationCategory? notificationCategoryFromKey(String value) {
  return switch (value) {
    'agent' => NotificationCategory.agent,
    'permissions' => NotificationCategory.permissions,
    'errors' => NotificationCategory.errors,
    _ => null,
  };
}

String soundCategoryKey(SoundCategory category) {
  return switch (category) {
    SoundCategory.agent => 'agent',
    SoundCategory.permissions => 'permissions',
    SoundCategory.errors => 'errors',
  };
}

SoundCategory? soundCategoryFromKey(String value) {
  return switch (value) {
    'agent' => SoundCategory.agent,
    'permissions' => SoundCategory.permissions,
    'errors' => SoundCategory.errors,
    _ => null,
  };
}

String soundOptionKey(SoundOption option) {
  return switch (option) {
    SoundOption.off => 'off',
    SoundOption.click => 'click',
    SoundOption.alert => 'alert',
  };
}

SoundOption soundOptionFromKey(String value) {
  return switch (value) {
    'click' => SoundOption.click,
    'alert' => SoundOption.alert,
    _ => SoundOption.off,
  };
}

String shortcutActionKey(ShortcutAction action) {
  return switch (action) {
    ShortcutAction.newChat => 'new_chat',
    ShortcutAction.refresh => 'refresh',
    ShortcutAction.focusInput => 'focus_input',
    ShortcutAction.quickOpen => 'quick_open',
    ShortcutAction.escape => 'escape',
    ShortcutAction.cycleAgentForward => 'cycle_agent_forward',
    ShortcutAction.cycleAgentBackward => 'cycle_agent_backward',
  };
}

ShortcutAction? shortcutActionFromKey(String value) {
  return switch (value) {
    'new_chat' => ShortcutAction.newChat,
    'refresh' => ShortcutAction.refresh,
    'focus_input' => ShortcutAction.focusInput,
    'quick_open' => ShortcutAction.quickOpen,
    'escape' => ShortcutAction.escape,
    'cycle_agent_forward' => ShortcutAction.cycleAgentForward,
    'cycle_agent_backward' => ShortcutAction.cycleAgentBackward,
    _ => null,
  };
}

class ExperienceSettings {
  const ExperienceSettings({
    required this.notifications,
    required this.sounds,
    required this.shortcuts,
  });

  final Map<NotificationCategory, bool> notifications;
  final Map<SoundCategory, SoundOption> sounds;
  final Map<ShortcutAction, String> shortcuts;

  factory ExperienceSettings.defaults() {
    final shortcuts = <ShortcutAction, String>{
      for (final definition in kShortcutDefinitions)
        definition.action: definition.defaultBinding,
    };
    return ExperienceSettings(
      notifications: const <NotificationCategory, bool>{
        NotificationCategory.agent: true,
        NotificationCategory.permissions: true,
        NotificationCategory.errors: true,
      },
      sounds: const <SoundCategory, SoundOption>{
        SoundCategory.agent: SoundOption.alert,
        SoundCategory.permissions: SoundOption.click,
        SoundCategory.errors: SoundOption.alert,
      },
      shortcuts: shortcuts,
    );
  }

  ExperienceSettings copyWith({
    Map<NotificationCategory, bool>? notifications,
    Map<SoundCategory, SoundOption>? sounds,
    Map<ShortcutAction, String>? shortcuts,
  }) {
    return ExperienceSettings(
      notifications: notifications ?? this.notifications,
      sounds: sounds ?? this.sounds,
      shortcuts: shortcuts ?? this.shortcuts,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notifications': <String, bool>{
        for (final entry in notifications.entries)
          notificationCategoryKey(entry.key): entry.value,
      },
      'sounds': <String, String>{
        for (final entry in sounds.entries)
          soundCategoryKey(entry.key): soundOptionKey(entry.value),
      },
      'shortcuts': <String, String>{
        for (final entry in shortcuts.entries)
          shortcutActionKey(entry.key): entry.value,
      },
    };
  }

  static ExperienceSettings fromJson(Map<String, dynamic> json) {
    final defaults = ExperienceSettings.defaults();

    final notifications = Map<NotificationCategory, bool>.from(
      defaults.notifications,
    );
    final sounds = Map<SoundCategory, SoundOption>.from(defaults.sounds);
    final shortcuts = Map<ShortcutAction, String>.from(defaults.shortcuts);

    final notificationsJson = json['notifications'];
    if (notificationsJson is Map) {
      for (final entry in notificationsJson.entries) {
        final category = notificationCategoryFromKey(entry.key.toString());
        if (category == null) {
          continue;
        }
        notifications[category] = entry.value == true;
      }
    }

    final soundsJson = json['sounds'];
    if (soundsJson is Map) {
      for (final entry in soundsJson.entries) {
        final category = soundCategoryFromKey(entry.key.toString());
        if (category == null) {
          continue;
        }
        sounds[category] = soundOptionFromKey(entry.value.toString());
      }
    }

    final shortcutsJson = json['shortcuts'];
    if (shortcutsJson is Map) {
      for (final entry in shortcutsJson.entries) {
        final action = shortcutActionFromKey(entry.key.toString());
        if (action == null) {
          continue;
        }
        final value = entry.value.toString().trim().toLowerCase();
        if (value.isNotEmpty) {
          shortcuts[action] = value;
        }
      }
    }

    return ExperienceSettings(
      notifications: notifications,
      sounds: sounds,
      shortcuts: shortcuts,
    );
  }
}
