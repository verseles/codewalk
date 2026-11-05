import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'apk_update_controller.dart';
import 'linux_update_controller.dart';
import 'release_news_card.dart';
import 'update_check_controller.dart';
import 'updates_settings_page.dart';

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Where to get help: the project on GitHub and its Telegram group.
class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({
    super.key,
    this.open = _openExternally,
    this.onHistory,
  });

  static final githubUri = Uri.parse('https://github.com/verseles/codewalk');
  static final telegramUri = Uri.parse('https://t.me/codewalkapp');

  final Future<bool> Function(Uri) open;
  final VoidCallback? onHistory;

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.v2L10n.chatMessageUnableToOpenLink;
    var opened = false;
    try {
      opened = await open(uri);
    } on Object {
      opened = false;
    }
    if (!opened) showAppSnackBar(messenger, failed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final checks = context.watch<UpdateCheckController?>();
    final install = context.watch<ApkUpdateController?>();
    final linux = context.watch<LinuxUpdateController?>();
    final busy =
        (linux?.busy ?? false) ||
        linux?.status == LinuxUpdateStatus.ready ||
        (install != null &&
            install.status != ApkUpdateStatus.idle &&
            (install.status != ApkUpdateStatus.failed ||
                install.hasVerifiedPackage));
    final candidate = checks?.visibleCandidate;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const ValueKey('about_settings_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l.settingsAboutTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (checks != null && checks.supported) ...[
              ListTile(
                title: Text(
                  checks.status == UpdateCheckStatus.checking
                      ? l.settingsAboutChecking
                      : l.settingsAboutCheckForUpdates,
                ),
                leading: const Icon(Symbols.system_update_alt),
                onTap: busy || checks.status == UpdateCheckStatus.checking
                    ? null
                    : () => unawaited(checks.check()),
              ),
              if (candidate != null)
                UpdateCandidateCard(
                  target: checks.target!,
                  candidate: candidate,
                  install: install,
                  showInstalled: true,
                  onDismiss: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    if (!await checks.dismissCandidate()) {
                      showAppSnackBar(messenger, l.settingsStorageError);
                    }
                  },
                ),
              if (candidate == null && onHistory != null)
                ReleaseNewsCard(onHistory: onHistory!),
            ],
            if (onHistory != null)
              ListTile(
                title: Text(l.releaseHistoryTitle),
                leading: const Icon(Symbols.history),
                onTap: onHistory,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                l.settingsGroupHelp,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListTile(
              key: const ValueKey('about_github'),
              leading: const Icon(Symbols.code),
              title: Text(l.aboutGitHub),
              subtitle: Text(githubUri.host + githubUri.path),
              trailing: const Icon(Symbols.open_in_new),
              onTap: () => unawaited(_launch(context, githubUri)),
            ),
            ListTile(
              key: const ValueKey('about_telegram'),
              leading: const Icon(Symbols.forum),
              title: Text(l.aboutTelegram),
              subtitle: Text(l.settingsAboutOurGroup),
              trailing: const Icon(Symbols.open_in_new),
              onTap: () => unawaited(_launch(context, telegramUri)),
            ),
          ],
        ),
      ),
    );
  }
}
