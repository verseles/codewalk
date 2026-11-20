import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:codewalk_net/codewalk_net.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/media/attachment_sniff.dart';
import '../../shared/sessions/session_attachments.dart';
import '../../shared/sessions/session_live_source.dart';

/// Typed failure thrown when preparing attachments for an OpenCode prompt.
final class OpenCodeAttachmentPrepareException implements Exception {
  const OpenCodeAttachmentPrepareException(this.reason);
  final String reason;
  @override
  String toString() => 'OpenCodeAttachmentPrepareException($reason)';
}

/// Per-profile attachment lane for an OpenCode v2 endpoint:
/// - resolves timeline media (`media:<hash>`, `inline:<hash>`, `local:<sha256>`)
///   through [OpenCodeMediaClient] + local [AttachmentBlobRepository];
/// - caches inline base64 media extracted during history/inbox/SSE reads;
/// - prepares [PromptDraft.attachments] into inline base64 or streamed
///   `POST /api/experimental/fs/write` uploads before outbox sealing.
final class OpenCodeAttachmentLane implements AttachmentFacet {
  OpenCodeAttachmentLane({
    required EndpointHttpTransport transport,
    required HarnessRef harness,
    required String connectedVersion,
    required this.blobs,
    required this.temporaryPath,
    required this.view,
    required this.modelInputModalities,
    required this.currentBinding,
    OpenCodeMediaClient? mediaClient,
    OpenCodeAttachmentUploadClient? uploadClient,
  }) : _media = mediaClient ?? OpenCodeMediaClient(transport),
       _uploader =
           uploadClient ??
           OpenCodeAttachmentUploadClient(
             transport,
             harness: harness,
             connectedVersion: connectedVersion,
           );

  final AttachmentBlobRepository blobs;
  final String? temporaryPath;
  final SessionLiveView Function(SessionRef) view;
  final Map<String, bool?> Function(SessionRef) modelInputModalities;
  final bool Function() currentBinding;
  final OpenCodeMediaClient _media;
  final OpenCodeAttachmentUploadClient _uploader;
  final _pendingUploads = <RequestCancellation>{};
  final _rng = Random.secure();
  bool _closed = false;

  bool get supportsStageUpload =>
      !_closed &&
      currentBinding() &&
      temporaryPath != null &&
      temporaryPath!.isNotEmpty;

  bool get supportsMediaRead => !_closed && currentBinding();

  String _mintUploadId() => List.generate(
    16,
    (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Records inline base64 media extracted from history, inbox, or SSE frames
  /// into both memory LRU and local content-addressed blob storage.
  void cacheInlineMedia(String contentId, Uint8List bytes, String mimeType) {
    if (_closed) return;
    _media.putInline(contentId, bytes, mimeType);
    unawaited(
      blobs.putBytes(bytes).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  @override
  Future<AttachmentMedia?> read(AttachmentRef ref) async {
    if (_closed) return null;
    final id = ref.content.id;
    final fallbackMime = ref.content.mimeType ?? ref.mimeType;

    // 1. Check in-memory LRU cache first (covers inline:, media:, local:).
    if (_media.peek(id) case final hit?) return hit;

    // 2. Local or inline SHA-256 content-addressed blobs live in local store.
    if (id.startsWith('local:') || id.startsWith('inline:')) {
      final digest = id.substring(id.indexOf(':') + 1);
      if (RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
        try {
          final bytes = await blobs.readBytes(
            digest,
            maxBytes: maxAttachmentFileBytes,
          );
          if (bytes != null) {
            _media.putInline(id, bytes, fallbackMime);
            return AttachmentMedia(bytes: bytes, mimeType: fallbackMime);
          }
        } on Object {
          return null;
        }
      }
      return null;
    }

    // 3. Remote `media:<64-hex>`: check local blob cache by hash before network.
    final mediaHash = openCodeMediaHashFromUri(id);
    if (mediaHash != null) {
      try {
        final local = await blobs.readBytes(
          mediaHash,
          maxBytes: maxInlineAttachmentBytes,
        );
        if (local != null) {
          _media.putInline('media:$mediaHash', local, fallbackMime);
          return AttachmentMedia(bytes: local, mimeType: fallbackMime);
        }
      } on Object {
        // Fall through to remote fetch.
      }
      if (!currentBinding()) return null;
      final fetched = await _media.read(ref);
      if (fetched != null) {
        unawaited(
          blobs
              .putBytes(fetched.bytes)
              .then<void>((_) {}, onError: (Object _) {}),
        );
      }
      return fetched;
    }

    return null;
  }

  /// Resolves [draft.attachments] into wire-ready [OpenCodePreparedAttachment]s
  /// (inline base64 vs streamed `fs/write` uploads) BEFORE the outbox seals the
  /// prompt payload. Uploads happen once under a fresh UUID path so same-ID
  /// outbox replays reuse the exact sealed payload without re-uploading.
  Future<List<OpenCodePreparedAttachment>> prepareForSubmit({
    required SessionRef session,
    required PromptDraft draft,
    RequestCancellation? cancellation,
  }) async {
    if (draft.attachments.isEmpty) return const [];
    if (_closed || !currentBinding()) {
      throw const OpenCodeAttachmentPrepareException('sourceChanged');
    }
    final token = RequestCancellation();
    if (cancellation?.isCancelled ?? false) token.cancel();
    _pendingUploads.add(token);
    final cancelSub = cancellation?.onCancel.listen((_) => token.cancel());
    try {
      final modalities = modelInputModalities(session);
      final directory = view(session).state?.info?.project?.canonicalDirectory;
      final tmpDir = temporaryPath;
      final prepared = <OpenCodePreparedAttachment>[];
      var inlineTotal = 0;

      for (final ref in draft.attachments) {
        if (token.isCancelled || _closed || !currentBinding()) {
          throw const OpenCodeAttachmentPrepareException('cancelledBeforeSend');
        }
        final kind = ref.kind.known ?? attachmentKindForMime(ref.mimeType);
        if (kind == AttachmentKind.location) {
          final point = ref.location;
          if (point == null) {
            throw const OpenCodeAttachmentPrepareException('invalidAttachment');
          }
          prepared.add(OpenCodeLocationAttachment(point: point));
          continue;
        }

        final contentId = ref.content.id;
        if (!contentId.startsWith('local:')) {
          throw const OpenCodeAttachmentPrepareException('invalidAttachment');
        }
        final digest = contentId.substring('local:'.length);
        if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
          throw const OpenCodeAttachmentPrepareException('invalidAttachment');
        }
        final byteSize = await blobs.byteSizeOf(digest);
        if (byteSize == null || byteSize <= 0) {
          throw const OpenCodeAttachmentPrepareException('attachmentMissing');
        }
        if (byteSize > maxAttachmentFileBytes) {
          throw const OpenCodeAttachmentPrepareException('attachmentTooLarge');
        }
        final safeName = sanitizeAttachmentFilename(ref.name ?? 'attachment');
        final mime = ref.mimeType.split(';').first.trim().toLowerCase();

        final canInline =
            kind != AttachmentKind.audio &&
            canInlineOpenCodeAttachment(
              mimeType: mime,
              byteSize: byteSize,
              inputModalities: modalities,
            ) &&
            inlineTotal + byteSize <= openCodeMaxInlineAttachmentBytes;

        if (canInline) {
          final bytes = await blobs.readBytes(
            digest,
            maxBytes: openCodeMaxInlineAttachmentBytes,
          );
          if (bytes == null) {
            throw const OpenCodeAttachmentPrepareException('attachmentMissing');
          }
          final sniffed = sniffOpenCodeMime(bytes, filename: safeName);
          final stillInline =
              canInlineOpenCodeAttachment(
                mimeType: sniffed,
                byteSize: bytes.length,
                inputModalities: modalities,
              ) &&
              inlineTotal + bytes.length <= openCodeMaxInlineAttachmentBytes;
          if (stillInline) {
            inlineTotal += bytes.length;
            prepared.add(
              OpenCodeInlineAttachment(
                name: safeName,
                mimeType: sniffed,
                base64Data: base64Encode(bytes),
                byteSize: bytes.length,
                width: ref.width,
                height: ref.height,
              ),
            );
            continue;
          }
        }

        // Fall back to streamed temp upload via POST /api/experimental/fs/write.
        if (tmpDir == null ||
            tmpDir.isEmpty ||
            directory == null ||
            directory.isEmpty) {
          throw const OpenCodeAttachmentPrepareException('uploadUnavailable');
        }
        final stream = blobs.openRead(digest);
        if (stream == null) {
          throw const OpenCodeAttachmentPrepareException('attachmentMissing');
        }
        final result = await _uploader.upload(
          sessionDirectory: directory,
          temporaryPath: tmpDir,
          uploadId: _mintUploadId(),
          filename: safeName,
          bytes: stream,
          length: byteSize,
          cancellation: token,
        );
        switch (result) {
          case OpenCodeUploadCompleted(:final serverPath):
            prepared.add(
              OpenCodePathAttachment(
                name: safeName,
                mimeType: mime.isEmpty ? 'application/octet-stream' : mime,
                serverPath: serverPath,
                byteSize: byteSize,
                kind: kind,
                sha256: digest,
              ),
            );
          case OpenCodeUploadFailed(:final reason):
            throw OpenCodeAttachmentPrepareException(
              switch (reason) {
                'tooLarge' => 'attachmentTooLarge',
                'UnauthorizedError' ||
                'authenticationRequired' => 'authenticationRequired',
                'cancelled' || 'cancelledBeforeSend' => 'cancelledBeforeSend',
                'timeout' => 'timeout',
                'RateLimited' || 'rateLimited' => 'rateLimited',
                'unverifiedVersion' ||
                'unavailable' ||
                'uploadUnavailable' => 'uploadUnavailable',
                _ => 'uploadFailed',
              },
            );
        }
      }

      return prepared;
    } finally {
      _pendingUploads.remove(token);
      await cancelSub?.cancel();
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final token in _pendingUploads.toList()) {
      token.cancel();
    }
    _pendingUploads.clear();
    _media.dispose();
  }
}
