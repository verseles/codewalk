import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_picker.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'attachment_image_viewer.dart';
import 'audio_attachment_card.dart';
import 'location_attachment_card.dart';
import 'session_attachment_scope.dart';

/// Renders canonical [UserInput.attachments] inside a user timeline bubble:
/// image thumbnails with lightbox, inline audio players, clickable map
/// location cards, and file cards that open app-owned cached bytes only.
class SessionAttachmentStrip extends StatelessWidget {
  const SessionAttachmentStrip({super.key, required this.attachments});

  final List<AttachmentRef> attachments;

  Future<void> _openMediaExternally(
    BuildContext context,
    AttachmentRef attachment,
    AttachmentMedia media,
  ) async {
    final opener = context.read<AttachmentFileOpener?>();
    final filename = sanitizeAttachmentFilename(
      attachment.name ?? _defaultNameForMime(media.mimeType),
    );
    final opened =
        opener != null &&
        await opener.openBytes(
          bytes: media.bytes,
          filename: filename,
          mimeType: media.mimeType,
        );
    if (!opened && context.mounted) {
      showAppSnackBar(
        ScaffoldMessenger.maybeOf(context),
        context.v2L10n.attachmentOpenFailed,
      );
    }
  }

  static String _defaultNameForMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower == 'application/pdf') return 'document.pdf';
    if (lower == 'image/png') return 'image.png';
    if (lower == 'image/jpeg') return 'image.jpg';
    if (lower == 'image/webp') return 'image.webp';
    if (lower == 'image/gif') return 'image.gif';
    if (lower.startsWith('text/')) return 'attachment.txt';
    return 'attachment.bin';
  }

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    final facet = SessionAttachmentScope.maybeOf(context);
    final images = <AttachmentRef>[];
    final cards = <AttachmentRef>[];
    for (final item in attachments) {
      final kind = item.kind.known ?? attachmentKindForMime(item.mimeType);
      if (kind == AttachmentKind.image) {
        images.add(item);
      } else {
        cards.add(item);
      }
    }

    return Column(
      key: const ValueKey('timeline-attachment-strip'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final img in images)
                AttachmentImageThumbnail(
                  attachment: img,
                  facet: facet,
                  onOpenExternal: (media) =>
                      _openMediaExternally(context, img, media),
                ),
            ],
          ),
        for (var i = 0; i < cards.length; i++) ...[
          if (images.isNotEmpty || i > 0) const SizedBox(height: 8),
          _buildCard(context, cards[i], facet),
        ],
      ],
    );
  }

  Widget _buildCard(
    BuildContext context,
    AttachmentRef attachment,
    AttachmentFacet? facet,
  ) {
    final kind =
        attachment.kind.known ?? attachmentKindForMime(attachment.mimeType);
    if (kind == AttachmentKind.location && attachment.location != null) {
      return LocationAttachmentCard(
        attachment: attachment,
        point: attachment.location!,
      );
    }
    if (kind == AttachmentKind.audio) {
      return AudioAttachmentCard(attachment: attachment, facet: facet);
    }
    return _FileAttachmentCard(
      attachment: attachment,
      facet: facet,
      onOpenMedia: (media) => _openMediaExternally(context, attachment, media),
    );
  }
}

class _FileAttachmentCard extends StatefulWidget {
  const _FileAttachmentCard({
    required this.attachment,
    required this.facet,
    required this.onOpenMedia,
  });

  final AttachmentRef attachment;
  final AttachmentFacet? facet;
  final Future<void> Function(AttachmentMedia media) onOpenMedia;

  @override
  State<_FileAttachmentCard> createState() => _FileAttachmentCardState();
}

class _FileAttachmentCardState extends State<_FileAttachmentCard> {
  bool _opening = false;

  bool get _canOpen =>
      widget.facet != null &&
      widget.attachment.availability.known != AttachmentAvailability.omitted &&
      widget.attachment.availability.known !=
          AttachmentAvailability.unavailable;

  IconData _iconForMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower == 'application/pdf') return Symbols.picture_as_pdf;
    if (lower.startsWith('text/') ||
        lower == 'application/json' ||
        lower == 'application/xml') {
      return Symbols.article;
    }
    if (lower.contains('zip') ||
        lower.contains('tar') ||
        lower.contains('gzip')) {
      return Symbols.folder_zip;
    }
    return Symbols.description;
  }

  Future<void> _tap() async {
    if (_opening) return;
    final l10n = context.v2L10n;
    final facet = widget.facet;
    if (!_canOpen || facet == null) {
      showAppSnackBar(
        ScaffoldMessenger.maybeOf(context),
        l10n.attachmentPreviewUnavailable,
      );
      return;
    }
    setState(() => _opening = true);
    try {
      final media = await facet.read(widget.attachment);
      if (!mounted) return;
      if (media == null || media.bytes.isEmpty) {
        showAppSnackBar(
          ScaffoldMessenger.maybeOf(context),
          l10n.attachmentPreviewUnavailable,
        );
        return;
      }
      await widget.onOpenMedia(media);
    } on Object {
      if (mounted) {
        showAppSnackBar(
          ScaffoldMessenger.maybeOf(context),
          l10n.attachmentOpenFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = widget.attachment.name ?? l10n.composerAttachFile;
    final sizeBytes = widget.attachment.content.sizeBytes;
    final mime = widget.attachment.mimeType;
    final details = [
      if (mime.isNotEmpty && mime != 'application/octet-stream') mime,
      if (sizeBytes != null) formatAttachmentBytes(sizeBytes),
      if (!_canOpen) l10n.attachmentPreviewUnavailable,
    ].join(' · ');

    return Semantics(
      button: _canOpen,
      label: '${l10n.attachmentOpenFile}: $name',
      child: Material(
        key: ValueKey('attachment-file-${widget.attachment.id}'),
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_tap()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _opening
                      ? const Center(
                          child: AppIndeterminateRing(size: 18, strokeWidth: 2),
                        )
                      : Icon(
                          _iconForMime(mime),
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_canOpen) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Symbols.open_in_new,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
