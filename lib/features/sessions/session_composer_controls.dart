import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import 'session_agent_color.dart';
import 'session_selection_chip.dart';
import 'session_selection_host.dart';

/// The composer's one selection control (#484): the model and its variant
/// on the current agent's color, opening the one pick of agent, model,
/// variant and permissions (#485). A sub-conversation keeps its parent's
/// choice, so its chip shows locked.
class SessionModelChip extends StatelessWidget {
  const SessionModelChip({super.key, required this.live});

  final SessionSelectionHost live;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      if (!live.supportsSelection) return const SizedBox.shrink();
      final l10n = context.v2L10n;
      final state = live.selectionState;
      final selection = state.selection;
      final model = offeredSessionModel(state);
      final variant = selection?.modelVariant;
      final busy =
          state.phase == SessionSelectionPhase.pending || state.loading;
      final attention =
          state.phase == SessionSelectionPhase.unconfirmed ||
          state.notice != SessionSelectionNotice.none;
      final picks =
          live.canChangeSelection &&
          canShowSessionSelection(live) &&
          !live.isChild;
      final description = [
        l10n.chatChooseModel,
        if (selection != null) sessionSelectionLabel(state, l10n),
        if (live.isChild) l10n.chatModelLockedSubConversation,
        ?sessionSelectionStatus(state, l10n),
      ].join(': ');
      final modelText = switch (selection?.modelId) {
        final modelId? => catalogLabel(model?.label, modelId),
        null =>
          selection == null
              ? l10n.chatChooseModel
              : state.defaultModel ?? l10n.liveSelectionDefault,
      };
      final background = sessionAgentColor(state.agents, selection?.agentId);
      final foreground = sessionAgentForeground(background);
      final avatar = busy
          ? AppIndeterminateRing(size: 14, strokeWidth: 2, color: foreground)
          : live.isChild
          ? Icon(Symbols.lock_outline, size: 16, color: foreground)
          : attention
          ? Icon(Symbols.info, size: 16, color: foreground)
          : null;
      final style = DefaultTextStyle.of(
        context,
      ).style.copyWith(color: foreground);
      return Semantics(
        label: description,
        button: true,
        enabled: picks,
        child: Tooltip(
          message: description,
          child: ActionChip(
            key: const ValueKey('live-model-chip'),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
            color: WidgetStatePropertyAll(background),
            avatar: avatar,
            label: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: modelText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (variant != null)
                    // Same color as the model, so it keeps the contrast;
                    // the lighter weight sets it apart.
                    TextSpan(text: ' $variant'),
                ],
              ),
              style: style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: picks
                ? () => unawaited(showSessionSelection(context, live))
                : null,
          ),
        ),
      );
    },
  );
}
