import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/releases/release_source.dart';
import '../../shared/releases/update_selector.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'apk_update_controller.dart';
import 'linux_update_controller.dart';
import 'linux_update_panel.dart';
import 'update_check_controller.dart';
import 'update_failure_text.dart';
import 'update_scheduler.dart';

/// Native update controls: Android verifies an in-app APK download before
/// installer handoff; managed Linux bundles install in-app, with an exact-tag
/// command available for older or unmanaged installations.
class UpdatesSettingsPage extends StatefulWidget {
  const UpdatesSettingsPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<UpdateCheckController?>();
    final install = context.watch<ApkUpdateController?>();
    final scheduler = context.watch<UpdateScheduler?>();
    final linux = context.watch<LinuxUpdateController?>();
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
      final installBusy =
          (linux?.busy ?? false) ||
          linux?.status == LinuxUpdateStatus.ready ||
          install != null &&
              (install.status == ApkUpdateStatus.downloading ||
                  install.status == ApkUpdateStatus.verifying ||
                  install.status == ApkUpdateStatus.ready ||
                  install.status == ApkUpdateStatus.handingOff ||
                  install.status == ApkUpdateStatus.installerOpened ||
                  (install.status == ApkUpdateStatus.failed &&
                      install.hasVerifiedPackage));
      children.addAll([
        if (scheduler != null)
          SwitchListTile.adaptive(
            key: const ValueKey('updates_check_on_open'),
            title: Text(l.settingsAboutCheckOnOpen),
            subtitle: Text(l.settingsAboutCheckOnOpenDescription),
            value: scheduler.enabled,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              if (!await scheduler.setEnabled(value)) {
                showAppSnackBar(messenger, l.settingsStorageError);
              }
            },
          ),
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
          onSelectionChanged: installBusy
              ? null
              : (selection) =>
                    unawaited(controller.setChannel(selection.single)),
        ),
        if (controller.channel == UpdateChannel.beta) ...[
          const SizedBox(height: 8),
          Text(l.updatesBetaHint, style: theme.textTheme.bodySmall),
        ],
        if (controller.installedVersion case final version?) ...[
          const SizedBox(height: 16),
          Text(
            '${l.updatesInstalledVersion}: $version${controller.installedBuild == null ? '' : ' (${controller.installedBuild})'}',
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const ValueKey('updates_check'),
            onPressed: checking || installBusy
                ? null
                : () => unawaited(controller.check()),
            icon: const Icon(Symbols.system_update_alt),
            label: Text(
              checking
                  ? l.settingsAboutChecking
                  : l.settingsAboutCheckForUpdates,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (checking) const AppIndeterminateBar(),
        if (controller.status == UpdateCheckStatus.upToDate)
          Text(l.updatesUpToDate, key: const ValueKey('updates_up_to_date')),
        if (controller.status == UpdateCheckStatus.failed)
          Text(
            switch (controller.failure) {
              ReleaseSourceFailure.rateLimited => l.updatesRateLimited,
              ReleaseSourceFailure.invalidResponse => l.updatesCheckUnreadable,
              _ => l.updatesCheckFailed,
            },
            key: const ValueKey('updates_failed'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (controller.status == UpdateCheckStatus.available &&
            candidate != null)
          UpdateCandidateCard(
            target: controller.target!,
            candidate: candidate,
            install: install,
          ),
      ]);
    }
    return ListView(
      key: const ValueKey('settings_updates_page'),
      padding: const EdgeInsets.all(24),
      children: children,
    );
  }
}

class UpdateCandidateCard extends StatelessWidget {
  const UpdateCandidateCard({
    super.key,
    required this.target,
    required this.candidate,
    required this.install,
    this.onDismiss,
    this.showInstalled = false,
  });

  final UpdateTarget target;
  final UpdateCandidate candidate;
  final ApkUpdateController? install;
  final VoidCallback? onDismiss;
  final bool showInstalled;

  Future<void> _copy(BuildContext context, String command) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copied = context.v2L10n.updatesCommandCopied;
    await Clipboard.setData(ClipboardData(text: command));
    showAppSnackBar(messenger, copied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.v2L10n;
    final checks = context.watch<UpdateCheckController?>();
    final linux = context.watch<LinuxUpdateController?>();
    final activeAndroid =
        target == UpdateTarget.androidArm64 &&
        install != null &&
        install!.status != ApkUpdateStatus.idle;
    final activeLinux =
        target != UpdateTarget.androidArm64 &&
        linux != null &&
        (linux.busy || linux.status == LinuxUpdateStatus.ready);
    final displayed = activeAndroid
        ? install!.candidate ?? candidate
        : activeLinux
        ? linux.candidate ?? candidate
        : candidate;
    final theme = Theme.of(context);
    final command = linuxInstallCommand(displayed);
    return Card(
      key: const ValueKey('updates_available'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.settingsAboutUpdateAvailable(displayed.version.toString()),
              style: theme.textTheme.titleMedium,
            ),
            if (showInstalled && checks?.installedVersion != null)
              Text(
                '${l.updatesInstalledVersion}: ${checks!.installedVersion}${checks.installedBuild == null ? '' : ' (${checks.installedBuild})'}',
              ),
            if (onDismiss != null && !activeAndroid && !activeLinux)
              TextButton(
                onPressed: onDismiss,
                child: Text(l.settingsAboutDismiss),
              ),
            const SizedBox(height: 12),
            if (target == UpdateTarget.androidArm64)
              _androidInstall(context, displayed, install)
            else ...[
              LinuxUpdatePanel(candidate: displayed),
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
                onPressed: () => unawaited(_copy(context, command)),
                icon: const Icon(Symbols.content_copy),
                label: Text(l.updatesCopyCommand),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _androidInstall(
    BuildContext context,
    UpdateCandidate candidate,
    ApkUpdateController? install,
  ) {
    final l = context.v2L10n;
    final theme = Theme.of(context);
    if (install == null) {
      return Text(l.updatesUnsupported);
    }
    switch (install.status) {
      case ApkUpdateStatus.idle:
        final verified = install.hasVerifiedCandidate(candidate);
        return FilledButton.icon(
          key: ValueKey(verified ? 'updates_install' : 'updates_download'),
          onPressed: () => unawaited(install.start(candidate)),
          icon: Icon(verified ? Symbols.install_mobile : Symbols.download),
          label: Text(verified ? l.updatesInstall : l.updatesDownload),
        );
      case ApkUpdateStatus.downloading:
        final percent = (install.progress * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              key: const ValueKey('updates_progress'),
              value: install.progress > 0 ? install.progress : null,
            ),
            const SizedBox(height: 8),
            Text(install.progress > 0 ? '$percent%' : l.updatesDownload),
            TextButton(
              key: const ValueKey('updates_cancel'),
              onPressed: () => unawaited(install.cancel()),
              child: Text(l.commonCancel),
            ),
          ],
        );
      case ApkUpdateStatus.verifying:
      case ApkUpdateStatus.handingOff:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: AppIndeterminateRing(size: 16, strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l.updatesVerifying),
          ],
        );
      case ApkUpdateStatus.ready:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('updates_install'),
              onPressed: () => unawaited(install.openInstaller()),
              icon: const Icon(Symbols.install_mobile),
              label: Text(l.updatesInstall),
            ),
            TextButton(
              key: const ValueKey('updates_cancel'),
              onPressed: () => unawaited(install.cancel()),
              child: Text(l.commonCancel),
            ),
          ],
        );
      case ApkUpdateStatus.installerOpened:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.updatesInstallerOpened,
              key: const ValueKey('updates_installer_opened'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('updates_install'),
              onPressed: () => unawaited(install.openInstaller()),
              child: Text(l.updatesInstall),
            ),
            TextButton(
              key: const ValueKey('updates_dismiss_install'),
              onPressed: install.dismiss,
              child: Text(l.settingsAboutDismiss),
            ),
          ],
        );
      case ApkUpdateStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              apkUpdateFailureText(l, install.failure),
              key: const ValueKey('updates_error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('updates_retry'),
              onPressed: () => unawaited(install.retry()),
              child: Text(
                install.progress > 0 &&
                        (install.failure == ApkUpdateFailure.network ||
                            install.failure == ApkUpdateFailure.timeout)
                    ? l.updatesResume
                    : l.updatesRetry,
              ),
            ),
            if (install.hasVerifiedPackage)
              TextButton(
                key: const ValueKey('updates_dismiss_install'),
                onPressed: install.dismiss,
                child: Text(l.settingsAboutDismiss),
              ),
          ],
        );
    }
  }
}
