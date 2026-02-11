import 'dart:async';

final StreamController<String> _tapController =
    StreamController<String>.broadcast();

Stream<String> get webNotificationTapStream => _tapController.stream;

Future<bool> requestWebNotificationPermission() async => false;

Future<bool> showWebNotification({
  required String title,
  required String body,
  required String payload,
}) async {
  return false;
}
