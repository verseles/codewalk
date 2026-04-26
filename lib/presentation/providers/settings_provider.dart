import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../data/models/agent_model.dart';
import '../../data/models/provider_model.dart';
import '../../domain/entities/experience_settings.dart';
import '../../l10n/l10n.dart';
import '../services/android_background_alert_logic.dart';
import '../services/android_background_alert_worker.dart';
import '../services/android_foreground_monitor_service.dart';
import '../services/cellular_data_saver_service.dart';
import '../services/sound_service.dart';
import '../services/update_check_service.dart';
import '../utils/shortcut_binding_codec.dart';

/// Tracks the lifecycle of an in-app update installation.
enum UpdateInstallState { idle, downloading, installing, done, failed }

@immutable
class OpenCodeDefaultModelOption {
  const OpenCodeDefaultModelOption({
    required this.key,
    required this.providerId,
    required this.providerName,
    required this.modelId,
    required this.modelName,
    required this.connected,
  });

  final String key;
  final String providerId;
  final String providerName;
  final String modelId;
  final String modelName;
  final bool connected;

  String get label => '$providerName / $modelName';
}

enum OpenCodeAutoupdateMode { automatic, notify, disabled }

enum OpenCodeShareMode { manual, automatic, disabled }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required AppLocalDataSource localDataSource,
    required DioClient dioClient,
    required SoundService soundService,
    UpdateCheckService? updateCheckService,
    CellularDataSaverService? cellularDataSaverService,
  }) : _localDataSource = localDataSource,
       _dioClient = dioClient,
       _soundService = soundService,
       _updateCheckService = updateCheckService ?? UpdateCheckService(),
       _cellularDataSaverService =
           cellularDataSaverService ?? CellularDataSaverService.disabled() {
    _cellularDataSaverService.addListener(_handleCellularDataSaverChanged);
  }

  final AppLocalDataSource _localDataSource;
  final DioClient _dioClient;
  final SoundService _soundService;
  final UpdateCheckService _updateCheckService;
  final CellularDataSaverService _cellularDataSaverService;

  ExperienceSettings _settings = ExperienceSettings.defaults();
  final Map<NotificationCategory, bool> _serverBackedNotifications =
      <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      };
  final Map<NotificationCategory, String> _serverConfigKeyByCategory =
      <NotificationCategory, String>{};
  UpdateCheckResult? _updateCheckResult;
  String? _dismissedUpdateVersion;
  bool _checkingForUpdate = false;
  bool _lastCheckFoundNoUpdate = false;
  // Set only by _performStartupUpdateCheck(); cleared by acknowledgeStartupUpdateToast().
  // Keeps startup-origin results separate from manual check results.
  bool _pendingStartupUpdateToast = false;
  UpdateInstallState _installState = UpdateInstallState.idle;
  double _installProgress = 0.0;
  bool _initialized = false;
  Future<void>? _initFuture;
  Timer? _automaticUpdateCheckTimer;
  bool _openCodeDefaultsLoading = false;
  bool _openCodeDefaultsLoaded = false;
  String? _openCodeDefaultsError;
  String? _openCodeDefaultModelKey;
  String? _openCodeSmallModelKey;
  String? _openCodeDefaultAgentName;
  String? _openCodeUsername;
  bool _openCodeSnapshotEnabled = true;
  OpenCodeAutoupdateMode _openCodeAutoupdateMode =
      OpenCodeAutoupdateMode.automatic;
  OpenCodeShareMode _openCodeShareMode = OpenCodeShareMode.manual;
  List<OpenCodeDefaultModelOption> _openCodeDefaultModelOptions =
      const <OpenCodeDefaultModelOption>[];
  List<String> _openCodeDefaultAgentOptions = const <String>[];
  bool? _lastBackgroundDataSaverDisableState;

  // Whether the platform actually provided a dynamic color scheme at runtime.
  // Set from main.dart's DynamicColorBuilder callback.
  bool _dynamicColorAvailable = false;

  bool get initialized => _initialized;
  bool get dynamicColorAvailable => _dynamicColorAvailable;
  ExperienceSettings get settings => _settings;
  UpdateCheckResult? get updateCheckResult => _updateCheckResult;
  bool get checkingForUpdate => _checkingForUpdate;
  bool get lastCheckFoundNoUpdate => _lastCheckFoundNoUpdate;
  bool get pendingStartupUpdateToast => _pendingStartupUpdateToast;
  UpdateInstallState get installState => _installState;
  double get installProgress => _installProgress;
  bool get openCodeDefaultsLoading => _openCodeDefaultsLoading;
  bool get openCodeDefaultsLoaded => _openCodeDefaultsLoaded;
  String? get openCodeDefaultsError => _openCodeDefaultsError;
  String? get openCodeDefaultModelKey => _openCodeDefaultModelKey;
  String? get openCodeSmallModelKey => _openCodeSmallModelKey;
  String? get openCodeDefaultAgentName => _openCodeDefaultAgentName;
  String? get openCodeUsername => _openCodeUsername;
  bool get openCodeSnapshotEnabled => _openCodeSnapshotEnabled;
  OpenCodeAutoupdateMode get openCodeAutoupdateMode => _openCodeAutoupdateMode;
  OpenCodeShareMode get openCodeShareMode => _openCodeShareMode;
  List<OpenCodeDefaultModelOption> get openCodeDefaultModelOptions =>
      List<OpenCodeDefaultModelOption>.unmodifiable(
        _openCodeDefaultModelOptions,
      );
  List<String> get openCodeDefaultAgentOptions =>
      List<String>.unmodifiable(_openCodeDefaultAgentOptions);
  ThemeModeOption get themeMode => _settings.themeMode;
  String? get preferredLocaleTag => _settings.preferredLocaleTag;
  Locale? get preferredLocale => appLocaleFromTag(_settings.preferredLocaleTag);
  bool get useAmoledDark => _settings.useAmoledDark;
  bool get useDynamicColor => _settings.useDynamicColor;
  int? get customColorSeed => _settings.customColorSeed;
  double get contrastLevel => _settings.contrastLevel;
  AppDensity get appDensity => _settings.appDensity;
  bool get showThinkingBubbles => _settings.showThinkingBubbles;
  bool get showToolCallBubbles => _settings.showToolCallBubbles;
  bool get showTaskList => _settings.showTaskList;
  bool get showRecentSessions => _settings.showRecentSessions;
  bool get taskListCollapsed => _settings.taskListCollapsed;
  bool get showComposerTips => _settings.showComposerTips;
  bool get terminalPanelVisible => _settings.terminalPanelVisible;
  double get terminalPanelHeight => _settings.terminalPanelHeight;
  bool get terminalPanelMaximized => _settings.terminalPanelMaximized;
  bool get composerAutoApprovePermissions =>
      _settings.composerAutoApprovePermissions;
  DesktopCloseBehavior get desktopCloseBehavior =>
      _settings.desktopCloseBehavior;
  bool get keepDesktopRunningInTray =>
      _settings.desktopCloseBehavior != DesktopCloseBehavior.close;
  bool get dataSaverEnabled => _settings.dataSaverEnabled;
  bool get isCellularConnection =>
      _cellularDataSaverService.isCellularConnection;
  bool get isCellularDataSaverActive =>
      _cellularDataSaverService.isDataSaverActive;
  Duration get cellularDataSaverInterval =>
      _cellularDataSaverService.automaticSyncInterval;
  bool get androidBackgroundAlertsEnabled =>
      _settings.androidBackgroundAlertsEnabled;
  bool get keepMobileRealtimeForShortPeriod =>
      _settings.keepMobileRealtimeForShortPeriod;
  bool get shouldMonitorAndroidBackgroundAlerts =>
      shouldRunAndroidBackgroundAlerts(_settings);
  bool get enableExperimentalMultiDeviceSync =>
      _settings.enableExperimentalMultiDeviceSync;
  SpeechToTextEngine get speechToTextEngine => _settings.speechToTextEngine;
  OpenCodeThemePreset? get themePreset => _settings.themePreset;
  int get speechSilenceTimeoutSeconds => _settings.speechSilenceTimeoutSeconds;
  String get sherpaLanguageCode => _settings.sherpaLanguageCode;
  String get moonshineModelId => _settings.moonshineModelId;
  String get parakeetModelId => _settings.parakeetModelId;
  String get senseVoiceModelId => _settings.senseVoiceModelId;
  bool get skipOnboardingWizard => _settings.skipOnboardingWizard;
  bool get pendingPostOnboardingChatTour =>
      _settings.pendingPostOnboardingChatTour;
  bool get hasAnyServerBackedNotificationCategory =>
      _serverBackedNotifications.values.any((value) => value);

  bool notifyOnlyWhenBackground(NotificationCategory category) {
    return _settings.notifyOnlyWhenBackground[category] ?? false;
  }

  bool notifyOnlyWhenAnotherSession(NotificationCategory category) {
    return _settings.notifyOnlyWhenAnotherSession[category] ?? false;
  }

  bool soundOnlyWhenBackground(NotificationCategory category) {
    return _settings.soundOnlyWhenBackground[category] ?? false;
  }

  bool soundOnlyWhenAnotherSession(NotificationCategory category) {
    return _settings.soundOnlyWhenAnotherSession[category] ?? false;
  }

  bool isServerBackedNotification(NotificationCategory category) {
    return _serverBackedNotifications[category] ?? false;
  }

  Future<void> initialize() async {
    _initFuture ??= _initializeInternal();
    await _initFuture;
  }

  Future<void> _initializeInternal() async {
    final raw = await _localDataSource.getExperienceSettingsJson();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _settings = ExperienceSettings.fromJson(decoded);
        }
      } catch (error, stackTrace) {
        AppLogger.warn(
          'Failed to decode experience settings, using defaults',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // Platform STT policy migration:
    // - Linux: Native is disabled, force Parakeet for new installs / invalid native selections.
    // - Android: Sherpa/Moonshine/Parakeet/SenseVoice are disabled in slim APK builds, force Native.
    // - iOS/Web: Moonshine/Parakeet/SenseVoice stay unavailable until a dedicated client path exists.
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isLinux && _settings.speechToTextEngine == SpeechToTextEngine.native) {
      _settings = _settings.copyWith(
        speechToTextEngine: SpeechToTextEngine.parakeet,
      );
      unawaited(_persist());
    } else if (isAndroid &&
        (_settings.speechToTextEngine == SpeechToTextEngine.sherpa ||
            _settings.speechToTextEngine == SpeechToTextEngine.moonshine ||
            _settings.speechToTextEngine == SpeechToTextEngine.parakeet ||
            _settings.speechToTextEngine == SpeechToTextEngine.sensevoice)) {
      _settings = _settings.copyWith(
        speechToTextEngine: SpeechToTextEngine.native,
      );
      unawaited(_persist());
    } else if ((kIsWeb || isIos) &&
        (_settings.speechToTextEngine == SpeechToTextEngine.moonshine ||
            _settings.speechToTextEngine == SpeechToTextEngine.parakeet ||
            _settings.speechToTextEngine == SpeechToTextEngine.sensevoice)) {
      _settings = _settings.copyWith(
        speechToTextEngine: SpeechToTextEngine.native,
      );
      unawaited(_persist());
    }

    _cellularDataSaverService.setDataSaverEnabled(_settings.dataSaverEnabled);
    _lastBackgroundDataSaverDisableState =
        _cellularDataSaverService.shouldDisableBackgroundNetworkTasks;
    _dismissedUpdateVersion = await _localDataSource
        .getDismissedUpdateVersion();
    unawaited(syncNotificationsFromServerConfig());
    if (_settings.checkUpdatesOnOpen) {
      unawaited(_performStartupUpdateCheck());
    }
    unawaited(_syncAndroidBackgroundAlertRuntime());
    _configureAutomaticUpdateChecks();
    _initialized = true;
    notifyListeners();
  }

  void _configureAutomaticUpdateChecks() {
    _automaticUpdateCheckTimer?.cancel();
    _automaticUpdateCheckTimer = null;
    if (!_settings.checkUpdatesOnOpen) {
      return;
    }
    _automaticUpdateCheckTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_performStartupUpdateCheck());
    });
  }

  /// Silently checks for updates on startup. No spinner, no "up to date" state.
  /// Only notifies when a newer version is found and not already dismissed.
  Future<void> _performStartupUpdateCheck() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final result = await _updateCheckService.check(info.version);
      if (result != null &&
          result.isNewer &&
          result.latestVersion != _dismissedUpdateVersion) {
        _updateCheckResult = result;
        _pendingStartupUpdateToast = true;
        notifyListeners();
      }
    } catch (_) {
      // Startup check is silent; errors are swallowed.
    }
  }

  /// Clears the pending startup toast flag after AppShellPage has consumed it.
  void acknowledgeStartupUpdateToast() {
    if (!_pendingStartupUpdateToast) return;
    _pendingStartupUpdateToast = false;
  }

  bool isNotificationEnabled(NotificationCategory category) {
    return _settings.notifications[category] ?? true;
  }

  SoundCategory soundCategoryForNotification(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.agent => SoundCategory.agent,
      NotificationCategory.permissions => SoundCategory.permissions,
      NotificationCategory.errors => SoundCategory.errors,
    };
  }

  bool isSoundEnabledForNotification(NotificationCategory category) {
    return soundFor(soundCategoryForNotification(category)) != SoundOption.off;
  }

  SoundOption soundFor(SoundCategory category) {
    return _settings.sounds[category] ?? SoundOption.off;
  }

  String? soundSourceFor(SoundCategory category) {
    final value = _settings.soundSources[category]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? soundLabelFor(SoundCategory category) {
    final value = _settings.soundLabels[category]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String bindingFor(ShortcutAction action) {
    return _settings.shortcuts[action] ??
        kShortcutDefinitions
            .where((definition) => definition.action == action)
            .first
            .defaultBinding;
  }

  bool isDesktopPaneVisible(DesktopPane pane) {
    return _settings.desktopPanes[pane] ?? true;
  }

  // Default widths per pane when no custom width is persisted.
  static double defaultDesktopPaneWidth(DesktopPane pane) {
    return switch (pane) {
      DesktopPane.conversations => 300,
      DesktopPane.files => 280,
      DesktopPane.utility => 280,
    };
  }

  /// Current width for a desktop pane (persisted or default).
  double desktopPaneWidth(DesktopPane pane) {
    return _settings.desktopPaneWidths[pane] ?? defaultDesktopPaneWidth(pane);
  }

  /// Update pane width in memory only (no disk write).
  /// Use during continuous drag; call [persistDesktopPaneWidths] on drag end.
  void updateDesktopPaneWidthInMemory(DesktopPane pane, double width) {
    final clamped = width.clamp(160.0, 500.0);
    final current = _settings.desktopPaneWidths[pane];
    if (current != null && (current - clamped).abs() < 1) {
      return;
    }
    final next = Map<DesktopPane, double>.from(_settings.desktopPaneWidths);
    next[pane] = clamped;
    _settings = _settings.copyWith(desktopPaneWidths: next);
    notifyListeners();
  }

  /// Persist current pane widths to disk. Call once after drag ends.
  Future<void> persistDesktopPaneWidths() async {
    await _persist();
  }

  Future<void> setDesktopPaneWidth(DesktopPane pane, double width) async {
    updateDesktopPaneWidthInMemory(pane, width);
    await _persist();
  }

  Future<void> resetDesktopPaneWidth(DesktopPane pane) async {
    if (!_settings.desktopPaneWidths.containsKey(pane)) {
      return;
    }
    final next = Map<DesktopPane, double>.from(_settings.desktopPaneWidths);
    next.remove(pane);
    _settings = _settings.copyWith(desktopPaneWidths: next);
    notifyListeners();
    await _persist();
  }

  void updateTerminalPanelHeightInMemory(double height) {
    final clamped = height.clamp(180.0, 480.0);
    if ((_settings.terminalPanelHeight - clamped).abs() < 1) {
      return;
    }
    _settings = _settings.copyWith(terminalPanelHeight: clamped);
    notifyListeners();
  }

  Future<void> persistTerminalPanelHeight() async {
    await _persist();
  }

  Future<void> setTerminalPanelHeight(double height) async {
    updateTerminalPanelHeightInMemory(height);
    await _persist();
  }

  Future<void> setTerminalPanelMaximized(bool maximized) async {
    if (_settings.terminalPanelMaximized == maximized) {
      return;
    }
    _settings = _settings.copyWith(terminalPanelMaximized: maximized);
    notifyListeners();
    await _persist();
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_settings.themeMode == mode) {
      return;
    }
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _persist();
  }

  Future<void> setPreferredLocaleTag(String? localeTag) async {
    final normalizedTag = localeTag?.trim();
    final nextTag = (normalizedTag == null || normalizedTag.isEmpty)
        ? null
        : appLocaleToTag(appLocaleFromTag(normalizedTag));
    if (_settings.preferredLocaleTag == nextTag) {
      return;
    }
    _settings = _settings.copyWith(preferredLocaleTag: () => nextTag);
    notifyListeners();
    await _persist();
  }

  Future<void> setThemePreset(OpenCodeThemePreset? preset) async {
    if (_settings.themePreset == preset) {
      return;
    }
    _settings = _settings.copyWith(themePreset: () => preset);
    notifyListeners();
    await _persist();
  }

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

  Future<void> setUseAmoledDark(bool value) async {
    if (_settings.useAmoledDark == value) {
      return;
    }
    _settings = _settings.copyWith(useAmoledDark: value);
    notifyListeners();
    await _persist();
  }

  /// Sync runtime dynamic color availability from DynamicColorBuilder.
  void updateDynamicColorAvailability({required bool available}) {
    if (_dynamicColorAvailable == available) {
      return;
    }
    _dynamicColorAvailable = available;
    notifyListeners();
  }

  Future<void> setUseDynamicColor(bool value) async {
    if (_settings.useDynamicColor == value) {
      return;
    }
    _settings = _settings.copyWith(useDynamicColor: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setCustomColorSeed(int? value) async {
    if (_settings.customColorSeed == value) {
      return;
    }
    _settings = _settings.copyWith(customColorSeed: () => value);
    notifyListeners();
    await _persist();
  }

  Future<void> setContrastLevel(double level) async {
    final clamped = level.clamp(-1.0, 1.0);
    if (_settings.contrastLevel == clamped) {
      return;
    }
    _settings = _settings.copyWith(contrastLevel: clamped);
    notifyListeners();
    await _persist();
  }

  Future<void> setAppDensity(AppDensity density) async {
    if (_settings.appDensity == density) {
      return;
    }
    _settings = _settings.copyWith(appDensity: density);
    notifyListeners();
    await _persist();
  }

  Future<void> setShowThinkingBubbles(bool visible) async {
    if (_settings.showThinkingBubbles == visible) {
      return;
    }
    _settings = _settings.copyWith(showThinkingBubbles: visible);
    notifyListeners();
    await _persist();
  }

  Future<void> setShowToolCallBubbles(bool visible) async {
    if (_settings.showToolCallBubbles == visible) {
      return;
    }
    _settings = _settings.copyWith(showToolCallBubbles: visible);
    notifyListeners();
    await _persist();
  }

  Future<void> setShowTaskList(bool visible) async {
    if (_settings.showTaskList == visible) {
      return;
    }
    _settings = _settings.copyWith(showTaskList: visible);
    notifyListeners();
    await _persist();
  }

  Future<void> setShowRecentSessions(bool visible) async {
    if (_settings.showRecentSessions == visible) {
      return;
    }
    _settings = _settings.copyWith(showRecentSessions: visible);
    notifyListeners();
    await _persist();
  }

  Future<void> setTaskListCollapsed(bool collapsed) async {
    if (_settings.taskListCollapsed == collapsed) {
      return;
    }
    _settings = _settings.copyWith(taskListCollapsed: collapsed);
    notifyListeners();
    await _persist();
  }

  Future<void> setShowComposerTips(bool enabled) async {
    if (_settings.showComposerTips == enabled) {
      return;
    }
    _settings = _settings.copyWith(showComposerTips: enabled);
    notifyListeners();
    await _persist();
  }

  Future<void> setComposerAutoApprovePermissions(bool enabled) async {
    if (_settings.composerAutoApprovePermissions == enabled) {
      return;
    }
    _settings = _settings.copyWith(composerAutoApprovePermissions: enabled);
    notifyListeners();
    await _persist();
  }

  Future<void> setDesktopCloseBehavior(DesktopCloseBehavior behavior) async {
    if (_settings.desktopCloseBehavior == behavior) {
      return;
    }
    _settings = _settings.copyWith(desktopCloseBehavior: behavior);
    notifyListeners();
    await _persist();
  }

  Future<void> setKeepDesktopRunningInTray(bool enabled) async {
    await setDesktopCloseBehavior(
      enabled ? DesktopCloseBehavior.tray : DesktopCloseBehavior.close,
    );
  }

  Future<void> setDataSaverEnabled(bool enabled) async {
    if (_settings.dataSaverEnabled == enabled) {
      return;
    }
    _settings = _settings.copyWith(dataSaverEnabled: enabled);
    _cellularDataSaverService.setDataSaverEnabled(enabled);
    notifyListeners();
    await _persist();
    await _syncAndroidBackgroundAlertRuntime();
  }

  Future<void> setAndroidBackgroundAlertsEnabled(bool enabled) async {
    if (_settings.androidBackgroundAlertsEnabled == enabled) {
      return;
    }
    _settings = _settings.copyWith(androidBackgroundAlertsEnabled: enabled);
    notifyListeners();
    await _persist();
    await _syncAndroidBackgroundAlertRuntime();
  }

  void _handleCellularDataSaverChanged() {
    if (!_initialized) {
      return;
    }
    notifyListeners();
    final nextDisableState =
        _cellularDataSaverService.shouldDisableBackgroundNetworkTasks;
    if (_lastBackgroundDataSaverDisableState == nextDisableState) {
      return;
    }
    _lastBackgroundDataSaverDisableState = nextDisableState;
    unawaited(_syncAndroidBackgroundAlertRuntime());
  }

  Future<void> setKeepMobileRealtimeForShortPeriod(bool enabled) async {
    if (_settings.keepMobileRealtimeForShortPeriod == enabled) {
      return;
    }
    _settings = _settings.copyWith(keepMobileRealtimeForShortPeriod: enabled);
    notifyListeners();
    await _persist();
  }

  Future<void> setEnableExperimentalMultiDeviceSync(bool enabled) async {
    if (_settings.enableExperimentalMultiDeviceSync == enabled) {
      return;
    }
    _settings = _settings.copyWith(enableExperimentalMultiDeviceSync: enabled);
    notifyListeners();
    await _persist();
  }

  Future<void> setSpeechToTextEngine(SpeechToTextEngine engine) async {
    if (_settings.speechToTextEngine == engine) {
      return;
    }
    _settings = _settings.copyWith(speechToTextEngine: engine);
    notifyListeners();
    await _persist();
  }

  Future<void> setSpeechSilenceTimeoutSeconds(int seconds) async {
    final normalized = seconds.clamp(2, 10).toInt();
    if (_settings.speechSilenceTimeoutSeconds == normalized) {
      return;
    }
    _settings = _settings.copyWith(speechSilenceTimeoutSeconds: normalized);
    notifyListeners();
    await _persist();
  }

  Future<void> setSkipOnboardingWizard(bool value) async {
    if (_settings.skipOnboardingWizard == value) {
      return;
    }
    _settings = _settings.copyWith(skipOnboardingWizard: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setPendingPostOnboardingChatTour(bool value) async {
    if (_settings.pendingPostOnboardingChatTour == value) {
      return;
    }
    _settings = _settings.copyWith(pendingPostOnboardingChatTour: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setCheckUpdatesOnOpen(bool value) async {
    if (_settings.checkUpdatesOnOpen == value) {
      return;
    }
    _settings = _settings.copyWith(checkUpdatesOnOpen: value);
    _configureAutomaticUpdateChecks();
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  bool get hasAutomaticUpdateCheckTimer => _automaticUpdateCheckTimer != null;

  @visibleForTesting
  void debugSetInstallStateForTesting(
    UpdateInstallState state, {
    double progress = 0.0,
  }) {
    _installState = state;
    _installProgress = progress;
    notifyListeners();
  }

  Future<void> setSherpaLanguageCode(String languageCode) async {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_settings.sherpaLanguageCode == normalized) {
      return;
    }
    _settings = _settings.copyWith(sherpaLanguageCode: normalized);
    notifyListeners();
    await _persist();
  }

  Future<void> setMoonshineModelId(String modelId) async {
    final normalized = modelId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_settings.moonshineModelId == normalized) {
      return;
    }
    _settings = _settings.copyWith(moonshineModelId: normalized);
    notifyListeners();
    await _persist();
  }

  Future<void> setParakeetModelId(String modelId) async {
    final normalized = modelId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_settings.parakeetModelId == normalized) {
      return;
    }
    _settings = _settings.copyWith(parakeetModelId: normalized);
    notifyListeners();
    await _persist();
  }

  Future<void> setSenseVoiceModelId(String modelId) async {
    final normalized = modelId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    if (_settings.senseVoiceModelId == normalized) {
      return;
    }
    _settings = _settings.copyWith(senseVoiceModelId: normalized);
    notifyListeners();
    await _persist();
  }

  Future<void> setDesktopPaneVisible(DesktopPane pane, bool visible) async {
    final next = Map<DesktopPane, bool>.from(_settings.desktopPanes);
    next[pane] = visible;
    _settings = _settings.copyWith(desktopPanes: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setTerminalPanelVisible(bool visible) async {
    if (_settings.terminalPanelVisible == visible) {
      return;
    }
    _settings = _settings.copyWith(
      terminalPanelVisible: visible,
      terminalPanelMaximized: visible
          ? _settings.terminalPanelMaximized
          : false,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> setNotificationEnabled(
    NotificationCategory category,
    bool value,
  ) async {
    final next = Map<NotificationCategory, bool>.from(_settings.notifications);
    next[category] = value;
    _settings = _settings.copyWith(notifications: next);
    notifyListeners();
    await _persist();
    await _syncAndroidBackgroundAlertRuntime();
    await _syncNotificationToServer(category, value);
  }

  Future<void> setNotifyOnlyWhenBackground(
    NotificationCategory category,
    bool value,
  ) async {
    final next = Map<NotificationCategory, bool>.from(
      _settings.notifyOnlyWhenBackground,
    );
    next[category] = value;
    _settings = _settings.copyWith(notifyOnlyWhenBackground: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setNotifyOnlyWhenAnotherSession(
    NotificationCategory category,
    bool value,
  ) async {
    final next = Map<NotificationCategory, bool>.from(
      _settings.notifyOnlyWhenAnotherSession,
    );
    next[category] = value;
    _settings = _settings.copyWith(notifyOnlyWhenAnotherSession: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundOnlyWhenBackground(
    NotificationCategory category,
    bool value,
  ) async {
    final next = Map<NotificationCategory, bool>.from(
      _settings.soundOnlyWhenBackground,
    );
    next[category] = value;
    _settings = _settings.copyWith(soundOnlyWhenBackground: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundOnlyWhenAnotherSession(
    NotificationCategory category,
    bool value,
  ) async {
    final next = Map<NotificationCategory, bool>.from(
      _settings.soundOnlyWhenAnotherSession,
    );
    next[category] = value;
    _settings = _settings.copyWith(soundOnlyWhenAnotherSession: next);
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundOption(
    SoundCategory category,
    SoundOption option, {
    String? source,
    String? label,
  }) async {
    final next = Map<SoundCategory, SoundOption>.from(_settings.sounds);
    final nextSources = Map<SoundCategory, String>.from(_settings.soundSources);
    final nextLabels = Map<SoundCategory, String>.from(_settings.soundLabels);
    next[category] = option;

    final normalizedSource = source?.trim();
    final normalizedLabel = label?.trim();
    if (option == SoundOption.systemChoice ||
        option == SoundOption.customFile) {
      if (normalizedSource != null && normalizedSource.isNotEmpty) {
        nextSources[category] = normalizedSource;
      }
      if (normalizedLabel != null && normalizedLabel.isNotEmpty) {
        nextLabels[category] = normalizedLabel;
      }
    }

    if (option == SoundOption.click ||
        option == SoundOption.alert ||
        option == SoundOption.systemDefault ||
        option == SoundOption.off) {
      nextSources.remove(category);
      nextLabels.remove(category);
    }

    _settings = _settings.copyWith(
      sounds: next,
      soundSources: nextSources,
      soundLabels: nextLabels,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> setSoundEnabledForNotification(
    NotificationCategory category,
    bool enabled,
  ) async {
    final soundCategory = soundCategoryForNotification(category);
    final current = soundFor(soundCategory);
    if (enabled) {
      if (current != SoundOption.off) {
        return;
      }
      final fallback =
          ExperienceSettings.defaults().sounds[soundCategory] ??
          SoundOption.alert;
      await setSoundOption(soundCategory, fallback);
      return;
    }
    if (current == SoundOption.off) {
      return;
    }
    await setSoundOption(soundCategory, SoundOption.off);
  }

  Future<void> previewSound(SoundCategory category) async {
    await _soundService.play(
      option: soundFor(category),
      source: soundSourceFor(category),
    );
  }

  bool shouldDispatchNotification(
    NotificationCategory category, {
    required bool isAppInForeground,
    required bool isAnotherSession,
  }) {
    if (!isNotificationEnabled(category)) {
      return false;
    }
    return _matchesOnlyWhenRule(
      onlyWhenBackground: notifyOnlyWhenBackground(category),
      onlyWhenAnotherSession: notifyOnlyWhenAnotherSession(category),
      isAppInForeground: isAppInForeground,
      isAnotherSession: isAnotherSession,
    );
  }

  bool shouldDispatchSound(
    NotificationCategory category, {
    required bool isAppInForeground,
    required bool isAnotherSession,
  }) {
    final soundCategory = soundCategoryForNotification(category);
    if (soundFor(soundCategory) == SoundOption.off) {
      return false;
    }
    return _matchesOnlyWhenRule(
      onlyWhenBackground: soundOnlyWhenBackground(category),
      onlyWhenAnotherSession: soundOnlyWhenAnotherSession(category),
      isAppInForeground: isAppInForeground,
      isAnotherSession: isAnotherSession,
    );
  }

  bool _matchesOnlyWhenRule({
    required bool onlyWhenBackground,
    required bool onlyWhenAnotherSession,
    required bool isAppInForeground,
    required bool isAnotherSession,
  }) {
    if (!onlyWhenBackground && !onlyWhenAnotherSession) {
      return true;
    }
    final backgroundMatch = onlyWhenBackground && !isAppInForeground;
    final anotherSessionMatch = onlyWhenAnotherSession && isAnotherSession;
    return backgroundMatch || anotherSessionMatch;
  }

  String? findShortcutConflict(ShortcutAction action, String binding) {
    final normalized = ShortcutBindingCodec.normalize(binding);
    if (normalized.isEmpty) {
      return null;
    }

    for (final entry in _settings.shortcuts.entries) {
      if (entry.key == action) {
        continue;
      }
      if (ShortcutBindingCodec.normalize(entry.value) == normalized) {
        final label = kShortcutDefinitions
            .where((item) => item.action == entry.key)
            .first
            .label;
        return label;
      }
    }
    return null;
  }

  Future<String?> updateShortcut(ShortcutAction action, String binding) async {
    final normalized = ShortcutBindingCodec.normalize(binding);
    if (normalized.isEmpty) {
      return 'Invalid shortcut';
    }

    final parsed = ShortcutBindingCodec.parse(normalized);
    if (parsed == null) {
      return 'Unsupported shortcut key';
    }

    final conflict = findShortcutConflict(action, normalized);
    if (conflict != null) {
      return 'Conflicts with "$conflict"';
    }

    final next = Map<ShortcutAction, String>.from(_settings.shortcuts);
    next[action] = normalized;
    _settings = _settings.copyWith(shortcuts: next);
    notifyListeners();
    await _persist();
    return null;
  }

  Future<void> clearShortcut(ShortcutAction action) async {
    final definition = kShortcutDefinitions
        .where((item) => item.action == action)
        .first;
    final next = Map<ShortcutAction, String>.from(_settings.shortcuts);
    next[action] = definition.defaultBinding;
    _settings = _settings.copyWith(shortcuts: next);
    notifyListeners();
    await _persist();
  }

  Future<void> resetAllShortcuts() async {
    final defaults = <ShortcutAction, String>{
      for (final definition in kShortcutDefinitions)
        definition.action: definition.defaultBinding,
    };
    _settings = _settings.copyWith(shortcuts: defaults);
    notifyListeners();
    await _persist();
  }

  Future<void> checkForUpdate() async {
    _checkingForUpdate = true;
    _lastCheckFoundNoUpdate = false;
    notifyListeners();
    try {
      final info = await PackageInfo.fromPlatform();
      _updateCheckService.clearCache();
      final result = await _updateCheckService.check(info.version);
      if (result != null &&
          result.isNewer &&
          result.latestVersion != _dismissedUpdateVersion) {
        _updateCheckResult = result;
        _lastCheckFoundNoUpdate = false;
      } else {
        _updateCheckResult = null;
        _lastCheckFoundNoUpdate = result != null;
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Update check failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _checkingForUpdate = false;
      notifyListeners();
    }
  }

  Future<void> dismissUpdate(String version) async {
    _dismissedUpdateVersion = version;
    _updateCheckResult = null;
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    await _localDataSource.saveDismissedUpdateVersion(version);
    notifyListeners();
  }

  /// Resets in-memory state to defaults (used after clearAll during app reset).
  void resetToDefaults() {
    _automaticUpdateCheckTimer?.cancel();
    _automaticUpdateCheckTimer = null;
    _settings = ExperienceSettings.defaults();
    _updateCheckResult = null;
    _dismissedUpdateVersion = null;
    _checkingForUpdate = false;
    _lastCheckFoundNoUpdate = false;
    _pendingStartupUpdateToast = false;
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    _initialized = false;
    _initFuture = null;
    unawaited(_syncAndroidBackgroundAlertRuntime());
    notifyListeners();
  }

  /// Begins the in-app update installation flow for the current platform.
  /// Android: downloads the APK then opens the system installer.
  /// Desktop: runs the install.cat shell script and signals "Restart to apply".
  /// Resetting to idle first lets AppShellPage clear its SnackBar guards on retry.
  Future<void> startInstall() async {
    if (_installState == UpdateInstallState.downloading ||
        _installState == UpdateInstallState.installing) {
      return;
    }
    final result = _updateCheckResult;
    if (result == null) {
      return;
    }

    // Reset to idle so AppShellPage observers can clear their snackbar guards.
    _installState = UpdateInstallState.idle;
    _installProgress = 0.0;
    notifyListeners();

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid) {
      await _installAndroid(result);
    } else {
      await _installDesktop();
    }
  }

  Future<void> _installAndroid(UpdateCheckResult result) async {
    final apkUrl = result.apkUrl;
    if (apkUrl == null) return;

    _installState = UpdateInstallState.downloading;
    _installProgress = 0.0;
    notifyListeners();

    String? destPath;
    try {
      final tmpDir = await getTemporaryDirectory();
      destPath = '${tmpDir.path}/codewalk-update.apk';
      // Use explicit timeouts; APK downloads can be large but should not hang forever.
      await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 10),
        ),
      ).download(
        apkUrl,
        destPath,
        onReceiveProgress: (received, total) {
          _installProgress = total > 0 ? received / total : 0.0;
          notifyListeners();
        },
      );
      _installState = UpdateInstallState.installing;
      notifyListeners();
      await OpenFilex.open(destPath);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'APK download failed',
        error: error,
        stackTrace: stackTrace,
      );
      // Clean up partial file so a retry does not open a corrupt APK.
      if (destPath != null) {
        try {
          final file = File(destPath);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
      _installState = UpdateInstallState.failed;
      notifyListeners();
    }
  }

  Future<void> _installDesktop() async {
    _installState = UpdateInstallState.installing;
    notifyListeners();

    try {
      final isWindows =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      // Wrap in a timeout so a stalled network does not hang indefinitely.
      ProcessResult processResult;
      if (isWindows) {
        processResult = await Process.run('powershell', [
          '-c',
          'irm install.cat/verseles/codewalk | iex',
        ]).timeout(const Duration(minutes: 5));
      } else {
        processResult = await Process.run('sh', [
          '-c',
          'curl -fsSL install.cat/verseles/codewalk | sh',
        ]).timeout(const Duration(minutes: 5));
      }
      _installState = processResult.exitCode == 0
          ? UpdateInstallState.done
          : UpdateInstallState.failed;
      if (processResult.exitCode != 0) {
        AppLogger.warn('Desktop install failed: ${processResult.stderr}');
      }
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Desktop install failed',
        error: error,
        stackTrace: stackTrace,
      );
      _installState = UpdateInstallState.failed;
    }
    notifyListeners();
  }

  Future<void> restartDesktopApp() async {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (!isDesktop) {
      return;
    }
    try {
      final executable = Platform.resolvedExecutable;
      final args = List<String>.from(Platform.executableArguments);
      await Process.start(executable, args, mode: ProcessStartMode.detached);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Desktop restart relaunch failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      exit(0);
    }
  }

  Future<void> _persist() async {
    try {
      await _localDataSource.saveExperienceSettingsJson(
        jsonEncode(_settings.toJson()),
      );
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to persist experience settings',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> syncNotificationsFromServerConfig() async {
    try {
      final response = await _dioClient.get<Map<String, dynamic>>('/config');
      final config = response.data;
      if (config == null) {
        return;
      }
      _applyServerNotificationConfig(config);
    } catch (_) {
      // Keep local values when server does not expose /config or fails.
    }
  }

  void _applyServerNotificationConfig(Map<String, dynamic> config) {
    var changed = false;
    final nextNotifications = Map<NotificationCategory, bool>.from(
      _settings.notifications,
    );

    for (final category in NotificationCategory.values) {
      _serverBackedNotifications[category] = false;
    }
    _serverConfigKeyByCategory.clear();

    bool bindDirectKey(NotificationCategory category, String key) {
      if (!config.containsKey(key)) {
        return false;
      }
      final value = config[key];
      if (value is bool) {
        nextNotifications[category] = value;
        changed = true;
      }
      _serverBackedNotifications[category] = true;
      _serverConfigKeyByCategory[category] = key;
      return true;
    }

    bindDirectKey(NotificationCategory.agent, 'settings-notifications-agent');
    bindDirectKey(
      NotificationCategory.permissions,
      'settings-notifications-permissions',
    );
    bindDirectKey(NotificationCategory.errors, 'settings-notifications-errors');

    final notificationsMap = config['notifications'];
    if (notificationsMap is Map) {
      void bindNested(NotificationCategory category, String key) {
        final value = notificationsMap[key];
        if (value is bool) {
          nextNotifications[category] = value;
          changed = true;
          _serverBackedNotifications[category] = true;
          _serverConfigKeyByCategory[category] = 'notifications.$key';
        }
      }

      bindNested(NotificationCategory.agent, 'agent');
      bindNested(NotificationCategory.permissions, 'permissions');
      bindNested(NotificationCategory.errors, 'errors');
    }

    if (changed) {
      _settings = _settings.copyWith(notifications: nextNotifications);
      notifyListeners();
      unawaited(_persist());
      unawaited(_syncAndroidBackgroundAlertRuntime());
    }
  }

  Future<void> _syncAndroidBackgroundAlertRuntime() async {
    final enabled =
        shouldRunAndroidBackgroundAlerts(_settings) &&
        !shouldDisableBackgroundNetworkForDataSaver(
          settings: _settings,
          isCellularTransport: _cellularDataSaverService.isCellularConnection,
        );
    await AndroidBackgroundAlertWorker.syncRegistration(enabled: enabled);
    if (!enabled) {
      await AndroidForegroundMonitorService.sync(
        enabled: false,
        activeSessionCount: 0,
      );
    }
  }

  Future<void> _syncNotificationToServer(
    NotificationCategory category,
    bool value,
  ) async {
    final key = _serverConfigKeyByCategory[category];
    if (key == null || key.isEmpty) {
      return;
    }
    try {
      if (key.startsWith('notifications.')) {
        final nested = key.substring('notifications.'.length);
        await _dioClient.patch<void>(
          '/config',
          data: <String, dynamic>{
            'notifications': <String, dynamic>{nested: value},
          },
        );
      } else {
        await _dioClient.patch<void>(
          '/config',
          data: <String, dynamic>{key: value},
        );
      }
    } catch (_) {
      // Server sync is best-effort; local value remains source of truth.
    }
  }

  String? _configuredModelKeyFromConfig(Map<String, dynamic> config) {
    return _configuredModelKeyFromRawValue(config['model']);
  }

  String? _configuredSmallModelKeyFromConfig(Map<String, dynamic> config) {
    return _configuredModelKeyFromRawValue(config['small_model']);
  }

  String? _configuredModelKeyFromRawValue(dynamic modelValue) {
    if (modelValue is String) {
      final normalized = modelValue.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (modelValue is Map) {
      final providerId =
          (modelValue['providerID'] ??
                  modelValue['providerId'] ??
                  modelValue['provider'])
              as String?;
      final modelId =
          (modelValue['modelID'] ?? modelValue['modelId'] ?? modelValue['id'])
              as String?;
      final normalizedProviderId = providerId?.trim();
      final normalizedModelId = modelId?.trim();
      if (normalizedProviderId == null ||
          normalizedProviderId.isEmpty ||
          normalizedModelId == null ||
          normalizedModelId.isEmpty) {
        return null;
      }
      return '$normalizedProviderId/$normalizedModelId';
    }
    return null;
  }

  String? _configuredAgentNameFromConfig(Map<String, dynamic> config) {
    final value =
        (config['default_agent'] ?? config['defaultAgent']) as String?;
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _configuredUsernameFromConfig(Map<String, dynamic> config) {
    final value = config['username'] as String?;
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _configuredSnapshotEnabledFromConfig(Map<String, dynamic> config) {
    final value = config['snapshot'];
    if (value is bool) {
      return value;
    }
    return true;
  }

  OpenCodeAutoupdateMode _configuredAutoupdateModeFromConfig(
    Map<String, dynamic> config,
  ) {
    final value = config['autoupdate'];
    if (value is bool) {
      return value
          ? OpenCodeAutoupdateMode.automatic
          : OpenCodeAutoupdateMode.disabled;
    }
    if (value is String && value.trim().toLowerCase() == 'notify') {
      return OpenCodeAutoupdateMode.notify;
    }
    return OpenCodeAutoupdateMode.automatic;
  }

  dynamic _encodeAutoupdateMode(OpenCodeAutoupdateMode mode) {
    return switch (mode) {
      OpenCodeAutoupdateMode.automatic => true,
      OpenCodeAutoupdateMode.notify => 'notify',
      OpenCodeAutoupdateMode.disabled => false,
    };
  }

  OpenCodeShareMode _configuredShareModeFromConfig(
    Map<String, dynamic> config,
  ) {
    final value = config['share'];
    if (value is! String) {
      return OpenCodeShareMode.manual;
    }
    return switch (value.trim().toLowerCase()) {
      'auto' => OpenCodeShareMode.automatic,
      'disabled' => OpenCodeShareMode.disabled,
      _ => OpenCodeShareMode.manual,
    };
  }

  String _encodeShareMode(OpenCodeShareMode mode) {
    return switch (mode) {
      OpenCodeShareMode.manual => 'manual',
      OpenCodeShareMode.automatic => 'auto',
      OpenCodeShareMode.disabled => 'disabled',
    };
  }

  List<OpenCodeDefaultModelOption> _buildOpenCodeDefaultModelOptions(
    Map<String, dynamic>? rawProviders, {
    required Iterable<String?> configuredModelKeys,
  }) {
    final normalizedConfiguredKeys = configuredModelKeys
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (rawProviders == null) {
      return normalizedConfiguredKeys.isEmpty
          ? const <OpenCodeDefaultModelOption>[]
          : normalizedConfiguredKeys
                .map(_fallbackModelOption)
                .toList(growable: false);
    }

    final parsed = ProvidersResponseModel.fromJson(rawProviders);
    final connectedProviderIds = parsed.connected.toSet();
    final options = <OpenCodeDefaultModelOption>[];

    for (final provider in parsed.providers) {
      for (final entry in provider.models.entries) {
        final model = entry.value;
        options.add(
          OpenCodeDefaultModelOption(
            key: '${provider.id}/${model.id}',
            providerId: provider.id,
            providerName: provider.name,
            modelId: model.id,
            modelName: model.name,
            connected: connectedProviderIds.contains(provider.id),
          ),
        );
      }
    }

    options.sort((a, b) {
      final byConnection = (b.connected ? 1 : 0).compareTo(a.connected ? 1 : 0);
      if (byConnection != 0) {
        return byConnection;
      }
      final byProvider = a.providerName.toLowerCase().compareTo(
        b.providerName.toLowerCase(),
      );
      if (byProvider != 0) {
        return byProvider;
      }
      return a.modelName.toLowerCase().compareTo(b.modelName.toLowerCase());
    });

    for (final configuredKey in normalizedConfiguredKeys.toList().reversed) {
      if (options.any((option) => option.key == configuredKey)) {
        continue;
      }
      options.insert(0, _fallbackModelOption(configuredKey));
    }

    return options;
  }

  List<String> _buildOpenCodeDefaultAgentOptions(
    List<dynamic>? rawAgents, {
    required String? configuredAgentName,
  }) {
    final options = <String>[];
    if (rawAgents != null) {
      for (final item in rawAgents) {
        if (item is! Map) {
          continue;
        }
        final agent = AgentModel.fromJson(Map<String, dynamic>.from(item));
        if (agent.hidden) {
          continue;
        }
        final mode = agent.mode.trim().toLowerCase();
        if (mode.isNotEmpty && mode != 'primary' && mode != 'all') {
          continue;
        }
        final normalizedName = agent.name.trim();
        if (normalizedName.isEmpty || options.contains(normalizedName)) {
          continue;
        }
        options.add(normalizedName);
      }
      options.sort((a, b) {
        final byPriority = _agentSortPriority(
          a,
        ).compareTo(_agentSortPriority(b));
        if (byPriority != 0) {
          return byPriority;
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    }

    if (configuredAgentName != null && !options.contains(configuredAgentName)) {
      options.insert(0, configuredAgentName);
    }

    return options;
  }

  int _agentSortPriority(String agentName) {
    switch (agentName.trim().toLowerCase()) {
      case 'build':
        return 0;
      case 'plan':
        return 1;
      default:
        return 2;
    }
  }

  OpenCodeDefaultModelOption _fallbackModelOption(String configuredModelKey) {
    final separatorIndex = configuredModelKey.indexOf('/');
    if (separatorIndex <= 0 ||
        separatorIndex >= configuredModelKey.length - 1) {
      return OpenCodeDefaultModelOption(
        key: configuredModelKey,
        providerId: configuredModelKey,
        providerName: 'Configured on server',
        modelId: configuredModelKey,
        modelName: configuredModelKey,
        connected: false,
      );
    }

    final providerId = configuredModelKey.substring(0, separatorIndex);
    final modelId = configuredModelKey.substring(separatorIndex + 1);
    return OpenCodeDefaultModelOption(
      key: configuredModelKey,
      providerId: providerId,
      providerName: providerId,
      modelId: modelId,
      modelName: modelId,
      connected: false,
    );
  }

  void _ensureConfiguredModelOption(String configuredModelKey) {
    if (_openCodeDefaultModelOptions.any(
      (option) => option.key == configuredModelKey,
    )) {
      return;
    }
    _openCodeDefaultModelOptions = <OpenCodeDefaultModelOption>[
      _fallbackModelOption(configuredModelKey),
      ..._openCodeDefaultModelOptions,
    ];
  }

  void _ensureConfiguredAgentOption(String configuredAgentName) {
    if (_openCodeDefaultAgentOptions.contains(configuredAgentName)) {
      return;
    }
    _openCodeDefaultAgentOptions = <String>[
      configuredAgentName,
      ..._openCodeDefaultAgentOptions,
    ];
  }

  @override
  void dispose() {
    _cellularDataSaverService.removeListener(_handleCellularDataSaverChanged);
    _automaticUpdateCheckTimer?.cancel();
    _automaticUpdateCheckTimer = null;
    super.dispose();
  }
}
