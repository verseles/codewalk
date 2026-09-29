import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/l10n_context.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_indeterminate_progress.dart';
import '../../widgets/direct_provider.dart';

class ReleaseHistoryPage extends StatefulWidget {
  const ReleaseHistoryPage({super.key});

  @override
  State<ReleaseHistoryPage> createState() => _ReleaseHistoryPageState();
}

class _ReleaseHistoryPageState extends State<ReleaseHistoryPage> {
  int _visibleCount = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<SettingsProvider>().loadReleaseHistory());
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.releaseHistoryTitle)),
    body: DirectConsumer<SettingsProvider>(
      builder: (context, settings, _) {
        final history = settings.releaseHistory;
        final entries = history.entries.take(_visibleCount);
        final colors = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              key: const ValueKey('release_history_list'),
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: settings.releaseHistoryLoading
                        ? null
                        : () => settings.loadReleaseHistory(forceRefresh: true),
                    icon: const Icon(Symbols.refresh),
                    label: Text(
                      history.failed
                          ? context.l10n.chatRetry
                          : context.l10n.chatRefresh,
                    ),
                  ),
                ),
                if (settings.releaseHistoryLoading) const AppIndeterminateBar(),
                if (history.failed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      history.entries.isEmpty
                          ? context.l10n.releaseHistoryLoadError
                          : context.l10n.releaseHistoryStale,
                    ),
                  ),
                if (settings.releaseHistoryCoverageMissing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.l10n.releaseHistoryIncomplete),
                  ),
                if (!settings.releaseHistoryLoading &&
                    !history.failed &&
                    history.entries.isEmpty)
                  Text(context.l10n.releaseHistoryEmpty),
                for (final entry in entries)
                  Card(
                    key: ValueKey('release_history_${entry.version}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'v${entry.version}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            entry.date,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (entry.announcement case final announcement?) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SelectableText(
                                announcement,
                                style: TextStyle(
                                  color: colors.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ],
                          if (entry.notes.isNotEmpty)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(context.l10n.settingsAboutChangelog),
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: SelectableText(entry.notes),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (history.entries.length > _visibleCount)
                  TextButton(
                    onPressed: () => setState(() => _visibleCount += 20),
                    child: Text(context.l10n.chatLoadMore),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
