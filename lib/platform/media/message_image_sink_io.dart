import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/media/message_image.dart';

MessageImageSink createMessageImageSink() => _PlatformMessageImages();

/// Shares a message's PNG through the system sheet, or saves it on Linux,
/// whose `share_plus` takes no files (#540).
final class _PlatformMessageImages implements MessageImageSink {
  /// How long a shared image stays: the receiving app may read it after
  /// the sheet closes.
  static const _keep = Duration(days: 1);
  static const _folder = 'codewalk_shares';

  @override
  MessageImageMode get mode =>
      Platform.isLinux ? MessageImageMode.save : MessageImageMode.share;

  @override
  Future<MessageImageOutcome> deliver(
    Uint8List png, {
    required String fileName,
    Rect? origin,
  }) async {
    try {
      if (Platform.isLinux) {
        final saved = await FilePicker.saveFile(
          fileName: fileName,
          bytes: png,
          mimeType: 'image/png',
          type: FileType.image,
        );
        return saved == null
            ? MessageImageOutcome.cancelled
            : MessageImageOutcome.saved;
      }
      final file = await _write(png, fileName);
      // The file alone: Windows targets then take the image itself, never
      // a text fallback (a v1 lesson).
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
          sharePositionOrigin: origin,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.dismissed => MessageImageOutcome.cancelled,
        _ => MessageImageOutcome.shared,
      };
    } on Object {
      return MessageImageOutcome.failed;
    }
  }

  Future<File> _write(Uint8List png, String fileName) async {
    // Windows share targets read the file after the call returns, from a
    // folder that outlives the temporary one.
    final base = Platform.isWindows
        ? await getApplicationSupportDirectory()
        : await getTemporaryDirectory();
    final folder = Directory('${base.path}${Platform.pathSeparator}$_folder');
    await folder.create(recursive: true);
    await _prune(folder);
    final file = File('${folder.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  /// Removes this app's shared images older than a day.
  Future<void> _prune(Directory folder) async {
    final now = DateTime.now();
    try {
      await for (final entry in folder.list()) {
        if (entry is! File || !entry.path.endsWith('.png')) continue;
        final changed = entry.lastModifiedSync();
        if (now.difference(changed) > _keep) await entry.delete();
      }
    } on FileSystemException {
      // A file another process holds stays for the next time.
    }
  }
}
