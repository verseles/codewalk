import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/sessions/session_live_source.dart';
import 'session_actions_menu.dart';
import 'session_grouping.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'session_live_controller.dart';
import 'session_live_page.dart';
import 'session_ownership.dart';
import 'sessions_controller.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  SessionsController? _controller;
  bool _openingHistory = false;
  bool _openingLive = false;

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
    // to; the groups follow the rows the server returned.
    final items = sessionListItems(controller.sessions);
    final notices = <String>[
      if (hosts.storageError) l10n.hostsProfileStorageError,
      if (hosts.loading || controller.loading) l10n.sessionsLoading,
      if (available && hosts.profiles.isEmpty) l10n.serversNoServersFound,
      if (controller.failure != null) _failure(l10n, controller.failure!),
      if (controller.stale) l10n.sessionsPreviousResults,
      if (controller.behind) l10n.liveStale,
      if (controller.limited) l10n.sessionsLimit,
      if (controller.actionFailure != null) l10n.sessionsActionFailed,
      if (controller.hideUnreadable) l10n.sessionsActionUnavailableStore,
      if (controller.actionUncertain) l10n.sessionsActionPending,
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
                  Text(
                    l10n.chatConversations,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  if (hosts.loading || controller.loading)
                    LinearProgressIndicator(
                      semanticsLabel: l10n.sessionsLoading,
                    ),
                  DropdownButton<String>(
                    key: const ValueKey('sessions-profile'),
                    isExpanded: true,
                    value:
                        hosts.profiles.any(
                          (p) => p.id == controller.selectedProfile?.id,
                        )
                        ? controller.selectedProfile?.id
                        : null,
                    hint: Text(
                      l10n.sessionsSelectProfile,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    itemHeight: null,
                    items: [
                      for (final profile in hosts.profiles)
                        DropdownMenuItem(
                          value: profile.id,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              profile.label,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: available
                        ? (id) {
                            if (id != null) controller.selectProfile(id);
                          }
                        : null,
                  ),
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
                            Text(_filterLabel(l10n, controller.filter)),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
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
                      TextButton(
                        key: const ValueKey('sessions-hosts'),
                        onPressed: () => context.go('/hosts'),
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
              SessionGroupHeader(:final group) => _groupHeader(context, group),
              SessionRow(:final session) => _row(
                context,
                controller,
                available,
                session,
              ),
            };
          },
        ),
      ),
    );
  }

  /// The header of one project group: the directory the server reported, with
  /// its last segment as the title. The path is always left-to-right, so the
  /// separators do not reorder in a right-to-left locale.
  Widget _groupHeader(BuildContext context, SessionGroup group) {
    final l10n = context.v2L10n;
    final directory = group.project?.canonicalDirectory;
    if (directory == null) {
      return Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            l10n.sessionsUnknownProject,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      );
    }
    final segments = directory
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty);
    final title = segments.isEmpty ? directory : segments.last;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              directory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// The label of the filter that shows which sessions the list holds.
  String _filterLabel(V2Localizations l10n, SessionActionFilter filter) =>
      switch (filter) {
        SessionActionFilter.active => l10n.sessionsFilterActive,
        SessionActionFilter.hidden => l10n.sessionsFilterHidden,
        SessionActionFilter.all => l10n.sessionsFilterAll,
      };

  /// The endpoint's own unread marker: the session went idle and that
  /// transition was not seen yet.
  Widget _unreadMark(BuildContext context, SessionSummary row) {
    final l10n = context.v2L10n;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            l10n.sessionsActionUnread,
            key: ValueKey('session-unread-${row.info.ref.storageKey}'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SessionsController controller,
    bool available,
    SessionSummary row,
  ) {
    final l10n = context.v2L10n;
    final expanded = controller.selectedSession?.info.ref == row.info.ref;
    void openMenu() => _menuKey(row.info.ref).currentState?.showButtonMenu();
    return Card(
              key: ValueKey<SessionRef>(row.info.ref),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (_) => openMenu(),
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(
                      LogicalKeyboardKey.contextMenu,
                    ): openMenu,
                    const SingleActivator(
                      LogicalKeyboardKey.f10,
                      shift: true,
                    ): openMenu,
                  },
                  child: Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(
                        label: l10n.sessionsActionsMenu,
                      ): openMenu,
                    },
                    child: InkWell(
                onTap: () => controller.inspect(row.info.ref),
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
                                  maxLines: expanded ? null : 3,
                                  overflow: expanded
                                      ? null
                                      : TextOverflow.ellipsis,
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
                                        current: !controller.stale &&
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
                                if (controller.viewState(row) ==
                                    SessionViewState.unread)
                                  _unreadMark(context, row),
                              ],
                            ),
                          ),
                          SessionActionsMenu(
                            controller: controller,
                            row: row,
                            menuKey: _menuKey(row.info.ref),
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        if (row.updatedAt case final date?)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_date(context, date)),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          context.watch<SessionHistoryFactory?>() == null
                              ? l10n.sessionsHistoryUnavailable
                              : l10n.historyReadOnly,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            key: ValueKey(
                              'history-open-${row.info.ref.storageKey}',
                            ),
                            onPressed:
                                _openingHistory ||
                                    controller.loading ||
                                    !available ||
                                    context.watch<SessionHistoryFactory?>() ==
                                        null
                                ? null
                                : () => _openHistory(context, controller, row),
                            child: Text(l10n.historyOpen),
                          ),
                        ),
                        if (context.watch<SessionLiveDirectory?>() != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              key: ValueKey(
                                'live-open-${row.info.ref.storageKey}',
                              ),
                              onPressed:
                                  _openingLive ||
                                      controller.loading ||
                                      !available
                                  ? null
                                  : () => _openLive(context, controller, row),
                              child: Text(l10n.liveOpen),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
                    ),
                  ),
                ),
            );
  }

  String _date(BuildContext context, DateTime date) {
    final local = date.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
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

  EditablePermissionModePolicy? _permissionPolicy(BuildContext context) {
    try {
      return context.read<EditablePermissionModePolicy>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _openLive(
    BuildContext context,
    SessionsController catalog,
    SessionSummary row,
  ) async {
    final profile = catalog.selectedProfile;
    final directory = context.read<SessionLiveDirectory?>();
    if (_openingLive ||
        profile == null ||
        directory == null ||
        !catalog.sessions.any((s) => s.info.ref == row.info.ref)) {
      return;
    }
    setState(() => _openingLive = true);
    final live = SessionLiveController(
      hosts: catalog.hosts,
      profile: profile,
      summary: row,
      directory: directory,
      permissionModes: _permissionPolicy(context),
    );
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => SessionLivePage(controller: live)),
      );
    } finally {
      live.dispose();
      if (mounted) setState(() => _openingLive = false);
    }
  }

  String _failure(V2Localizations l10n, SessionCatalogFailure failure) =>
      switch (failure) {
        SessionCatalogFailure.authenticationRequired => l10n.hostsAuthRequired,
        SessionCatalogFailure.unsupportedPlatform => l10n.sessionsUnavailable,
        SessionCatalogFailure.timeout => l10n.sessionsTimeout,
        SessionCatalogFailure.invalidCursor => l10n.sessionsInvalidCursor,
        SessionCatalogFailure.rateLimited => l10n.sessionsRateLimited,
        SessionCatalogFailure.unavailable ||
        SessionCatalogFailure.incompatibleResponse ||
        SessionCatalogFailure.cancelled ||
        SessionCatalogFailure.connection => l10n.sessionsReadFailed,
      };
}
