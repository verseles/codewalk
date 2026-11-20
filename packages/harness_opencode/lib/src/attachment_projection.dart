import 'dart:convert';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';

import 'attachment_encoding.dart';
import 'media_client.dart';

const _cwInlineIdKey = '_cwInlineId';
const _cwByteSizeKey = '_cwByteSize';
const _cwOmittedKey = '_cwOmitted';

const _maxProjectedAttachments = 32;
const _maxFieldChars = 4096;
const _maxMetadataBytes = 64 * 1024;
const _maxDisplayTextChars = 256 * 1024;
const _defaultMaxInlineEntryBytes = 20 * 1024 * 1024;
const _defaultMaxInlinePageBytes = 32 * 1024 * 1024;

/// Thrown when user attachment metadata exceeds bounded projection limits.
final class OpenCodeAttachmentLimitException extends FormatException {
  const OpenCodeAttachmentLimitException([super.message = 'Attachment limit exceeded.']);
}

/// Callback invoked whenever inline base64 media is extracted from a history,
/// inbox, or admission JSON payload before the bounded string projector runs.
typedef OpenCodeInlineMediaSink =
    void Function(String contentId, Uint8List bytes, String mimeType);

/// Extracts inline `files[].data` base64 blobs out of a decoded OpenCode HTTP
/// JSON payload (`data` list or single object), feeding them to [onMedia] and
/// replacing `data` with lightweight stubs so the 256 KiB / 1 MiB projection
/// budgets never trip on multi-megabyte inline images or PDFs.
///
/// Returns a shallow-cloned structure where only touched user rows and file
/// entries are replaced; untouched nodes are shared as-is.
Object? extractOpenCodeInlineMedia(
  Object? decoded, {
  OpenCodeInlineMediaSink? onMedia,
  int maxInlineEntryBytes = _defaultMaxInlineEntryBytes,
  int maxInlinePageBytes = _defaultMaxInlinePageBytes,
}) {
  if (decoded is! Map<String, Object?>) return decoded;
  final budget = _InlineBudget(maxInlineEntryBytes, maxInlinePageBytes);
  final data = decoded['data'];
  if (data is List<Object?>) {
    var changed = false;
    final nextRows = List<Object?>.of(data);
    for (var i = 0; i < nextRows.length; i++) {
      final row = nextRows[i];
      final stripped = _stripRow(row, onMedia, budget);
      if (!identical(stripped, row)) {
        nextRows[i] = stripped;
        changed = true;
      }
    }
    if (!changed) return decoded;
    return {...decoded, 'data': nextRows};
  }
  if (data is Map<String, Object?>) {
    final stripped = _stripRow(data, onMedia, budget);
    if (!identical(stripped, data)) {
      return {...decoded, 'data': stripped};
    }
    // Live SSE `session.inbox.enqueued` wraps `data.item.payload`.
    final item = data['item'];
    if (item is Map<String, Object?>) {
      final strippedItem = _stripRow(item, onMedia, budget);
      if (!identical(strippedItem, item)) {
        return {
          ...decoded,
          'data': {...data, 'item': strippedItem},
        };
      }
    }
  }
  return decoded;
}

final class _InlineBudget {
  _InlineBudget(this.maxEntry, this.maxTotal);
  final int maxEntry;
  final int maxTotal;
  int used = 0;
}

Object? _stripRow(
  Object? row,
  OpenCodeInlineMediaSink? onMedia,
  _InlineBudget budget,
) {
  if (row is! Map<String, Object?> || row['type'] != 'user') return row;
  // History row has `files` directly; inbox row nests `payload.files`.
  if (row['files'] is List<Object?>) {
    final stripped = _stripFilesList(
      row['files']! as List<Object?>,
      onMedia,
      budget,
    );
    if (stripped == null) return row;
    return {...row, 'files': stripped};
  }
  final payload = row['payload'];
  if (payload is Map<String, Object?> && payload['files'] is List<Object?>) {
    final stripped = _stripFilesList(
      payload['files']! as List<Object?>,
      onMedia,
      budget,
    );
    if (stripped == null) return row;
    return {
      ...row,
      'payload': {...payload, 'files': stripped},
    };
  }
  return row;
}

List<Object?>? _stripFilesList(
  List<Object?> files,
  OpenCodeInlineMediaSink? onMedia,
  _InlineBudget budget,
) {
  var changed = false;
  final next = List<Object?>.of(files);
  for (var i = 0; i < next.length; i++) {
    final entry = next[i];
    if (entry is! Map<String, Object?>) continue;
    final rawData = entry['data'];
    if (rawData is! String || rawData.isEmpty) continue;
    final mime = entry['mime'] is String && (entry['mime']! as String).isNotEmpty
        ? (entry['mime']! as String).split(';').first.trim().toLowerCase()
        : 'application/octet-stream';
    final estimatedBytes = (rawData.length * 3) ~/ 4;
    if (estimatedBytes > budget.maxEntry ||
        budget.used + estimatedBytes > budget.maxTotal) {
      final copy = Map<String, Object?>.of(entry)..remove('data');
      copy[_cwOmittedKey] = true;
      copy[_cwByteSizeKey] = estimatedBytes;
      next[i] = copy;
      changed = true;
      continue;
    }
    try {
      final bytes = base64Decode(rawData);
      if (bytes.length > budget.maxEntry ||
          budget.used + bytes.length > budget.maxTotal) {
        final copy = Map<String, Object?>.of(entry)..remove('data');
        copy[_cwOmittedKey] = true;
        copy[_cwByteSizeKey] = bytes.length;
        next[i] = copy;
        changed = true;
        continue;
      }
      budget.used += bytes.length;
      final digest = sha256.convert(bytes).toString();
      final contentId = 'inline:$digest';
      onMedia?.call(contentId, bytes, mime);
      final copy = Map<String, Object?>.of(entry)..remove('data');
      copy[_cwInlineIdKey] = contentId;
      copy[_cwByteSizeKey] = bytes.length;
      next[i] = copy;
      changed = true;
    } on FormatException {
      final copy = Map<String, Object?>.of(entry)..remove('data');
      copy[_cwOmittedKey] = true;
      next[i] = copy;
      changed = true;
    }
  }
  return changed ? next : null;
}

/// Result of projecting user message attachments from history or inbox rows.
final class OpenCodeProjectedUserAttachments {
  const OpenCodeProjectedUserAttachments({
    required this.displayText,
    required this.attachments,
    this.unprojectedManifest,
  });

  final String displayText;
  final List<AttachmentRef> attachments;

  /// Non-null only when unprojected user context remains (such as `agents`,
  /// `skills`, `application/x-directory`, or overflow entries).
  final Map<String, Object?>? unprojectedManifest;
}

/// Projects user message `files`, `metadata` (`displayText`, `attachments`,
/// `codewalk`), and `[codewalk-location v1]` fences into canonical
/// [AttachmentRef]s plus clean display text.
///
/// Validates structural types for `files`, `agents`, and `skills` matching the
/// strict contract of `history_projection.dart` and `inbox_projection.dart`,
/// throwing [FormatException] on malformed protocol shapes.
OpenCodeProjectedUserAttachments projectOpenCodeUserAttachments({
  required String messageId,
  required String rawText,
  required Object? rawFiles,
  required Object? rawMetadata,
  required Object? rawAgents,
  required Object? rawSkills,
  OpenCodeInlineMediaSink? onInlineMedia,
}) {
  final attachments = <AttachmentRef>[];
  final unprojectedCounts = <String, Object?>{};
  final unprojectedFiles = <Object?>[];
  final seenPathKeys = <String>{};
  var ordinal = 0;

  void validateMention(Map<String, Object?> entry) {
    if (!entry.containsKey('mention') || entry['mention'] == null) return;
    final mention = entry['mention'];
    if (mention is! Map<String, Object?>) {
      throw const FormatException('Malformed mention.');
    }
    for (final bound in const ['start', 'end']) {
      final v = mention[bound];
      if (v is! num || !v.isFinite) {
        throw const FormatException('Malformed mention bound.');
      }
    }
  }

  // 1. Validate agents and skills (retained in unprojectedManifest when non-empty).
  for (final pair in [('agents', rawAgents), ('skills', rawSkills)]) {
    final (key, raw) = pair;
    if (raw == null) continue;
    if (raw is! List<Object?>) {
      throw FormatException('Malformed user $key list.');
    }
    if (raw.length > 1024) {
      throw FormatException('User $key list exceeds limit.');
    }
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) {
        throw FormatException('Malformed user $key entry.');
      }
      validateMention(entry);
    }
    if (raw.isNotEmpty) unprojectedCounts[key] = raw.length;
  }

  // 2. Project wire `files[]`.
  if (rawFiles != null) {
    if (rawFiles is! List<Object?>) {
      throw const FormatException('Malformed user files list.');
    }
    if (rawFiles.length > 1024) {
      throw const OpenCodeAttachmentLimitException('User files list exceeds limit.');
    }
    var metadataBytes = 0;
    void chargeMetadata(String value) {
      metadataBytes += utf8.encode(value).length;
      if (metadataBytes > _maxMetadataBytes) {
        throw const OpenCodeAttachmentLimitException('Attachment metadata exceeds limit.');
      }
    }

    for (final entry in rawFiles) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('Malformed user file entry.');
      }
      validateMention(entry);
      final source = entry['source'];
      if (source is! Map<String, Object?>) {
        throw const FormatException('Malformed file source.');
      }
      final sourceKind = _requireShortText(source['type'], nonempty: true);
      final mime = _requireShortText(entry['mime'], nonempty: false);
      chargeMetadata(sourceKind);
      chargeMetadata(mime);
      if (entry['name'] case final String rawName) chargeMetadata(rawName);
      if (entry['uri'] case final String rawUri) chargeMetadata(rawUri);
      final effectiveMime = mime.isEmpty ? 'application/octet-stream' : mime;

      // Workspace `@mention` references and directories stay unprojected.
      final hasMention = entry['mention'] != null;
      if (hasMention ||
          effectiveMime == 'application/x-directory' ||
          attachments.length >= _maxProjectedAttachments) {
        unprojectedFiles.add({'mime': mime, 'sourceKind': sourceKind});
        continue;
      }

      final name = _optionalShortName(entry['name']);
      final width = _optionalNonNegativeInt(entry['width']);
      final height = _optionalNonNegativeInt(entry['height']);
      final kind = openCodeAttachmentKindForMime(effectiveMime);

      String contentId;
      int? sizeBytes = _optionalNonNegativeInt(entry['bytes']) ??
          _optionalNonNegativeInt(entry[_cwByteSizeKey]);
      AttachmentAvailability availability;

      final uri = entry['uri'];
      final mediaHash = uri is String ? openCodeMediaHashFromUri(uri) : null;
      final inlineId = entry[_cwInlineIdKey];
      final omitted = entry[_cwOmittedKey] == true;
      final rawData = entry['data'];

      if (mediaHash != null) {
        contentId = 'media:$mediaHash';
        availability = AttachmentAvailability.remote;
      } else if (inlineId is String && inlineId.startsWith('inline:')) {
        contentId = inlineId;
        availability = AttachmentAvailability.ready;
      } else if (omitted) {
        contentId =
            'omitted:${sha256.convert(utf8.encode('$messageId:f:$ordinal')).toString()}';
        availability = AttachmentAvailability.omitted;
      } else if (rawData is String && rawData.isNotEmpty) {
        final estimated = (rawData.length * 3) ~/ 4;
        if (estimated <= _defaultMaxInlineEntryBytes) {
          try {
            final bytes = base64Decode(rawData);
            final digest = sha256.convert(bytes).toString();
            contentId = 'inline:$digest';
            sizeBytes = bytes.length;
            availability = AttachmentAvailability.ready;
            onInlineMedia?.call(contentId, bytes, effectiveMime);
          } on FormatException {
            contentId =
                'invalid:${sha256.convert(utf8.encode('$messageId:f:$ordinal')).toString()}';
            availability = AttachmentAvailability.unavailable;
          }
        } else {
          contentId =
              'omitted:${sha256.convert(utf8.encode('$messageId:f:$ordinal')).toString()}';
          sizeBytes = estimated;
          availability = AttachmentAvailability.omitted;
        }
      } else {
        contentId =
            'ref:${sha256.convert(utf8.encode('$messageId:f:$ordinal')).toString()}';
        availability = AttachmentAvailability.omitted;
      }

      attachments.add(
        AttachmentRef(
          id: '$messageId:file:${ordinal++}',
          mimeType: effectiveMime,
          name: name,
          kind: OpenValue.known(kind),
          width: width,
          height: height,
          availability: OpenValue.known(availability),
          content: OutputRef(
            id: contentId,
            mimeType: effectiveMime,
            sizeBytes: sizeBytes,
          ),
        ),
      );
    }
    if (unprojectedFiles.isNotEmpty) {
      unprojectedCounts['files'] = unprojectedFiles.length;
    }
  }

  // 3. Project metadata (`displayText`, `attachments[]`, `codewalk.audio[]`,
  //    `codewalk.location[]`). Malformed optional metadata never crashes the row.
  String? metaDisplayText;
  final syntheticPaths = <String>[];
  var projectedLocationsFromMeta = false;
  if (rawMetadata is Map<String, Object?>) {
    final dt = rawMetadata['displayText'];
    if (dt is String && dt.length <= _maxDisplayTextChars) {
      metaDisplayText = dt;
    }
    final audioByPath = <String, Map<String, Object?>>{};
    List<Object?>? rawLocations;
    final cw = rawMetadata['codewalk'];
    if (cw is Map<String, Object?>) {
      final rawAudio = cw['audio'];
      if (rawAudio is List<Object?>) {
        for (final entry in rawAudio) {
          if (entry is Map<String, Object?> && entry['path'] is String) {
            audioByPath[entry['path']! as String] = entry;
          }
        }
      }
      if (cw['location'] case final List<Object?> locs) {
        rawLocations = locs;
      }
    }

    final rawMetaAttachments = rawMetadata['attachments'];
    if (rawMetaAttachments is List<Object?>) {
      for (final entry in rawMetaAttachments) {
        if (attachments.length >= _maxProjectedAttachments) break;
        if (entry is! Map<String, Object?>) continue;
        final path = entry['path'];
        if (path is! String || path.isEmpty || path.length > _maxFieldChars) {
          continue;
        }
        syntheticPaths.add(path);
        final pathDigest = sha256.convert(utf8.encode(path)).toString();
        if (!seenPathKeys.add(pathDigest)) continue;

        final audioMeta = audioByPath[path];
        final rawMime =
            (audioMeta?['mime'] is String ? audioMeta!['mime']! as String : null) ??
            (entry['mime'] is String ? entry['mime']! as String : null) ??
            'application/octet-stream';
        final mime = rawMime.split(';').first.trim().toLowerCase();
        final effectiveMime =
            mime.isEmpty ? 'application/octet-stream' : mime;
        final rawName =
            (audioMeta?['name'] is String ? audioMeta!['name']! as String : null) ??
            (entry['name'] is String ? entry['name']! as String : null) ??
            openCodeBasename(path);
        final name = _optionalShortName(rawName);
        final bytes =
            _optionalNonNegativeInt(audioMeta?['bytes']) ??
            _optionalNonNegativeInt(entry['bytes']);
        final sha = audioMeta?['sha256'] ?? entry['sha256'];
        final hasLocalHash =
            sha is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha);
        final kind = audioMeta != null
            ? AttachmentKind.audio
            : openCodeAttachmentKindForMime(effectiveMime);

        attachments.add(
          AttachmentRef(
            id: '$messageId:path:${ordinal++}',
            mimeType: effectiveMime,
            name: name,
            kind: OpenValue.known(kind),
            availability: OpenValue.known(
              hasLocalHash
                  ? AttachmentAvailability.remote
                  : AttachmentAvailability.omitted,
            ),
            content: OutputRef(
              id: hasLocalHash ? 'local:$sha' : 'path:$pathDigest',
              mimeType: effectiveMime,
              sizeBytes: bytes,
            ),
          ),
        );
      }
    }
    // Also project any `codewalk.audio` entries whose path was absent from
    // `metadata.attachments`.
    for (final entry in audioByPath.values) {
      if (attachments.length >= _maxProjectedAttachments) break;
      final path = entry['path']! as String;
      final pathDigest = sha256.convert(utf8.encode(path)).toString();
      if (!seenPathKeys.add(pathDigest)) continue;
      syntheticPaths.add(path);
      final mime =
          (entry['mime'] is String && (entry['mime']! as String).isNotEmpty)
          ? (entry['mime']! as String).split(';').first.trim().toLowerCase()
          : 'audio/mpeg';
      final sha = entry['sha256'];
      final hasLocalHash =
          sha is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(sha);
      attachments.add(
        AttachmentRef(
          id: '$messageId:audio:${ordinal++}',
          mimeType: mime,
          name: _optionalShortName(entry['name']) ?? openCodeBasename(path),
          kind: const OpenValue.known(AttachmentKind.audio),
          availability: OpenValue.known(
            hasLocalHash
                ? AttachmentAvailability.remote
                : AttachmentAvailability.omitted,
          ),
          content: OutputRef(
            id: hasLocalHash ? 'local:$sha' : 'path:$pathDigest',
            mimeType: mime,
            sizeBytes: _optionalNonNegativeInt(entry['bytes']),
          ),
        ),
      );
    }
    if (rawLocations != null) {
      for (final entry in rawLocations) {
        if (attachments.length >= _maxProjectedAttachments) break;
        final point = _parseLocationMap(entry);
        if (point == null) continue;
        projectedLocationsFromMeta = true;
        attachments.add(_locationAttachment(messageId, ordinal++, point));
      }
    }
  }

  // 4. Fallback: parse `[codewalk-location v1]` blocks from text if metadata
  //    was dropped or absent, and compute clean displayText.
  final fenced = parseCodeWalkLocationFences(rawText);
  if (!projectedLocationsFromMeta && fenced.locations.isNotEmpty) {
    for (final point in fenced.locations) {
      if (attachments.length >= _maxProjectedAttachments) break;
      attachments.add(_locationAttachment(messageId, ordinal++, point));
    }
  }

  String displayText;
  if (metaDisplayText != null) {
    displayText = metaDisplayText;
  } else {
    displayText = _stripTrailingPathLines(fenced.remainingText, syntheticPaths);
  }

  Map<String, Object?>? manifest;
  if (unprojectedCounts.values.any((v) => (v as int) > 0)) {
    manifest = {
      'type': 'user-context-manifest',
      'reason': 'contentResolutionUnavailable',
      'counts': unprojectedCounts,
      'files': unprojectedFiles,
      'contextNotProjected': true,
    };
  }

  return OpenCodeProjectedUserAttachments(
    displayText: displayText,
    attachments: List.unmodifiable(attachments),
    unprojectedManifest: manifest,
  );
}

AttachmentRef _locationAttachment(
  String messageId,
  int ordinal,
  GeoPoint point,
) {
  final key =
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)},${point.label ?? ''}';
  final digest = sha256.convert(utf8.encode(key)).toString();
  return AttachmentRef(
    id: '$messageId:loc:$ordinal',
    mimeType: 'application/geo+json',
    name: point.label,
    kind: const OpenValue.known(AttachmentKind.location),
    location: point,
    availability: const OpenValue.known(AttachmentAvailability.ready),
    content: OutputRef(id: 'geo:$digest', mimeType: 'application/geo+json'),
  );
}

GeoPoint? _parseLocationMap(Object? entry) {
  if (entry is! Map<String, Object?>) return null;
  final lat = entry['latitude'];
  final lon = entry['longitude'];
  if (lat is! num || lon is! num) return null;
  final acc = entry['accuracyMeters'];
  final label = entry['label'];
  try {
    return GeoPoint(
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      accuracyMeters: acc is num ? acc.toDouble() : null,
      label: label is String ? label : null,
    );
  } on ArgumentError {
    return null;
  }
}

String _stripTrailingPathLines(String text, List<String> paths) {
  if (paths.isEmpty || text.isEmpty) return text;
  final expected = {for (final p in paths) formatOpenCodeAttachmentReference(p)};
  final lines = text.split('\n');
  while (lines.isNotEmpty && expected.contains(lines.last)) {
    lines.removeLast();
  }
  return lines.join('\n');
}

String _requireShortText(Object? value, {required bool nonempty}) {
  if (value is! String ||
      (nonempty && value.isEmpty) ||
      value.length > _maxFieldChars) {
    throw const FormatException('Malformed attachment metadata string.');
  }
  return value;
}

String? _optionalShortName(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > _maxFieldChars) return null;
  return openCodeBasename(trimmed).isEmpty ? trimmed : openCodeBasename(trimmed);
}

int? _optionalNonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
