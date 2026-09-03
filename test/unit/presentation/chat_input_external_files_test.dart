import 'dart:typed_data';

import 'package:codewalk/presentation/widgets/chat_input/chat_input_external_files.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('composerFileFromBytes', () {
    test('preserves supported names and client bytes', () async {
      final file = composerFileFromBytes(
        _bytes(<int>[1, 2, 3]),
        name: 'photo.PNG',
        fallbackName: 'fallback',
      );

      expect(file, isNotNull);
      expect(file!.name, 'photo.PNG');
      expect(await file.length(), 3);
      expect(await file.readAsBytes(), _bytes(<int>[1, 2, 3]));
      expect(file.path, isNull);
    });

    test('uses MIME when a content URI has no usable name', () async {
      final file = composerFileFromBytes(
        _bytes(<int>[1, 2]),
        name: '42',
        fallbackName: 'Pasted file',
        mimeType: 'application/pdf',
      );

      expect(file?.name, '42.pdf');
      expect(await file?.readAsBytes(), _bytes(<int>[1, 2]));
    });

    test('rejects unsupported names and MIME types', () {
      expect(
        composerFileFromBytes(
          _bytes(<int>[1]),
          name: 'notes.txt',
          fallbackName: 'fallback',
          mimeType: 'text/plain',
        ),
        isNull,
      );
    });

    test('pre-gates unsupported names before reading bytes', () {
      expect(
        composerAttachmentNameOrMimeSupported('movie.mp4', 'video/mp4'),
        isFalse,
      );
      expect(
        composerAttachmentNameOrMimeSupported('opaque', 'application/pdf'),
        isTrue,
      );
    });
  });

  group('composerImageExtensionFromBytes', () {
    test('detects formats from their signatures', () {
      expect(
        composerImageExtensionFromBytes(_bytes([0x89, 0x50, 0x4E, 0x47, 0, 0])),
        'png',
      );
      expect(
        composerImageExtensionFromBytes(_bytes([0xFF, 0xD8, 0xFF, 0xE0])),
        'jpg',
      );
      expect(
        composerImageExtensionFromBytes(_bytes([0x47, 0x49, 0x46, 0x38])),
        'gif',
      );
      expect(
        composerImageExtensionFromBytes(_bytes([0x42, 0x4D, 0, 0])),
        'bmp',
      );
      expect(
        composerImageExtensionFromBytes(
          _bytes([
            0x52, 0x49, 0x46, 0x46, //
            0, 0, 0, 0,
            0x57, 0x45, 0x42, 0x50,
          ]),
        ),
        'webp',
      );
    });

    test('falls back to png for unrecognised bytes', () {
      expect(composerImageExtensionFromBytes(_bytes([1, 2, 3, 4])), 'png');
    });
  });

  group('composerFileFromImageBytes', () {
    test('names a pasted screenshot with the detected extension', () async {
      final file = composerFileFromImageBytes(
        _bytes([0xFF, 0xD8, 0xFF, 0xE0]),
        baseName: 'Pasted image',
      );

      expect(file, isNotNull);
      expect(file!.name, 'Pasted image.jpg');
      expect(await file.length(), 4);
      expect(await file.readAsBytes(), isNotEmpty);
    });

    test('ignores empty clipboard payloads', () {
      expect(
        composerFileFromImageBytes(_bytes(<int>[]), baseName: 'x'),
        isNull,
      );
    });
  });
}
