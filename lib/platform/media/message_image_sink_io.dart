import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
      final name = file.uri.pathSegments.last;
      // The file alone: Windows targets then take the image itself, never
      // a text fallback (a v1 lesson). Windows still needs a title, which
      // names the sheet and adds no text.
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png', name: name)],
          title: Platform.isWindows ? name : null,
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
    return writeNewImage(folder, fileName, png);
  }

  /// Removes this app's shared images older than a day.
  Future<void> _prune(Directory folder) async {
    final now = DateTime.now();
    try {
      await for (final entry in folder.list()) {
        if (entry is! File || !entry.path.endsWith('.png')) continue;
        try {
          final changed = entry.lastModifiedSync();
          if (now.difference(changed) > _keep) await entry.delete();
        } on FileSystemException {
          // A file another process holds stays for the next time.
        }
      }
    } on FileSystemException {
      // A folder that cannot be listed is pruned the next time.
    }
  }
}

/// Writes [png] to a new file in [folder] named after [fileName], adding
/// `-2`, `-3`… when that name is taken: two images of the same second never
/// share a file, so a target still reading the first never gets the second.
@visibleForTesting
Future<File> writeNewImage(
  Directory folder,
  String fileName,
  Uint8List png,
) async {
  final stem = fileName.endsWith('.png')
      ? fileName.substring(0, fileName.length - 4)
      : fileName;
  for (var n = 1; ; n++) {
    final name = n == 1 ? '$stem.png' : '$stem-$n.png';
    final file = File('${folder.path}${Platform.pathSeparator}$name');
    try {
      await file.create(exclusive: true);
    } on FileSystemException {
      if (n < 100) continue;
      rethrow;
    }
    await file.writeAsBytes(png, flush: true);
    return file;
  }
}
