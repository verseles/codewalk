import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../shared/sessions/permission_mode.dart';
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

  /// Whether the new session's allow-everything rule was settled: written,
  /// not wanted, or given up on after [_ruleWait].
  bool _ruled = false;
  Timer? _ruleWait;
  bool _ruleWaitedOut = false;
  bool _ruling = false;
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
    final binding = WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) unawaited(_deliver());
      });
    // A timer or a listener may call this while no frame is coming.
    binding.ensureVisualUpdate();
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
    if (!await _rule(live)) return;
    if (!mounted || identical(_attempted, intent) || !w.owns(intent)) return;
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

  /// A session created here starts ON when the default is ON (ADR-059,
  /// amended for #494): its rule is written before the first prompt, once
  /// the server has said it has none. False while that cannot be decided
  /// yet (rules or policy unread, a read that failed and is tried again, a
  /// read in flight); after a short wait the prompt goes anyway.
  Future<bool> _rule(SessionLiveController live) async {
    if (_ruled) return true;
    // A write in flight holds every other delivery attempt; its end runs
    // the delivery again.
    if (_ruling) return false;
    final policy = live.permissionModes;
    final rules = live.unrestrictedState;
    if (!live.supportsUnrestricted ||
        _ruleWaitedOut ||
        policy == null ||
        (policy.loaded &&
            live.permissionModeState.mode != PermissionMode.allowAll) ||
        rules.inEffect) {
      return _settleRule();
    }
    if (policy.loaded && live.canEnableUnrestricted) {
      _ruling = true;
      try {
        await live.enableUnrestricted();
      } finally {
        _ruling = false;
      }
      _settleRule();
      _changed();
      return false;
    }
    _ruleWait ??= Timer(const Duration(seconds: 3), () {
      _ruleWaitedOut = true;
      _changed();
    });
    return false;
  }

  bool _settleRule() {
    _ruleWait?.cancel();
    _ruled = true;
    return true;
  }

  @override
  void dispose() {
    _ruleWait?.cancel();
    widget.live.removeListener(_changed);
    widget.live.composer.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
