import 'dart:async';

import 'package:flutter/widgets.dart';

import 'session_live_controller.dart';
import 'workspace_draft_controller.dart';

/// Waits for the exact session's live outbox; never sends from build or after
/// another route has taken over the first-send intent.
class WorkspaceFirstPromptDelivery extends StatefulWidget {
  const WorkspaceFirstPromptDelivery({
    required this.workspace,
    required this.live,
    required this.child,
    super.key,
  });
  final WorkspaceDraftController workspace;
  final SessionLiveController live;
  final Widget child;
  @override
  State<WorkspaceFirstPromptDelivery> createState() => _DeliveryState();
}

class _DeliveryState extends State<WorkspaceFirstPromptDelivery> {
  bool _scheduled = false;
  WorkspaceFirstPrompt? _attempted;
  @override
  void initState() {
    super.initState();
    widget.live.addListener(_changed);
    widget.live.composer.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_deliver());
    });
  }

  Future<void> _deliver() async {
    final w = widget.workspace;
    final live = widget.live;
    final intent = w.firstPromptFor(live.session);
    if (intent == null ||
        identical(_attempted, intent) ||
        !w.owns(intent) ||
        !live.draftSettled ||
        !live.composer.canSend) {
      return;
    }
    _attempted = intent;
    if (live.draft.text.isEmpty) live.draft.text = intent.text;
    if (!w.owns(intent)) return;
    final recorded = await live.composer.send(
      intent.text,
      commandId: intent.commandId,
      isCurrent: () => w.owns(intent),
    );
    if (recorded && !live.disposed && live.draft.text == intent.text) {
      live.draft.clear();
    }
    await w.finishHandoff(intent, recorded: recorded);
  }

  @override
  void dispose() {
    widget.live.removeListener(_changed);
    widget.live.composer.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
