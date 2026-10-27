import 'package:flutter/material.dart';

/// The one way the app shows an in-app message (#160, #161, #212). The app
/// theme makes it float: a toast on compact windows, a bar of at most 420 dp
/// beside the end edge with a close button on wide ones. A message without
/// an action also closes when tapped, so none waits for its timeout; an
/// action such as Retry stays the message's own.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppSnackBar(
  ScaffoldMessengerState? messenger,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  int? maxLines,
}) {
  if (messenger == null || !messenger.mounted) return null;
  final text = Text(
    message,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
  );
  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      action: action,
      padding: action == null ? EdgeInsets.zero : null,
      content: action == null
          ? GestureDetector(
              key: const ValueKey('app-snack-bar-dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: messenger.hideCurrentSnackBar,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SizedBox(width: double.infinity, child: text),
              ),
            )
          : text,
    ),
  );
}
