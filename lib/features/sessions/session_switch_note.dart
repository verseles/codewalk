import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_agent_color.dart';

/// The names the session's catalog gives its agents and models, for the
/// notes of the switches in its conversation (#426). Without it a note
/// names the id the harness reported.
class SessionSwitchLabels extends InheritedWidget {
  const SessionSwitchLabels({
    super.key,
    required this.models,
    required this.agents,
    required super.child,
  });

  final List<ModelEntry> models;
  final List<CatalogEntry> agents;

  static SessionSwitchLabels? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionSwitchLabels>();

  @override
  bool updateShouldNotify(SessionSwitchLabels old) =>
      !identical(old.models, models) || !identical(old.agents, agents);
}

/// A small note where the session switched its agent or model (#426), as
/// the official client shows one: the agent on its color, or the model
/// with its variant.
class SessionSwitchNote extends StatelessWidget {
  const SessionSwitchNote({super.key, required this.selection});

  final Selection selection;

  /// The catalog's name, or the reported id when it names none.
  static String _named(String? label, String id) =>
      label == null || label.trim().isEmpty ? id : label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final theme = Theme.of(context);
    final labels = SessionSwitchLabels.maybeOf(context);
    final agentId = selection.agentId;
    final String text;
    final Widget lead;
    if (agentId != null) {
      final agents = labels?.agents ?? const <CatalogEntry>[];
      final agent = agents.where((entry) => entry.id == agentId).firstOrNull;
      text = l10n.liveSwitchedAgent(_named(agent?.label, agentId));
      lead = CircleAvatar(
        radius: 5,
        backgroundColor: sessionAgentColor(agents, agentId),
      );
    } else {
      final model = labels?.models
          .where(
            (entry) =>
                entry.id == selection.modelId &&
                entry.providerId == selection.modelProviderId,
          )
          .firstOrNull;
      final name = _named(model?.label, selection.modelId ?? '');
      final variant = selection.modelVariant;
      text = l10n.liveSwitchedModel(variant == null ? name : '$name $variant');
      lead = Icon(
        Symbols.swap_horiz,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
    return ConversationTextScale(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            lead,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
