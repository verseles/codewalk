import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/experience_settings.dart';
import '../services/sound_service.dart';
import '../utils/shortcut_binding_codec.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required AppLocalDataSource localDataSource,
    required DioClient dioClient,
    required SoundService soundService,
  }) : _localDataSource = localDataSource,
       _dioClient = dioClient,
       _soundService = soundService;

  final AppLocalDataSource _localDataSource;
  final DioClient _dioClient;
  final SoundService _soundService;

  ExperienceSettings _settings = ExperienceSettings.defaults();
  final Map<NotificationCategory, bool> _serverBackedNotifications =
      <NotificationCategory, bool>{
        NotificationCategory.agent: false,
        NotificationCategory.permissions: false,
        NotificationCategory.errors: false,
      };
  final Map<NotificationCategory, String> _serverConfigKeyByCategory =
      <NotificationCategory, String>{};
  bool _initialized = false;
  Future<void>? _initFuture;

  bool get initialized => _initialized;
  ExperienceSettings get settings => _settings;
  bool get hasAnyServerBackedNotificationCategory =>
      _serverBackedNotifications.values.any((value) => value);

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
    unawaited(syncNotificationsFromServerConfig());
    _initialized = true;
    notifyListeners();
  }

  bool isNotificationEnabled(NotificationCategory category) {
    return _settings.notifications[category] ?? true;
  }

  SoundOption soundFor(SoundCategory category) {
    return _settings.sounds[category] ?? SoundOption.off;
  }

  String bindingFor(ShortcutAction action) {
    return _settings.shortcuts[action] ??
        kShortcutDefinitions
            .where((definition) => definition.action == action)
            .first
            .defaultBinding;
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
    await _syncNotificationToServer(category, value);
  }

  Future<void> setSoundOption(
    SoundCategory category,
    SoundOption option,
  ) async {
    final next = Map<SoundCategory, SoundOption>.from(_settings.sounds);
    next[category] = option;
    _settings = _settings.copyWith(sounds: next);
    notifyListeners();
    await _persist();
  }

  Future<void> previewSound(SoundCategory category) async {
    await _soundService.play(soundFor(category));
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
}
