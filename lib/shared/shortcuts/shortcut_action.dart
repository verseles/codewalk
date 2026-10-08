import '../l10n/generated/v2_localizations.dart';

/// Stable local identities shared with the v1 importer, not server keybinds.
enum ShortcutAction {
  newChat('new_chat', 'mod+n'),
  refresh('refresh', 'mod+r'),
  focusInput('focus_input', 'mod+l'),
  toggleVoiceInput('toggle_voice_input', 'alt+shift+s'),
  quickOpen('quick_open', 'mod+p'),
  openSettings('open_settings', 'mod+,'),
  cycleRecentModels('cycle_recent_models', 'mod+m'),
  cycleVariant('cycle_variant', 'mod+t'),
  escape('escape', 'escape'),
  cycleAgentForward('cycle_agent_forward', 'alt+shift+j'),
  cycleAgentBackward('cycle_agent_backward', 'alt+shift+k'),
  cycleTabsForward('cycle_tabs_forward', 'ctrl+tab'),
  cycleTabsBackward('cycle_tabs_backward', 'ctrl+shift+tab'),
  closeApp('close_app', 'mod+w'),
  quitApp('quit_app', 'mod+q');

  const ShortcutAction(this.key, this.defaultBinding);

  final String key;
  final String defaultBinding;

  String label(V2Localizations l) => switch (this) {
    newChat => l.shortcutNewConversation,
    refresh => l.shortcutRefreshData,
    focusInput => l.shortcutFocusInput,
    toggleVoiceInput => l.shortcutToggleVoiceInput,
    quickOpen => l.shortcutQuickOpenFiles,
    openSettings => l.shortcutOpenSettings,
    cycleRecentModels => l.shortcutNextRecentModel,
    cycleVariant => l.shortcutNextVariant,
    escape => l.shortcutFocusCloseDrawer,
    cycleAgentForward => l.shortcutNextAgent,
    cycleAgentBackward => l.shortcutPreviousAgent,
    cycleTabsForward => l.shortcutNextTab,
    cycleTabsBackward => l.shortcutPreviousTab,
    closeApp => l.shortcutCloseApp,
    quitApp => l.shortcutQuitApp,
  };

  String description(V2Localizations l) => switch (this) {
    newChat => l.shortcutNewConversationDesc,
    refresh => l.shortcutRefreshDataDesc,
    focusInput => l.shortcutFocusInputDesc,
    toggleVoiceInput => l.shortcutToggleVoiceInputDesc,
    quickOpen => l.shortcutQuickOpenFilesDesc,
    openSettings => l.shortcutOpenSettingsDesc,
    cycleRecentModels => l.shortcutNextRecentModelDesc,
    cycleVariant => l.shortcutNextVariantDesc,
    escape => l.shortcutFocusCloseDrawerDesc,
    cycleAgentForward => l.shortcutNextAgentDesc,
    cycleAgentBackward => l.shortcutPreviousAgentDesc,
    cycleTabsForward => l.shortcutNextTabDesc,
    cycleTabsBackward => l.shortcutPreviousTabDesc,
    closeApp => l.shortcutCloseAppDesc,
    quitApp => l.shortcutQuitAppDesc,
  };

  String group(V2Localizations l) => switch (this) {
    newChat || cycleTabsForward || cycleTabsBackward => l.shortcutGroupSession,
    refresh => l.shortcutGroupGeneral,
    focusInput || toggleVoiceInput => l.shortcutGroupPrompt,
    quickOpen || openSettings || escape => l.shortcutGroupNavigation,
    cycleRecentModels ||
    cycleVariant ||
    cycleAgentForward ||
    cycleAgentBackward => l.shortcutGroupModelAndAgent,
    closeApp || quitApp => l.shortcutGroupApplication,
  };
}
