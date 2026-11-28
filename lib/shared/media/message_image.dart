import 'dart:typed_data';
import 'dart:ui';

/// How this platform hands a message's image over (#540).
enum MessageImageMode {
  /// The system share sheet receives the PNG file.
  share,

  /// A save dialog writes the PNG where the user chooses (Linux, whose
  /// share sheet takes no files).
  save,

  /// Not offered here.
  none,
}

/// What became of a message's image.
enum MessageImageOutcome { shared, saved, cancelled, failed }

/// Hands a message's PNG to the platform: its share sheet or a save dialog.
abstract interface class MessageImageSink {
  MessageImageMode get mode;

  /// Delivers [png] as [fileName]; [origin] anchors the share sheet where
  /// the platform needs one (macOS), in global coordinates.
  Future<MessageImageOutcome> deliver(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  });
}
