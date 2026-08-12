part of 'settings_provider.dart';

extension SettingsProviderOpenCodeDefaults on SettingsProvider {
  Future<void> refreshOpenCodeBackedDefaults() async {
    if (_openCodeDefaultsLoading) {
      return;
    }

    _openCodeDefaultsLoading = true;
    _openCodeDefaultsError = null;
    notifyListeners();

    try {
      final configResponse = await _dioClient.get<Map<String, dynamic>>(
        '/config',
      );
      final config = configResponse.data ?? const <String, dynamic>{};

      Map<String, dynamic>? providersPayload;
      try {
        final providersResponse = await _dioClient.get<Map<String, dynamic>>(
          '/provider',
        );
        providersPayload = providersResponse.data;
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to load OpenCode providers for settings defaults',
          error: error,
          stackTrace: stackTrace,
        );
      }

      List<dynamic>? agentsPayload;
      try {
        final agentsResponse = await _dioClient.get<List<dynamic>>('/agent');
        agentsPayload = agentsResponse.data;
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to load OpenCode agents for settings defaults',
          error: error,
          stackTrace: stackTrace,
        );
      }

      final configuredModelKey = _configuredModelKeyFromConfig(config);
      final configuredSmallModelKey = _configuredSmallModelKeyFromConfig(
        config,
      );
      final configuredAgentName = _configuredAgentNameFromConfig(config);
      final configuredUsername = _configuredUsernameFromConfig(config);
      final configuredSnapshotEnabled = _configuredSnapshotEnabledFromConfig(
        config,
      );
      final configuredAutoupdateMode = _configuredAutoupdateModeFromConfig(
        config,
      );
      final configuredShareMode = _configuredShareModeFromConfig(config);

      final nextModelOptions = _buildOpenCodeDefaultModelOptions(
        providersPayload,
        configuredModelKeys: <String?>[
          configuredModelKey,
          configuredSmallModelKey,
        ],
      );
      final nextAgentOptions = _buildOpenCodeDefaultAgentOptions(
        agentsPayload,
        configuredAgentName: configuredAgentName,
      );

      _openCodeDefaultModelKey = configuredModelKey;
      _openCodeSmallModelKey = configuredSmallModelKey;
      _openCodeDefaultAgentName = configuredAgentName;
      _openCodeUsername = configuredUsername;
      _openCodeSnapshotEnabled = configuredSnapshotEnabled;
      _openCodeAutoupdateMode = configuredAutoupdateMode;
      _openCodeShareMode = configuredShareMode;
      _openCodeDefaultModelOptions = nextModelOptions;
      _openCodeDefaultAgentOptions = nextAgentOptions;
      _openCodeDefaultsLoaded = true;
    } catch (error, stackTrace) {
      _openCodeDefaultsError =
          L10nBridge.current?.settingsBehaviorOpenCodeDefaultsLoadError ??
          'Could not load OpenCode-backed defaults from the active server.';
      AppLogger.warn(
        'Failed to load OpenCode-backed defaults',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _openCodeDefaultsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setOpenCodeDefaultModel(String modelKey) async {
    final normalizedModelKey = modelKey.trim();
    if (normalizedModelKey.isEmpty ||
        normalizedModelKey == _openCodeDefaultModelKey) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'model': normalizedModelKey},
      );
      _openCodeDefaultModelKey = normalizedModelKey;
      _ensureConfiguredModelOption(normalizedModelKey);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode default model',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeSmallModel(String modelKey) async {
    final normalizedModelKey = modelKey.trim();
    if (normalizedModelKey.isEmpty ||
        normalizedModelKey == _openCodeSmallModelKey) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'small_model': normalizedModelKey},
      );
      _openCodeSmallModelKey = normalizedModelKey;
      _ensureConfiguredModelOption(normalizedModelKey);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode small model',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeDefaultAgent(String agentName) async {
    final normalizedAgentName = agentName.trim();
    if (normalizedAgentName.isEmpty ||
        normalizedAgentName == _openCodeDefaultAgentName) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'default_agent': normalizedAgentName},
      );
      _openCodeDefaultAgentName = normalizedAgentName;
      _ensureConfiguredAgentOption(normalizedAgentName);
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode default agent',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeUsername(String username) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      return false;
    }
    if (normalizedUsername == _openCodeUsername) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'username': normalizedUsername},
      );
      _openCodeUsername = normalizedUsername;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode username',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeSnapshotEnabled(bool enabled) async {
    if (enabled == _openCodeSnapshotEnabled) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'snapshot': enabled},
      );
      _openCodeSnapshotEnabled = enabled;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode snapshot mode',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeAutoupdateMode(OpenCodeAutoupdateMode mode) async {
    if (mode == _openCodeAutoupdateMode) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'autoupdate': _encodeAutoupdateMode(mode)},
      );
      _openCodeAutoupdateMode = mode;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode autoupdate mode',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> setOpenCodeShareMode(OpenCodeShareMode mode) async {
    if (mode == _openCodeShareMode) {
      return true;
    }

    try {
      await _dioClient.patch<void>(
        '/config',
        data: <String, dynamic>{'share': _encodeShareMode(mode)},
      );
      _openCodeShareMode = mode;
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to update OpenCode share mode',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
