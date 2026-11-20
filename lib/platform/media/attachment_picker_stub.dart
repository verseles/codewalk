import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';

import '../../shared/media/attachment_picker.dart';

AttachmentPickerPort createAttachmentPickerPort() =>
    const _UnsupportedAttachmentPicker();

AttachmentFileOpener createAttachmentFileOpener() =>
    const _UnsupportedAttachmentFileOpener();

MapUriLauncher createMapUriLauncher() => const _UnsupportedMapUriLauncher();

final class _UnsupportedAttachmentPicker implements AttachmentPickerPort {
  const _UnsupportedAttachmentPicker();

  @override
  Future<List<PickedAttachmentFile>> pick(
    AttachmentPickCategory category, {
    required int maxBytes,
  }) async => const [];
}

final class _UnsupportedAttachmentFileOpener implements AttachmentFileOpener {
  const _UnsupportedAttachmentFileOpener();

  @override
  Future<bool> openBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async => false;
}

final class _UnsupportedMapUriLauncher implements MapUriLauncher {
  const _UnsupportedMapUriLauncher();

  @override
  Future<bool> launchLocation(GeoPoint point) async => false;
}
