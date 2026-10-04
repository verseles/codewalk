/// Selectively port v1 data, without importing legacy entities/providers.
/// No defaults are applied: explicit false remains false, absence remains absent.
Map<String, Object> selectedLegacySettings(Map<String, dynamic> source) {
  const booleans = {
    'useProjectIconTabColors',
    'useAmoledDark',
    'useDynamicColor',
    'speechKeepModelInMemory',
    'readAloudEnabled',
    'composerAutoApprovePermissions',
  };
  const numbers = {
    'customColorSeed',
    'contrastLevel',
    'systemFontScale',
    'chatFontScale',
    'terminalFontSize',
    'speechSilenceTimeoutSeconds',
    'readAloudRate',
    'readAloudPitch',
  };
  const strings = {
    'themeMode',
    'visualStyle',
    'themePreset',
    'appDensity',
    'localeCode',
    'speechToTextEngine',
    'sherpaLanguageCode',
    'moonshineModelId',
    'parakeetModelId',
    'senseVoiceModelId',
    'speechApiProvider',
    'speechApiBaseUrl',
    'speechApiModel',
    'readAloudProvider',
    'readAloudVoice',
    'readAloudVoiceId',
    'readAloudVoiceLocale',
    'readAloudModel',
    'readAloudBaseUrl',
    'readAloudResponseFormat',
  };
  const boolMaps = {
    'notifications',
    'notifyOnlyWhenBackground',
    'notifyOnlyWhenAnotherSession',
    'soundOnlyWhenBackground',
    'soundOnlyWhenAnotherSession',
  };
  const stringMaps = {'sounds', 'soundSources', 'soundLabels', 'shortcuts'};
  const categories = {'agent', 'permissions', 'errors'};
  // Owning v1 ShortcutAction keys; unknown actions are not effective v2 truth.
  const actions = {
    'new_chat',
    'refresh',
    'focus_input',
    'toggle_voice_input',
    'quick_open',
    'open_settings',
    'cycle_recent_models',
    'cycle_variant',
    'escape',
    'cycle_agent_forward',
    'cycle_agent_backward',
    'cycle_tabs_forward',
    'cycle_tabs_backward',
    'close_app',
    'quit_app',
  };
  final selected = <String, Object>{};
  for (final entry in source.entries) {
    final key = entry.key;
    final value = entry.value;
    if ((key == 'speechApiBaseUrl' || key == 'readAloudBaseUrl') &&
        value is String) {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          {'http', 'https'}.contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.hasQuery &&
          !uri.hasFragment &&
          value.length <= 8192) {
        selected[key] = value;
      }
    } else if ((booleans.contains(key) && value is bool) ||
        (numbers.contains(key) && value is num && value.isFinite) ||
        (strings.contains(key) && value is String && value.length <= 8192)) {
      selected[key] = value as Object;
    } else if ((boolMaps.contains(key) || stringMaps.contains(key)) &&
        value is Map) {
      final map = <String, Object>{};
      for (final pair in value.entries) {
        if (pair.key is String &&
            (key == 'shortcuts' ? actions : categories).contains(pair.key) &&
            ((boolMaps.contains(key) && pair.value is bool) ||
                (stringMaps.contains(key) &&
                    pair.value is String &&
                    (pair.value as String).length <= 8192))) {
          map[pair.key as String] = pair.value as Object;
        }
      }
      selected[key] = map;
    }
  }
  return selected;
}
