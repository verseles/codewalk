import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_snack_bar.dart';

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Where to get help: the project on GitHub and its Telegram group.
class AboutSettingsPage extends StatelessWidget {
  const AboutSettingsPage({super.key, this.open = _openExternally});

  static final githubUri = Uri.parse('https://github.com/verseles/codewalk');
  static final telegramUri = Uri.parse('https://t.me/codewalkapp');

  final Future<bool> Function(Uri) open;

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
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                l.settingsGroupHelp,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListTile(
              key: const ValueKey('about_github'),
              leading: const Icon(Icons.code),
              title: Text(l.aboutGitHub),
              subtitle: Text(githubUri.host + githubUri.path),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => unawaited(_launch(context, githubUri)),
            ),
            ListTile(
              key: const ValueKey('about_telegram'),
              leading: const Icon(Icons.forum_outlined),
              title: Text(l.aboutTelegram),
              subtitle: Text(l.settingsAboutOurGroup),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => unawaited(_launch(context, telegramUri)),
            ),
          ],
        ),
      ),
    );
  }
}
