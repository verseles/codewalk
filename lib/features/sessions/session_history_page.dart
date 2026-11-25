import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart'
    show ItemId, resolveTurnTokensPerSecondByAnswer;
import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/markdown_link_opener.dart';
import '../../shared/sessions/session_history_source.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_attachment_scope.dart';
import 'session_history_controller.dart';
import 'session_report_group.dart';
import 'session_timeline_projection.dart';
import 'session_timeline_tile.dart';
import 'session_work_group.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({
    super.key,
    required this.controller,
    this.onTapLink,
  });
  final SessionHistoryController controller;
  final void Function(String text, String href, String? title)? onTapLink;
  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  /// What each row keeps while it is not built, such as an opened tool.
  final _rowState = PageStorageBucket();
  final _presentation = SessionTimelinePresentation();
  final _expandedSubagentCalls = <ItemId>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.refresh();
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, child) {
      final c = widget.controller;
      final l10n = context.v2L10n;
      final failure = switch (c.failure) {
        null => null,
        SessionHistoryFailure.authenticationRequired => l10n.hostsAuthRequired,
        SessionHistoryFailure.sourceChanged => l10n.historySourceChanged,
        SessionHistoryFailure.timeout => l10n.sessionsTimeout,
        SessionHistoryFailure.rateLimited => l10n.sessionsRateLimited,
        SessionHistoryFailure.invalidCursor => l10n.sessionsInvalidCursor,
        _ => l10n.historyUnavailable,
      };
      final rows = _presentation.project(c.items, settled: true);
      final turnTpsByItem = ChatAppearance.showTokensPerSecondOf(context)
          ? resolveTurnTokensPerSecondByAnswer(
              c.items,
              // A later page or an omitted item may still continue it.
              trailingTurnClosed: !c.hasMore && !c.limited,
            )
          : const <ItemId, double>{};
      return Scaffold(
        appBar: AppBar(
          title: Text(
            c.summary.info.title.trim().isEmpty
                ? l10n.sessionExportUntitled
                : c.summary.info.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                if (c.loading)
                  AppIndeterminateBar(semanticsLabel: l10n.sessionsLoading),
                Expanded(
                  child: SessionAttachmentScope(
                    facet: c.attachmentFacet,
                    child: PageStorage(
                      bucket: _rowState,
                      child: ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: timelineSideInset(context),
                        vertical: 16,
                      ),
                      itemCount: rows.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.historyReadOnly,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                c.profile.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(l10n.historyUnverified),
                              if (failure != null) Text(failure),
                              if (c.stale) Text(l10n.sessionsPreviousResults),
                              if (c.limited) Text(l10n.historyLimit),
                              if (c.loaded &&
                                  c.items.isEmpty &&
                                  failure == null)
                                Text(l10n.historyEmpty),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  key: const ValueKey('history-refresh'),
                                  onPressed: c.loading ? null : c.refresh,
                                  child: Text(l10n.chatRefresh),
                                ),
                              ),
                            ],
                          );
                        }
                        if (index == rows.length + 1) {
                          return Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.limited) Text(l10n.historyLimit),
                                TextButton(
                                  key: const ValueKey('history-more'),
                                  onPressed: c.hasMore && !c.loading
                                      ? c.loadMore
                                      : null,
                                  child: Text(l10n.chatLoadMore),
                                ),
                              ],
                            ),
                          );
                        }
                        final row = rows[index - 1];
                        void tapLink(String text, String href, String? title) {
                          final handler = widget.onTapLink;
                          if (handler != null) {
                            handler(text, href, title);
                          } else {
                            unawaited(openExternalMarkdownLink(context, href));
                          }
                        }

                        if (row is SessionSubagentCallsRow) {
                          return SessionSubagentCalls(
                            key: row.key,
                            row: row,
                            expandedAnchors: _expandedSubagentCalls,
                            onTapLink: tapLink,
                          );
                        }
                        if (row is SessionReportRow) {
                          return SessionReportGroup(
                            key: row.key,
                            reports: row.reports,
                            onTapLink: tapLink,
                          );
                        }
                        if (row is SessionActivityStretchRow) {
                          return SessionActivityStretchHeader(
                            key: row.key,
                            row: row,
                            onToggle: () =>
                                setState(() => _presentation.toggle(row.id)),
                          );
                        }
                        final single = row as SessionItemRow;
                        final item = single.item;
                        return SessionTimelineTile(
                          key: ValueKey(item.id),
                          item: item,
                          onTapLink: tapLink,
                          minimizeUnknownShell: true,
                          messageHeader: single.messageHeader,
                          turnTokensPerSecond: turnTpsByItem[item.id],
                        );
                      },
                    ),
                  ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.historySendUnavailable,
                      key: const ValueKey('history-composer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
