import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app/app_keyboard_shortcuts.dart';
import '../../app/workspace_actions.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_stop.dart';
import '../../shared/shortcuts/shortcut_action.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_composer.dart';
import 'session_composer_status.dart';
import 'session_error_card.dart';
import 'session_form_card.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_live_controller.dart';
import 'session_live_timeline.dart';
import 'session_permission_card.dart';
import 'session_permission_mode_chip.dart';
import 'session_selection_chip.dart';
import 'session_stop_button.dart';
import 'sessions_controller.dart';
import 'subconversation_navigation.dart';
import 'subconversation_resolver.dart';

/// Minimum height the prompt composer keeps beside a resident permission card:
/// the open composer's field and controls rows (#484).
const double _composerFloor = 104;

/// Live view of one session: it observes the server and sends prompts only
/// through the composer's outbox. Stop is explicit; it never answers or reverts.
class SessionLivePage extends StatefulWidget {
  const SessionLivePage({
    super.key,
    required this.controller,
    this.leading,
    this.ownsController = true,
    this.workspaceChrome = false,
    this.bodyFrame,
  });
  final SessionLiveController controller;

  /// Whether the page disposes [controller] with itself. A session tab keeps
  /// its view open while other tabs are shown, so its page does not.
  final bool ownsController;
  final bool workspaceChrome;
  final Widget Function(BuildContext, Widget)? bodyFrame;

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

  /// The composer field, which mod+L and a single Escape focus from anywhere
  /// in the workspace while this page is shown.
  final _composerFocus = FocusNode();
  WorkspaceActions? _shown;

  void _focusComposer() => _composerFocus.requestFocus();

  /// The latest sub-conversation tap; an older one opens nothing and its
  /// reads are cancelled.
  int _childTap = 0;
  SubconversationLookup? _childLookup;

  void _openChild(ToolCall tool) {
    final tap = ++_childTap;
    _childLookup?.cancel();
    final lookup = _childLookup = SubconversationLookup();
    unawaited(
      openSubconversation(
        context,
        widget.controller,
        tool,
        current: () => mounted && tap == _childTap,
        lookup: lookup,
      ),
    );
  }

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
    _shown = context.read<WorkspaceActions?>()?..claimComposer(_focusComposer);
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
    _childLookup?.cancel();
    _shown?.releaseComposer(_focusComposer);
    _composerFocus.dispose();
    _catalog?.leave(widget.controller.session);
    if (widget.ownsController) widget.controller.dispose();
    super.dispose();
  }

  /// The block above the timeline items. A conversation's state shows only
  /// in the status bar above its footer (#468); this keeps the permission
  /// mode and, outside the workspace, which session and server this is.
  Widget _header(
    BuildContext context,
    SessionLiveController c,
    V2Localizations l10n,
    TextTheme textTheme, {
    required bool canAct,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.workspaceChrome)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            // The model and agent are picked from the composer's chips.
            if (c.permissionModes != null)
              SessionPermissionModeChip(live: c, compact: true),
          ],
        )
      else ...[
        Text(
          canAct ? l10n.composerLiveSession : l10n.liveReadOnly,
          style: textTheme.titleMedium,
        ),
        Text(c.profileLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
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

  /// What an empty timeline shows: a quiet loader while the session loads,
  /// never the empty conversation (#69), and the empty conversation once a
  /// read of the session reported no items. Nothing while the view cannot be
  /// read.
  WidgetBuilder? _empty(SessionLiveController c, V2Localizations l10n) {
    if (c.loading) {
      return (context) => AppIndeterminateRing(
        key: const ValueKey('live-hydrating'),
        size: 28,
        strokeWidth: 2.5,
        semanticsLabel: l10n.liveHydrating,
      );
    }
    // Only a session synced at least once is known to be empty: a failed
    // first read may still publish a state with no items.
    if (c.state == null || c.view?.lastSyncedAt == null) return null;
    return (context) {
      final theme = Theme.of(context);
      return Column(
        key: const ValueKey('live-empty'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.waving_hand, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.chatHelloAssistant,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatWelcomeSubmessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    };
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

  Widget _frameBody(BuildContext context, Widget body) =>
      widget.bodyFrame?.call(context, body) ?? body;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    // The cycling shortcuts reach this session while it can switch.
    builder: (context, page) {
      final c = widget.controller;
      return KeyboardActionScope(
        handlers: c.supportsSelection && !c.isChild
            ? {
                ShortcutAction.cycleRecentModels: () =>
                    unawaited(c.cycleModel()),
                ShortcutAction.cycleVariant: () => unawaited(c.cycleVariant()),
                ShortcutAction.cycleAgentForward: () =>
                    unawaited(c.cycleAgent()),
                ShortcutAction.cycleAgentBackward: () =>
                    unawaited(c.cycleAgent(reverse: true)),
              }
            : const {},
        child: page!,
      );
    },
    child: _page(context),
  );

  Widget _page(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.controller.turn]),
    builder: (context, child) {
      final c = widget.controller;
      final l10n = context.v2L10n;
      final state = c.state;
      final cut = c.turnActions?.state.staged == true
          ? c.turnActions?.state.revert?.anchor
          : null;
      final rawItems = state?.timeline ?? const <TimelineItem>[];
      final items = cut == null
          ? rawItems
          : [
              for (final item in rawItems)
                if (item.meta.anchor == null ||
                    item.meta.anchor!.compareTo(cut) < 0)
                  item,
            ];
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
        // Inside the workspace the shell owns the only toolbar (decision 8).
        appBar: widget.workspaceChrome
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                // The chips follow this page's width, not the window's: beside the
                // session list the page is narrower than the window.
                child: LayoutBuilder(
                  builder: (context, bar) {
                    final compact = bar.maxWidth < 600;
                    return AppBar(
                      leading: widget.leading,
                      actions: [
                        if (c.permissionModes != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: SessionPermissionModeChip(
                              live: c,
                              compact: compact,
                            ),
                          ),
                      ],
                      title: Text(
                        c.summary.info.title.trim().isEmpty
                            ? l10n.sessionExportUntitled
                            : c.summary.info.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
        body: _frameBody(
          context,
          LayoutBuilder(
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
                  (c.summary.info.lineage.parent != null
                      ? returnToParentHeight(context)
                      : 0.0) +
                  MediaQuery.paddingOf(context).bottom +
                  (c.canRetry ? 48.0 : 0.0) +
                  (c.outbox == null ? SessionComposerStatus.height : 0.0) +
                  (stopButton ? 56.0 : 0.0) +
                  (stopNotice ? 24.0 : 0.0);
              final space = max(0.0, body.maxHeight - pad - chrome);
              final composerBase = max(
                0.0,
                // The open composer's two rows (#484) and the shortest
                // usable `/` picker above them.
                max(body.maxHeight * 0.4, min(body.maxHeight - 4, 182)) - pad,
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
                      // The status bar says what loads; this only shows it.
                      if (c.loading) const AppIndeterminateBar(),
                      if (c.summary.info.lineage.parent case final parent?)
                        ReturnToParentConversation(parent: parent),
                      Expanded(
                        child: SessionLiveTimeline(
                          onOpenChild: _openChild,
                          items: items,
                          userTurnActionBuilder: (context, turnItem, isLatest) {
                            final tooltip = isLatest
                                ? l10n.msgInfoUndoThisTurn
                                : l10n.chatMessageRewindEdit;
                            return IconButton(
                              key: ValueKey(
                                'user-turn-action-${turnItem.id.value}',
                              ),
                              icon: Icon(
                                isLatest
                                    ? Symbols.undo_rounded
                                    : Symbols.settings_backup_restore,
                              ),
                              // v1 density: a 48 dp target with a 24 dp glyph.
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              splashRadius: 18,
                              tooltip: tooltip,
                              onPressed: c.turn.canUndo
                                  ? () => unawaited(
                                      c.turn.stageUndo(
                                        target: turnItem,
                                        context: context,
                                      ),
                                    )
                                  : null,
                            );
                          },
                          emptyBuilder: _empty(c, l10n),
                          scroll: widget.controller.scroll,
                          settled: settled,
                          olderLoading: c.olderHistory.loading,
                          topBuilder: _top(c, l10n),
                          onLoadOlder: c.canLoadOlderHistory
                              ? c.loadOlderHistory
                              : null,
                          errorRecovery: (error) => sessionErrorRecovery(
                            l10n,
                            error,
                            chooseModel: canShowSessionSelection(c)
                                ? () => showSessionSelection(context, c)
                                : null,
                            openServers: () => context.push('/hosts'),
                          ),
                          headerBuilder: (context) => _header(
                            context,
                            c,
                            l10n,
                            textTheme,
                            canAct: canAct,
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: tight ? 2 : 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: cardBudget,
                                ),
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
                              if (c.canRetry)
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton(
                                    key: const ValueKey('live-retry'),
                                    onPressed: c.retry,
                                    child: Text(l10n.liveRetry),
                                  ),
                                ),
                              c.outbox == null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SessionComposerStatus(
                                          activity: liveStatus(c, l10n),
                                          retryAt: liveRetryAt(c),
                                          now: c.clock,
                                        ),
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
                                      focusNode: _composerFocus,
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
        ),
      );
    },
  );
}
