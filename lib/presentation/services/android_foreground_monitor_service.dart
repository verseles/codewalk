import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';

class AndroidForegroundMonitorService {
  static const MethodChannel _channel = MethodChannel('codewalk/system');
  static const String _notificationBody =
      'Reliable background alerts are active';

  static bool _running = false;

  static bool get isRunning => _running;

  static Future<void> sync({
    required bool enabled,
    required int activeSessionCount,
  }) async {
    if (!_isAndroidRuntime()) {
      return;
    }

    final normalizedCount = activeSessionCount < 0 ? 0 : activeSessionCount;
    final title = _titleForActiveSessionCount(normalizedCount);
    if (!enabled) {
      if (!_running) {
        return;
      }
      try {
        await _channel.invokeMethod<void>('stopForegroundService');
        _running = false;
      } catch (error, stackTrace) {
        // Reset so the next sync() call can retry the stop.
        _running = false;
        AppLogger.warn(
          'Failed to stop Android foreground monitor service',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    try {
      // Always invoke the channel call instead of deduplicating by count.
      // The native side is idempotent and this ensures the service is
      // restarted if Android killed it while the Dart statics were stale.
      await _channel
          .invokeMethod<void>('updateForegroundNotification', <String, String>{
            'title': title,
            'body':
                L10nBridge.current?.foregroundMonitorNotificationBody ??
                _notificationBody,
          });

      _running = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Failed to sync Android foreground monitor service',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool _isAndroidRuntime() {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android;
  }

  static String _titleForActiveSessionCount(int activeSessionCount) {
    final l10n = L10nBridge.current;
    if (activeSessionCount <= 0) {
      return l10n?.foregroundMonitorNotificationTitle ??
          'Background monitoring active';
    }
    if (activeSessionCount == 1) {
      return l10n?.foregroundMonitorNotificationOneSession ??
          'Monitoring one session';
    }
    return l10n?.foregroundMonitorNotificationSessionCount(
          activeSessionCount,
        ) ??
        'Monitoring $activeSessionCount sessions';
  }
}
