import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/rendering/canonical_message_body.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'session_error_card.dart';
import 'session_message_info.dart';
import 'session_reasoning_body.dart';
import 'session_switch_note.dart';
import 'session_tool_result.dart';

/// The timeline's side margin: narrow on a phone, so the agent's text,
/// which has no card, reaches close to the screen's edge.
double timelineSideInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? 8 : 16;

/// The running text of the user's and the agent's messages: one Material
/// step above the app's body text (#489). The conversation text scale still
/// multiplies it.
TextStyle? conversationBodyStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge;

/// Copies [text] and says so, as every copy in the conversation does.
void copyConversationText(BuildContext context, String text) {
  unawaited(Clipboard.setData(ClipboardData(text: text)));
  showAppSnackBar(
    ScaffoldMessenger.maybeOf(context),
    context.v2L10n.commonCopiedToClipboard,
  );
}

/// An option a message offers in its menu beside Copy and Select (#492).
final class SessionBubbleAction {
  const SessionBubbleAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final IconData icon;

  /// Runs the option; [context] is the message's, for any confirmation.
  final void Function(BuildContext context) onSelected;
}

/// One read-only timeline item, shared by the history and live views.
///
/// V2-071A: text-bearing canonical items render rich Markdown/math/HTML/
/// Mermaid/code via [CanonicalMessageBody] bound to canonical fields only.
/// V2-044D: tool and shell items show what ran and how it stands, with their
/// bounded, redacted input, output and error in a dialog on demand
/// ([SessionToolResult]). Reasoning shows a few lines and the rest on demand
/// ([SessionReasoningBody]). V2-055A: a failed turn that carries its typed
/// error shows a [SessionErrorCard]. Other outcome and unknown items keep minimized
/// markers and never expose `raw` or fallback text. No legacy imports (G4).
class SessionTimelineTile extends StatelessWidget {
  const SessionTimelineTile({
    super.key,
    required this.item,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
    this.errorRecovery,
    this.onOpenChild,
    this.messageHeader = false,
    this.revert,
    this.minimizeUnknownShell = false,
  });
  final TimelineItem item;

  /// The user turn's revert (undo this turn, or rewind and edit from here),
  /// offered in the message's menu. Null for none.
  final SessionBubbleAction? revert;
  final bool minimizeUnknownShell;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;

  /// The recovery an error card offers here; null in the read-only history,
  /// whose cards show no button.
  final SessionErrorRecovery? Function(ErrorInfo error)? errorRecovery;

  /// Opens the sub-conversation a subagent call runs; the whole card is the
  /// way in, and its own controls keep their taps. Null for none.
  final ValueChanged<ToolCall>? onOpenChild;

  /// Whether this item opens its message, so its header shows the message's
  /// elapsed time and details.
  final bool messageHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final item = this.item;
    if (item case Notice(
      kind: OpenValue(known: NoticeKind.selectionChanged),
      :final selection?,
    )) {
      return SessionSwitchNote(
        key: ValueKey('timeline-switch-${item.id.value}'),
        selection: selection,
      );
    }
    // Reminders the harness adds, other system notes, a compaction that did
    // not fail and unknown parts are light lines, like the switch notes, so
    // the conversation leads (#491).
    final light = switch (item) {
      Notice(
        kind: OpenValue(known: NoticeKind.system || NoticeKind.continuation),
      ) =>
        item.text,
      // A compaction says nothing until it ends: its card stands till then.
      Notice(
        kind: OpenValue(known: NoticeKind.compaction),
        status: OpenValue(known: final status),
      )
          when status != ItemStatus.failed && item.text.trim().isNotEmpty =>
        item.text,
      UnknownItem() => l10n.chatMessageMessagePartUnavailable,
      _ => null,
    };
    if (light != null) {
      // A note with nothing to say, such as an instructions update that
      // rendered empty, takes no room.
      if (light.trim().isEmpty) return const SizedBox.shrink();
      return SessionLightNote(
        key: ValueKey('timeline-note-${item.id.value}'),
        text: light,
        // An unknown part has nothing more to show.
        rich: item is Notice,
        onTapLink: onTapLink,
        onTapFilePath: onTapFilePath,
        onCopyCode: onCopyCode,
      );
    }
    if (item is Notice && item.kind.known == NoticeKind.interruption) {
      return ConversationTextScale(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(l10n.liveStepInterrupted),
        ),
      );
    }
    if (item is TurnOutcome && item.kind.known == OutcomeKind.failed) {
      final error = item.error;
      if (error != null) {
        return ConversationTextScale(
          child: SessionErrorCard(
            error: error,
            recovery: errorRecovery?.call(error),
          ),
        );
      }
    }
    final (label, icon) = switch (item) {
      UserInput() => (l10n.chatMessageYou, Symbols.person_outline),
      AssistantText() => (l10n.historyAssistant, Symbols.chat_bubble_outline),
      // Compact screens use the retained reference's short label.
      Reasoning() => (
        MediaQuery.sizeOf(context).width < 600
            ? l10n.chatMessageThinking
            : l10n.chatMessageThinkingProcess,
        Symbols.psychology,
      ),
      Notice() => (l10n.historyDetails, Symbols.info),
      ToolCall() => (l10n.historyDetails, Symbols.build),
      ShellRun() => (l10n.historyDetails, Symbols.terminal),
      TurnOutcome() => (l10n.historyDetails, Symbols.flag),
      UnknownItem() => (l10n.historyDetails, Symbols.info),
    };
    final open = onOpenChild;
    final child = item is ToolCall && item.kind.known == ToolKind.subagent
        ? open
        : null;
    final message = messageHeader ? item.meta.message : null;
    final isUser = item is UserInput;
    final assistant = !isUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final created = message?.created;
    final clock = created == null
        ? null
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(created.toLocal()),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
    // A message without a time, a duration or an action has no header at
    // all, so it takes no space above its body. The user's bubble names no
    // sender: its color and side already do.
    final headerShown = switch (item) {
      AssistantText() => clock != null || message != null,
      UserInput() => clock != null,
      _ => true,
    };
    final body = Padding(
      // The agent's text sits on the page, with no card and no inset of its
      // own; every other item keeps the compact bubble padding.
      padding: item is AssistantText
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerShown) ...[
            if (item is UserInput || item is AssistantText)
              // A message's header is its time; an assistant message's
              // duration ends the line. Selecting the message's text leaves
              // it out.
              SelectionContainer.disabled(
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (clock != null)
                            Flexible(
                              child: Text(
                                clock,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item is AssistantText && message != null)
                      MessageElapsedChip(message: message),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(label, style: theme.textTheme.titleSmall),
                    ),
                  ),
                  if (message != null) MessageElapsedChip(message: message),
                ],
              ),
            const SizedBox(height: 8),
          ],
          _buildBody(context, l10n),
        ],
      ),
    );
    // Asymmetric bubble radius with tighter trailing corner for messaging
    // feel; the fill alone sets the bubble apart, with no outline.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16).copyWith(
        bottomRight: isUser
            ? const Radius.circular(4)
            : const Radius.circular(16),
        bottomLeft: assistant
            ? const Radius.circular(4)
            : const Radius.circular(16),
      ),
    );
    final tile = item is AssistantText
        ? body
        : Card(
            color: isUser
                ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                : null,
            shape: shape,
            clipBehavior: child != null ? Clip.antiAlias : Clip.none,
            child: child != null
                ? Semantics(
                    button: true,
                    child: InkWell(
                      key: ValueKey('subagent-open-${item.id.value}'),
                      onTap: () => child(item as ToolCall),
                      child: body,
                    ),
                  )
                : body,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final candidateW = isUser
            ? max(220.0, min(640.0, maxW * 0.85))
            : min(760.0, maxW);
        final text = switch (item) {
          UserInput(:final text) || AssistantText(:final text) => text,
          _ => null,
        };
        Widget bubble = ConversationTextScale(
          // The sender is no longer written on the bubble; screen readers
          // still hear it.
          child: isUser
              ? Semantics(
                  container: true,
                  label: l10n.chatMessageYou,
                  child: tile,
                )
              : tile,
        );
        if (text != null) {
          bubble = _MessageBubble(
            key: ValueKey('message-bubble-${item.id.value}'),
            text: text,
            revert: isUser ? revert : null,
            child: bubble,
          );
        }
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: candidateW),
            child: bubble,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, dynamic l10n) {
    final item = this.item;
    switch (item) {
      // A message selects its text only on request (#492): an always-on
      // selection would take the long press its menu needs.
      case UserInput(:final text):
        return CanonicalMessageBody(
          key: ValueKey('timeline-content-${item.id.value}'),
          source: text,
          complete: true,
          allowBasicHtml: false,
          bodyStyle: conversationBodyStyle(context),
          onTapLink: onTapLink,
          onTapFilePath: onTapFilePath,
          onCopyCode: onCopyCode,
          onCopyInlineCode: (code) => copyConversationText(context, code),
        );
      case AssistantText(:final text, :final complete, :final prefixMissing):
        return CanonicalMessageBody(
          key: ValueKey('timeline-content-${item.id.value}'),
          source: text,
          complete: complete,
          prefixMissing: prefixMissing,
          allowBasicHtml: true,
          bodyStyle: conversationBodyStyle(context),
          onTapLink: onTapLink,
          onTapFilePath: onTapFilePath,
          onCopyCode: onCopyCode,
          onCopyInlineCode: (code) => copyConversationText(context, code),
        );
      case Reasoning(:final text, :final complete, :final prefixMissing):
        return SessionReasoningBody(
          text: text,
          complete: complete,
          child: SelectionArea(
            child: CanonicalMessageBody(
              key: ValueKey('timeline-content-${item.id.value}'),
              source: text,
              complete: complete,
              prefixMissing: prefixMissing,
              allowBasicHtml: false,
              onTapLink: onTapLink,
              onTapFilePath: onTapFilePath,
              onCopyCode: onCopyCode,
            ),
          ),
        );
      case Notice(:final text):
        return SelectionArea(
          child: CanonicalMessageBody(
            key: ValueKey('timeline-content-${item.id.value}'),
            source: text,
            complete: true,
            allowBasicHtml: false,
            onTapLink: onTapLink,
            onTapFilePath: onTapFilePath,
            onCopyCode: onCopyCode,
          ),
        );
      case ShellRun(:final shellStatus)
          when minimizeUnknownShell && shellStatus?.known == null:
        return Text(
          l10n.chatMessageMessagePartUnavailable as String,
          maxLines: 16,
          overflow: TextOverflow.ellipsis,
        );
      case ToolCall() || ShellRun():
        return SessionToolResult(item: item);
      case TurnOutcome(:final kind):
        final text = switch (kind.known) {
          OutcomeKind.succeeded => l10n.liveOutcomeSucceeded as String,
          OutcomeKind.failed => l10n.liveOutcomeFailed as String,
          OutcomeKind.interrupted => l10n.liveOutcomeInterrupted as String,
          null => l10n.chatMessageMessagePartUnavailable as String,
        };
        return Text(text, maxLines: 16, overflow: TextOverflow.ellipsis);
      case UnknownItem():
        // Minimized neutral marker: never expose fallbackText/rawType.
        return Text(
          l10n.chatMessageMessagePartUnavailable as String,
          maxLines: 16,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}

enum _BubbleChoice { revert, copy, select }

class _OpenMenuIntent extends Intent {
  const _OpenMenuIntent();
}

/// Escape while selecting: its own intent, since the selection's region
/// takes the shared dismiss intent to hide its toolbar first.
class _StopSelectingIntent extends Intent {
  const _StopSelectingIntent();
}

/// A message's own gestures (#492): a double tap copies its whole text, and
/// a long press, a secondary click or the Menu key offers Revert (on the
/// user's own turns, where the session can), Copy all text and Select text.
/// Selecting is a mode of this message alone, until Escape, a tap outside
/// it or a copy from its toolbar.
class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.text,
    required this.revert,
    required this.child,
  });

  /// The message's canonical text, as the harness sent it.
  final String text;
  final SessionBubbleAction? revert;
  final Widget child;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  // The message keeps its state while the selection wraps it and lets go.
  final _content = GlobalKey();
  final _selection = GlobalKey<SelectionAreaState>();
  final _selectionFocus = FocusNode(debugLabel: 'message selection');
  bool _selecting = false;
  bool _highlight = false;

  // Whether the selection took the focus: it ends when the focus moves on,
  // as when another selectable item (reasoning, a notice) is tapped, which
  // shares the selection's tap group.
  bool _selectionFocused = false;

  // A double tap is read from raw pointers rather than a double-tap
  // recognizer, which would hold every single tap on the message's own
  // controls (links, the elapsed chip, copy buttons) for its timeout.
  Offset? _downAt;
  Offset? _lastTapAt;
  Timer? _lastTapTimer;

  @override
  void initState() {
    super.initState();
    _selectionFocus.addListener(_selectionFocusChanged);
  }

  void _selectionFocusChanged() {
    if (_selectionFocus.hasFocus) {
      _selectionFocused = true;
    } else if (_selectionFocused) {
      _stopSelecting();
    }
  }

  @override
  void dispose() {
    _lastTapTimer?.cancel();
    _selectionFocus.dispose();
    super.dispose();
  }

  void _copyAll() => copyConversationText(context, widget.text);

  void _pointerDown(PointerDownEvent event) {
    _downAt = event.buttons == kPrimaryButton ? event.position : null;
  }

  void _pointerUp(PointerUpEvent event) {
    final downAt = _downAt;
    _downAt = null;
    if (_selecting || downAt == null) return;
    // Only a tap counts: a press that did not travel or turn into the long
    // press, which clears [_downAt].
    if ((event.position - downAt).distance > kTouchSlop) {
      _lastTapAt = null;
      return;
    }
    final lastAt = _lastTapAt;
    if (lastAt != null &&
        (_lastTapTimer?.isActive ?? false) &&
        (downAt - lastAt).distance <= kDoubleTapSlop) {
      _lastTapTimer?.cancel();
      _lastTapAt = null;
      // After this pointer's own taps, so a copy a control inside the
      // message makes (inline code, a code block) cannot replace it.
      scheduleMicrotask(() {
        if (mounted) _copyAll();
      });
      return;
    }
    _lastTapAt = event.position;
    _lastTapTimer?.cancel();
    _lastTapTimer = Timer(kDoubleTapTimeout, () => _lastTapAt = null);
  }

  void _select() {
    setState(() => _selecting = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_selecting) return;
      _selectionFocus.requestFocus();
      _selection.currentState?.selectableRegion.selectAll();
      // The handles and the toolbar need the selection's geometry, which the
      // next frame lays out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_selecting) return;
        _selection.currentState?.selectableRegion.selectAll(
          SelectionChangedCause.toolbar,
        );
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _stopSelecting() {
    _selectionFocused = false;
    if (!_selecting) return;
    setState(() => _selecting = false);
  }

  Future<void> _openMenu([Offset? at]) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box == null || overlay is! RenderBox) return;
    final point = overlay.globalToLocal(
      at ?? box.localToGlobal(box.size.center(Offset.zero)),
    );
    final l10n = context.v2L10n;
    final revert = widget.revert;
    unawaited(HapticFeedback.selectionClick());
    final choice = await showMenu<_BubbleChoice>(
      context: context,
      position: RelativeRect.fromRect(
        point & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        if (revert != null)
          _item(_BubbleChoice.revert, revert.icon, revert.label),
        _item(_BubbleChoice.copy, Symbols.content_copy, l10n.messageCopyAll),
        _item(_BubbleChoice.select, Symbols.select_all, l10n.messageSelectText),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case _BubbleChoice.revert:
        revert?.onSelected(context);
      case _BubbleChoice.copy:
        _copyAll();
      case _BubbleChoice.select:
        _select();
      case null:
        break;
    }
  }

  PopupMenuItem<_BubbleChoice> _item(
    _BubbleChoice choice,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    key: ValueKey('message-menu-${choice.name}'),
    value: choice,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.v2L10n;
    final revert = widget.revert;
    Widget content = KeyedSubtree(key: _content, child: widget.child);
    if (_selecting) {
      content = TapRegion(
        // The selection's handles and toolbar live in the overlay, in this
        // group, so touching them does not end the selection.
        groupId: SelectableRegion,
        onTapOutside: (_) => _stopSelecting(),
        child: SelectionArea(
          key: _selection,
          focusNode: _selectionFocus,
          // A copy from the toolbar ends the selection, as it does on a
          // native text view.
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: [
                  for (final button in state.contextMenuButtonItems)
                    button.type == ContextMenuButtonType.copy
                        ? button.copyWith(
                            onPressed: () {
                              button.onPressed?.call();
                              _stopSelecting();
                            },
                          )
                        : button,
                ],
              ),
          child: content,
        ),
      );
    }
    return Semantics(
      container: true,
      customSemanticsActions: {
        if (revert != null)
          CustomSemanticsAction(label: revert.label): () =>
              revert.onSelected(context),
        CustomSemanticsAction(label: l10n.messageCopyAll): _copyAll,
        CustomSemanticsAction(label: l10n.messageSelectText): _select,
      },
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlight = value),
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.contextMenu):
              const _OpenMenuIntent(),
          const SingleActivator(LogicalKeyboardKey.f10, shift: true):
              const _OpenMenuIntent(),
          if (_selecting)
            const SingleActivator(LogicalKeyboardKey.escape):
                const _StopSelectingIntent(),
        },
        actions: {
          _OpenMenuIntent: CallbackAction<_OpenMenuIntent>(
            onInvoke: (_) => unawaited(_openMenu()),
          ),
          _StopSelectingIntent: CallbackAction<_StopSelectingIntent>(
            onInvoke: (_) => _stopSelecting(),
          ),
        },
        child: GestureDetector(
          // The whole message answers, its padding and line ends included.
          behavior: HitTestBehavior.translucent,
          onLongPressStart: _selecting
              ? null
              : (details) {
                  _downAt = null;
                  unawaited(_openMenu(details.globalPosition));
                },
          onSecondaryTapUp: _selecting
              ? null
              : (details) => unawaited(_openMenu(details.globalPosition)),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _pointerDown,
            onPointerUp: _pointerUp,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: _highlight
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : const BoxDecoration(),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// One light line in the timeline (#491): a small info mark and the text in
/// one muted line, the whole of it on a tap.
class SessionLightNote extends StatefulWidget {
  const SessionLightNote({
    super.key,
    required this.text,
    this.rich = true,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
  });

  final String text;

  /// Whether the open note renders its text as Markdown, selectable, with
  /// links, file paths and code copy working.
  final bool rich;
  final void Function(String text, String href, String? title)? onTapLink;
  final void Function(String path, int? line, int? col)? onTapFilePath;
  final ValueChanged<String>? onCopyCode;

  @override
  State<SessionLightNote> createState() => _SessionLightNoteState();
}

class _SessionLightNoteState extends State<SessionLightNote> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final text = widget.text.trim();
    return ConversationTextScale(
      child: Semantics(
        button: true,
        expanded: _open,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.info, size: 16, color: muted),
                const SizedBox(width: 8),
                Flexible(
                  child: _open && widget.rich
                      ? SelectionArea(
                          child: CanonicalMessageBody(
                            source: text,
                            complete: true,
                            allowBasicHtml: false,
                            bodyStyle: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                            onTapLink: widget.onTapLink,
                            onTapFilePath: widget.onTapFilePath,
                            onCopyCode: widget.onCopyCode,
                          ),
                        )
                      : Text(
                          _open ? text : text.replaceAll(RegExp(r'\s+'), ' '),
                          maxLines: _open ? null : 1,
                          overflow: _open ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
