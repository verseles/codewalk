import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';

/// One attachment staged locally in a composer draft or preserved in an outbox
/// entry for take-back editing. Binary payloads live out-of-band in
/// [AttachmentBlobRepository] keyed by [sha256]; drafts never store raw base64.
final class StagedAttachment {
  const StagedAttachment({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.byteSize,
    this.name,
    this.sha256,
    this.width,
    this.height,
    this.location,
  });

  factory StagedAttachment.location({
    required String id,
    required GeoPoint location,
  }) => StagedAttachment(
    id: id,
    kind: AttachmentKind.location,
    mimeType: 'application/geo+json',
    byteSize: 0,
    name: location.label,
    location: location,
  );

  final String id;
  final AttachmentKind kind;
  final String? name;
  final String mimeType;
  final int byteSize;
  final String? sha256;
  final int? width;
  final int? height;
  final GeoPoint? location;

  /// Converts this staged item into a canonical [AttachmentRef] suitable for
  /// [PromptDraft.attachments].
  AttachmentRef toAttachmentRef() {
    if (kind == AttachmentKind.location && location != null) {
      return AttachmentRef(
        id: id,
        mimeType: 'application/geo+json',
        name: location!.label,
        kind: const OpenValue.known(AttachmentKind.location),
        location: location,
        availability: const OpenValue.known(AttachmentAvailability.ready),
        content: OutputRef(id: 'geo:$id', mimeType: 'application/geo+json'),
      );
    }
    final digest = sha256 ?? '';
    return AttachmentRef(
      id: id,
      mimeType: mimeType,
      name: name,
      kind: OpenValue.known(kind),
      width: width,
      height: height,
      availability: const OpenValue.known(AttachmentAvailability.ready),
      content: OutputRef(
        id: 'local:$digest',
        mimeType: mimeType,
        sizeBytes: byteSize,
      ),
    );
  }

  /// Restores a [StagedAttachment] from a canonical [AttachmentRef] carried by
  /// an outbox entry or workspace first-prompt handoff; null if incompatible.
  static StagedAttachment? fromAttachmentRef(AttachmentRef ref) {
    final kind = ref.kind.known ?? AttachmentKind.file;
    if (kind == AttachmentKind.location) {
      final point = ref.location;
      if (point == null) return null;
      return StagedAttachment.location(id: ref.id, location: point);
    }
    final contentId = ref.content.id;
    if (!contentId.startsWith('local:')) return null;
    final digest = contentId.substring('local:'.length);
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) return null;
    return StagedAttachment(
      id: ref.id,
      kind: kind,
      name: ref.name,
      mimeType: ref.mimeType,
      byteSize: ref.content.sizeBytes ?? 0,
      sha256: digest,
      width: ref.width,
      height: ref.height,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'mimeType': mimeType,
    'byteSize': byteSize,
    if (name != null) 'name': name,
    if (sha256 != null) 'sha256': sha256,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (location != null)
      'location': {
        'latitude': location!.latitude,
        'longitude': location!.longitude,
        if (location!.accuracyMeters != null)
          'accuracyMeters': location!.accuracyMeters,
        if (location!.label != null) 'label': location!.label,
      },
  };

  static StagedAttachment? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final id = value['id'];
    final kindName = value['kind'];
    final mimeType = value['mimeType'];
    final byteSize = value['byteSize'];
    if (id is! String ||
        id.isEmpty ||
        kindName is! String ||
        mimeType is! String ||
        mimeType.isEmpty ||
        byteSize is! int ||
        byteSize < 0) {
      return null;
    }
    AttachmentKind kind;
    try {
      kind = AttachmentKind.values.byName(kindName);
    } on ArgumentError {
      return null;
    }
    GeoPoint? location;
    if (value['location'] case final Map<String, Object?> loc) {
      final lat = loc['latitude'];
      final lon = loc['longitude'];
      if (lat is! num || lon is! num) return null;
      final acc = loc['accuracyMeters'];
      final label = loc['label'];
      try {
        location = GeoPoint(
          latitude: lat.toDouble(),
          longitude: lon.toDouble(),
          accuracyMeters: acc is num ? acc.toDouble() : null,
          label: label is String ? label : null,
        );
      } on ArgumentError {
        return null;
      }
    }
    final sha = value['sha256'];
    if (kind == AttachmentKind.location) {
      if (location == null) return null;
      return StagedAttachment.location(id: id, location: location);
    }
    if (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      return null;
    }
    final width = value['width'];
    final height = value['height'];
    return StagedAttachment(
      id: id,
      kind: kind,
      name: value['name'] is String ? value['name']! as String : null,
      mimeType: mimeType,
      byteSize: byteSize,
      sha256: sha,
      width: width is int && width > 0 ? width : null,
      height: height is int && height > 0 ? height : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StagedAttachment &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.byteSize == byteSize &&
      other.sha256 == sha256 &&
      other.width == width &&
      other.height == height &&
      other.location == location;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    mimeType,
    byteSize,
    sha256,
    width,
    height,
    location,
  );
}

enum AttachmentStageFailure {
  tooMany,
  tooLarge,
  emptyFile,
  readFailed,
  storageFailed,
}

final class AttachmentStageException implements Exception {
  const AttachmentStageException(this.failure);
  final AttachmentStageFailure failure;
  @override
  String toString() => 'AttachmentStageException(${failure.name})';
}

/// Content-addressed local blob storage for staged attachments, downloaded
/// timeline media, and out-of-band outbox payloads.
abstract interface class AttachmentBlobRepository {
  Future<({String sha256, int byteSize, Uint8List head})> putStream(
    Stream<List<int>> stream, {
    required int maxBytes,
  });

  Future<({String sha256, int byteSize})> putBytes(Uint8List bytes);

  Future<Uint8List?> readBytes(String sha256, {int? maxBytes});

  Stream<List<int>>? openRead(String sha256);

  Future<int?> byteSizeOf(String sha256);

  Future<void> pin(String ownerId, Iterable<String> digests);

  Future<void> unpin(String ownerId);
}

/// Optional capability surface implemented by live session handles and
/// read-only history sources that can fetch attachment content and report
/// upload capabilities.
abstract interface class SessionAttachmentSource {
  AttachmentFacet? get attachments;
  bool get supportsStageUpload;
  bool get supportsMediaRead;
}
