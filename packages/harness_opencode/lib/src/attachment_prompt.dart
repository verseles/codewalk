import 'package:codewalk_core/codewalk_core.dart';

import 'attachment_encoding.dart';

/// Prepared attachment ready to be sealed into a single deterministic
/// `POST /api/session/{id}/prompt` body.
sealed class OpenCodePreparedAttachment {
  const OpenCodePreparedAttachment();
}

/// Inline base64 attachment carried in wire `files[]` (`data:<mime>;base64,...`).
final class OpenCodeInlineAttachment extends OpenCodePreparedAttachment {
  const OpenCodeInlineAttachment({
    required this.name,
    required this.mimeType,
    required this.base64Data,
    required this.byteSize,
    this.width,
    this.height,
  });

  final String name;
  final String mimeType;
  final String base64Data;
  final int byteSize;
  final int? width;
  final int? height;
}

/// Server-staged file/audio attachment carried as an `Attached file:` line
/// in wire `text` and `{name, mime, path}` in `metadata.attachments` (plus
/// optional `metadata.codewalk.audio` descriptor). Never placed in `files[]`.
final class OpenCodePathAttachment extends OpenCodePreparedAttachment {
  const OpenCodePathAttachment({
    required this.name,
    required this.mimeType,
    required this.serverPath,
    required this.byteSize,
    required this.kind,
    this.sha256,
  });

  final String name;
  final String mimeType;
  final String serverPath;
  final int byteSize;
  final AttachmentKind kind;
  final String? sha256;
}

/// Geographic location attachment carried as a `[codewalk-location v1]` block
/// in wire `text` and structured coordinates in `metadata.codewalk.location`.
final class OpenCodeLocationAttachment extends OpenCodePreparedAttachment {
  const OpenCodeLocationAttachment({required this.point});
  final GeoPoint point;
}

/// Deterministic wire fields produced by [buildOpenCodePromptEnvelope].
final class OpenCodePromptEnvelope {
  const OpenCodePromptEnvelope({
    required this.displayText,
    required this.wireText,
    required this.files,
    required this.metadata,
  });

  final String displayText;
  final String wireText;
  final List<Map<String, Object?>> files;
  final Map<String, Object?>? metadata;
}

final _base64Whitespace = RegExp(r'\s');

/// Builds the deterministic `text`, `files`, and `metadata` fields for
/// `POST /api/session/{id}/prompt`. Returns a finite refusal reason string on
/// validation failure (`tooManyAttachments`, `tooLarge`, `unsupportedMime`,
/// `invalidAttachment`, `unsafePath`, `emptyText`).
({OpenCodePromptEnvelope? envelope, String? refusal})
buildOpenCodePromptEnvelope({
  required String displayText,
  required List<OpenCodePreparedAttachment> attachments,
}) {
  if (attachments.isEmpty && displayText.trim().isEmpty) {
    return (envelope: null, refusal: 'emptyText');
  }
  if (attachments.length > openCodeMaxAttachmentsPerPrompt) {
    return (envelope: null, refusal: 'tooManyAttachments');
  }

  final files = <Map<String, Object?>>[];
  final metaAttachments = <Map<String, Object?>>[];
  final metaAudio = <Map<String, Object?>>[];
  final metaLocations = <Map<String, Object?>>[];
  final syntheticLines = <String>[];
  var inlineTotalBytes = 0;

  for (final attachment in attachments) {
    switch (attachment) {
      case OpenCodeInlineAttachment(
        :final name,
        :final mimeType,
        :final base64Data,
        :final byteSize,
      ):
        final mime = mimeType.split(';').first.trim().toLowerCase();
        final isText = openCodeIsInlineTextMime(mime);
        final allowed =
            openCodeInlineImageMimes.contains(mime) ||
            mime == 'application/pdf' ||
            isText;
        if (!allowed) return (envelope: null, refusal: 'unsupportedMime');
        if (byteSize < 0 ||
            byteSize > openCodeMaxInlineAttachmentBytes ||
            (isText && byteSize > openCodeMaxInlineTextBytes)) {
          return (envelope: null, refusal: 'tooLarge');
        }
        inlineTotalBytes += byteSize;
        if (inlineTotalBytes > openCodeMaxInlineAttachmentBytes) {
          return (envelope: null, refusal: 'tooLarge');
        }
        if (base64Data.isEmpty || _base64Whitespace.hasMatch(base64Data)) {
          return (envelope: null, refusal: 'invalidAttachment');
        }
        final cleanName = name.trim().isEmpty
            ? 'attachment'
            : sanitizeOpenCodeUploadFilename(name);
        files.add({
          'uri': 'data:$mime;base64,$base64Data',
          'name': cleanName,
        });

      case OpenCodePathAttachment(
        :final name,
        :final mimeType,
        :final serverPath,
        :final byteSize,
        :final kind,
        :final sha256,
      ):
        if (!isSafeAbsoluteOpenCodePath(serverPath)) {
          return (envelope: null, refusal: 'unsafePath');
        }
        if (byteSize < 0 || byteSize > openCodeMaxUploadBytes) {
          return (envelope: null, refusal: 'tooLarge');
        }
        final mime = mimeType.split(';').first.trim().toLowerCase();
        if (mime.isEmpty) {
          return (envelope: null, refusal: 'invalidAttachment');
        }
        final cleanName = name.trim().isEmpty
            ? openCodeBasename(serverPath)
            : sanitizeOpenCodeUploadFilename(name);
        syntheticLines.add(formatOpenCodeAttachmentReference(serverPath));
        // The local digest lets the sending device preview its own copy.
        metaAttachments.add({
          'name': cleanName,
          'mime': mime,
          'path': serverPath,
          'bytes': byteSize,
          if (sha256 != null && sha256.isNotEmpty) 'sha256': sha256,
        });
        if (kind == AttachmentKind.audio || mime.startsWith('audio/')) {
          metaAudio.add({
            'name': cleanName,
            'mime': mime,
            'path': serverPath,
            'bytes': byteSize,
            if (sha256 != null && sha256.isNotEmpty) 'sha256': sha256,
          });
        }

      case OpenCodeLocationAttachment(:final point):
        syntheticLines.add(formatCodeWalkLocationFence(point));
        metaLocations.add({
          'latitude': point.latitude,
          'longitude': point.longitude,
          if (point.accuracyMeters != null)
            'accuracyMeters': point.accuracyMeters,
          if (point.label != null) 'label': point.label,
        });
    }
  }

  final wireParts = <String>[
    if (displayText.trim().isNotEmpty) displayText,
    ...syntheticLines,
  ];
  final wireText = wireParts.isEmpty ? displayText : wireParts.join('\n');

  final hasPresentationMeta =
      metaAttachments.isNotEmpty ||
      metaAudio.isNotEmpty ||
      metaLocations.isNotEmpty;
  Map<String, Object?>? metadata;
  if (hasPresentationMeta) {
    final codewalk = <String, Object?>{
      'v': 1,
      if (metaAudio.isNotEmpty) 'audio': metaAudio,
      if (metaLocations.isNotEmpty) 'location': metaLocations,
    };
    metadata = {
      // Official OpenCode `readPromptPresentation` requires `displayText`
      // alongside `comments` and `attachments` to hide synthetic text lines.
      'displayText': displayText,
      'comments': const <Object?>[],
      if (metaAttachments.isNotEmpty) 'attachments': metaAttachments,
      if (metaAudio.isNotEmpty || metaLocations.isNotEmpty)
        'codewalk': codewalk,
    };
  }

  return (
    envelope: OpenCodePromptEnvelope(
      displayText: displayText,
      wireText: wireText,
      files: List.unmodifiable(files),
      metadata: metadata,
    ),
    refusal: null,
  );
}
