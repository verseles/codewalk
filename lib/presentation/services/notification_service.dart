import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/logging/app_logger.dart';
import 'web_notification_bridge.dart';

class NotificationTapPayload {
  const NotificationTapPayload({required this.category, this.sessionId});

  final String category;
  final String? sessionId;

  String toRaw() {
    return jsonEncode(<String, dynamic>{
      'category': category,
      'sessionId': sessionId,
    });
  }

  static NotificationTapPayload? fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final category = decoded['category']?.toString().trim();
      if (category == null || category.isEmpty) {
        return null;
      }
      final sessionId = decoded['sessionId']?.toString().trim();
      return NotificationTapPayload(
        category: category,
        sessionId: (sessionId?.isEmpty ?? true) ? null : sessionId,
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTapPayload> _tapController =
      StreamController<NotificationTapPayload>.broadcast();
  bool _initialized = false;
  NotificationTapPayload? _pendingTap;
  StreamSubscription<String>? _webTapSubscription;

  Stream<NotificationTapPayload> get onNotificationTapped =>
      _tapController.stream;

  NotificationTapPayload? consumePendingTap() {
    final pending = _pendingTap;
    _pendingTap = null;
    return pending;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      if (kIsWeb) {
        _webTapSubscription ??= webNotificationTapStream.listen(_handleRawTap);
        _initialized = true;
        return;
      }

      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const macos = DarwinInitializationSettings();
      const linux = LinuxInitializationSettings(defaultActionName: 'Open');
      const windows = WindowsInitializationSettings(
        appName: 'CodeWalk',
        appUserModelId: 'com.codewalk.app',
        guid: '1f111f3e-6f5e-4fca-9ba2-2c9f8f9ddc7a',
      );
      const settings = InitializationSettings(
        android: android,
        macOS: macos,
        linux: linux,
        windows: windows,
      );

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          _handleRawTap(response.payload);
        },
      );

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

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _handleRawTap(launchDetails?.notificationResponse?.payload);
      }

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
    String? sessionId,
  }) async {
    final payload = NotificationTapPayload(
      category: category,
      sessionId: sessionId,
    ).toRaw();

    if (kIsWeb) {
      await initialize();
      final granted = await requestWebNotificationPermission();
      if (!granted) {
        AppLogger.info('Web notification permission denied: $title');
        return false;
      }
      return showWebNotification(title: title, body: body, payload: payload);
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
        id: DateTime.now().microsecondsSinceEpoch % 100000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
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

  void _handleRawTap(String? rawPayload) {
    final payload = NotificationTapPayload.fromRaw(rawPayload);
    if (payload == null) {
      return;
    }
    _pendingTap = payload;
    if (!_tapController.isClosed) {
      _tapController.add(payload);
    }
  }
}
