import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import 'qr_camera_page.dart';
import 'qr_image_decoder_io.dart';

QrInput createQrInput(GlobalKey<NavigatorState> navigator) =>
    _NativeInput(navigator);

final class _NativeInput implements QrInput {
  _NativeInput(this.navigator);
  final GlobalKey<NavigatorState> navigator;
  Future<void> _tail = Future.value();
  QrInputTask _queue(QrInputTask Function() create) {
    final task = _QueuedTask(_tail, create);
    _tail = task.result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return task;
  }

  @override
  bool get cameraAvailable => Platform.isAndroid;
  @override
  QrInputTask image() => _queue(_ImageTask.new);
  @override
  QrInputTask camera() =>
      _queue(() => CameraQrTask(navigator, supported: cameraAvailable));
}

final class _QueuedTask implements QrInputTask {
  _QueuedTask(Future<void> previous, QrInputTask Function() create) {
    result = previous.then((_) {
      if (_cancelled) return null;
      final task = _active = create();
      return task.result;
    });
  }
  bool _cancelled = false;
  QrInputTask? _active;
  @override
  late final Future<String?> result;
  @override
  void cancel() {
    _cancelled = true;
    _active?.cancel();
  }
}

final class _ImageTask implements QrInputTask {
  _ImageTask() {
    result = _run();
  }
  bool _cancelled = false;
  QrInputTask? _decode;
  StreamIterator<Uint8List>? _reader;
  @override
  late final Future<String?> result;
  @override
  void cancel() {
    _cancelled = true;
    _decode?.cancel();
    _reader?.cancel().catchError((Object _) {});
  }

  Future<String?> _run() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (_cancelled || picked == null) return null;
    if (!{'file', 'content'}.contains(picked.uri.scheme) ||
        !{'png', 'jpg', 'jpeg'}.contains(picked.extension?.toLowerCase())) {
      throw const QrInputException(QrInputFailure.unreadable);
    }
    final declared = picked.lengthSync();
    if (declared != null &&
        (declared < 0 || declared > QrImageDecodeTask.maxBytes)) {
      throw const QrInputException(QrInputFailure.tooLarge);
    }
    final builder = BytesBuilder(copy: true);
    final reader = _reader = StreamIterator(picked.readAsByteStream());
    try {
      while (await reader.moveNext()) {
        if (_cancelled) return null;
        final chunk = reader.current;
        if (chunk.length > QrImageDecodeTask.maxBytes - builder.length) {
          throw const QrInputException(QrInputFailure.tooLarge);
        }
        builder.add(chunk);
      }
    } finally {
      await reader.cancel();
      _reader = null;
    }
    if (_cancelled) return null;
    final decoder = _decode = QrImageDecodeTask(builder.takeBytes());
    return decoder.result;
  }
}
