import 'dart:typed_data';
import 'dart:ui';

import '../../shared/media/message_image.dart';

MessageImageSink createMessageImageSink() => const _NoMessageImages();

final class _NoMessageImages implements MessageImageSink {
  const _NoMessageImages();

  @override
  MessageImageMode get mode => MessageImageMode.none;

  @override
  Future<MessageImageOutcome> deliver(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  }) async => MessageImageOutcome.failed;
}
