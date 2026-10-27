import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_tool_details_dialog.dart';

/// What the composer's status slot reports while the session works (#133):
/// the call or the reasoning of the message in flight, a retry, or, with
/// nothing more specific, that the assistant works.
enum ComposerStatusKind { progress, reasoning, retrying, working }

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
  const SessionComposerStatus({super.key, required this.activity, this.pick});

  /// The slot's height, kept while it is empty.
  static const height = 26.0;

  static const showDelay = Duration(seconds: 2);
  static const hideDelay = Duration(seconds: 1);
  static const tipInterval = Duration(seconds: 15);

  final ComposerActivity? activity;

  /// Picks the first tip; random by default.
  final int Function(int count)? pick;

  @override
  State<SessionComposerStatus> createState() => _SessionComposerStatusState();
}

/// What the slot shows: an activity, or a tip.
typedef _Shown = ({ComposerStatusKind? kind, String label});

class _SessionComposerStatusState extends State<SessionComposerStatus> {
  _Shown? _shown;
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
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final retrying = shown?.kind == ComposerStatusKind.retrying;
    final icon = switch (shown?.kind) {
      null => Symbols.lightbulb_outline,
      ComposerStatusKind.progress => Symbols.build,
      ComposerStatusKind.retrying => Symbols.sync_rounded,
      ComposerStatusKind.reasoning ||
      ComposerStatusKind.working => Symbols.auto_awesome,
    };
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
                  child: Row(
                    key: ValueKey(
                      'composer-status-${shown.kind?.name ?? 'tip'}-'
                      '${shown.label}',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: retrying ? scheme.error : scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          shown.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall?.copyWith(
                            fontSize: (theme.bodySmall?.fontSize ?? 12) + 1,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
