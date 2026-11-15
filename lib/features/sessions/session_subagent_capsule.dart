import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_live_source.dart';
import 'session_live_controller.dart';

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
  final _anchor = GlobalKey();
  final _focus = FocusNode();
  bool _open = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _current =>
      widget.live.phase == SessionLivePhase.live &&
      widget.live.view?.stale != true;

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
    final l10n = context.v2L10n;
    try {
      final child = await showGeneralDialog<SessionRef>(
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
                  onOpen: (ref) => Navigator.of(dialogContext).pop(ref),
                );
                return Stack(
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
                );
              },
            ),
      );
      if (!mounted || widget.live.session != parent) return;
      if (child != null) {
        widget.onOpen(child);
      } else {
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
      if (state == null || children.isEmpty) return const SizedBox.shrink();
      final count = children
          .where(
            (work) => subagentIsActive(
              subagentStatus(work, state, current: _current),
            ),
          )
          .length;
      final l10n = context.v2L10n;
      return SizedBox(
        height: SessionSubagentCapsule.height,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Tooltip(
            key: _anchor,
            message: l10n.liveSubagentsCount(count),
            child: FilledButton.tonal(
              key: const ValueKey('subagent-capsule'),
              focusNode: _focus,
              style: FilledButton.styleFrom(
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

class _SubagentPopin extends StatelessWidget {
  const _SubagentPopin({
    required this.live,
    required this.parent,
    required this.onOpen,
  });

  final SessionLiveController live;
  final SessionRef parent;
  final ValueChanged<SessionRef> onOpen;

  @override
  Widget build(BuildContext context) {
    final initial = subagentWork(live.state);
    final state = live.state;
    final completedOnly =
        live.phase == SessionLivePhase.live &&
        live.view?.stale != true &&
        state != null &&
        initial.every((w) => subagentIsCompleted(subagentStatus(w, state)));
    return DefaultTabController(
      length: 2,
      initialIndex: completedOnly ? 1 : 0,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListenableBuilder(
          listenable: live,
          builder: (context, _) {
            final l10n = context.v2L10n;
            final current =
                live.phase == SessionLivePhase.live &&
                live.view?.stale != true &&
                live.session == parent;
            final state = live.state;
            final rows = subagentWork(state);
            final active = <(WorkItem, WorkStatus)>[];
            final completed = <(WorkItem, WorkStatus)>[];
            if (state != null && live.session == parent) {
              for (final work in rows) {
                final status = subagentStatus(work, state, current: current);
                (subagentIsCompleted(status) ? completed : active).add((
                  work,
                  status,
                ));
              }
            }
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
                Expanded(
                  child: TabBarView(
                    children: [
                      _list(context, active, l10n, enabled: current),
                      _list(context, completed, l10n, enabled: current),
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
    List<(WorkItem, WorkStatus)> rows,
    V2Localizations l10n, {
    required bool enabled,
  }) => rows.isEmpty
      ? Center(
          child: Text(l10n.liveSubagentsEmpty, textAlign: TextAlign.center),
        )
      : ListView(
          padding: const EdgeInsets.all(8),
          children: [
            for (final (work, status) in rows)
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
                onTap: enabled ? () => onOpen(work.child!) : null,
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                l10n.liveSubagentsRecent,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
}
