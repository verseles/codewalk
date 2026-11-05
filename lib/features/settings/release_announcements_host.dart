import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'apk_update_controller.dart';
import 'linux_update_controller.dart';
import 'release_announcements_controller.dart';

class ReleaseAnnouncementsHost extends StatefulWidget {
  const ReleaseAnnouncementsHost({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;

  @override
  State<ReleaseAnnouncementsHost> createState() =>
      _ReleaseAnnouncementsHostState();
}

class _ReleaseAnnouncementsHostState extends State<ReleaseAnnouncementsHost>
    with WidgetsBindingObserver {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReleaseAnnouncementsController?>();
    final install = context.watch<ApkUpdateController?>();
    final linux = context.watch<LinuxUpdateController?>();
    if (!_showing &&
        widget.enabled &&
        controller != null &&
        (linux == null ||
            (!linux.busy && linux.status != LinuxUpdateStatus.ready)) &&
        (install == null || !install.blocksNotices)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _present(controller));
    }
    return widget.child;
  }

  Future<void> _present(ReleaseAnnouncementsController controller) async {
    if (!mounted ||
        _showing ||
        !widget.enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final install = context.read<ApkUpdateController?>();
    final linux = context.read<LinuxUpdateController?>();
    if (linux != null &&
        (linux.busy || linux.status == LinuxUpdateStatus.ready)) {
      return;
    }
    if (install?.blocksNotices == true) return;
    final entries = controller.pendingAnnouncements;
    final key = controller.pendingKey;
    if (entries == null ||
        key == null ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _showing = true;
    controller.markPresented(key);
    if (entries.isEmpty) {
      await controller.acknowledge(key);
      _showing = false;
      return;
    }
    final l = context.v2L10n;
    var remember = true;
    final acknowledge = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l.releaseAnnouncementsTitle),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries) ...[
                    Text(entry.tag, textDirection: TextDirection.ltr),
                    SelectableText(entry.announcement!),
                    const SizedBox(height: 16),
                  ],
                  CheckboxListTile(
                    value: remember,
                    onChanged: (value) =>
                        update(() => remember = value ?? false),
                    title: Text(l.releaseAnnouncementsDoNotShowAgain),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(remember),
              child: Text(l.chatClose),
            ),
          ],
        ),
      ),
    );
    if (acknowledge == true) {
      final saved = await controller.acknowledge(key);
      if (!saved && mounted) {
        showAppSnackBar(
          ScaffoldMessenger.maybeOf(context),
          l.settingsStorageError,
        );
      }
    }
    _showing = false;
    controller.presentationClosed();
  }
}
