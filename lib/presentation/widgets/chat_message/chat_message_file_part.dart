part of '../chat_message_widget.dart';

/// Issue #177: byte-bounded LRU of decoded data-URI attachment bytes.
/// Screenshots decode from multi-MB base64 on every timeline rebuild
/// (including every streaming batch); decoding once and reusing removes
/// the largest per-frame CPU/RAM spike in the render path.
const int _maxDataUriBytesCached = 32 * 1024 * 1024;

class _CachedDataUriBytes {
  const _CachedDataUriBytes({required this.url, required this.bytes});

  final String url;
  final Uint8List bytes;
}

final LinkedHashMap<String, _CachedDataUriBytes> _dataUriBytesCache =
    LinkedHashMap<String, _CachedDataUriBytes>();
int _dataUriBytesCached = 0;

Uint8List? _cachedDataUriBytes(String partId, String dataUrl) {
  // Cheap composite key; the full URL equality check on hits rules out
  // hash collisions ever showing the wrong image.
  final key = '$partId:${dataUrl.length}:${dataUrl.hashCode}';
  final hit = _dataUriBytesCache.remove(key);
  if (hit != null) {
    if (hit.url == dataUrl) {
      _dataUriBytesCache[key] = hit;
      return hit.bytes;
    }
    _dataUriBytesCached -= hit.bytes.length;
  }
  Uint8List? bytes;
  try {
    bytes = Uint8List.fromList(UriData.parse(dataUrl).contentAsBytes());
  } catch (_) {
    return null;
  }
  if (bytes.isEmpty) {
    return null;
  }
  _dataUriBytesCache[key] = _CachedDataUriBytes(url: dataUrl, bytes: bytes);
  _dataUriBytesCached += bytes.length;
  while (_dataUriBytesCached > _maxDataUriBytesCached &&
      _dataUriBytesCache.length > 1) {
    final oldestKey = _dataUriBytesCache.keys.first;
    final evicted = _dataUriBytesCache.remove(oldestKey);
    if (evicted == null) {
      break;
    }
    _dataUriBytesCached -= evicted.bytes.length;
  }
  return bytes;
}

/// File attachment rendering with image preview and action handling.
extension _ChatMessageFilePartBuilder on _ChatMessageWidgetState {
  Widget _buildFilePart(BuildContext context, FilePart part) {
    final theme = Theme.of(context);
    final visualTokens = theme.visualStyleTokens;
    final sourcePath = part.fileSource?.path ?? part.symbolSource?.path;
    final isInlineDataAttachment = _isInlineDataAttachment(part.url);
    final imagePreview = _buildImageAttachmentPreview(context, part);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visualTokens.isRefined
            ? visualTokens.cardSurface
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: visualTokens.isRefined
            ? visualTokens.cardRadius
            : AppShapes.borderSmall,
        border: Border.all(
          color: visualTokens.isRefined
              ? visualTokens.separator
              : theme.dividerColor,
          width: visualTokens.isRefined ? visualTokens.enabledBorderWidth : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePreview != null) ...[
            imagePreview,
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(_getFileIcon(part.mime), color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.filename ?? context.l10n.commonFile,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sourcePath != null && sourcePath.trim().isNotEmpty)
                      Text(
                        sourcePath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  unawaited(
                    _handleFilePartAction(
                      context,
                      url: part.url,
                      sourcePath: sourcePath,
                      mimeType: part.mime,
                      filename: part.filename,
                    ),
                  );
                },
                icon: Icon(
                  isInlineDataAttachment
                      ? Symbols.download_rounded
                      : Symbols.open_in_new_rounded,
                ),
                tooltip: isInlineDataAttachment
                    ? context.l10n.chatMessageSaveFile
                    : context.l10n.chatMessageOpenFile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildImageAttachmentPreview(BuildContext context, FilePart part) {
    if (!part.mime.toLowerCase().startsWith('image/')) {
      return null;
    }

    final image = _resolveAttachmentImageWidget(part.url, context, part.id);
    if (image == null) {
      return null;
    }

    final visualTokens = Theme.of(context).visualStyleTokens;
    return ClipRRect(
      key: ValueKey<String>('file_image_preview_${part.id}'),
      borderRadius: visualTokens.isRefined
          ? visualTokens.controlRadius
          : AppShapes.borderSmall,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220, minHeight: 120),
        child: Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surface,
          child: image,
        ),
      ),
    );
  }

  Widget? _resolveAttachmentImageWidget(
    String rawUrl,
    BuildContext context,
    String partId,
  ) {
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(trimmedUrl);
    if (parsed == null) {
      return null;
    }

    final scheme = parsed.scheme.toLowerCase();
    if (scheme == 'data') {
      final bytes = _cachedDataUriBytes(partId, trimmedUrl);
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        cacheHeight: _previewCacheHeight(context),
      );
    }
    if (scheme == 'http' || scheme == 'https') {
      return Image.network(
        trimmedUrl,
        fit: BoxFit.cover,
        cacheHeight: _previewCacheHeight(context),
      );
    }
    return null;
  }

  /// Decodes attachment previews at display height. A single-dimension bound
  /// keeps the aspect ratio intact during decode; without any bound a
  /// full-size screenshot decodes at native resolution on every rebuild,
  /// churning the image cache and driving the process toward low-memory
  /// kills. Height is the safer bound here: phone screenshots (tall) are the
  /// dominant attachment shape.
  int? _previewCacheHeight(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio <= 0) {
      return null;
    }
    return (220 * ratio).round();
  }

  Future<void> _handleFilePartAction(
    BuildContext context, {
    required String url,
    required String? sourcePath,
    required String mimeType,
    required String? filename,
  }) async {
    final result = await file_part_action.handleFilePartAction(
      url: url,
      sourcePath: sourcePath,
      mimeType: mimeType,
      filename: filename,
    );
    if (!context.mounted || result.message == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message!)));
  }

  bool _isInlineDataAttachment(String url) {
    if (url.trim().isEmpty) {
      return false;
    }
    final parsed = Uri.tryParse(url.trim());
    return parsed?.scheme.toLowerCase() == 'data';
  }

  IconData _getFileIcon(String mime) {
    if (mime.startsWith('image/')) {
      return Symbols.image;
    } else if (mime.startsWith('video/')) {
      return Symbols.video_file;
    } else if (mime.startsWith('audio/')) {
      return Symbols.audio_file;
    } else if (mime.contains('pdf')) {
      return Symbols.picture_as_pdf;
    } else if (mime.contains('text/')) {
      return Symbols.text_snippet;
    } else {
      return Symbols.insert_drive_file;
    }
  }
}
