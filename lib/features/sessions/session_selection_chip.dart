import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_selection.dart';
import 'session_live_controller.dart';

/// The live session's model and agent (V2-054A). The label is the server's
/// selection, or a switch it accepted and has not reported yet; a missing
/// half is the server's default. A pick sends one switch, and the composer
/// holds this session's sends until it settles.
class SessionSelectionChip extends StatelessWidget {
  const SessionSelectionChip({super.key, required this.live, this.compact});

  final SessionLiveController live;

  /// Icon-only; by default below 600 dp of window width.
  final bool? compact;

  @override
  Widget build(BuildContext context) {
    if (!live.supportsSelection) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final l10n = context.v2L10n;
        final state = live.selectionState;
        final narrow = compact ?? MediaQuery.sizeOf(context).width < 600;
        final label = sessionSelectionLabel(state, l10n);
        final semantics = [
          l10n.liveSelection,
          if (state.selection != null) label,
          if (live.isChild) l10n.chatModelLockedSubConversation,
          ?_status(state, l10n),
        ].join(': ');
        final busy =
            state.phase == SessionSelectionPhase.pending || state.loading;
        final enabled = live.canChangeSelection && _openable(state);
        final attention =
            state.phase == SessionSelectionPhase.unconfirmed ||
            state.notice != SessionSelectionNotice.none;
        return Semantics(
          button: true,
          enabled: enabled,
          label: semantics,
          child: ActionChip(
            key: const ValueKey('live-selection'),
            tooltip: semantics,
            onPressed: enabled
                ? () => showSessionSelection(context, live)
                : null,
            avatar: busy
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    live.isChild
                        ? Icons.lock_outline
                        : attention
                        ? Icons.info_outline
                        : Icons.tune,
                  ),
            // On compact widths the AppBar has no room for the label; the
            // icon plus the tooltip and semantics carry it.
            label: narrow
                ? const SizedBox.shrink()
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  /// Nothing can be picked when neither list can be read for a reason a
  /// retry would not change.
  static bool _openable(SessionSelectionState state) {
    bool closed(SessionSelectionUnavailable? reason) =>
        reason != null &&
        reason != SessionSelectionUnavailable.serviceUnavailable;
    return state.phase == SessionSelectionPhase.unconfirmed ||
        !closed(state.modelUnavailable) ||
        !closed(state.agentUnavailable);
  }

  static String? _status(SessionSelectionState state, V2Localizations l10n) {
    if (state.phase == SessionSelectionPhase.pending) {
      return l10n.liveSelectionPending;
    }
    if (state.phase == SessionSelectionPhase.unconfirmed) {
      return l10n.liveSelectionUnconfirmed;
    }
    if (_notice(state.notice, l10n) case final notice?) return notice;
    if (state.loading) return l10n.liveSelectionLoading;
    // A half that can still be picked is no reason to report; the pick
    // explains each half on its own.
    final model = state.modelUnavailable;
    if (model == null || state.agentUnavailable == null) return null;
    return sessionSelectionReason(model, l10n);
  }
}

/// `model#variant · agent`, by catalog label when the catalog names them.
String sessionSelectionLabel(
  SessionSelectionState state,
  V2Localizations l10n,
) {
  final selection = state.selection;
  // Before the session is read nothing is known, not even the default.
  if (selection == null) return l10n.liveSelection;
  final modelId = selection.modelId;
  final agentId = selection.agentId;
  if (modelId == null && agentId == null) return l10n.liveSelectionDefault;
  final model = _offeredModel(state, selection);
  final agent = state.agents.where((a) => a.id == agentId).firstOrNull;
  final modelText = modelId == null
      ? l10n.liveSelectionDefault
      : [_label(model?.label, modelId), ?selection.modelVariant].join('#');
  final agentText = agentId == null
      ? l10n.liveSelectionDefault
      : _label(agent?.label, agentId);
  return '$modelText · $agentText';
}

String sessionSelectionReason(
  SessionSelectionUnavailable reason,
  V2Localizations l10n,
) => switch (reason) {
  SessionSelectionUnavailable.locationUnknown =>
    l10n.liveSelectionLocationUnknown,
  SessionSelectionUnavailable.routeAbsent => l10n.liveSelectionRouteAbsent,
  SessionSelectionUnavailable.authenticationRequired =>
    l10n.liveSelectionAuthRequired,
  SessionSelectionUnavailable.serviceUnavailable =>
    l10n.liveSelectionServiceUnavailable,
  SessionSelectionUnavailable.catalogUnreadable => l10n.liveSelectionUnreadable,
  SessionSelectionUnavailable.emptyCatalog => l10n.liveSelectionEmpty,
};

String? _notice(SessionSelectionNotice notice, V2Localizations l10n) =>
    switch (notice) {
      SessionSelectionNotice.none => null,
      SessionSelectionNotice.refused => l10n.liveSelectionRefused,
      SessionSelectionNotice.notApplied => l10n.liveSelectionNotApplied,
      SessionSelectionNotice.changedElsewhere =>
        l10n.liveSelectionChangedElsewhere,
    };

String _label(String? label, String id) =>
    label == null || label.trim().isEmpty ? id : label;

/// A catalog entry's label, or its id when it has none.
String catalogLabel(String? label, String id) => _label(label, id);

/// The catalog model the session's selection names, when it is offered.
ModelEntry? offeredSessionModel(SessionSelectionState state) =>
    _offeredModel(state, state.selection);

ModelEntry? _offeredModel(SessionSelectionState state, Selection? selection) =>
    state.models
        .where(
          (m) =>
              m.id == selection?.modelId &&
              m.providerId == selection?.modelProviderId,
        )
        .firstOrNull;

/// Whether [showSessionSelection] can open for [live] now, by the AppBar
/// chip's own rule.
bool canShowSessionSelection(SessionLiveController live) =>
    live.supportsSelection &&
    live.canChangeSelection &&
    SessionSelectionChip._openable(live.selectionState);

/// Opens the pick: a bottom sheet on compact widths, a dialog otherwise. The
/// lists are read again on open; a pick closes it and sends one switch.
Future<void> showSessionSelection(
  BuildContext context,
  SessionLiveController live,
) async {
  unawaited(live.refreshSelection());
  final compact = MediaQuery.sizeOf(context).width < 600;
  final pick = compact
      ? await showModalBottomSheet<_Pick>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => FractionallySizedBox(
            heightFactor: 0.8,
            child: _SelectionPanel(live: live),
          ),
        )
      : await showDialog<_Pick>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: _SelectionPanel(live: live),
            ),
          ),
        );
  if (pick == null || !context.mounted) return;
  await pick.apply(live);
  if (context.mounted) announceSessionSelection(context, live);
}

/// Tells the reader how a pick ended when it did not simply apply: refused,
/// not applied, changed elsewhere, or not confirmed yet.
void announceSessionSelection(
  BuildContext context,
  SessionLiveController live,
) {
  final l10n = context.v2L10n;
  final state = live.selectionState;
  final unconfirmed = state.phase == SessionSelectionPhase.unconfirmed;
  final message = unconfirmed
      ? l10n.liveSelectionUnconfirmed
      : switch (state.notice) {
          SessionSelectionNotice.refused ||
          SessionSelectionNotice.notApplied ||
          SessionSelectionNotice.changedElsewhere => _notice(
            state.notice,
            l10n,
          ),
          _ => null,
        };
  if (message == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      action: unconfirmed
          ? SnackBarAction(
              label: l10n.liveSelectionCheckAgain,
              onPressed: () => unawaited(live.refreshSelection()),
            )
          : null,
    ),
  );
}

/// One explicit switch: a model reference or an agent.
final class _Pick {
  const _Pick.model(ModelEntry this.model, this.variant) : agent = null;
  const _Pick.agent(CatalogEntry this.agent) : model = null, variant = null;

  final ModelEntry? model;
  final String? variant;
  final CatalogEntry? agent;

  Future<void> apply(SessionLiveController live) => switch (model) {
    final model? => live.selectModel(model, variant: variant),
    null => live.selectAgent(agent!),
  };
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({required this.live});

  final SessionLiveController live;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: live,
    builder: (context, _) {
      final l10n = context.v2L10n;
      final theme = Theme.of(context);
      final state = live.selectionState;
      final selection = state.selection;
      final enabled = live.canChangeSelection;
      final unconfirmed = state.phase == SessionSelectionPhase.unconfirmed;
      final notice = unconfirmed
          ? l10n.liveSelectionUnconfirmed
          : state.phase == SessionSelectionPhase.pending
          ? l10n.liveSelectionPending
          : _notice(state.notice, l10n);
      final agentId = selection?.agentId;
      final offeredModel = _offeredModel(state, selection);
      // A current variant the offered model no longer lists stays visible.
      final currentVariant = selection?.modelVariant;
      final modelListed =
          offeredModel != null &&
          (currentVariant == null ||
              offeredModel.variants.contains(currentVariant));
      final providers = <String, List<ModelEntry>>{};
      for (final model in state.models) {
        (providers[model.providerId] ??= []).add(model);
      }
      void pick(_Pick pick) => Navigator.of(context).pop(pick);
      Widget header(String text) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      );
      Widget unavailable(SessionSelectionUnavailable reason) => ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(sessionSelectionReason(reason, l10n)),
      );
      // The session's value stays visible when the list does not hold it;
      // only a list that was read says it is not offered.
      Widget current(String label, {required bool listed}) => ListTile(
        enabled: false,
        title: Text(label),
        subtitle: listed ? Text(l10n.liveSelectionNotOffered) : null,
        trailing: const Icon(Icons.check),
      );
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(
                l10n.liveSelection,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (state.loading || state.phase == SessionSelectionPhase.pending)
              const LinearProgressIndicator(),
            if (notice != null)
              ListTile(
                key: const ValueKey('live-selection-notice'),
                leading: const Icon(Icons.info_outline),
                title: Text(notice),
                trailing: unconfirmed
                    ? TextButton(
                        onPressed: () => unawaited(live.refreshSelection()),
                        child: Text(l10n.liveSelectionCheckAgain),
                      )
                    : null,
              ),
            header(l10n.liveSelectionAgent),
            if (state.agentUnavailable case final reason?)
              unavailable(reason)
            else
              for (final agent in state.agents)
                ListTile(
                  key: ValueKey('live-selection-agent-${agent.id}'),
                  enabled: enabled,
                  selected: agent.id == agentId,
                  title: Text(_label(agent.label, agent.id)),
                  subtitle: agent.description == null
                      ? null
                      : Text(
                          agent.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: agent.id == agentId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => pick(_Pick.agent(agent)),
                ),
            if (agentId != null && !state.agents.any((a) => a.id == agentId))
              current(
                agentId,
                listed: !state.loading && state.agentUnavailable == null,
              ),
            header(l10n.liveSelectionModel),
            if (state.modelUnavailable case final reason?)
              unavailable(reason)
            else
              for (final MapEntry(key: provider, value: models)
                  in providers.entries) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                  child: Text(provider, style: theme.textTheme.labelMedium),
                ),
                for (final model in models) ...[
                  ListTile(
                    key: ValueKey(
                      'live-selection-model-${model.providerId}/${model.id}',
                    ),
                    enabled: enabled,
                    selected: identical(model, offeredModel),
                    title: Text(_label(model.label, model.id)),
                    trailing:
                        identical(model, offeredModel) &&
                            selection?.modelVariant == null
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => pick(_Pick.model(model, null)),
                  ),
                  if (model.variants.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        32,
                        0,
                        16,
                        8,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final variant in model.variants)
                            ChoiceChip(
                              key: ValueKey(
                                'live-selection-variant-'
                                '${model.providerId}/${model.id}#$variant',
                              ),
                              label: Text(variant),
                              selected:
                                  identical(model, offeredModel) &&
                                  selection?.modelVariant == variant,
                              onSelected: enabled
                                  ? (_) => pick(_Pick.model(model, variant))
                                  : null,
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            if (selection?.modelId case final modelId? when !modelListed)
              current(
                [modelId, ?currentVariant].join('#'),
                listed: !state.loading && state.modelUnavailable == null,
              ),
          ],
        ),
      );
    },
  );
}
