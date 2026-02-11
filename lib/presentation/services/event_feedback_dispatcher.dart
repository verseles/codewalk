import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/experience_settings.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';
import 'sound_service.dart';

class EventFeedbackDispatcher {
  EventFeedbackDispatcher({
    required SettingsProvider settingsProvider,
    required NotificationService notificationService,
    required SoundService soundService,
  }) : _settingsProvider = settingsProvider,
       _notificationService = notificationService,
       _soundService = soundService;

  final SettingsProvider _settingsProvider;
  final NotificationService _notificationService;
  final SoundService _soundService;
  final Map<String, DateTime> _lastDispatchByCategory = <String, DateTime>{};

  Future<void> handle(ChatEvent event) async {
    final signal = _signalForEvent(event);
    if (signal == null) {
      return;
    }

    final now = DateTime.now();
    final last = _lastDispatchByCategory[signal.categoryKey];
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _lastDispatchByCategory[signal.categoryKey] = now;

    if (_settingsProvider.isNotificationEnabled(signal.notificationCategory)) {
      unawaited(
        _notificationService.notify(
          title: signal.title,
          body: signal.body,
          category: signal.categoryKey,
        ),
      );
    }

    final sound = _settingsProvider.soundFor(signal.soundCategory);
    final played = await _soundService.play(sound);
    if (!played && sound != SoundOption.off) {
      AppLogger.info('Sound fallback active for ${signal.categoryKey}');
    }
  }

  _FeedbackSignal? _signalForEvent(ChatEvent event) {
    switch (event.type) {
      case 'permission.asked':
      case 'question.asked':
      case 'question.updated':
        return const _FeedbackSignal(
          notificationCategory: NotificationCategory.permissions,
          soundCategory: SoundCategory.permissions,
          categoryKey: 'permissions',
          title: 'Action required',
          body: 'A tool permission or question needs your input.',
        );
      case 'session.error':
        return const _FeedbackSignal(
          notificationCategory: NotificationCategory.errors,
          soundCategory: SoundCategory.errors,
          categoryKey: 'errors',
          title: 'Session error',
          body: 'The current session reported an error.',
        );
      case 'session.idle':
        return const _FeedbackSignal(
          notificationCategory: NotificationCategory.agent,
          soundCategory: SoundCategory.agent,
          categoryKey: 'agent',
          title: 'Response ready',
          body: 'Agent finished the current response.',
        );
      default:
        return null;
    }
  }
}

class _FeedbackSignal {
  const _FeedbackSignal({
    required this.notificationCategory,
    required this.soundCategory,
    required this.categoryKey,
    required this.title,
    required this.body,
  });

  final NotificationCategory notificationCategory;
  final SoundCategory soundCategory;
  final String categoryKey;
  final String title;
  final String body;
}
