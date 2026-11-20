import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_picker.dart';
import '../../shared/widgets/app_snack_bar.dart';

/// Clickable geographic location card in the timeline. Always builds an
/// allowlisted numeric map URI via [MapUriLauncher] and never trusts URLs
/// embedded in labels or metadata.
class LocationAttachmentCard extends StatelessWidget {
  const LocationAttachmentCard({
    super.key,
    required this.attachment,
    required this.point,
  });

  final AttachmentRef attachment;
  final GeoPoint point;

  Future<void> _openMap(BuildContext context) async {
    final launcher = context.read<MapUriLauncher?>();
    final opened = launcher != null && await launcher.launchLocation(point);
    if (!opened && context.mounted) {
      final coords =
          '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      unawaited(Clipboard.setData(ClipboardData(text: coords)));
      showAppSnackBar(
        ScaffoldMessenger.maybeOf(context),
        context.v2L10n.attachmentMapFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = point.label ?? l10n.composerAttachLocation;
    final coords =
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    final accuracy = point.accuracyMeters != null
        ? ' · ±${point.accuracyMeters!.round()}m'
        : '';

    return Semantics(
      button: true,
      label: '${l10n.attachmentOpenMap}: $title ($coords)',
      child: Material(
        key: ValueKey('attachment-location-${attachment.id}'),
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(_openMap(context)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Symbols.location_on,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        '$coords$accuracy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Symbols.open_in_new,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
