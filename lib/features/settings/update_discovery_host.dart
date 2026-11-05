import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/releases/linux_update.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'apk_update_controller.dart';
import 'linux_update_controller.dart';
import 'release_announcements_controller.dart';
import 'update_check_controller.dart';

class UpdateDiscoveryHost extends StatefulWidget {
  const UpdateDiscoveryHost({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;
  @override
  State<UpdateDiscoveryHost> createState() => _UpdateDiscoveryHostState();
}

class _UpdateDiscoveryHostState extends State<UpdateDiscoveryHost>
    with WidgetsBindingObserver {
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final checks = context.watch<UpdateCheckController?>();
    context.watch<ReleaseAnnouncementsController?>();
    context.watch<ApkUpdateController?>();
    context.watch<LinuxUpdateController?>();
    if (!_scheduled &&
        widget.enabled &&
        checks != null &&
        (checks.automaticUpdateNotice != null ||
            checks.automaticNewsNotice != null)) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _present();
      });
    }
    return widget.child;
  }

  void _present() {
    if (!widget.enabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final apk = context.read<ApkUpdateController?>();
    final linux = context.read<LinuxUpdateController?>();
    final announcements = context.read<ReleaseAnnouncementsController?>();
    if (announcements != null && !announcements.initialized) return;
    if (apk?.blocksNotices == true ||
        (linux != null &&
            (linux.busy || linux.status == LinuxUpdateStatus.ready)) ||
        announcements?.pendingAnnouncements?.isNotEmpty == true) {
      return;
    }
    final checks = context.read<UpdateCheckController?>();
    final update = checks?.automaticUpdateNotice;
    var news = checks?.automaticNewsNotice;
    if (news != null &&
        announcements != null &&
        !announcements.shouldNotifyNews(news.tag)) {
      checks!.markNoticePresented(news.tag, news: true);
      news = null;
    }
    if (update == null && news == null) return;
    final l = context.v2L10n;
    final shown = showAppSnackBar(
      ScaffoldMessenger.maybeOf(context),
      update != null
          ? l.settingsAboutUpdateAvailable('${update.version}')
          : '${l.settingsAboutWhatsNew('${news!.version}')}\n${news.announcement}',
      maxLines: 3,
      action: SnackBarAction(
        label: l.settingsTitle,
        onPressed: () => context.push('/settings'),
      ),
    );
    if (shown != null) {
      checks!.markNoticePresented(
        update?.tag ?? news!.tag,
        news: update == null,
      );
    }
  }
}
