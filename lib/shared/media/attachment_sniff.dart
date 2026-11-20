import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

/// Maximum raw file size CodeWalk will stage for sending (100 MiB).
const maxAttachmentFileBytes = 100 * 1024 * 1024;

/// Maximum attachments staged on a single composer message.
const maxComposerAttachments = 8;

/// Maximum inline attachment payload size per item & per prompt (20 MiB).
const maxInlineAttachmentBytes = 20 * 1024 * 1024;

/// Maximum decoded UTF-8 text file size sent inline (256 KiB).
const maxInlineTextAttachmentBytes = 256 * 1024;

/// MIME types sniffed from magic bytes for composer staging and timeline icons.
String sniffAttachmentMime(
  Uint8List head, {
  required int byteSize,
  String? filename,
  String? hintMime,
}) {
  if (head.length >= 8 &&
      head[0] == 0x89 &&
      head[1] == 0x50 &&
      head[2] == 0x4E &&
      head[3] == 0x47 &&
      head[4] == 0x0D &&
      head[5] == 0x0A &&
      head[6] == 0x1A &&
      head[7] == 0x0A) {
    return 'image/png';
  }
  if (head.length >= 3 &&
      head[0] == 0xFF &&
      head[1] == 0xD8 &&
      head[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (head.length >= 6 &&
      head[0] == 0x47 &&
      head[1] == 0x49 &&
      head[2] == 0x46 &&
      head[3] == 0x38 &&
      (head[4] == 0x37 || head[4] == 0x39) &&
      head[5] == 0x61) {
    return 'image/gif';
  }
  if (head.length >= 12 &&
      head[0] == 0x52 &&
      head[1] == 0x49 &&
      head[2] == 0x46 &&
      head[3] == 0x46 &&
      head[8] == 0x57 &&
      head[9] == 0x45 &&
      head[10] == 0x42 &&
      head[11] == 0x50) {
    return 'image/webp';
  }
  if (head.length >= 5 &&
      head[0] == 0x25 &&
      head[1] == 0x50 &&
      head[2] == 0x44 &&
      head[3] == 0x46 &&
      head[4] == 0x2D) {
    return 'application/pdf';
  }
  if (head.length >= 3 &&
      head[0] == 0x49 &&
      head[1] == 0x44 &&
      head[2] == 0x33) {
    return 'audio/mpeg';
  }
  if (head.length >= 2 && head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) {
    return 'audio/mpeg';
  }
  if (head.length >= 12 &&
      head[0] == 0x52 &&
      head[1] == 0x49 &&
      head[2] == 0x46 &&
      head[3] == 0x46 &&
      head[8] == 0x57 &&
      head[9] == 0x41 &&
      head[10] == 0x56 &&
      head[11] == 0x45) {
    return 'audio/wav';
  }
  if (head.length >= 4 &&
      head[0] == 0x4F &&
      head[1] == 0x67 &&
      head[2] == 0x67 &&
      head[3] == 0x53) {
    return 'audio/ogg';
  }
  if (head.length >= 4 &&
      head[0] == 0x66 &&
      head[1] == 0x4C &&
      head[2] == 0x61 &&
      head[3] == 0x43) {
    return 'audio/flac';
  }
  if (head.length >= 12 &&
      head[4] == 0x66 &&
      head[5] == 0x74 &&
      head[6] == 0x79 &&
      head[7] == 0x70) {
    final brand = String.fromCharCodes(head.sublist(8, 12));
    if (brand == 'M4A ' || brand == 'M4B ' || brand == 'isom' || brand == 'mp42') {
      final lower = (filename ?? '').toLowerCase();
      if (brand.startsWith('M4') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          (hintMime?.startsWith('audio/') ?? false)) {
        return 'audio/mp4';
      }
    }
  }
  if (byteSize <= maxInlineTextAttachmentBytes &&
      head.isNotEmpty &&
      _looksLikeUtf8Text(head)) {
    return _textMimeForExtension(filename) ?? 'text/plain';
  }
  final normalizedHint = hintMime?.split(';').first.trim().toLowerCase();
  if (normalizedHint != null &&
      normalizedHint.contains('/') &&
      !normalizedHint.startsWith('image/') &&
      normalizedHint != 'application/pdf') {
    return normalizedHint;
  }
  return _extensionFallbackMime(filename) ?? 'application/octet-stream';
}

bool _looksLikeUtf8Text(Uint8List bytes) {
  for (final b in bytes) {
    if (b == 0x00) return false;
  }
  try {
    // Allow partial multi-byte UTF-8 sequence at end of a truncated head slice.
    final end = bytes.length > 4 ? bytes.length - 3 : bytes.length;
    utf8.decode(bytes.sublist(0, end), allowMalformed: false);
    return true;
  } on FormatException {
    return false;
  }
}

String? _textMimeForExtension(String? filename) {
  final lower = (filename ?? '').toLowerCase();
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
    return 'text/markdown';
  }
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.csv')) return 'text/csv';
  if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
  if (lower.endsWith('.xml')) return 'text/xml';
  if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'text/yaml';
  return null;
}

String? _extensionFallbackMime(String? filename) {
  final lower = (filename ?? '').toLowerCase();
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/mp4';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
  if (lower.endsWith('.flac')) return 'audio/flac';
  if (lower.endsWith('.zip')) return 'application/zip';
  return null;
}

/// Classifies a MIME type into a canonical [AttachmentKind].
AttachmentKind attachmentKindForMime(String mimeType) {
  final base = mimeType.split(';').first.trim().toLowerCase();
  if (base == 'application/geo+json') return AttachmentKind.location;
  if (base.startsWith('image/')) return AttachmentKind.image;
  if (base.startsWith('audio/')) return AttachmentKind.audio;
  return AttachmentKind.file;
}

/// Parses image width/height from file headers without decoding full pixel data.
({int width, int height})? probeImageDimensions(
  Uint8List bytes,
  String mimeType,
) {
  if (mimeType == 'image/png' && bytes.length >= 24) {
    final data = ByteData.sublistView(bytes);
    final w = data.getUint32(16, Endian.big);
    final h = data.getUint32(20, Endian.big);
    if (w > 0 && h > 0) return (width: w, height: h);
  } else if (mimeType == 'image/gif' && bytes.length >= 10) {
    final data = ByteData.sublistView(bytes);
    final w = data.getUint16(6, Endian.little);
    final h = data.getUint16(8, Endian.little);
    if (w > 0 && h > 0) return (width: w, height: h);
  } else if (mimeType == 'image/jpeg' && bytes.length >= 4) {
    var i = 2;
    while (i + 3 < bytes.length) {
      if (bytes[i] != 0xFF) break;
      while (i < bytes.length && bytes[i] == 0xFF) {
        i++;
      }
      if (i >= bytes.length) break;
      final marker = bytes[i++];
      if (marker == 0xD8 ||
          marker == 0xD9 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        continue;
      }
      if (i + 1 >= bytes.length) break;
      final length = (bytes[i] << 8) | bytes[i + 1];
      if (length < 2) break;
      final isSof =
          (marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB) ||
          (marker >= 0xCD && marker <= 0xCF);
      if (isSof && i + 6 < bytes.length) {
        final h = (bytes[i + 3] << 8) | bytes[i + 4];
        final w = (bytes[i + 5] << 8) | bytes[i + 6];
        if (w > 0 && h > 0) return (width: w, height: h);
        break;
      }
      i += length;
    }
  } else if (mimeType == 'image/webp' && bytes.length >= 30) {
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    if (chunk == 'VP8X' && bytes.length >= 30) {
      final w = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
      final h = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
      if (w > 0 && h > 0) return (width: w, height: h);
    } else if (chunk == 'VP8 ' && bytes.length >= 30) {
      final w = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
      final h = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
      if (w > 0 && h > 0) return (width: w, height: h);
    } else if (chunk == 'VP8L' && bytes.length >= 25) {
      final bits =
          bytes[21] |
          (bytes[22] << 8) |
          (bytes[23] << 16) |
          (bytes[24] << 24);
      final w = (bits & 0x3FFF) + 1;
      final h = ((bits >> 14) & 0x3FFF) + 1;
      if (w > 0 && h > 0) return (width: w, height: h);
    }
  }
  return null;
}

/// Sanitizes an arbitrary filename into a safe, bounded single basename.
String sanitizeAttachmentFilename(String raw, {String fallback = 'attachment'}) {
  final parts = raw.split(RegExp(r'[/\\]'));
  final base = parts.isEmpty ? '' : parts.last.trim();
  final cleaned = base
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp('[^A-Za-z0-9._ -]+'), '_')
      .trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return fallback;
  }
  final noLeadingDots = cleaned.replaceFirst(RegExp(r'^\.+'), '');
  if (noLeadingDots.isEmpty) return fallback;
  return noLeadingDots.length <= 120
      ? noLeadingDots
      : noLeadingDots.substring(0, 120);
}

/// Human-readable byte count (e.g. `1.4 MB`, `24 KB`, `512 B`).
String formatAttachmentBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    return kb >= 100 ? '${kb.round()} KB' : '${kb.toStringAsFixed(1)} KB';
  }
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

/// Builds a strictly numeric, allowlisted map URI for [point]. Never trusts
/// URLs embedded in [point.label] or arbitrary metadata.
Uri buildAllowlistedMapUri(GeoPoint point, {required TargetPlatform platform}) {
  final lat = point.latitude.toStringAsFixed(6);
  final lon = point.longitude.toStringAsFixed(6);
  if (platform == TargetPlatform.android) {
    final label = point.label?.trim();
    final query = (label != null && label.isNotEmpty)
        ? '$lat,$lon(${Uri.encodeComponent(label)})'
        : '$lat,$lon';
    return Uri.parse('geo:$lat,$lon?q=$query');
  }
  return Uri.https('www.openstreetmap.org', '/', {
    'mlat': lat,
    'mlon': lon,
  }).replace(fragment: 'map=16/$lat/$lon');
}

/// Verifies a URI is safe to hand to `url_launcher` for location cards.
bool isAllowlistedMapUri(Uri uri) {
  if (uri.scheme == 'geo') return true;
  if (uri.scheme == 'https' && uri.host == 'www.openstreetmap.org') {
    return true;
  }
  return false;
}
