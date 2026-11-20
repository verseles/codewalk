import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';

/// Official OpenCode v2 server limit for decoded inline `files[]` attachments.
const openCodeMaxInlineAttachmentBytes = 20 * 1024 * 1024;

/// Maximum decoded UTF-8 text attachment inlined directly in `files[]`.
const openCodeMaxInlineTextBytes = 256 * 1024;

/// Hard upper bound for streamed temporary uploads via `POST /api/experimental/fs/write`.
const openCodeMaxUploadBytes = 100 * 1024 * 1024;

/// Maximum attachments allowed on a single prompt.
const openCodeMaxAttachmentsPerPrompt = 8;

/// Image MIME types forwarded natively to models by OpenCode v2.
const openCodeInlineImageMimes = {
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
};

/// Magic-byte MIME detector mirroring OpenCode `packages/core/src/mime.ts`
/// plus common audio containers so spoofed filenames cannot bypass routing.
String sniffOpenCodeMime(Uint8List bytes, {String? filename}) {
  final media = _detectMagicMime(bytes, filename: filename);
  if (media != null) return media;
  if (_isUtf8Text(bytes)) return 'text/plain';
  return 'application/octet-stream';
}

String? _detectMagicMime(Uint8List bytes, {String? filename}) {
  if (_startsWith(bytes, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (_startsWith(bytes, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (bytes.length >= 6) {
    final sig = _ascii(bytes, 0, 6);
    if (sig == 'GIF87a' || sig == 'GIF89a') return 'image/gif';
  }
  if (bytes.length >= 18 && _startsWith(bytes, const [0x42, 0x4d])) {
    final view = ByteData.sublistView(bytes);
    final pixels = view.getUint32(10, Endian.little);
    final dib = view.getUint32(14, Endian.little);
    if (const {12, 16, 40, 52, 56, 64, 108, 124}.contains(dib) &&
        pixels >= 14 + dib) {
      return 'image/bmp';
    }
  }
  if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46, 0x2d])) {
    return 'application/pdf';
  }
  if (bytes.length >= 12 && _startsWith(bytes, const [0x52, 0x49, 0x46, 0x46])) {
    final form = _ascii(bytes, 8, 12);
    if (form == 'WEBP') return 'image/webp';
    if (form == 'WAVE') return 'audio/wav';
  }
  if (bytes.length >= 12 && _ascii(bytes, 4, 8) == 'ftyp') {
    final brand = _ascii(bytes, 8, 12);
    final view = ByteData.sublistView(bytes);
    final rawBoxEnd = view.getUint32(0, Endian.big);
    final boxEnd = rawBoxEnd < bytes.length ? rawBoxEnd : bytes.length;
    final compatible = <String>{};
    for (var offset = 16; offset + 4 <= boxEnd; offset += 4) {
      compatible.add(_ascii(bytes, offset, offset + 4));
    }
    final generic = brand == 'mif1' || brand == 'msf1';
    if (brand == 'avif' ||
        brand == 'avis' ||
        (generic &&
            (compatible.contains('avif') || compatible.contains('avis')))) {
      return 'image/avif';
    }
    if (generic || const {'heic', 'heix', 'hevc', 'hevx'}.contains(brand)) {
      return 'image/heic';
    }
    if (brand == 'qt  ') return 'video/quicktime';
    if (brand == 'M4A ' || brand == 'M4B ' || compatible.contains('M4A ')) {
      return 'audio/mp4';
    }
    if (brand == '3gp4' || brand == '3gp5') {
      final ext = _extension(filename);
      if (ext == '3ga' || ext == 'm4a') return 'audio/mp4';
    }
    return 'video/mp4';
  }
  // Audio signatures: ID3 / MP3 frame sync, Ogg, FLAC, AMR, AAC ADTS, WebM audio.
  if (_startsWith(bytes, const [0x49, 0x44, 0x33])) return 'audio/mpeg';
  if (bytes.length >= 2 &&
      bytes[0] == 0xff &&
      (bytes[1] == 0xfb ||
          bytes[1] == 0xf3 ||
          bytes[1] == 0xf2 ||
          bytes[1] == 0xe3)) {
    return 'audio/mpeg';
  }
  if (bytes.length >= 2 &&
      bytes[0] == 0xff &&
      (bytes[1] == 0xf1 || bytes[1] == 0xf9)) {
    return 'audio/aac';
  }
  if (_startsWith(bytes, const [0x4f, 0x67, 0x67, 0x53])) return 'audio/ogg';
  if (_startsWith(bytes, const [0x66, 0x4c, 0x61, 0x43])) return 'audio/flac';
  if (_startsWith(bytes, const [0x23, 0x21, 0x41, 0x4d, 0x52])) {
    return 'audio/amr';
  }
  if (_startsWith(bytes, const [0x1a, 0x45, 0xdf, 0xa3])) {
    final ext = _extension(filename);
    if (ext == 'weba' || ext == 'mka' || ext == 'opus') return 'audio/webm';
    return 'video/webm';
  }
  return null;
}

bool _isUtf8Text(Uint8List bytes) {
  if (bytes.isEmpty) return true;
  final sampleLen = bytes.length < 4096 ? bytes.length : 4096;
  var controls = 0;
  for (var i = 0; i < sampleLen; i++) {
    final b = bytes[i];
    if (b == 0) return false;
    if (b < 9 || (b > 13 && b < 32)) controls++;
  }
  if (controls / sampleLen > 0.3) return false;
  try {
    utf8.decode(bytes, allowMalformed: false);
    return true;
  } on FormatException {
    return false;
  }
}

bool _startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _ascii(Uint8List bytes, int start, int end) =>
    String.fromCharCodes(bytes.sublist(start, end));

String _extension(String? filename) {
  if (filename == null || filename.isEmpty) return '';
  final base = openCodeBasename(filename);
  final dot = base.lastIndexOf('.');
  if (dot <= 0 || dot == base.length - 1) return '';
  return base.substring(dot + 1).toLowerCase();
}

/// Extracts the basename from a POSIX or Windows path.
String openCodeBasename(String value) {
  var end = value.length;
  while (end > 0 && (value[end - 1] == '/' || value[end - 1] == r'\')) {
    end--;
  }
  if (end == 0) return '';
  final trimmed = value.substring(0, end);
  final slash = trimmed.lastIndexOf('/');
  final backslash = trimmed.lastIndexOf(r'\');
  final sep = slash > backslash ? slash : backslash;
  return sep < 0 ? trimmed : trimmed.substring(sep + 1);
}

/// Maps a MIME type to its canonical [AttachmentKind].
AttachmentKind openCodeAttachmentKindForMime(String mimeType) {
  final normalized = mimeType.split(';').first.trim().toLowerCase();
  if (normalized.startsWith('image/')) return AttachmentKind.image;
  if (normalized.startsWith('audio/')) return AttachmentKind.audio;
  if (normalized == 'application/geo+json') return AttachmentKind.location;
  if (normalized.isEmpty) return AttachmentKind.unknown;
  return AttachmentKind.file;
}

/// MIME types recognized as inline UTF-8 text attachments (`<=256 KiB`) in
/// OpenCode v2 `files[]`.
const openCodeInlineTextApplicationMimes = <String>{
  'application/json',
  'application/xml',
  'application/yaml',
  'application/x-yaml',
  'application/javascript',
  'application/ecmascript',
};

/// Whether [mimeType] represents a UTF-8 text format eligible for inline
/// transport (`<=256 KiB`).
bool openCodeIsInlineTextMime(String mimeType) {
  final normalized = mimeType.split(';').first.trim().toLowerCase();
  return normalized.startsWith('text/') ||
      openCodeInlineTextApplicationMimes.contains(normalized);
}

/// Whether [mimeType] can be inlined in OpenCode v2 `files[]` for a model with
/// [inputModalities] and [byteSize] decoded bytes.
bool canInlineOpenCodeAttachment({
  required String mimeType,
  required int byteSize,
  required Map<String, bool?> inputModalities,
}) {
  if (byteSize < 0 || byteSize > openCodeMaxInlineAttachmentBytes) return false;
  final normalized = mimeType.split(';').first.trim().toLowerCase();
  if (openCodeInlineImageMimes.contains(normalized)) {
    return inputModalities['image'] == true;
  }
  if (normalized == 'application/pdf') {
    return inputModalities['pdf'] == true;
  }
  if (openCodeIsInlineTextMime(normalized)) {
    return byteSize <= openCodeMaxInlineTextBytes;
  }
  return false;
}

/// Sanitizes an arbitrary filename into a safe basename for
/// `<tmp>/uploads/<uuid>/<name>`: strips separators/control chars, allows only
/// `[A-Za-z0-9._-]`, removes leading dots, caps length at 120 preserving the
/// extension, and falls back to `attachment.bin`.
String sanitizeOpenCodeUploadFilename(String raw) {
  final base = openCodeBasename(raw);
  final cleaned = base
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceFirst(RegExp(r'^\.+'), '');
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'attachment.bin';
  }
  if (cleaned.length <= 120) return cleaned;
  final dot = cleaned.lastIndexOf('.');
  if (dot > 0 && cleaned.length - dot <= 16) {
    final ext = cleaned.substring(dot);
    final stem = cleaned.substring(0, 120 - ext.length);
    return stem.isEmpty ? 'attachment$ext' : '$stem$ext';
  }
  return cleaned.substring(0, 120);
}

final _uploadIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
final _windowsAbsPattern = RegExp(r'^[A-Za-z]:[\\/]');

/// Whether [path] is an absolute filesystem path without traversal segments or
/// control characters.
bool isSafeAbsoluteOpenCodePath(String path) {
  if (path.isEmpty || path.length > 4096) return false;
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(path)) return false;
  final abs = path.startsWith('/') || _windowsAbsPattern.hasMatch(path);
  if (!abs) return false;
  final segments = path.split(RegExp(r'[\\/]'));
  return !segments.any((s) => s == '..');
}

/// Builds the strictly confined temporary upload path
/// `<temporaryPath>/uploads/<uploadId>/<safeFilename>`.
/// Throws [ArgumentError] if any component is unsafe.
String buildOpenCodeUploadPath({
  required String temporaryPath,
  required String uploadId,
  required String filename,
}) {
  if (!isSafeAbsoluteOpenCodePath(temporaryPath)) {
    throw ArgumentError.value(
      temporaryPath,
      'temporaryPath',
      'Must be a safe absolute path',
    );
  }
  if (!_uploadIdPattern.hasMatch(uploadId)) {
    throw ArgumentError.value(
      uploadId,
      'uploadId',
      'Must be 8..64 safe identifier characters',
    );
  }
  final safeName = sanitizeOpenCodeUploadFilename(filename);
  final useBackslash =
      _windowsAbsPattern.hasMatch(temporaryPath) && !temporaryPath.contains('/');
  final sep = useBackslash ? r'\' : '/';
  final trimmed = temporaryPath.replaceFirst(RegExp(r'[\\/]+$'), '');
  return '$trimmed${sep}uploads$sep$uploadId$sep$safeName';
}

String _normalizeSeparators(String path) =>
    path.replaceAll(r'\', '/').replaceAll(RegExp(r'/+'), '/');

/// Verifies the server-returned upload path stays strictly confined to
/// `<temporaryPath>/uploads/` and matches [expectedPath].
bool isTrustedOpenCodeUploadPath({
  required String returnedPath,
  required String expectedPath,
  required String temporaryPath,
}) {
  if (!isSafeAbsoluteOpenCodePath(returnedPath) ||
      !isSafeAbsoluteOpenCodePath(expectedPath) ||
      !isSafeAbsoluteOpenCodePath(temporaryPath)) {
    return false;
  }
  final normReturned = _normalizeSeparators(returnedPath);
  final normExpected = _normalizeSeparators(expectedPath);
  final normPrefix =
      '${_normalizeSeparators(temporaryPath).replaceFirst(RegExp(r'/+$'), '')}/uploads/';
  return normReturned.startsWith(normPrefix) && normReturned == normExpected;
}

/// Official OpenCode path-attachment reference line appended to prompt text.
String formatOpenCodeAttachmentReference(String path) =>
    'Attached file: `$path`';

/// Builds the canonical OpenStreetMap HTTPS URL strictly from numeric values.
String formatGeoPointMapUrl(GeoPoint point) {
  final lat = _formatCoord(point.latitude);
  final lon = _formatCoord(point.longitude);
  return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=16/$lat/$lon';
}

String _formatCoord(double value) {
  final normalized = value == 0 ? 0.0 : value;
  final fixed = normalized.toStringAsFixed(6);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

const _locationFenceOpen = '[codewalk-location v1]';
const _locationFenceClose = '[/codewalk-location]';

/// Formats a self-contained location block readable by LLMs and other clients,
/// and parseable back into a [GeoPoint] if a server drops custom metadata.
String formatCodeWalkLocationFence(GeoPoint point) {
  final lines = <String>[
    _locationFenceOpen,
    if (point.label != null) 'label: ${point.label}',
    'latitude: ${_formatCoord(point.latitude)}',
    'longitude: ${_formatCoord(point.longitude)}',
    if (point.accuracyMeters != null)
      'accuracy_m: ${point.accuracyMeters!.toStringAsFixed(1)}',
    'map: ${formatGeoPointMapUrl(point)}',
    _locationFenceClose,
  ];
  return lines.join('\n');
}

/// Extracts all valid `[codewalk-location v1]` blocks from [text], returning
/// the remaining display text and parsed [GeoPoint]s. Invalid blocks are left
/// untouched as plain text.
({String remainingText, List<GeoPoint> locations}) parseCodeWalkLocationFences(
  String text,
) {
  if (!text.contains(_locationFenceOpen)) {
    return (remainingText: text, locations: const []);
  }
  final locations = <GeoPoint>[];
  final kept = StringBuffer();
  var cursor = 0;
  while (cursor < text.length) {
    final start = text.indexOf(_locationFenceOpen, cursor);
    if (start < 0) {
      kept.write(text.substring(cursor));
      break;
    }
    final atLineStart = start == 0 || text[start - 1] == '\n';
    final end = text.indexOf(_locationFenceClose, start + _locationFenceOpen.length);
    if (!atLineStart || end < 0) {
      kept.write(text.substring(cursor));
      break;
    }
    final blockEnd = end + _locationFenceClose.length;
    final atLineEnd = blockEnd == text.length || text[blockEnd] == '\n';
    final block = text.substring(start, blockEnd);
    final parsed = atLineEnd ? _parseSingleLocationBlock(block) : null;
    if (parsed == null) {
      kept.write(text.substring(cursor, blockEnd));
      cursor = blockEnd;
      continue;
    }
    kept.write(text.substring(cursor, start));
    locations.add(parsed);
    cursor = blockEnd;
    if (cursor < text.length && text[cursor] == '\n') cursor++;
  }
  if (locations.isEmpty) {
    return (remainingText: text, locations: const []);
  }
  final cleaned = kept.toString().replaceFirst(RegExp(r'\n+$'), '');
  return (remainingText: cleaned, locations: List.unmodifiable(locations));
}

GeoPoint? _parseSingleLocationBlock(String block) {
  final lines = block.split('\n');
  if (lines.length < 4 ||
      lines.first != _locationFenceOpen ||
      lines.last != _locationFenceClose) {
    return null;
  }
  double? lat;
  double? lon;
  double? accuracy;
  String? label;
  for (var i = 1; i < lines.length - 1; i++) {
    final line = lines[i];
    final sep = line.indexOf(':');
    if (sep <= 0) return null;
    final key = line.substring(0, sep).trim();
    final value = line.substring(sep + 1).trim();
    switch (key) {
      case 'latitude':
        lat = double.tryParse(value);
      case 'longitude':
        lon = double.tryParse(value);
      case 'accuracy_m':
        accuracy = double.tryParse(value);
        if (accuracy == null) return null;
      case 'label':
        label = value;
      case 'map':
        // Ignored on parse; URLs are always rebuilt from validated numbers.
        break;
      default:
        return null;
    }
  }
  if (lat == null || lon == null) return null;
  try {
    return GeoPoint(
      latitude: lat,
      longitude: lon,
      accuracyMeters: accuracy,
      label: label,
    );
  } on ArgumentError {
    return null;
  }
}
