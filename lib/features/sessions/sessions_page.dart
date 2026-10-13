import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_catalog_source.dart';
import '../../shared/sessions/session_history_source.dart';
import 'session_history_controller.dart';
import 'session_history_page.dart';
import 'sessions_controller.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  SessionsController? _controller;
  bool _openingHistory = false;
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
    final notices = <String>[
      if (hosts.storageError) l10n.hostsProfileStorageError,
      if (hosts.loading || controller.loading) l10n.sessionsLoading,
      if (available && hosts.profiles.isEmpty) l10n.serversNoServersFound,
      if (controller.failure != null) _failure(l10n, controller.failure!),
      if (controller.stale) l10n.sessionsPreviousResults,
      if (controller.limited) l10n.sessionsLimit,
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
          itemCount: controller.sessions.length + 2,
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
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonal(
                      key: const ValueKey('sessions-refresh'),
                      onPressed:
                          available &&
                              controller.selectedProfile != null &&
                              !controller.refreshing
                          ? controller.refresh
                          : null,
                      child: Text(l10n.chatRefresh),
                    ),
                  ),
                  if (hosts.storageError)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: hosts.loading ? null : hosts.load,
                        child: Text(l10n.chatRetry),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      key: const ValueKey('sessions-hosts'),
                      onPressed: () => context.go('/hosts'),
                      child: Text(l10n.onboardingConnectRunningServer),
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
            if (index == controller.sessions.length + 1) {
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
            final row = controller.sessions[index - 1];
            final expanded =
                controller.selectedSession?.info.ref == row.info.ref;
            return Card(
              key: ValueKey<SessionRef>(row.info.ref),
              child: InkWell(
                onTap: () => controller.inspect(row.info.ref),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row.info.title.trim().isEmpty
                            ? l10n.sessionExportUntitled
                            : row.info.title,
                        maxLines: expanded ? null : 3,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
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
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
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
