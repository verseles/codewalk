import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import 'release_history_controller.dart';

class ReleaseHistorySettingsPage extends StatefulWidget {
  const ReleaseHistorySettingsPage({super.key});

  @override
  State<ReleaseHistorySettingsPage> createState() =>
      _ReleaseHistorySettingsPageState();
}

class _ReleaseHistorySettingsPageState
    extends State<ReleaseHistorySettingsPage> {
  ReleaseHistoryController? _controller;
  int _visible = 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<ReleaseHistoryController?>();
    if (identical(controller, _controller)) return;
    _controller = controller;
    _visible = 20;
    // Schedule outside build; mounted/generation ownership remains explicit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _controller)) {
        unawaited(controller?.load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReleaseHistoryController?>();
    final l = context.v2L10n;
    final entries = controller?.entries ?? const [];
    return ListView(
      key: const ValueKey('settings_release_history_page'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l.releaseHistoryTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(l.releaseHistoryDescription),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('release_history_refresh'),
            onPressed: controller == null || controller.loading
                ? null
                : () => controller.load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(l.chatRefresh),
          ),
        ),
        if (controller?.loading == true) const LinearProgressIndicator(),
        if (controller == null || controller.failed) ...[
          Text(
            controller?.savedCopyAvailable == true
                ? l.releaseHistoryStale
                : l.releaseHistoryLoadError,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('release_history_retry'),
              onPressed: controller == null || controller.loading
                  ? null
                  : () => controller.load(forceRefresh: true),
              child: Text(l.chatRetry),
            ),
          ),
        ],
        for (final entry in entries.take(_visible))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'v${entry.version}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(entry.date, textDirection: TextDirection.ltr),
                  if (entry.announcement != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        entry.announcement!,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                  if (entry.notes.isNotEmpty)
                    ExpansionTile(
                      key: ValueKey('release_notes_${entry.version}'),
                      tilePadding: EdgeInsets.zero,
                      title: Text(l.releaseHistoryDescription),
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
        if (entries.length > _visible)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('release_history_load_more'),
              onPressed: () => setState(() => _visible += 20),
              child: Text(l.chatLoadMore),
            ),
          ),
      ],
    );
  }
}
