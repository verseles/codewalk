import 'dart:async';

import 'web_notification_bridge_stub.dart'
    if (dart.library.html) 'web_notification_bridge_web.dart'
    as impl;

Stream<String> get webNotificationTapStream => impl.webNotificationTapStream;

Future<bool> requestWebNotificationPermission() {
  return impl.requestWebNotificationPermission();
}

Future<bool> showWebNotification({
  required String title,
  required String body,
  required String payload,
}) {
  return impl.showWebNotification(title: title, body: body, payload: payload);
}
