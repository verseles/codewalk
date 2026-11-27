import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart' hide ConnectionState;
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';

/// Maximum pixel area decoded inline for thumbnails and lightbox (25 MP).
const _maxInlineImagePixels = 25000000;

/// Maximum decoded edge dimension for the fullscreen lightbox so images with
/// missing/untrusted dimensions can never cause unbounded RAM decode spikes.
const _maxLightboxDecodeDimension = 2048;

bool _dimensionsExceedPixelGuard(
  ({int width, int height})? probed,
  AttachmentRef attachment,
) {
  final pw = probed?.width ?? 0;
  final ph = probed?.height ?? 0;
  if (pw > 0 && ph > 0 && pw * ph > _maxInlineImagePixels) return true;
  final aw = attachment.width ?? 0;
  final ah = attachment.height ?? 0;
  return aw > 0 && ah > 0 && aw * ah > _maxInlineImagePixels;
}

/// Renders an image attachment thumbnail loaded lazily through [facet], with
/// bounded decode dimensions, >25 MP guard, error/retry state, and tap-to-zoom
/// fullscreen lightbox.
class AttachmentImageThumbnail extends StatefulWidget {
  const AttachmentImageThumbnail({
    super.key,
    required this.attachment,
    required this.facet,
    this.onOpenExternal,
  });

  final AttachmentRef attachment;
  final AttachmentFacet? facet;
  final Future<void> Function(AttachmentMedia media)? onOpenExternal;

  @override
  State<AttachmentImageThumbnail> createState() =>
      _AttachmentImageThumbnailState();
}

class _AttachmentImageThumbnailState extends State<AttachmentImageThumbnail> {
  Future<AttachmentMedia?>? _loadFuture;
  bool _failed = false;

  bool get _exceedsPixelGuard {
    final w = widget.attachment.width ?? 0;
    final h = widget.attachment.height ?? 0;
    return w > 0 && h > 0 && w * h > _maxInlineImagePixels;
  }

  bool get _unavailable =>
      widget.facet == null ||
      widget.attachment.availability.known == AttachmentAvailability.omitted ||
      widget.attachment.availability.known ==
          AttachmentAvailability.unavailable;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant AttachmentImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.content.id != widget.attachment.content.id ||
        !identical(oldWidget.facet, widget.facet)) {
      _startLoad();
    }
  }

  void _startLoad() {
    _failed = false;
    final facet = widget.facet;
    if (facet == null || _unavailable || _exceedsPixelGuard) {
      _loadFuture = null;
      return;
    }
    _loadFuture = facet.read(widget.attachment).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
      return null;
    });
  }

  void _openLightbox(
    BuildContext context,
    AttachmentMedia media, {
    ({int width, int height})? probedDimensions,
  }) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _AttachmentImageLightbox(
            attachment: widget.attachment,
            media: media,
            probedDimensions: probedDimensions,
            onOpenExternal: widget.onOpenExternal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = widget.attachment.name ?? l10n.composerAttachImage;

    if (_unavailable || _exceedsPixelGuard) {
      return _fallbackTile(
        context,
        scheme,
        icon: Symbols.image,
        title: name,
        subtitle: l10n.attachmentPreviewUnavailable,
        onTap: _exceedsPixelGuard && widget.facet != null
            ? () async {
                final media = await widget.facet!.read(widget.attachment);
                if (media != null) {
                  await widget.onOpenExternal?.call(media);
                }
              }
            : null,
      );
    }

    return FutureBuilder<AttachmentMedia?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            key: ValueKey('attachment-image-loading-${widget.attachment.id}'),
            width: 140,
            height: 112,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const AppIndeterminateRing(size: 20, strokeWidth: 2),
          );
        }

        final media = snapshot.data;
        if (_failed || media == null || media.bytes.isEmpty) {
          return _fallbackTile(
            context,
            scheme,
            icon: Symbols.broken_image,
            title: name,
            subtitle: l10n.attachmentLoadFailed,
            trailingAction: TextButton(
              key: ValueKey('attachment-image-retry-${widget.attachment.id}'),
              onPressed: () => setState(_startLoad),
              child: Text(l10n.attachmentRetry),
            ),
          );
        }

        // Probe real dimensions from the fetched bytes so timeline images
        // (whose wire entries omit width/height) or understated metadata
        // never bypass the >25 MP inline decode guard.
        final probed = probeImageDimensions(media.bytes, media.mimeType);
        if (_dimensionsExceedPixelGuard(probed, widget.attachment)) {
          return _fallbackTile(
            context,
            scheme,
            icon: Symbols.image,
            title: name,
            subtitle: l10n.attachmentPreviewUnavailable,
            onTap: widget.onOpenExternal == null
                ? null
                : () => unawaited(widget.onOpenExternal!(media)),
          );
        }

        return Semantics(
          button: true,
          label: '${l10n.attachmentImagePreview}: $name',
          child: Material(
            key: ValueKey('attachment-image-${widget.attachment.id}'),
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  _openLightbox(context, media, probedDimensions: probed),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 96,
                  maxWidth: 220,
                  minHeight: 88,
                  maxHeight: 180,
                ),
                child: Image.memory(
                  media.bytes,
                  cacheWidth: 384,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => SizedBox(
                    width: 140,
                    height: 100,
                    child: Center(
                      child: Icon(
                        Symbols.broken_image,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackTile(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailingAction,
  }) {
    final theme = Theme.of(context);
    return Material(
      key: ValueKey('attachment-image-fallback-${widget.attachment.id}'),
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingAction != null) ...[
                const SizedBox(width: 6),
                trailingAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentImageLightbox extends StatelessWidget {
  const _AttachmentImageLightbox({
    required this.attachment,
    required this.media,
    this.probedDimensions,
    this.onOpenExternal,
  });

  final AttachmentRef attachment;
  final AttachmentMedia media;
  final ({int width, int height})? probedDimensions;
  final Future<void> Function(AttachmentMedia media)? onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final title = attachment.name ?? l10n.composerAttachImage;
    final sizeBytes = attachment.content.sizeBytes ?? media.bytes.length;
    final dims =
        probedDimensions ?? probeImageDimensions(media.bytes, media.mimeType);
    int? cacheWidth;
    int? cacheHeight;
    if (dims == null) {
      // Unknown or unprobed format: always cap decode width so a hostile or
      // huge image cannot decode at unbounded resolution.
      cacheWidth = _maxLightboxDecodeDimension;
    } else if (dims.width > _maxLightboxDecodeDimension ||
        dims.height > _maxLightboxDecodeDimension) {
      if (dims.width >= dims.height) {
        cacheWidth = _maxLightboxDecodeDimension;
      } else {
        cacheHeight = _maxLightboxDecodeDimension;
      }
    }
    return Scaffold(
      key: const ValueKey('attachment-image-lightbox'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
            Text(
              formatAttachmentBytes(sizeBytes),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (onOpenExternal != null)
            IconButton(
              tooltip: l10n.attachmentOpenFile,
              icon: const Icon(Symbols.open_in_new),
              onPressed: () => unawaited(onOpenExternal!(media)),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(
            media.bytes,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Symbols.broken_image,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
