import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_live_controller.dart';
import 'session_tool_details_dialog.dart';

/// What the conversation's status bar reports (#133, #468), the only place
/// a conversation shows its state: a view that is not live, a wait for the
/// user, an interruption, a retry, the call or the reasoning in flight,
/// running sub-agents, the assistant working, or the session waiting for a
/// prompt.
enum ComposerStatusKind {
  connection,
  attention,
  notice,
  retrying,
  progress,
  reasoning,
  subagents,
  working,
  failed,
  idle,
}

typedef ComposerActivity = ({ComposerStatusKind kind, String label});

/// The tips the slot rotates while the assistant works: prompting practices
/// that hold for any agent, like the retained reference's.
List<String> composerTips(V2Localizations l10n) => [
  l10n.chatTipBeSpecific,
  l10n.chatTipStepByStep,
  l10n.chatTipProvideContext,
  l10n.chatTipBreakTasks,
  l10n.chatTipStartWithGoal,
  l10n.chatTipNameRelevantFiles,
  l10n.chatTipStateConstraints,
  l10n.chatTipAskForPlan,
  l10n.chatTipDefineVerification,
  l10n.chatTipShareAttempts,
  l10n.chatTipCompareOptions,
  l10n.chatTipRequestDocs,
  l10n.chatTipAcceptanceCriteria,
  l10n.chatTipUseFocusedAgents,
];

/// Calls that say nothing about what the assistant does now.
const _quietTools = {'todowrite', 'todoread'};

/// What [state] reports the assistant doing, or null while it does not work.
/// Only the messages still in flight of the last turn count: the last call
/// or reasoning in them, the reasoning by the heading it opens with. A call
/// stays the message's activity until the message ends, so the slot does not
/// flash between quick calls; an item outside any message, such as a shell
/// run, counts only while it runs.
ComposerActivity? composerActivity(SessionState? state, V2Localizations l10n) {
  final execution = state?.execution?.kind.known;
  if (execution == ExecutionKind.retrying) {
    return (
      kind: ComposerStatusKind.retrying,
      label: l10n.chatRetryingModelRequest,
    );
  }
  if (execution != ExecutionKind.running) return null;
  final timeline = state!.timeline;
  for (var index = timeline.length - 1; index >= 0; index--) {
    final item = timeline[index];
    if (item is UserInput) break;
    final message = item.meta.message;
    if (message?.completed != null) continue;
    if (message == null && !_runs(item)) continue;
    switch (item) {
      case ToolCall(:final kind, :final rawName)
          when kind.known == ToolKind.subagent ||
              _quietTools.contains(rawName.toLowerCase()):
        continue;
      case ToolCall() || ShellRun():
        return (kind: ComposerStatusKind.progress, label: toolTitle(item));
      case Reasoning(:final text) when text.trim().isNotEmpty:
        return (
          kind: ComposerStatusKind.reasoning,
          label: reasoningHeading(text) ?? l10n.chatStatusThinking,
        );
      default:
        continue;
    }
  }
  return (kind: ComposerStatusKind.working, label: l10n.chatReasoning);
}

/// What the status bar reports for [live], most urgent first (BEHAVIOR.md,
/// V2 conversation status bar): a view that is not live, a question or
/// approval waiting for the user, an interruption, a retry, the work in
/// flight, running sub-agents, a last turn that failed or was interrupted,
/// then the session idle.
ComposerActivity? liveStatus(SessionLiveController live, V2Localizations l10n) {
  ComposerActivity status(ComposerStatusKind kind, String label) =>
      (kind: kind, label: label);
  if (liveFailureLabel(l10n, live.failure) case final failure?) {
    return status(ComposerStatusKind.connection, failure);
  }
  final phase = live.phase;
  if (live.endpointOffline && phase != SessionLivePhase.authRequired) {
    final health = live.endpointHealth;
    return status(
      ComposerStatusKind.connection,
      switch (health.credentialFailure == null
          ? health.assessment?.status
          : null) {
        EndpointStatus.authenticationRequired => l10n.hostsAuthRequired,
        // A server version is not something the bar predicts or argues
        // about; an unusable server simply reads as offline (#468).
        _ => l10n.statusOffline,
      },
    );
  }
  if (phase != SessionLivePhase.live) {
    return status(ComposerStatusKind.connection, livePhaseLabel(l10n, phase));
  }
  if (live.view?.stale ?? false) {
    return status(ComposerStatusKind.connection, l10n.liveStale);
  }
  final state = live.state;
  final kind = state?.execution?.kind.known;
  if ((state?.interactions.isNotEmpty ?? false) ||
      kind == ExecutionKind.waitingForApproval ||
      kind == ExecutionKind.waitingForInput) {
    return status(ComposerStatusKind.attention, l10n.liveNeedsYou);
  }
  if (live.executionNotice case final notice?) {
    return status(ComposerStatusKind.notice, switch (notice) {
      SessionExecutionNotice.interrupted => l10n.liveResuming,
      SessionExecutionNotice.unconfirmed => l10n.liveExecutionUnconfirmed,
    });
  }
  if (kind == ExecutionKind.interruptedPendingResume) {
    return status(ComposerStatusKind.notice, l10n.liveResuming);
  }
  // A Stop sent from here reports itself beside the composer.
  if (kind == ExecutionKind.interrupting &&
      live.stopState.phase == SessionStopPhase.ready) {
    return status(ComposerStatusKind.notice, l10n.liveStopping);
  }
  final activity = composerActivity(state, l10n);
  if (activity != null && activity.kind != ComposerStatusKind.working) {
    return activity;
  }
  // A session stays idle while its sub-agents run; they are counted here.
  final children =
      state?.work
          .where((w) => w.child != null && w.status.known == WorkStatus.running)
          .length ??
      0;
  if (children > 0) {
    return status(
      ComposerStatusKind.subagents,
      l10n.liveChildrenRunning(children),
    );
  }
  if (activity != null) return activity;
  if (kind != ExecutionKind.idle) return null;
  // The last turn's result, unless the timeline already shows its
  // interruption; a success is silent.
  if (!live.hasInterruptedLatestStep) {
    switch (state?.execution?.lastOutcome?.kind.known) {
      case ExecutionOutcomeKind.failed:
        return status(ComposerStatusKind.failed, l10n.liveOutcomeFailed);
      case ExecutionOutcomeKind.interrupted:
        return status(ComposerStatusKind.notice, l10n.liveOutcomeInterrupted);
      default:
    }
  }
  return status(ComposerStatusKind.idle, l10n.liveIdle);
}

/// When the retry the server scheduled for [live] starts; only a wait the
/// harness reported is counted down.
DateTime? liveRetryAt(SessionLiveController live) {
  final execution = live.state?.execution;
  return execution?.kind.known == ExecutionKind.retrying
      ? execution?.retryAt
      : null;
}

/// The reason a live view could not be opened, or null when it opened.
String? liveFailureLabel(V2Localizations l10n, SessionLiveFailure? failure) =>
    switch (failure) {
      null => null,
      SessionLiveFailure.authenticationRequired => l10n.hostsAuthRequired,
      SessionLiveFailure.timeout => l10n.sessionsTimeout,
      SessionLiveFailure.rateLimited => l10n.sessionsRateLimited,
      SessionLiveFailure.notFound => l10n.liveEvicted,
      // An unsupported server version reads as Offline (owner, 2026-11-10).
      SessionLiveFailure.incompatibleResponse => l10n.statusOffline,
      SessionLiveFailure.capacity => l10n.liveCapacity,
      SessionLiveFailure.sourceChanged => l10n.liveSourceChanged,
      _ => l10n.liveUnavailable,
    };

/// The label of a live view's [phase].
String livePhaseLabel(V2Localizations l10n, SessionLivePhase phase) =>
    switch (phase) {
      SessionLivePhase.probing ||
      SessionLivePhase.connecting => l10n.liveConnecting,
      SessionLivePhase.hydrating => l10n.liveHydrating,
      SessionLivePhase.live => l10n.liveLive,
      SessionLivePhase.reconnecting => l10n.liveReconnecting,
      SessionLivePhase.degraded => l10n.liveDegraded,
      SessionLivePhase.evicted => l10n.liveEvicted,
      SessionLivePhase.authRequired => l10n.hostsAuthRequired,
      SessionLivePhase.incompatible => l10n.statusOffline,
      SessionLivePhase.closed => l10n.liveUnavailable,
    };

/// Whether [item] still runs, by its own status.
bool _runs(TimelineItem item) => switch (item) {
  ToolCall() || ShellRun() => switch (toolProgress(item)) {
    ToolProgress.queued || ToolProgress.running => true,
    _ => false,
  },
  Reasoning(:final complete) => !complete,
  _ => false,
};

/// The heading a reasoning opens with, `**Like this**` on its first line,
/// when it reads as words.
String? reasoningHeading(String text) {
  final first = text.trimLeft().split('\n').first.trim();
  final label = RegExp(r'^\*\*(.*?)\*\*$').firstMatch(first)?.group(1)?.trim();
  if (label == null || label.isEmpty || label.runes.length > 64) return null;
  if (RegExp(r'[\[\]{}*+?\\^$|<>]').hasMatch(label)) return null;
  final letters = label.runes.where(
    (rune) =>
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        rune > 0x7F,
  );
  return letters.length >= 2 ? label : null;
}

/// The composer's fixed status slot. Real activity shows at once; with
/// nothing more specific it waits a moment, then rotates a tip every 15
/// seconds, or says the assistant reasons when tips are off; it clears a
/// moment after the work ends. The slot keeps its height either way.
class SessionComposerStatus extends StatefulWidget {
  const SessionComposerStatus({
    super.key,
    required this.activity,
    this.pick,
    this.retryAt,
    this.now = DateTime.now,
  });

  /// The slot's height, kept while it is empty.
  static const height = 26.0;

  static const showDelay = Duration(seconds: 2);
  static const hideDelay = Duration(seconds: 1);
  static const tipInterval = Duration(seconds: 15);

  final ComposerActivity? activity;

  /// When the retry the server scheduled starts, counted down while shown.
  final DateTime? retryAt;
  final DateTime Function() now;

  /// Picks the first tip; random by default.
  final int Function(int count)? pick;

  @override
  State<SessionComposerStatus> createState() => _SessionComposerStatusState();
}

/// What the slot shows: an activity, or a tip.
typedef _Shown = ({ComposerStatusKind? kind, String label});

/// The states a screen reader must hear; work and tips change too often.
bool _announced(ComposerStatusKind? kind) => switch (kind) {
  ComposerStatusKind.connection ||
  ComposerStatusKind.attention ||
  ComposerStatusKind.notice ||
  ComposerStatusKind.failed => true,
  _ => false,
};

class _SessionComposerStatusState extends State<SessionComposerStatus> {
  _Shown? _shown;

  /// Counts what the slot showed, so a label that comes back while its old
  /// copy still fades out gets a fresh key.
  var _turn = 0;
  _Shown? _keyed;
  _Shown? _pending;
  Timer? _show;
  Timer? _hide;
  Timer? _rotation;
  int? _tip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tip ??= (widget.pick ?? Random().nextInt)(
      composerTips(context.v2L10n).length,
    );
    _apply();
  }

  @override
  void didUpdateWidget(covariant SessionComposerStatus old) {
    super.didUpdateWidget(old);
    if (old.activity != widget.activity) _apply();
  }

  @override
  void dispose() {
    _show?.cancel();
    _hide?.cancel();
    _rotation?.cancel();
    super.dispose();
  }

  bool get _tips => ChatAppearance.maybeOf(context)?.composerTips ?? true;

  _Shown _fallback() {
    if (!_tips) {
      return (kind: ComposerStatusKind.working, label: widget.activity!.label);
    }
    final tips = composerTips(context.v2L10n);
    return (kind: null, label: tips[_tip! % tips.length]);
  }

  /// Takes what the session reports now; called before each build that may
  /// change it, so it sets the state without asking for another build.
  void _apply() {
    final activity = widget.activity;
    if (activity == null) {
      _show?.cancel();
      _show = null;
      _rotation?.cancel();
      _rotation = null;
      _pending = null;
      // A resolved connection, wait or notice clears at once; only work
      // lingers, so a short gap between activities does not flash.
      if (_announced(_shown?.kind)) {
        _hide?.cancel();
        _hide = null;
        _shown = null;
        return;
      }
      if (_shown != null && _hide == null) {
        _hide = Timer(SessionComposerStatus.hideDelay, () {
          _hide = null;
          if (mounted) setState(() => _shown = null);
        });
      }
      return;
    }
    _hide?.cancel();
    _hide = null;
    if (activity.kind != ComposerStatusKind.working) {
      _show?.cancel();
      _show = null;
      _rotation?.cancel();
      _rotation = null;
      _pending = null;
      _shown = (kind: activity.kind, label: activity.label);
      return;
    }
    final fallback = _fallback();
    if (fallback.kind == null) {
      _rotation ??= Timer.periodic(SessionComposerStatus.tipInterval, (_) {
        if (!mounted) return;
        setState(() {
          _tip = _tip! + 1;
          if (_shown?.kind == null && _shown != null) _shown = _fallback();
        });
      });
    } else {
      _rotation?.cancel();
      _rotation = null;
    }
    // A fallback after nothing, or after a reasoning heading, waits a moment
    // so a short gap between activities does not flash a tip.
    if (_shown == null || _shown!.kind == ComposerStatusKind.reasoning) {
      if (_pending == fallback && _show != null) return;
      _pending = fallback;
      _show?.cancel();
      _show = Timer(SessionComposerStatus.showDelay, () {
        _show = null;
        final pending = _pending;
        _pending = null;
        if (mounted && pending != null) setState(() => _shown = pending);
      });
      return;
    }
    _shown = fallback;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown != _keyed) {
      _keyed = shown;
      _turn++;
    }
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final retrying = shown?.kind == ComposerStatusKind.retrying;
    final alert = switch (shown?.kind) {
      ComposerStatusKind.retrying ||
      ComposerStatusKind.connection ||
      ComposerStatusKind.failed => true,
      _ => false,
    };
    final icon = switch (shown?.kind) {
      null => Symbols.lightbulb_outline,
      ComposerStatusKind.connection => Symbols.cloud_off,
      ComposerStatusKind.attention => Symbols.front_hand,
      ComposerStatusKind.notice => Symbols.info,
      ComposerStatusKind.progress => Symbols.build,
      ComposerStatusKind.retrying => Symbols.sync_rounded,
      ComposerStatusKind.subagents => Symbols.account_tree,
      ComposerStatusKind.failed => Symbols.error,
      ComposerStatusKind.idle => Symbols.edit_note,
      ComposerStatusKind.reasoning ||
      ComposerStatusKind.working => Symbols.auto_awesome,
    };
    final announced = _announced(shown?.kind);
    final style = theme.bodySmall?.copyWith(
      fontSize: (theme.bodySmall?.fontSize ?? 12) + 1,
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return SizedBox(
      key: const ValueKey('composer-status'),
      height: SessionComposerStatus.height,
      child: shown == null
          ? const SizedBox.expand()
          : Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  child: LayoutBuilder(
                    key: ValueKey(_turn),
                    builder: (context, constraints) {
                      final countdown = retrying && widget.retryAt != null;
                      // A label longer than the bar keeps one line and offers
                      // the whole text behind a thin More at the end.
                      final cut =
                          !countdown &&
                          _overflows(
                            context,
                            shown.label,
                            style,
                            constraints.maxWidth - 21,
                          );
                      final label = Semantics(
                        liveRegion: announced,
                        child: countdown
                            ? RetryCountdown(
                                at: widget.retryAt!,
                                now: widget.now,
                                style: style,
                              )
                            : Text(
                                shown.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style,
                              ),
                      );
                      return Row(
                        mainAxisSize: cut ? MainAxisSize.max : MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 15,
                            color: alert ? scheme.error : scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          if (cut)
                            Expanded(child: label)
                          else
                            Flexible(child: label),
                          if (cut)
                            TextButton(
                              key: const ValueKey('composer-status-more'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(0, 22),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: style,
                              ),
                              onPressed: () => _showWhole(context, shown.label),
                              child: Text(
                                context.v2L10n.chatMessageShowMoreCompact,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

/// Whether [text] needs more than one line of [width] in [style].
bool _overflows(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width.isFinite ? max(0.0, width) : double.infinity);
  final cut = painter.didExceedMaxLines;
  painter.dispose();
  return cut;
}

/// Shows the whole of a status the bar had to cut.
void _showWhole(BuildContext context, String text) {
  final l10n = context.v2L10n;
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('composer-status-whole'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.chatClose),
          ),
        ],
      ),
    ),
  );
}

/// A scheduled retry's label: the wait the server reported, counted down each
/// second while it lasts, then just "Retrying". The count pauses while the
/// page does not tick (a hidden tab) or the app is hidden.
class RetryCountdown extends StatefulWidget {
  const RetryCountdown({
    super.key,
    required this.at,
    required this.now,
    this.style,
  });
  final DateTime at;
  final DateTime Function() now;
  final TextStyle? style;

  @override
  State<RetryCountdown> createState() => _RetryCountdownState();
}

class _RetryCountdownState extends State<RetryCountdown> {
  Timer? _timer;
  var _ticking = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (_) => setState(_schedule),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ticking = TickerMode.valuesOf(context).enabled;
    _schedule();
  }

  @override
  void didUpdateWidget(RetryCountdown old) {
    super.didUpdateWidget(old);
    if (old.at != widget.at || old.now != widget.now) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Duration get _left => widget.at.difference(widget.now());

  /// Wakes at the next whole second of the wait, only while it is shown.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final left = _left;
    final shown = switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
      _ => true,
    };
    if (!_ticking || !shown || left <= Duration.zero) return;
    final part = left.inMicroseconds % Duration.microsecondsPerSecond;
    _timer = Timer(
      Duration(microseconds: part == 0 ? Duration.microsecondsPerSecond : part),
      () {
        if (mounted) setState(_schedule);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final left = _left;
    if (left <= Duration.zero) {
      return Text(l10n.liveRetrying, style: widget.style);
    }
    // Whole seconds, rounded up, so the count never shows a passed second.
    final seconds =
        (left.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
    final hours = seconds ~/ 3600;
    final minutes = seconds ~/ 60 % 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    final time = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$rest'
        : '$minutes:$rest';
    return Text(
      l10n.liveRetryingIn(time),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
