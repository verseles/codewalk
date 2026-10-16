import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_stop.dart';
import 'session_live_controller.dart';

class SessionStopButton extends StatelessWidget {
  const SessionStopButton({super.key, required this.live});
  final SessionLiveController live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    if (live.stopping) {
      return SizedBox.square(
        dimension: 48,
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.liveStopping),
        ),
      );
    }
    return IconButton.filled(
      key: const ValueKey('live-stop'),
      tooltip: l10n.liveStop,
      onPressed: live.canStop ? live.stopCurrentTurn : null,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
      ),
      icon: const Icon(Icons.stop_rounded),
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
