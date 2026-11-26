import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../shared/theme/chat_appearance.dart';

/// One row of the timeline: a resident item, a subagent call/report group, a
/// collapsed activity stretch, or a Block-mode pending placeholder.
///
/// Rows are presentation only: canonical items stay untouched, and every row
/// knows the items it stands for, so the timeline still places its center and
/// measures arrivals on the items themselves.
sealed class SessionTimelineRow {
  const SessionTimelineRow();

  /// The row's identity in the list, stable while the row shows the same
  /// content, so a rebuild keeps its element and what the reader opened.
  Key get key;

  /// The resident items the row shows or stands for, in order.
  List<TimelineItem> get items;
}

/// A single resident item.
final class SessionItemRow extends SessionTimelineRow {
  const SessionItemRow(this.item, {required this.messageHeader});

  final TimelineItem item;

  /// Whether the item opens its message, so it shows the message details.
  final bool messageHeader;

  @override
  Key get key => ValueKey(item.id);

  @override
  List<TimelineItem> get items => [item];
}

/// Consecutive replies, anchored to the first while more arrive.
final class SessionReportRow extends SessionTimelineRow {
  const SessionReportRow(this.reports);
  final List<Notice> reports;
  @override
  Key get key => ValueKey(reports.first.id);
  @override
  List<TimelineItem> get items => reports;
}

/// A compact summary which opens the original call rows and message headers.
final class SessionSubagentCallsRow extends SessionTimelineRow {
  SessionSubagentCallsRow(this.calls);
  final List<SessionItemRow> calls;

  @override
  Key get key => calls.first.key;
  @override
  List<TimelineItem> get items => [for (final call in calls) call.item];
}

bool _subagentCall(TimelineItem item) =>
    item is ToolCall && item.kind.known == ToolKind.subagent;

/// Use original adjacency so folding work or hiding tools cannot join
/// reports from opposite sides of an intervening item.
List<SessionTimelineRow> groupSubagentActivity(
  List<SessionTimelineRow> rows,
  List<TimelineItem> original,
) {
  if (!original.any(
    (item) => _subagentCall(item) || item is Notice && item.report != null,
  )) {
    return rows;
  }
  final follows = <ItemId, ItemId>{};
  for (var i = 1; i < original.length; i++) {
    final item = original[i];
    if (_subagentCall(item) || item is Notice && item.report != null) {
      follows[original[i].id] = original[i - 1].id;
    }
  }
  final grouped = <SessionTimelineRow>[];
  var run = <Notice>[];
  var calls = <SessionItemRow>[];
  for (final row in rows) {
    if (row case SessionItemRow(
      item: final Notice notice,
    ) when notice.report != null) {
      if (run.isEmpty || follows[notice.id] != run.last.id) {
        run = [];
        grouped.add(SessionReportRow(run));
      }
      run.add(notice);
      calls = [];
    } else if (row is SessionItemRow && _subagentCall(row.item)) {
      if (calls.isEmpty || follows[row.item.id] != calls.last.item.id) {
        calls = [];
        grouped.add(SessionSubagentCallsRow(calls));
      }
      calls.add(row);
      run = [];
    } else {
      run = [];
      calls = [];
      grouped.add(row);
    }
  }
  return grouped;
}

/// A maximal contiguous stretch of non-text activity (reasoning, shell runs,
/// and non-subagent tool calls) collapsed into one descriptive summary row.
///
/// [AssistantText] items are never members: every assistant text response stays
/// visible in the conversation forever.
final class SessionActivityStretchRow extends SessionTimelineRow {
  const SessionActivityStretchRow(
    this.work, {
    required this.id,
    required this.expanded,
    required this.messageHeaders,
    required this.runningCount,
    required this.failedCount,
  });

  /// Anchored to the stretch's first item, never to a list position or a
  /// generation, so a passive refresh keeps the same row and toggle state.
  final String id;

  final List<TimelineItem> work;
  final bool expanded;

  /// For each item in [work], whether it opens its harness message.
  final List<bool> messageHeaders;

  /// Items in this stretch still pending, streaming, or running.
  final int runningCount;

  /// Items in this stretch that failed, timed out, were killed, or interrupted.
  final int failedCount;

  /// The first harness message opened inside this stretch, shown on the
  /// collapsed header so message details stay reachable.
  MessageContext? get openingMessage {
    for (var i = 0; i < work.length; i++) {
      if (messageHeaders[i] && work[i].meta.message != null) {
        return work[i].meta.message;
      }
    }
    return null;
  }

  @override
  Key get key => ValueKey(id);

  @override
  List<TimelineItem> get items => work;
}

/// Where the Block render mode holds the rest of a turn in flight: after
/// what it already published, while the response is generated.
final class SessionPendingRow extends SessionTimelineRow {
  const SessionPendingRow(this.anchor);

  /// The prompt the turn answers, or its first item without one, so the row
  /// keeps its identity while the turn runs.
  final ItemId anchor;

  @override
  Key get key => ValueKey('pending-${anchor.value}');

  @override
  List<TimelineItem> get items => const [];
}

/// How the live and history timelines present their resident items:
/// non-text activity stretches collapse into descriptive summaries as soon as
/// following visible answer text arrives (or when settled), while every
/// [AssistantText] stays visible forever.
///
/// Keeps what the reader opened and which trailing stretches settled for as
/// long as the owning timeline is shown; reopening a session starts collapsed.
final class SessionTimelinePresentation {
  final Set<String> _expanded = {};

  /// Trailing stretches already collapsed on settle, with their length, so a
  /// brief busy status pulse does not pop them back open until new items arrive.
  Map<String, int> _settledTrailing = {};

  bool isExpanded(String id) => _expanded.contains(id);

  /// Opens or closes an activity stretch.
  void toggle(String id) {
    if (!_expanded.remove(id)) _expanded.add(id);
  }

  /// Whether [item] participates in non-text activity stretch compaction.
  ///
  /// Every [AssistantText], [UserInput], [Notice], [TurnOutcome],
  /// [UnknownItem], unknown-status [ShellRun], and subagent [ToolCall] stays
  /// outside stretches.
  static bool isCompactable(TimelineItem item) => switch (item) {
    Reasoning() => true,
    ShellRun(:final shellStatus) => shellStatus?.known != null,
    ToolCall(:final kind) =>
      kind.known != ToolKind.subagent && kind.known != ToolKind.plan,
    Notice(shellReport: _?) => true,
    _ => false,
  };

  /// The rows of [items]. [settled] tells whether the session has no turn in
  /// flight, so a trailing stretch with no following text may also collapse.
  ///
  /// Reasoning and tool calls the reader hid are filtered out before grouping,
  /// so an emptied stretch emits no row (#108). In Block render mode, the turn
  /// in flight hides unfinished answers and reasoning until they end (#284).
  List<SessionTimelineRow> project(
    List<TimelineItem> items, {
    required bool settled,
    bool showReasoning = true,
    bool showToolCalls = true,
    ChatRenderMode renderMode = ChatRenderMode.live,
  }) {
    final original = items;
    items = sessionTimelineItems(items);
    final out = _Rows(
      this,
      showReasoning: showReasoning,
      showToolCalls: showToolCalls,
    );
    final latched = <String, int>{};
    final block = renderMode == ChatRenderMode.block && !settled;
    var index = 0;
    while (index < items.length) {
      if (items[index] is UserInput) {
        out.emitSingle(items[index]);
        index++;
        continue;
      }
      // A turn: everything up to the next prompt.
      var end = index;
      while (end < items.length && items[end] is! UserInput) {
        end++;
      }
      final last = end == items.length;
      _turn(
        items,
        index,
        end,
        out,
        latched,
        settled: settled || !last,
        held: block && last,
      );
      index = end;
    }
    // A prompt still waiting for its first answer.
    if (block) {
      if (items.lastOrNull case final UserInput prompt) {
        out.rows.add(SessionPendingRow(prompt.id));
      }
    }
    _settledTrailing = latched;
    return groupSubagentActivity(out.rows, original);
  }

  void _turn(
    List<TimelineItem> items,
    int start,
    int end,
    _Rows out,
    Map<String, int> latched, {
    required bool settled,
    required bool held,
  }) {
    if (held) {
      _held(items, start, end, out, latched);
      return;
    }
    _emitTurn(items.sublist(start, end), out, latched, settled: settled);
  }

  void _emitTurn(
    List<TimelineItem> turnItems,
    _Rows out,
    Map<String, int> latched, {
    required bool settled,
  }) {
    final shown = turnItems.where(out._shows).toList();
    if (shown.isEmpty) return;

    // Precompute the last visible non-empty AssistantText index so an empty
    // `session.text.started` or whitespace-only part never collapses activity
    // before visible text actually renders.
    var lastAnswerIndex = -1;
    for (var i = shown.length - 1; i >= 0; i--) {
      if (shown[i] case AssistantText(
        :final text,
      ) when text.trim().isNotEmpty) {
        lastAnswerIndex = i;
        break;
      }
    }

    var index = 0;
    while (index < shown.length) {
      if (!isCompactable(shown[index])) {
        out.emitSingle(shown[index]);
        index++;
        continue;
      }
      var stop = index + 1;
      while (stop < shown.length && isCompactable(shown[stop])) {
        stop++;
      }
      final stretch = shown.sublist(index, stop);
      final hasFollowingAnswer = lastAnswerIndex >= stop;
      final id = 'work-${stretch.first.id.value}';
      final activeCount = stretch.where(_isActiveItem).length;
      final failedCount = stretch.where(_isFailedItem).length;
      final settledTrailing =
          !hasFollowingAnswer &&
          activeCount == 0 &&
          (settled || _settledTrailing[id] == stretch.length);
      final collapse = hasFollowingAnswer || settledTrailing;
      if (collapse) {
        if (settledTrailing) latched[id] = stretch.length;
        out.stretch(
          id,
          stretch,
          runningCount: activeCount,
          failedCount: failedCount,
        );
      } else {
        for (final item in stretch) {
          out.emitSingle(item);
        }
      }
      index = stop;
    }
  }

  /// The turn in flight in Block render mode: already-ended leading items
  /// (compacting any stretch before a published intermediate answer, never
  /// before held answers), then ended calls that finished early, then the
  /// pending placeholder.
  void _held(
    List<TimelineItem> items,
    int start,
    int end,
    _Rows out,
    Map<String, int> latched,
  ) {
    var published = start;
    while (published < end && _ended(items[published])) {
      published++;
    }
    if (published > start) {
      _emitTurn(items.sublist(start, published), out, latched, settled: false);
    }
    for (var index = published; index < end; index++) {
      final item = items[index];
      if (_callEnded(item) && out._shows(item)) {
        out.emitSingle(item);
      }
    }
    out.rows.add(
      SessionPendingRow(start > 0 ? items[start - 1].id : items[start].id),
    );
  }

  /// The answers and reasoning the Block render mode holds back now, so a
  /// search does not find what the timeline does not show yet (#462): the
  /// part of the turn in flight after the first item that has not ended.
  static Set<ItemId> heldText(
    List<TimelineItem> items, {
    required bool settled,
    required ChatRenderMode renderMode,
  }) {
    if (renderMode != ChatRenderMode.block || settled) return const {};
    items = sessionTimelineItems(items);
    var start = items.length;
    while (start > 0 && items[start - 1] is! UserInput) {
      start--;
    }
    var published = start;
    while (published < items.length && _ended(items[published])) {
      published++;
    }
    return {
      for (final item in items.skip(published))
        if (item is AssistantText || item is Reasoning) item.id,
    };
  }

  /// A reminder or system note the harness adds (#491): a light line, never
  /// work in flight, whatever its own status.
  static bool _isReminder(TimelineItem item) =>
      item is Notice &&
      item.shellReport == null &&
      (item.kind.known == NoticeKind.continuation ||
          item.kind.known == NoticeKind.system ||
          item.kind.known == NoticeKind.skillActivated);

  /// Whether an item can be published in Block render mode.
  static bool _ended(TimelineItem item) {
    if (_isReminder(item)) return true;
    if (item is Notice && item.kind.known == NoticeKind.compaction) return true;
    if (item is Notice && item.shellReport != null) return true;
    final message = item.meta.message;
    if (message != null) return message.completed != null;
    return switch (item.status.known) {
      ItemStatus.pending || ItemStatus.streaming => false,
      _ => !_running(item),
    };
  }

  /// Whether a call ended: completed, failed or interrupted (never a
  /// backgrounded shell tool still running via [ToolCall.runFacts]).
  static bool _callEnded(TimelineItem item) => switch (item) {
    Notice(shellReport: _?) => true,
    ShellRun(:final shellStatus?) =>
      shellStatus.known != null && shellStatus.known != ShellStatus.running,
    ToolCall() =>
      !_isActiveItem(item) &&
          switch (item.status.known) {
            ItemStatus.completed ||
            ItemStatus.failed ||
            ItemStatus.interrupted => true,
            _ => false,
          },
    ShellRun() => switch (item.status.known) {
      ItemStatus.completed ||
      ItemStatus.failed ||
      ItemStatus.interrupted => true,
      _ => false,
    },
    _ => false,
  };

  static bool _running(TimelineItem item) => switch (item) {
    ShellRun(:final shellStatus) => shellStatus?.known == ShellStatus.running,
    ToolCall() => _isActiveItem(item),
    _ => false,
  };

  static bool _isActiveItem(TimelineItem item) => switch (item) {
    Reasoning(:final complete) =>
      !complete ||
          item.status.known == ItemStatus.pending ||
          item.status.known == ItemStatus.streaming,
    ShellRun(:final shellStatus) =>
      shellStatus?.known == ShellStatus.running ||
          item.status.known == ItemStatus.pending ||
          item.status.known == ItemStatus.streaming,
    ToolCall(:final runFacts) => () {
      final itemStatus = item.status.known;
      if (itemStatus == ItemStatus.failed ||
          itemStatus == ItemStatus.interrupted) {
        return false;
      }
      if (runFacts != null) {
        if (runFacts.timedOut ||
            runFacts.interrupted ||
            runFacts.shellStatus?.known == ShellStatus.timeout ||
            runFacts.shellStatus?.known == ShellStatus.killed) {
          return false;
        }
        if (runFacts.shellStatus?.known == ShellStatus.running ||
            (runFacts.background &&
                runFacts.exitCode == null &&
                runFacts.exitToken == null &&
                runFacts.shellStatus?.known != ShellStatus.exited)) {
          return true;
        }
        if (runFacts.exitCode != null) return false;
      }
      return itemStatus == ItemStatus.pending ||
          itemStatus == ItemStatus.streaming;
    }(),
    _ => false,
  };

  static bool _isFailedItem(TimelineItem item) => switch (item) {
    Notice(shellReport: final report?) =>
      report.timedOut ||
          report.killed ||
          report.outcome == OutcomeKind.failed ||
          report.outcome == OutcomeKind.interrupted ||
          (report.exitCode != null && report.exitCode != 0),
    ShellRun(:final shellStatus, :final exitCode) =>
      shellStatus?.known == ShellStatus.timeout ||
          shellStatus?.known == ShellStatus.killed ||
          (shellStatus?.known == ShellStatus.exited &&
              exitCode != null &&
              exitCode != 0) ||
          item.status.known == ItemStatus.failed ||
          item.status.known == ItemStatus.interrupted,
    ToolCall(:final runFacts) =>
      (runFacts?.timedOut ?? false) ||
          (runFacts?.interrupted ?? false) ||
          runFacts?.shellStatus?.known == ShellStatus.timeout ||
          runFacts?.shellStatus?.known == ShellStatus.killed ||
          (runFacts?.exitCode != null && runFacts!.exitCode != 0) ||
          item.status.known == ItemStatus.failed ||
          item.status.known == ItemStatus.interrupted,
    _ =>
      item.status.known == ItemStatus.failed ||
          item.status.known == ItemStatus.interrupted,
  };
}

/// The rows a projection emits, in chronological order: it leaves out what
/// the reader hid and marks the first shown item of each message so its
/// details stay reachable.
final class _Rows {
  _Rows(
    this.presentation, {
    required this.showReasoning,
    required this.showToolCalls,
  });

  final SessionTimelinePresentation presentation;
  final bool showReasoning;
  final bool showToolCalls;
  final rows = <SessionTimelineRow>[];

  /// The message of the last item shown.
  MessageRef? _message;

  bool _shows(TimelineItem item) => switch (item) {
    Reasoning() => showReasoning,
    ToolCall() || ShellRun() || Notice(shellReport: _?) => showToolCalls,
    _ => true,
  };

  /// Whether [item], shown next, opens its message.
  bool _opens(TimelineItem item) {
    final message = item.meta.message?.message;
    final opens = message != null && message != _message;
    _message = message;
    return opens;
  }

  void emitSingle(TimelineItem item) {
    if (!_shows(item)) return;
    rows.add(SessionItemRow(item, messageHeader: _opens(item)));
  }

  void stretch(
    String id,
    List<TimelineItem> items, {
    required int runningCount,
    required int failedCount,
  }) {
    if (items.isEmpty) return;
    final headers = [for (final item in items) _opens(item)];
    final expanded = presentation.isExpanded(id);
    rows.add(
      SessionActivityStretchRow(
        items,
        id: id,
        expanded: expanded,
        messageHeaders: headers,
        runningCount: runningCount,
        failedCount: failedCount,
      ),
    );
    if (expanded) {
      for (var i = 0; i < items.length; i++) {
        rows.add(SessionItemRow(items[i], messageHeader: headers[i]));
      }
    }
  }
}

/// What a row of the live timeline may ask of the timeline that shows it.
class SessionTimelineScope extends InheritedWidget {
  const SessionTimelineScope({
    super.key,
    required this.items,
    required this.onReaderToggle,
    required super.child,
  });

  /// The resident items as they change, so a dialog opened from a row keeps
  /// showing its item as it is now.
  final ValueListenable<List<TimelineItem>> items;

  /// Called before a row opens or closes content because the reader asked,
  /// so the timeline does not follow the growth that makes.
  final VoidCallback onReaderToggle;

  /// The scope above [context]; null outside the live timeline, as in the
  /// read-only history.
  static SessionTimelineScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionTimelineScope>();

  @override
  bool updateShouldNotify(SessionTimelineScope oldWidget) => false;
}

/// Whether [input] is a prompt the harness admitted and has not delivered:
/// it waits, pinned after the conversation, until it enters it (#502).
bool sessionPromptWaits(UserInput input) => switch (input.delivery.known) {
  DeliveryState.accepted || DeliveryState.queued => true,
  _ => false,
};

/// Splits a live timeline into what the conversation holds and the prompts
/// still waiting for the harness (#502).
///
/// A waiting prompt is pinned after everything else, oldest first, until the
/// harness delivers it: a prompt admitted as a [UserInput] leaves its place,
/// with what belongs to the same message, and one the harness only lists in
/// [pending] (a queued prompt, or one from another client) is shown from that
/// entry, with this device's own text and attachments when [sentHere] knows
/// them. A cancelled or rejected prompt never joined the conversation and is
/// not shown. Without anything waiting, [items] comes back as it is.
({List<TimelineItem> items, List<UserInput> waiting}) sessionWaitingPrompts(
  List<TimelineItem> items,
  List<PendingInput> pending, {
  required HarnessRef harness,
  ({String text, List<AttachmentRef> attachments})? Function(ItemId id)?
  sentHere,
}) {
  final ids = <ItemId>{};
  final waits = <ItemId>{};
  for (final item in items) {
    ids.add(item.id);
    if (item is UserInput && sessionPromptWaits(item)) waits.add(item.id);
  }
  // A pending entry whose prompt is already in the conversation is stale.
  final open = [
    for (final entry in pending)
      if (!ids.contains(entry.id) || waits.contains(entry.id)) entry,
  ];
  if (open.isEmpty &&
      !items.any((item) => item is UserInput && _outsideConversation(item))) {
    return (items: _withOwnAttachments(items, sentHere), waiting: const []);
  }
  // What belongs to the message of a prompt outside the conversation, such
  // as its context, waits or leaves with it.
  final anchors = <MessageAnchor>{
    for (final entry in open) ?entry.anchor,
    for (final item in items)
      if (item is UserInput && _outsideConversation(item)) ?item.meta.anchor,
  };
  final resident = <ItemId, UserInput>{};
  final kept = <TimelineItem>[];
  for (final item in items) {
    if (item is UserInput) {
      if (_outsideConversation(item)) {
        if (sessionPromptWaits(item)) resident[item.id] = item;
        continue;
      }
    } else if (anchors.contains(item.meta.anchor)) {
      continue;
    }
    kept.add(item);
  }
  final shown = <ItemId>{};
  final waiting = <UserInput>[];
  void add(UserInput input) {
    if (shown.add(input.id)) waiting.add(_own(input, sentHere) ?? input);
  }

  for (final entry in open) {
    if (resident[entry.id] case final input?) {
      add(input);
      continue;
    }
    add(
      UserInput(
        meta: ItemMeta(
          id: entry.id,
          generation: 'pending',
          status: const OpenValue.known(ItemStatus.pending),
          source: SourceProvenance(
            harness: harness,
            version: 'local',
            nativeType: 'pendingInput',
          ),
          anchor: entry.anchor,
        ),
        text: entry.text,
        delivery: OpenValue.known(
          entry.delivery.known == Delivery.queue
              ? DeliveryState.queued
              : DeliveryState.accepted,
        ),
      ),
    );
  }
  resident.values.forEach(add);
  return (items: _withOwnAttachments(kept, sentHere), waiting: waiting);
}

/// [input] with this device's text and attachments of it, when the harness
/// row carries no attachments and this device sent it with some; null when
/// nothing changes.
UserInput? _own(
  UserInput input,
  ({String text, List<AttachmentRef> attachments})? Function(ItemId id)?
  sentHere,
) {
  if (input.attachments.isNotEmpty || sentHere == null) return null;
  final own = sentHere(input.id);
  if (own == null ||
      (own.attachments.isEmpty &&
          (own.text == input.text || !sessionPromptWaits(input)))) {
    return null;
  }
  return UserInput(
    meta: input.meta,
    text: sessionPromptWaits(input) ? own.text : input.text,
    attachments: own.attachments,
    delivery: input.delivery,
    confirmed: input.confirmed,
  );
}

/// [items], with a prompt this device sent keeping its own attachments when
/// the harness reported it without them, until a history read brings them;
/// the same list when nothing changes.
List<TimelineItem> _withOwnAttachments(
  List<TimelineItem> items,
  ({String text, List<AttachmentRef> attachments})? Function(ItemId id)?
  sentHere,
) {
  if (sentHere == null) return items;
  List<TimelineItem>? out;
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (item is! UserInput) continue;
    final own = _own(item, sentHere);
    if (own == null) continue;
    (out ??= List.of(items))[i] = own;
  }
  return out ?? items;
}

/// Whether [input] is not part of the conversation (yet): waiting, or
/// cancelled or rejected before the harness took it.
bool _outsideConversation(UserInput input) =>
    sessionPromptWaits(input) ||
    switch (input.delivery.known) {
      DeliveryState.cancelled || DeliveryState.rejected => true,
      _ => false,
    };

/// Whether [input] belongs to the conversation: a prompt the harness took,
/// not one still waiting, cancelled or rejected (#502).
bool sessionPromptInConversation(UserInput input) =>
    !_outsideConversation(input);

/// The items a timeline shows: a succeeded turn needs no row of its own, the
/// header already reports it; structured plan tools are shown in the task list
/// panel instead of timeline rows; synthetic shell completion notices that
/// duplicate a user [ShellRun] with the same `shellId` are omitted (mirroring
/// the official client's `echoesUserShell`).
List<TimelineItem> sessionTimelineItems(List<TimelineItem> items) {
  final userShellIds = <String>{
    for (final item in items)
      if (item case ShellRun(shellId: final id?)) id,
  };
  return [
    for (final item in items)
      if ((item is! TurnOutcome || item.kind.known != OutcomeKind.succeeded) &&
          !(item is ToolCall && item.kind.known == ToolKind.plan) &&
          !(item is Notice &&
              item.shellReport?.shellId != null &&
              userShellIds.contains(item.shellReport!.shellId)))
        item,
  ];
}
