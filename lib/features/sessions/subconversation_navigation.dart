import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_live_controller.dart';
import 'session_tab_strip.dart';
import 'sessions_controller.dart';
import 'subconversation_resolver.dart';

/// Whether [live] holds every subagent call of its session, in order: its
/// whole history is in the window, nothing was trimmed and no read is open.
bool subconversationAnchorsComplete(SessionLiveController live) {
  final state = live.state;
  return state != null &&
      !state.hasMoreHistory &&
      !live.olderHistory.loading &&
      !live.olderHistory.trimmed &&
      state.timeline.length < state.limits.maxItems &&
      state.connection.kind.known != ConnectionKind.hydrating;
}

/// Opens the sub-conversation [tool] runs in [live]'s session, or says that
/// none was found and stays. [current] tells whether this tap still leads;
/// any navigation meanwhile wins over it.
Future<void> openSubconversation(
  BuildContext context,
  SessionLiveController live,
  ToolCall tool, {
  required bool Function() current,
}) async {
  final parent = live.session;
  final source = context.read<SessionsController?>()?.sourceFor(parent);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final missing = context.v2L10n.chatNoSubConversationFound;
  final router = GoRouter.of(context);
  final routes = router.routeInformationProvider;
  var moved = false;
  void navigated() => moved = true;
  bool leads() => current() && !moved;
  routes.addListener(navigated);
  SessionRef? child;
  try {
    if (source != null) {
      child = await resolveSubconversation(
        tool: tool,
        parent: parent,
        timeline: live.state?.timeline ?? const [],
        anchorsComplete: subconversationAnchorsComplete(live),
        source: source,
        current: leads,
      );
    }
  } finally {
    routes.removeListener(navigated);
  }
  if (!leads()) return;
  // What the call says now must still allow the choice: a refusal or another
  // child observed meanwhile wins.
  final now = live.state?.timeline
      .whereType<ToolCall>()
      .where((item) => item.id == tool.id)
      .firstOrNull;
  if (child == null ||
      now == null ||
      now.childEvidence?.kind == ToolChildEvidenceKind.rejected ||
      (now.child != null && now.child != child)) {
    if (messenger?.mounted ?? false) {
      messenger!.showSnackBar(SnackBar(content: Text(missing)));
    }
    return;
  }
  router.go(sessionTabLocation(child));
}

/// The way back from a sub-conversation to its immediate parent, one level
/// at a time.
class ReturnToParentConversation extends StatelessWidget {
  const ReturnToParentConversation({super.key, required this.parent});

  final SessionRef parent;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const ValueKey('subconversation-return'),
      icon: const BackButtonIcon(),
      label: Text(context.v2L10n.chatReturnToParentConversation),
      onPressed: () => context.go(sessionTabLocation(parent)),
    ),
  );
}
