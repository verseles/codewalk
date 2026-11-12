import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../app/app_preferences_controller.dart';
import '../../shared/l10n/generated/v2_localizations.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/sessions/prompt_outbox.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_indeterminate_progress.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../hosts/endpoint_health_view.dart';
import 'composer_input.dart';
import 'session_builtin_commands.dart';
import 'session_command_picker.dart';
import 'session_composer_controller.dart';
import 'session_composer_controls.dart';
import 'session_composer_status.dart';
import 'session_input_history.dart';
import 'session_stop_button.dart';

/// The live screen's composer: pending inbox chips, entries that still need
/// the user and the text field, whose Send button, held, chooses steer or
/// queue (#470). It edits the
/// session's draft, so typing never rebuilds the timeline, and a reopened
/// lease or a tab shown again keeps the text.
class SessionComposer extends StatefulWidget {
  const SessionComposer({
    super.key,
    required this.controller,
    required this.text,
    required this.maxHeight,
    this.focusNode,
  });
  final SessionComposerController controller;

  /// Owned by the session's live controller, so a draft outlives a reopened
  /// lease and the page. It must be that session's draft
  /// (`SessionLiveController.draft`): a taken-back message returns there.
  final TextEditingController text;

  /// The most the composer may take of the page body, which already
  /// excludes the keyboard; past it the composer scrolls.
  final double maxHeight;

  /// The field's focus, so the page's shortcuts can focus it.
  final FocusNode? focusNode;
  @override
  State<SessionComposer> createState() => _SessionComposerState();
}

class _SessionComposerState extends State<SessionComposer> {
  TextEditingController get _text => widget.text;
  DateTime? _escapeAt;
  late final SessionCommandMenu _commands = SessionCommandMenu(_text);

  /// The field's focus: the page's, or the composer's own.
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  final _sendAnchor = GlobalKey();

  /// The field row's height, which the `/` picker above it leaves free.
  double _fieldHeight = composerActionSize;

  /// The room the composer leaves above its field, less the picker's 4 dp
  /// gap: the scroll above keeps the field, so a taller list is clipped.
  double get _pickerRoom => widget.maxHeight - _fieldHeight - 4;

  void _fieldMeasured(double height) {
    if (mounted && height != _fieldHeight) {
      setState(() => _fieldHeight = height);
    }
  }

  /// Up and Down recall the session's prompts on a desktop keyboard, as in
  /// v1; a phone has no recall gesture.
  static bool get _desktop =>
      kIsWeb ||
      const {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final picking = sessionCommandPickerHeight(context, _pickerRoom) > 0;
    if (_commands.handleKey(event, context.v2L10n, _pick, shown: picking) ==
        KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (isComposerSendKey(event, _text.value)) {
      // The key never breaks the line; with nothing to send it does nothing,
      // and the field keeps its focus either way (#174).
      if (_canSend) unawaited(_send());
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown)) {
      return _arrow(up: event.logicalKey == LogicalKeyboardKey.arrowUp);
    }
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed ||
        !_text.value.composing.isCollapsed ||
        widget.controller.sending ||
        !widget.controller.live.canStop ||
        // An open search takes Escape first, so it never stops a turn (#462).
        widget.controller.live.search.open) {
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    final previous = _escapeAt;
    _escapeAt = now;
    if (previous != null &&
        now.difference(previous) <= const Duration(milliseconds: 500)) {
      _escapeAt = null;
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      widget.controller.live.stopCurrentTurn();
    } else {
      showAppSnackBar(
        ScaffoldMessenger.maybeOf(context),
        context.v2L10n.liveStopEscapeHint,
        duration: const Duration(seconds: 1),
      );
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _arrow({required bool up}) {
    final keyboard = HardwareKeyboard.instance;
    final value = _text.value;
    if (!_desktop ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed ||
        !value.composing.isCollapsed ||
        !value.selection.isCollapsed ||
        widget.controller.sending ||
        !widget.controller.live.draftSettled ||
        !_onEdgeLine(up: up)) {
      return KeyEventResult.ignored;
    }
    final recall = widget.controller.live.recall;
    final handled = up
        ? recall.up(
            value,
            () => sessionInputHistory(
              widget.controller.live.state?.timeline ?? const [],
            ),
          )
        : recall.down(value);
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  /// Whether the caret is on the field's first line (or last, going down),
  /// so the key would not move it within the text.
  bool _onEdgeLine({required bool up}) {
    final editable = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>()
        ?.renderEditable;
    final selection = _text.selection;
    if (editable == null || !editable.hasSize || !selection.isValid) {
      return true;
    }
    final position = TextPosition(
      offset: selection.extentOffset.clamp(0, _text.text.length),
      affinity: selection.affinity,
    );
    final next = up
        ? editable.getTextPositionAbove(position)
        : editable.getTextPositionBelow(position);
    return editable.getLineAtOffset(position) == editable.getLineAtOffset(next);
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(_textChanged);
  }

  @override
  void dispose() {
    _text.removeListener(_textChanged);
    _commands.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  // The draft belongs to the session and outlives this widget, so a
  // finished send still updates it after an unmount.
  Future<void> _sendAgain(CommandId id) async {
    final draft = _text;
    final text = await widget.controller.sendAgain(id);
    if (text != null && draft.text.isEmpty) draft.text = text;
  }

  /// Takes a waiting message back into the field (#486); the session puts
  /// its text in the draft once the cancel settles.
  Future<void> _edit(CommandId id) async {
    if (await widget.controller.takeBack(id) && mounted) _focus.requestFocus();
  }

  void _textChanged() => setState(() {});

  /// A local command runs whenever no send is pending; text needs a
  /// session that can take it.
  bool get _canSend => parseSessionBuiltinCommand(_text.text) != null
      ? !widget.controller.sending
      : widget.controller.canSend && _text.text.trim().isNotEmpty;

  void _pick(SessionBuiltinCommand command) => unawaited(_run(command));

  /// Runs a local `/` command in place of a send; the command leaves the
  /// field, as in v1 (#137).
  Future<void> _run(SessionBuiltinCommand command) {
    _text.clear();
    return runSessionBuiltinCommand(
      context,
      command,
      live: widget.controller.live,
      turnActions: widget.controller.live.turn,
    );
  }

  /// A double tap on the empty Send of a session the server reports idle
  /// continues it, once, through the same send as typed text (#82).
  bool get _canContinue =>
      widget.controller.canSend &&
      _text.text.trim().isEmpty &&
      widget.controller.live.state?.execution?.kind.known == ExecutionKind.idle;

  /// Whether a continue is being sent: the field stays editable meanwhile,
  /// since the send does not take its text.
  bool _continuing = false;

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _continuing = true);
    try {
      await widget.controller.send('continue', fromDraft: false);
    } finally {
      if (mounted) setState(() => _continuing = false);
    }
  }

  Future<void> _send() async {
    final draft = _text;
    final sent = draft.text;
    final command = parseSessionBuiltinCommand(sent);
    if (command != null) return _run(command);
    final queue = context.read<AppPreferencesController?>()?.composerQueue;
    final clear = await widget.controller.send(
      sent,
      delivery: queue == true ? Delivery.queue : Delivery.steer,
    );
    // Text typed while the send was pending is the user's, never cleared.
    if (clear && draft.text == sent) draft.clear();
  }

  /// The delivery choice, opened from the Send button's own position: a hold,
  /// a right click, or the Menu key or Shift+F10 in the composer (#470).
  void _chooseSend(AppPreferencesController preferences) {
    final anchor = _sendAnchor.currentContext;
    if (anchor == null) return;
    unawaited(_chooseDelivery(anchor, preferences));
  }

  /// The default delivery menu, over the Send button: each choice says what
  /// it does, and the current one is checked.
  Future<void> _chooseDelivery(
    BuildContext anchor,
    AppPreferencesController preferences,
  ) async {
    unawaited(Feedback.forLongPress(anchor));
    final l10n = anchor.v2L10n;
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final current = preferences.composerQueue ? Delivery.queue : Delivery.steer;
    PopupMenuItem<Delivery> item(
      Delivery delivery,
      String key,
      String label,
      String hint,
    ) => PopupMenuItem<Delivery>(
      key: ValueKey(key),
      value: delivery,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(delivery == current ? Symbols.check : null),
        title: Text(label),
        subtitle: Text(hint),
      ),
    );
    final picked = await showMenu<Delivery>(
      context: anchor,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        item(
          Delivery.steer,
          'live-delivery-steer',
          l10n.composerSteer,
          l10n.composerSteerHint,
        ),
        item(
          Delivery.queue,
          'live-delivery-queue',
          l10n.composerQueue,
          l10n.composerQueueHint,
        ),
      ],
    );
    if (picked == null) return;
    preferences.setComposerQueue(picked == Delivery.queue);
  }

  String? _notice(V2Localizations l10n, ComposerNotice notice) =>
      switch (notice) {
        ComposerNotice.none => null,
        ComposerNotice.unconfirmed => l10n.composerNotConfirmed,
        ComposerNotice.notSaved => l10n.composerNoticeNotSaved,
        ComposerNotice.full => l10n.composerNoticeFull,
        ComposerNotice.unreadable => l10n.composerNoticeUnreadable,
        ComposerNotice.unavailable => l10n.composerNoticeUnavailable,
        ComposerNotice.conflict => l10n.composerNoticeConflict,
        ComposerNotice.identityOccupied => l10n.composerNoticeIdentity,
        ComposerNotice.authRequired => l10n.hostsAuthRequired,
        ComposerNotice.rateLimited => l10n.sessionsRateLimited,
        ComposerNotice.sessionGone => l10n.liveEvicted,
        ComposerNotice.rejected => l10n.composerNoticeRejected,
        ComposerNotice.cancelled => l10n.composerNoticeCancelled,
        ComposerNotice.deliveredFirst => l10n.composerNoticeDeliveredFirst,
        ComposerNotice.cancelPending => l10n.composerCancelling,
        ComposerNotice.switched => l10n.composerNoticeSwitched,
        ComposerNotice.switchNotApplied => l10n.composerNoticeSwitchNotApplied,
        ComposerNotice.changeFailed => l10n.composerNoticeChangeFailed,
        ComposerNotice.versionChanged => l10n.composerNoticeVersionChanged,
        ComposerNotice.sourceChanged => l10n.composerSourceChanged,
        ComposerNotice.sourceUnknown => l10n.composerSourceUnknown,
      };

  static String _preview(String text) {
    final head = text.runes.take(201).toList();
    return head.length > 200
        ? '${String.fromCharCodes(head.take(200))}…'
        : String.fromCharCodes(head);
  }

  Widget _action(
    String key,
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) => IconButton(
    key: ValueKey(key),
    icon: Icon(icon),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );

  /// One message the harness holds but has not taken yet (#486): one line,
  /// pinned above the status bar until it enters the conversation. Tapping it
  /// takes it back to edit, ✕ cancels it and ↑ delivers it now; each only
  /// when the harness can, and only for this device's own messages.
  Widget _waiting(BuildContext context, ComposerChip chip) {
    final l10n = context.v2L10n;
    final c = widget.controller;
    final entry = chip.entry;
    final queued =
        (entry?.delivery ?? chip.pending.delivery.known) == Delivery.queue;
    final fenced = entry != null && openFence(entry.fence);
    final uncertain = entry?.state == SubmissionKind.uncertain;
    final idle =
        !c.live.stopping &&
        (entry == null || !c.busy.contains(entry.commandId));
    final status = fenced
        ? l10n.composerCancelling
        : uncertain
        ? l10n.composerNotConfirmed
        : queued
        ? l10n.composerQueued
        : l10n.composerSteering;
    final label = entry == null
        ? '$status · ${l10n.composerOtherClient}'
        : status;
    final cancellable =
        entry != null && idle && c.cancelsPending && canCancel(entry);
    final steerable =
        entry != null && idle && queued && c.steersPending && canSwitch(entry);
    final checkable = entry != null && idle && (fenced || uncertain);
    final icon = fenced
        ? Symbols.hourglass_top
        : uncertain
        ? Symbols.help
        : entry == null
        ? Symbols.devices
        : queued
        ? Symbols.schedule
        : Symbols.bolt;
    return Material(
      key: ValueKey('live-waiting-${chip.pending.id.value}'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        onTapHint: cancellable && !c.sending ? l10n.composerWaitingEdit : null,
        child: InkWell(
          // The field is the send's while it runs.
          onTap: cancellable && !c.sending
              ? () => unawaited(_edit(entry.commandId))
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
              child: Row(
                children: [
                  Tooltip(
                    message: label,
                    child: Icon(icon, size: 18, semanticLabel: label),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _preview(chip.pending.text).replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (checkable)
                    _action(
                      'live-waiting-check-${entry.commandId.value}',
                      Symbols.refresh,
                      l10n.composerCheckAgain,
                      () => c.checkAgain(entry.commandId),
                    ),
                  if (cancellable)
                    _action(
                      'live-waiting-cancel-${entry.commandId.value}',
                      Symbols.close,
                      l10n.composerCancel,
                      () => c.cancel(entry.commandId),
                    ),
                  if (steerable)
                    _action(
                      'live-waiting-send-${entry.commandId.value}',
                      Symbols.arrow_upward,
                      l10n.composerSendNow,
                      () => c.switchDelivery(entry.commandId, Delivery.steer),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, OutboxEntry entry) {
    final l10n = context.v2L10n;
    final c = widget.controller;
    final id = entry.commandId.value;
    final localIdle = !c.busy.contains(entry.commandId);
    final idle =
        localIdle && !c.live.stopping && entry.source == OutboxSource.current;
    final fenced = openFence(entry.fence);
    final status = switch (entry.state) {
      _ when entry.source == OutboxSource.changed => l10n.composerSourceChanged,
      _ when entry.source == OutboxSource.unknown => l10n.composerSourceUnknown,
      _ when fenced => l10n.composerCancelling,
      SubmissionKind.sending => l10n.composerSending,
      SubmissionKind.rejected => l10n.composerNotSent,
      _ => l10n.composerNotConfirmed,
    };
    final uncertain = entry.state == SubmissionKind.uncertain;
    return Padding(
      key: ValueKey('live-row-$id'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              '${_preview(entry.text)} · $status',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (idle && (uncertain || fenced))
            TextButton(
              key: ValueKey('live-row-check-$id'),
              onPressed: () => c.checkAgain(entry.commandId),
              child: Text(l10n.composerCheckAgain),
            ),
          if (idle && uncertain && !fenced)
            TextButton(
              key: ValueKey('live-row-again-$id'),
              // Enabled only with an empty field, which gets the text back
              // if the new send does not take it.
              onPressed: c.canSend && _text.text.isEmpty
                  ? () => _sendAgain(entry.commandId)
                  : null,
              child: Text(l10n.composerSendAgain),
            ),
          if (localIdle && entry.source != OutboxSource.current)
            IconButton(
              key: ValueKey('live-row-inspect-$id'),
              tooltip: l10n.composerHint,
              icon: const Icon(Symbols.visibility),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.composerHint),
                  content: SingleChildScrollView(
                    child: SelectableText(entry.text),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
              ),
            ),
          if (localIdle && entry.state != SubmissionKind.sending)
            TextButton(
              key: ValueKey('live-row-discard-$id'),
              onPressed: () => c.discard(entry.commandId),
              child: Text(l10n.composerDiscard),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final l10n = context.v2L10n;
      final state = c.live.state;
      final chips = c.chips(state);
      final rows = c.rows(state, chips);
      final notice = _notice(l10n, c.notice);
      final canSend = _canSend;
      final preferences = context.watch<AppPreferencesController?>();
      final queue = preferences?.composerQueue ?? false;
      final choose = preferences == null
          ? null
          : () => _chooseSend(preferences);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: max(0, widget.maxHeight)),
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            key: const ValueKey('live-composer'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                // Leaves room for the field with the keyboard open.
                constraints: BoxConstraints(
                  maxHeight: min(200, MediaQuery.sizeOf(context).height * 0.2),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (chips.isNotEmpty)
                        // Oldest on top, one line each; past three the
                        // lines scroll.
                        ConstrainedBox(
                          key: const ValueKey('live-waiting'),
                          constraints: const BoxConstraints(maxHeight: 132),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 4),
                            children: [
                              for (final chip in chips)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _waiting(context, chip),
                                ),
                            ],
                          ),
                        ),
                      for (final entry in rows) _row(context, entry),
                    ],
                  ),
                ),
              ),
              Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  key: const ValueKey('live-composer-notice'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (notice != null) Text(notice),
                    if (c.live.endpointOffline && c.live.health != null)
                      EndpointHealthRecovery(
                        profile: c.live.profile,
                        health: c.live.health!,
                      ),
                    SessionStopNotice(live: c.live),
                    if (c.unreadable)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          key: const ValueKey('live-composer-reload'),
                          onPressed: c.reload,
                          child: Text(l10n.composerCheckAgain),
                        ),
                      ),
                    if (!c.canSend &&
                        !c.live.endpointOffline &&
                        !c.sending &&
                        !c.unreadable &&
                        !c.live.stopping)
                      Text(l10n.composerOffline),
                  ],
                ),
              ),
              SessionComposerStatus(
                activity: liveStatus(c.live, l10n),
                retryAt: liveRetryAt(c.live),
                now: c.live.clock,
              ),
              SessionCommandPicker(
                menu: _commands,
                onRun: _pick,
                maxHeight: _pickerRoom,
              ),
              SessionFieldHeightReporter(
                onHeight: _fieldMeasured,
                child: CallbackShortcuts(
                  bindings: {
                    if (choose != null) ...{
                      const SingleActivator(LogicalKeyboardKey.contextMenu):
                          choose,
                      const SingleActivator(
                        LogicalKeyboardKey.f10,
                        shift: true,
                      ): choose,
                    },
                  },
                  child: ComposerFrame(
                    attachTooltip: l10n.composerAttachSoon,
                    voiceTooltip: l10n.composerVoiceSoon,
                    chip: SessionModelChip(live: c.live),
                    field: (context, open) => Focus(
                      onKeyEvent: _key,
                      onFocusChange: (_) => _escapeAt = null,
                      child: ConversationTextScale(
                        child: TextField(
                          key: const ValueKey('live-composer-input'),
                          controller: _text,
                          focusNode: _focus,
                          // A text that a failed resend hands back needs the
                          // field untouched until the send ends.
                          readOnly:
                              (c.sending && !_continuing) ||
                              c.live.endpointOffline,
                          minLines: 1,
                          // A closed phone composer stays one line.
                          maxLines: open ? 4 : 1,
                          keyboardType: TextInputType.multiline,
                          autocorrect: composerSuggests(context),
                          enableSuggestions: composerSuggests(context),
                          spellCheckConfiguration:
                              composerSpellCheckConfiguration(context),
                          decoration: composerDecoration(
                            context,
                            open
                                ? l10n.composerHintCommands
                                : l10n.composerHint,
                          ),
                        ),
                      ),
                    ),
                    action: c.sending
                        ? SizedBox.square(
                            dimension: composerActionSize,
                            child: Center(
                              child: AppIndeterminateRing(
                                size: 18,
                                strokeWidth: 2,
                                semanticsLabel: l10n.composerSending,
                              ),
                            ),
                          )
                        : c.live.stopping ||
                              (c.live.canStop && _text.text.trim().isEmpty)
                        ? SessionStopButton(live: c.live)
                        // Holding Send, or a right click there, chooses how a
                        // prompt sent while the assistant works goes; the keys
                        // do the same from the composer (#470).
                        : KeyedSubtree(
                            key: _sendAnchor,
                            child: ComposerSendButton(
                              buttonKey: const ValueKey('live-composer-send'),
                              tooltip: queue
                                  ? l10n.composerQueue
                                  : l10n.composerSend,
                              icon: queue
                                  ? Symbols.schedule_send
                                  : Symbols.send_rounded,
                              onPressed: canSend ? _send : null,
                              onDoubleTap: _canContinue ? _continue : null,
                              onChoose: choose,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
