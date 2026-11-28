import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'about_settings_page.dart';
import 'update_check_controller.dart';

/// The news of the installed release, in Settings: seen once, it stays
/// until they close and is gone from the next visit; its X dismisses it at
/// once (#552).
class ReleaseNewsCard extends StatefulWidget {
  const ReleaseNewsCard({super.key, required this.onHistory});
  final VoidCallback onHistory;

  @override
  State<ReleaseNewsCard> createState() => _ReleaseNewsCardState();
}

class _ReleaseNewsCardState extends State<ReleaseNewsCard> {
  @override
  Widget build(BuildContext context) {
    final checks = context.watch<UpdateCheckController?>();
    final news = checks?.visibleNews;
    if (news == null) return const SizedBox.shrink();
    // Shown: the next visit does not show it again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(checks!.newsSeen());
    });
    final l = context.v2L10n;
    return Card(
      key: const ValueKey('updates_news'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l.settingsAboutWhatsNew('${news.version}'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('updates_news_dismiss'),
                  tooltip: l.settingsAboutDismiss,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Symbols.close),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    if (!await checks!.dismissNews()) {
                      showAppSnackBar(messenger, l.settingsStorageError);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: SelectableText(news.announcement!),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: widget.onHistory,
                  child: Text(l.settingsAboutNews),
                ),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    var opened = false;
                    try {
                      opened = await launchUrl(
                        AboutSettingsPage.telegramUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } on Object {
                      // The same localized failure covers unavailable handlers.
                    }
                    if (!opened) {
                      showAppSnackBar(messenger, l.chatMessageUnableToOpenLink);
                    }
                  },
                  child: Text(l.settingsAboutOurGroup),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
