import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk/platform/pairing/qr_image_decoder_io.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test(
    'tiny JPEG SOF rejects excessive dimensions before the allocating decoder',
    () async {
      final bytes = Uint8List.fromList([
        0xff,
        0xd8,
        0xff,
        0xc0,
        0,
        11,
        8,
        0xff,
        0xff,
        0xff,
        0xff,
        1,
        1,
        0x11,
        0,
        0xff,
        0xd9,
      ]);
      await expectLater(
        QrImageDecodeTask(bytes).result,
        throwsA(
          isA<QrInputException>().having(
            (e) => e.failure,
            'failure',
            QrInputFailure.tooLarge,
          ),
        ),
      );
    },
  );
  test(
    'bounded baseline JPEG still decodes the independent QR payload',
    () async {
      final source = image.decodePng(
        await File('test/v2/pairing/fixtures/reference_qr.png').readAsBytes(),
      )!;
      final bytes = image.encodeJpg(source, quality: 95);
      expect(
        await QrImageDecodeTask(bytes).result,
        r'MEBKM:URL:http\://en.wikipedia.org/wiki/Main_Page;;',
      );
    },
  );
  test(
    'independent upstream black-box QR decodes exact published payload',
    () async {
      final bytes = await File(
        'test/v2/pairing/fixtures/reference_qr.png',
      ).readAsBytes();
      expect(
        await QrImageDecodeTask(bytes).result,
        r'MEBKM:URL:http\://en.wikipedia.org/wiki/Main_Page;;',
      );
    },
  );
  test(
    'oversized raster in small PNG header is rejected before raster decode',
    () async {
      final header = Uint8List(24)
        ..setAll(0, [137, 80, 78, 71, 13, 10, 26, 10]);
      ByteData.sublistView(header)
        ..setUint32(16, 100000)
        ..setUint32(20, 100000);
      await expectLater(
        QrImageDecodeTask(header).result,
        throwsA(
          isA<QrInputException>().having(
            (e) => e.failure,
            'failure',
            QrInputFailure.tooLarge,
          ),
        ),
      );
    },
  );
  test('cancellation during spawn completes only after worker exit', () async {
    final bytes = await File(
      'test/v2/pairing/fixtures/reference_qr.png',
    ).readAsBytes();
    final task = QrImageDecodeTask(bytes);
    task.cancel();
    expect(await task.result, isNull);
    expect(await QrImageDecodeTask(bytes).result, isNotEmpty);
  });
}
