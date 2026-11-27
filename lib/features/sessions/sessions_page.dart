import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app/workspace_chrome.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/layout/window_size_class.dart';
import '../../shared/sessions/server_path.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../../shared/sessions/session_visibility.dart';
import '../../shared/theme/app_surface_tokens.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../hosts/server_switcher.dart';
import 'project_context_list.dart';
import 'project_contexts_controller.dart';
import 'project_icon_view.dart';
import 'project_picker_dialog.dart';
import 'session_actions_menu.dart';
import 'session_drawer_header.dart';
import 'session_grouping.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_list_projection.dart';
import 'session_ownership.dart';
import 'sessions_controller.dart';
import 'workspace_draft_page.dart';

/// The conversations an inactive project previews from its last read.
const _previewRows = 3;

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  SessionsController? _controller;
  bool _openingHistory = false;

  /// The shown project whose conversations the user folded away by tapping
  /// it; showing another project drops the fold, and a search shows the rows
  /// while it lasts.
  String? _folded;

  // The project whose "Show more" lists every conversation (#534).
  String? _expanded;

  // Where each keyed row of the project list sits in this build, so a row
  // that moves when the projects reorder keeps its element, focus included
  // (#534).
  final _rowIndex = <Key, int>{};

  /// Rebuilds the list when the first unread emphasis ends.
  Timer? _emphasis;

  /// The popup of each row, so the row's own gestures open the same menu.
  final _menuKeys = <String, GlobalKey<PopupMenuButtonState>>{};

  GlobalKey<PopupMenuButtonState> _menuKey(SessionRef ref) =>
      _menuKeys.putIfAbsent(
        ref.storageKey,
        () => GlobalKey<PopupMenuButtonState>(
          debugLabel: 'session-actions-${ref.storageKey}',
        ),
      );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.watch<SessionsController?>();
    if (identical(controller, _controller)) return;
    _controller = controller;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(controller, _controller)) {
          controller.initialize();
        }
      });
    }
  }

  @override
  void dispose() {
    _emphasis?.cancel();
    super.dispose();
  }

  void _scheduleEmphasis(Duration? next) {
    _emphasis?.cancel();
    _emphasis = next == null
        ? null
        : Timer(next, () {
            if (mounted) setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionsController?>();
    final contexts = context.watch<ProjectContextsController?>();
    final l10n = context.v2L10n;
    if (controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.sessionsUnavailable),
        ),
      );
    }
    final hosts = controller.hosts;
    final available = !hosts.loading && !hosts.storageError;
    final compact = WindowSizeClass.fromWidth(
      MediaQuery.sizeOf(context).width,
    ).isCompact;
    // The list reads one project context once the contexts are readable;
    // until then it reads the whole server, grouped by project.
    final directory = controller.directory;
    final scoped =
        contexts != null &&
        contexts.available &&
        directory != null &&
        contexts.active == directory;
    // A list that is catching up is transient, not a reason to read: the
    // workspace notice above already says the conversations are syncing, and
    // the draft explains a create it holds (#532).
    final createReason =
        controller.selectedProfile != null &&
            controller.createReason != SessionActionReason.none &&
            controller.createReason != SessionActionReason.commandInFlight &&
            controller.createReason != SessionActionReason.listNotCurrent
        ? _actionReasonText(l10n, controller.createReason)
        : null;
    final notice = contexts?.notice ?? ProjectContextNotice.none;
    final notices = <String>[
      if (hosts.storageError) l10n.hostsProfileStorageError,
      if (hosts.loading || controller.loading) l10n.sessionsLoading,
      if (available && hosts.profiles.isEmpty) l10n.serversNoServersFound,
      if (controller.failure != null)
        sessionCatalogFailureText(l10n, controller.failure!),
      if (controller.stale) l10n.sessionsPreviousResults,
      if (controller.limited) l10n.sessionsLimit,
      if (controller.actionFailure != null) l10n.sessionsActionFailed,
      if (controller.actionUncertain) l10n.sessionsActionPending,
      ?createReason,
      if (notice == ProjectContextNotice.soleContext)
        l10n.projectProviderErrorAtLeastOneContext,
      if (notice == ProjectContextNotice.capacity) l10n.projectsCapacity,
      if (notice == ProjectContextNotice.unavailable ||
          (contexts?.unreadable ?? false))
        l10n.projectsUnavailable,
      if (controller.loaded &&
          !controller.loading &&
          !controller.stale &&
          controller.failure == null &&
          controller.sessions.isEmpty)
        scoped ? l10n.chatNoConversationsInProject : l10n.sessionsEmpty,
    ];
    _rowIndex.clear();
    final rows = scoped
        ? _scopedRows(context, controller, contexts, available, compact)
        : _serverRows(context, controller, available, compact);
    final header = _header(
      context,
      controller,
      contexts != null && contexts.available ? contexts : null,
      available,
      notices,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView.builder(
          // The server row sits near the top edge; the phone keeps more room
          // at the end, above the system gestures (#533).
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 8,
            8,
            compact ? 12 : 8,
            compact ? 16 : 8,
          ),
          itemCount: rows.length + 1,
          findChildIndexCallback: (key) => _rowIndex[key],
          itemBuilder: (context, index) =>
              index == 0 ? header : rows[index - 1](context),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    SessionsController controller,
    ProjectContextsController? contexts,
    bool available,
    List<String> notices,
  ) {
    final l10n = context.v2L10n;
    final hosts = controller.hosts;
    final ready = available && controller.selectedProfile != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The server row stays at the top; transient notices (syncing, an
        // update, a loading bar) come below it instead of pushing it down
        // (#533).
        Row(
          children: [
            const Expanded(child: ServerSwitcher()),
            IconButton(
              key: const ValueKey('sidebar_settings_icon_button'),
              tooltip: l10n.settingsTitle,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Symbols.settings, size: 20),
            ),
          ],
        ),
        const WorkspaceDrawerNotice(),
        if (hosts.loading || controller.loading)
          AppIndeterminateBar(semanticsLabel: l10n.sessionsLoading),
        const SizedBox(height: 8),
        SessionDrawerHeader(
          contexts: contexts,
          onCreate: ready && !controller.creating
              ? () => openWorkspaceDraft(context)
              : null,
          onProjects: contexts != null && ready
              ? () => unawaited(
                  pickWorkspaceProject(
                    context,
                    catalog: controller,
                    contexts: contexts,
                  ),
                )
              : null,
        ),
        // Settings and Servers are in the toolbar (decision 10) and the list
        // recovers by itself (#467); the retry stays here while the stored
        // profiles cannot be read.
        if (hosts.storageError)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: hosts.loading ? null : hosts.load,
              child: Text(l10n.chatRetry),
            ),
          ),
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(notice),
          ),
      ],
    );
  }

  /// The list of one project context: the open projects, the shown one
  /// first with up to five of its conversations and the others below it by
  /// what happened last in each, with a preview of their last read (#534).
  List<WidgetBuilder> _scopedRows(
    BuildContext context,
    SessionsController controller,
    ProjectContextsController contexts,
    bool available,
    bool compact,
  ) {
    final l10n = context.v2L10n;
    final shown = controller.directory!;
    final now = controller.now;
    final current = contexts.viewOf(shown);
    final everything = [
      for (final directory in contexts.open)
        ...?controller.contextRows(directory),
    ];
    final visible = [
      for (final row in everything)
        if (isPrimarySummary(row)) row,
    ];
    // Every emphasized row ends its hour.
    _scheduleEmphasis(nextEmphasisEnd(visible, now: now));
    final builders = <WidgetBuilder>[];
    // A keyed row is found again after a reorder; the header is index 0.
    void add(Key key, WidgetBuilder build) {
      builders.add((context) => KeyedSubtree(key: key, child: build(context)));
      _rowIndex[key] = builders.length;
    }

    // A fold and a "Show more" belong to the project shown when they were
    // made: the page builds again on every switch, so another project shown
    // by any route (a tap, a preview, a link) drops them.
    if (_folded != shown) _folded = null;
    if (_expanded != shown) _expanded = null;
    final searching = contexts.query.isNotEmpty;
    for (final directory in contexts.ordered) {
      final active = directory == shown;
      // A search always shows the rows it filters.
      final folded = active && _folded == directory && !searching;
      // A project not read yet has no count and says so.
      final rows = active
          ? (controller.contextRows(directory) == null
                ? null
                : controller.sessions)
          : switch (controller.contextRows(directory)) {
              final rows? => [
                for (final row in rows)
                  if (isPrimarySummary(row)) row,
              ],
              null => null,
            };
      add(
        ValueKey('drawer-project-$directory'),
        (context) => ProjectContextRow(
          key: ValueKey('project-row-$directory'),
          directory: directory,
          icon: controller.projects.iconAt(directory),
          active: active,
          // The count names the conversations the project lists: only the
          // primary ones, the same rows an open project shows.
          count: rows?.where(isPrimarySummary).length,
          complete: controller.contextComplete(directory),
          compact: compact,
          expanded: active && !folded,
          // The shown project folds and unfolds its conversations, except
          // during a search, whose rows stay; another one is shown, unfolded.
          onTap: active
              ? searching
                    ? null
                    : () => setState(() => _folded = folded ? null : directory)
              : contexts.busy
              ? null
              : () async {
                  if (await contexts.activate(directory) && context.mounted) {
                    setState(() => _folded = null);
                    _showContext(context, controller, contexts, directory);
                  }
                },
          onClose: contexts.busy
              ? null
              : () async {
                  // Closing the shown project shows the one that takes
                  // its place, never a session of the closed project.
                  // A route the user changed meanwhile wins.
                  final shown = contexts.active == directory;
                  final router = GoRouter.of(context);
                  final before = router.routeInformationProvider.value.uri;
                  if (await contexts.close(directory) &&
                      shown &&
                      context.mounted &&
                      router.routeInformationProvider.value.uri == before) {
                    if (contexts.active case final next?) {
                      _showContext(context, controller, contexts, next);
                    }
                  }
                },
        ),
      );
      if (folded) {
        // Folded by the user: only the row shows.
      } else if (active && rows != null) {
        final listed = projectSessionList(
          controller.sessions,
          query: contexts.query,
          pinned: contexts.isPinned,
        );
        // Five conversations, pins first and the one on screen always among
        // them; "Show more" lists every row read, and a search every match
        // (#534).
        final window = activeProjectWindow(listed, current: current);
        final expanded = _expanded == directory;
        final whole = searching || expanded || window.hidden == 0;
        for (final item in whole ? listed : window.shown) {
          add(
            ValueKey('drawer-session-${item.session.info.ref.storageKey}'),
            (context) => _sessionRow(
              context,
              controller,
              contexts,
              available,
              compact,
              item,
              current: current,
              emphasized: unreadEmphasized(
                item.session,
                now: now,
                current: current,
              ),
            ),
          );
        }
        if (!searching && window.hidden > 0) {
          add(
            ValueKey('drawer-reveal-$directory'),
            (context) => _reveal(context, directory, expanded: expanded),
          );
        }
        // Load more reads the next page into the full list, which opens so
        // the page shows.
        if (whole) {
          add(
            ValueKey('drawer-more-$directory'),
            (context) => _more(
              context,
              controller,
              available,
              onLoad: searching
                  ? null
                  : () => setState(() => _expanded = directory),
            ),
          );
        }
      } else if (rows == null) {
        add(
          ValueKey('drawer-hint-$directory'),
          (context) => _hint(context, l10n.chatOpenProjectToLoad),
        );
      } else {
        for (final row
            in rows
                .where((row) => row.info.lineage.parent == null)
                .take(_previewRows)) {
          add(
            ValueKey('drawer-preview-${row.info.ref.storageKey}'),
            (context) => _preview(context, controller, available, row),
          );
        }
      }
    }
    return builders;
  }

  /// The whole server's list, grouped by the project the server attributed
  /// each session to; the groups follow the rows the server returned, and
  /// only primary sessions appear inside each group.
  List<WidgetBuilder> _serverRows(
    BuildContext context,
    SessionsController controller,
    bool available,
    bool compact,
  ) {
    _scheduleEmphasis(null);
    final open = controller.selectedProject;
    return [
      for (final item in sessionListItems(controller.sessions, open: open))
        switch (item) {
          SessionGroupHeader(:final group) => (context) => _groupHeader(
            context,
            controller,
            group,
            selected: open?.project == group.project,
          ),
          final SessionRow row => (context) => _sessionRow(
            context,
            controller,
            null,
            available,
            compact,
            row,
          ),
        },
      (context) => _more(context, controller, available),
    ];
  }

  /// Shows every conversation the shown project read, or its first five
  /// again (#534).
  Widget _reveal(
    BuildContext context,
    String directory, {
    required bool expanded,
  }) {
    final l10n = context.v2L10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const ValueKey('sessions-reveal'),
        onPressed: () =>
            setState(() => _expanded = expanded ? null : directory),
        child: Text(
          expanded
              ? l10n.chatProjectShowFewerSessions
              : l10n.chatProjectShowMoreSessions,
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 12, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// One conversation of a project the list does not show, from its last
  /// read; a tap opens it, which shows its project.
  Widget _preview(
    BuildContext context,
    SessionsController controller,
    bool available,
    SessionSummary row,
  ) {
    final l10n = context.v2L10n;
    return InkWell(
      key: ValueKey('project-preview-${row.info.ref.storageKey}'),
      onTap: available ? () => _openLive(context, controller, row) : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 12, 4),
        child: Text(
          row.info.title.trim().isEmpty
              ? l10n.sessionExportUntitled
              : row.info.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _more(
    BuildContext context,
    SessionsController controller,
    bool available, {
    VoidCallback? onLoad,
  }) {
    final l10n = context.v2L10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const ValueKey('sessions-more'),
        onPressed:
            available &&
                controller.hasMore &&
                !controller.loading &&
                !controller.stale
            ? () {
                onLoad?.call();
                controller.loadMore();
              }
            : null,
        child: Text(l10n.chatLoadMore),
      ),
    );
  }

  /// The header of one project group: the directory the server reported, with
  /// its last segment as the title. Choosing it shows its sessions, as the
  /// project list of the legacy workspace does. The path is always
  /// left-to-right, so the separators do not reorder in a right-to-left
  /// locale.
  Widget _groupHeader(
    BuildContext context,
    SessionsController controller,
    SessionGroup group, {
    required bool selected,
  }) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final directory = group.project?.canonicalDirectory;
    final title = directory == null
        ? l10n.sessionsUnknownProject
        : serverPathTitle(directory);
    return Semantics(
      header: true,
      selected: selected,
      child: AccentedRow(
        selected: selected,
        child: InkWell(
          key: ValueKey('session-project-${directory ?? ''}'),
          onTap: () => controller.selectProject(group.project),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // v1: chat_page_scaffold.dart project group row (folder
                      // and count beside the title). The path keeps the full
                      // width below, so its trailing folders stay visible.
                      Row(
                        children: [
                          ProjectIconView(
                            source: controller.projects.iconFor(group.project),
                            color: selected ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${group.sessions.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: selected ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (directory != null)
                        StartEllipsisPath(
                          directory,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Icon(selected ? Symbols.expand_less : Symbols.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The reason the create is not offered, as the plan's controls say.
  String? _actionReasonText(
    V2Localizations l10n,
    SessionActionReason reason,
  ) => switch (reason) {
    SessionActionReason.none => null,
    SessionActionReason.versionUnverified =>
      l10n.sessionsActionUnavailableVersion,
    SessionActionReason.unsupportedPlatform =>
      l10n.sessionsActionUnavailablePlatform,
    SessionActionReason.authenticationRequired =>
      l10n.sessionsActionUnavailableAuth,
    SessionActionReason.listNotCurrent => l10n.sessionsActionUnavailableList,
    SessionActionReason.commandInFlight => l10n.sessionsActionUnavailableBusy,
    SessionActionReason.noIdleMarker => l10n.sessionsActionUnavailableMarker,
  };

  /// The row's marks, each from its own observed source: a pending
  /// permission request or form, the endpoint's active map and its unread
  /// marker (the session went idle and that transition was not seen yet).
  /// They are compact foreground badges that wrap in the narrow pane
  /// instead of overflowing it, and the label is what a screen reader
  /// announces.
  Widget _activityMarks(
    BuildContext context,
    SessionSummary row,
    List<SessionActivityMark> marks,
  ) {
    final l10n = context.v2L10n;
    final scheme = Theme.of(context).colorScheme;
    final key = row.info.ref.storageKey;
    Widget mark(
      IconData icon,
      double size,
      Color color,
      String text,
      String id,
    ) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            key: ValueKey('$id-$key'),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final kind in marks)
            switch (kind) {
              SessionActivityMark.needsYou => mark(
                Symbols.help_outline,
                14,
                scheme.tertiary,
                l10n.liveNeedsYou,
                'session-needs-you',
              ),
              SessionActivityMark.running => mark(
                Symbols.sync,
                14,
                scheme.secondary,
                l10n.liveRunning,
                'session-running',
              ),
              SessionActivityMark.unread => mark(
                Symbols.circle,
                10,
                scheme.primary,
                l10n.sessionsActionUnread,
                'session-unread',
              ),
            },
        ],
      ),
    );
  }

  Widget _sessionRow(
    BuildContext context,
    SessionsController controller,
    ProjectContextsController? contexts,
    bool available,
    bool compact,
    SessionRow item, {
    SessionRef? current,
    bool emphasized = false,
  }) {
    final row = item.session;
    final pinned = contexts?.isPinned(row) ?? false;
    return _row(
      context,
      controller,
      available,
      compact,
      row,
      selected: row.info.ref == current,
      emphasized: emphasized,
      pinned: pinned,
      onPin: contexts == null || row.info.project == null
          ? null
          : (pin) => unawaited(contexts.setPinned(row, pinned: pin)),
    );
  }

  Widget _row(
    BuildContext context,
    SessionsController controller,
    bool available,
    bool compact,
    SessionSummary row, {
    bool selected = false,
    bool emphasized = false,
    bool pinned = false,
    ValueChanged<bool>? onPin,
  }) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = context.watch<SessionLiveDirectory?>() != null;
    final history = context.watch<SessionHistoryFactory?>() != null;
    final ownership = displayedSessionOwnership(
      row.info.ownership,
      now: controller.now,
      current: !controller.stale && !controller.behind,
    );
    void openMenu() => _menuKey(row.info.ref).currentState?.showButtonMenu();
    const rowRadius = BorderRadius.all(Radius.circular(8));
    // Selected sessions use a subtle contrasted fill (the start accent bar
    // stays exclusive to the selected project header); an unread completed
    // reply keeps a lighter highlight for its hour.
    final background = selected
        ? theme.surfaceTokens.selectedSurface
        : emphasized
        ? scheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    return KeyedSubtree(
      key: ValueKey<SessionRef>(row.info.ref),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (_) => openMenu(),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.contextMenu): openMenu,
            const SingleActivator(LogicalKeyboardKey.f10, shift: true):
                openMenu,
          },
          child: Semantics(
            selected: selected,
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.sessionsActionsMenu): openMenu,
            },
            child: Material(
              key: ValueKey('session-surface-${row.info.ref.storageKey}'),
              color: background,
              borderRadius: rowRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('live-open-${row.info.ref.storageKey}'),
                borderRadius: rowRadius,
                // A tap opens the session; without a live view it opens the
                // read-only history instead.
                onTap: !available
                    ? null
                    : live
                    ? () => _openLive(context, controller, row)
                    : history
                    ? () => _openHistory(context, controller, row)
                    : null,
                onLongPress: openMenu,
                child: Padding(
                  // Denser than before #534: the menu's button no longer sets
                  // the height, and a title wraps to two lines at most.
                  padding: EdgeInsetsDirectional.fromSTEB(
                    12,
                    compact ? 8 : 4,
                    4,
                    compact ? 8 : 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                if (pinned)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 4,
                                    ),
                                    child: Icon(
                                      Symbols.push_pin,
                                      key: ValueKey(
                                        'session-pinned-${row.info.ref.storageKey}',
                                      ),
                                      size: 14,
                                      color: scheme.primary,
                                      semanticLabel: l10n.sessionsPinnedMark,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    row.info.title.trim().isEmpty
                                        ? l10n.sessionExportUntitled
                                        : row.info.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (compact
                                                ? theme.textTheme.titleMedium
                                                : theme.textTheme.titleSmall)
                                            ?.copyWith(
                                              color: selected || emphasized
                                                  ? scheme.primary
                                                  : null,
                                              fontWeight: selected || emphasized
                                                  ? FontWeight.w600
                                                  : null,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                            // The ownership the adapter proved, and nothing
                            // else: an unproven, stale or expired proof, and a
                            // list that is not the endpoint's current answer,
                            // omit the subtitle instead of repeating unknown.
                            if (ownership != OwnershipKind.unknown)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  sessionOwnershipLabel(l10n, ownership),
                                  key: ValueKey(
                                    'session-ownership-${row.info.ref.storageKey}',
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (controller.activityMarks(row) case final marks
                                when marks.isNotEmpty)
                              _activityMarks(context, row, marks),
                          ],
                        ),
                      ),
                      SessionActionsMenu(
                        controller: controller,
                        row: row,
                        buttonSize: compact ? 40 : 32,
                        menuKey: _menuKey(row.info.ref),
                        pinned: pinned,
                        onPin: onPin,
                        historyEnabled:
                            !_openingHistory &&
                            !controller.loading &&
                            available,
                        onHistory: live && history
                            ? () {
                                if (controller.loading || !available) return;
                                _openHistory(context, controller, row);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openHistory(
    BuildContext context,
    SessionsController catalog,
    SessionSummary row,
  ) async {
    final profile = catalog.selectedProfile;
    final factory = context.read<SessionHistoryFactory?>();
    if (_openingHistory ||
        profile == null ||
        factory == null ||
        catalog.findSession(row.info.ref) == null) {
      return;
    }
    setState(() => _openingHistory = true);
    final history = SessionHistoryController(
      hosts: catalog.hosts,
      profile: profile,
      summary: row,
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

  /// Shows what the project at [directory] last showed: its session, or
  /// its list or draft, so a project never keeps another project's session
  /// beside its list.
  void _showContext(
    BuildContext context,
    SessionsController catalog,
    ProjectContextsController contexts,
    String directory,
  ) {
    final profile = catalog.selectedProfile;
    if (profile == null || contexts.active != directory) return;
    final view = contexts.viewOf(directory);
    context.go(
      view == null
          ? '/sessions'
          : Uri(pathSegments: ['', 's', profile.id, view.nativeId]).toString(),
    );
  }

  /// Opens the session in the workspace, through the same route a link
  /// takes; a compact window closes the list drawer first. A session of
  /// another open project opens there, and its project becomes the shown
  /// one.
  void _openLive(
    BuildContext context,
    SessionsController catalog,
    SessionSummary row,
  ) {
    final profile = catalog.selectedProfile;
    if (profile == null || catalog.findSession(row.info.ref) == null) return;
    Scaffold.maybeOf(context)?.closeDrawer();
    context.go(
      Uri(
        pathSegments: ['', 's', profile.id, row.info.ref.nativeId],
      ).toString(),
    );
  }
}

/// The title of a project: its directory's last segment, or the directory
/// itself at a root.
String serverPathTitle(String directory) {
  final name = serverPathName(directory);
  return name.isEmpty ? directory : name;
}

/// What a failed read of the session list tells the user.
String sessionCatalogFailureText(
  V2Localizations l10n,
  SessionCatalogFailure failure,
) => switch (failure) {
  SessionCatalogFailure.authenticationRequired => l10n.hostsAuthRequired,
  SessionCatalogFailure.unsupportedPlatform => l10n.sessionsUnavailable,
  SessionCatalogFailure.timeout => l10n.sessionsTimeout,
  SessionCatalogFailure.invalidCursor => l10n.sessionsInvalidCursor,
  SessionCatalogFailure.rateLimited => l10n.sessionsRateLimited,
  SessionCatalogFailure.unavailable ||
  SessionCatalogFailure.incompatibleResponse ||
  SessionCatalogFailure.cancelled ||
  SessionCatalogFailure.notFound ||
  SessionCatalogFailure.connection => l10n.sessionsReadFailed,
};
