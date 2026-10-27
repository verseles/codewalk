import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_selection.dart';
import 'session_live_controller.dart';
import 'session_selection_chip.dart';

/// The composer's selection chips, like the retained reference's controls
/// row (#153): the agent, with the count of permissions waiting for the
/// user, the model and its variant, then [trailing]. A sub-conversation keeps
/// its parent's choice: its model shows locked and it has no agent to pick.
class SessionComposerControls extends StatelessWidget {
  const SessionComposerControls({
    super.key,
    required this.live,
    this.trailing = const [],
  });

  final SessionLiveController live;

  /// More controls on the same row, after the selection.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      final selects = live.supportsSelection;
      final agentMenu =
          !live.isChild && (selects || live.permissionModes != null);
      if (!selects && !agentMenu && trailing.isEmpty) {
        return const SizedBox.shrink();
      }
      final l10n = context.v2L10n;
      final state = live.selectionState;
      final selection = state.selection;
      final compact = MediaQuery.sizeOf(context).width < 600;
      final model = offeredSessionModel(state);
      final variant = selection?.modelVariant;
      final pending = (live.state?.interactions ?? const [])
          .where((i) => i.kind.known == InteractionKind.permission)
          .length;
      final busy =
          state.phase == SessionSelectionPhase.pending || state.loading;
      final attention =
          state.phase == SessionSelectionPhase.unconfirmed ||
          state.notice != SessionSelectionNotice.none;
      final picks = live.canChangeSelection && canShowSessionSelection(live);
      Widget chip(
        String key,
        String label, {
        required String tooltip,
        required VoidCallback? onPressed,
        Widget? avatar,
        double maxWidth = 200,
      }) => Tooltip(
        message: tooltip,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 160 : maxWidth),
          child: ActionChip(
            key: ValueKey(key),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
            avatar: avatar,
            label: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: onPressed,
          ),
        ),
      );
      final agentId = selection?.agentId;
      final agent = state.agents.where((a) => a.id == agentId).firstOrNull;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        // A row that wraps rather than scrolls, so no control hides past the
        // edge of a phone.
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (agentMenu)
              Builder(
                builder: (anchor) => Badge.count(
                  key: const ValueKey('live-agent-badge'),
                  isLabelVisible: pending > 0,
                  count: min(pending, 99),
                  child: chip(
                    'live-agent-chip',
                    agentId == null
                        ? l10n.chatChooseAgent
                        : catalogLabel(agent?.label, agentId),
                    tooltip: l10n.modelChooseAgent,
                    onPressed: () => showAgentMenu(anchor, live),
                  ),
                ),
              ),
            if (selects)
              chip(
                'live-model-chip',
                switch (selection?.modelId) {
                  final modelId? => catalogLabel(model?.label, modelId),
                  null => l10n.chatChooseModel,
                },
                tooltip: live.isChild
                    ? l10n.chatModelLockedSubConversation
                    : l10n.chatChooseModel,
                maxWidth: 240,
                avatar: busy
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : live.isChild
                    ? const Icon(Icons.lock_outline, size: 16)
                    : attention
                    ? const Icon(Icons.info_outline, size: 16)
                    : null,
                onPressed: picks && !live.isChild
                    ? () => unawaited(showSessionSelection(context, live))
                    : null,
              ),
            if (selects &&
                (variant != null || (model?.variants.isNotEmpty ?? false)))
              Builder(
                builder: (anchor) => chip(
                  'live-variant-chip',
                  variant ?? l10n.liveSelectionDefault,
                  tooltip: l10n.shortcutNextVariant,
                  maxWidth: 180,
                  onPressed:
                      picks &&
                          !live.isChild &&
                          (model?.variants.isNotEmpty ?? false)
                      ? () => unawaited(_pickVariant(anchor, live, model!))
                      : null,
                ),
              ),
            ...trailing,
          ],
        ),
      );
    },
  );
}

/// The variant menu under the variant chip: the model's own variants, and
/// the server's default.
Future<void> _pickVariant(
  BuildContext anchor,
  SessionLiveController live,
  ModelEntry model,
) async {
  final l10n = anchor.v2L10n;
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  final current = live.selectionState.selection?.modelVariant;
  const none = '';
  final picked = await showMenu<String>(
    context: anchor,
    position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
    items: [
      for (final variant in [none, ...model.variants])
        CheckedPopupMenuItem<String>(
          key: ValueKey(
            'live-variant-${variant.isEmpty ? 'default' : variant}',
          ),
          value: variant,
          checked: (current ?? none) == variant,
          child: Text(variant.isEmpty ? l10n.liveSelectionDefault : variant),
        ),
    ],
  );
  if (picked == null || picked == (current ?? none) || !anchor.mounted) return;
  await live.selectModel(model, variant: picked.isEmpty ? null : picked);
  if (anchor.mounted) announceSessionSelection(anchor, live);
}

/// The agent menu, opening upward from the agent chip like the retained
/// reference's: the agents, in a list that scrolls, over a fixed footer
/// whose switch auto-approves this session's permission requests (Allow
/// all) or asks for each (Ask). The switch keeps the menu open.
Future<void> showAgentMenu(
  BuildContext anchor,
  SessionLiveController live,
) async {
  if (live.supportsSelection) unawaited(live.refreshSelection());
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final top = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = top & box.size;
  const margin = 8.0;
  final width = min(260.0, overlay.size.width - margin * 2);
  final directionality = Directionality.of(anchor);
  final start =
      (directionality == TextDirection.rtl ? rect.right - width : rect.left)
          .clamp(margin, max(margin, overlay.size.width - width - margin))
          .toDouble();
  final bottom = overlay.size.height - rect.top + 4;
  final maxHeight = max(120.0, rect.top - margin * 2);
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
          bottom: bottom,
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

  final SessionLiveController live;

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
                      leading: const Icon(Icons.info_outline),
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
                            ? const Icon(Icons.check, size: 18)
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
                on
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
    ScaffoldMessenger.maybeOf(anchor)?.showSnackBar(
      SnackBar(content: Text(anchor.v2L10n.livePermissionModeFailed)),
    );
  }
}
