import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/attachment_sniff.dart';
import '../../shared/media/audio_playback.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';

/// Timeline card for an audio attachment with an inline play/pause button and
/// progress scrubber backed by [AudioPlaybackPort]. Degrades honestly when
/// bytes are unavailable on this device or audio playback is unsupported.
class AudioAttachmentCard extends StatefulWidget {
  const AudioAttachmentCard({
    super.key,
    required this.attachment,
    required this.facet,
  });

  final AttachmentRef attachment;
  final AttachmentFacet? facet;

  @override
  State<AudioAttachmentCard> createState() => _AudioAttachmentCardState();
}

class _AudioAttachmentCardState extends State<AudioAttachmentCard> {
  bool _fetching = false;
  bool _fetchUnavailable = false;
  AttachmentMedia? _loaded;

  String get _playerId => widget.attachment.content.id;

  bool get _bytesUnavailable =>
      _fetchUnavailable ||
      widget.facet == null ||
      widget.attachment.availability.known == AttachmentAvailability.omitted ||
      widget.attachment.availability.known ==
          AttachmentAvailability.unavailable;

  @override
  void didUpdateWidget(covariant AudioAttachmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.content.id != widget.attachment.content.id ||
        !identical(oldWidget.facet, widget.facet)) {
      _loaded = null;
      _fetchUnavailable = false;
      _fetching = false;
    }
  }

  Future<void> _togglePlay(AudioPlaybackPort playback) async {
    if (_fetching) return;
    if (playback.current.isActive(_playerId) && _loaded != null) {
      await playback.togglePlay(
        id: _playerId,
        bytes: _loaded!.bytes,
        mimeType: _loaded!.mimeType,
      );
      return;
    }
    var media = _loaded;
    if (media == null) {
      final facet = widget.facet;
      if (facet == null) {
        setState(() => _fetchUnavailable = true);
        return;
      }
      setState(() => _fetching = true);
      try {
        media = await facet.read(widget.attachment);
      } on Object {
        media = null;
      }
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _loaded = media;
        _fetchUnavailable = media == null || media.bytes.isEmpty;
      });
    }
    if (media == null || media.bytes.isEmpty) return;
    await playback.togglePlay(
      id: _playerId,
      bytes: media.bytes,
      mimeType: media.mimeType,
    );
  }

  static String _formatClock(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playback = context.read<AudioPlaybackPort?>();
    final name = widget.attachment.name ?? l10n.composerAttachAudio;
    final sizeBytes = widget.attachment.content.sizeBytes;
    final supported = playback != null && playback.supported;
    final playable = supported && !_bytesUnavailable;

    return StreamBuilder<AudioPlaybackState>(
      stream: playback?.updates,
      initialData: playback?.current ?? const AudioPlaybackState(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AudioPlaybackState();
        final active = state.isActive(_playerId);
        final playing = active && state.status == AudioPlaybackStatus.playing;
        final loading =
            _fetching || (active && state.status == AudioPlaybackStatus.loading);
        final errored = active && state.status == AudioPlaybackStatus.error;
        final duration = active ? state.duration : Duration.zero;
        final position = active ? state.position : Duration.zero;
        final maxMs = duration.inMilliseconds;
        final posMs = maxMs > 0
            ? position.inMilliseconds.clamp(0, maxMs)
            : 0;

        final String? statusNote;
        if (!supported) {
          statusNote = l10n.attachmentAudioUnavailable;
        } else if (_bytesUnavailable) {
          statusNote = l10n.attachmentPreviewUnavailable;
        } else if (errored) {
          statusNote = l10n.attachmentAudioUnavailable;
        } else {
          statusNote = null;
        }

        return Material(
          key: ValueKey('attachment-audio-${widget.attachment.id}'),
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      key: ValueKey(
                        'attachment-audio-play-${widget.attachment.id}',
                      ),
                      tooltip: playing
                          ? l10n.attachmentPauseAudio
                          : l10n.attachmentPlayAudio,
                      onPressed: playable && !loading
                          ? () => unawaited(_togglePlay(playback))
                          : null,
                      icon: loading
                          ? const AppIndeterminateRing(size: 18, strokeWidth: 2)
                          : Icon(
                              playing ? Symbols.pause : Symbols.play_arrow,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            statusNote ??
                                (sizeBytes != null
                                    ? formatAttachmentBytes(sizeBytes)
                                    : l10n.composerAttachAudio),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: errored
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (playable)
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            key: ValueKey(
                              'attachment-audio-slider-${widget.attachment.id}',
                            ),
                            value: maxMs > 0 ? posMs / maxMs : 0.0,
                            onChanged: active && maxMs > 0
                                ? (v) => unawaited(
                                    playback.seek(
                                      Duration(
                                        milliseconds: (v * maxMs).round(),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Text(
                        maxMs > 0
                            ? '${_formatClock(position)} / ${_formatClock(duration)}'
                            : '0:00',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
