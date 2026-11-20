import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';

enum AttachmentPickCategory { image, file, audio }

/// One file returned by the platform picker, readable as a bounded stream so
/// large files never buffer wholly in RAM before hashing/staging.
final class PickedAttachmentFile {
  const PickedAttachmentFile({
    required this.name,
    required this.openRead,
    this.byteSize,
    this.mimeHint,
  });

  final String name;
  final Stream<List<int>> Function() openRead;
  final int? byteSize;
  final String? mimeHint;
}

/// Platform file picker port for staging attachments into the composer.
abstract interface class AttachmentPickerPort {
  Future<List<PickedAttachmentFile>> pick(
    AttachmentPickCategory category, {
    required int maxBytes,
  });
}

/// Opens app-owned cached attachment bytes in an external platform viewer.
/// Never passes untrusted remote/server filesystem paths.
abstract interface class AttachmentFileOpener {
  Future<bool> openBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

/// Launches an allowlisted geographic map URI (`geo:` / OpenStreetMap) for a
/// timeline location card.
abstract interface class MapUriLauncher {
  Future<bool> launchLocation(GeoPoint point);
}
