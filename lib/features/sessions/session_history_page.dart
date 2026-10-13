import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_history_source.dart';
import 'session_history_controller.dart';

class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key, required this.controller});
  final SessionHistoryController controller;
  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
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
                  LinearProgressIndicator(semanticsLabel: l10n.sessionsLoading),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: c.items.length + 2,
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
                            if (c.loaded && c.items.isEmpty && failure == null)
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
                      if (index == c.items.length + 1) {
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
                      final item = c.items[index - 1];
                      final (label, text, icon) = switch (item) {
                        UserInput() => (
                          l10n.chatMessageYou,
                          item.text,
                          Icons.person_outline,
                        ),
                        AssistantText() => (
                          l10n.historyAssistant,
                          item.text,
                          Icons.chat_bubble_outline,
                        ),
                        Reasoning() => (
                          l10n.chatMessageThinkingProcess,
                          item.text,
                          Icons.psychology_outlined,
                        ),
                        Notice() => (
                          l10n.historyDetails,
                          item.text,
                          Icons.info_outline,
                        ),
                        ToolCall() => (
                          l10n.historyDetails,
                          item.rawName,
                          Icons.build_outlined,
                        ),
                        _ => (
                          l10n.historyDetails,
                          l10n.chatMessageMessagePartUnavailable,
                          Icons.info_outline,
                        ),
                      };
                      return Card(
                        key: ValueKey(item.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(icon),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                String.fromCharCodes(text.runes.take(2000)),
                                maxLines: 16,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
