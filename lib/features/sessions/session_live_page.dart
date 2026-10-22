import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_stop.dart';
import 'session_composer.dart';
import 'session_form_card.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_live_controller.dart';
import 'session_live_timeline.dart';
import 'session_permission_card.dart';
import 'session_permission_mode_chip.dart';
import 'session_stop_button.dart';
import 'sessions_controller.dart';

/// Minimum height the prompt composer keeps beside a resident permission card.
const double _composerFloor = 56;

/// Live view of one session: it observes the server and sends prompts only
/// through the composer's outbox. Stop is explicit; it never answers or reverts.
class SessionLivePage extends StatefulWidget {
  const SessionLivePage({
    super.key,
    required this.controller,
    this.leading,
    this.ownsController = true,
  });
  final SessionLiveController controller;

  /// Whether the page disposes [controller] with itself. A session tab keeps
  /// its view open while other tabs are shown, so its page does not.
  final bool ownsController;

  /// The control before the title, such as the list drawer button of a
  /// compact window.
  final Widget? leading;
  @override
  State<SessionLivePage> createState() => _SessionLivePageState();
}

class _SessionLivePageState extends State<SessionLivePage>
    with WidgetsBindingObserver {
  /// The list told which session this page shows, so the endpoint's unread
  /// mark of that session is cleared while the user sees it.
  SessionsController? _catalog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.controller.started) widget.controller.start();
      _catalog = context.read<SessionsController?>();
      if (_foreground(WidgetsBinding.instance.lifecycleState)) _show();
    });
  }

  /// The page is seen unless the app is hidden or in the background.
  static bool _foreground(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  void _show() => _catalog?.showing(widget.controller.session);

  @override
  void didUpdateWidget(SessionLivePage old) {
    super.didUpdateWidget(old);
    final session = widget.controller.session;
    if (old.controller.session == session) return;
    _catalog?.leave(old.controller.session);
    if (_foreground(WidgetsBinding.instance.lifecycleState)) _show();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_foreground(state)) {
      _show();
    } else {
      _catalog?.leave(widget.controller.session);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catalog?.leave(widget.controller.session);
    if (widget.ownsController) widget.controller.dispose();
    super.dispose();
  }

  /// The block above the timeline items: the phase, the notices and the
  /// retry. It scrolls with the items, so a long session keeps its status
  /// in reach.
  Widget _header(
    BuildContext context,
    SessionLiveController c,
    V2Localizations l10n,
    TextTheme textTheme, {
    required String? failure,
    required String? execution,
    required String? outcome,
    required bool needsYou,
    required SessionLiveView? view,
    required bool canAct,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        canAct ? l10n.composerLiveSession : l10n.liveReadOnly,
        style: textTheme.titleMedium,
      ),
      Text(c.profile.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: const ValueKey('live-status'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failure != null) Text(failure) else Text(_phase(l10n, c.phase)),
            if (view?.stale ?? false) Text(l10n.liveStale),
          ],
        ),
      ),
      // Outside the live region: it changes on every event.
      if (view?.lastSyncedAt case final synced?)
        Text('${l10n.liveLastSynced}: ${_time(context, synced)}'),
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
              if (outcome != null) Chip(label: Text(outcome)),
            ],
          ),
        ),
      if (needsYou && execution != l10n.liveNeedsYou)
        Text(l10n.liveNeedsYou, key: const ValueKey('live-needs-you')),
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

  /// The top of the list, above the older rows: the way back once the window
  /// holds all it can, and the retry of a failed older page. Null when there
  /// is nothing to offer there.
  WidgetBuilder? _top(SessionLiveController c, V2Localizations l10n) {
    final beyond = c.olderHistoryBeyondWindow;
    final failed = c.olderHistory.failure != null && c.canLoadOlderHistory;
    if (!beyond && !failed) return null;
    return (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The window cannot page in more: the history viewer is the way back.
        if (beyond) ...[
          Text(l10n.historyLimit, key: const ValueKey('live-history-limit')),
          if (context.watch<SessionHistoryFactory?>() != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('live-open-history'),
                onPressed: _openingHistory ? null : () => _openHistory(c),
                child: Text(l10n.historyOpen),
              ),
            ),
        ],
        if (failed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('live-older-retry'),
              onPressed: c.loadOlderHistory,
              child: Text(l10n.liveRetry),
            ),
          ),
      ],
    );
  }

  bool _openingHistory = false;

  /// Opens the read-only history viewer of this session, the fallback once
  /// the live window holds all it can.
  Future<void> _openHistory(SessionLiveController c) async {
    final factory = context.read<SessionHistoryFactory?>();
    if (_openingHistory || factory == null) return;
    setState(() => _openingHistory = true);
    final history = SessionHistoryController(
      hosts: c.hosts,
      profile: c.profile,
      summary: c.summary,
      sourceFactory: factory,
    );
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => SessionHistoryPage(controller: history),
        ),
      );
    } finally {
      history.dispose();
      if (mounted) setState(() => _openingHistory = false);
    }
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
      // A settled session has no turn in flight, so a finished answer can be
      // offered to the reader from its start.
      final settled = switch (state?.execution?.kind.known) {
        null => false,
        ExecutionKind.running => false,
        ExecutionKind.waitingForApproval => false,
        ExecutionKind.waitingForInput => false,
        ExecutionKind.retrying => false,
        ExecutionKind.interrupting => false,
        ExecutionKind.interruptedPendingResume => false,
        ExecutionKind.idle => true,
        ExecutionKind.unknown => false,
      };
      final textTheme = Theme.of(context).textTheme;
      return Scaffold(
        appBar: AppBar(
          leading: widget.leading,
          actions: [
            if (c.permissionModes != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: SessionPermissionModeChip(live: c),
              ),
          ],
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
                      (r) =>
                          r.kind.known == InteractionKind.permission ||
                          r.kind.known == InteractionKind.form,
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
                      child: SessionLiveTimeline(
                        items: items,
                        scroll: widget.controller.scroll,
                        settled: settled,
                        olderLoading: c.olderHistory.loading,
                        topBuilder: _top(c, l10n),
                        onLoadOlder: c.canLoadOlderHistory
                            ? c.loadOlderHistory
                            : null,
                        headerBuilder: (context) => _header(
                          context,
                          c,
                          l10n,
                          textTheme,
                          failure: failure,
                          execution: execution,
                          outcome: outcome,
                          needsYou: needsYou,
                          view: view,
                          canAct: canAct,
                        ),
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
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxHeight: cardBudget),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SessionPermissionCards(
                                      live: c,
                                      maxHeight: cardBudget,
                                    ),
                                    SessionFormCards(
                                      live: c,
                                      maxHeight: cardBudget,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            c.outbox == null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Prompt storage is missing, so the
                                      // footer explains that only prompt
                                      // sending is out, whether or not the
                                      // cards above it can still reply.
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
                                    controller: widget.controller.composer,
                                    text: widget.controller.draft,
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
