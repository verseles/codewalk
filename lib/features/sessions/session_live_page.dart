import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import 'session_live_controller.dart';
import 'session_timeline_tile.dart';

/// Live, read-only view of one session: it observes the server and never
/// sends, answers, stops or reverts anything.
class SessionLivePage extends StatefulWidget {
  const SessionLivePage({super.key, required this.controller});
  final SessionLiveController controller;
  @override
  State<SessionLivePage> createState() => _SessionLivePageState();
}

class _SessionLivePageState extends State<SessionLivePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.start();
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  String? _failure(V2Localizations l10n, SessionLiveFailure? failure) =>
      switch (failure) {
        null => null,
        SessionLiveFailure.authenticationRequired => l10n.hostsAuthRequired,
        SessionLiveFailure.timeout => l10n.sessionsTimeout,
        SessionLiveFailure.rateLimited => l10n.sessionsRateLimited,
        SessionLiveFailure.notFound => l10n.liveEvicted,
        SessionLiveFailure.incompatibleResponse => l10n.liveIncompatible,
        SessionLiveFailure.capacity => l10n.liveCapacity,
        _ => l10n.liveUnavailable,
      };

  String _phase(V2Localizations l10n, SessionLivePhase phase) =>
      switch (phase) {
        SessionLivePhase.probing ||
        SessionLivePhase.connecting => l10n.liveConnecting,
        SessionLivePhase.hydrating => l10n.liveHydrating,
        SessionLivePhase.live => l10n.liveLive,
        SessionLivePhase.reconnecting => l10n.liveReconnecting,
        SessionLivePhase.degraded => l10n.liveDegraded,
        SessionLivePhase.evicted => l10n.liveEvicted,
        SessionLivePhase.authRequired => l10n.hostsAuthRequired,
        SessionLivePhase.incompatible => l10n.liveIncompatible,
        SessionLivePhase.closed => l10n.liveUnavailable,
      };

  String? _execution(V2Localizations l10n, ExecutionState? execution) =>
      switch (execution?.kind.known) {
        null || ExecutionKind.unknown => null,
        ExecutionKind.idle => l10n.liveIdle,
        ExecutionKind.waitingForApproval ||
        ExecutionKind.waitingForInput => l10n.liveNeedsYou,
        ExecutionKind.interruptedPendingResume => l10n.liveResuming,
        _ => l10n.liveRunning,
      };

  String? _outcome(V2Localizations l10n, ExecutionOutcome? outcome) =>
      switch (outcome?.kind.known) {
        ExecutionOutcomeKind.succeeded => l10n.liveOutcomeSucceeded,
        ExecutionOutcomeKind.failed => l10n.liveOutcomeFailed,
        ExecutionOutcomeKind.interrupted => l10n.liveOutcomeInterrupted,
        _ => null,
      };

  String _time(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(date.toLocal()),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final c = widget.controller;
      final l10n = context.v2L10n;
      final view = c.view;
      final state = c.state;
      final items = state?.timeline ?? const <TimelineItem>[];
      // An opened view speaks through its phase; this is an open failure.
      final failure = _failure(l10n, c.failure);
      final execution = _execution(l10n, state?.execution);
      final outcome = _outcome(l10n, state?.execution?.lastOutcome);
      final needsYou = state?.interactions.isNotEmpty ?? false;
      final textTheme = Theme.of(context).textTheme;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            c.summary.info.title.trim().isEmpty
                ? l10n.sessionExportUntitled
                : c.summary.info.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                if (c.loading)
                  LinearProgressIndicator(semanticsLabel: l10n.liveConnecting),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index > 0) {
                        final item = items[index - 1];
                        return SessionTimelineTile(
                          key: ValueKey(item.id),
                          item: item,
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.liveReadOnly, style: textTheme.titleMedium),
                          Text(
                            c.profile.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Semantics(
                            liveRegion: true,
                            container: true,
                            child: Column(
                              key: const ValueKey('live-status'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (failure != null)
                                  Text(failure)
                                else
                                  Text(_phase(l10n, c.phase)),
                                if (view?.stale ?? false) Text(l10n.liveStale),
                              ],
                            ),
                          ),
                          // Outside the live region: it changes on every event.
                          if (view?.lastSyncedAt case final synced?)
                            Text(
                              '${l10n.liveLastSynced}: ${_time(context, synced)}',
                            ),
                          if (execution != null || outcome != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (execution != null)
                                    Chip(
                                      key: const ValueKey('live-execution'),
                                      label: Text(execution),
                                    ),
                                  if (outcome != null)
                                    Chip(label: Text(outcome)),
                                ],
                              ),
                            ),
                          if (needsYou && execution != l10n.liveNeedsYou)
                            Text(
                              l10n.liveNeedsYou,
                              key: const ValueKey('live-needs-you'),
                            ),
                          if (state?.hasMoreHistory ?? false)
                            Text(l10n.historyLimit),
                          if (c.canRetry)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                key: const ValueKey('live-retry'),
                                onPressed: c.retry,
                                child: Text(l10n.liveRetry),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.liveSendUnavailable,
                      key: const ValueKey('live-composer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
