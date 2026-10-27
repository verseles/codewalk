import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
import '../hosts/server_switcher.dart';
import 'project_context_list.dart';
import 'project_contexts_controller.dart';
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

/// The start indent of one nesting level, and the deepest level the list
/// indents: deeper rows still nest, at the cap's indent.
const _nestingIndent = 16.0;
const _nestingMaxLevels = 3;

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
    final createReason =
        controller.selectedProfile != null &&
            controller.createReason != SessionActionReason.none &&
            controller.createReason != SessionActionReason.commandInFlight
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
      if (controller.behind) l10n.liveStale,
      if (controller.limited) l10n.sessionsLimit,
      if (controller.actionFailure != null) l10n.sessionsActionFailed,
      if (controller.hideUnreadable) l10n.sessionsActionUnavailableStore,
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
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 8,
            vertical: compact ? 16 : 8,
          ),
          itemCount: rows.length + 1,
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
        const WorkspaceDrawerNotice(),
        if (hosts.loading || controller.loading)
          LinearProgressIndicator(semanticsLabel: l10n.sessionsLoading),
        const ServerSwitcher(),
        if (contexts != null && ready)
          _projectTitle(context, controller, contexts),
        const SizedBox(height: 8),
        SessionDrawerHeader(
          catalog: controller,
          contexts: contexts,
          onCreate: ready && !controller.creating
              ? () => openWorkspaceDraft(context)
              : null,
        ),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('sessions-refresh'),
              tooltip: l10n.chatRefresh,
              onPressed: ready && !controller.refreshing
                  ? controller.refresh
                  : null,
              icon: const Icon(Icons.refresh),
            ),
            if (hosts.storageError)
              TextButton(
                onPressed: hosts.loading ? null : hosts.load,
                child: Text(l10n.chatRetry),
              ),
            IconButton(
              key: const ValueKey('sessions-settings'),
              tooltip: l10n.settingsTitle,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
            TextButton(
              key: const ValueKey('sessions-hosts'),
              onPressed: () => context.push('/hosts'),
              child: Text(l10n.onboardingConnectRunningServer),
            ),
          ],
        ),
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(notice),
          ),
      ],
    );
  }

  /// The project the list shows; a tap opens the project picker.
  Widget _projectTitle(
    BuildContext context,
    SessionsController controller,
    ProjectContextsController contexts,
  ) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final active = contexts.active;
    return InkWell(
      key: const ValueKey('project-title'),
      onTap: () => unawaited(
        pickWorkspaceProject(context, catalog: controller, contexts: contexts),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    active == null
                        ? l10n.chatChooseDirectory
                        : serverPathTitle(active),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (active != null)
                    StartEllipsisPath(
                      active,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.unfold_more, semanticLabel: l10n.chatChooseDirectory),
          ],
        ),
      ),
    );
  }

  /// The list of one project context: Recent across the open projects,
  /// then the open projects, the shown one followed by its conversations
  /// and the others by a preview of their last read.
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
    final hidden = controller.hiddenIn(everything);
    final visible = filterSessions(everything, hidden, controller.filter);
    final recent = recentSessions(everything, hidden);
    // Every emphasized row ends its hour, Recent's included.
    _scheduleEmphasis(nextEmphasisEnd([...visible, ...recent], now: now));
    final builders = <WidgetBuilder>[
      if (recent.isNotEmpty) ...[
        (context) => _sectionTitle(context, l10n.chatRecentSessions),
        for (final row in recent)
          (context) => RecentSessionRow(
            row: row,
            current: row.info.ref == current,
            running: controller
                .activityMarks(row)
                .contains(SessionActivityMark.running),
            emphasized: unreadEmphasized(row, now: now, current: current),
            onTap: available ? () => _openLive(context, controller, row) : null,
          ),
      ],
      (context) => _sectionTitle(context, l10n.workspaceOpenProjects),
    ];
    for (final directory in contexts.open) {
      final active = directory == shown;
      // A project not read yet has no count and says so.
      final rows = active
          ? (controller.contextRows(directory) == null
                ? null
                : controller.sessions)
          : switch (controller.contextRows(directory)) {
              final rows? => filterSessions(rows, hidden, controller.filter),
              null => null,
            };
      builders.add(
        (context) => ProjectContextRow(
          key: ValueKey('project-row-$directory'),
          directory: directory,
          active: active,
          count: rows?.length,
          complete: controller.contextComplete(directory),
          compact: compact,
          onTap: active || contexts.busy
              ? null
              : () async {
                  if (await contexts.activate(directory) && context.mounted) {
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
      if (active && rows != null) {
        final listed = projectSessionList(
          controller.sessions,
          query: contexts.query,
          sort: contexts.preferences.sort,
          pinned: contexts.isPinned,
        );
        for (final item in listed) {
          builders.add(
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
        builders.add((context) => _more(context, controller, available));
      } else if (rows == null) {
        builders.add((context) => _hint(context, l10n.chatOpenProjectToLoad));
      } else {
        for (final row
            in rows
                .where((row) => row.info.lineage.parent == null)
                .take(_previewRows)) {
          builders.add(
            (context) => _preview(context, controller, available, row),
          );
        }
      }
    }
    return builders;
  }

  /// The whole server's list, grouped by the project the server attributed
  /// each session to; the groups follow the rows the server returned, and
  /// inside a group a child is drawn under the parent its record names.
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

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 4),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

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
    bool available,
  ) {
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
            ? controller.loadMore
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
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: selected ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (directory != null)
                        StartEllipsisPath(
                          directory,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Icon(selected ? Icons.expand_less : Icons.expand_more),
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
                Icons.help_outline,
                14,
                scheme.tertiary,
                l10n.liveNeedsYou,
                'session-needs-you',
              ),
              SessionActivityMark.running => mark(
                Icons.sync,
                14,
                scheme.secondary,
                l10n.liveRunning,
                'session-running',
              ),
              SessionActivityMark.unread => mark(
                Icons.circle,
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

  /// A nested row: indented from the start edge by its depth, up to a cap
  /// that keeps a phone's content width, with a guide along the start edge.
  /// The directional insets mirror in a right-to-left locale.
  Widget _nested(
    BuildContext context,
    SessionSummary row,
    int depth,
    Widget child,
  ) {
    if (depth == 0) return child;
    final level = depth.clamp(1, _nestingMaxLevels);
    return Padding(
      key: ValueKey('session-nesting-${row.info.ref.storageKey}'),
      padding: EdgeInsetsDirectional.only(
        start: _nestingIndent * (level - 1) + 8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              width: 2,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        // The border paints over the box, so the padding clears it.
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: child,
        ),
      ),
    );
  }

  /// The lineage of a child row: a nested child, or a child whose parent is
  /// not drawn above it.
  Widget _lineage(BuildContext context, SessionSummary row, String text) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          key: ValueKey('session-lineage-${row.info.ref.storageKey}'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

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
    final l10n = context.v2L10n;
    final row = item.session;
    final lineage = item.depth > 0
        ? l10n.sessionsChildSession
        : item.parentElsewhere
        ? l10n.sessionsChildParentElsewhere
        : null;
    final pinned = contexts?.isPinned(row) ?? false;
    return _nested(
      context,
      row,
      item.depth,
      _row(
        context,
        controller,
        available,
        compact,
        row,
        lineage: lineage,
        selected: row.info.ref == current,
        emphasized: emphasized,
        pinned: pinned,
        onPin: contexts == null || row.info.project == null
            ? null
            : (pin) => unawaited(contexts.setPinned(row, pinned: pin)),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SessionsController controller,
    bool available,
    bool compact,
    SessionSummary row, {
    String? lineage,
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
    void openMenu() => _menuKey(row.info.ref).currentState?.showButtonMenu();
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (_) => openMenu(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.contextMenu): openMenu,
          const SingleActivator(LogicalKeyboardKey.f10, shift: true): openMenu,
        },
        child: Semantics(
          selected: selected,
          customSemanticsActions: {
            CustomSemanticsAction(label: l10n.sessionsActionsMenu): openMenu,
          },
          child: InkWell(
            key: ValueKey('live-open-${row.info.ref.storageKey}'),
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
              padding: EdgeInsetsDirectional.fromSTEB(
                12,
                compact ? 12 : 6,
                4,
                compact ? 12 : 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Icons.push_pin,
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
                                maxLines: compact ? 3 : 2,
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
                        // show unknown.
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            sessionOwnershipLabel(
                              l10n,
                              displayedSessionOwnership(
                                row.info.ownership,
                                now: controller.now,
                                current:
                                    !controller.stale && !controller.behind,
                              ),
                            ),
                            key: ValueKey(
                              'session-ownership-${row.info.ref.storageKey}',
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (lineage != null) _lineage(context, row, lineage),
                        if (controller.activityMarks(row) case final marks
                            when marks.isNotEmpty)
                          _activityMarks(context, row, marks),
                      ],
                    ),
                  ),
                  SessionActionsMenu(
                    controller: controller,
                    row: row,
                    menuKey: _menuKey(row.info.ref),
                    pinned: pinned,
                    onPin: onPin,
                    historyEnabled:
                        !_openingHistory && !controller.loading && available,
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
    );
    // A completed reply not seen yet keeps a subtle highlight for its hour;
    // every other row stays on the list's own surface.
    return AccentedRow(
      key: ValueKey<SessionRef>(row.info.ref),
      selected: selected,
      child: emphasized
          ? ColoredBox(
              key: ValueKey('session-emphasis-${row.info.ref.storageKey}'),
              color: scheme.primary.withValues(alpha: 0.08),
              child: content,
            )
          : content,
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
