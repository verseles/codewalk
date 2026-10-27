import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'session_message_info.dart';

/// One row of the live timeline: a resident item, a run of tool calls shown
/// together, or the header of a finished turn's work.
///
/// Rows are presentation only: the canonical items stay untouched, and every
/// row knows the items it stands for, so the timeline still places its
/// center and measures arrivals on the items themselves.
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

/// Consecutive tool calls and shell runs of one turn, shown as one row whose
/// summary counts them and whose calls open on demand.
final class SessionToolRunRow extends SessionTimelineRow {
  const SessionToolRunRow(
    this.tools, {
    required this.expanded,
    required this.messageHeaders,
  });

  /// Two or more [ToolCall] or [ShellRun] items.
  final List<TimelineItem> tools;
  final bool expanded;

  /// For each call, whether it opens its message, so the run still offers
  /// that message's details.
  final List<bool> messageHeaders;

  /// Anchored to the first call, so the run keeps its identity while calls
  /// are appended to it.
  String get id => 'tools-${tools.first.id.value}';

  @override
  Key get key => ValueKey(id);

  @override
  List<TimelineItem> get items => tools;
}

/// The header of a finished turn's work: everything the turn did before its
/// final answer, collapsed to a count until the reader expands it.
final class SessionWorkGroupRow extends SessionTimelineRow {
  const SessionWorkGroupRow(
    this.work, {
    required this.messageCount,
    required this.expanded,
  });

  final List<TimelineItem> work;

  /// The number of harness messages the work spans.
  final int messageCount;
  final bool expanded;

  /// Anchored to the turn's first item, never to a list position or a
  /// generation, so a passive refresh of the same turn keeps the same row.
  String get id => 'work-${work.first.id.value}';

  @override
  Key get key => ValueKey(id);

  @override
  List<TimelineItem> get items => work;
}

/// How the live timeline presents its resident items: tool calls in runs,
/// and a finished turn's work collapsed behind its final answer.
///
/// It keeps what the reader opened and which turns settled for as long as
/// the timeline that owns it is shown; a session shown again starts with
/// every finished turn collapsed.
final class SessionTimelinePresentation {
  final Set<String> _expanded = {};

  /// The turns already collapsed, with the answer and the length they had,
  /// so a status pulse that briefly reports the session busy again does not
  /// reopen a settled turn; only new content in that turn does.
  Map<String, ({ItemId answer, int length})> _settled = {};

  bool isExpanded(String id) => _expanded.contains(id);

  /// Opens or closes a run or a work group.
  void toggle(String id) {
    if (!_expanded.remove(id)) _expanded.add(id);
  }

  /// The rows of [items]. [settled] tells whether the session has no turn in
  /// flight, so its last turn may be collapsed.
  List<SessionTimelineRow> project(
    List<TimelineItem> items, {
    required bool settled,
  }) {
    final rows = <SessionTimelineRow>[];
    final latched = <String, ({ItemId answer, int length})>{};
    var index = 0;
    while (index < items.length) {
      if (items[index] is UserInput) {
        rows.add(_itemRow(items, index));
        index++;
        continue;
      }
      // A turn: everything up to the next prompt. The window may open in the
      // middle of one, which is then presented from where it starts.
      var end = index;
      while (end < items.length && items[end] is! UserInput) {
        end++;
      }
      _turn(
        items,
        index,
        end,
        rows,
        latched,
        settled: settled || end < items.length,
      );
      index = end;
    }
    _settled = latched;
    return rows;
  }

  void _turn(
    List<TimelineItem> items,
    int start,
    int end,
    List<SessionTimelineRow> rows,
    Map<String, ({ItemId answer, int length})> latched, {
    required bool settled,
  }) {
    final last = _lastText(items, start, end);
    final message = last == null ? null : items[last].meta.message?.message;
    // The final answer is the harness message that holds the last answer
    // text; without that message its start is unknown, and nothing is
    // collapsed on a guess.
    final answer = message == null
        ? null
        : _answerStart(items, start, last!, message);
    if (answer != null && answer > start) {
      final id = 'work-${items[start].id.value}';
      final mark = (answer: items[last!].id, length: end - start);
      // The turn must have finished either way (#273); the latch only
      // stands in for a session that a status pulse reports busy again.
      final collapse =
          _finished(items, start, end, last) &&
          (settled || _settled[id] == mark);
      if (collapse) {
        latched[id] = mark;
        final work = items.sublist(start, answer);
        final expanded = isExpanded(id);
        rows.add(
          SessionWorkGroupRow(
            work,
            messageCount: _messageCount(work),
            expanded: expanded,
          ),
        );
        if (expanded) _runs(items, start, answer, rows);
        _runs(items, answer, end, rows);
        return;
      }
    }
    _runs(items, start, end, rows);
  }

  /// Rows for [start]..[end], with consecutive calls joined in runs.
  void _runs(
    List<TimelineItem> items,
    int start,
    int end,
    List<SessionTimelineRow> rows,
  ) {
    var index = start;
    while (index < end) {
      var stop = index;
      while (stop < end && _joinable(items[stop])) {
        stop++;
      }
      if (stop - index >= 2) {
        final tools = items.sublist(index, stop);
        rows.add(
          SessionToolRunRow(
            tools,
            expanded: isExpanded('tools-${tools.first.id.value}'),
            messageHeaders: [
              for (var at = index; at < stop; at++) opensMessage(items, at),
            ],
          ),
        );
        index = stop;
        continue;
      }
      rows.add(_itemRow(items, index));
      index++;
    }
  }

  SessionItemRow _itemRow(List<TimelineItem> items, int index) =>
      SessionItemRow(items[index], messageHeader: opensMessage(items, index));

  /// A call that may share a run. A sub-agent call is a way into its own
  /// conversation, so it keeps a row of its own.
  static bool _joinable(TimelineItem item) => switch (item) {
    ShellRun() => true,
    ToolCall(:final kind) => kind.known != ToolKind.subagent,
    _ => false,
  };

  /// The index of the last answer text in [start]..[end].
  static int? _lastText(List<TimelineItem> items, int start, int end) {
    for (var index = end - 1; index >= start; index--) {
      if (items[index] is AssistantText) return index;
    }
    return null;
  }

  /// Where the turn's final answer starts: the first item of [message],
  /// the message that holds the last answer text at [last].
  static int _answerStart(
    List<TimelineItem> items,
    int start,
    int last,
    MessageRef message,
  ) {
    var first = last;
    while (first > start && items[first - 1].meta.message?.message == message) {
      first--;
    }
    return first;
  }

  /// Whether every item of the turn reached its end and the turn ended with
  /// a complete answer, at [last], so its work may be collapsed (#273):
  /// never while anything still streams, and never over a failure the reader
  /// must see.
  static bool _finished(
    List<TimelineItem> items,
    int start,
    int end,
    int last,
  ) {
    if (!(items[last] as AssistantText).complete) return false;
    for (var index = start; index < end; index++) {
      final item = items[index];
      switch (item.status.known) {
        case ItemStatus.pending || ItemStatus.streaming:
          return false;
        case ItemStatus.failed || ItemStatus.interrupted when index >= last:
          return false;
        default:
      }
      if (item case ShellRun(
        shellStatus: OpenValue(known: ShellStatus.running),
      )) {
        return false;
      }
      if (item case TurnOutcome(:final kind)
          when kind.known == OutcomeKind.failed ||
              kind.known == OutcomeKind.interrupted) {
        return false;
      }
    }
    return true;
  }

  /// The harness messages [work] spans; an item without one counts alone.
  static int _messageCount(List<TimelineItem> work) {
    var count = 0;
    MessageRef? previous;
    for (final item in work) {
      final message = item.meta.message?.message;
      if (message == null || message != previous) count++;
      previous = message;
    }
    return count;
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
