import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/media/attachment_picker.dart';
import '../../shared/media/attachment_sniff.dart';

AttachmentPickerPort createAttachmentPickerPort() =>
    const _NativeAttachmentPicker();

AttachmentFileOpener createAttachmentFileOpener() =>
    const _NativeAttachmentFileOpener();

MapUriLauncher createMapUriLauncher() => const _NativeMapUriLauncher();

final class _NativeAttachmentPicker implements AttachmentPickerPort {
  const _NativeAttachmentPicker();

  @override
  Future<List<PickedAttachmentFile>> pick(
    AttachmentPickCategory category, {
    required int maxBytes,
  }) async {
    final (type, extensions) = switch (category) {
      AttachmentPickCategory.image => (
        FileType.custom,
        const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      ),
      AttachmentPickCategory.audio => (
        FileType.custom,
        const ['mp3', 'm4a', 'wav', 'ogg', 'opus', 'flac', 'aac'],
      ),
      AttachmentPickCategory.file => (FileType.any, null),
    };
    final picked = await FilePicker.pickFiles(
      type: type,
      allowedExtensions: extensions,
    );
    return [
      for (final file in picked)
        PickedAttachmentFile(
          name: file.name,
          byteSize: file.lengthSync(),
          openRead: file.readAsByteStream,
        ),
    ];
  }
}

final class _NativeAttachmentFileOpener implements AttachmentFileOpener {
  const _NativeAttachmentFileOpener();

  @override
  Future<bool> openBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final cache = await getTemporaryDirectory();
      final dir = Directory(
        '${cache.path}${Platform.pathSeparator}cw2_open_attachments',
      );
      await dir.create(recursive: true);
      final safeName = sanitizeAttachmentFilename(filename);
      final rng = Random.secure();
      final tag = List.generate(
        6,
        (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final file = File('${dir.path}${Platform.pathSeparator}${tag}_$safeName');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: mimeType);
      return result.type == ResultType.done;
    } on Object {
      return false;
    }
  }
}

final class _NativeMapUriLauncher implements MapUriLauncher {
  const _NativeMapUriLauncher();

  @override
  Future<bool> launchLocation(GeoPoint point) async {
    final uri = buildAllowlistedMapUri(point, platform: defaultTargetPlatform);
    if (!isAllowlistedMapUri(uri)) return false;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      // Fallback to HTTPS OpenStreetMap when no geo: app handles the intent.
      if (uri.scheme == 'geo') {
        final fallback = buildAllowlistedMapUri(
          point,
          platform: defaultTargetPlatform == TargetPlatform.android
              ? TargetPlatform.linux
              : defaultTargetPlatform,
        );
        if (isAllowlistedMapUri(fallback)) {
          return await launchUrl(
            fallback,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      return false;
    } on Object {
      return false;
    }
  }
}
