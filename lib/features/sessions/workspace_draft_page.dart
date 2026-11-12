import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../platform/sessions/workspace_draft_store.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/session_actions.dart';
import '../../shared/theme/chat_appearance.dart';
import '../hosts/endpoint_health_view.dart';
import 'composer_input.dart';
import 'composer_voice_button.dart';
import 'session_builtin_commands.dart';
import 'session_command_picker.dart';
import 'session_composer_controls.dart';
import 'session_composer_status.dart';
import 'sessions_controller.dart';
import 'workspace_draft_controller.dart';

bool canOpenWorkspaceDraft(SessionsController catalog) =>
    !catalog.hosts.loading &&
    !catalog.hosts.storageError &&
    catalog.selectedProfile != null &&
    !catalog.creating;

/// Starts locally: no create is sent by this navigation or by opening a drawer.
void openWorkspaceDraft(BuildContext context) {
  final controller = context.read<WorkspaceDraftController?>();
  if (controller == null) return;
  Scaffold.maybeOf(context)?.closeDrawer();
  context.go('/sessions');
  unawaited(controller.openDraft());
}

class WorkspaceDraftPage extends StatefulWidget {
  const WorkspaceDraftPage({required this.controller, super.key});
  final WorkspaceDraftController controller;
  @override
  State<WorkspaceDraftPage> createState() => _WorkspaceDraftPageState();
}

class _WorkspaceDraftPageState extends State<WorkspaceDraftPage> {
  final _voice = GlobalKey<ComposerVoiceButtonState>();
  final _directory = TextEditingController();
  final _composerFocus = FocusNode();
  late final _commands = SessionCommandMenu(widget.controller.draft);

  /// The field row's height, which the `/` picker above it leaves free.
  double _fieldHeight = composerActionSize;

  void _fieldMeasured(double height) {
    if (mounted && height != _fieldHeight) {
      setState(() => _fieldHeight = height);
    }
  }

  bool _invalidPath = false;

  @override
  void initState() {
    super.initState();
    _composerFocus.addListener(_composerFocusChanged);
  }

  @override
  void dispose() {
    _composerFocus.removeListener(_composerFocusChanged);
    _directory.dispose();
    _composerFocus.dispose();
    _commands.dispose();
    super.dispose();
  }

  void _chooseDirectory() {
    final path = _directory.text.trim();
    if (!(path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) ||
        path.length > 4096 ||
        utf8.encode(path).length > 4096 ||
        path.contains(String.fromCharCode(0))) {
      setState(() => _invalidPath = true);
      return;
    }
    setState(() => _invalidPath = false);
    unawaited(widget.controller.openDraft(directory: path));
  }

  /// A local command runs whenever no send is pending.
  static bool _canSend(WorkspaceDraftController c) =>
      parseSessionBuiltinCommand(c.draft.text) != null ? !c.sending : c.canSend;

  /// Runs a local `/` command, which never becomes the first prompt (#137).
  void _run(SessionBuiltinCommand command) {
    widget.controller.draft.clear();
    unawaited(
      runSessionBuiltinCommand(
        context,
        command,
        selection: widget.controller.selection,
      ),
    );
  }

  /// Sends the first prompt, then opens the session it created. A dictation
  /// in flight ends first, so nothing it hears lands after the prompt is
  /// read.
  void _send(WorkspaceDraftController c) {
    _voice.currentState?.cancel();
    final command = parseSessionBuiltinCommand(c.draft.text);
    if (command != null) return _run(command);
    _sendPrompt(c);
  }

  void _sendPrompt(WorkspaceDraftController c) => unawaited(
    c.sendFirstPrompt(
      onBound: (ref, _, _) {
        if (mounted) {
          context.go(
            Uri(
              pathSegments: ['', 's', ref.host.value, ref.nativeId],
            ).toString(),
          );
        }
      },
    ),
  );

  /// The greeting steps aside while the field has the focus, so it follows the
  /// focus.
  void _composerFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<SessionsController?>();
    final l10n = context.v2L10n;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (!c.loading &&
            !c.sending &&
            !c.needsDirectory &&
            c.takeFocusRequest()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _composerFocus.requestFocus();
          });
        }
        final uncertain =
            (c.status == WorkspaceDraftStatus.creating && !c.sending) ||
            const {
              WorkspaceDraftStatus.uncertain,
              WorkspaceDraftStatus.confirming,
              WorkspaceDraftStatus.bound,
            }.contains(c.status);
        final failed = c.status == WorkspaceDraftStatus.failed;
        final notice = uncertain
            ? c.entry?.createdSession != null
                  ? l10n.composerNotConfirmed
                  : l10n.workspaceDraftUncertain
            : switch (c.notice) {
                WorkspaceDraftNotice.fenceFailed => l10n.composerNoticeNotSaved,
                WorkspaceDraftNotice.rejected => l10n.sessionsActionFailed,
                WorkspaceDraftNotice.unavailable =>
                  l10n.composerNoticeUnavailable,
                WorkspaceDraftNotice.unreadable =>
                  l10n.composerNoticeUnreadable,
                _ => null,
              };
        final unavailable = switch (catalog?.createReason) {
          null || SessionActionReason.none => null,
          SessionActionReason.versionUnverified =>
            l10n.sessionsActionUnavailableVersion,
          SessionActionReason.unsupportedPlatform =>
            l10n.sessionsActionUnavailablePlatform,
          SessionActionReason.authenticationRequired =>
            l10n.sessionsActionUnavailableAuth,
          SessionActionReason.listNotCurrent =>
            l10n.sessionsActionUnavailableList,
          SessionActionReason.commandInFlight =>
            l10n.sessionsActionUnavailableBusy,
          SessionActionReason.noIdleMarker =>
            l10n.sessionsActionUnavailableMarker,
        };
        return LayoutBuilder(
          builder: (context, box) {
            // The field scrolls into view with the keyboard open; the `/`
            // picker keeps above it in what is left: less the field's 20 dp
            // scroll margin, the page's 16 and the picker's own 4.
            final pickerRoom =
                box.maxHeight -
                MediaQuery.paddingOf(context).bottom -
                _fieldHeight -
                40;
            return SingleChildScrollView(
              key: const ValueKey('workspace-draft'),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.chatNewChat,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (c.needsDirectory) ...[
                              TextField(
                                key: const ValueKey(
                                  'workspace-draft-directory',
                                ),
                                controller: _directory,
                                textDirection: TextDirection.ltr,
                                decoration: InputDecoration(
                                  labelText: l10n.sessionsCreateProject,
                                  hintText: l10n.sessionsCreateDirectoryHint,
                                  errorText: _invalidPath
                                      ? l10n.sessionsCreateDirectoryAbsolute
                                      : null,
                                ),
                                onSubmitted: (_) => _chooseDirectory(),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                  key: const ValueKey(
                                    'workspace-draft-project-confirm',
                                  ),
                                  onPressed: _chooseDirectory,
                                  child: Text(l10n.sessionsCreateProject),
                                ),
                              ),
                            ] else
                              Text(
                                c.currentKey!.canonicalDirectory,
                                textDirection: TextDirection.ltr,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (notice != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  notice,
                                  key: const ValueKey('workspace-draft-notice'),
                                ),
                              ),
                            if (uncertain || failed)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  key: const ValueKey('workspace-draft-reset'),
                                  onPressed: c.sending
                                      ? null
                                      : c.discardAttempt,
                                  child: Text(l10n.workspaceDraftReset),
                                ),
                              ),
                            if (c.loading) Text(l10n.sessionsLoading),
                            if (c.endpointOffline &&
                                c.health != null &&
                                catalog?.selectedProfile != null)
                              EndpointHealthRecovery(
                                profile: catalog!.selectedProfile!,
                                health: c.health!,
                              ),
                            if (!c.needsDirectory &&
                                !c.loading &&
                                unavailable != null &&
                                !c.sending)
                              Text(unavailable),
                          ],
                        ),
                        // The v1 greeting of an empty conversation, in the space
                        // above the field: a draft has no items yet. It steps
                        // aside while the field has the focus, so the keyboard
                        // leaves the field whole.
                        Visibility(
                          visible: !_composerFocus.hasFocus,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.waving_hand,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.chatHelloAssistant,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.chatWelcomeSubmessage,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The live composer's status slot, so the
                              // composer sits where it will after the first
                              // send.
                              const SizedBox(
                                height: SessionComposerStatus.height,
                              ),
                              SessionCommandPicker(
                                menu: _commands,
                                onRun: _run,
                                maxHeight: pickerRoom,
                              ),
                              SessionFieldHeightReporter(
                                onHeight: _fieldMeasured,
                                child: ComposerFrame(
                                  attachTooltip: l10n.composerAttachSoon,
                                  voiceTooltip: l10n.composerVoiceUnavailable,
                                  voice: ComposerVoiceButton(
                                    key: _voice,
                                    text: c.draft,
                                    enabled: !c.sending && !c.endpointOffline,
                                  ),
                                  chip: SessionModelChip(live: c.selection),
                                  field: (context, open) => Focus(
                                    // A physical Enter sends; Shift+Enter
                                    // breaks the line (#174).
                                    onKeyEvent: (_, event) {
                                      if (_commands.handleKey(
                                            event,
                                            l10n,
                                            _run,
                                            shown:
                                                sessionCommandPickerHeight(
                                                  context,
                                                  pickerRoom,
                                                ) >
                                                0,
                                          ) ==
                                          KeyEventResult.handled) {
                                        return KeyEventResult.handled;
                                      }
                                      if (!isComposerSendKey(
                                        event,
                                        c.draft.value,
                                      )) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (_canSend(c)) _send(c);
                                      return KeyEventResult.handled;
                                    },
                                    child: ConversationTextScale(
                                      child: TextField(
                                        key: const ValueKey(
                                          'workspace-draft-text',
                                        ),
                                        controller: c.draft,
                                        focusNode: _composerFocus,
                                        enabled: !c.sending,
                                        readOnly: c.endpointOffline,
                                        minLines: 1,
                                        // A closed phone composer stays
                                        // one line.
                                        maxLines: open ? 6 : 1,
                                        keyboardType: TextInputType.multiline,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        autocorrect: composerSuggests(context),
                                        enableSuggestions: composerSuggests(
                                          context,
                                        ),
                                        spellCheckConfiguration:
                                            composerSpellCheckConfiguration(
                                              context,
                                            ),
                                        decoration: composerDecoration(
                                          context,
                                          open
                                              ? l10n.composerHintCommands
                                              : l10n.composerHint,
                                        ),
                                      ),
                                    ),
                                  ),
                                  action: ComposerSendButton(
                                    buttonKey: const ValueKey(
                                      'workspace-draft-send',
                                    ),
                                    tooltip: c.sending
                                        ? l10n.composerSending
                                        : l10n.composerSend,
                                    onPressed: _canSend(c)
                                        ? () => _send(c)
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
