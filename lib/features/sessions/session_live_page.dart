import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_stop.dart';
import 'session_composer.dart';
import 'session_composer_controller.dart';
import 'session_live_controller.dart';
import 'session_permission_card.dart';
import 'session_stop_button.dart';
import 'session_timeline_tile.dart';

/// Minimum height the prompt composer keeps beside a resident permission card.
const double _composerFloor = 56;

/// Live view of one session: it observes the server and sends prompts only
/// through the composer's outbox. Stop is explicit; it never answers or reverts.
class SessionLivePage extends StatefulWidget {
  const SessionLivePage({super.key, required this.controller});
  final SessionLiveController controller;
  @override
  State<SessionLivePage> createState() => _SessionLivePageState();
}

class _SessionLivePageState extends State<SessionLivePage> {
  late final SessionComposerController _composer;
  final _draft = TextEditingController();

  @override
  void initState() {
    super.initState();
    _composer = SessionComposerController(live: widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.start();
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _draft.dispose();
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
        body: LayoutBuilder(
          builder: (context, body) {
            final tight = body.maxHeight < 200;
            final pad = tight ? 8.0 : 32.0;
            final hasCards =
                c.supportsReplies &&
                (state?.interactions.any(
                      (r) => r.kind.known == InteractionKind.permission,
                    ) ??
                    false);
            final canAct =
                c.outbox != null || c.canStop || c.stopping || hasCards;
            // Cards and composer partition the footer instead of competing for
            // it: cards take a bounded slice, the composer keeps at least a
            // usable field, and their sum never exceeds the body, so a short
            // viewport (keyboard open, landscape) cannot overrun the footer and
            // a pending card can never starve the composer. The other fixed
            // children of this column (the loading bar, the safe-area inset and
            // a rendered Stop button) are reserved up front, or the partition
            // would saturate the body and those would overflow it.
            final stopButton = c.outbox == null && (c.canStop || c.stopping);
            // The prompt-less footer also renders the Stop button and, while a
            // Stop waits or failed, its notice: both live outside the partition.
            final stopNotice =
                c.outbox == null &&
                c.stopState.phase != SessionStopPhase.ready;
            final chrome =
                (c.loading ? 4.0 : 0.0) +
                MediaQuery.paddingOf(context).bottom +
                (stopButton ? 56.0 : 0.0) +
                (stopNotice ? 24.0 : 0.0);
            final space = max(0.0, body.maxHeight - pad - chrome);
            final composerBase = max(
              0.0,
              max(body.maxHeight * 0.4, min(body.maxHeight - 4, 136)) - pad,
            );
            final cardBudget = hasCards
                ? min(
                    min(300.0, max(0.0, body.maxHeight * 0.45)),
                    max(0.0, space - min(composerBase, _composerFloor)),
                  )
                : 0.0;
            final composerBudget = min(
              composerBase,
              max(0.0, space - cardBudget),
            );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    if (c.loading)
                      LinearProgressIndicator(
                        semanticsLabel: l10n.liveConnecting,
                      ),
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
                              Text(
                                canAct
                                    ? l10n.composerLiveSession
                                    : l10n.liveReadOnly,
                                style: textTheme.titleMedium,
                              ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (failure != null)
                                      Text(failure)
                                    else
                                      Text(_phase(l10n, c.phase)),
                                    if (view?.stale ?? false)
                                      Text(l10n.liveStale),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: tight ? 4 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SessionPermissionCards(live: c, maxHeight: cardBudget),
                            c.outbox == null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // With actionable cards above it, the
                                      // prompt-less footer is not "read-only":
                                      // the cards do answer the server.
                                      if (!hasCards)
                                        Text(
                                          l10n.liveSendUnavailable,
                                          key: const ValueKey('live-composer'),
                                        ),
                                      if (c.canStop || c.stopping)
                                        SessionStopButton(live: c),
                                      SessionStopNotice(live: c),
                                    ],
                                  )
                                : SessionComposer(
                                    controller: _composer,
                                    text: _draft,
                                    // Most of the body stays the timeline's; with
                                    // the keyboard over a short body the field
                                    // wins instead (the 4 is the progress bar).
                                    maxHeight: composerBudget,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
