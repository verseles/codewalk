import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/i18n/l10n_bridge.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';

class SessionAttentionOverlay extends StatelessWidget {
  const SessionAttentionOverlay({
    super.key,
    required this.items,
    required this.expanded,
    required this.semanticLabel,
    required this.openLabel,
    required this.expandLabel,
    required this.collapseLabel,
    required this.readLabel,
    required this.stopReadingLabel,
    required this.dismissLabel,
    required this.stopOverlayLabel,
    required this.onOpen,
    required this.onToggleExpanded,
    required this.onDismiss,
    required this.onStopOverlay,
    this.onRead,
    this.activeSpeechSnapshotId,
  });

  final List<SessionAttentionItem> items;
  final bool expanded;
  final String semanticLabel;
  final String openLabel;
  final String expandLabel;
  final String collapseLabel;
  final String readLabel;
  final String stopReadingLabel;
  final String dismissLabel;
  final String stopOverlayLabel;
  final ValueChanged<SessionAttentionItem> onOpen;
  final VoidCallback onToggleExpanded;
  final ValueChanged<SessionAttentionItem> onDismiss;
  final ValueChanged<SessionAttentionItem>? onRead;
  final VoidCallback onStopOverlay;
  final String? activeSpeechSnapshotId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final ordered = List<SessionAttentionItem>.from(items)
      ..sort((left, right) {
        final priority = rootSessionAttentionPriority(
          right.kind,
        ).compareTo(rootSessionAttentionPriority(left.kind));
        if (priority != 0) return priority;
        final time = right.lastObservedAtEpochMs.compareTo(
          left.lastObservedAtEpochMs,
        );
        return time != 0
            ? time
            : left.identity.key.compareTo(right.identity.key);
      });
    return expanded
        ? _buildPanel(context, ordered)
        : _buildBubble(context, ordered.first, ordered.length);
  }

  Widget _buildBubble(
    BuildContext context,
    SessionAttentionItem primary,
    int count,
  ) {
    final colors = _colorsFor(context, primary.kind);
    return Semantics(
      label: '${_localizedKindLabel(primary.kind)}, $count, $semanticLabel',
      button: true,
      child: Material(
        key: const ValueKey<String>('session_attention_bubble'),
        color: colors.$1,
        shape: const CircleBorder(),
        elevation: 6,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onOpen(primary),
            onLongPress: onToggleExpanded,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(child: Icon(_iconFor(primary.kind), color: colors.$2)),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: Badge(label: Text('$count')),
                ),
                PositionedDirectional(
                  end: -8,
                  bottom: -8,
                  child: IconButton.filledTonal(
                    key: const ValueKey<String>('session_attention_expand'),
                    tooltip: expandLabel,
                    onPressed: onToggleExpanded,
                    icon: const Icon(Symbols.open_in_full, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, List<SessionAttentionItem> ordered) {
    return Material(
      key: const ValueKey<String>('session_attention_panel'),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    semanticLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('session_attention_collapse'),
                  tooltip: collapseLabel,
                  onPressed: onToggleExpanded,
                  icon: const Icon(Symbols.close_fullscreen),
                ),
                IconButton(
                  key: const ValueKey<String>('session_attention_stop'),
                  tooltip: stopOverlayLabel,
                  onPressed: onStopOverlay,
                  icon: const Icon(Symbols.stop_circle),
                ),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ordered.length,
                itemBuilder: (context, index) =>
                    _buildRow(context, ordered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, SessionAttentionItem item) {
    final colors = _colorsFor(context, item.kind);
    final reading = activeSpeechSnapshotId == item.snapshotId;
    final readEnabled =
        onRead != null &&
        item.speechText.isNotEmpty &&
        item.transportCapability !=
            SessionAttentionTransportCapability.reopenRequired;
    return Semantics(
      container: true,
      label:
          '${item.projectLabel}, ${item.title}, ${_localizedKindLabel(item.kind)}',
      child: Padding(
        key: ValueKey<String>('session_attention_item_${item.snapshotId}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_iconFor(item.kind), color: colors.$1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.projectLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (item.pauseReason != null)
                    Text(
                      _localizedPauseReasonLabel(item.pauseReason!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  if (item.displayText.isNotEmpty)
                    Text(
                      item.displayText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.displayTruncated || item.speechTruncated)
                    const Text(
                      '…',
                      key: ValueKey<String>('session_attention_truncated'),
                    ),
                  Wrap(
                    spacing: 4,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => onOpen(item),
                        child: Text(openLabel),
                      ),
                      TextButton(
                        onPressed: readEnabled ? () => onRead!(item) : null,
                        child: Text(reading ? stopReadingLabel : readLabel),
                      ),
                      TextButton(
                        onPressed: () => onDismiss(item),
                        child: Text(dismissLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RootSessionAttentionKind kind) => switch (kind) {
    RootSessionAttentionKind.error => Symbols.error,
    RootSessionAttentionKind.pendingInteraction => Symbols.help,
    RootSessionAttentionKind.completed => Symbols.check_circle,
    RootSessionAttentionKind.delayed => Symbols.schedule,
    RootSessionAttentionKind.receiving => Symbols.downloading,
    RootSessionAttentionKind.active => Symbols.progress_activity,
  };

  (Color, Color) _colorsFor(
    BuildContext context,
    RootSessionAttentionKind kind,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return switch (kind) {
      RootSessionAttentionKind.error => (scheme.error, scheme.onError),
      RootSessionAttentionKind.pendingInteraction => (
        scheme.tertiary,
        scheme.onTertiary,
      ),
      RootSessionAttentionKind.completed => (scheme.primary, scheme.onPrimary),
      RootSessionAttentionKind.delayed => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      RootSessionAttentionKind.receiving || RootSessionAttentionKind.active => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
  }

  String _localizedKindLabel(RootSessionAttentionKind kind) => switch (kind) {
    RootSessionAttentionKind.error =>
      L10nBridge.current?.sessionAttentionKindError ?? 'Error',
    RootSessionAttentionKind.pendingInteraction =>
      L10nBridge.current?.sessionAttentionKindPendingInteraction ??
          'Pending interaction',
    RootSessionAttentionKind.completed =>
      L10nBridge.current?.sessionAttentionKindCompleted ?? 'Completed',
    RootSessionAttentionKind.delayed =>
      L10nBridge.current?.sessionAttentionKindDelayed ?? 'Delayed',
    RootSessionAttentionKind.receiving =>
      L10nBridge.current?.sessionAttentionKindReceiving ?? 'Receiving',
    RootSessionAttentionKind.active =>
      L10nBridge.current?.sessionAttentionKindActive ?? 'Active',
  };

  String _localizedPauseReasonLabel(SessionAttentionPauseReason reason) =>
      switch (reason) {
        SessionAttentionPauseReason.cellularDataSaver =>
          L10nBridge.current?.sessionAttentionPauseCellularDataSaver ??
              'Cellular data saver is active',
        SessionAttentionPauseReason.oauthReopenRequired =>
          L10nBridge.current?.sessionAttentionPauseOauthReopenRequired ??
              'OAuth sign-in required',
        SessionAttentionPauseReason.tailscaleReopenRequired =>
          L10nBridge.current?.sessionAttentionPauseTailscaleReopenRequired ??
              'Tailscale connection required',
        SessionAttentionPauseReason.offline =>
          L10nBridge.current?.sessionAttentionPauseOffline ?? 'Offline',
        SessionAttentionPauseReason.permissionRevoked =>
          L10nBridge.current?.sessionAttentionPausePermissionRevoked ??
              'Permission revoked',
        SessionAttentionPauseReason.serviceStopped =>
          L10nBridge.current?.sessionAttentionPauseServiceStopped ??
              'Service stopped',
        SessionAttentionPauseReason.hostUnavailable =>
          L10nBridge.current?.sessionAttentionPauseHostUnavailable ??
              'Host unavailable',
      };
}
