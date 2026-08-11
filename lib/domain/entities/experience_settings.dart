import 'package:flutter/foundation.dart';

enum NotificationCategory { agent, permissions, errors }

enum SoundCategory { agent, permissions, errors }

enum SoundOption { off, click, alert, systemDefault, systemChoice, customFile }

enum ShortcutAction {
  newChat,
  refresh,
  focusInput,
  toggleVoiceInput,
  quickOpen,
  openSettings,
  cycleRecentModels,
  cycleVariant,
  escape,
  cycleAgentForward,
  cycleAgentBackward,
  closeApp,
  quitApp,
}

enum DesktopPane { conversations, files, utility }

enum AppDensity { extraDense, dense, normal, spacious, extraSpacious }

enum DataSaverLevel { off, standard, aggressive }

enum SessionAttentionPresentation { off, bubble, panel }

/// Size of the Android attention Bubble. Panel keeps a fixed size.
enum SessionAttentionBubbleSize {
  extraSmall,
  small,
  standard,
  large,
  extraLarge,
}

/// Linear factor applied to the Bubble's base dimensions.
///
/// `standard` is 0.7, i.e. about 30% smaller than the original fixed size.
double sessionAttentionBubbleScale(SessionAttentionBubbleSize size) {
  return switch (size) {
    SessionAttentionBubbleSize.extraSmall => 0.5,
    SessionAttentionBubbleSize.small => 0.6,
    SessionAttentionBubbleSize.standard => 0.7,
    SessionAttentionBubbleSize.large => 0.85,
    SessionAttentionBubbleSize.extraLarge => 1.0,
  };
}

String sessionAttentionBubbleSizeKey(SessionAttentionBubbleSize size) =>
    size.name;

SessionAttentionBubbleSize sessionAttentionBubbleSizeFromKey(String value) {
  for (final size in SessionAttentionBubbleSize.values) {
    if (size.name.toLowerCase() == value.toLowerCase()) {
      return size;
    }
  }
  return SessionAttentionBubbleSize.standard;
}

enum ChatRenderMode { live, block }

enum ThemeModeOption { system, light, dark }

enum VisualStyle { classic, refined }

enum OpenCodeThemePreset {
  oc2,
  amoled,
  aura,
  ayu,
  carbonfox,
  catppuccin,
  catppuccinFrappe,
  catppuccinMacchiato,
  cobalt2,
  cursor,
  dracula,
  tokyonight,
  everforest,
  flexoki,
  github,
  gruvbox,
  kanagawa,
  lucentOrng,
  material,
  mercury,
  monokai,
  nightowl,
  nord,
  onedarkPro,
  opencode,
  orng,
  osakaJade,
  palenight,
  rosepine,
  shadesofpurple,
  solarized,
  synthwave84,
  vercel,
  vesper,
  zenburn,
  matrix,
  oneDark,
}

enum SpeechToTextEngine { native, sherpa, moonshine, parakeet, sensevoice }

enum ReadAloudProvider { native, edgeExperimental, openAiCompatible }

enum DesktopCloseBehavior { tray, minimize, close }

enum DesktopWindowChrome { integratedTabs, systemDecoration }

const String kSherpaLanguageSystem = 'system';
const String kMoonshineModelTiny = 'tiny';
const String kMoonshineModelBase = 'base';
const String kParakeetModelDefault = 'parakeet-v3';
const String kSenseVoiceModelDefault = 'sensevoice-2024-07-17';
const String kDefaultOpenAiCompatibleTtsBaseUrl = 'https://api.openai.com/v1';
const String kDefaultOpenAiCompatibleTtsModel = 'gpt-4o-mini-tts';
const String kDefaultReadAloudResponseFormat = 'mp3';

const double kMinSystemFontScale = 0.8;
const double kMaxSystemFontScale = 1.6;
const double kMinChatFontScale = 0.8;
const double kMaxChatFontScale = 1.6;
const double kMinTerminalFontSize = 9.0;
const double kMaxTerminalFontSize = 22.0;
const double kDefaultTerminalFontSize = 13.0;
const Duration kDefaultSyncResumeGracePeriod = Duration(seconds: 5);
const Duration kMaxSyncResumeGracePeriod = Duration(seconds: 30);

double clampSystemFontScale(double value) {
  return value.clamp(kMinSystemFontScale, kMaxSystemFontScale);
}

double clampChatFontScale(double value) {
  return value.clamp(kMinChatFontScale, kMaxChatFontScale);
}

double clampTerminalFontSize(double value) {
  return value.clamp(kMinTerminalFontSize, kMaxTerminalFontSize);
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
    action: ShortcutAction.toggleVoiceInput,
    group: 'Prompt',
    label: 'Toggle voice input',
    description: 'Start or stop speech-to-text in the composer',
    defaultBinding: 'alt+shift+s',
  ),
  ShortcutDefinition(
    action: ShortcutAction.quickOpen,
    group: 'Navigation',
    label: 'Quick open files',
    description: 'Open file quick search',
    defaultBinding: 'mod+p',
  ),
  ShortcutDefinition(
    action: ShortcutAction.openSettings,
    group: 'Navigation',
    label: 'Open settings',
    description: 'Open settings page',
    defaultBinding: 'mod+,',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleRecentModels,
    group: 'Model and agent',
    label: 'Next recent model',
    description: 'Cycle through recently used models',
    defaultBinding: 'mod+m',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleVariant,
    group: 'Model and agent',
    label: 'Next variant',
    description: 'Cycle through available model variants',
    defaultBinding: 'mod+t',
  ),
  ShortcutDefinition(
    action: ShortcutAction.escape,
    group: 'Navigation',
    label: 'Focus/close drawer',
    description: 'Focus composer by default, or close drawer when open',
    defaultBinding: 'escape',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleAgentForward,
    group: 'Model and agent',
    label: 'Next agent',
    description: 'Cycle to next available agent',
    defaultBinding: 'alt+shift+j',
  ),
  ShortcutDefinition(
    action: ShortcutAction.cycleAgentBackward,
    group: 'Model and agent',
    label: 'Previous agent',
    description: 'Cycle to previous available agent',
    defaultBinding: 'alt+shift+k',
  ),
  ShortcutDefinition(
    action: ShortcutAction.closeApp,
    group: 'Application',
    label: 'Close tab/application',
    description:
        'Close the current session tab when available, otherwise soft-close the app',
    defaultBinding: 'mod+w',
  ),
  ShortcutDefinition(
    action: ShortcutAction.quitApp,
    group: 'Application',
    label: 'Quit application',
    description: 'Force-exit the app (bypass soft-close behavior)',
    defaultBinding: 'mod+q',
  ),
];

bool shortcutActionSupportedInRuntime(
  ShortcutAction action, {
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required bool refreshlessRealtimeEnabled,
}) {
  if (isWeb) {
    return switch (action) {
      ShortcutAction.closeApp || ShortcutAction.quitApp => false,
      ShortcutAction.refresh => !refreshlessRealtimeEnabled,
      _ => true,
    };
  }

  return switch (action) {
    ShortcutAction.refresh => !refreshlessRealtimeEnabled,
    ShortcutAction.closeApp ||
    ShortcutAction.quitApp => switch (targetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    },
    _ => true,
  };
}

List<ShortcutAction> shortcutActionsForRuntime({
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required bool refreshlessRealtimeEnabled,
}) {
  return kShortcutDefinitions
      .where(
        (definition) => shortcutActionSupportedInRuntime(
          definition.action,
          isWeb: isWeb,
          targetPlatform: targetPlatform,
          refreshlessRealtimeEnabled: refreshlessRealtimeEnabled,
        ),
      )
      .map((definition) => definition.action)
      .toList(growable: false);
}

List<ShortcutDefinition> shortcutDefinitionsForRuntime({
  required bool isWeb,
  required TargetPlatform targetPlatform,
  required bool refreshlessRealtimeEnabled,
}) {
  final visibleActions = shortcutActionsForRuntime(
    isWeb: isWeb,
    targetPlatform: targetPlatform,
    refreshlessRealtimeEnabled: refreshlessRealtimeEnabled,
  ).toSet();
  return kShortcutDefinitions
      .where((definition) => visibleActions.contains(definition.action))
      .toList(growable: false);
}

String notificationCategoryKey(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.agent => 'agent',
    NotificationCategory.permissions => 'permissions',
    NotificationCategory.errors => 'errors',
  };
}

String openCodeThemePresetKey(OpenCodeThemePreset preset) {
  return switch (preset) {
    OpenCodeThemePreset.oc2 => 'oc-2',
    OpenCodeThemePreset.amoled => 'amoled',
    OpenCodeThemePreset.aura => 'aura',
    OpenCodeThemePreset.ayu => 'ayu',
    OpenCodeThemePreset.carbonfox => 'carbonfox',
    OpenCodeThemePreset.catppuccin => 'catppuccin',
    OpenCodeThemePreset.catppuccinFrappe => 'catppuccin-frappe',
    OpenCodeThemePreset.catppuccinMacchiato => 'catppuccin-macchiato',
    OpenCodeThemePreset.cobalt2 => 'cobalt2',
    OpenCodeThemePreset.cursor => 'cursor',
    OpenCodeThemePreset.dracula => 'dracula',
    OpenCodeThemePreset.tokyonight => 'tokyonight',
    OpenCodeThemePreset.everforest => 'everforest',
    OpenCodeThemePreset.flexoki => 'flexoki',
    OpenCodeThemePreset.github => 'github',
    OpenCodeThemePreset.gruvbox => 'gruvbox',
    OpenCodeThemePreset.kanagawa => 'kanagawa',
    OpenCodeThemePreset.lucentOrng => 'lucent-orng',
    OpenCodeThemePreset.material => 'material',
    OpenCodeThemePreset.mercury => 'mercury',
    OpenCodeThemePreset.monokai => 'monokai',
    OpenCodeThemePreset.nightowl => 'nightowl',
    OpenCodeThemePreset.nord => 'nord',
    OpenCodeThemePreset.onedarkPro => 'onedarkpro',
    OpenCodeThemePreset.opencode => 'opencode',
    OpenCodeThemePreset.orng => 'orng',
    OpenCodeThemePreset.osakaJade => 'osaka-jade',
    OpenCodeThemePreset.palenight => 'palenight',
    OpenCodeThemePreset.rosepine => 'rosepine',
    OpenCodeThemePreset.shadesofpurple => 'shadesofpurple',
    OpenCodeThemePreset.solarized => 'solarized',
    OpenCodeThemePreset.synthwave84 => 'synthwave84',
    OpenCodeThemePreset.vercel => 'vercel',
    OpenCodeThemePreset.vesper => 'vesper',
    OpenCodeThemePreset.zenburn => 'zenburn',
    OpenCodeThemePreset.matrix => 'matrix',
    OpenCodeThemePreset.oneDark => 'one-dark',
  };
}

OpenCodeThemePreset? openCodeThemePresetFromKey(String value) {
  return switch (value) {
    'system' => OpenCodeThemePreset.oc2,
    'oc-1' => OpenCodeThemePreset.oc2,
    'oc-2' => OpenCodeThemePreset.oc2,
    'amoled' => OpenCodeThemePreset.amoled,
    'aura' => OpenCodeThemePreset.aura,
    'ayu' => OpenCodeThemePreset.ayu,
    'carbonfox' => OpenCodeThemePreset.carbonfox,
    'catppuccin' => OpenCodeThemePreset.catppuccin,
    'catppuccin-frappe' => OpenCodeThemePreset.catppuccinFrappe,
    'catppuccin-macchiato' => OpenCodeThemePreset.catppuccinMacchiato,
    'cobalt2' => OpenCodeThemePreset.cobalt2,
    'cursor' => OpenCodeThemePreset.cursor,
    'dracula' => OpenCodeThemePreset.dracula,
    'tokyonight' => OpenCodeThemePreset.tokyonight,
    'everforest' => OpenCodeThemePreset.everforest,
    'flexoki' => OpenCodeThemePreset.flexoki,
    'github' => OpenCodeThemePreset.github,
    'gruvbox' => OpenCodeThemePreset.gruvbox,
    'kanagawa' => OpenCodeThemePreset.kanagawa,
    'lucent-orng' => OpenCodeThemePreset.lucentOrng,
    'material' => OpenCodeThemePreset.material,
    'mercury' => OpenCodeThemePreset.mercury,
    'monokai' => OpenCodeThemePreset.monokai,
    'nightowl' => OpenCodeThemePreset.nightowl,
    'nord' => OpenCodeThemePreset.nord,
    'onedarkpro' => OpenCodeThemePreset.onedarkPro,
    'opencode' => OpenCodeThemePreset.opencode,
    'orng' => OpenCodeThemePreset.orng,
    'osaka-jade' => OpenCodeThemePreset.osakaJade,
    'palenight' => OpenCodeThemePreset.palenight,
    'rosepine' => OpenCodeThemePreset.rosepine,
    'shadesofpurple' => OpenCodeThemePreset.shadesofpurple,
    'solarized' => OpenCodeThemePreset.solarized,
    'synthwave84' => OpenCodeThemePreset.synthwave84,
    'vercel' => OpenCodeThemePreset.vercel,
    'vesper' => OpenCodeThemePreset.vesper,
    'zenburn' => OpenCodeThemePreset.zenburn,
    'matrix' => OpenCodeThemePreset.matrix,
    'one-dark' => OpenCodeThemePreset.oneDark,
    _ => null,
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
    SoundOption.systemDefault => 'system_default',
    SoundOption.systemChoice => 'system_choice',
    SoundOption.customFile => 'custom_file',
  };
}

SoundOption soundOptionFromKey(String value) {
  return switch (value) {
    'click' => SoundOption.click,
    'alert' => SoundOption.alert,
    'system_default' => SoundOption.systemDefault,
    'system_choice' => SoundOption.systemChoice,
    'custom_file' => SoundOption.customFile,
    _ => SoundOption.off,
  };
}

String shortcutActionKey(ShortcutAction action) {
  return switch (action) {
    ShortcutAction.newChat => 'new_chat',
    ShortcutAction.refresh => 'refresh',
    ShortcutAction.focusInput => 'focus_input',
    ShortcutAction.toggleVoiceInput => 'toggle_voice_input',
    ShortcutAction.quickOpen => 'quick_open',
    ShortcutAction.openSettings => 'open_settings',
    ShortcutAction.cycleRecentModels => 'cycle_recent_models',
    ShortcutAction.cycleVariant => 'cycle_variant',
    ShortcutAction.escape => 'escape',
    ShortcutAction.cycleAgentForward => 'cycle_agent_forward',
    ShortcutAction.cycleAgentBackward => 'cycle_agent_backward',
    ShortcutAction.closeApp => 'close_app',
    ShortcutAction.quitApp => 'quit_app',
  };
}

ShortcutAction? shortcutActionFromKey(String value) {
  return switch (value) {
    'new_chat' => ShortcutAction.newChat,
    'refresh' => ShortcutAction.refresh,
    'focus_input' => ShortcutAction.focusInput,
    'toggle_voice_input' => ShortcutAction.toggleVoiceInput,
    'quick_open' => ShortcutAction.quickOpen,
    'open_settings' => ShortcutAction.openSettings,
    'cycle_recent_models' => ShortcutAction.cycleRecentModels,
    'cycle_variant' => ShortcutAction.cycleVariant,
    'escape' => ShortcutAction.escape,
    'cycle_agent_forward' => ShortcutAction.cycleAgentForward,
    'cycle_agent_backward' => ShortcutAction.cycleAgentBackward,
    'close_app' => ShortcutAction.closeApp,
    'quit_app' => ShortcutAction.quitApp,
    _ => null,
  };
}

String desktopPaneKey(DesktopPane pane) {
  return switch (pane) {
    DesktopPane.conversations => 'conversations',
    DesktopPane.files => 'files',
    DesktopPane.utility => 'utility',
  };
}

String desktopCloseBehaviorKey(DesktopCloseBehavior behavior) {
  return switch (behavior) {
    DesktopCloseBehavior.tray => 'tray',
    DesktopCloseBehavior.minimize => 'minimize',
    DesktopCloseBehavior.close => 'close',
  };
}

DesktopCloseBehavior desktopCloseBehaviorFromKey(String value) {
  return switch (value) {
    'minimize' => DesktopCloseBehavior.minimize,
    'close' => DesktopCloseBehavior.close,
    _ => DesktopCloseBehavior.tray,
  };
}

String desktopWindowChromeKey(DesktopWindowChrome chrome) {
  return switch (chrome) {
    DesktopWindowChrome.integratedTabs => 'integrated',
    DesktopWindowChrome.systemDecoration => 'system',
  };
}

DesktopWindowChrome desktopWindowChromeFromKey(String value) {
  return switch (value) {
    'system' => DesktopWindowChrome.systemDecoration,
    _ => DesktopWindowChrome.integratedTabs,
  };
}

DesktopPane? desktopPaneFromKey(String value) {
  return switch (value) {
    'conversations' => DesktopPane.conversations,
    'files' => DesktopPane.files,
    'utility' => DesktopPane.utility,
    _ => null,
  };
}

String appDensityKey(AppDensity density) {
  return switch (density) {
    AppDensity.extraDense => 'extra_dense',
    AppDensity.dense => 'dense',
    AppDensity.normal => 'normal',
    AppDensity.spacious => 'spacious',
    AppDensity.extraSpacious => 'extra_spacious',
  };
}

String themeModeOptionKey(ThemeModeOption mode) {
  return switch (mode) {
    ThemeModeOption.system => 'system',
    ThemeModeOption.light => 'light',
    ThemeModeOption.dark => 'dark',
  };
}

ThemeModeOption themeModeOptionFromKey(String value) {
  return switch (value) {
    'light' => ThemeModeOption.light,
    'dark' => ThemeModeOption.dark,
    _ => ThemeModeOption.system,
  };
}

String visualStyleKey(VisualStyle style) {
  return switch (style) {
    VisualStyle.classic => 'classic',
    VisualStyle.refined => 'refined',
  };
}

VisualStyle visualStyleFromKey(String value) {
  return switch (value.trim().toLowerCase()) {
    'refined' => VisualStyle.refined,
    _ => VisualStyle.classic,
  };
}

String speechToTextEngineKey(SpeechToTextEngine engine) {
  return switch (engine) {
    SpeechToTextEngine.native => 'native',
    SpeechToTextEngine.sherpa => 'sherpa',
    SpeechToTextEngine.moonshine => 'moonshine',
    SpeechToTextEngine.parakeet => 'parakeet',
    SpeechToTextEngine.sensevoice => 'sensevoice',
  };
}

SpeechToTextEngine speechToTextEngineFromKey(String value) {
  return switch (value) {
    'sherpa' => SpeechToTextEngine.sherpa,
    'moonshine' => SpeechToTextEngine.moonshine,
    'parakeet' => SpeechToTextEngine.parakeet,
    'sensevoice' => SpeechToTextEngine.sensevoice,
    _ => SpeechToTextEngine.native,
  };
}

String readAloudProviderKey(ReadAloudProvider provider) {
  return switch (provider) {
    ReadAloudProvider.native => 'native',
    ReadAloudProvider.edgeExperimental => 'edge_experimental',
    ReadAloudProvider.openAiCompatible => 'openai_compatible',
  };
}

ReadAloudProvider readAloudProviderFromKey(String value) {
  return switch (value.trim().toLowerCase()) {
    'edge' ||
    'edge_experimental' ||
    'microsoft_edge' ||
    'microsoft-edge' => ReadAloudProvider.edgeExperimental,
    'openai' ||
    'openai_compatible' ||
    'openai-compatible' ||
    'openai_compat' => ReadAloudProvider.openAiCompatible,
    _ => ReadAloudProvider.native,
  };
}

AppDensity appDensityFromKey(String value) {
  return switch (value) {
    'extra_dense' => AppDensity.extraDense,
    'dense' => AppDensity.dense,
    'spacious' => AppDensity.spacious,
    'extra_spacious' => AppDensity.extraSpacious,
    _ => AppDensity.normal,
  };
}

String dataSaverLevelKey(DataSaverLevel level) {
  return switch (level) {
    DataSaverLevel.off => 'off',
    DataSaverLevel.standard => 'standard',
    DataSaverLevel.aggressive => 'aggressive',
  };
}

String sessionAttentionPresentationKey(SessionAttentionPresentation value) {
  return switch (value) {
    SessionAttentionPresentation.off => 'off',
    SessionAttentionPresentation.bubble => 'bubble',
    SessionAttentionPresentation.panel => 'panel',
  };
}

SessionAttentionPresentation sessionAttentionPresentationFromKey(String value) {
  return switch (value.trim().toLowerCase()) {
    'bubble' => SessionAttentionPresentation.bubble,
    'panel' => SessionAttentionPresentation.panel,
    _ => SessionAttentionPresentation.off,
  };
}

DataSaverLevel dataSaverLevelFromKey(String value) {
  return switch (value.trim().toLowerCase()) {
    'aggressive' => DataSaverLevel.aggressive,
    'standard' => DataSaverLevel.standard,
    'on' || 'enabled' || 'true' => DataSaverLevel.standard,
    _ => DataSaverLevel.off,
  };
}

String chatRenderModeKey(ChatRenderMode mode) {
  return switch (mode) {
    ChatRenderMode.live => 'live',
    ChatRenderMode.block => 'block',
  };
}

ChatRenderMode chatRenderModeFromKey(String value) {
  final key = value.trim().toLowerCase();
  return switch (key) {
    'block' => ChatRenderMode.block,
    // Historical aliases from early drafts of the setting key.
    'blocks' => ChatRenderMode.block,
    'sorted' => ChatRenderMode.block,
    _ => ChatRenderMode.live,
  };
}

String _normalizeShortcutBinding(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('command', 'meta')
      .replaceAll('cmd', 'meta')
      .replaceAll('control', 'ctrl')
      .replaceAll('option', 'alt');
}

String _migrateShortcutBinding(ShortcutAction action, String value) {
  final normalized = _normalizeShortcutBinding(value);
  return switch (action) {
    ShortcutAction.cycleAgentForward
        when normalized == 'mod+j' || normalized == 'ctrl+j' =>
      'alt+shift+j',
    ShortcutAction.cycleAgentBackward
        when normalized == 'mod+shift+j' || normalized == 'ctrl+shift+j' =>
      'alt+shift+k',
    _ => normalized,
  };
}

Duration clampSyncResumeGracePeriod(Duration value) {
  if (value.isNegative) {
    return Duration.zero;
  }
  if (value > kMaxSyncResumeGracePeriod) {
    return kMaxSyncResumeGracePeriod;
  }
  return value;
}

class ExperienceSettings {
  factory ExperienceSettings.defaults() {
    final defaultSpeechEngine =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux
        ? SpeechToTextEngine.parakeet
        : SpeechToTextEngine.native;
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
        SoundCategory.agent: SoundOption.systemDefault,
        SoundCategory.permissions: SoundOption.systemDefault,
        SoundCategory.errors: SoundOption.systemDefault,
      },
      notifyOnlyWhenBackground: const <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      },
      notifyOnlyWhenAnotherSession: const <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      },
      soundOnlyWhenBackground: const <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      },
      soundOnlyWhenAnotherSession: const <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      },
      soundSources: const <SoundCategory, String>{},
      soundLabels: const <SoundCategory, String>{},
      shortcuts: shortcuts,
      desktopPanes: const <DesktopPane, bool>{
        DesktopPane.conversations: true,
        DesktopPane.files: true,
        DesktopPane.utility: true,
      },
      desktopPaneWidths: const <DesktopPane, double>{},
      terminalPanelVisible: false,
      terminalPanelHeight: 240,
      terminalPanelMaximized: false,
      appDensity: AppDensity.normal,
      chatRenderMode: ChatRenderMode.live,
      showThinkingBubbles: true,
      showToolCallBubbles: true,
      showTaskList: true,
      showReviewChanges: true,
      showRecentSessions: true,
      showSessionTabsOverride: null,
      sessionTabsGestureHintDismissed: false,
      taskListCollapsed: false,
      showComposerTips: true,
      showMathRendering: true,
      composerSpellCheckEnabled: true,
      composerAutoApprovePermissions: true,
      desktopCloseBehavior: DesktopCloseBehavior.tray,
      desktopWindowChrome: DesktopWindowChrome.integratedTabs,
      editorAutosaveEnabled: false,
      sessionAttentionBubbleSize: SessionAttentionBubbleSize.standard,
      dataSaverEnabled: true,
      dataSaverLevel: DataSaverLevel.standard,
      androidBackgroundAlertsEnabled: true,
      sessionAttentionPresentation: SessionAttentionPresentation.off,
      keepMobileRealtimeForShortPeriod: true,
      syncResumeGracePeriod: kDefaultSyncResumeGracePeriod,
      enableExperimentalMultiDeviceSync: false,
      loggingEnabled: false,
      performanceLoggingEnabled: false,
      themeMode: ThemeModeOption.system,
      visualStyle: VisualStyle.refined,
      localeCode: null,
      themePreset: null,
      useAmoledDark: false,
      useDynamicColor: true,
      customColorSeed: null,
      contrastLevel: 0.0,
      speechToTextEngine: defaultSpeechEngine,
      speechSilenceTimeoutSeconds: 5,
      sherpaLanguageCode: kSherpaLanguageSystem,
      moonshineModelId: kMoonshineModelTiny,
      parakeetModelId: kParakeetModelDefault,
      senseVoiceModelId: kSenseVoiceModelDefault,
      pendingPostOnboardingChatTour: false,
      checkUpdatesOnOpen: true,
      readAloudEnabled: true,
      readAloudProvider: ReadAloudProvider.native,
      readAloudRate: 0.5,
      readAloudPitch: 1.0,
      readAloudVoice: null,
      readAloudVoiceId: null,
      readAloudVoiceLocale: null,
      readAloudModel: kDefaultOpenAiCompatibleTtsModel,
      readAloudBaseUrl: kDefaultOpenAiCompatibleTtsBaseUrl,
      readAloudResponseFormat: kDefaultReadAloudResponseFormat,
      systemFontScale: 1.0,
      chatFontScale: 1.0,
      terminalFontSize: kDefaultTerminalFontSize,
    );
  }
  const ExperienceSettings({
    required this.notifications,
    required this.sounds,
    required this.notifyOnlyWhenBackground,
    required this.notifyOnlyWhenAnotherSession,
    required this.soundOnlyWhenBackground,
    required this.soundOnlyWhenAnotherSession,
    required this.soundSources,
    required this.soundLabels,
    required this.shortcuts,
    required this.desktopPanes,
    this.desktopPaneWidths = const <DesktopPane, double>{},
    this.terminalPanelVisible = false,
    this.terminalPanelHeight = 240,
    this.terminalPanelMaximized = false,
    required this.appDensity,
    required this.chatRenderMode,
    required this.showThinkingBubbles,
    required this.showToolCallBubbles,
    required this.showTaskList,
    required this.showReviewChanges,
    required this.showRecentSessions,
    this.showSessionTabsOverride,
    this.sessionTabsGestureHintDismissed = false,
    required this.taskListCollapsed,
    required this.showComposerTips,
    required this.showMathRendering,
    this.composerSpellCheckEnabled = true,
    required this.composerAutoApprovePermissions,
    required this.desktopCloseBehavior,
    this.desktopWindowChrome = DesktopWindowChrome.integratedTabs,
    this.editorAutosaveEnabled = false,
    this.sessionAttentionBubbleSize = SessionAttentionBubbleSize.standard,
    required this.dataSaverEnabled,
    required this.dataSaverLevel,
    required this.androidBackgroundAlertsEnabled,
    this.sessionAttentionPresentation = SessionAttentionPresentation.off,
    required this.keepMobileRealtimeForShortPeriod,
    required this.syncResumeGracePeriod,
    this.enableExperimentalMultiDeviceSync = false,
    this.loggingEnabled = false,
    this.performanceLoggingEnabled = false,
    this.themeMode = ThemeModeOption.system,
    this.visualStyle = VisualStyle.refined,
    this.localeCode,
    this.themePreset,
    this.useAmoledDark = false,
    this.useDynamicColor = true,
    this.customColorSeed,
    this.contrastLevel = 0.0,
    this.speechToTextEngine = SpeechToTextEngine.native,
    this.speechSilenceTimeoutSeconds = 5,
    this.sherpaLanguageCode = kSherpaLanguageSystem,
    this.moonshineModelId = kMoonshineModelTiny,
    this.parakeetModelId = kParakeetModelDefault,
    this.senseVoiceModelId = kSenseVoiceModelDefault,
    this.skipOnboardingWizard = false,
    this.pendingPostOnboardingChatTour = false,
    this.checkUpdatesOnOpen = true,
    this.readAloudEnabled = true,
    this.readAloudProvider = ReadAloudProvider.native,
    this.readAloudRate = 0.5,
    this.readAloudPitch = 1.0,
    this.readAloudVoice,
    this.readAloudVoiceId,
    this.readAloudVoiceLocale,
    this.readAloudModel = kDefaultOpenAiCompatibleTtsModel,
    this.readAloudBaseUrl = kDefaultOpenAiCompatibleTtsBaseUrl,
    this.readAloudResponseFormat = kDefaultReadAloudResponseFormat,
    this.systemFontScale = 1.0,
    this.chatFontScale = 1.0,
    this.terminalFontSize = kDefaultTerminalFontSize,
  });

  final Map<NotificationCategory, bool> notifications;
  final Map<SoundCategory, SoundOption> sounds;
  final Map<NotificationCategory, bool> notifyOnlyWhenBackground;
  final Map<NotificationCategory, bool> notifyOnlyWhenAnotherSession;
  final Map<NotificationCategory, bool> soundOnlyWhenBackground;
  final Map<NotificationCategory, bool> soundOnlyWhenAnotherSession;
  final Map<SoundCategory, String> soundSources;
  final Map<SoundCategory, String> soundLabels;
  final Map<ShortcutAction, String> shortcuts;
  final Map<DesktopPane, bool> desktopPanes;
  final Map<DesktopPane, double> desktopPaneWidths;
  final bool terminalPanelVisible;
  final double terminalPanelHeight;
  final bool terminalPanelMaximized;
  final AppDensity appDensity;
  final ChatRenderMode chatRenderMode;
  final bool showThinkingBubbles;
  final bool showToolCallBubbles;
  final bool showTaskList;
  final bool showReviewChanges;
  final bool showRecentSessions;
  final bool? showSessionTabsOverride;
  final bool sessionTabsGestureHintDismissed;
  final bool taskListCollapsed;
  final bool showComposerTips;
  final bool showMathRendering;
  final bool composerSpellCheckEnabled;
  final bool composerAutoApprovePermissions;
  final DesktopCloseBehavior desktopCloseBehavior;
  final DesktopWindowChrome desktopWindowChrome;

  /// Autosave in the file micro editor. Global: applies to every open tab.
  final bool editorAutosaveEnabled;
  final SessionAttentionBubbleSize sessionAttentionBubbleSize;
  final bool dataSaverEnabled;
  final DataSaverLevel dataSaverLevel;
  final bool androidBackgroundAlertsEnabled;
  final SessionAttentionPresentation sessionAttentionPresentation;
  final bool keepMobileRealtimeForShortPeriod;
  final Duration syncResumeGracePeriod;
  final bool enableExperimentalMultiDeviceSync;
  final bool loggingEnabled;
  final bool performanceLoggingEnabled;
  final ThemeModeOption themeMode;
  final VisualStyle visualStyle;
  final String? localeCode;
  final OpenCodeThemePreset? themePreset;
  final bool useAmoledDark;
  final bool useDynamicColor;
  final int? customColorSeed;
  final double contrastLevel;
  final SpeechToTextEngine speechToTextEngine;
  final int speechSilenceTimeoutSeconds;
  final String sherpaLanguageCode;
  final String moonshineModelId;
  final String parakeetModelId;
  final String senseVoiceModelId;
  final bool skipOnboardingWizard;
  final bool pendingPostOnboardingChatTour;
  final bool checkUpdatesOnOpen;
  final bool readAloudEnabled;
  final ReadAloudProvider readAloudProvider;
  final double readAloudRate;
  final double readAloudPitch;
  // Legacy native voice key. New provider-aware code should use
  // readAloudVoiceId/readAloudVoiceLocale and keep this as migration input.
  final String? readAloudVoice;
  final String? readAloudVoiceId;
  final String? readAloudVoiceLocale;
  final String readAloudModel;
  final String readAloudBaseUrl;
  final String readAloudResponseFormat;
  final double systemFontScale;
  final double chatFontScale;
  final double terminalFontSize;

  ExperienceSettings copyWith({
    Map<NotificationCategory, bool>? notifications,
    Map<SoundCategory, SoundOption>? sounds,
    Map<NotificationCategory, bool>? notifyOnlyWhenBackground,
    Map<NotificationCategory, bool>? notifyOnlyWhenAnotherSession,
    Map<NotificationCategory, bool>? soundOnlyWhenBackground,
    Map<NotificationCategory, bool>? soundOnlyWhenAnotherSession,
    Map<SoundCategory, String>? soundSources,
    Map<SoundCategory, String>? soundLabels,
    Map<ShortcutAction, String>? shortcuts,
    Map<DesktopPane, bool>? desktopPanes,
    Map<DesktopPane, double>? desktopPaneWidths,
    bool? terminalPanelVisible,
    double? terminalPanelHeight,
    bool? terminalPanelMaximized,
    AppDensity? appDensity,
    ChatRenderMode? chatRenderMode,
    bool? showThinkingBubbles,
    bool? showToolCallBubbles,
    bool? showTaskList,
    bool? showReviewChanges,
    bool? showRecentSessions,
    bool? Function()? showSessionTabsOverride,
    bool? sessionTabsGestureHintDismissed,
    bool? taskListCollapsed,
    bool? showComposerTips,
    bool? showMathRendering,
    bool? composerSpellCheckEnabled,
    bool? composerAutoApprovePermissions,
    DesktopCloseBehavior? desktopCloseBehavior,
    DesktopWindowChrome? desktopWindowChrome,
    bool? editorAutosaveEnabled,
    SessionAttentionBubbleSize? sessionAttentionBubbleSize,
    bool? dataSaverEnabled,
    DataSaverLevel? dataSaverLevel,
    bool? androidBackgroundAlertsEnabled,
    SessionAttentionPresentation? sessionAttentionPresentation,
    bool? keepMobileRealtimeForShortPeriod,
    Duration? syncResumeGracePeriod,
    bool? enableExperimentalMultiDeviceSync,
    bool? loggingEnabled,
    bool? performanceLoggingEnabled,
    ThemeModeOption? themeMode,
    VisualStyle? visualStyle,
    String? Function()? localeCode,
    OpenCodeThemePreset? Function()? themePreset,
    bool? useAmoledDark,
    bool? useDynamicColor,
    int? Function()? customColorSeed,
    double? contrastLevel,
    SpeechToTextEngine? speechToTextEngine,
    int? speechSilenceTimeoutSeconds,
    String? sherpaLanguageCode,
    String? moonshineModelId,
    String? parakeetModelId,
    String? senseVoiceModelId,
    bool? skipOnboardingWizard,
    bool? pendingPostOnboardingChatTour,
    bool? checkUpdatesOnOpen,
    bool? readAloudEnabled,
    ReadAloudProvider? readAloudProvider,
    double? readAloudRate,
    double? readAloudPitch,
    String? Function()? readAloudVoice,
    String? Function()? readAloudVoiceId,
    String? Function()? readAloudVoiceLocale,
    String? readAloudModel,
    String? readAloudBaseUrl,
    String? readAloudResponseFormat,
    double? systemFontScale,
    double? chatFontScale,
    double? terminalFontSize,
  }) {
    final nextDataSaverLevel =
        dataSaverLevel ??
        (dataSaverEnabled == null
            ? this.dataSaverLevel
            : (dataSaverEnabled
                  ? DataSaverLevel.standard
                  : DataSaverLevel.off));
    return ExperienceSettings(
      notifications: notifications ?? this.notifications,
      sounds: sounds ?? this.sounds,
      notifyOnlyWhenBackground:
          notifyOnlyWhenBackground ?? this.notifyOnlyWhenBackground,
      notifyOnlyWhenAnotherSession:
          notifyOnlyWhenAnotherSession ?? this.notifyOnlyWhenAnotherSession,
      soundOnlyWhenBackground:
          soundOnlyWhenBackground ?? this.soundOnlyWhenBackground,
      soundOnlyWhenAnotherSession:
          soundOnlyWhenAnotherSession ?? this.soundOnlyWhenAnotherSession,
      soundSources: soundSources ?? this.soundSources,
      soundLabels: soundLabels ?? this.soundLabels,
      shortcuts: shortcuts ?? this.shortcuts,
      desktopPanes: desktopPanes ?? this.desktopPanes,
      desktopPaneWidths: desktopPaneWidths ?? this.desktopPaneWidths,
      terminalPanelVisible: terminalPanelVisible ?? this.terminalPanelVisible,
      terminalPanelHeight: terminalPanelHeight ?? this.terminalPanelHeight,
      terminalPanelMaximized:
          terminalPanelMaximized ?? this.terminalPanelMaximized,
      appDensity: appDensity ?? this.appDensity,
      chatRenderMode: chatRenderMode ?? this.chatRenderMode,
      showThinkingBubbles: showThinkingBubbles ?? this.showThinkingBubbles,
      showToolCallBubbles: showToolCallBubbles ?? this.showToolCallBubbles,
      showTaskList: showTaskList ?? this.showTaskList,
      showReviewChanges: showReviewChanges ?? this.showReviewChanges,
      showRecentSessions: showRecentSessions ?? this.showRecentSessions,
      showSessionTabsOverride: showSessionTabsOverride != null
          ? showSessionTabsOverride()
          : this.showSessionTabsOverride,
      sessionTabsGestureHintDismissed:
          sessionTabsGestureHintDismissed ??
          this.sessionTabsGestureHintDismissed,
      taskListCollapsed: taskListCollapsed ?? this.taskListCollapsed,
      showComposerTips: showComposerTips ?? this.showComposerTips,
      showMathRendering: showMathRendering ?? this.showMathRendering,
      composerSpellCheckEnabled:
          composerSpellCheckEnabled ?? this.composerSpellCheckEnabled,
      composerAutoApprovePermissions:
          composerAutoApprovePermissions ?? this.composerAutoApprovePermissions,
      desktopCloseBehavior: desktopCloseBehavior ?? this.desktopCloseBehavior,
      desktopWindowChrome: desktopWindowChrome ?? this.desktopWindowChrome,
      editorAutosaveEnabled:
          editorAutosaveEnabled ?? this.editorAutosaveEnabled,
      sessionAttentionBubbleSize:
          sessionAttentionBubbleSize ?? this.sessionAttentionBubbleSize,
      dataSaverEnabled: nextDataSaverLevel != DataSaverLevel.off,
      dataSaverLevel: nextDataSaverLevel,
      androidBackgroundAlertsEnabled:
          androidBackgroundAlertsEnabled ?? this.androidBackgroundAlertsEnabled,
      sessionAttentionPresentation:
          sessionAttentionPresentation ?? this.sessionAttentionPresentation,
      keepMobileRealtimeForShortPeriod:
          keepMobileRealtimeForShortPeriod ??
          this.keepMobileRealtimeForShortPeriod,
      syncResumeGracePeriod: clampSyncResumeGracePeriod(
        syncResumeGracePeriod ?? this.syncResumeGracePeriod,
      ),
      enableExperimentalMultiDeviceSync:
          enableExperimentalMultiDeviceSync ??
          this.enableExperimentalMultiDeviceSync,
      loggingEnabled: loggingEnabled ?? this.loggingEnabled,
      performanceLoggingEnabled:
          performanceLoggingEnabled ?? this.performanceLoggingEnabled,
      themeMode: themeMode ?? this.themeMode,
      visualStyle: visualStyle ?? this.visualStyle,
      localeCode: localeCode != null ? localeCode() : this.localeCode,
      themePreset: themePreset != null ? themePreset() : this.themePreset,
      useAmoledDark: useAmoledDark ?? this.useAmoledDark,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      customColorSeed: customColorSeed != null
          ? customColorSeed()
          : this.customColorSeed,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      speechToTextEngine: speechToTextEngine ?? this.speechToTextEngine,
      speechSilenceTimeoutSeconds:
          speechSilenceTimeoutSeconds ?? this.speechSilenceTimeoutSeconds,
      sherpaLanguageCode: sherpaLanguageCode ?? this.sherpaLanguageCode,
      moonshineModelId: moonshineModelId ?? this.moonshineModelId,
      parakeetModelId: parakeetModelId ?? this.parakeetModelId,
      senseVoiceModelId: senseVoiceModelId ?? this.senseVoiceModelId,
      skipOnboardingWizard: skipOnboardingWizard ?? this.skipOnboardingWizard,
      pendingPostOnboardingChatTour:
          pendingPostOnboardingChatTour ?? this.pendingPostOnboardingChatTour,
      checkUpdatesOnOpen: checkUpdatesOnOpen ?? this.checkUpdatesOnOpen,
      readAloudEnabled: readAloudEnabled ?? this.readAloudEnabled,
      readAloudProvider: readAloudProvider ?? this.readAloudProvider,
      readAloudRate: readAloudRate ?? this.readAloudRate,
      readAloudPitch: readAloudPitch ?? this.readAloudPitch,
      readAloudVoice: readAloudVoice != null
          ? readAloudVoice()
          : this.readAloudVoice,
      readAloudVoiceId: readAloudVoiceId != null
          ? readAloudVoiceId()
          : this.readAloudVoiceId,
      readAloudVoiceLocale: readAloudVoiceLocale != null
          ? readAloudVoiceLocale()
          : this.readAloudVoiceLocale,
      readAloudModel: readAloudModel ?? this.readAloudModel,
      readAloudBaseUrl: readAloudBaseUrl ?? this.readAloudBaseUrl,
      readAloudResponseFormat:
          readAloudResponseFormat ?? this.readAloudResponseFormat,
      systemFontScale: systemFontScale ?? this.systemFontScale,
      chatFontScale: chatFontScale ?? this.chatFontScale,
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
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
      'notifyOnlyWhenBackground': <String, bool>{
        for (final entry in notifyOnlyWhenBackground.entries)
          notificationCategoryKey(entry.key): entry.value,
      },
      'notifyOnlyWhenAnotherSession': <String, bool>{
        for (final entry in notifyOnlyWhenAnotherSession.entries)
          notificationCategoryKey(entry.key): entry.value,
      },
      'soundOnlyWhenBackground': <String, bool>{
        for (final entry in soundOnlyWhenBackground.entries)
          notificationCategoryKey(entry.key): entry.value,
      },
      'soundOnlyWhenAnotherSession': <String, bool>{
        for (final entry in soundOnlyWhenAnotherSession.entries)
          notificationCategoryKey(entry.key): entry.value,
      },
      'soundSources': <String, String>{
        for (final entry in soundSources.entries)
          soundCategoryKey(entry.key): entry.value,
      },
      'soundLabels': <String, String>{
        for (final entry in soundLabels.entries)
          soundCategoryKey(entry.key): entry.value,
      },
      'shortcuts': <String, String>{
        for (final entry in shortcuts.entries)
          shortcutActionKey(entry.key): entry.value,
      },
      'desktopPanes': <String, bool>{
        for (final entry in desktopPanes.entries)
          desktopPaneKey(entry.key): entry.value,
      },
      if (desktopPaneWidths.isNotEmpty)
        'desktopPaneWidths': <String, double>{
          for (final entry in desktopPaneWidths.entries)
            desktopPaneKey(entry.key): entry.value,
        },
      'terminalPanelVisible': terminalPanelVisible,
      'terminalPanelHeight': terminalPanelHeight,
      'terminalPanelMaximized': terminalPanelMaximized,
      'appDensity': appDensityKey(appDensity),
      'chatRenderMode': chatRenderModeKey(chatRenderMode),
      'showThinkingBubbles': showThinkingBubbles,
      'showToolCallBubbles': showToolCallBubbles,
      'showTaskList': showTaskList,
      'showReviewChanges': showReviewChanges,
      'showRecentSessions': showRecentSessions,
      if (showSessionTabsOverride != null)
        'showSessionTabsOverride': showSessionTabsOverride,
      'sessionTabsGestureHintDismissed': sessionTabsGestureHintDismissed,
      'taskListCollapsed': taskListCollapsed,
      'showComposerTips': showComposerTips,
      'showMathRendering': showMathRendering,
      'composerSpellCheckEnabled': composerSpellCheckEnabled,
      'composerAutoApprovePermissions': composerAutoApprovePermissions,
      'desktopCloseBehavior': desktopCloseBehaviorKey(desktopCloseBehavior),
      'desktopWindowChrome': desktopWindowChromeKey(desktopWindowChrome),
      'editorAutosaveEnabled': editorAutosaveEnabled,
      'sessionAttentionBubbleSize': sessionAttentionBubbleSizeKey(
        sessionAttentionBubbleSize,
      ),
      'dataSaverEnabled': dataSaverEnabled,
      'dataSaverLevel': dataSaverLevelKey(dataSaverLevel),
      'keepDesktopRunningInTray':
          desktopCloseBehavior != DesktopCloseBehavior.close,
      'androidBackgroundAlertsEnabled': androidBackgroundAlertsEnabled,
      'sessionAttentionPresentation': sessionAttentionPresentationKey(
        sessionAttentionPresentation,
      ),
      'keepMobileRealtimeForShortPeriod': keepMobileRealtimeForShortPeriod,
      'syncResumeGracePeriodMs': syncResumeGracePeriod.inMilliseconds,
      'enableExperimentalMultiDeviceSync': enableExperimentalMultiDeviceSync,
      'loggingEnabled': loggingEnabled,
      'performanceLoggingEnabled': performanceLoggingEnabled,
      'themeMode': themeModeOptionKey(themeMode),
      'visualStyle': visualStyleKey(visualStyle),
      if (localeCode != null) 'localeCode': localeCode,
      if (themePreset != null)
        'themePreset': openCodeThemePresetKey(themePreset!),
      'useAmoledDark': useAmoledDark,
      'useDynamicColor': useDynamicColor,
      if (customColorSeed != null) 'customColorSeed': customColorSeed,
      'contrastLevel': contrastLevel,
      'speechToTextEngine': speechToTextEngineKey(speechToTextEngine),
      'speechSilenceTimeoutSeconds': speechSilenceTimeoutSeconds,
      'sherpaLanguageCode': sherpaLanguageCode,
      'moonshineModelId': moonshineModelId,
      'parakeetModelId': parakeetModelId,
      'senseVoiceModelId': senseVoiceModelId,
      'skipOnboardingWizard': skipOnboardingWizard,
      'pendingPostOnboardingChatTour': pendingPostOnboardingChatTour,
      'checkUpdatesOnOpen': checkUpdatesOnOpen,
      'readAloudEnabled': readAloudEnabled,
      'readAloudProvider': readAloudProviderKey(readAloudProvider),
      'readAloudRate': readAloudRate,
      'readAloudPitch': readAloudPitch,
      if (readAloudVoice != null) 'readAloudVoice': readAloudVoice,
      if (readAloudVoiceId != null) 'readAloudVoiceId': readAloudVoiceId,
      if (readAloudVoiceLocale != null)
        'readAloudVoiceLocale': readAloudVoiceLocale,
      'readAloudModel': readAloudModel,
      'readAloudBaseUrl': readAloudBaseUrl,
      'readAloudResponseFormat': readAloudResponseFormat,
      'systemFontScale': systemFontScale,
      'chatFontScale': chatFontScale,
      'terminalFontSize': terminalFontSize,
    };
  }

  static ExperienceSettings fromJson(Map<String, dynamic> json) {
    final defaults = ExperienceSettings.defaults();

    final notifications = Map<NotificationCategory, bool>.from(
      defaults.notifications,
    );
    final sounds = Map<SoundCategory, SoundOption>.from(defaults.sounds);
    final notifyOnlyWhenBackground = Map<NotificationCategory, bool>.from(
      defaults.notifyOnlyWhenBackground,
    );
    final notifyOnlyWhenAnotherSession = Map<NotificationCategory, bool>.from(
      defaults.notifyOnlyWhenAnotherSession,
    );
    final soundOnlyWhenBackground = Map<NotificationCategory, bool>.from(
      defaults.soundOnlyWhenBackground,
    );
    final soundOnlyWhenAnotherSession = Map<NotificationCategory, bool>.from(
      defaults.soundOnlyWhenAnotherSession,
    );
    final soundSources = Map<SoundCategory, String>.from(defaults.soundSources);
    final soundLabels = Map<SoundCategory, String>.from(defaults.soundLabels);
    final shortcuts = Map<ShortcutAction, String>.from(defaults.shortcuts);
    final desktopPanes = Map<DesktopPane, bool>.from(defaults.desktopPanes);
    final desktopPaneWidths = <DesktopPane, double>{};
    var terminalPanelVisible = defaults.terminalPanelVisible;
    var terminalPanelHeight = defaults.terminalPanelHeight;
    var terminalPanelMaximized = defaults.terminalPanelMaximized;
    var appDensity = defaults.appDensity;
    var chatRenderMode = defaults.chatRenderMode;
    var showThinkingBubbles = defaults.showThinkingBubbles;
    var showToolCallBubbles = defaults.showToolCallBubbles;
    var showTaskList = defaults.showTaskList;
    var showReviewChanges = defaults.showReviewChanges;
    var showRecentSessions = defaults.showRecentSessions;
    var showSessionTabsOverride = defaults.showSessionTabsOverride;
    var sessionTabsGestureHintDismissed =
        defaults.sessionTabsGestureHintDismissed;
    var taskListCollapsed = defaults.taskListCollapsed;
    var showComposerTips = defaults.showComposerTips;
    var showMathRendering = defaults.showMathRendering;
    var composerSpellCheckEnabled = defaults.composerSpellCheckEnabled;
    var composerAutoApprovePermissions =
        defaults.composerAutoApprovePermissions;
    var desktopCloseBehavior = defaults.desktopCloseBehavior;
    var desktopWindowChrome = defaults.desktopWindowChrome;
    var editorAutosaveEnabled = defaults.editorAutosaveEnabled;
    var sessionAttentionBubbleSize = defaults.sessionAttentionBubbleSize;
    var dataSaverEnabled = defaults.dataSaverEnabled;
    var dataSaverLevel = defaults.dataSaverLevel;
    var androidBackgroundAlertsEnabled =
        defaults.androidBackgroundAlertsEnabled;
    var sessionAttentionPresentation = defaults.sessionAttentionPresentation;
    var keepMobileRealtimeForShortPeriod =
        defaults.keepMobileRealtimeForShortPeriod;
    var syncResumeGracePeriod = defaults.syncResumeGracePeriod;
    var enableExperimentalMultiDeviceSync =
        defaults.enableExperimentalMultiDeviceSync;
    var loggingEnabled = defaults.loggingEnabled;
    var performanceLoggingEnabled = defaults.performanceLoggingEnabled;
    var speechToTextEngine = defaults.speechToTextEngine;
    var speechSilenceTimeoutSeconds = defaults.speechSilenceTimeoutSeconds;
    var sherpaLanguageCode = defaults.sherpaLanguageCode;
    var moonshineModelId = defaults.moonshineModelId;
    var parakeetModelId = defaults.parakeetModelId;
    var senseVoiceModelId = defaults.senseVoiceModelId;
    var readAloudEnabled = defaults.readAloudEnabled;
    var readAloudProvider = defaults.readAloudProvider;
    var readAloudRate = defaults.readAloudRate;
    var readAloudPitch = defaults.readAloudPitch;
    var readAloudVoice = defaults.readAloudVoice;
    var readAloudVoiceId = defaults.readAloudVoiceId;
    var readAloudVoiceLocale = defaults.readAloudVoiceLocale;
    var readAloudModel = defaults.readAloudModel;
    var readAloudBaseUrl = defaults.readAloudBaseUrl;
    var readAloudResponseFormat = defaults.readAloudResponseFormat;
    var systemFontScale = defaults.systemFontScale;
    var chatFontScale = defaults.chatFontScale;
    var terminalFontSize = defaults.terminalFontSize;

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

    void parseNotificationRule(
      String jsonKey,
      Map<NotificationCategory, bool> target,
    ) {
      final value = json[jsonKey];
      if (value is! Map) {
        return;
      }
      for (final entry in value.entries) {
        final category = notificationCategoryFromKey(entry.key.toString());
        if (category == null) {
          continue;
        }
        target[category] = entry.value == true;
      }
    }

    parseNotificationRule('notifyOnlyWhenBackground', notifyOnlyWhenBackground);
    parseNotificationRule(
      'notifyOnlyWhenAnotherSession',
      notifyOnlyWhenAnotherSession,
    );
    parseNotificationRule('soundOnlyWhenBackground', soundOnlyWhenBackground);
    parseNotificationRule(
      'soundOnlyWhenAnotherSession',
      soundOnlyWhenAnotherSession,
    );

    void parseSoundStringMap(
      String jsonKey,
      Map<SoundCategory, String> target,
    ) {
      final value = json[jsonKey];
      if (value is! Map) {
        return;
      }
      for (final entry in value.entries) {
        final category = soundCategoryFromKey(entry.key.toString());
        final mapped = entry.value.toString().trim();
        if (category == null || mapped.isEmpty) {
          continue;
        }
        target[category] = mapped;
      }
    }

    parseSoundStringMap('soundSources', soundSources);
    parseSoundStringMap('soundLabels', soundLabels);

    final shortcutsJson = json['shortcuts'];
    if (shortcutsJson is Map) {
      for (final entry in shortcutsJson.entries) {
        final action = shortcutActionFromKey(entry.key.toString());
        if (action == null) {
          continue;
        }
        final value = _migrateShortcutBinding(action, entry.value.toString());
        if (value.isNotEmpty) {
          shortcuts[action] = value;
        }
      }
    }

    final desktopPanesJson = json['desktopPanes'];
    if (desktopPanesJson is Map) {
      for (final entry in desktopPanesJson.entries) {
        final pane = desktopPaneFromKey(entry.key.toString());
        if (pane == null) {
          continue;
        }
        desktopPanes[pane] = entry.value == true;
      }
    }

    final desktopPaneWidthsJson = json['desktopPaneWidths'];
    if (desktopPaneWidthsJson is Map) {
      for (final entry in desktopPaneWidthsJson.entries) {
        final pane = desktopPaneFromKey(entry.key.toString());
        if (pane == null) {
          continue;
        }
        final raw = entry.value;
        if (raw is num) {
          desktopPaneWidths[pane] = raw.toDouble().clamp(160.0, 500.0);
        }
      }
    }

    final terminalPanelVisibleJson = json['terminalPanelVisible'];
    if (terminalPanelVisibleJson is bool) {
      terminalPanelVisible = terminalPanelVisibleJson;
    }

    final terminalPanelHeightJson = json['terminalPanelHeight'];
    if (terminalPanelHeightJson is num) {
      terminalPanelHeight = terminalPanelHeightJson.toDouble().clamp(
        180.0,
        480.0,
      );
    }

    final terminalPanelMaximizedJson = json['terminalPanelMaximized'];
    if (terminalPanelMaximizedJson is bool) {
      terminalPanelMaximized = terminalPanelMaximizedJson;
    }

    final appDensityJson = json['appDensity'];
    if (appDensityJson is String && appDensityJson.trim().isNotEmpty) {
      appDensity = appDensityFromKey(appDensityJson.trim().toLowerCase());
    }

    final chatRenderModeJson = json['chatRenderMode'];
    if (chatRenderModeJson is String && chatRenderModeJson.trim().isNotEmpty) {
      chatRenderMode = chatRenderModeFromKey(chatRenderModeJson);
    }

    final showThinkingBubblesJson = json['showThinkingBubbles'];
    if (showThinkingBubblesJson is bool) {
      showThinkingBubbles = showThinkingBubblesJson;
    }

    final showToolCallBubblesJson = json['showToolCallBubbles'];
    if (showToolCallBubblesJson is bool) {
      showToolCallBubbles = showToolCallBubblesJson;
    }

    final showTaskListJson = json['showTaskList'];
    if (showTaskListJson is bool) {
      showTaskList = showTaskListJson;
    }

    final showReviewChangesJson = json['showReviewChanges'];
    if (showReviewChangesJson is bool) {
      showReviewChanges = showReviewChangesJson;
    }

    final showRecentSessionsJson = json['showRecentSessions'];
    if (showRecentSessionsJson is bool) {
      showRecentSessions = showRecentSessionsJson;
    }

    final showSessionTabsOverrideJson = json['showSessionTabsOverride'];
    if (showSessionTabsOverrideJson is bool) {
      showSessionTabsOverride = showSessionTabsOverrideJson;
    }

    final sessionTabsGestureHintDismissedJson =
        json['sessionTabsGestureHintDismissed'];
    if (sessionTabsGestureHintDismissedJson is bool) {
      sessionTabsGestureHintDismissed = sessionTabsGestureHintDismissedJson;
    }

    final taskListCollapsedJson = json['taskListCollapsed'];
    if (taskListCollapsedJson is bool) {
      taskListCollapsed = taskListCollapsedJson;
    }

    final showComposerTipsJson = json['showComposerTips'];
    if (showComposerTipsJson is bool) {
      showComposerTips = showComposerTipsJson;
    }

    final showMathRenderingJson = json['showMathRendering'];
    if (showMathRenderingJson is bool) {
      showMathRendering = showMathRenderingJson;
    }

    final composerSpellCheckEnabledJson = json['composerSpellCheckEnabled'];
    if (composerSpellCheckEnabledJson is bool) {
      composerSpellCheckEnabled = composerSpellCheckEnabledJson;
    }

    final composerAutoApprovePermissionsJson =
        json['composerAutoApprovePermissions'];
    if (composerAutoApprovePermissionsJson is bool) {
      composerAutoApprovePermissions = composerAutoApprovePermissionsJson;
    }

    final desktopCloseBehaviorJson = json['desktopCloseBehavior'];
    if (desktopCloseBehaviorJson is String &&
        desktopCloseBehaviorJson.trim().isNotEmpty) {
      desktopCloseBehavior = desktopCloseBehaviorFromKey(
        desktopCloseBehaviorJson.trim().toLowerCase(),
      );
    } else {
      final keepDesktopRunningInTrayJson = json['keepDesktopRunningInTray'];
      if (keepDesktopRunningInTrayJson is bool) {
        desktopCloseBehavior = keepDesktopRunningInTrayJson
            ? DesktopCloseBehavior.tray
            : DesktopCloseBehavior.close;
      }
    }

    // Absent key keeps the default, so existing installs migrate to integrated
    // tabs without an explicit opt-in, as required by the desktop chrome rollout.
    final desktopWindowChromeJson = json['desktopWindowChrome'];
    if (desktopWindowChromeJson is String &&
        desktopWindowChromeJson.trim().isNotEmpty) {
      desktopWindowChrome = desktopWindowChromeFromKey(
        desktopWindowChromeJson.trim().toLowerCase(),
      );
    }

    final editorAutosaveEnabledJson = json['editorAutosaveEnabled'];
    if (editorAutosaveEnabledJson is bool) {
      editorAutosaveEnabled = editorAutosaveEnabledJson;
    }

    final bubbleSizeJson = json['sessionAttentionBubbleSize'];
    if (bubbleSizeJson is String && bubbleSizeJson.trim().isNotEmpty) {
      sessionAttentionBubbleSize = sessionAttentionBubbleSizeFromKey(
        bubbleSizeJson.trim(),
      );
    }

    final dataSaverEnabledJson = json['dataSaverEnabled'];
    if (dataSaverEnabledJson is bool) {
      dataSaverEnabled = dataSaverEnabledJson;
      dataSaverLevel = dataSaverEnabled
          ? DataSaverLevel.standard
          : DataSaverLevel.off;
    }

    final dataSaverLevelJson = json['dataSaverLevel'];
    if (dataSaverLevelJson is String && dataSaverLevelJson.trim().isNotEmpty) {
      dataSaverLevel = dataSaverLevelFromKey(dataSaverLevelJson);
      dataSaverEnabled = dataSaverLevel != DataSaverLevel.off;
    }

    final keepMobileRealtimeForShortPeriodJson =
        json['keepMobileRealtimeForShortPeriod'];
    if (keepMobileRealtimeForShortPeriodJson is bool) {
      keepMobileRealtimeForShortPeriod = keepMobileRealtimeForShortPeriodJson;
    }

    final syncResumeGracePeriodJson = json['syncResumeGracePeriodMs'];
    if (syncResumeGracePeriodJson is num) {
      syncResumeGracePeriod = clampSyncResumeGracePeriod(
        Duration(milliseconds: syncResumeGracePeriodJson.toInt()),
      );
    }

    final androidBackgroundAlertsEnabledJson =
        json['androidBackgroundAlertsEnabled'];
    if (androidBackgroundAlertsEnabledJson is bool) {
      androidBackgroundAlertsEnabled = androidBackgroundAlertsEnabledJson;
    }

    final sessionAttentionPresentationJson =
        json['sessionAttentionPresentation'];
    if (sessionAttentionPresentationJson is String) {
      sessionAttentionPresentation = sessionAttentionPresentationFromKey(
        sessionAttentionPresentationJson,
      );
    }

    final enableExperimentalMultiDeviceSyncJson =
        json['enableExperimentalMultiDeviceSync'];
    if (enableExperimentalMultiDeviceSyncJson is bool) {
      enableExperimentalMultiDeviceSync = enableExperimentalMultiDeviceSyncJson;
    }

    final loggingEnabledJson = json['loggingEnabled'];
    final performanceLoggingEnabledJson = json['performanceLoggingEnabled'];
    if (performanceLoggingEnabledJson is bool) {
      performanceLoggingEnabled = performanceLoggingEnabledJson;
    }
    if (loggingEnabledJson is bool) {
      loggingEnabled = loggingEnabledJson;
    } else if (performanceLoggingEnabled) {
      loggingEnabled = true;
    }

    var themeMode = defaults.themeMode;
    final themeModeJson = json['themeMode'];
    if (themeModeJson is String && themeModeJson.trim().isNotEmpty) {
      themeMode = themeModeOptionFromKey(themeModeJson.trim().toLowerCase());
    }

    // Missing visualStyle means an older persisted settings payload; keep those
    // users on Classic while new installs use ExperienceSettings.defaults().
    var visualStyle = VisualStyle.classic;
    final visualStyleJson = json['visualStyle'];
    if (visualStyleJson is String && visualStyleJson.trim().isNotEmpty) {
      visualStyle = visualStyleFromKey(visualStyleJson);
    }

    String? localeCode;
    final localeCodeJson = json['localeCode'];
    if (localeCodeJson is String && localeCodeJson.trim().isNotEmpty) {
      localeCode = localeCodeJson.trim().toLowerCase();
    }

    var themePreset = defaults.themePreset;
    final themePresetJson = json['themePreset'];
    if (themePresetJson is String && themePresetJson.trim().isNotEmpty) {
      themePreset = openCodeThemePresetFromKey(
        themePresetJson.trim().toLowerCase(),
      );
    }

    var useAmoledDark = defaults.useAmoledDark;
    final useAmoledDarkJson = json['useAmoledDark'];
    if (useAmoledDarkJson is bool) {
      useAmoledDark = useAmoledDarkJson;
    }

    var useDynamicColor = defaults.useDynamicColor;
    final useDynamicColorJson = json['useDynamicColor'];
    if (useDynamicColorJson is bool) {
      useDynamicColor = useDynamicColorJson;
    }

    var customColorSeed = defaults.customColorSeed;
    final customColorSeedJson = json['customColorSeed'];
    if (customColorSeedJson is num) {
      customColorSeed = customColorSeedJson.toInt();
    }

    var contrastLevel = defaults.contrastLevel;
    final contrastLevelJson = json['contrastLevel'];
    if (contrastLevelJson is num) {
      contrastLevel = contrastLevelJson.toDouble().clamp(-1.0, 1.0);
    }

    final speechToTextEngineJson = json['speechToTextEngine'];
    if (speechToTextEngineJson is String &&
        speechToTextEngineJson.trim().isNotEmpty) {
      speechToTextEngine = speechToTextEngineFromKey(
        speechToTextEngineJson.trim().toLowerCase(),
      );
    }

    final speechSilenceTimeoutSecondsJson = json['speechSilenceTimeoutSeconds'];
    if (speechSilenceTimeoutSecondsJson is num) {
      speechSilenceTimeoutSeconds = speechSilenceTimeoutSecondsJson
          .toInt()
          .clamp(2, 10)
          .toInt();
    }

    final sherpaLanguageCodeJson = json['sherpaLanguageCode'];
    if (sherpaLanguageCodeJson is String &&
        sherpaLanguageCodeJson.trim().isNotEmpty) {
      sherpaLanguageCode = sherpaLanguageCodeJson.trim().toLowerCase();
    }

    final moonshineModelIdJson = json['moonshineModelId'];
    if (moonshineModelIdJson is String &&
        moonshineModelIdJson.trim().isNotEmpty) {
      moonshineModelId = moonshineModelIdJson.trim().toLowerCase();
    }

    final parakeetModelIdJson = json['parakeetModelId'];
    if (parakeetModelIdJson is String &&
        parakeetModelIdJson.trim().isNotEmpty) {
      parakeetModelId = parakeetModelIdJson.trim().toLowerCase();
    }

    final senseVoiceModelIdJson = json['senseVoiceModelId'];
    if (senseVoiceModelIdJson is String &&
        senseVoiceModelIdJson.trim().isNotEmpty) {
      senseVoiceModelId = senseVoiceModelIdJson.trim().toLowerCase();
    }

    var skipOnboardingWizard = defaults.skipOnboardingWizard;
    final skipOnboardingWizardJson = json['skipOnboardingWizard'];
    if (skipOnboardingWizardJson is bool) {
      skipOnboardingWizard = skipOnboardingWizardJson;
    }

    var pendingPostOnboardingChatTour = defaults.pendingPostOnboardingChatTour;
    final pendingPostOnboardingChatTourJson =
        json['pendingPostOnboardingChatTour'];
    if (pendingPostOnboardingChatTourJson is bool) {
      pendingPostOnboardingChatTour = pendingPostOnboardingChatTourJson;
    }

    var checkUpdatesOnOpen = defaults.checkUpdatesOnOpen;
    final checkUpdatesOnOpenJson = json['checkUpdatesOnOpen'];
    if (checkUpdatesOnOpenJson is bool) {
      checkUpdatesOnOpen = checkUpdatesOnOpenJson;
    }

    final readAloudEnabledJson = json['readAloudEnabled'];
    if (readAloudEnabledJson is bool) {
      readAloudEnabled = readAloudEnabledJson;
    }

    final readAloudProviderJson = json['readAloudProvider'];
    if (readAloudProviderJson is String &&
        readAloudProviderJson.trim().isNotEmpty) {
      readAloudProvider = readAloudProviderFromKey(readAloudProviderJson);
    }

    final readAloudRateJson = json['readAloudRate'];
    if (readAloudRateJson is num) {
      readAloudRate = readAloudRateJson.toDouble().clamp(0.0, 1.0);
    }

    final readAloudPitchJson = json['readAloudPitch'];
    if (readAloudPitchJson is num) {
      readAloudPitch = readAloudPitchJson.toDouble().clamp(0.5, 2.0);
    }

    final readAloudVoiceJson = json['readAloudVoice'];
    if (readAloudVoiceJson is String && readAloudVoiceJson.trim().isNotEmpty) {
      readAloudVoice = readAloudVoiceJson.trim();
    }

    final readAloudVoiceIdJson = json['readAloudVoiceId'];
    if (readAloudVoiceIdJson is String &&
        readAloudVoiceIdJson.trim().isNotEmpty) {
      readAloudVoiceId = readAloudVoiceIdJson.trim();
    } else if (readAloudVoice != null && readAloudVoice.trim().isNotEmpty) {
      readAloudVoiceId = readAloudVoice.trim();
    }

    final readAloudVoiceLocaleJson = json['readAloudVoiceLocale'];
    if (readAloudVoiceLocaleJson is String &&
        readAloudVoiceLocaleJson.trim().isNotEmpty) {
      readAloudVoiceLocale = readAloudVoiceLocaleJson.trim();
    }

    final readAloudModelJson = json['readAloudModel'];
    if (readAloudModelJson is String && readAloudModelJson.trim().isNotEmpty) {
      readAloudModel = readAloudModelJson.trim();
    }

    final readAloudBaseUrlJson = json['readAloudBaseUrl'];
    if (readAloudBaseUrlJson is String &&
        readAloudBaseUrlJson.trim().isNotEmpty) {
      readAloudBaseUrl = readAloudBaseUrlJson.trim().replaceFirst(
        RegExp(r'/+$'),
        '',
      );
    }

    final readAloudResponseFormatJson = json['readAloudResponseFormat'];
    if (readAloudResponseFormatJson is String &&
        readAloudResponseFormatJson.trim().isNotEmpty) {
      readAloudResponseFormat = readAloudResponseFormatJson
          .trim()
          .toLowerCase();
    }

    final systemFontScaleJson = json['systemFontScale'];
    if (systemFontScaleJson is num) {
      systemFontScale = clampSystemFontScale(systemFontScaleJson.toDouble());
    }

    final chatFontScaleJson = json['chatFontScale'];
    if (chatFontScaleJson is num) {
      chatFontScale = clampChatFontScale(chatFontScaleJson.toDouble());
    }

    final terminalFontSizeJson = json['terminalFontSize'];
    if (terminalFontSizeJson is num) {
      terminalFontSize = clampTerminalFontSize(terminalFontSizeJson.toDouble());
    }

    return ExperienceSettings(
      notifications: notifications,
      sounds: sounds,
      notifyOnlyWhenBackground: notifyOnlyWhenBackground,
      notifyOnlyWhenAnotherSession: notifyOnlyWhenAnotherSession,
      soundOnlyWhenBackground: soundOnlyWhenBackground,
      soundOnlyWhenAnotherSession: soundOnlyWhenAnotherSession,
      soundSources: soundSources,
      soundLabels: soundLabels,
      shortcuts: shortcuts,
      desktopPanes: desktopPanes,
      desktopPaneWidths: desktopPaneWidths,
      terminalPanelVisible: terminalPanelVisible,
      terminalPanelHeight: terminalPanelHeight,
      terminalPanelMaximized: terminalPanelMaximized,
      appDensity: appDensity,
      chatRenderMode: chatRenderMode,
      showThinkingBubbles: showThinkingBubbles,
      showToolCallBubbles: showToolCallBubbles,
      showTaskList: showTaskList,
      showReviewChanges: showReviewChanges,
      showRecentSessions: showRecentSessions,
      showSessionTabsOverride: showSessionTabsOverride,
      sessionTabsGestureHintDismissed: sessionTabsGestureHintDismissed,
      taskListCollapsed: taskListCollapsed,
      showComposerTips: showComposerTips,
      showMathRendering: showMathRendering,
      composerSpellCheckEnabled: composerSpellCheckEnabled,
      composerAutoApprovePermissions: composerAutoApprovePermissions,
      desktopCloseBehavior: desktopCloseBehavior,
      desktopWindowChrome: desktopWindowChrome,
      editorAutosaveEnabled: editorAutosaveEnabled,
      sessionAttentionBubbleSize: sessionAttentionBubbleSize,
      dataSaverEnabled: dataSaverEnabled,
      dataSaverLevel: dataSaverLevel,
      androidBackgroundAlertsEnabled: androidBackgroundAlertsEnabled,
      sessionAttentionPresentation: sessionAttentionPresentation,
      keepMobileRealtimeForShortPeriod: keepMobileRealtimeForShortPeriod,
      syncResumeGracePeriod: syncResumeGracePeriod,
      enableExperimentalMultiDeviceSync: enableExperimentalMultiDeviceSync,
      loggingEnabled: loggingEnabled,
      performanceLoggingEnabled: performanceLoggingEnabled,
      themeMode: themeMode,
      visualStyle: visualStyle,
      localeCode: localeCode,
      themePreset: themePreset,
      useAmoledDark: useAmoledDark,
      useDynamicColor: useDynamicColor,
      customColorSeed: customColorSeed,
      contrastLevel: contrastLevel,
      speechToTextEngine: speechToTextEngine,
      speechSilenceTimeoutSeconds: speechSilenceTimeoutSeconds,
      sherpaLanguageCode: sherpaLanguageCode,
      moonshineModelId: moonshineModelId,
      parakeetModelId: parakeetModelId,
      senseVoiceModelId: senseVoiceModelId,
      skipOnboardingWizard: skipOnboardingWizard,
      pendingPostOnboardingChatTour: pendingPostOnboardingChatTour,
      checkUpdatesOnOpen: checkUpdatesOnOpen,
      readAloudEnabled: readAloudEnabled,
      readAloudProvider: readAloudProvider,
      readAloudRate: readAloudRate,
      readAloudPitch: readAloudPitch,
      readAloudVoice: readAloudVoice,
      readAloudVoiceId: readAloudVoiceId,
      readAloudVoiceLocale: readAloudVoiceLocale,
      readAloudModel: readAloudModel,
      readAloudBaseUrl: readAloudBaseUrl,
      readAloudResponseFormat: readAloudResponseFormat,
      systemFontScale: systemFontScale,
      chatFontScale: chatFontScale,
      terminalFontSize: terminalFontSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ExperienceSettings &&
            _deepJsonEquals(toJson(), other.toJson());
  }

  @override
  int get hashCode => _deepJsonHash(toJson());
}

bool _deepJsonEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!_deepJsonEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepJsonHash(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList(growable: false)
      ..sort(
        (left, right) => left.key.toString().compareTo(right.key.toString()),
      );
    return Object.hashAll(
      entries.map(
        (entry) => Object.hash(entry.key, _deepJsonHash(entry.value)),
      ),
    );
  }
  if (value is List) {
    return Object.hashAll(value.map(_deepJsonHash));
  }
  return value.hashCode;
}
