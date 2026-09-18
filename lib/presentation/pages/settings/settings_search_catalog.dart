import 'package:flutter/foundation.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../domain/entities/experience_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/read_aloud_service.dart';
import '../../utils/shortcut_l10n.dart';

/// Explicit control destinations, never user values or remotely loaded data.
class SettingsSearchOption {
  const SettingsSearchOption(
    this.sectionId,
    this.targetKey,
    this.label, [
    this.terms = const [],
  ]);
  final String sectionId;
  final String targetKey;
  final String label;
  final List<String> terms;

  bool matches(String query) => <String>[
    label,
    ...terms,
  ].join(' ').toLowerCase().contains(query.trim().toLowerCase());
}

List<SettingsSearchOption> settingsSearchOptions(
  AppLocalizations l,
  SettingsProvider s, {
  bool hasLocaleProvider = true,
  bool hasServerProfiles = true,
}) {
  final desktop =
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final options = <SettingsSearchOption>[];
  void add(
    String section,
    String key,
    String label, [
    List<String> terms = const [],
  ]) => options.add(SettingsSearchOption(section, key, label, terms));

  add('servers', 'settings_servers_setup', l.serversSetupWizard);
  add('servers', 'settings_servers_health', l.serversRefreshHealth);
  add('servers', 'settings_servers_add', l.serversAddServer);
  if (hasServerProfiles) {
    add('servers', 'settings_servers_active', l.settingsServersChooseActive);
  }

  add(
    'appearance',
    'settings_theme_mode_segmented',
    l.settingsAppearanceTheme,
    [
      l.settingsAppearanceSystem,
      l.settingsAppearanceLight,
      l.settingsAppearanceDark,
    ],
  );
  add(
    'appearance',
    'settings_theme_family_segmented',
    l.settingsAppearanceCodeWalkClassic,
    [l.settingsAppearanceOpenCodePresets],
  );
  if (s.themePreset != null) {
    add(
      'appearance',
      'settings_theme_preset_dropdown',
      l.settingsAppearancePresetPalette,
    );
  }
  add(
    'appearance',
    'settings_visual_style_segmented',
    l.settingsAppearanceVisualStyle,
    [
      l.settingsAppearanceVisualStyleClassic,
      l.settingsAppearanceVisualStyleRefined,
    ],
  );
  add(
    'appearance',
    'settings_toggle_amoled_dark',
    l.settingsAppearanceAmoledDark,
  );
  if (s.dynamicColorAvailable) {
    add(
      'appearance',
      'settings_toggle_dynamic_color',
      l.settingsAppearanceWallpaperColors,
    );
  }
  add(
    'appearance',
    'settings_brand_color_wrap',
    l.settingsAppearanceBrandColor,
  );
  add('appearance', 'settings_contrast_slider', l.settingsAppearanceContrast);
  add(
    'appearance',
    'settings_density_choice_wrap',
    l.settingsAppearanceDensity,
    [
      l.settingsAppearanceDensityExtraDense,
      l.settingsAppearanceDensityDense,
      l.settingsAppearanceDensityNormal,
      l.settingsAppearanceDensitySpacious,
      l.settingsAppearanceDensityExtraSpacious,
    ],
  );
  add(
    'appearance',
    'settings_font_size_slider_system',
    l.settingsAppearanceSystemFontScale,
  );
  add(
    'appearance',
    'settings_font_size_slider_chat',
    l.settingsAppearanceChatFontScale,
  );
  add(
    'appearance',
    'settings_font_size_slider_terminal',
    l.settingsAppearanceTerminalFontSize,
  );
  if (desktop) {
    add(
      'appearance',
      'settings_window_chrome_integrated',
      l.settingsAppearanceWindowChromeIntegrated,
    );
    add(
      'appearance',
      'settings_window_chrome_system',
      l.settingsAppearanceWindowChromeSystem,
    );
  }
  add(
    'appearance',
    'settings_toggle_thinking_bubbles',
    l.settingsAppearanceThinkingBubbles,
  );
  add(
    'appearance',
    'settings_toggle_tool_call_bubbles',
    l.settingsAppearanceToolCallBubbles,
  );
  add('appearance', 'settings_toggle_task_list', l.settingsAppearanceTaskList);
  add(
    'appearance',
    'settings_toggle_composer_tips',
    l.settingsAppearanceComposerTips,
  );
  add(
    'appearance',
    'settings_toggle_math_rendering',
    l.settingsAppearanceMathRendering,
  );

  if (hasLocaleProvider) {
    add('behavior', 'settings_language_selector', l.settingsLanguageTitle);
  }
  add(
    'behavior',
    'settings_chat_render_mode',
    l.settingsBehaviorChatRenderMode,
  );
  add(
    'behavior',
    'settings_toggle_composer_spell_check',
    l.settingsBehaviorComposerSpellCheck,
  );
  add('behavior', 'settings_opencode_default_model', l.settingsDefaultModel);
  add('behavior', 'settings_opencode_default_agent', l.settingsDefaultAgent);
  add('behavior', 'settings_opencode_username', l.settingsConversationUsername);
  add(
    'behavior',
    'settings_opencode_username_save',
    l.settingsBehaviorSaveUsername,
  );
  add(
    'behavior',
    'settings_opencode_snapshot',
    l.settingsBehaviorOpenCodeSnapshots,
  );
  add('behavior', 'settings_opencode_small_model', l.settingsSmallModel);
  add('behavior', 'settings_opencode_autoupdate', l.settingsOpenCodeAutoUpdate);
  add(
    'behavior',
    'settings_opencode_share_mode',
    l.settingsOpenCodeSharingDefault,
  );
  add('behavior', 'settings_data_saver_level', l.behaviorCellularDataSaver);
  add(
    'behavior',
    'settings_toggle_experimental_multi_device_sync',
    l.settingsBehaviorMultiDeviceSync,
  );
  if (s.sessionAttentionHostCapability.supported) {
    add(
      'behavior',
      'settings_session_attention_mode',
      l.settingsSessionAttentionTitle,
    );
    if (android &&
        s.sessionAttentionPresentation != SessionAttentionPresentation.off) {
      add(
        'behavior',
        'settings_session_attention_size',
        l.settingsSessionAttentionSize,
      );
    }
    if (android && !s.sessionAttentionHostCapability.permissionGranted) {
      add(
        'behavior',
        'settings_session_attention_permission',
        l.settingsSessionAttentionOpenSettings,
      );
    }
    if (s.sessionAttentionHostCapability.running) {
      add(
        'behavior',
        'settings_session_attention_stop',
        l.settingsSessionAttentionStop,
      );
    }
  }

  for (final category in NotificationCategory.values) {
    final title = switch (category) {
      NotificationCategory.agent => l.settingsNotificationsAgentUpdates,
      NotificationCategory.permissions => l.settingsNotificationsPermissions,
      NotificationCategory.errors => l.settingsNotificationsErrors,
    };
    add(
      'notifications',
      'settings_notify_${category.name}',
      '$title — ${l.settingsNotificationsNotify}',
    );
    add(
      'notifications',
      'settings_sound_${category.name}',
      '$title — ${l.settingsNotificationsSound}',
    );
    if (s.isNotificationEnabled(category)) {
      add(
        'notifications',
        'settings_notify_when_${category.name}',
        '$title — ${l.settingsNotificationsNotifyOnlyWhen}',
      );
    }
    if (s.isSoundEnabledForNotification(category)) {
      add(
        'notifications',
        'settings_sound_when_${category.name}',
        '$title — ${l.settingsNotificationsSoundOnlyWhen}',
      );
      add(
        'notifications',
        'settings_sound_type_${category.name}',
        '$title — ${l.settingsNotificationsSoundType}',
      );
      add(
        'notifications',
        'settings_preview_sound_${category.name}',
        '$title — ${l.settingsNotificationsPreview}',
      );
      final sound = s.soundFor(s.soundCategoryForNotification(category));
      if (sound == SoundOption.systemChoice) {
        add(
          'notifications',
          'settings_system_sound_${category.name}',
          '$title — ${l.settingsNotificationsChooseSystemSound}',
        );
      }
      if (sound == SoundOption.customFile) {
        add(
          'notifications',
          'settings_custom_sound_${category.name}',
          '$title — ${l.settingsNotificationsChooseAudioFile}',
        );
      }
    }
  }
  if (android) {
    add(
      'notifications',
      'settings_toggle_android_background_alerts',
      l.settingsNotificationsBackgroundToggle,
    );
    add(
      'notifications',
      'settings_toggle_keep_mobile_realtime',
      l.settingsNotificationsKeepLive,
    );
  }

  add('speech', 'settings_speech_engine', l.speechEngine, [
    l.speechNative,
    l.speechSherpa,
    l.speechMoonshine,
    l.speechParakeet,
    l.speechSenseVoice,
    l.speechApiEngine,
  ]);
  add('speech', 'settings_speech_silence', l.speechAutoStopSilence);
  if (s.speechToTextEngine == SpeechToTextEngine.api) {
    final provider = speechApiProviderKey(s.speechApiProvider);
    add('speech', 'speech-api-provider-field', l.speechApiProvider);
    add('speech', 'speech-api-base-url-$provider', l.speechBaseUrl);
    add('speech', 'speech-api-model-$provider', l.speechModel);
    add('speech', 'speech-api-key-$provider', l.speechApiKey);
    add('speech', 'speech-api-save-key', l.speechSaveApiKey);
  }

  add('tts', 'settings_tts_provider', l.speechTextToSpeechProvider, [
    l.speechProviderSystemNative,
    l.speechProviderEdgeExperimental,
    l.speechProviderOpenAiCompatible,
    l.speechProviderElevenLabs,
    l.speechProviderNvidiaNim,
  ]);
  add('tts', 'settings_tts_enabled', l.settingsReadAloudEnabled);
  add('tts', 'read-aloud-test-phrase', l.speechReadAloudTestPhraseLabel);
  add('tts', 'settings_tts_test', l.speechTestVoice);
  if (s.readAloudProvider != ReadAloudProvider.nim) {
    add('tts', 'settings_tts_speed', l.settingsReadAloudSpeed);
  }
  if (s.readAloudProvider == ReadAloudProvider.native) {
    add('tts', 'settings_tts_pitch', l.settingsReadAloudPitch);
  }
  if (s.readAloudProvider == ReadAloudProvider.openAiCompatible) {
    add(
      'tts',
      'read-aloud-base-url-${s.readAloudProvider.name}',
      l.speechBaseUrl,
    );
    add('tts', 'read-aloud-model-${s.readAloudProvider.name}', l.speechModel);
  }
  if (s.readAloudProvider == ReadAloudProvider.openAiCompatible ||
      di.sl.isRegistered<ReadAloudService>()) {
    add('tts', 'settings_tts_voice', l.settingsReadAloudVoice);
  }
  if (s.readAloudProvider == ReadAloudProvider.elevenLabs) {
    add('tts', 'read-aloud-base-url-elevenlabs', l.speechBaseUrl);
  }
  if (di.sl.isRegistered<ReadAloudService>() &&
      (s.readAloudProvider == ReadAloudProvider.elevenLabs ||
          s.readAloudProvider == ReadAloudProvider.nim)) {
    add('tts', 'settings_tts_model', l.speechModel);
  }
  if (s.readAloudProvider == ReadAloudProvider.nim) {
    add('tts', 'read-aloud-base-url-nim', l.speechBaseUrl);
  }
  if (s.readAloudProvider != ReadAloudProvider.native &&
      s.readAloudProvider != ReadAloudProvider.edgeExperimental) {
    add('tts', 'read-aloud-api-key', l.speechApiKey);
  }

  add('logs', 'settings_logs_enabled', l.logsEnableLogging);
  add('logs', 'settings_logs_performance', l.logsMeasurePerformance);
  add('logs', 'settings_logs_range', l.logsTimeRange);
  add('logs', 'settings_logs_level', l.logsLevel);
  add('logs', 'settings_logs_tags', l.logsFilterByTag);
  add('logs', 'settings_logs_custom_tag', l.logsTagCustomAction);
  add('logs', 'settings_logs_filter_performance', l.logsPerformanceFilter);

  add('shortcuts', 'settings_shortcuts_search', l.settingsShortcutsSearch);
  add('shortcuts', 'settings_shortcuts_reset', l.shortcutsReset);
  for (final definition in shortcutDefinitionsForRuntime(
    isWeb: kIsWeb,
    targetPlatform: defaultTargetPlatform,
    refreshlessRealtimeEnabled: FeatureFlags.refreshlessRealtime,
  )) {
    add(
      'shortcuts',
      'settings_shortcut_${definition.action.name}',
      definition.localizedLabel(l),
      [definition.localizedGroup(l), definition.localizedDescription(l)],
    );
  }
  add('about', 'settings_about_check_on_open', l.settingsAboutCheckOnOpen);
  add('about', 'settings_about_check_now', l.settingsAboutCheckForUpdates);
  add('about', 'about_replay_chat_tour_tile', l.settingsAboutReplayChatTour);
  add('about', 'settings_about_github', l.aboutGitHub);
  add('about', 'settings_about_reset', l.settingsAboutResetApp);
  return options;
}
