import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging/app_logger.dart';

/// Maximum render height in logical pixels for a single capture.
/// Messages taller than this are rejected to avoid GPU texture overflow.
const _maxCaptureHeight = 4096.0;

/// Pixel ratio for the captured image — balances sharpness and memory.
const _capturePixelRatio = 2.5;

const _shareImageFilePrefix = 'codewalk_message_share_';
const _shareImageCacheMaxAge = Duration(days: 1);

/// Result of a share-image export attempt.
enum MessageImageExportResult {
  /// Image captured and share sheet invoked successfully.
  shared,

  /// The message widget is too tall for a safe GPU capture.
  tooTall,

  /// The RepaintBoundary has not been laid out yet (no render object).
  notLaidOut,

  /// An unexpected error occurred during capture or sharing.
  failed,
}

/// Service that captures a [RepaintBoundary] widget as a PNG image and
/// invokes the platform share sheet. Designed for single-message image
/// export from the chat view.
class MessageImageExportService {
  /// Captures the widget tree under [boundaryKey] as a PNG, writes it to a
  /// PNG share file, and opens the native share sheet with [subject] as the
  /// share title when the platform supports that without interfering with
  /// file-only image shares.
  ///
  /// Returns [MessageImageExportResult.shared] on success, or a specific
  /// failure code so the caller can show an appropriate user-facing message.
  static Future<MessageImageExportResult> captureAndShare({
    required GlobalKey boundaryKey,
    String? subject,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) {
      return MessageImageExportResult.notLaidOut;
    }

    final size = boundary.size;
    if (size.height > _maxCaptureHeight) {
      return MessageImageExportResult.tooTall;
    }

    ui.Image? image;
    try {
      image = await boundary.toImage(pixelRatio: _capturePixelRatio);
    } catch (e) {
      AppLogger.error('MessageImageExport: toImage failed', error: e);
      return MessageImageExportResult.failed;
    }

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return MessageImageExportResult.failed;
      }

      final buffer = byteData.buffer;
      return await _writeAndSharePngBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        subject: subject,
      );
    } catch (e) {
      AppLogger.error('MessageImageExport: share failed', error: e);
      return MessageImageExportResult.failed;
    } finally {
      image.dispose();
    }
  }

  @visibleForTesting
  static Future<MessageImageExportResult> sharePngBytesForTesting({
    required Uint8List pngBytes,
    String? subject,
    Directory? shareDirectory,
    DateTime? now,
  }) {
    return _writeAndSharePngBytes(
      pngBytes,
      subject: subject,
      shareDirectory: shareDirectory,
      now: now,
    );
  }

  static Future<MessageImageExportResult> _writeAndSharePngBytes(
    Uint8List pngBytes, {
    String? subject,
    Directory? shareDirectory,
    DateTime? now,
  }) async {
    final targetPlatform = defaultTargetPlatform;
    final isWindows = !kIsWeb && targetPlatform == TargetPlatform.windows;
    final timestamp = now ?? DateTime.now().toUtc();
    final directory =
        shareDirectory ?? await _resolveShareDirectory(isWindows: isWindows);

    await directory.create(recursive: true);
    await _pruneExpiredShareImages(directory, now: timestamp);

    final fileName = _shareImageFileName(timestamp);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (isWindows) {
      file.writeAsBytesSync(pngBytes, flush: true);
    } else {
      await file.writeAsBytes(pngBytes);
    }

    AppLogger.info(
      'MessageImageExport: wrote PNG share file '
      'path=${file.path} bytes=${pngBytes.length}',
    );

    final shareFile = XFile(file.path, mimeType: 'image/png', name: fileName);

    if (isWindows) {
      // share_plus maps subject to Windows DataPackage text for file shares.
      // Suppress it so image-capable targets do not receive a text-only
      // fallback when they fail to consume the StorageItems payload.
      await SharePlus.instance.share(ShareParams(files: <XFile>[shareFile]));
    } else {
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[shareFile], subject: subject),
      );
    }

    return MessageImageExportResult.shared;
  }

  static Future<Directory> _resolveShareDirectory({
    required bool isWindows,
  }) async {
    final baseDirectory = isWindows
        ? await getApplicationSupportDirectory()
        : await getTemporaryDirectory();
    return Directory(
      '${baseDirectory.path}${Platform.pathSeparator}codewalk_message_shares',
    );
  }

  static String _shareImageFileName(DateTime timestamp) {
    return '$_shareImageFilePrefix'
        '${timestamp.toUtc().microsecondsSinceEpoch}.png';
  }

  static Future<void> _pruneExpiredShareImages(
    Directory directory, {
    required DateTime now,
  }) async {
    if (!await directory.exists()) {
      return;
    }

    final cutoff = now.subtract(_shareImageCacheMaxAge);
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final fileName = entity.uri.pathSegments.isEmpty
            ? ''
            : entity.uri.pathSegments.last;
        if (!fileName.startsWith(_shareImageFilePrefix) ||
            !fileName.endsWith('.png')) {
          continue;
        }

        try {
          final lastModified = await entity.lastModified();
          if (lastModified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (e) {
          AppLogger.debug(
            'MessageImageExport: failed to prune old share file',
            error: e,
          );
        }
      }
    } catch (e) {
      AppLogger.debug(
        'MessageImageExport: failed to list old share files',
        error: e,
      );
    }
  }
}
