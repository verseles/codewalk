import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../../shared/widgets/modal_primary_action_shortcuts.dart';
import 'session_composer_controls.dart';
import 'session_live_controller.dart';
import 'session_selection_chip.dart';
import 'sessions_controller.dart';
import 'workspace_draft_page.dart';

/// The composer's local `/` commands, as in v1 (#137). Each one runs an
/// action the app already has and is never sent as a prompt; the server's
/// own commands are not listed here (#292).
enum SessionBuiltinCommand {
  newChat('new'),
  model('model', aliases: {'models'}),
  agent('agent'),
  sessions('sessions'),
  help('help'),
  thinking('thinking'),
  undo('undo'),
  redo('redo'),
  compact('compact');

  const SessionBuiltinCommand(this.name, {this.aliases = const {}});

  /// What the user types after the `/`.
  final String name;

  /// Other names that run the same command.
  final Set<String> aliases;

  String description(V2Localizations l) => switch (this) {
    newChat => l.chatSlashCommandNew,
    model => l.chatSlashCommandModels,
    agent => l.chatSlashCommandAgent,
    sessions => l.chatSlashCommandSessions,
    help => l.chatSlashCommandHelp,
    thinking => l.chatSlashCommandThinking,
    undo => l.chatSlashCommandUndo,
    redo => l.chatSlashCommandRedo,
    compact => l.chatSlashCommandCompact,
  };

  /// The command [name] names, ignoring case, or null.
  static SessionBuiltinCommand? named(String name) {
    final key = name.toLowerCase();
    for (final command in values) {
      if (command.name == key || command.aliases.contains(key)) return command;
    }
    return null;
  }
}

/// The command [text] runs when sent: a leading `/` and a builtin's name.
/// As in v1, words after the name are ignored rather than sent.
SessionBuiltinCommand? parseSessionBuiltinCommand(String text) {
  final match = RegExp(r'^/(\S+)').firstMatch(text.trim());
  return match == null ? null : SessionBuiltinCommand.named(match.group(1)!);
}

/// What the picker filters by while the field holds only `/` and a word, as
/// in v1; null otherwise, and while an input method is composing.
String? sessionCommandQuery(TextEditingValue value) {
  if (!value.composing.isCollapsed) return null;
  return RegExp(r'^/(\S*)$').firstMatch(value.text.trim())?.group(1);
}

/// The commands whose name, other name or description holds [query].
List<SessionBuiltinCommand> sessionCommandSuggestions(
  String query,
  V2Localizations l10n,
) {
  final key = query.toLowerCase();
  return [
    for (final command in SessionBuiltinCommand.values)
      if (command.name.contains(key) ||
          command.aliases.any((alias) => alias.contains(key)) ||
          command.description(l10n).toLowerCase().contains(key))
        command,
  ];
}

/// The turn actions #455 brings: undo, redo and compact.
enum SessionTurnAction { undo, redo, compact }

/// Why a turn action cannot run.
enum SessionTurnActionUnavailable { notYetAvailable, needsConversation }

/// How the `/undo`, `/redo` and `/compact` commands reach a session. Until
/// #455 binds the real actions, [unboundSessionTurnActions] says they are
/// not available yet, so the command never pretends to have run.
abstract interface class SessionTurnActions {
  /// Why [action] cannot run now, or null when it can.
  SessionTurnActionUnavailable? unavailable(SessionTurnAction action);

  Future<void> run(SessionTurnAction action);
}

final class _UnboundSessionTurnActions implements SessionTurnActions {
  const _UnboundSessionTurnActions();

  @override
  SessionTurnActionUnavailable unavailable(SessionTurnAction action) =>
      SessionTurnActionUnavailable.notYetAvailable;

  @override
  Future<void> run(SessionTurnAction action) async {}
}

const SessionTurnActions unboundSessionTurnActions =
    _UnboundSessionTurnActions();

/// Runs [command] from a composer: [live] is the shown session, or null on
/// the New Chat draft; [agentAnchor] places the agent menu on its chip.
Future<void> runSessionBuiltinCommand(
  BuildContext context,
  SessionBuiltinCommand command, {
  SessionLiveController? live,
  GlobalKey? agentAnchor,
  SessionTurnActions turnActions = unboundSessionTurnActions,
}) async {
  final l10n = context.v2L10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void tell(String message) => showAppSnackBar(messenger, message);
  switch (command) {
    case SessionBuiltinCommand.newChat:
      final catalog = context.read<SessionsController?>();
      if (catalog != null && canOpenWorkspaceDraft(catalog)) {
        openWorkspaceDraft(context);
      } else {
        tell(l10n.commandUnavailableHere);
      }
    case SessionBuiltinCommand.model:
      if (live == null) return tell(l10n.commandNeedsConversation);
      if (live.isChild) return tell(l10n.chatModelLockedSubConversation);
      if (!canShowSessionSelection(live)) {
        return tell(l10n.commandUnavailableHere);
      }
      await showSessionSelection(context, live, agents: false);
    case SessionBuiltinCommand.agent:
      if (live == null) return tell(l10n.commandNeedsConversation);
      final anchor = agentAnchor?.currentContext;
      if (live.isChild || anchor == null) {
        return tell(l10n.commandUnavailableHere);
      }
      await showAgentMenu(anchor, live);
    case SessionBuiltinCommand.sessions:
      openSessionList(context);
    case SessionBuiltinCommand.help:
      await _showCommandHelp(context);
    case SessionBuiltinCommand.thinking:
      final preferences = context.read<AppPreferencesController?>();
      if (preferences == null) return tell(l10n.commandUnavailableHere);
      final shown = !preferences.showReasoning;
      preferences.setShowReasoning(shown);
      tell(shown ? l10n.commandThinkingShown : l10n.commandThinkingHidden);
    case SessionBuiltinCommand.undo:
    case SessionBuiltinCommand.redo:
    case SessionBuiltinCommand.compact:
      final action = switch (command) {
        SessionBuiltinCommand.undo => SessionTurnAction.undo,
        SessionBuiltinCommand.redo => SessionTurnAction.redo,
        _ => SessionTurnAction.compact,
      };
      final reason = live == null
          ? SessionTurnActionUnavailable.needsConversation
          : turnActions.unavailable(action);
      if (reason == null) return turnActions.run(action);
      tell(switch (reason) {
        SessionTurnActionUnavailable.notYetAvailable =>
          l10n.commandNotYetAvailable,
        SessionTurnActionUnavailable.needsConversation =>
          l10n.commandNeedsConversation,
      });
  }
}

/// Shows the conversation list: the drawer of a compact window, else the
/// side pane, shown again when the reader hid it.
void openSessionList(BuildContext context) {
  // The open session brings its own Scaffold, without the drawer.
  var scaffold = Scaffold.maybeOf(context);
  while (scaffold != null && !scaffold.hasDrawer) {
    scaffold = scaffold.context.findAncestorStateOfType<ScaffoldState>();
  }
  if (scaffold != null) {
    scaffold.openDrawer();
    return;
  }
  final preferences = context.read<AppPreferencesController?>();
  if (preferences?.sessionPaneHidden ?? false) {
    preferences!.setSessionPaneHidden(false);
  }
}

Future<void> _showCommandHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = context.v2L10n;
    void close() => Navigator.of(context).pop();
    return ModalPrimaryActionShortcuts(
      onPrimaryAction: close,
      child: AlertDialog(
        key: const ValueKey('live-command-help'),
        title: Text(l10n.commandsTitle),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(l10n.commandsHint),
              const SizedBox(height: 8),
              for (final command in SessionBuiltinCommand.values)
                SessionCommandTile(command: command),
            ],
          ),
        ),
        actions: [TextButton(onPressed: close, child: Text(l10n.chatClose))],
      ),
    );
  },
);

/// One command as the picker and the help list show it: its name, written
/// left to right in every language, over its description.
class SessionCommandTile extends StatelessWidget {
  const SessionCommandTile({
    super.key,
    required this.command,
    this.selected = false,
    this.onTap,
  });

  final SessionBuiltinCommand command;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    selected: selected,
    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
    contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 8),
    visualDensity: VisualDensity.compact,
    title: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        [
          '/${command.name}',
          for (final alias in command.aliases) '/$alias',
        ].join('  '),
        textDirection: TextDirection.ltr,
      ),
    ),
    subtitle: Text(command.description(context.v2L10n)),
    onTap: onTap,
  );
}
