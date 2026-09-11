import '../../domain/entities/experience_settings.dart';
import '../../l10n/generated/app_localizations.dart';

extension ShortcutDefinitionL10n on ShortcutDefinition {
  String localizedGroup(AppLocalizations l10n) => switch (action) {
        ShortcutAction.newChat => l10n.shortcutGroupSession,
        ShortcutAction.cycleTabsForward ||
        ShortcutAction.cycleTabsBackward => l10n.shortcutGroupSession,
        ShortcutAction.refresh => l10n.shortcutGroupGeneral,
        ShortcutAction.focusInput ||
        ShortcutAction.toggleVoiceInput =>
          l10n.shortcutGroupPrompt,
        ShortcutAction.quickOpen ||
        ShortcutAction.openSettings ||
        ShortcutAction.escape =>
          l10n.shortcutGroupNavigation,
        ShortcutAction.cycleRecentModels ||
        ShortcutAction.cycleVariant ||
        ShortcutAction.cycleAgentForward ||
        ShortcutAction.cycleAgentBackward =>
          l10n.shortcutGroupModelAndAgent,
        ShortcutAction.closeApp ||
        ShortcutAction.quitApp =>
          l10n.shortcutGroupApplication,
      };

  String localizedLabel(AppLocalizations l10n) => switch (action) {
        ShortcutAction.newChat => l10n.shortcutNewConversation,
        ShortcutAction.refresh => l10n.shortcutRefreshData,
        ShortcutAction.focusInput => l10n.shortcutFocusInput,
        ShortcutAction.toggleVoiceInput => l10n.shortcutToggleVoiceInput,
        ShortcutAction.quickOpen => l10n.shortcutQuickOpenFiles,
        ShortcutAction.openSettings => l10n.shortcutOpenSettings,
        ShortcutAction.cycleRecentModels => l10n.shortcutNextRecentModel,
        ShortcutAction.cycleVariant => l10n.shortcutNextVariant,
        ShortcutAction.escape => l10n.shortcutFocusCloseDrawer,
        ShortcutAction.cycleAgentForward => l10n.shortcutNextAgent,
        ShortcutAction.cycleAgentBackward => l10n.shortcutPreviousAgent,
        ShortcutAction.cycleTabsForward => l10n.shortcutNextTab,
        ShortcutAction.cycleTabsBackward => l10n.shortcutPreviousTab,
        ShortcutAction.closeApp => l10n.shortcutCloseApp,
        ShortcutAction.quitApp => l10n.shortcutQuitApp,
      };

  String localizedDescription(AppLocalizations l10n) => switch (action) {
        ShortcutAction.newChat => l10n.shortcutNewConversationDesc,
        ShortcutAction.refresh => l10n.shortcutRefreshDataDesc,
        ShortcutAction.focusInput => l10n.shortcutFocusInputDesc,
        ShortcutAction.toggleVoiceInput =>
          l10n.shortcutToggleVoiceInputDesc,
        ShortcutAction.quickOpen => l10n.shortcutQuickOpenFilesDesc,
        ShortcutAction.openSettings => l10n.shortcutOpenSettingsDesc,
        ShortcutAction.cycleRecentModels =>
          l10n.shortcutNextRecentModelDesc,
        ShortcutAction.cycleVariant => l10n.shortcutNextVariantDesc,
        ShortcutAction.escape => l10n.shortcutFocusCloseDrawerDesc,
        ShortcutAction.cycleAgentForward => l10n.shortcutNextAgentDesc,
        ShortcutAction.cycleAgentBackward =>
          l10n.shortcutPreviousAgentDesc,
        ShortcutAction.cycleTabsForward => l10n.shortcutNextTabDesc,
        ShortcutAction.cycleTabsBackward => l10n.shortcutPreviousTabDesc,
        ShortcutAction.closeApp => l10n.shortcutCloseAppDesc,
        ShortcutAction.quitApp => l10n.shortcutQuitAppDesc,
      };
}
