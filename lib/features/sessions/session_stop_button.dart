import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_stop.dart';
import 'composer_input.dart';
import 'session_live_controller.dart';

class SessionStopButton extends StatelessWidget {
  const SessionStopButton({super.key, required this.live});
  final SessionLiveController live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    if (live.stopping) {
      return SizedBox.square(
        dimension: composerActionSize,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: l10n.liveStopping,
            ),
          ),
        ),
      );
    }
    // Round and dark with the stop glyph in the error color, like the
    // retained reference's Stop in place of Send.
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: composerActionSize,
      child: IconButton.filled(
        key: const ValueKey('live-stop'),
        tooltip: l10n.liveStop,
        onPressed: live.canStop ? live.stopCurrentTurn : null,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(composerActionSize),
          minimumSize: const Size.square(composerActionSize),
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const Color(0xFF424242),
          foregroundColor: scheme.error,
        ),
        icon: const Icon(Icons.stop_rounded, size: 20),
      ),
    );
  }
}

class SessionStopNotice extends StatelessWidget {
  const SessionStopNotice({super.key, required this.live});
  final SessionLiveController live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final stop = live.stopState;
    final text = switch (stop.phase) {
      SessionStopPhase.ready => null,
      SessionStopPhase.requesting ||
      SessionStopPhase.requested => l10n.liveStopping,
      SessionStopPhase.idle => l10n.liveStopIdle,
      SessionStopPhase.unconfirmed => l10n.liveStopUnconfirmed,
      SessionStopPhase.refused => switch (stop.receipt?.error?.rawType) {
        'UnauthorizedError' => l10n.hostsAuthRequired,
        'SessionNotFoundError' => l10n.liveEvicted,
        'RateLimited' => l10n.sessionsRateLimited,
        _ => l10n.liveStopFailed,
      },
    };
    return text == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Text(text, key: const ValueKey('live-stop-notice')),
          );
  }
}
