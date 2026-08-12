import '../../core/i18n/l10n_bridge.dart';
import 'file_part_action_types.dart';

Future<FilePartActionResult> handleFilePartAction({
  required String url,
  required String? sourcePath,
  required String mimeType,
  required String? filename,
}) async {
  return FilePartActionResult(
    success: false,
    message:
        L10nBridge.current?.attachmentNotAvailableOnPlatform ??
        'Attachment actions are not available on this platform.',
  );
}
