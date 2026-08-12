import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../core/i18n/l10n_bridge.dart';
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
      return _downloadInlineAttachment(
        dataUrl: trimmedUrl,
        mimeType: mimeType,
        filename: filename,
      );
    }
    if (scheme == 'http' || scheme == 'https') {
      final launched = await _safeLaunch(
        parsedUrl,
        mode: LaunchMode.platformDefault,
      );
      if (launched) {
        return const FilePartActionResult(success: true);
      }
      return FilePartActionResult(
        success: false,
        message:
            L10nBridge.current?.attachmentUnableToOpenLink ??
            'Unable to open the attachment link.',
      );
    }
    if (scheme == 'file') {
      return FilePartActionResult(
        success: false,
        message:
            L10nBridge.current?.attachmentBrowserSandboxLocalFile ??
            'Browser sandbox prevents opening local file:// attachments directly.',
      );
    }

    if (parsedUrl.hasScheme) {
      final launched = await _safeLaunch(parsedUrl);
      if (launched) {
        return const FilePartActionResult(success: true);
      }
    }
  }

  if (sourcePath != null && sourcePath.trim().isNotEmpty) {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentLocalPathBrowserBlocked ??
          'This attachment points to a local path that cannot be opened from the browser.',
    );
  }

  return FilePartActionResult(
    success: false,
    message:
        L10nBridge.current?.attachmentNoValidLocation ??
        'Attachment does not provide a valid location.',
  );
}

FilePartActionResult _downloadInlineAttachment({
  required String dataUrl,
  required String mimeType,
  required String? filename,
}) {
  try {
    final safeName = _resolveOutputName(
      filename: filename,
      mimeType: mimeType,
      dataUrl: dataUrl,
    );
    final anchor = web.HTMLAnchorElement()
      ..href = dataUrl
      ..download = safeName
      ..style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    return FilePartActionResult(
      success: true,
      message:
          L10nBridge.current?.attachmentDownloadStarted ??
          'Attachment download started.',
    );
  } catch (_) {
    return FilePartActionResult(
      success: false,
      message:
          L10nBridge.current?.attachmentCouldNotDownload ??
          'Attachment could not be downloaded.',
    );
  }
}

// Delegate to shared implementation to avoid duplication with io variant.
Future<bool> _safeLaunch(Uri uri, {LaunchMode? mode}) =>
    safeLaunch(uri, mode: mode);

String _resolveOutputName({
  required String? filename,
  required String mimeType,
  required String dataUrl,
}) {
  final trimmedName = filename?.trim() ?? '';
  if (trimmedName.isNotEmpty) {
    return _sanitizeFilename(trimmedName);
  }

  String effectiveMime = mimeType.trim().toLowerCase();
  if (effectiveMime.isEmpty) {
    try {
      effectiveMime = UriData.parse(dataUrl).mimeType.trim().toLowerCase();
    } catch (_) {
      effectiveMime = '';
    }
  }
  final extension = _mimeToExtension(effectiveMime);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'attachment_$timestamp$extension';
}

// Delegate to shared implementation to avoid duplication with io variant.
String _mimeToExtension(String mimeType) => mimeToExtension(mimeType);

String _sanitizeFilename(String filename) {
  final sanitized = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (sanitized.isEmpty) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'attachment_$timestamp.bin';
  }
  return sanitized;
}
