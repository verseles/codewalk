import 'dart:convert';
import 'dart:typed_data';

/// Small, uncredentialed presentation images; never workspace files.
final class ProjectIconData {
  const ProjectIconData(this.bytes, {required this.svg});
  final Uint8List bytes;
  final bool svg;

  static const maxBytes = 256 * 1024;
  static const maxSvgBytes = 64 * 1024;

  static ProjectIconData? fromBytes(Uint8List bytes, {String? mediaType}) {
    if (bytes.isEmpty || bytes.length > maxBytes) return null;
    final mime = mediaType?.split(';').first.trim().toLowerCase();
    final prefix = utf8
        .decode(bytes.take(128).toList(), allowMalformed: true)
        .trimLeft();
    final svg =
        mime == 'image/svg+xml' ||
        ((mime == null || mime == 'application/octet-stream') &&
            (prefix.startsWith('<svg') || prefix.startsWith('<?xml')));
    if (svg) {
      return bytes.length <= maxSvgBytes
          ? ProjectIconData(bytes, svg: true)
          : null;
    }
    if (mime != null &&
        mime != 'application/octet-stream' &&
        !const {
          'image/png',
          'image/jpeg',
          'image/jpg',
          'image/webp',
          'image/gif',
          'image/bmp',
          'image/x-icon',
          'image/vnd.microsoft.icon',
        }.contains(mime)) {
      return null;
    }
    return ProjectIconData(bytes, svg: false);
  }

  static ProjectIconData? fromDataUri(Uri uri) {
    if (!uri.isScheme('data') || uri.toString().length > maxSvgBytes) {
      return null;
    }
    try {
      final data = uri.data!;
      if (!data.mimeType.startsWith('image/')) return null;
      return fromBytes(data.contentAsBytes(), mediaType: data.mimeType);
    } on FormatException {
      return null;
    }
  }
}

bool isProjectIconNetworkUri(Uri uri) =>
    uri.isScheme('https') && uri.host.isNotEmpty && uri.userInfo.isEmpty;
