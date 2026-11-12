import 'dart:async';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/permission_mode.dart';
import '../../shared/sessions/session_selection.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'session_agent_color.dart';
import 'session_live_controller.dart';
import 'session_selection_host.dart';

/// The live session's model and agent (V2-054A). The label is the server's
/// selection, or a switch it accepted and has not reported yet; a missing
/// half is the server's default. A pick sends one switch, and the composer
/// holds this session's sends until it settles.
class SessionSelectionChip extends StatelessWidget {
  const SessionSelectionChip({super.key, required this.live, this.compact});

  final SessionSelectionHost live;

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
          ?sessionSelectionStatus(state, l10n),
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
                ? const AppIndeterminateRing(size: 14, strokeWidth: 2)
                : Icon(
                    live.isChild
                        ? Symbols.lock_outline
                        : attention
                        ? Symbols.info
                        : Symbols.tune,
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
}

/// The persistent explanation for a selection still settling or unavailable.
String? sessionSelectionStatus(
  SessionSelectionState state,
  V2Localizations l10n,
) {
  if (state.phase == SessionSelectionPhase.pending) {
    return l10n.liveSelectionPending;
  }
  if (state.phase == SessionSelectionPhase.unconfirmed) {
    return l10n.liveSelectionUnconfirmed;
  }
  if (_notice(state.notice, l10n) case final notice?) return notice;
  // Taken by the server, not reported yet: the next pick waits for it.
  if (state.awaitingReport) return l10n.liveSelectionAwaitingReport;
  if (state.loading) return l10n.liveSelectionLoading;
  // A half that can still be picked is no reason to report; the pick
  // explains each half on its own.
  final model = state.modelUnavailable;
  if (model == null || state.agentUnavailable == null) return null;
  return sessionSelectionReason(model, l10n);
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
  final fallback = state.defaultModel;
  if (modelId == null && agentId == null && fallback == null) {
    return l10n.liveSelectionDefault;
  }
  final model = _offeredModel(state, selection);
  final agent = state.agents.where((a) => a.id == agentId).firstOrNull;
  // Without a model of its own the session runs on the one the server names.
  final modelText = modelId == null
      ? fallback ?? l10n.liveSelectionDefault
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
bool canShowSessionSelection(SessionSelectionHost live) =>
    live.supportsSelection &&
    live.canChangeSelection &&
    SessionSelectionChip._openable(live.selectionState);

/// Opens the one pick of agent, model, variant and permissions (#485): a
/// bottom sheet on compact widths, a dialog otherwise. Every entry point (the
/// composer's chip, `/model`, `/agent`, error recovery) opens it. The lists
/// are read again on open; a pick closes it and sends one switch.
Future<void> showSessionSelection(
  BuildContext context,
  SessionSelectionHost live,
) async {
  unawaited(live.refreshSelection());
  final compact = MediaQuery.sizeOf(context).width < 600;
  final pick = compact
      ? await showModalBottomSheet<_Pick>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => Padding(
            // The search field keeps above the keyboard.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.8,
              child: _SelectionPanel(live: live, fill: true),
            ),
          ),
        )
      : await showDialog<_Pick>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: _SelectionPanel(live: live, autofocus: true),
            ),
          ),
        );
  if (pick == null || !context.mounted) return;
  // A pick the session can no longer take (its lease is not live, or a
  // switch it took still awaits the server's report) is said, never dropped
  // in silence (#431).
  if (!live.canChangeSelection) {
    showAppSnackBar(
      ScaffoldMessenger.maybeOf(context),
      context.v2L10n.liveSelectionNotApplied,
    );
    return;
  }
  await pick.apply(live);
  if (context.mounted) announceSessionSelection(context, live);
}

/// Tells the reader how a pick ended when it did not simply apply: refused,
/// not applied, changed elsewhere, or not confirmed yet.
void announceSessionSelection(BuildContext context, SessionSelectionHost live) {
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
  showAppSnackBar(
    ScaffoldMessenger.maybeOf(context),
    message,
    action: unconfirmed
        ? SnackBarAction(
            label: l10n.liveSelectionCheckAgain,
            onPressed: () => unawaited(live.refreshSelection()),
          )
        : null,
  );
}

/// One explicit switch: a model reference or an agent.
final class _Pick {
  const _Pick.model(ModelEntry this.model, this.variant) : agent = null;
  const _Pick.agent(CatalogEntry this.agent) : model = null, variant = null;

  final ModelEntry? model;
  final String? variant;
  final CatalogEntry? agent;

  Future<void> apply(SessionSelectionHost live) => switch (model) {
    final model? => live.selectModel(model, variant: variant),
    null => live.selectAgent(agent!),
  };
}

/// The pick (#485). Models come first: this server's favorites, then this
/// project's recent models, then every model by provider, each offered by
/// the session's location, with its variants in a compact menu on its row; a
/// search narrows them by name, id or provider. A fixed footer holds the
/// agents, each on its color, and this session's permission mode with the
/// count of requests waiting. A part the harness does not offer is not shown.
class _SelectionPanel extends StatefulWidget {
  const _SelectionPanel({
    required this.live,
    this.fill = false,
    this.autofocus = false,
  });

  final SessionSelectionHost live;

  /// The panel takes its whole height (a sheet) instead of fitting its
  /// content (a dialog).
  final bool fill;
  final bool autofocus;

  @override
  State<_SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<_SelectionPanel> {
  final _search = TextEditingController();
  late final _shown = _SelectionShown(widget.live);

  /// The last permission write failed. It is said beside the switch, since a
  /// snack bar would sit under the sheet (#485).
  bool _permissionFailed = false;

  @override
  void dispose() {
    _search.dispose();
    _shown.dispose();
    super.dispose();
  }

  Future<void> _setAutoApprove(bool value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.v2L10n.livePermissionModeFailed;
    setState(() => _permissionFailed = false);
    final applied = await widget.live.setPermissionMode(
      value ? PermissionMode.allowAll : PermissionMode.ask,
    );
    if (mounted) {
      setState(() => _permissionFailed = !applied);
    } else if (!applied) {
      showAppSnackBar(messenger, failed);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_shown, _search]),
    builder: (context, _) {
      final live = widget.live;
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
      final query = _search.text.trim().toLowerCase();
      bool matches(ModelEntry model) =>
          query.isEmpty ||
          [
            model.label,
            model.id,
            model.providerId,
            ?state.providers[model.providerId],
          ].any((text) => text.toLowerCase().contains(query));
      final byKey = {
        for (final model in state.models)
          SessionLiveController.modelKey(model): model,
      };
      final favoriteKeys = live.favoriteModels.toSet();
      // Saved names the location does not offer are not shown.
      final favorites = [for (final key in live.favoriteModels) ?byKey[key]];
      final recents = [
        for (final key in live.recentModels)
          if (!favoriteKeys.contains(key)) ?byKey[key],
      ];
      final providers = <String, List<ModelEntry>>{};
      for (final model in state.models.where(matches)) {
        (providers[model.providerId] ??= []).add(model);
      }
      void pick(_Pick pick) => Navigator.of(context).pop(pick);
      // The session's own value needs no switch: picking it again closes the
      // pick and sends nothing (#431); only an explicit Auto clears a
      // variant.
      void pickModel(ModelEntry model, String? variant) =>
          identical(model, offeredModel) && variant == currentVariant
          ? Navigator.of(context).pop()
          : pick(_Pick.model(model, variant));
      void pickAgent(CatalogEntry agent) => agent.id == agentId
          ? Navigator.of(context).pop()
          : pick(_Pick.agent(agent));
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
        leading: const Icon(Symbols.info),
        title: Text(sessionSelectionReason(reason, l10n)),
      );
      // The session's value stays visible when the list does not hold it;
      // only a list that was read says it is not offered.
      Widget current(String label, {required bool listed}) => ListTile(
        enabled: false,
        title: Text(label),
        subtitle: listed ? Text(l10n.liveSelectionNotOffered) : null,
        trailing: const Icon(Symbols.check),
      );
      Widget model(ModelEntry model, {String? section}) {
        final key = SessionLiveController.modelKey(model);
        final selected = identical(model, offeredModel);
        final favorite = favoriteKeys.contains(key);
        // A tap on the row keeps the session's variant for its own model and
        // takes the server's default (Auto) for any other.
        final variant = selected ? currentVariant : null;
        return ListTile(
          key: ValueKey(
            section == null
                ? 'live-selection-model-$key'
                : 'live-selection-$section-$key',
          ),
          enabled: enabled,
          selected: selected,
          title: Text(
            _label(model.label, model.id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Outside its provider's group a model names its provider.
          subtitle: section == null
              ? null
              : Text(
                  state.providers[model.providerId] ?? model.providerId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (model.free) _FreeBadge(label: l10n.liveModelFree),
              if (model.variants.isNotEmpty || variant != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _VariantMenu(
                    key: ValueKey(
                      'live-selection-variant-menu-${section ?? 'model'}-$key',
                    ),
                    modelKey: key,
                    variants: model.variants,
                    current: variant,
                    autoLabel: l10n.liveSelectionAuto,
                    enabled: enabled,
                    onPicked: (picked) => pickModel(model, picked),
                  ),
                ),
              if (selected)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Icon(Symbols.check),
                ),
              // Starring never picks the model.
              IconButton(
                key: ValueKey('live-selection-star-${section ?? 'model'}-$key'),
                tooltip: favorite
                    ? l10n.liveModelFavoriteRemove
                    : l10n.liveModelFavoriteAdd,
                isSelected: favorite,
                icon: const Icon(Symbols.star_border),
                // A Material Symbols glyph is outlined unless it is filled.
                selectedIcon: const Icon(Symbols.star, fill: 1),
                onPressed: live.canFavoriteModels
                    ? () => unawaited(
                        live.setFavoriteModel(model, favorite: !favorite),
                      )
                    : null,
              ),
            ],
          ),
          onTap: () => pickModel(model, variant),
        );
      }

      Widget agents() => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.liveSelectionAgent, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            if (state.agentUnavailable case final reason?)
              Text(sessionSelectionReason(reason, l10n))
            else
              SingleChildScrollView(
                key: const ValueKey('live-selection-agents'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final agent in state.agents)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          key: ValueKey('live-selection-agent-${agent.id}'),
                          showCheckmark: false,
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: sessionAgentColor(
                              state.agents,
                              agent.id,
                            ),
                          ),
                          label: Text(_label(agent.label, agent.id)),
                          tooltip: agent.description,
                          selected: agent.id == agentId,
                          onSelected: enabled ? (_) => pickAgent(agent) : null,
                        ),
                      ),
                    if (agentId != null &&
                        !state.agents.any((a) => a.id == agentId))
                      ChoiceChip(
                        key: const ValueKey('live-selection-agent-current'),
                        showCheckmark: false,
                        label: Text(
                          !state.loading && state.agentUnavailable == null
                              ? '$agentId · ${l10n.liveSelectionNotOffered}'
                              : agentId,
                        ),
                        selected: true,
                        onSelected: null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      );

      Widget permissions() {
        final unrestricted =
            live.supportsUnrestricted && live.unrestrictedState.inEffect;
        final mode = live.permissionModeState.mode;
        final on = unrestricted || mode == PermissionMode.allowAll;
        final pending = live.pendingPermissions;
        final detail = [
          // The session's allow-everything rule decides while it is in
          // effect; it is turned off from the permission chip.
          if (unrestricted) l10n.livePermissionModeUnrestricted,
          if (pending > 0) l10n.liveSelectionPermissionsWaiting(pending),
        ].join(' · ');
        return SwitchListTile(
          key: const ValueKey('live-auto-approve'),
          title: Text(
            !unrestricted && mode == null
                ? l10n.livePermissionModeUnavailable
                : on
                ? l10n.chatPermissionAutoApproveOn
                : l10n.chatPermissionAutoApproveOff,
          ),
          subtitle: _permissionFailed
              ? Text(
                  [
                    l10n.livePermissionModeFailed,
                    detail,
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: TextStyle(color: theme.colorScheme.error),
                )
              : detail.isEmpty
              ? null
              : Text(detail),
          value: on,
          onChanged:
              unrestricted ||
                  mode == null ||
                  live.savingPermissionMode ||
                  !live.canChangePermissionMode
              ? null
              : (value) => unawaited(_setAutoApprove(value)),
        );
      }

      final saving = live.modelPreferences;
      // No title: the lists take its room (owner, beta.21). The sheet's drag
      // handle spaces its top; the dialog keeps a little room of its own.
      final rows = <Widget>[
        if (!widget.fill) const SizedBox(height: 8),
        if (state.loading || state.phase == SessionSelectionPhase.pending)
          const AppIndeterminateBar(),
        if (notice != null)
          ListTile(
            key: const ValueKey('live-selection-notice'),
            leading: const Icon(Symbols.info),
            title: Text(notice),
            trailing: unconfirmed
                ? TextButton(
                    onPressed: () => unawaited(live.refreshSelection()),
                    child: Text(l10n.liveSelectionCheckAgain),
                  )
                : null,
          ),
        if (state.modelUnavailable case final reason?)
          unavailable(reason)
        else ...[
          if (state.models.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
              child: TextField(
                key: const ValueKey('live-selection-search'),
                controller: _search,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Symbols.search),
                  hintText: l10n.liveModelSearch,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (saving != null &&
              (saving.unreadable || saving.hasPersistenceError))
            ListTile(
              key: const ValueKey('live-selection-preferences-unsaved'),
              leading: const Icon(Symbols.info),
              title: Text(l10n.liveModelPreferencesUnsaved),
            ),
          // While searching, the matches show once, by provider.
          if (query.isEmpty && favorites.isNotEmpty) ...[
            header(l10n.liveModelFavorites),
            for (final entry in favorites) model(entry, section: 'favorite'),
          ],
          if (query.isEmpty && recents.isNotEmpty) ...[
            header(l10n.liveModelRecent),
            for (final entry in recents) model(entry, section: 'recent'),
          ],
          if (query.isNotEmpty && providers.isEmpty)
            ListTile(
              key: const ValueKey('live-selection-no-match'),
              title: Text(l10n.liveModelNoMatch),
            ),
          for (final MapEntry(key: provider, value: models)
              in providers.entries) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(
                state.providers[provider] ?? provider,
                style: theme.textTheme.labelMedium,
              ),
            ),
            for (final entry in models) model(entry),
          ],
        ],
        if (selection?.modelId case final modelId? when !modelListed)
          current(
            [modelId, ?currentVariant].join('#'),
            listed: !state.loading && state.modelUnavailable == null,
          ),
      ];
      // Picking the model and its variant comes first; the agent and the
      // permission mode stay in reach below the list, fixed when the pick
      // has room, or at the list's end on a short screen (keyboard open,
      // large text), where a fixed footer would not fit.
      final footer = [
        if (live.supportsSelection) agents(),
        if (live.permissionModes != null) permissions(),
      ];
      // The title is gone (beta.21); the panel still names its route for a
      // screen reader.
      return Semantics(
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveSelection,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fixed = constraints.maxHeight >= 420;
              final list = ListView(
                key: const ValueKey('live-selection-list'),
                shrinkWrap: !widget.fill,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  ...rows,
                  if (!fixed && footer.isNotEmpty) ...[
                    const Divider(height: 1),
                    ...footer,
                  ],
                ],
              );
              return Column(
                mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (widget.fill)
                    Expanded(child: list)
                  else
                    Flexible(child: list),
                  if (fixed && footer.isNotEmpty) ...[
                    const Divider(height: 1),
                    ...footer,
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

/// Notifies only when something the pick shows changed, so live events that
/// touch none of it never rebuild its long list (#431).
final class _SelectionShown extends ChangeNotifier {
  _SelectionShown(this.live) : _last = _read(live) {
    live.addListener(_changed);
  }

  final SessionSelectionHost live;
  List<Object?> _last;

  void _changed() {
    final next = _read(live);
    if (_same(next, _last)) return;
    _last = next;
    notifyListeners();
  }

  @override
  void dispose() {
    live.removeListener(_changed);
    super.dispose();
  }

  static List<Object?> _read(SessionSelectionHost live) {
    final state = live.selectionState;
    final selection = state.selection;
    final preferences = live.modelPreferences;
    return [
      selection == null,
      selection?.modelId,
      selection?.modelProviderId,
      selection?.modelVariant,
      selection?.agentId,
      state.models,
      state.agents,
      state.defaultModel,
      state.providers,
      state.loading,
      state.modelUnavailable,
      state.agentUnavailable,
      state.phase,
      state.notice,
      state.awaitingReport,
      live.canChangeSelection,
      live.canFavoriteModels,
      live.favoriteModels.join('\n'),
      live.recentModels.join('\n'),
      preferences?.unreadable,
      preferences?.hasPersistenceError,
      live.pendingPermissions,
      live.permissionModeState.mode,
      live.savingPermissionMode,
      live.canChangePermissionMode,
      live.supportsUnrestricted && live.unrestrictedState.inEffect,
    ];
  }

  /// Lists and maps compare by identity: the catalog replaces them whole.
  static bool _same(List<Object?> a, List<Object?> b) {
    for (var i = 0; i < a.length; i++) {
      final (x, y) = (a[i], b[i]);
      if (x is List || x is Map ? !identical(x, y) : x != y) return false;
    }
    return true;
  }
}

/// A model's variants in a compact menu on its row (#485): Auto, which leaves
/// the variant to the server, and each variant it lists; a chosen variant it
/// no longer lists stays, so Auto can still clear it.
class _VariantMenu extends StatelessWidget {
  const _VariantMenu({
    super.key,
    required this.modelKey,
    required this.variants,
    required this.current,
    required this.autoLabel,
    required this.enabled,
    required this.onPicked,
  });

  final String modelKey;
  final List<String> variants;
  final String? current;
  final String autoLabel;
  final bool enabled;
  final void Function(String? variant) onPicked;

  @override
  Widget build(BuildContext context) {
    const auto = '';
    final theme = Theme.of(context);
    final values = [
      auto,
      ...variants,
      if (current case final current? when !variants.contains(current)) current,
    ];
    return PopupMenuButton<String>(
      enabled: enabled,
      initialValue: current ?? auto,
      onSelected: (value) => onPicked(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        for (final value in values)
          CheckedPopupMenuItem<String>(
            key: ValueKey(
              value.isEmpty
                  ? 'live-selection-auto-$modelKey'
                  : 'live-selection-variant-$modelKey#$value',
            ),
            value: value,
            checked: (current ?? auto) == value,
            child: Text(value.isEmpty ? autoLabel : value),
          ),
      ],
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 2, 2),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                current ?? autoLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium,
              ),
            ),
            const Icon(Symbols.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Marks a model whose stated price is zero.
class _FreeBadge extends StatelessWidget {
  const _FreeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}
