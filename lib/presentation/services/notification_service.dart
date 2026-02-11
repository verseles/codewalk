import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/logging/app_logger.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const macos = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, macOS: macos);

      await _plugin.initialize(settings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();

      final macOsPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macOsPlugin?.requestPermissions(
        alert: true,
        badge: false,
        sound: true,
      );

      _initialized = true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Notification initialization unavailable on this platform',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> notify({
    required String title,
    required String body,
    required String category,
  }) async {
    if (kIsWeb) {
      AppLogger.info('Web notification fallback: $title - $body');
      return false;
    }

    await initialize();

    if (!_initialized) {
      return false;
    }

    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'codewalk_$category',
          'CodeWalk $category',
          channelDescription: 'CodeWalk $category notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        macOS: const DarwinNotificationDetails(),
      );

      await _plugin.show(
        DateTime.now().microsecondsSinceEpoch % 100000,
        title,
        body,
        details,
      );
      return true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Notification dispatch failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
