import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/logging/app_logger.dart';
import '../../data/datasources/app_local_datasource.dart';
import '../../domain/entities/experience_settings.dart';
import '../services/sound_service.dart';
import '../utils/shortcut_binding_codec.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required AppLocalDataSource localDataSource,
    required SoundService soundService,
  }) : _localDataSource = localDataSource,
       _soundService = soundService;

  final AppLocalDataSource _localDataSource;
  final SoundService _soundService;

  ExperienceSettings _settings = ExperienceSettings.defaults();
  bool _initialized = false;
  Future<void>? _initFuture;

  bool get initialized => _initialized;
  ExperienceSettings get settings => _settings;

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
}
