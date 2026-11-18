import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/canonical_message_body.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_timeline_projection.dart';
import 'session_timeline_tile.dart';

/// One quiet summary in the conversation; report bodies are built on demand.
class SessionReportGroup extends StatefulWidget {
  const SessionReportGroup({
    super.key,
    required this.reports,
    this.onOpenChild,
  });

  final List<Notice> reports;
  final ValueChanged<SessionRef>? onOpenChild;

  @override
  State<SessionReportGroup> createState() => _SessionReportGroupState();
}

class _SessionReportGroupState extends State<SessionReportGroup> {
  bool _expanded = false;
  final _open = <ItemId>{};

  @override
  void didUpdateWidget(SessionReportGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports.length == 1 &&
        widget.reports.length > 1 &&
        _open.contains(widget.reports.first.id)) {
      _expanded = true;
    }
  }

  void _toggle(VoidCallback change) {
    SessionTimelineScope.maybeOf(context)?.onReaderToggle();
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final reports = widget.reports;
    final group = reports.length > 1;
    final failures = reports
        .where((n) => n.report!.outcome == OutcomeKind.failed)
        .length;
    return ConversationTextScale(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group)
            _summary(
              context,
              failures == 0
                  ? l10n.reportCount(reports.length)
                  : '${l10n.reportFailures(failures)} · ${l10n.reportCount(reports.length)}',
              failed: failures > 0,
              expanded: _expanded,
              onTap: () => _toggle(() => _expanded = !_expanded),
            ),
          if (!group || _expanded)
            for (final notice in reports)
              Padding(
                key: ValueKey(notice.id),
                padding: EdgeInsetsDirectional.only(start: group ? 16 : 0),
                child: _reply(notice),
              ),
        ],
      ),
    );
  }

  Widget _reply(Notice notice) {
    final l10n = context.v2L10n;
    final report = notice.report!;
    final failed = report.outcome == OutcomeKind.failed;
    final expanded = _open.contains(notice.id);
    final title = report.agent == null
        ? l10n.reportUnnamed
        : l10n.reportBy(report.agent!);
    final status = switch (report.outcome) {
      OutcomeKind.failed => l10n.statusFailed,
      OutcomeKind.interrupted => l10n.liveSubagentsCancelled,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(
          context,
          status == null ? title : '$status · $title',
          expanded: expanded,
          failed: failed,
          onTap: () => _toggle(() {
            if (!_open.remove(notice.id)) _open.add(notice.id);
          }),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.description case final description?)
                  Text(
                    description,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                if (notice.text.isNotEmpty)
                  SelectionArea(
                    child: CanonicalMessageBody(
                      source: notice.text,
                      complete: true,
                      allowBasicHtml: false,
                    ),
                  ),
                if (notice.relatedSession case final child?
                    when widget.onOpenChild != null)
                  TextButton(
                    onPressed: () => widget.onOpenChild!(child),
                    child: Text(l10n.reportOpenChild),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _summary(
  BuildContext context,
  String title, {
  required bool expanded,
  required bool failed,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final color = failed
      ? theme.colorScheme.error
      : theme.colorScheme.onSurfaceVariant;
  return Semantics(
    button: true,
    expanded: expanded,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              failed ? Symbols.error_outline : Symbols.smart_toy,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ),
            Icon(
              expanded ? Symbols.expand_less : Symbols.expand_more,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    ),
  );
}

class SessionSubagentCalls extends StatefulWidget {
  const SessionSubagentCalls({super.key, required this.row, this.onOpenChild});
  final SessionSubagentCallsRow row;
  final ValueChanged<ToolCall>? onOpenChild;

  @override
  State<SessionSubagentCalls> createState() => _SessionSubagentCallsState();
}

class _SessionSubagentCallsState extends State<SessionSubagentCalls> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final calls = widget.row.calls;
    int count(ItemStatus status) =>
        calls.where((call) => call.item.status.known == status).length;
    final failed = count(ItemStatus.failed);
    final running = count(ItemStatus.streaming);
    final queued = count(ItemStatus.pending);
    final title = [
      if (failed > 0) l10n.reportFailures(failed),
      l10n.liveSubagentsTitle,
      if (running != calls.length && queued != calls.length)
        l10n.chatMessageToolChainCallsCompact(calls.length),
      if (running > 0) l10n.chatMessageToolRunningCount(running),
      if (queued > 0) l10n.chatMessageToolQueuedCount(queued),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConversationTextScale(
          child: _summary(
            context,
            title,
            expanded: expanded,
            failed: failed > 0,
            onTap: () {
              SessionTimelineScope.maybeOf(context)?.onReaderToggle();
              setState(() => expanded = !expanded);
            },
          ),
        ),
        if (expanded)
          for (final call in calls)
            SessionTimelineTile(
              key: ValueKey('call-detail-${call.item.id.value}'),
              item: call.item,
              messageHeader: call.messageHeader,
              onOpenChild: widget.onOpenChild,
            ),
      ],
    );
  }
}
