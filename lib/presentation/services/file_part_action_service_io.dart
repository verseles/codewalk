import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n_bridge.dart';
import '../../core/logging/app_logger.dart';
import 'file_part_action_service_shared.dart';
import 'file_part_action_types.dart';

Future<FilePartActionResult> handleFilePartAction({
  required String url,
  required String? sourcePath,
  required String mimeType,
  required String? filename,
}) async {
  final trimmedUrl = url.trim();
  final parsedUrl = trimmedUrl.isEmpty ? null : Uri.tryParse(trimmedUrl);

  if (parsedUrl != null) {
    final scheme = parsedUrl.scheme.toLowerCase();
    if (scheme == 'data') {
      return _saveInlineAttachment(
        dataUrl: trimmedUrl,
        mimeType: mimeType,
        filename: filename,
      );
    }
    if (scheme == 'http' || scheme == 'https') {
      return _launchUri(
        parsedUrl,
        mode: LaunchMode.externalApplication,
        fallbackMessage:
            L10nBridge.current?.attachmentUnableToOpenLink ??
            'Unable to open the attachment link.',
      );
    }
    if (scheme == 'file') {
      final filePath = _toFilePath(parsedUrl);
      if (filePath != null) {
        return _openLocalPath(filePath);
      }
    }
    if (parsedUrl.hasScheme) {
      final launched = await _safeLaunch(parsedUrl);
      if (launched) {
        return const FilePartActionResult(success: true);
      }
    }
  }

  final inferredPath = _inferLocalPath(trimmedUrl, parsedUrl) ?? sourcePath;
  if (inferredPath != null && inferredPath.trim().isNotEmpty) {
    return _openLocalPath(inferredPath);
  }

  return FilePartActionResult(
    success: false,
    message:
        L10nBridge.current?.attachmentNoValidLocation ??
        'Attachment does not provide a valid location.',
  );
}

Future<FilePartActionResult> _saveInlineAttachment({
  required String dataUrl,
  required String mimeType,
  required String? filename,
}) async {
  late final List<int> bytes;
  try {
    bytes = _decodeInlineData(dataUrl);
  } on FormatException {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentCouldNotDecode ??
          'Attachment data could not be decoded.',
    );
  } catch (error, stackTrace) {
    AppLogger.warn(
      'Unexpected failure while decoding inline attachment data.',
      error: error,
      stackTrace: stackTrace,
    );
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentCouldNotDecode ??
          'Attachment data could not be decoded.',
    );
  }

  if (bytes.isEmpty) {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentPayloadEmpty ??
          'Attachment payload is empty.',
    );
  }

  final safeName = _resolveOutputName(
    filename: filename,
    mimeType: mimeType,
    uriDataMimeType: _inferUriDataMimeType(dataUrl),
  );

  final pickerResult = await _saveWithSystemDialog(
    bytes: bytes,
    fileName: safeName,
  );
  if (pickerResult != null) {
    return pickerResult;
  }

  final candidateRoots = await _resolveAttachmentDirectories();
  Object? lastError;
  StackTrace? lastStackTrace;

  for (final root in candidateRoots) {
    try {
      final directory = Directory(_joinPath(root.path, 'codewalk_attachments'));
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      final outputFile = _allocateUniqueFile(directory.path, safeName);
      await outputFile.writeAsBytes(bytes, flush: true);

      final opened = await _safeLaunch(outputFile.uri);
      if (opened) {
        return FilePartActionResult(
          success: true,
          message:
              L10nBridge.current?.attachmentSavedAndOpened(outputFile.path) ??
              'Attachment saved to ${outputFile.path} and opened.',
        );
      }
      return FilePartActionResult(
        success: true,
        message:
            L10nBridge.current?.attachmentSavedPath(outputFile.path) ??
            'Attachment saved to ${outputFile.path}.',
      );
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }

  AppLogger.warn(
    'Failed to save inline attachment in all candidate directories.',
    error: lastError,
    stackTrace: lastStackTrace,
  );

  return FilePartActionResult(
    success: false,
    message:
        L10nBridge.current?.attachmentCouldNotSave ??
        'Attachment could not be saved on this device.',
  );
}

Future<FilePartActionResult?> _saveWithSystemDialog({
  required List<int> bytes,
  required String fileName,
}) async {
  try {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: L10nBridge.current?.attachmentSaveTitle ?? 'Save attachment',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
    if (savedPath == null) {
      return FilePartActionResult(
        success: false,
        message: L10nBridge.current?.attachmentSaveCanceled ?? 'Save canceled.',
      );
    }
    return FilePartActionResult(
      success: true,
      message:
          L10nBridge.current?.attachmentSavedPath(savedPath) ??
          'Attachment saved to $savedPath.',
    );
  } catch (error, stackTrace) {
    AppLogger.info(
      'System save dialog unavailable, falling back to direct write.',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<List<Directory>> _resolveAttachmentDirectories() async {
  final directories = <Directory>[];
  final seenPaths = <String>{};

  void addDirectory(Directory? directory) {
    if (directory == null) {
      return;
    }
    final path = directory.path.trim();
    if (path.isEmpty || !seenPaths.add(path)) {
      return;
    }
    directories.add(directory);
  }

  try {
    final downloadDirs = await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    );
    if (downloadDirs != null) {
      for (final directory in downloadDirs) {
        addDirectory(directory);
      }
    }
  } catch (_) {}

  try {
    addDirectory(await getDownloadsDirectory());
  } catch (_) {}

  try {
    addDirectory(await getExternalStorageDirectory());
  } catch (_) {}

  try {
    addDirectory(await getTemporaryDirectory());
  } catch (_) {}

  try {
    addDirectory(await getApplicationDocumentsDirectory());
  } catch (_) {}

  try {
    addDirectory(await getApplicationSupportDirectory());
  } catch (_) {}

  addDirectory(Directory.systemTemp);

  if (directories.isEmpty) {
    return <Directory>[Directory.systemTemp];
  }
  return directories;
}

Future<FilePartActionResult> _openLocalPath(String rawPath) async {
  final trimmedPath = rawPath.trim();
  if (trimmedPath.isEmpty) {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentPathEmpty ??
          'Attachment path is empty.',
    );
  }

  final entityType = FileSystemEntity.typeSync(trimmedPath, followLinks: true);
  if (entityType == FileSystemEntityType.notFound) {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentLocalNotFound ??
          'Local attachment was not found on this device.',
    );
  }

  final launched = await _safeLaunch(Uri.file(trimmedPath));
  if (launched) {
    return const FilePartActionResult(success: true);
  }
  return FilePartActionResult(
    success: false,
    message:
        L10nBridge.current?.attachmentUnableToOpenLocal ??
        'Unable to open the local attachment.',
  );
}

Future<FilePartActionResult> _launchUri(
  Uri uri, {
  required LaunchMode mode,
  required String fallbackMessage,
}) async {
  final launched = await _safeLaunch(uri, mode: mode);
  if (launched) {
    return const FilePartActionResult(success: true);
  }
  return FilePartActionResult(success: false, message: fallbackMessage);
}

// Delegate to shared implementation to avoid duplication with web variant.
Future<bool> _safeLaunch(Uri uri, {LaunchMode? mode}) =>
    safeLaunch(uri, mode: mode);

String? _toFilePath(Uri uri) {
  try {
    return uri.toFilePath(windows: Platform.isWindows);
  } catch (_) {
    return null;
  }
}

String? _inferLocalPath(String rawUrl, Uri? parsedUrl) {
  if (parsedUrl != null && !parsedUrl.hasScheme && parsedUrl.path.isNotEmpty) {
    return parsedUrl.path;
  }
  if (rawUrl.startsWith('/') ||
      rawUrl.startsWith('./') ||
      rawUrl.startsWith('../')) {
    return rawUrl;
  }
  if (Platform.isWindows && RegExp(r'^[a-zA-Z]:\\').hasMatch(rawUrl)) {
    return rawUrl;
  }
  return null;
}

String _resolveOutputName({
  required String? filename,
  required String mimeType,
  required String uriDataMimeType,
}) {
  final trimmedName = filename?.trim() ?? '';
  if (trimmedName.isNotEmpty) {
    return _sanitizeFilename(trimmedName);
  }

  final effectiveMime = mimeType.trim().isNotEmpty
      ? mimeType.trim().toLowerCase()
      : uriDataMimeType.trim().toLowerCase();
  final extension = _mimeToExtension(effectiveMime);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'attachment_$timestamp$extension';
}

// Delegate to shared implementation to avoid duplication with web variant.
String _mimeToExtension(String mimeType) => mimeToExtension(mimeType);

String _sanitizeFilename(String filename) {
  final sanitized = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (sanitized.isEmpty) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'attachment_$timestamp.bin';
  }
  return sanitized;
}

File _allocateUniqueFile(String directoryPath, String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  final hasExtension = dotIndex > 0;
  final stem = hasExtension ? fileName.substring(0, dotIndex) : fileName;
  final extension = hasExtension ? fileName.substring(dotIndex) : '';
  var index = 0;

  while (true) {
    final suffix = index == 0 ? '' : '_$index';
    final candidate = File(_joinPath(directoryPath, '$stem$suffix$extension'));
    if (!candidate.existsSync()) {
      return candidate;
    }
    index += 1;
  }
}

String _joinPath(String left, String right) {
  if (left.isEmpty) return right;
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

List<int> _decodeInlineData(String dataUrl) {
  try {
    return UriData.parse(dataUrl).contentAsBytes();
  } catch (_) {
    final markerIndex = dataUrl.indexOf('base64,');
    if (markerIndex < 0) {
      throw const FormatException('Invalid data URI');
    }
    final encoded = dataUrl.substring(markerIndex + 'base64,'.length).trim();
    if (encoded.isEmpty) {
      return const <int>[];
    }
    return base64Decode(encoded);
  }
}

String _inferUriDataMimeType(String dataUrl) {
  try {
    return UriData.parse(dataUrl).mimeType;
  } catch (_) {
    return '';
  }
}
