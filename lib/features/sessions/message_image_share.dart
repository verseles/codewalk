import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/message_image.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// The margin around a message in its image, on the theme's surface: the
/// agent's text has no card of its own (#540).
const messageImagePadding = 16.0;

/// The tallest and widest image, in pixels; a message too tall for them at
/// half its size is refused rather than cut.
const messageImageMaxHeight = 8192.0;
const messageImageMaxWidth = 4096.0;

/// The scale a message of [content] logical size is drawn at: the screen's,
/// up to 3, then smaller so the image fits; null when it cannot fit at half
/// size.
@visibleForTesting
double? messageImageRatio(Size content, {required double devicePixelRatio}) {
  final width = content.width + 2 * messageImagePadding;
  final height = content.height + 2 * messageImagePadding;
  final ratio = [
    min(devicePixelRatio, 3.0),
    messageImageMaxHeight / height,
    messageImageMaxWidth / width,
  ].reduce(min);
  return ratio < 0.5 ? null : ratio;
}

/// Draws [boundary] at [ratio] on [background], with the margin.
@visibleForTesting
Future<Uint8List?> captureMessageImage(
  RenderRepaintBoundary boundary, {
  required double ratio,
  required Color background,
}) async {
  final content = await boundary.toImage(pixelRatio: ratio);
  ui.Image? composed;
  try {
    final margin = messageImagePadding * ratio;
    final width = content.width + (2 * margin).round();
    final height = content.height + (2 * margin).round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = background,
      )
      ..drawImage(content, Offset(margin, margin), Paint());
    final picture = recorder.endRecording();
    composed = await picture.toImage(width, height);
    picture.dispose();
    final data = await composed.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    content.dispose();
    composed?.dispose();
  }
}

/// Whether this platform shares or saves a message's image; none without
/// a way to.
MessageImageMode messageImageMode(BuildContext context) =>
    Provider.of<MessageImageSink?>(context, listen: false)?.mode ??
    MessageImageMode.none;

/// Shares, or saves, the image of the message [context] is in: the nearest
/// repaint boundary above it, which holds the message alone.
Future<void> shareMessageImage(BuildContext context) async {
  final sink = Provider.of<MessageImageSink?>(context, listen: false);
  final boundary = context
      .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.v2L10n;
  final background = Theme.of(context).colorScheme.surface;
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  if (sink == null || boundary == null || !boundary.hasSize) {
    showAppSnackBar(messenger, l10n.messageImageFailed);
    return;
  }
  final ratio = messageImageRatio(
    boundary.size,
    devicePixelRatio: devicePixelRatio,
  );
  if (ratio == null) {
    showAppSnackBar(messenger, l10n.messageImageTooLong);
    return;
  }
  // The bar that ran this is gone from the next frame on.
  await WidgetsBinding.instance.endOfFrame;
  if (!boundary.attached) return;
  Uint8List? png;
  try {
    png = await captureMessageImage(
      boundary,
      ratio: ratio,
      background: background,
    );
  } on Object {
    png = null;
  }
  if (png == null || !boundary.attached) {
    showAppSnackBar(messenger, l10n.messageImageFailed);
    return;
  }
  final origin = boundary.localToGlobal(Offset.zero) & boundary.size;
  final outcome = await sink.deliver(
    png,
    fileName: messageImageFileName(DateTime.now()),
    origin: origin,
  );
  switch (outcome) {
    case MessageImageOutcome.saved:
      showAppSnackBar(messenger, l10n.messageImageSaved);
    case MessageImageOutcome.failed:
      showAppSnackBar(messenger, l10n.messageImageFailed);
    case MessageImageOutcome.shared || MessageImageOutcome.cancelled:
      break;
  }
}

/// `codewalk-message-YYYYMMDD-HHMMSS.png`, in local time.
@visibleForTesting
String messageImageFileName(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = at.toLocal();
  return 'codewalk-message-${local.year}${two(local.month)}${two(local.day)}'
      '-${two(local.hour)}${two(local.minute)}${two(local.second)}.png';
}
