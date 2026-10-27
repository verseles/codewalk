import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/update_selector.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'update_check_controller.dart';

Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Manual update check: Android downloads the exact APK in the browser; Linux
/// shows the installer command for the exact tag. Nothing installs itself.
class UpdatesSettingsPage extends StatefulWidget {
  const UpdatesSettingsPage({super.key, this.open = _openExternally});

  final Future<bool> Function(Uri uri) open;

  @override
  State<UpdatesSettingsPage> createState() => _UpdatesSettingsPageState();
}

class _UpdatesSettingsPageState extends State<UpdatesSettingsPage> {
  UpdateCheckController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<UpdateCheckController?>();
    if (identical(controller, _controller)) return;
    _controller = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(controller, _controller)) {
        unawaited(controller?.restore());
      }
    });
  }

  Future<void> _copy(String command) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.v2L10n.updatesCommandCopied;
    await Clipboard.setData(ClipboardData(text: command));
    showAppSnackBar(messenger, copied);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpdateCheckController?>();
    final l = context.v2L10n;
    final theme = Theme.of(context);
    final children = <Widget>[
      Text(l.settingsGroupVersionUpdates, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(l.updatesDescription),
      const SizedBox(height: 16),
    ];
    if (controller == null || !controller.supported) {
      children.add(
        Text(l.updatesUnsupported, key: const ValueKey('updates_unsupported')),
      );
    } else {
      final checking = controller.status == UpdateCheckStatus.checking;
      final candidate = controller.candidate;
      children.addAll([
        Text(l.updatesChannel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<UpdateChannel>(
          key: const ValueKey('updates_channel'),
          segments: [
            ButtonSegment(
              value: UpdateChannel.stable,
              label: Text(l.updatesChannelStable),
            ),
            ButtonSegment(
              value: UpdateChannel.beta,
              label: Text(l.updatesChannelBeta),
            ),
          ],
          selected: {controller.channel},
          onSelectionChanged: (selection) =>
              unawaited(controller.setChannel(selection.single)),
        ),
        if (controller.channel == UpdateChannel.beta) ...[
          const SizedBox(height: 8),
          Text(l.updatesBetaHint, style: theme.textTheme.bodySmall),
        ],
        if (controller.installedVersion case final version?) ...[
          const SizedBox(height: 16),
          Text('${l.updatesInstalledVersion}: $version'),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const ValueKey('updates_check'),
            onPressed: checking ? null : () => unawaited(controller.check()),
            icon: const Icon(Icons.system_update_alt),
            label: Text(l.settingsAboutCheckForUpdates),
          ),
        ),
        const SizedBox(height: 16),
        if (checking) const LinearProgressIndicator(),
        if (controller.status == UpdateCheckStatus.upToDate)
          Text(l.updatesUpToDate, key: const ValueKey('updates_up_to_date')),
        if (controller.status == UpdateCheckStatus.failed)
          Text(
            l.updatesCheckFailed,
            key: const ValueKey('updates_failed'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (controller.status == UpdateCheckStatus.available &&
            candidate != null)
          _available(context, controller.target!, candidate),
      ]);
    }
    return ListView(
      key: const ValueKey('settings_updates_page'),
      padding: const EdgeInsets.all(24),
      children: children,
    );
  }

  Widget _available(
    BuildContext context,
    UpdateTarget target,
    UpdateCandidate candidate,
  ) {
    final l = context.v2L10n;
    final theme = Theme.of(context);
    final command = linuxInstallCommand(candidate);
    return Card(
      key: const ValueKey('updates_available'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.settingsAboutUpdateAvailable(candidate.version.toString()),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (target == UpdateTarget.androidArm64)
              FilledButton.icon(
                key: const ValueKey('updates_download'),
                onPressed: () => unawaited(widget.open(candidate.assetUrl)),
                icon: const Icon(Icons.download),
                label: Text(l.updatesDownload),
              )
            else ...[
              Text(l.updatesLinuxInstallHint),
              const SizedBox(height: 8),
              SelectableText(
                command,
                key: const ValueKey('updates_linux_command'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('updates_copy_command'),
                onPressed: () => unawaited(_copy(command)),
                icon: const Icon(Icons.copy),
                label: Text(l.updatesCopyCommand),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
