import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

final StreamController<String> _tapController =
    StreamController<String>.broadcast();

Stream<String> get webNotificationTapStream => _tapController.stream;

bool _notificationsSupported() {
  return web.window.hasProperty('Notification'.toJS).toDart;
}

Future<bool> requestWebNotificationPermission() async {
  if (!_notificationsSupported()) {
    return false;
  }
  final permission = await web.Notification.requestPermission().toDart;
  final permissionText = permission.toDart;
  return permissionText == 'granted';
}

Future<bool> showWebNotification({
  required String title,
  required String body,
  required String payload,
}) async {
  if (!_notificationsSupported()) {
    return false;
  }
  if (web.Notification.permission != 'granted') {
    return false;
  }

  final notification = web.Notification(
    title,
    web.NotificationOptions(body: body),
  );
  notification.onclick = ((web.Event _) {
    web.window.focus();
    _tapController.add(payload);
    notification.close();
  }).toJS;
  return true;
}
