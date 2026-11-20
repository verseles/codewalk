import 'dart:typed_data';

import 'timeline.dart';
import 'values.dart';

/// Harness-neutral attachment category for composer drafts and timeline items.
enum AttachmentKind { image, file, audio, location, unknown }

/// Availability of an attachment's underlying payload bytes.
///
/// [remote] indicates that bytes are not held in canonical state and can be
/// fetched on demand through an adapter-provided media facet or cache.
/// [omitted] indicates the harness or reader intentionally withheld payload
/// bytes (for example, exceeding a bounded read limit or a server-side path
/// reference without a media read route).
enum AttachmentAvailability { ready, remote, omitted, unavailable }

/// Canonical capability keys for prompt attachments and media retrieval.
abstract final class AttachmentCapabilities {
  /// Staging non-inline files onto the harness host (for example a scoped
  /// temporary uploads directory) so the session can reference them by path.
  static const stageUpload = 'attachments.stageUpload';

  /// Fetching stored attachment media bytes on demand by opaque media key.
  static const mediaRead = 'attachments.mediaRead';
}

/// Validated geographic coordinates for a location attachment.
///
/// Coordinates are stored strictly as validated finite numbers so consumers
/// can build safe map URLs without trusting arbitrary URLs from message text
/// or harness metadata.
final class GeoPoint {
  GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    String? label,
  }) : label = _sanitizeLabel(label) {
    if (!latitude.isFinite || latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be finite within [-90, 90]',
      );
    }
    if (!longitude.isFinite || longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be finite within [-180, 180]',
      );
    }
    if (accuracyMeters != null &&
        (!accuracyMeters!.isFinite || accuracyMeters! < 0.0)) {
      throw ArgumentError.value(
        accuracyMeters,
        'accuracyMeters',
        'Must be finite and nonnegative',
      );
    }
  }

  static const maxLabelChars = 200;

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? label;

  static String? _sanitizeLabel(String? raw) {
    if (raw == null) return null;
    final singleLine = raw
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
        .trim();
    if (singleLine.isEmpty) return null;
    if (singleLine.length > maxLabelChars) {
      throw ArgumentError.value(
        raw,
        'label',
        'Must be at most $maxLabelChars characters',
      );
    }
    return singleLine;
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters &&
      other.label == label;

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters, label);
}

/// Immutable binary media loaded on demand outside canonical timeline state.
final class AttachmentMedia {
  AttachmentMedia({required List<int> bytes, required String mimeType})
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      mimeType = requireText(mimeType, 'mimeType');

  final Uint8List bytes;
  final String mimeType;
}

/// Optional adapter-provided media reader for fetching remote or cached
/// attachment bytes without embedding raw binaries in canonical state.
abstract interface class AttachmentFacet {
  Future<AttachmentMedia?> read(AttachmentRef ref);
}

final _disallowedAttachmentIdSchemes = RegExp(
  r'^(file|data|http|https|ftp|content|javascript):',
  caseSensitive: false,
);

final _windowsDrivePrefix = RegExp(r'^[A-Za-z]:[\\/]');

/// Validates an opaque attachment content handle.
///
/// Rejects empty values, absolute filesystem paths, backslash paths,
/// traversal segments, control/whitespace characters, and executable/raw URI
/// schemes while allowing opaque adapter handles such as `media:<64-hex>`,
/// `inline:<sha256>`, `local:<sha256>`, `path:<sha256>`, or
/// `phone-local:opaque/ref`.
String requireAttachmentContentId(String value) {
  final text = requireText(value, 'content.id');
  if (text.startsWith('/') ||
      text.contains(r'\') ||
      text.contains('..') ||
      _windowsDrivePrefix.hasMatch(text) ||
      RegExp(r'[\x00-\x1f\x7f\s]').hasMatch(text) ||
      _disallowedAttachmentIdSchemes.hasMatch(text)) {
    throw ArgumentError.value(
      value,
      'content.id',
      'Must be an opaque handle, not a path or URI',
    );
  }
  return text;
}
