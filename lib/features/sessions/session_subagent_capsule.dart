import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_shells.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_live_controller.dart';
import 'session_shell_output_sheet.dart';
import 'session_tool_details_dialog.dart';

/// A real canonical child row is the adapter's discovery evidence. Harnesses
/// without child work produce no rows and get no fabricated management control.
List<WorkItem> subagentWork(SessionState? state) => [
  if (state != null)
    for (final work in state.work)
      if (work.child != null &&
          work.child != state.ref &&
          work.child!.harnessRef == state.ref.harnessRef &&
          work.parent == state.ref &&
          work.completionScope.known == CompletionScope.child)
        work,
];

WorkStatus subagentStatus(
  WorkItem work,
  SessionState state, {
  bool current = true,
}) {
  if (!current) return WorkStatus.unknown;
  if (state.interactions.any(
    (request) =>
        (request.kind.known == InteractionKind.permission ||
            request.kind.known == InteractionKind.form) &&
        request.owner is SessionOwner &&
        (request.owner as SessionOwner).session == work.child &&
        (request.owner as SessionOwner).origin == state.ref,
  )) {
    return WorkStatus.waiting;
  }
  return work.status.known ?? WorkStatus.unknown;
}

bool subagentIsActive(WorkStatus status) =>
    status == WorkStatus.running ||
    status == WorkStatus.queued ||
    status == WorkStatus.waiting;

bool subagentIsCompleted(WorkStatus status) =>
    status == WorkStatus.completed ||
    status == WorkStatus.failed ||
    status == WorkStatus.cancelled;

/// One deduplicated shell row for the unified capsule pop-in.
///
/// Merges live harness-observed [ShellWork] with its matching timeline twin
/// (`ShellRun` or `ToolKind.shell` [ToolCall]) by canonical opaque `shellId`
/// so a running shell appears in Active only and never duplicates into
/// Completed.
final class CapsuleShellEntry {
  const CapsuleShellEntry({
    required this.key,
    required this.command,
    required this.isRunning,
    this.isUnconfirmed = false,
    this.shellId,
    this.shellWork,
    this.timelineItem,
    this.status,
    this.exitCode,
    this.exitToken,
    this.startedAt,
    this.completedAt,
  });

  final String key;
  final String command;
  final bool isRunning;

  /// True when the shell outcome is unrecognized/unconfirmed and must remain
  /// in Active with an unconfirmed status instead of being labeled Done.
  final bool isUnconfirmed;
  final String? shellId;
  final ShellWork? shellWork;
  final TimelineItem? timelineItem;
  final ShellStatus? status;
  final int? exitCode;
  final String? exitToken;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Active tab includes both confirmed running shells and unconfirmed outcomes.
  bool get isActiveTab => isRunning || isUnconfirmed;

  bool get isFailed =>
      status == ShellStatus.timeout ||
      status == ShellStatus.killed ||
      (exitCode != null && exitCode != 0) ||
      (timelineItem != null && toolFailed(timelineItem!));
}

String? _timelineShellId(TimelineItem item) => switch (item) {
  ToolCall(:final runFacts) => runFacts?.shellId,
  ShellRun(:final shellId) => shellId,
  Notice(:final shellReport?) => shellReport.shellId,
  _ => null,
};

String _timelineShellCommand(TimelineItem item) => switch (item) {
  ShellRun(:final command) => redactCredentialText(command).trim(),
  Notice(:final shellReport?) =>
    shellReport.command == null
        ? ''
        : redactCredentialText(shellReport.command!).trim(),
  ToolCall(:final input) => () {
    final map = input?.value;
    if (map is Map && map['command'] is String) {
      return redactCredentialText(map['command'] as String).trim();
    }
    return '';
  }(),
  _ => '',
};

ShellStatus? _shellReportStatus(ShellReport report) {
  if (report.timedOut) return ShellStatus.timeout;
  if (report.killed || report.outcome == OutcomeKind.interrupted) {
    return ShellStatus.killed;
  }
  if (report.outcome == OutcomeKind.succeeded ||
      report.outcome == OutcomeKind.failed ||
      report.exitCode != null ||
      report.exitToken != null) {
    return ShellStatus.exited;
  }
  return null;
}

/// Projects deduplicated shell entries for [state].
///
/// When [canObserveShells] is false, live [SessionState.shells] observations
/// and active/running timeline shell rows are omitted so harnesses without
/// `shell.observe` never surface live shell counts, timers, Stop controls, or
/// output paging; completed timeline shell records remain inspectable via
/// [showToolDetailsDialog].
///
/// When [canObserveShells] is true:
/// - If [state.shellsObserved] is false (initial `/api/shell` failed or has not
///   settled yet), settled background shell `ToolCall`s with running status
///   remain unconfirmed in Active instead of being inferred as Done.
/// - Once [state.shellsObserved] is true, settled background shell `ToolCall`s
///   whose `shellId` is absent from [SessionState.shells] move to Completed
///   without fabricating a clean Done outcome when no exit code is reported.
/// - Any shell ID in [confirmedRemovedShellIds] (previously observed live and
///   subsequently stopped/deleted) is immediately suppressed from Active even
///   if its timeline `ToolCall` is momentarily still streaming.
List<CapsuleShellEntry> sessionShellEntries(
  SessionState? state, {
  required bool canObserveShells,
  Set<String> confirmedRemovedShellIds = const {},
}) {
  if (state == null) return const [];
  final byKey = <String, CapsuleShellEntry>{};
  final order = <String>[];
  final liveById = canObserveShells
      ? {for (final shell in state.shells) shell.id: shell}
      : const <String, ShellWork>{};

  void put(String key, CapsuleShellEntry entry) {
    if (!byKey.containsKey(key)) order.add(key);
    byKey[key] = entry;
  }

  // First scan timeline shells (oldest to newest; newer updates same key).
  for (final item in state.timeline) {
    final isShellRun = item is ShellRun && item.shellStatus != null;
    final isShellTool = item is ToolCall && item.kind.known == ToolKind.shell;
    if (!isShellRun && !isShellTool) continue;
    final shellId = _timelineShellId(item);
    final key = shellId ?? item.id.value;
    final command = _timelineShellCommand(item);
    final rawRunning = toolProgress(item) == ToolProgress.running;
    final itemStreaming =
        item.status.known == ItemStatus.pending ||
        item.status.known == ItemStatus.streaming;
    final unknownShellRun = item is ShellRun && item.shellStatus?.known == null;

    if (!canObserveShells) {
      // Without `shell.observe`, omit active/running timeline shell rows so
      // they never inflate active counts or mimic live observation.
      if (rawRunning || itemStreaming) continue;
      final status = switch (item) {
        ShellRun(:final shellStatus) => shellStatus?.known,
        ToolCall(:final runFacts) =>
          runFacts?.shellStatus?.known ?? ShellStatus.exited,
        _ => ShellStatus.exited,
      };
      final exitCode = switch (item) {
        ShellRun(:final exitCode) => exitCode,
        ToolCall(:final runFacts) => runFacts?.exitCode,
        _ => null,
      };
      final exitToken = switch (item) {
        ShellRun(:final exitToken) => exitToken,
        ToolCall(:final runFacts) => runFacts?.exitToken,
        _ => null,
      };
      put(
        key,
        CapsuleShellEntry(
          key: key,
          command: command,
          isRunning: false,
          isUnconfirmed: unknownShellRun,
          shellId: shellId,
          timelineItem: item,
          status: status == ShellStatus.running ? null : status,
          exitCode: exitCode,
          exitToken: exitToken,
        ),
      );
      continue;
    }

    final liveTwin = shellId == null ? null : liveById[shellId];
    final confirmedRemoved =
        liveTwin == null &&
        shellId != null &&
        confirmedRemovedShellIds.contains(shellId);
    final bool isRunning;
    final bool isUnconfirmed;
    if (liveTwin != null) {
      isRunning = liveTwin.isRunning;
      isUnconfirmed = liveTwin.status.known == null;
    } else if (confirmedRemoved) {
      isRunning = false;
      isUnconfirmed = false;
    } else if (unknownShellRun) {
      isRunning = false;
      isUnconfirmed = true;
    } else if (rawRunning && itemStreaming) {
      isRunning = true;
      isUnconfirmed = false;
    } else if (rawRunning && !state.shellsObserved) {
      // Shell observation has not succeeded yet: keep settled running-flagged
      // background shells unconfirmed rather than inferring completion.
      isRunning = false;
      isUnconfirmed = true;
    } else {
      isRunning = false;
      isUnconfirmed = false;
    }
    final rawStatus = switch (item) {
      ShellRun(:final shellStatus) => shellStatus?.known,
      ToolCall(:final runFacts) =>
        runFacts?.shellStatus?.known ??
            (isRunning ? ShellStatus.running : ShellStatus.exited),
      _ => null,
    };
    final effectiveStatus = !isRunning && rawStatus == ShellStatus.running
        ? null
        : rawStatus;
    final exitCode = switch (item) {
      ShellRun(:final exitCode) => exitCode,
      ToolCall(:final runFacts) => runFacts?.exitCode,
      _ => null,
    };
    final exitToken = switch (item) {
      ShellRun(:final exitToken) => exitToken,
      ToolCall(:final runFacts) => runFacts?.exitToken,
      _ => null,
    };
    put(
      key,
      CapsuleShellEntry(
        key: key,
        command: command,
        isRunning: isRunning,
        isUnconfirmed: isUnconfirmed,
        shellId: shellId,
        timelineItem: item,
        status: effectiveStatus,
        exitCode: exitCode,
        exitToken: exitToken,
      ),
    );
  }

  // Overlay completed background shell report notices so backgrounded tool
  // calls acquire their terminal outcome/output and detached reports stay
  // inspectable when their launch call is outside the resident window.
  for (final item in state.timeline) {
    if (item is! Notice || item.shellReport == null) continue;
    final report = item.shellReport!;
    final shellId = report.shellId;
    final key = shellId ?? item.id.value;
    final prior = byKey[key];
    if (prior?.timelineItem is ShellRun) continue;
    final reportCommand = _timelineShellCommand(item);
    final command = (prior?.command.isNotEmpty ?? false)
        ? prior!.command
        : reportCommand;
    final status = _shellReportStatus(report) ?? prior?.status;
    put(
      key,
      CapsuleShellEntry(
        key: key,
        command: command,
        isRunning: false,
        isUnconfirmed: false,
        shellId: shellId ?? prior?.shellId,
        timelineItem: item,
        status: status,
        exitCode: report.exitCode ?? prior?.exitCode,
        exitToken: report.exitToken ?? prior?.exitToken,
      ),
    );
  }

  // Overlay live harness-observed shells only when `shell.observe` is active.
  if (canObserveShells) {
    for (final shell in state.shells) {
      final prior = byKey[shell.id];
      final twin = prior?.timelineItem;
      final command = shell.command.trim().isNotEmpty
          ? redactCredentialText(shell.command).trim()
          : (twin != null ? _timelineShellCommand(twin) : '');
      final knownStatus = shell.status.known;
      put(
        shell.id,
        CapsuleShellEntry(
          key: shell.id,
          command: command,
          isRunning: shell.isRunning,
          isUnconfirmed: knownStatus == null,
          shellId: shell.id,
          shellWork: shell,
          timelineItem: twin,
          status: knownStatus,
          exitCode: shell.exitCode ?? prior?.exitCode,
          exitToken: shell.exitToken ?? prior?.exitToken,
          startedAt: shell.startedAt,
          completedAt: shell.completedAt,
        ),
      );
    }
  }

  return [for (final key in order) byKey[key]!];
}

/// How long a shell runs before the chip counts and shows it (#544), so
/// quick commands never make the count jump.
const shellShownAfter = Duration(seconds: 5);

/// When each shell of a session was seen to start and end, for one whose
/// own times are not known (#544): a shell that reports no start counts
/// from when it was first seen running (or unconfirmed), and a quick one
/// never shows, even once its live record gives way to a timeline row
/// without times or its shell id arrives late. A shell that had ended
/// before it was ever seen, as in history, shows. It tells its listeners
/// when a running shell reaches [shellShownAfter].
final class ShellSightings extends ChangeNotifier {
  // Sightings outlive a shell's absence from one update to the next (a
  // retry, a live record gone before its row ends); past this many, those
  // of shells no longer listed go, oldest first.
  static const _kept = 512;
  final _times = <String, (DateTime, DateTime?)>{};
  Timer? _timer;
  DateTime? _timerAt;
  bool _disposed = false;

  /// The shells of [entries], all the session's, that ran long enough by
  /// [now] to show.
  List<CapsuleShellEntry> shown(List<CapsuleShellEntry> entries, DateTime now) {
    final listed = <String>{};
    final shown = [
      for (final entry in entries)
        if (_shown(entry, now, listed)) entry,
    ];
    if (_times.length > _kept) {
      for (final key in _times.keys.toList()) {
        if (_times.length <= _kept) break;
        if (!listed.contains(key)) _times.remove(key);
      }
    }
    _arm(entries, now);
    return shown;
  }

  // The names a shell goes by: its entry's, and its timeline row's, which
  // stays when its shell id arrives later.
  static List<String> _keys(CapsuleShellEntry entry) => [
    entry.key,
    if (entry.timelineItem case final item?) 'item:${item.id.value}',
  ];

  static bool _active(CapsuleShellEntry entry) =>
      entry.isRunning || entry.isUnconfirmed;

  /// The earliest start any name of [entry] was seen with, and an end seen
  /// with it.
  (DateTime, DateTime?)? _seen(CapsuleShellEntry entry) {
    (DateTime, DateTime?)? seen;
    for (final key in _keys(entry)) {
      final times = _times[key];
      if (times == null) continue;
      if (seen == null || times.$1.isBefore(seen.$1)) {
        seen = (times.$1, times.$2 ?? seen?.$2);
      } else {
        seen = (seen.$1, seen.$2 ?? times.$2);
      }
    }
    return seen;
  }

  bool _shown(CapsuleShellEntry entry, DateTime now, Set<String> listed) {
    final seen = _seen(entry);
    final start = entry.startedAt ?? seen?.$1 ?? (_active(entry) ? now : null);
    if (start == null) return true;
    final end = _active(entry) ? null : entry.completedAt ?? seen?.$2 ?? now;
    for (final key in _keys(entry)) {
      // Rewritten as the newest, so a listed shell is the last to go.
      _times
        ..remove(key)
        ..[key] = (start, end);
      listed.add(key);
    }
    return (end ?? now).difference(start) >= shellShownAfter;
  }

  /// Tells the listeners when the next active shell of [entries] reaches
  /// [shellShownAfter].
  void _arm(List<CapsuleShellEntry> entries, DateTime now) {
    DateTime? next;
    for (final entry in entries) {
      if (!_active(entry)) continue;
      final started = entry.startedAt ?? _seen(entry)?.$1;
      if (started == null) continue;
      final at = started.add(shellShownAfter);
      if (!at.isAfter(now)) continue;
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) {
      // Nothing left to wait for.
      _timer?.cancel();
      _timer = null;
      _timerAt = null;
      return;
    }
    final pending = _timerAt;
    if (_disposed || (pending != null && !next.isBefore(pending))) return;
    _timer?.cancel();
    _timerAt = next;
    _timer = Timer(next.difference(now), () {
      _timer = null;
      _timerAt = null;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Whether the floating robot capsule may show for [state]: sub-agents, or
/// shells it still has to look at.
bool hasSessionCapsuleActivity(
  SessionState? state, {
  required bool canObserveShells,
}) =>
    subagentWork(state).isNotEmpty ||
    sessionShellEntries(state, canObserveShells: canObserveShells).isNotEmpty;

sealed class _PopinAction {
  const _PopinAction();
}

final class _OpenChildAction extends _PopinAction {
  const _OpenChildAction(this.child);
  final SessionRef child;
}

final class _OpenToolDetailsAction extends _PopinAction {
  const _OpenToolDetailsAction(this.item);
  final TimelineItem item;
}

final class _OpenShellOutputAction extends _PopinAction {
  const _OpenShellOutputAction(this.shell);
  final ShellWork shell;
}

/// The capsule owns only its popup, never a second subscription or transcript.
class SessionSubagentCapsule extends StatefulWidget {
  const SessionSubagentCapsule({
    super.key,
    required this.live,
    required this.onOpen,
  });

  static const height = 48.0;
  final SessionLiveController live;
  final ValueChanged<SessionRef> onOpen;

  @override
  State<SessionSubagentCapsule> createState() => _SessionSubagentCapsuleState();
}

class _SessionSubagentCapsuleState extends State<SessionSubagentCapsule> {
  static const _maxTrackedShellIds = 256;
  final _anchor = GlobalKey();
  final _focus = FocusNode();
  final _observedShellIds = <String>{};
  SessionRef? _observedSession;
  bool _open = false;

  Set<String> _confirmedRemovedFor(SessionState? state) {
    // A pop-in left open after its chip went asks nothing of it.
    if (!mounted) return const {};
    final session = widget.live.session;
    if (_observedSession != session) {
      _observedSession = session;
      _observedShellIds.clear();
    }
    if (state == null || !_canObserveShells) return const {};
    final liveIds = {for (final shell in state.shells) shell.id};
    for (final id in liveIds) {
      _observedShellIds.add(id);
      while (_observedShellIds.length > _maxTrackedShellIds) {
        _observedShellIds.remove(_observedShellIds.first);
      }
    }
    return _observedShellIds.difference(liveIds);
  }

  @override
  void dispose() {
    _focus.dispose();
    // Gone with its activity: the timeline gives its room back.
    final live = widget.live;
    scheduleMicrotask(() {
      if (!live.disposed) live.capsuleShown.value = false;
    });
    super.dispose();
  }

  bool get _current =>
      widget.live.phase == SessionLivePhase.live &&
      widget.live.view?.stale != true;

  bool get _canObserveShells => widget.live.shells?.canObserve ?? false;

  Future<void> _show() async {
    if (_open) return;
    final anchor = _anchor.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(
              context,
              rootNavigator: true,
            ).overlay?.context.findRenderObject()
            as RenderBox?;
    if (anchor == null || overlay == null || !anchor.hasSize) return;
    final openingRect =
        anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
    _open = true;
    final parent = widget.live.session;
    final themes = InheritedTheme.capture(
      from: context,
      to: Navigator.of(context, rootNavigator: true).context,
    );
    final l10n = context.v2L10n;
    try {
      final action = await showGeneralDialog<_PopinAction>(
        context: context,
        barrierDismissible: true,
        barrierLabel: l10n.chatClose,
        barrierColor: Colors.black12,
        requestFocus: true,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (dialogContext, animation, secondaryAnimation) =>
            LayoutBuilder(
              builder: (context, constraints) {
                final box =
                    _anchor.currentContext?.findRenderObject() as RenderBox?;
                // A live deletion can remove the robot before this route closes.
                final rect = box != null && box.attached && box.hasSize
                    ? box.localToGlobal(Offset.zero, ancestor: overlay) &
                          box.size
                    : openingRect;
                final media = MediaQuery.of(context);
                final width = min(380.0, max(0.0, constraints.maxWidth - 24));
                final bottom = min(
                  rect.top - 8,
                  constraints.maxHeight - media.viewInsets.bottom - 8,
                );
                final top = media.padding.top + 8;
                final height = min(420.0, max(0.0, bottom - top));
                if (height == 0 || width == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (dialogContext.mounted &&
                        ModalRoute.of(dialogContext)?.isCurrent == true) {
                      Navigator.of(dialogContext).pop();
                    }
                  });
                  return const SizedBox.shrink();
                }
                final left = Directionality.of(context) == TextDirection.rtl
                    ? rect.left
                    : rect.right - width;
                final panel = _SubagentPopin(
                  live: widget.live,
                  parent: parent,
                  confirmedRemovedFor: _confirmedRemovedFor,
                  onAction: (selected) =>
                      Navigator.of(dialogContext).pop(selected),
                );
                return themes.wrap(
                  Stack(
                    children: [
                      Positioned(
                        left: left.clamp(
                          12.0,
                          max(12.0, constraints.maxWidth - width - 12),
                        ),
                        top: max(top, bottom - height),
                        width: width,
                        height: height,
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.escape,
                            ): () =>
                                Navigator.of(dialogContext).pop(),
                          },
                          child: FocusTraversalGroup(
                            child: SizedBox(
                              key: const ValueKey('subagent-popin'),
                              child: height >= 160
                                  ? panel
                                  : ClipRect(
                                      child: SingleChildScrollView(
                                        primary: false,
                                        child: SizedBox(
                                          height: 160,
                                          child: panel,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      );
      if (!mounted || widget.live.session != parent) return;
      switch (action) {
        case _OpenChildAction(:final child):
          widget.onOpen(child);
        case _OpenToolDetailsAction(:final item):
          await showToolDetailsDialog(context, item);
        case _OpenShellOutputAction(:final shell):
          await showShellOutputDialog(context, live: widget.live, shell: shell);
        case null:
          _focus.requestFocus();
      }
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.live, widget.live.shellSightings]),
    builder: (context, _) {
      final state = widget.live.state;
      final children = subagentWork(state);
      final now = widget.live.clock().toUtc();
      final every = sessionShellEntries(
        state,
        canObserveShells: _canObserveShells,
        confirmedRemovedShellIds: _confirmedRemovedFor(state),
      );
      // A quick command never shows; one that runs on shows once it is
      // five seconds old.
      final shells = widget.live.shellSightings.shown(every, now);
      final visible =
          state != null && (children.isNotEmpty || shells.isNotEmpty);
      // The timeline keeps room for the chip only while it shows.
      if (widget.live.capsuleShown.value != visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!widget.live.disposed) widget.live.capsuleShown.value = visible;
        });
      }
      if (!visible) return const SizedBox.shrink();
      final activeSubagents = children
          .where(
            (work) => subagentIsActive(
              subagentStatus(work, state, current: _current),
            ),
          )
          .length;
      final activeShells = _current
          ? shells.where((shell) => shell.isRunning).length
          : 0;
      final count = activeSubagents + activeShells;
      final l10n = context.v2L10n;
      final colors = Theme.of(context).colorScheme;
      final tooltip = shells.isEmpty
          ? l10n.liveSubagentsCount(count)
          : l10n.liveActivityCapsuleCount(count);
      return SizedBox(
        height: SessionSubagentCapsule.height,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Tooltip(
            key: _anchor,
            message: tooltip,
            child: _CapsuleActivityBorder(
              active: count > 0,
              color: colors.primary,
              child: FilledButton.tonal(
                key: const ValueKey('subagent-capsule'),
                focusNode: _focus,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  elevation: 3,
                  shadowColor: colors.shadow,
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _show,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.smart_toy,
                      semanticLabel: l10n.liveSubagentsTitle,
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 8),
                      Text('$count', key: const ValueKey('subagent-count')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Luminous border sweeping around the capsule outline while work is active
/// (#525):
/// - inactive (`count == 0`): paints nothing and runs no ticker;
/// - active with reduced motion: paints a static `primary` border;
/// - active with motion enabled: sweeps a luminous `SweepGradient` arc around
///   the `StadiumBorder` outline (~2 s per full turn), paused automatically by
///   [TickerMode].
class _CapsuleActivityBorder extends StatefulWidget {
  const _CapsuleActivityBorder({
    required this.active,
    required this.color,
    required this.child,
  });

  static const period = Duration(milliseconds: 2000);

  final bool active;
  final Color color;
  final Widget child;

  @override
  State<_CapsuleActivityBorder> createState() => _CapsuleActivityBorderState();
}

class _CapsuleActivityBorderState extends State<_CapsuleActivityBorder>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _CapsuleActivityBorder.period,
  );
  bool _motion = true;

  void _syncAnimation() {
    if (widget.active && _motion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (!widget.active && _controller.value != 0) {
        _controller.value = 0;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = AppIndeterminate.motion(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _CapsuleActivityBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      key: const ValueKey('subagent-capsule-activity-border'),
      foregroundPainter: widget.active
          ? _CapsuleBorderPainter(
              color: widget.color,
              animate: _motion,
              animation: _controller,
            )
          : null,
      child: widget.child,
    ),
  );
}

class _CapsuleBorderPainter extends CustomPainter {
  _CapsuleBorderPainter({
    required this.color,
    required this.animate,
    required this.animation,
  }) : super(repaint: animate ? animation : null);

  final Color color;
  final bool animate;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;
    final outerRadius = rect.shortestSide / 2;

    RRect insetStadium(double strokeWidth) {
      final inset = min(strokeWidth / 2, outerRadius);
      return RRect.fromRectAndRadius(
        rect.deflate(inset),
        Radius.circular(max(0.0, outerRadius - inset)),
      );
    }

    if (!animate) {
      canvas.drawRRect(
        insetStadium(2.25),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.25
          ..color = color.withValues(alpha: 0.9),
      );
      return;
    }

    final clear = color.withValues(alpha: 0);
    final rotation = GradientRotation(animation.value * 2 * pi);

    // Subtle continuous perimeter ring so the sweeping glow stays anchored.
    canvas.drawRRect(
      insetStadium(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.24),
    );

    // Soft inner-bounded halo around the active arc without MaskFilter.blur.
    canvas.drawRRect(
      insetStadium(4.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..shader = SweepGradient(
          colors: [
            clear,
            clear,
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.34),
            clear,
          ],
          stops: const [0.0, 0.44, 0.70, 0.88, 1.0],
          transform: rotation,
        ).createShader(rect),
    );

    // Crisp luminous core gliding around the StadiumBorder outline.
    canvas.drawRRect(
      insetStadium(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = SweepGradient(
          colors: [
            clear,
            clear,
            color.withValues(alpha: 0.42),
            color,
            color.withValues(alpha: 0.6),
            clear,
          ],
          stops: const [0.0, 0.50, 0.72, 0.89, 0.96, 1.0],
          transform: rotation,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CapsuleBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.animate != animate ||
      oldDelegate.animation != animation;
}

class _SubagentPopin extends StatefulWidget {
  const _SubagentPopin({
    required this.live,
    required this.parent,
    required this.confirmedRemovedFor,
    required this.onAction,
  });

  final SessionLiveController live;
  final SessionRef parent;
  final Set<String> Function(SessionState?) confirmedRemovedFor;
  final ValueChanged<_PopinAction> onAction;

  @override
  State<_SubagentPopin> createState() => _SubagentPopinState();
}

class _SubagentPopinState extends State<_SubagentPopin> {
  Timer? _elapsedTimer;
  SessionShellStopOutcome? _stopOutcome;

  @override
  void initState() {
    super.initState();
    widget.live.addListener(_syncTimer);
    _syncTimer();
  }

  @override
  void dispose() {
    widget.live.removeListener(_syncTimer);
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    super.dispose();
  }

  bool get _canObserveShells => widget.live.shells?.canObserve ?? false;

  bool _hasTimedRunningShell() {
    if (!_canObserveShells ||
        widget.live.session != widget.parent ||
        widget.live.phase != SessionLivePhase.live ||
        widget.live.view?.stale == true) {
      return false;
    }
    final state = widget.live.state;
    if (state == null) return false;
    return state.shells.any(
      (shell) => shell.isRunning && shell.startedAt != null,
    );
  }

  void _syncTimer() {
    final needsTimer = _hasTimedRunningShell();
    if (needsTimer && _elapsedTimer == null) {
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!_hasTimedRunningShell()) {
          _elapsedTimer?.cancel();
          _elapsedTimer = null;
          return;
        }
        setState(() {});
      });
    } else if (!needsTimer && _elapsedTimer != null) {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  Future<void> _stopShell(String shellId) async {
    final port = widget.live.shells;
    if (port == null || !port.canStop) return;
    final outcome = await port.stop(shellId);
    if (!mounted) return;
    setState(() {
      _stopOutcome =
          outcome == SessionShellStopOutcome.rejected ||
              outcome == SessionShellStopOutcome.uncertain
          ? outcome
          : null;
    });
  }

  String _formatDuration(Duration duration) {
    final seconds = max(0, duration.inSeconds);
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    return rem == 0 ? '${minutes}m' : '${minutes}m ${rem}s';
  }

  String _shellSubtitle(
    CapsuleShellEntry entry,
    V2Localizations l10n, {
    required bool current,
  }) {
    if (entry.isUnconfirmed) return l10n.liveSubagentsUnknown;
    if (entry.isRunning) {
      if (!current) return l10n.liveSubagentsUnknown;
      if (_canObserveShells && entry.startedAt != null) {
        final elapsed = widget.live.clock().toUtc().difference(
          entry.startedAt!.toUtc(),
        );
        if (!elapsed.isNegative) {
          return '${l10n.toolRunning} · ${_formatDuration(elapsed)}';
        }
      }
      return l10n.toolRunning;
    }
    final statusLabel = switch (entry.status) {
      ShellStatus.timeout =>
        entry.exitToken != null
            ? '${l10n.liveShellTimedOut} · ${l10n.liveShellExitCode} ${entry.exitToken}'
            : l10n.liveShellTimedOut,
      ShellStatus.killed =>
        entry.exitCode != null
            ? '${l10n.liveShellKilled} · ${l10n.liveShellExitCode} ${entry.exitCode}'
            : l10n.liveShellKilled,
      ShellStatus.exited => switch ((entry.exitCode, entry.exitToken)) {
        (0, _) => l10n.liveToolDone,
        (final int code, _) =>
          '${l10n.statusFailed} · ${l10n.liveShellExitCode} $code',
        (null, final String token) => '${l10n.liveShellExitCode} $token',
        _ => switch (entry.timelineItem) {
          Notice(shellReport: ShellReport(outcome: OutcomeKind.succeeded)) =>
            l10n.liveToolDone,
          Notice(shellReport: ShellReport(outcome: OutcomeKind.failed)) =>
            l10n.statusFailed,
          Notice(shellReport: ShellReport(outcome: OutcomeKind.interrupted)) =>
            l10n.liveToolInterrupted,
          _ => l10n.liveSubagentsUnknown,
        },
      },
      ShellStatus.running => l10n.toolRunning,
      null => l10n.liveSubagentsUnknown,
    };
    if (entry.startedAt != null &&
        entry.completedAt != null &&
        !entry.completedAt!.isBefore(entry.startedAt!)) {
      return '$statusLabel · ${_formatDuration(entry.completedAt!.difference(entry.startedAt!))}';
    }
    return statusLabel;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.live.state;
    final initialSubagents = subagentWork(state);
    final now = widget.live.clock().toUtc();
    final initialShells = widget.live.shellSightings.shown(
      sessionShellEntries(
        state,
        canObserveShells: _canObserveShells,
        confirmedRemovedShellIds: widget.confirmedRemovedFor(state),
      ),
      now,
    );
    final isLive =
        widget.live.phase == SessionLivePhase.live &&
        widget.live.view?.stale != true &&
        state != null;
    final anyActiveSubagent =
        isLive &&
        initialSubagents.any(
          (w) => !subagentIsCompleted(subagentStatus(w, state)),
        );
    final anyActiveShell = isLive && initialShells.any((s) => s.isActiveTab);
    final anyCompleted =
        initialSubagents.any(
          (w) => isLive && subagentIsCompleted(subagentStatus(w, state)),
        ) ||
        initialShells.any((s) => !s.isActiveTab);
    final completedOnly =
        isLive && !anyActiveSubagent && !anyActiveShell && anyCompleted;

    return DefaultTabController(
      length: 2,
      initialIndex: completedOnly ? 1 : 0,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.live,
            widget.live.shellSightings,
          ]),
          builder: (context, _) {
            final l10n = context.v2L10n;
            final current =
                widget.live.phase == SessionLivePhase.live &&
                widget.live.view?.stale != true &&
                widget.live.session == widget.parent;
            final state = widget.live.state;
            final rows = subagentWork(state);
            final now = widget.live.clock().toUtc();
            final shells = widget.live.shellSightings.shown(
              sessionShellEntries(
                state,
                canObserveShells: _canObserveShells,
                confirmedRemovedShellIds: widget.confirmedRemovedFor(state),
              ),
              now,
            );
            final hasShells = shells.isNotEmpty;
            final activeSubagents = <(WorkItem, WorkStatus)>[];
            final completedSubagents = <(WorkItem, WorkStatus)>[];
            final activeShells = <CapsuleShellEntry>[];
            final completedShells = <CapsuleShellEntry>[];
            if (state != null && widget.live.session == widget.parent) {
              for (final work in rows) {
                final status = subagentStatus(work, state, current: current);
                (subagentIsCompleted(status)
                        ? completedSubagents
                        : activeSubagents)
                    .add((work, status));
              }
              for (final shell in shells) {
                (shell.isActiveTab ? activeShells : completedShells).add(shell);
              }
            }
            final stopFeedback = switch (_stopOutcome) {
              SessionShellStopOutcome.rejected => l10n.liveStopFailed,
              SessionShellStopOutcome.uncertain => l10n.liveStopUnconfirmed,
              _ => null,
            };
            return Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: l10n.liveSubagentsActive),
                    Tab(text: l10n.liveSubagentsCompleted),
                  ],
                ),
                if (stopFeedback != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        stopFeedback,
                        key: const ValueKey('shell-stop-feedback'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _list(
                        context,
                        activeSubagents,
                        activeShells,
                        l10n,
                        enabled: current,
                        hasShells: hasShells,
                      ),
                      _list(
                        context,
                        completedSubagents,
                        completedShells,
                        l10n,
                        enabled: current,
                        hasShells: hasShells,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<(WorkItem, WorkStatus)> subagents,
    List<CapsuleShellEntry> shells,
    V2Localizations l10n, {
    required bool enabled,
    required bool hasShells,
  }) {
    if (subagents.isEmpty && shells.isEmpty) {
      return Center(
        child: Text(
          hasShells ? l10n.liveActivityEmpty : l10n.liveSubagentsEmpty,
          textAlign: TextAlign.center,
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shellPort = widget.live.shells;
    final canStopShells = enabled && (shellPort?.canStop ?? false);

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final (work, status) in subagents)
          ListTile(
            key: ValueKey('subagent-row-${work.child!.storageKey}'),
            leading: const Icon(Symbols.smart_toy),
            title: Text(
              (work.title?.trim().isNotEmpty ?? false)
                  ? work.title!
                  : l10n.livePermissionChildBadge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(switch (status) {
              WorkStatus.running => l10n.liveRunning,
              WorkStatus.queued => l10n.composerQueued,
              WorkStatus.waiting => l10n.liveNeedsYou,
              WorkStatus.completed => l10n.liveSubagentsCompleted,
              WorkStatus.failed => l10n.statusFailed,
              WorkStatus.cancelled => l10n.liveSubagentsCancelled,
              WorkStatus.unknown => l10n.liveSubagentsUnknown,
            }),
            trailing: const Icon(Symbols.chevron_right),
            onTap: enabled
                ? () => widget.onAction(_OpenChildAction(work.child!))
                : null,
          ),
        for (final shell in shells)
          _shellTile(
            shell,
            l10n,
            theme: theme,
            scheme: scheme,
            enabled: enabled,
            canStopShells: canStopShells,
            stopping:
                shell.shellId != null &&
                (shellPort?.isStopping(shell.shellId!) ?? false),
            onStop: shell.shellId == null || shellPort == null
                ? null
                : () => unawaited(_stopShell(shell.shellId!)),
          ),
        if (subagents.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              l10n.liveSubagentsRecent,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _shellTile(
    CapsuleShellEntry shell,
    V2Localizations l10n, {
    required ThemeData theme,
    required ColorScheme scheme,
    required bool enabled,
    required bool canStopShells,
    required bool stopping,
    required VoidCallback? onStop,
  }) {
    final title = shell.command.isNotEmpty ? shell.command : l10n.toolKindShell;
    final subtitle = _shellSubtitle(shell, l10n, current: enabled);
    // Stop is offered only for owner-verified running live ShellWork rows.
    final showStop =
        shell.shellWork != null &&
        shell.shellWork!.isRunning &&
        canStopShells &&
        shell.shellId != null;

    // Live observed running shells open the live output dialog; completed
    // timeline shells open tool details (falling back to live output dialog
    // only for ephemeral completed shells without a timeline twin).
    VoidCallback? onTap;
    if (shell.isRunning &&
        _canObserveShells &&
        shell.shellWork != null &&
        enabled) {
      onTap = () => widget.onAction(_OpenShellOutputAction(shell.shellWork!));
    } else if (shell.timelineItem != null &&
        toolHasDetails(shell.timelineItem!)) {
      onTap = () =>
          widget.onAction(_OpenToolDetailsAction(shell.timelineItem!));
    } else if (_canObserveShells && shell.shellWork != null && enabled) {
      onTap = () => widget.onAction(_OpenShellOutputAction(shell.shellWork!));
    }

    return ListTile(
      key: ValueKey('shell-row-${shell.key}'),
      leading: Icon(
        Symbols.terminal,
        color: shell.isFailed
            ? scheme.error
            : shell.isRunning
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: shell.isFailed
            ? theme.textTheme.bodySmall?.copyWith(color: scheme.error)
            : null,
      ),
      trailing: showStop
          ? IconButton(
              key: ValueKey('shell-stop-${shell.shellId}'),
              tooltip: stopping ? l10n.liveStopping : l10n.liveStop,
              onPressed: stopping ? null : onStop,
              icon: Icon(
                Symbols.stop_circle,
                color: stopping ? scheme.onSurfaceVariant : scheme.error,
              ),
            )
          : (onTap != null ? const Icon(Symbols.chevron_right) : null),
      onTap: onTap,
    );
  }
}
