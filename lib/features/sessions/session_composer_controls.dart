import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'session_agent_color.dart';
import 'session_selection_chip.dart';
import 'session_selection_host.dart';

/// The composer's one selection control (#484): the model and its variant
/// on the current agent's color, opening the pick of agent, model and
/// variant. Its badge counts the session's pending permission requests. A
/// sub-conversation keeps its parent's choice, so its chip shows locked.
class SessionModelChip extends StatelessWidget {
  const SessionModelChip({super.key, required this.live, this.agentAnchor});

  final SessionSelectionHost live;

  /// Marks the chip, so a `/agent` command opens its menu there.
  final GlobalKey? agentAnchor;

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
      final pending = live.pendingPermissions;
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
      return Builder(
        key: agentAnchor,
        builder: (anchor) => Semantics(
          label: description,
          button: true,
          enabled: picks,
          excludeSemantics: true,
          child: Tooltip(
            message: description,
            child: Badge.count(
              key: const ValueKey('live-permission-badge'),
              isLabelVisible: pending > 0,
              count: min(pending, 99),
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
                        TextSpan(
                          text: ' $variant',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.78),
                          ),
                        ),
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
          ),
        ),
      );
    },
  );
}

/// The agent menu, opening upward from the agent chip like the retained
/// reference's: the agents, in a list that scrolls, over a fixed footer
/// whose switch auto-approves this session's permission requests (Allow
/// all) or asks for each (Ask). The switch keeps the menu open.
Future<void> showAgentMenu(
  BuildContext anchor,
  SessionSelectionHost live,
) async {
  if (live.supportsSelection) unawaited(live.refreshSelection());
  final box = anchor.findRenderObject()! as RenderBox;
  final rootOverlay = Overlay.of(anchor, rootOverlay: true);
  final overlay = rootOverlay.context.findRenderObject()! as RenderBox;
  final top = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = top & box.size;
  const margin = 8.0;
  // Scaffold removes the keyboard inset from its body after consuming it.
  // The root dialog needs the full viewport's inset instead.
  final media = MediaQuery.of(rootOverlay.context);
  final width = min(
    media.textScaler.scale(260),
    overlay.size.width - margin * 2,
  );
  final directionality = Directionality.of(anchor);
  final start =
      (directionality == TextDirection.rtl ? rect.right - width : rect.left)
          .clamp(margin, max(margin, overlay.size.width - width - margin))
          .toDouble();
  final safeTop = media.padding.top + margin;
  final safeBottom =
      overlay.size.height -
      max(media.padding.bottom, media.viewInsets.bottom) -
      margin;
  final available = max(0.0, safeBottom - safeTop);
  final above = (rect.top - 4 - safeTop).clamp(0.0, available);
  final below = (safeBottom - rect.bottom - 4).clamp(0.0, available);
  // Keep the menu above the chip when it fits. Short keyboard-reduced
  // windows can instead use the space below or the whole safe viewport.
  final preferredHeight = media.textScaler.scale(120);
  final opensAbove = above >= preferredHeight;
  final opensBelow = !opensAbove && below >= preferredHeight;
  final maxHeight = opensAbove
      ? above
      : opensBelow
      ? below
      : available;
  final agent = await showGeneralDialog<CatalogEntry>(
    context: anchor,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, _) => Stack(
      children: [
        Positioned(
          left: start,
          width: width,
          top: opensAbove
              ? null
              : opensBelow
              ? rect.bottom + 4
              : safeTop,
          bottom: opensAbove ? overlay.size.height - rect.top + 4 : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              key: const ValueKey('live-agent-menu'),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              elevation: 8,
              child: _AgentMenu(live: live, anchor: anchor),
            ),
          ),
        ),
      ],
    ),
  );
  if (agent == null || !anchor.mounted) return;
  await live.selectAgent(agent);
  if (anchor.mounted) announceSessionSelection(anchor, live);
}

class _AgentMenu extends StatelessWidget {
  const _AgentMenu({required this.live, required this.anchor});

  final SessionSelectionHost live;

  /// Where a failed switch is told: the page under the menu.
  final BuildContext anchor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      final l10n = context.v2L10n;
      final state = live.selectionState;
      final agentId = state.selection?.agentId;
      final enabled = live.canChangeSelection;
      final unrestricted =
          live.supportsUnrestricted && live.unrestrictedState.inEffect;
      final mode = live.permissionModeState.mode;
      final on = unrestricted || mode == PermissionMode.allowAll;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live.supportsSelection)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (state.agentUnavailable case final reason?)
                    ListTile(
                      leading: const Icon(Symbols.info),
                      title: Text(sessionSelectionReason(reason, l10n)),
                    )
                  else
                    for (final agent in state.agents)
                      ListTile(
                        key: ValueKey('live-agent-menu-${agent.id}'),
                        enabled: enabled,
                        selected: agent.id == agentId,
                        title: Text(
                          catalogLabel(agent.label, agent.id),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: agent.id == agentId
                            ? const Icon(Symbols.check, size: 18)
                            : null,
                        onTap: () => Navigator.of(context).pop(agent),
                      ),
                ],
              ),
            ),
          if (live.permissionModes != null) ...[
            if (live.supportsSelection) const Divider(height: 1),
            SwitchListTile(
              key: const ValueKey('live-auto-approve'),
              title: Text(
                !unrestricted && mode == null
                    ? l10n.livePermissionModeUnavailable
                    : on
                    ? l10n.chatPermissionAutoApproveOn
                    : l10n.chatPermissionAutoApproveOff,
              ),
              // The session's allow-everything rule decides while it is in
              // effect; it is turned off from the permission chip.
              subtitle: unrestricted
                  ? Text(l10n.livePermissionModeUnrestricted)
                  : null,
              value: on,
              onChanged:
                  unrestricted ||
                      mode == null ||
                      live.savingPermissionMode ||
                      !live.canChangePermissionMode
                  ? null
                  : (value) => unawaited(_setAutoApprove(value)),
            ),
          ],
        ],
      );
    },
  );

  Future<void> _setAutoApprove(bool value) async {
    final applied = await live.setPermissionMode(
      value ? PermissionMode.allowAll : PermissionMode.ask,
    );
    if (applied || !anchor.mounted) return;
    showAppSnackBar(
      ScaffoldMessenger.maybeOf(anchor),
      anchor.v2L10n.livePermissionModeFailed,
    );
  }
}
