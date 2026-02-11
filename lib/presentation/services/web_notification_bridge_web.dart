import 'dart:async';
import 'dart:html' as html;

final StreamController<String> _tapController =
    StreamController<String>.broadcast();

Stream<String> get webNotificationTapStream => _tapController.stream;

Future<bool> requestWebNotificationPermission() async {
  if (!html.Notification.supported) {
    return false;
  }
  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

Future<bool> showWebNotification({
  required String title,
  required String body,
  required String payload,
}) async {
  if (!html.Notification.supported) {
    return false;
  }
  if (html.Notification.permission != 'granted') {
    return false;
  }

  final notification = html.Notification(title, body: body);
  notification.onClick.listen((_) {
    html.window.focus();
    _tapController.add(payload);
    notification.close();
  });
  return true;
}
