import 'dart:async';
import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../shared/l10n/l10n_context.dart';
import '../../shared/media/message_image.dart';
import '../../shared/rendering/canonical_message_body.dart';
import '../../shared/rendering/message_render_budget.dart';
import '../../shared/theme/chat_appearance.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'message_action_bar.dart';
import 'message_image_share.dart';
import 'session_attachment_strip.dart';
import 'session_compaction_note.dart';
import 'session_error_card.dart';
import 'session_message_info.dart';
import 'session_reasoning_body.dart';
import 'session_switch_note.dart';
import 'session_timeline_projection.dart';
import 'session_tool_result.dart';

/// Whether [item] is a final answer that shows its turn's speed and time
/// itself (#538): an answer with a valid rate, in a message.
bool ownsTurnStats(TimelineItem item, double? tokensPerSecond) =>
    item is AssistantText &&
    tokensPerSecond != null &&
    tokensPerSecond.isFinite &&
    tokensPerSecond > 0 &&
    item.meta.message != null;

/// Whether [item] ends with its turn's speed and time (#538): a final
/// answer that shows them, rendered rich. An answer over the rich budget
/// shows them in an elapsed chip above it instead.
bool showsInlineTurnStats(TimelineItem item, double? tokensPerSecond) =>
    ownsTurnStats(item, tokensPerSecond) &&
    MessageRenderBudget.decide((item as AssistantText).text).kind ==
        RenderDecisionKind.rich;

/// The messages whose final answer shows its speed and time, so no other
/// row of them repeats the elapsed time (#538).
Set<MessageRef> inlineTurnStatsMessages(
  Iterable<TimelineItem> items,
  Map<ItemId, double> tokensPerSecond,
) => {
  for (final item in items)
    if (ownsTurnStats(item, tokensPerSecond[item.id]))
      item.meta.message!.message,
};

/// The timeline's side margin: narrower on a phone, so the agent's text,
/// which has no card, uses the screen, yet not glued to its edge (#536).
double timelineSideInset(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? 12 : 16;

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
    this.turnTokensPerSecond,
    this.showElapsed = true,
    this.actions = const [],
    this.minimizeUnknownShell = false,
    this.highlighted = false,
  });
  final TimelineItem item;

  /// The message's actions beyond Copy all (undo, rewind, fork and the
  /// like), offered in its action bar (#539).
  final List<MessageAction> actions;
  final bool minimizeUnknownShell;
  final bool highlighted;
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

  /// Turn-level tokens per second for the final completed [AssistantText] of a
  /// turn when enabled in the Display menu (#499). Null for all other rows.
  final double? turnTokensPerSecond;

  /// Whether a message header shows its elapsed chip; off for a message
  /// whose final answer already ends with its time (#538).
  final bool showElapsed;

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
    if (item case Notice(kind: OpenValue(known: NoticeKind.skillActivated))) {
      final name = item.text.trim();
      if (name.isEmpty) return const SizedBox.shrink();
      return SessionLightNote(
        key: ValueKey('timeline-note-${item.id.value}'),
        text: '${l10n.toolKindSkill} · $name',
        icon: Symbols.auto_stories,
        rich: false,
      );
    }
    if (item case Notice(kind: OpenValue(known: NoticeKind.compaction))) {
      return SessionCompactionNote(
        key: ValueKey('timeline-compaction-${item.id.value}'),
        item: item,
        highlighted: highlighted,
        onTapLink: onTapLink,
        onTapFilePath: onTapFilePath,
        onCopyCode: onCopyCode,
        onCopyInlineCode: (code) => copyConversationText(context, code),
      );
    }
    // Reminders the harness adds, other system notes and unknown parts are
    // light lines, like the switch notes, so the conversation leads (#491).
    final light = switch (item) {
      Notice(
        kind: OpenValue(known: NoticeKind.system || NoticeKind.continuation),
        shellReport: null,
      ) =>
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
    final message = messageHeader ? item.meta.message : null;
    // Non-subagent tool calls, shell runs (when not minimized-unknown), and
    // reasoning render as lightweight compact rows without an outer Card or
    // vertical "Details" header.
    final compactTool =
        (item is ToolCall && item.kind.known != ToolKind.subagent) ||
        (item is ShellRun &&
            !(minimizeUnknownShell && item.shellStatus?.known == null)) ||
        (item is Notice && item.shellReport != null);
    if (compactTool) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ConversationTextScale(
            child: SessionToolResult(
              item: item,
              messageHeader: showElapsed ? message : null,
            ),
          ),
        ),
      );
    }
    if (item is Reasoning) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ConversationTextScale(
            child: SessionReasoningBody(
              text: item.text,
              complete: item.complete,
              duration: item.duration,
              messageHeader: showElapsed ? message : null,
              autoExpand: highlighted,
              storageKey: 'reasoning-${item.id.value}',
              child: SelectionArea(
                child: CanonicalMessageBody(
                  key: ValueKey('timeline-content-${item.id.value}'),
                  source: item.text,
                  complete: item.complete,
                  prefixMissing: item.prefixMissing,
                  allowBasicHtml: false,
                  onTapLink: onTapLink,
                  onTapFilePath: onTapFilePath,
                  onCopyCode: onCopyCode,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final (label, icon) = switch (item) {
      UserInput() => (l10n.chatMessageYou, Symbols.person_outline),
      AssistantText() => (l10n.historyAssistant, Symbols.chat_bubble_outline),
      Reasoning() => (l10n.chatThought, Symbols.psychology),
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
    final speed = ChatAppearance.showTokensPerSecondOf(context);
    final showTps = speed && showsInlineTurnStats(item, turnTokensPerSecond);
    // An answer over the rich budget shows its speed and time in a chip
    // above it, even when another row opened its message.
    final statsChip =
        speed && !showTps && ownsTurnStats(item, turnTokensPerSecond)
        ? item.meta.message
        : null;
    // A message whose final answer ends with its speed and time shows no
    // elapsed chip on its other rows either (#538).
    final elapsed = message != null && showElapsed;
    // A message without a time, a duration, TPS or an action has no header at
    // all, so it takes no space above its body. The user's bubble names no
    // sender: its color and side already do.
    // With the speed on, the final answer's speed and time follow its last
    // word instead of heading it (#538).
    final headerShown = switch (item) {
      AssistantText() =>
        clock != null || (elapsed && !showTps) || statsChip != null,
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.stretch,
        children: [
          if (headerShown) ...[
            if (item is UserInput)
              // The user's bubble names no sender and carries no elapsed chip;
              // keeping the clock unconstrained lets short prompts shrink-wrap.
              SelectionContainer.disabled(
                child: Text(
                  clock!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              )
            else if (item is AssistantText)
              // A message's header is its time; an assistant message's
              // duration and optional turn speed end the line. Selecting the
              // message's text leaves it out.
              SelectionContainer.disabled(
                child: showTps
                    ? Text(
                        clock!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      )
                    : Row(
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
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (statsChip != null)
                            MessageElapsedChip(
                              message: statsChip,
                              tokensPerSecond: turnTokensPerSecond,
                            )
                          else if (elapsed)
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
                  if (elapsed) MessageElapsedChip(message: message),
                ],
              ),
            const SizedBox(height: 8),
          ],
          _buildBody(
            context,
            l10n,
            trailing: showTps
                ? formatInlineTurnStats(
                    turnTokensPerSecond!,
                    item.meta.message!,
                  )
                : null,
          ),
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
    // A prompt the harness has not taken yet is still on its way: a weaker
    // fill that slowly breathes, and no actions of its own (#502).
    final waiting = item is UserInput && sessionPromptWaits(item);
    Widget card(double alpha) => Card(
      color: isUser
          ? colorScheme.primaryContainer.withValues(alpha: alpha)
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
    final tile = item is AssistantText
        ? body
        : waiting
        ? _WaitingFill(
            builder: card,
            // Deliberate decision (owner, #502): a waiting prompt shows no
            // Cancel, nor any other action; it simply looks sent. Should a
            // Cancel return, it is a link at the bubble's bottom end, under
            // the body inside `card`, shown only for this device's prompts
            // when the harness can cancel (`PromptOutbox.cancelsPending`).
            // It needs an `onCancelWaiting` callback on this tile, passed
            // down from the live page: it finds this device's outbox entry
            // whose `messageId` is `nativeMessageOf(item.id)`, as
            // `SessionComposerController.chips` does, and calls `cancel` (or
            // `takeBack` to edit) with that entry's `commandId`:
            //
            // Align(
            //   alignment: AlignmentDirectional.bottomEnd,
            //   child: TextButton(
            //     key: ValueKey('waiting-cancel-${item.id.value}'),
            //     onPressed: () => onCancelWaiting?.call(item),
            //     child: Text(l10n.composerCancel),
            //   ),
            // ),
          )
        : card(0.7);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final candidateW = isUser ? min(640.0, maxW * 0.85) : min(760.0, maxW);
        final text = switch (item) {
          UserInput(:final text) || AssistantText(:final text) => text,
          _ => null,
        };
        final bubble = ConversationTextScale(
          // The sender is no longer written on the bubble; screen readers
          // still hear it.
          child: isUser
              ? Semantics(
                  container: true,
                  // A waiting prompt may be another client's: its state,
                  // not its sender (#502).
                  label: waiting
                      ? item.delivery.known == DeliveryState.queued
                            ? l10n.composerQueued
                            : l10n.composerSteering
                      : l10n.chatMessageYou,
                  child: Align(
                    alignment: Alignment.center,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: tile,
                  ),
                )
              : tile,
        );
        final bounds = BoxConstraints(
          minHeight: isUser ? 48.0 : 0.0,
          maxWidth: candidateW,
        );
        // A prompt still on its way has no actions of its own (#502); its
        // text stays selectable.
        if (text != null && !waiting) {
          final imageMode = messageImageMode(context);
          return MessageActionHost(
            key: ValueKey('message-row-${item.id.value}'),
            end: isUser,
            constraints: bounds,
            actions: [
              if (text.isNotEmpty)
                MessageAction(
                  id: MessageActionId.copy,
                  label: l10n.messageCopyAll,
                  icon: Symbols.content_copy,
                  onSelected: (context) => copyConversationText(context, text),
                ),
              // The whole message only: never a streaming answer, one whose
              // start history lost, one shown only in part for its length,
              // or one with nothing to show (#540).
              if (imageMode != MessageImageMode.none &&
                  MessageRenderBudget.decide(text).kind !=
                      RenderDecisionKind.plainTruncated &&
                  switch (item) {
                    AssistantText(:final complete, :final prefixMissing) =>
                      complete && !prefixMissing && text.trim().isNotEmpty,
                    UserInput(:final attachments) =>
                      text.trim().isNotEmpty || attachments.isNotEmpty,
                    _ => false,
                  })
                MessageAction(
                  id: MessageActionId.shareImage,
                  label: imageMode == MessageImageMode.save
                      ? l10n.messageSaveImage
                      : l10n.messageShareImage,
                  icon: imageMode == MessageImageMode.save
                      ? Symbols.download
                      : Symbols.share,
                  onSelected: (context) =>
                      unawaited(shareMessageImage(context)),
                ),
              ...actions,
            ],
            child: KeyedSubtree(
              key: ValueKey('message-bubble-${item.id.value}'),
              child: bubble,
            ),
          );
        }
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: bounds,
            child: text != null ? SelectionArea(child: bubble) : bubble,
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, dynamic l10n, {String? trailing}) {
    final item = this.item;
    switch (item) {
      // A message's text is always selectable (#539): its host wraps it in
      // a selection area.
      case UserInput(:final text, :final attachments):
        final messageBody = text.isEmpty
            ? null
            : CanonicalMessageBody(
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
        if (attachments.isEmpty) {
          return messageBody ??
              CanonicalMessageBody(
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
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SessionAttachmentStrip(attachments: attachments),
            if (messageBody != null) ...[
              const SizedBox(height: 8),
              messageBody,
            ],
          ],
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
          trailingText: trailing,
          trailingStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          onTapTrailing: trailing == null
              ? null
              : () => showMessageInfoDialog(
                  context,
                  item.meta.message!,
                  tokensPerSecond: turnTokensPerSecond,
                ),
          // Read whole, with the precise localized speed.
          trailingSemanticsLabel: trailing == null
              ? null
              : [
                  context.v2L10n.msgInfoMessageInfo,
                  formatTokensPerSecond(turnTokensPerSecond!, context),
                  ?formatMessageElapsed(item.meta.message!),
                ].join(', '),
        );
      case Reasoning():
        return const SizedBox.shrink();
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
      case ToolCall():
        return SessionSubagentToolBody(item: item);
      case ShellRun():
        return const SizedBox.shrink();
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

/// One light line in the timeline (#491): a small info mark and the text in
/// one muted line, the whole of it on a tap.
class SessionLightNote extends StatefulWidget {
  const SessionLightNote({
    super.key,
    required this.text,
    this.icon = Symbols.info,
    this.rich = true,
    this.onTapLink,
    this.onTapFilePath,
    this.onCopyCode,
  });

  final String text;
  final IconData icon;

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
    final richOpen = _open && widget.rich;
    final icon = Icon(widget.icon, size: 16, color: muted);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (richOpen)
            Semantics(
              button: true,
              expanded: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _open = false),
                child: Padding(padding: const EdgeInsets.all(2), child: icon),
              ),
            )
          else
            icon,
          const SizedBox(width: 8),
          Flexible(
            child: richOpen
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
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
          ),
        ],
      ),
    );
    return ConversationTextScale(
      child: richOpen
          ? row
          : Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _open = !_open),
                child: row,
              ),
            ),
    );
  }
}

/// The fill of a prompt still waiting for the harness (#502): weaker than a
/// sent prompt's and slowly breathing, held still with reduced motion.
class _WaitingFill extends StatefulWidget {
  const _WaitingFill({required this.builder});

  /// The bubble, given its fill's opacity.
  final Widget Function(double alpha) builder;

  static const breath = Duration(milliseconds: 1600);

  @override
  State<_WaitingFill> createState() => _WaitingFillState();
}

class _WaitingFillState extends State<_WaitingFill>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: _WaitingFill.breath,
    value: 0.5,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _breath,
    builder: (context, _) =>
        widget.builder(0.2 + 0.25 * Curves.easeInOut.transform(_breath.value)),
  );
}
