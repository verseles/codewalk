import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/apk_update.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/releases/update_selector.dart';
import 'apk_update_controller.dart';
import 'linux_update_controller.dart';
import 'linux_update_panel.dart';
import 'updates_settings_page.dart';

/// App-level presentation: changing routes never hides an active transfer.
class UpdateActivityHost extends StatefulWidget {
  const UpdateActivityHost({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateActivityHost> createState() => _UpdateActivityHostState();
}

class _UpdateActivityHostState extends State<UpdateActivityHost> {
  ApkUpdateStatus? _hiddenStatus;
  String? _hiddenTag;
  LinuxUpdateStatus? _hiddenLinuxStatus;
  String? _hiddenLinuxTag;

  @override
  Widget build(BuildContext context) {
    final install = context.watch<ApkUpdateController?>();
    final candidate = install?.candidate;
    final linux = context.watch<LinuxUpdateController?>();
    final linuxCandidate = linux?.candidate;
    final linuxVisible =
        linux != null &&
        linuxCandidate != null &&
        linux.status != LinuxUpdateStatus.idle &&
        !(_hiddenLinuxStatus == linux.status &&
            _hiddenLinuxTag == linuxCandidate.tag);
    final visible =
        install != null &&
        candidate != null &&
        install.status != ApkUpdateStatus.idle &&
        !(_hiddenStatus == install.status && _hiddenTag == candidate.tag);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (visible || linuxVisible)
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 320,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    key: const ValueKey('global_update_activity'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (visible) ...[
                          IconButton(
                            tooltip: context.v2L10n.chatClose,
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _hiddenStatus = install.status;
                              _hiddenTag = candidate.tag;
                            }),
                          ),
                          UpdateCandidateCard(
                            target: UpdateTarget.androidArm64,
                            candidate: candidate,
                            install: install,
                          ),
                        ],
                        if (linuxVisible)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: context.v2L10n.chatClose,
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() {
                                      _hiddenLinuxStatus = linux.status;
                                      _hiddenLinuxTag = linuxCandidate.tag;
                                    }),
                                  ),
                                  Text(
                                    context.v2L10n.settingsAboutUpdateAvailable(
                                      '${linuxCandidate.version}',
                                    ),
                                  ),
                                  LinuxUpdatePanel(candidate: linuxCandidate),
                                  if (linux.failure ==
                                      LinuxUpdateFailure.unavailable)
                                    SelectableText(
                                      linuxInstallCommand(linuxCandidate),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
