import 'dart:io';
import 'dart:typed_data';

/// Creates a capture once, even when multiple writers target the same path.
void writeParityCapture(File destination, Uint8List bytes) {
  destination.createSync(exclusive: true);
  destination.writeAsBytesSync(bytes);
}
