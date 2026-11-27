import 'dart:async';
import 'dart:typed_data';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../platform/sessions/attachment_staging_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/sessions/session_attachments.dart';
import 'composer_attachments_controller.dart';

/// Displays staged attachments inside the composer above the input field with
/// thumbnails, metadata, honest model-modality notes, and removal buttons.
class ComposerAttachmentStrip extends StatelessWidget {
  const ComposerAttachmentStrip({
    super.key,
    required this.attachments,
    this.enabled = true,
    this.modelInputModalities = const {},
    this.supportsStageUpload = true,
  });

  final ComposerAttachmentsController attachments;
  final bool enabled;
  final Map<String, bool?> modelInputModalities;
  final bool supportsStageUpload;

  bool _willUploadAsFile(StagedAttachment item) {
    if (item.kind == AttachmentKind.location) return false;
    if (item.kind == AttachmentKind.audio) return true;
    if (item.byteSize > maxInlineAttachmentBytes) return true;
    final mime = item.mimeType.toLowerCase();
    if (mime.startsWith('image/') && modelInputModalities['image'] == false) {
      return true;
    }
    if (mime == 'application/pdf' && modelInputModalities['pdf'] != true) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: attachments,
    builder: (context, _) {
      if (attachments.isEmpty) return const SizedBox.shrink();
      final staging = context.read<AttachmentStagingStore?>();
      final blobs = context.read<AttachmentBlobRepository?>();
      return Padding(
        key: const ValueKey('composer-attachment-strip'),
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in attachments.items)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: _StagedChip(
                    key: ValueKey('composer-attachment-${item.id}'),
                    item: item,
                    blobs: blobs,
                    enabled: enabled,
                    uploadedAsFile:
                        supportsStageUpload && _willUploadAsFile(item),
                    onRemove: () => unawaited(
                      attachments.remove(item.id, storeOverride: staging),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _StagedChip extends StatefulWidget {
  const _StagedChip({
    super.key,
    required this.item,
    required this.blobs,
    required this.enabled,
    required this.uploadedAsFile,
    required this.onRemove,
  });

  final StagedAttachment item;
  final AttachmentBlobRepository? blobs;
  final bool enabled;
  final bool uploadedAsFile;
  final VoidCallback onRemove;

  @override
  State<_StagedChip> createState() => _StagedChipState();
}

class _StagedChipState extends State<_StagedChip> {
  Future<Uint8List?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  @override
  void didUpdateWidget(covariant _StagedChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.sha256 != widget.item.sha256 ||
        oldWidget.item.kind != widget.item.kind) {
      _loadThumb();
    }
  }

  void _loadThumb() {
    final item = widget.item;
    final blobs = widget.blobs;
    final pixels = (item.width ?? 0) * (item.height ?? 0);
    if (item.kind == AttachmentKind.image &&
        item.sha256 != null &&
        blobs != null &&
        pixels <= 25000000) {
      _thumbFuture = blobs.readBytes(
        item.sha256!,
        maxBytes: maxInlineAttachmentBytes,
      );
    } else {
      _thumbFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;

    final String title;
    final String subtitle;
    final IconData fallbackIcon;
    switch (item.kind) {
      case AttachmentKind.image:
        title = item.name ?? l10n.composerAttachImage;
        subtitle = widget.uploadedAsFile
            ? '${formatAttachmentBytes(item.byteSize)} · ${l10n.composerAttachUploadedAsFile}'
            : formatAttachmentBytes(item.byteSize);
        fallbackIcon = Symbols.image;
      case AttachmentKind.audio:
        title = item.name ?? l10n.composerAttachAudio;
        subtitle = formatAttachmentBytes(item.byteSize);
        fallbackIcon = Symbols.audio_file;
      case AttachmentKind.location:
        final pt = item.location!;
        title = pt.label ?? l10n.composerAttachLocation;
        subtitle =
            '${pt.latitude.toStringAsFixed(4)}, ${pt.longitude.toStringAsFixed(4)}';
        fallbackIcon = Symbols.location_on;
      case AttachmentKind.file || AttachmentKind.unknown:
        title = item.name ?? l10n.composerAttachFile;
        subtitle = widget.uploadedAsFile
            ? '${formatAttachmentBytes(item.byteSize)} · ${l10n.composerAttachUploadedAsFile}'
            : formatAttachmentBytes(item.byteSize);
        fallbackIcon = item.mimeType == 'application/pdf'
            ? Symbols.picture_as_pdf
            : Symbols.description;
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, minHeight: 44),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 2, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _leading(scheme, fallbackIcon),
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
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('composer-attachment-remove-${item.id}'),
                tooltip: l10n.composerAttachRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: const Icon(Symbols.close, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leading(ColorScheme scheme, IconData fallbackIcon) {
    final future = _thumbFuture;
    if (future == null) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(fallbackIcon, size: 18, color: scheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: 34,
        child: FutureBuilder<Uint8List?>(
          future: future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  fallbackIcon,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              );
            }
            return Image.memory(
              data,
              width: 34,
              height: 34,
              cacheWidth: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  fallbackIcon,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
