import 'dart:async';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/chat_realtime.dart';
import '../../domain/entities/experience_settings.dart';
import '../providers/settings_provider.dart';
import '../utils/chat_event_property_extractors.dart';
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

  /// Dismiss all active notifications for [sessionId].
  ///
  /// Called reactively when a triggering event is resolved (e.g. the last
  /// pending permission/question for a session is replied, or the user opens
  /// a session that just completed). This prevents stale notifications from
  /// lingering after the user has already handled the underlying request.
  /// Errors are swallowed intentionally: this is a fire-and-forget cleanup
  /// called via `unawaited()` from the event reducer, so a notification-layer
  /// failure must not crash the app or leave an unhandled async error.
  Future<void> dismissForSession(String sessionId) async {
    final task = AppLogger.beginTask(
      'notification_dismiss',
      tags: const <String>{'notification:dismiss'},
      context: <String, Object?>{
        'sessionId': AppLogger.safeContextId(sessionId),
      },
    );
    try {
      await _notificationService.clearNotificationsForSession(sessionId);
      task.end();
    } catch (error, stackTrace) {
      task.end(status: 'error', error: error, stackTrace: stackTrace);
      AppLogger.warn(
        'dismissForSession failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> handle(
    ChatEvent event, {
    String? sessionTitleHint,
    bool isRootSession = true,
    bool isAppInForeground = true,
    String? currentSessionId,
    String? serverId,
  }) async {
    final signal = _signalForEvent(
      event,
      sessionTitleHint: sessionTitleHint,
      isRootSession: isRootSession,
    );
    if (signal == null) {
      return;
    }

    final isAnotherSession = _resolveIsAnotherSession(
      eventSessionId: signal.sessionId,
      currentSessionId: currentSessionId,
    );

    final shouldNotify = _settingsProvider.shouldDispatchNotification(
      signal.notificationCategory,
      isAppInForeground: isAppInForeground,
      isAnotherSession: isAnotherSession,
    );
    final shouldSound = _settingsProvider.shouldDispatchSound(
      signal.notificationCategory,
      isAppInForeground: isAppInForeground,
      isAnotherSession: isAnotherSession,
    );
    if (!shouldNotify && !shouldSound) {
      return;
    }

    final now = DateTime.now();
    _lastDispatchByCategory.removeWhere(
      (_, dispatchedAt) =>
          now.difference(dispatchedAt) >= const Duration(seconds: 1),
    );
    final dispatchKey = '${signal.categoryKey}:${signal.sessionId ?? '-'}';
    final last = _lastDispatchByCategory[dispatchKey];
    if (last != null && now.difference(last) < const Duration(seconds: 1)) {
      return;
    }
    _lastDispatchByCategory[dispatchKey] = now;

    final soundOption = _settingsProvider.soundFor(signal.soundCategory);
    final soundSource = _settingsProvider.soundSourceFor(signal.soundCategory);

    if (shouldNotify) {
      unawaited(
        _notificationService.notify(
          title: signal.title,
          body: signal.body,
          category: signal.categoryKey,
          sessionId: signal.sessionId,
          serverId: serverId,
          directory: signal.directory,
          sessionTitle: signal.sessionTitle,
          playSound: shouldSound && !isAppInForeground,
          soundOption: soundOption,
          soundSource: soundSource,
        ),
      );
    }

    if (!shouldSound || !isAppInForeground) {
      return;
    }

    final played = await _soundService.play(
      option: soundOption,
      source: soundSource,
    );
    if (!played && soundOption != SoundOption.off) {
      AppLogger.info('Sound fallback active for ${signal.categoryKey}');
    }
  }

  bool _resolveIsAnotherSession({
    required String? eventSessionId,
    required String? currentSessionId,
  }) {
    final eventId = eventSessionId?.trim();
    final currentId = currentSessionId?.trim();
    if (eventId == null || eventId.isEmpty) {
      return true;
    }
    if (currentId == null || currentId.isEmpty) {
      return true;
    }
    return eventId != currentId;
  }

  _FeedbackSignal? _signalForEvent(
    ChatEvent event, {
    String? sessionTitleHint,
    required bool isRootSession,
  }) {
    final properties = event.properties;
    final sessionId = extractEventSessionId(properties);
    final directory = extractEventDirectory(properties);
    final sessionTitle = _extractSessionTitle(
      properties,
      sessionTitleHint: sessionTitleHint,
    );
    final l10n = L10nBridge.current;
    switch (event.type) {
      case 'permission.asked':
      case 'permission.updated':
      case 'permission.v2.asked':
      case 'permission.v2.updated':
      case 'question.asked':
      case 'question.updated':
      case 'question.v2.asked':
      case 'question.v2.updated':
        return _FeedbackSignal(
          notificationCategory: NotificationCategory.permissions,
          soundCategory: SoundCategory.permissions,
          categoryKey: 'permissions',
          title: sessionTitle ?? (l10n?.notificationSession ?? 'Session'),
          sessionTitle: sessionTitle,
          body:
              l10n?.notificationPermissionOrQuestionNeedsInput ??
              'A tool permission or question needs your input.',
          sessionId: sessionId,
          directory: directory,
        );
      case 'session.error':
        return _FeedbackSignal(
          notificationCategory: NotificationCategory.errors,
          soundCategory: SoundCategory.errors,
          categoryKey: 'errors',
          title: sessionTitle ?? (l10n?.notificationSession ?? 'Session'),
          sessionTitle: sessionTitle,
          body:
              l10n?.notificationSessionError ?? 'A session reported an error.',
          sessionId: sessionId,
          directory: directory,
        );
      case 'session.idle':
        if (!isRootSession) {
          return null;
        }
        return _FeedbackSignal(
          notificationCategory: NotificationCategory.agent,
          soundCategory: SoundCategory.agent,
          categoryKey: 'agent',
          title: sessionTitle ?? (l10n?.notificationSession ?? 'Session'),
          sessionTitle: sessionTitle,
          body:
              l10n?.notificationAgentFinished ??
              'Agent finished the current response.',
          sessionId: sessionId,
          directory: directory,
        );
      default:
        return null;
    }
  }

  String? _extractSessionTitle(
    Map<String, dynamic> properties, {
    String? sessionTitleHint,
  }) {
    String? readTitle(Map<dynamic, dynamic> source) {
      final sessionTitle = source['sessionTitle']?.toString().trim();
      if (sessionTitle != null && sessionTitle.isNotEmpty) {
        return sessionTitle;
      }
      final title = source['title']?.toString().trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
      return null;
    }

    final direct = readTitle(properties);
    if (direct != null) {
      return direct;
    }

    final info = properties['info'];
    if (info is Map) {
      final nested = readTitle(info);
      if (nested != null) {
        return nested;
      }
    }

    // Parity with extractEventSessionId: v2 permission/question events place
    // the authoritative payload under `request`; `session` may carry the full
    // session object.
    for (final key in const <String>[
      'request',
      'permission',
      'question',
      'session',
      'part',
    ]) {
      final nested = properties[key];
      if (nested is Map) {
        final title = readTitle(nested);
        if (title != null) {
          return title;
        }
      }
    }

    final normalizedHint = sessionTitleHint?.trim();
    if (normalizedHint != null && normalizedHint.isNotEmpty) {
      return normalizedHint;
    }
    return null;
  }
}

class _FeedbackSignal {
  const _FeedbackSignal({
    required this.notificationCategory,
    required this.soundCategory,
    required this.categoryKey,
    required this.title,
    required this.body,
    this.sessionId,
    this.directory,
    this.sessionTitle,
  });

  final NotificationCategory notificationCategory;
  final SoundCategory soundCategory;
  final String categoryKey;
  final String title;
  final String body;
  final String? sessionId;
  final String? directory;
  final String? sessionTitle;
}
