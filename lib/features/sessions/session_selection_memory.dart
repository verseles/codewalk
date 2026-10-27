import 'package:codewalk_core/codewalk_core.dart';

import '../../platform/sessions/model_preference_store.dart';

/// How the local preferences name a model: `provider/model`.
String modelPreferenceKey(String providerId, String modelId) =>
    '$providerId/$modelId';

/// The model a selection names, by its preference key.
String? selectionModelKey(Selection? selection) =>
    switch ((selection?.modelProviderId, selection?.modelId)) {
      (final provider?, final model?) => modelPreferenceKey(provider, model),
      _ => null,
    };

/// One switch this view sent, waiting to settle before it is remembered.
/// [before] is the selection the switch started from.
final class PendingSelectionSwitch {
  const PendingSelectionSwitch.model(
    ModelEntry this.model,
    this.variant, {
    required this.project,
    required this.before,
  }) : agent = null;

  const PendingSelectionSwitch.agent(
    CatalogEntry this.agent, {
    required this.project,
    required this.before,
  }) : model = null,
       variant = null;

  final ModelEntry? model;
  final String? variant;
  final CatalogEntry? agent;
  final String project;
  final Selection? before;

  /// Whether [selection] is what this switch asked for.
  bool settledIn(Selection selection) => switch ((model, agent)) {
    (final model?, _) =>
      selection.modelId == model.id &&
          selection.modelProviderId == model.providerId &&
          selection.modelVariant == variant,
    (_, final agent?) => selection.agentId == agent.id,
    _ => false,
  };

  /// Remembers a switch the server took, like the retained reference: the
  /// new item first and the one before it next, so the first cycling press
  /// goes back; and the model each agent last used in this project.
  Future<void> remember(
    ModelPreferenceStore store,
    String server,
    Selection selection,
  ) async {
    final before = this.before;
    final beforeModel = selectionModelKey(before);
    if (model case final model?) {
      final key = modelPreferenceKey(model.providerId, model.id);
      await store.recordRecent(
        server,
        project,
        key,
        previous: beforeModel == key ? null : beforeModel,
      );
      await store.recordVariant(
        server,
        project,
        key,
        variant ?? ModelPreferenceStore.autoVariant,
        previous: beforeModel == key
            ? before?.modelVariant ?? ModelPreferenceStore.autoVariant
            : null,
      );
      if (selection.agentId case final agent?) {
        await store.rememberAgentModel(server, project, agent, key, variant);
      }
    }
    if (agent case final agent?) {
      final previous = before?.agentId;
      await store.recordAgent(
        server,
        project,
        agent.id,
        previous: previous == agent.id ? null : previous,
      );
      // The agent left keeps the model it was using.
      if ((previous, beforeModel) case (
        final previous?,
        final model?,
      ) when previous != agent.id) {
        await store.rememberAgentModel(
          server,
          project,
          previous,
          model,
          before?.modelVariant,
        );
      }
    }
  }
}
