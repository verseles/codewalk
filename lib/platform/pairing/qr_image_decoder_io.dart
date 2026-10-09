import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:image/image.dart' as image;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';

/// Limits precede rasterization; the worker owns both image and barcode parsing.
final class QrImageDecodeTask implements QrInputTask {
  QrImageDecodeTask(
    Uint8List bytes, {
    Duration deadline = const Duration(seconds: 5),
  }) {
    _timer = Timer(
      deadline,
      () => _finish(error: const QrInputException(QrInputFailure.timedOut)),
    );
    _messages.listen((message) {
      if (message == null) {
        if (!_terminal) {
          _finish(error: const QrInputException(QrInputFailure.unreadable));
        }
        _closePorts();
      } else if (message is List) {
        _finish(error: const QrInputException(QrInputFailure.unreadable));
      } else if (message is String) {
        _finish(value: message);
      } else if (message is int &&
          message >= 0 &&
          message < QrInputFailure.values.length) {
        _finish(error: QrInputException(QrInputFailure.values[message]));
      }
    });
    _start(bytes);
  }
  static const maxBytes = 8 * 1024 * 1024;
  static const maxPixels = 4 * 1024 * 1024;
  final _complete = Completer<String?>();
  final _messages = ReceivePort();
  String? _value;
  QrInputException? _error;
  Isolate? _isolate;
  Timer? _timer;
  bool _terminal = false;
  bool _portsClosed = false;
  @override
  Future<String?> get result => _complete.future;
  Future<void> _start(Uint8List bytes) async {
    try {
      if (bytes.isEmpty || bytes.length > maxBytes) {
        _finish(error: const QrInputException(QrInputFailure.tooLarge));
        _closePorts();
        return;
      }
      final isolate = await Isolate.spawn(
        _decode,
        (_messages.sendPort, TransferableTypedData.fromList([bytes])),
        onExit: _messages.sendPort,
        onError: _messages.sendPort,
        errorsAreFatal: true,
      );
      _isolate = isolate;
      if (_terminal) isolate.kill(priority: Isolate.immediate);
    } on Object {
      _finish(error: const QrInputException(QrInputFailure.unreadable));
      _closePorts();
    }
  }

  void _finish({String? value, QrInputException? error}) {
    if (_terminal) return;
    _terminal = true;
    _timer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    _value = value;
    _error = error;
  }

  void _closePorts() {
    if (_portsClosed) return;
    _portsClosed = true;
    _messages.close();
    final error = _error;
    if (error != null) {
      _complete.completeError(error);
    } else {
      _complete.complete(_value);
    }
  }

  @override
  void cancel() => _finish();

  static void _decode((SendPort, TransferableTypedData) input) {
    final (send, transferred) = input;
    try {
      final bytes = transferred.materialize().asUint8List();
      final image.Image? raster;
      if (bytes.length >= 24 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        final header = ByteData.sublistView(bytes);
        _dimensions(header.getUint32(16), header.getUint32(20));
        final decoder = image.PngDecoder();
        final info = decoder.startDecode(bytes);
        if (info == null || info.numFrames != 1) {
          throw const QrInputException(QrInputFailure.unreadable);
        }
        _dimensions(info.width, info.height);
        raster = decoder.decodeFrame(0);
      } else if (bytes.length >= 4 && bytes[0] == 255 && bytes[1] == 216) {
        // JPEG startDecode prepares coefficient matrices. Validate SOF with a
        // bounded cursor before the library can allocate from untrusted sizes.
        _jpegHeader(bytes);
        raster = image.JpegDecoder().decode(bytes);
      } else {
        throw const QrInputException(QrInputFailure.unreadable);
      }
      if (raster == null) {
        throw const QrInputException(QrInputFailure.unreadable);
      }
      _dimensions(raster.width, raster.height);
      final rgba = raster.convert(
        format: image.Format.uint8,
        numChannels: 4,
        noAnimation: true,
      );
      final pixels = Uint32List(rgba.width * rgba.height);
      var i = 0;
      for (final pixel in rgba) {
        final alpha = pixel.a.toInt();
        int white(num channel) =>
            (channel.toInt() * alpha + 255 * (255 - alpha) + 127) ~/ 255;
        pixels[i++] =
            (white(pixel.r) << 16) | (white(pixel.g) << 8) | white(pixel.b);
      }
      final text = QRCodeReader()
          .decode(
            BinaryBitmap(
              HybridBinarizer(
                RGBLuminanceSource(rgba.width, rgba.height, pixels),
              ),
            ),
          )
          .text;
      if (text.isEmpty || text.length > 4096) {
        throw const QrInputException(QrInputFailure.tooLarge);
      }
      send.send(text);
    } on QrInputException catch (error) {
      send.send(error.failure.index);
    } on ReaderException {
      send.send(QrInputFailure.noCode.index);
    } on Object {
      send.send(QrInputFailure.unreadable.index);
    }
  }

  static void _dimensions(int width, int height) {
    if (width <= 0 ||
        height <= 0 ||
        width > 4096 ||
        height > 4096 ||
        width > maxPixels ~/ height) {
      throw const QrInputException(QrInputFailure.tooLarge);
    }
  }

  /// Single-frame, 8-bit Huffman JPEG admission. Multiple progressive SOS scans
  /// are allowed; entropy stuffing and restart markers have no segment length.
  static void _jpegHeader(Uint8List bytes) {
    var offset = 2;
    var entropy = false;
    var frame = false;
    var scanned = false;
    var progressive = false;
    final components = <int>{};
    const invalid = QrInputException(QrInputFailure.unreadable);
    int word(int at) => (bytes[at] << 8) | bytes[at + 1];
    while (offset < bytes.length) {
      if (bytes[offset] != 255) {
        if (!entropy) throw invalid;
        offset++;
        continue;
      }
      var fill = 0;
      while (offset < bytes.length && bytes[offset] == 255) {
        offset++;
        fill++;
      }
      if (offset >= bytes.length) throw invalid;
      final marker = bytes[offset++];
      if (marker == 0) {
        if (!entropy || fill != 1) throw invalid;
        continue;
      }
      if (marker >= 0xd0 && marker <= 0xd7) {
        if (!entropy) throw invalid;
        continue;
      }
      entropy = false;
      if (marker == 0xd9) {
        if (!frame || !scanned || offset != bytes.length) throw invalid;
        return;
      }
      final sof = marker == 0xc0 || marker == 0xc1 || marker == 0xc2;
      if (!sof &&
          marker != 0xda &&
          marker != 0xdb &&
          marker != 0xc4 &&
          marker != 0xdd &&
          marker != 0xfe &&
          !(marker >= 0xe0 && marker <= 0xef)) {
        throw invalid;
      }
      if (offset + 2 > bytes.length) throw invalid;
      final length = word(offset);
      if (length < 2 || length > bytes.length - offset) throw invalid;
      final end = offset + length;
      if (sof) {
        if (frame || length < 8 || bytes[offset + 2] != 8) throw invalid;
        _dimensions(word(offset + 5), word(offset + 3));
        final count = bytes[offset + 7];
        if (!{1, 3, 4}.contains(count) || length != 8 + 3 * count) {
          throw invalid;
        }
        for (var i = 0; i < count; i++) {
          final at = offset + 8 + 3 * i;
          final sampling = bytes[at + 1];
          if (!components.add(bytes[at]) ||
              (sampling >> 4) == 0 ||
              (sampling >> 4) > 4 ||
              (sampling & 15) == 0 ||
              (sampling & 15) > 4 ||
              bytes[at + 2] > 3) {
            throw invalid;
          }
        }
        frame = true;
        progressive = marker == 0xc2;
      } else if (marker == 0xda) {
        if (!frame || length < 6) throw invalid;
        final count = bytes[offset + 2];
        if (count < 1 || count > components.length || length != 6 + 2 * count) {
          throw invalid;
        }
        final selected = <int>{};
        for (var i = 0; i < count; i++) {
          final at = offset + 3 + 2 * i;
          if (!components.contains(bytes[at]) ||
              !selected.add(bytes[at]) ||
              (bytes[at + 1] >> 4) > 3 ||
              (bytes[at + 1] & 15) > 3) {
            throw invalid;
          }
        }
        final ss = bytes[end - 3],
            se = bytes[end - 2],
            successive = bytes[end - 1];
        if (!progressive) {
          if (ss != 0 || se != 63 || successive != 0) throw invalid;
        } else if (ss > 63 ||
            se > 63 ||
            ss > se ||
            (ss == 0 && se != 0) ||
            (ss != 0 && count != 1) ||
            (successive >> 4) > 13 ||
            (successive & 15) > 13) {
          throw invalid;
        }
        scanned = true;
        entropy = true;
      } else if (marker == 0xdd && length != 4) {
        throw invalid;
      }
      offset = end;
    }
    throw invalid;
  }
}
