import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'about_settings_page.dart';
import 'update_check_controller.dart';

class ReleaseNewsCard extends StatelessWidget {
  const ReleaseNewsCard({super.key, required this.onHistory});
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final checks = context.watch<UpdateCheckController?>();
    final news = checks?.visibleNews;
    if (news == null) return const SizedBox.shrink();
    final l = context.v2L10n;
    return Card(
      key: const ValueKey('updates_news'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.settingsAboutWhatsNew('${news.version}'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(news.announcement!),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    if (!await checks!.dismissNews()) {
                      showAppSnackBar(messenger, l.settingsStorageError);
                    }
                  },
                  child: Text(l.settingsAboutDismiss),
                ),
                TextButton(
                  onPressed: onHistory,
                  child: Text(l.settingsAboutChangelog),
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
