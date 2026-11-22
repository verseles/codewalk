import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_shells.dart';
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

/// Whether the floating robot capsule should be displayed for [state].
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
    listenable: widget.live,
    builder: (context, _) {
      final state = widget.live.state;
      final children = subagentWork(state);
      final shells = sessionShellEntries(
        state,
        canObserveShells: _canObserveShells,
        confirmedRemovedShellIds: _confirmedRemovedFor(state),
      );
      if (state == null || (children.isEmpty && shells.isEmpty)) {
        return const SizedBox.shrink();
      }
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
      );
    },
  );
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
    final initialShells = sessionShellEntries(
      state,
      canObserveShells: _canObserveShells,
      confirmedRemovedShellIds: widget.confirmedRemovedFor(state),
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
          listenable: widget.live,
          builder: (context, _) {
            final l10n = context.v2L10n;
            final current =
                widget.live.phase == SessionLivePhase.live &&
                widget.live.view?.stale != true &&
                widget.live.session == widget.parent;
            final state = widget.live.state;
            final rows = subagentWork(state);
            final shells = sessionShellEntries(
              state,
              canObserveShells: _canObserveShells,
              confirmedRemovedShellIds: widget.confirmedRemovedFor(state),
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
