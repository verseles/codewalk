import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/releases/update_selector.dart';
import 'linux_update_controller.dart';
import 'update_failure_text.dart';

class LinuxUpdatePanel extends StatelessWidget {
  const LinuxUpdatePanel({super.key, required this.candidate});
  final UpdateCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LinuxUpdateController?>();
    if (controller == null) return const SizedBox.shrink();
    final l = context.v2L10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.busy) ...[
          LinearProgressIndicator(
            value:
                controller.status == LinuxUpdateStatus.downloading &&
                    controller.progress > 0
                ? controller.progress
                : null,
          ),
          Text(
            controller.status == LinuxUpdateStatus.installing
                ? l.appShellInstallingUpdate
                : controller.status == LinuxUpdateStatus.downloading
                ? '${l.updatesDownload} ${(controller.progress * 100).round()}%'
                : l.updatesVerifying,
          ),
        ],
        if (controller.failure != null)
          Text(
            linuxUpdateFailureText(l, controller.failure!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (controller.status == LinuxUpdateStatus.ready) ...[
          Text(l.settingsAboutUpdateInstalled),
          FilledButton(
            onPressed: () => unawaited(controller.restart()),
            child: Text(l.appShellRestart),
          ),
        ] else if (!controller.busy)
          FilledButton(
            key: const ValueKey('linux_update_install'),
            onPressed: () => unawaited(controller.install(candidate)),
            child: Text(
              controller.status == LinuxUpdateStatus.failed
                  ? l.updatesRetry
                  : l.updatesInstall,
            ),
          ),
      ],
    );
  }
}
