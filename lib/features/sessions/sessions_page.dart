import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/workspace_chrome.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/sessions/session_activity.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import '../hosts/server_switcher.dart';
import 'session_actions_menu.dart';
import 'session_grouping.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_ownership.dart';
import 'sessions_controller.dart';
import 'workspace_draft_page.dart';

/// The start indent of one nesting level, and the deepest level the list
/// indents: deeper rows still nest, at the cap's indent.
const _nestingIndent = 16.0;
const _nestingMaxLevels = 3;

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  SessionsController? _controller;
  bool _openingHistory = false;

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
  Widget build(BuildContext context) {
    final controller = context.watch<SessionsController?>();
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
    // The list is grouped by the project the server attributed each session
    // to; the groups follow the rows the server returned, and inside a group
    // a child is drawn under the parent its record names.
    final open = controller.selectedProject;
    final items = sessionListItems(controller.sessions, open: open);
    final createReason =
        controller.selectedProfile != null &&
            controller.createReason != SessionActionReason.none &&
            controller.createReason != SessionActionReason.commandInFlight
        ? _actionReasonText(l10n, controller.createReason)
        : null;
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
      if (controller.loaded &&
          !controller.loading &&
          !controller.stale &&
          controller.failure == null &&
          controller.sessions.isEmpty)
        l10n.sessionsEmpty,
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const WorkspaceDrawerNotice(),
                  Text(
                    l10n.chatConversations,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (hosts.loading || controller.loading)
                    LinearProgressIndicator(
                      semanticsLabel: l10n.sessionsLoading,
                    ),
                  const ServerSwitcher(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PopupMenuButton<SessionActionFilter>(
                      key: const ValueKey('sessions-filter'),
                      tooltip: _filterLabel(l10n, controller.filter),
                      onSelected: controller.setFilter,
                      itemBuilder: (context) => [
                        for (final filter in SessionActionFilter.values)
                          PopupMenuItem<SessionActionFilter>(
                            value: filter,
                            child: Text(_filterLabel(l10n, filter)),
                          ),
                      ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(_filterLabel(l10n, controller.filter)),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                      // The create is a compact control, so the header does
                      // not push the rows out of a small viewport.
                      IconButton.filled(
                        key: const ValueKey('sessions-create'),
                        tooltip: l10n.sessionsCreateNew,
                        onPressed:
                            available &&
                                controller.selectedProfile != null &&
                                !controller.creating
                            ? () => _openCreate(context, controller)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                      FilledButton.tonal(
                        key: const ValueKey('sessions-refresh'),
                        onPressed:
                            available &&
                                controller.selectedProfile != null &&
                                !controller.refreshing
                            ? controller.refresh
                            : null,
                        child: Text(l10n.chatRefresh),
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
            if (index == items.length + 1) {
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
            final item = items[index - 1];
            return switch (item) {
              SessionGroupHeader(:final group) => _groupHeader(
                context,
                controller,
                group,
                selected: open?.project == group.project,
              ),
              SessionRow(
                :final session,
                :final depth,
                :final parentElsewhere,
              ) =>
                _nested(
                  context,
                  session,
                  depth,
                  _row(
                    context,
                    controller,
                    available,
                    session,
                    lineage: depth > 0
                        ? l10n.sessionsChildSession
                        : parentElsewhere
                        ? l10n.sessionsChildParentElsewhere
                        : null,
                  ),
                ),
            };
          },
        ),
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
    final segments = (directory ?? '')
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty);
    final title = directory == null
        ? l10n.sessionsUnknownProject
        : segments.isEmpty
        ? directory
        : segments.last;
    return Semantics(
      header: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('session-project-${directory ?? ''}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.selectProject(group.project),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        directory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
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

  Future<void> _openCreate(
    BuildContext context,
    SessionsController controller,
  ) async {
    openWorkspaceDraft(context);
  }

  /// The label of the filter that shows which sessions the list holds.
  String _filterLabel(V2Localizations l10n, SessionActionFilter filter) =>
      switch (filter) {
        SessionActionFilter.active => l10n.sessionsFilterActive,
        SessionActionFilter.hidden => l10n.sessionsFilterHidden,
        SessionActionFilter.all => l10n.sessionsFilterAll,
      };

  /// The row's marks, each from its own observed source: a pending
  /// permission request or form, the endpoint's active map and its unread
  /// marker (the session went idle and that transition was not seen yet).
  /// They wrap in the narrow pane instead of overflowing it, and the label is
  /// what a screen reader announces.
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
    Widget card,
  ) {
    if (depth == 0) return card;
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
          child: card,
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

  Widget _row(
    BuildContext context,
    SessionsController controller,
    bool available,
    SessionSummary row, {
    String? lineage,
  }) {
    final l10n = context.v2L10n;
    final live = context.watch<SessionLiveDirectory?>() != null;
    final history = context.watch<SessionHistoryFactory?>() != null;
    void openMenu() => _menuKey(row.info.ref).currentState?.showButtonMenu();
    return Card(
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                row.info.title.trim().isEmpty
                                    ? l10n.sessionExportUntitled
                                    : row.info.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              // The ownership the adapter proved, and
                              // nothing else: an unproven, stale or expired
                              // proof, and a list that is not the
                              // endpoint's current answer, show unknown.
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  sessionOwnershipLabel(
                                    l10n,
                                    displayedSessionOwnership(
                                      row.info.ownership,
                                      now: controller.now,
                                      current:
                                          !controller.stale &&
                                          !controller.behind,
                                    ),
                                  ),
                                  key: ValueKey(
                                    'session-ownership-${row.info.ref.storageKey}',
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                              if (lineage != null)
                                _lineage(context, row, lineage),
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
                          historyEnabled:
                              !_openingHistory &&
                              !controller.loading &&
                              available,
                          onHistory: live && history
                              ? () {
                                  if (controller.loading || !available) {
                                    return;
                                  }
                                  _openHistory(context, controller, row);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
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
        !catalog.sessions.any((s) => s.info.ref == row.info.ref)) {
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


  /// Opens the session in the workspace, through the same route a link
  /// takes; a compact window closes the list drawer first.
  void _openLive(
    BuildContext context,
    SessionsController catalog,
    SessionSummary row,
  ) {
    final profile = catalog.selectedProfile;
    if (profile == null ||
        !catalog.sessions.any((s) => s.info.ref == row.info.ref)) {
      return;
    }
    Scaffold.maybeOf(context)?.closeDrawer();
    context.go(
      Uri(pathSegments: ['', 's', profile.id, row.info.ref.nativeId]).toString(),
    );
  }
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
