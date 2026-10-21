import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../shared/l10n/l10n_context.dart';
import 'session_live_scroll.dart';
import 'session_timeline_tile.dart';

/// The live session timeline: the resident items, the header and the
/// viewport rules that keep the newest content in view.
///
/// The list is chronological and forward, like the retained reference: the
/// header is the first row and the items follow it, so a live update appends
/// below the reader and the newest content is at the end.
class SessionLiveTimeline extends StatefulWidget {
  const SessionLiveTimeline({
    super.key,
    required this.items,
    required this.headerBuilder,
    required this.scroll,
    required this.settled,
  });

  /// The resident items, in the server's order.
  final List<TimelineItem> items;

  /// The block above the items: the phase, the notices and the retry.
  final WidgetBuilder headerBuilder;

  /// The scroll and viewport rules.
  final SessionLiveScroll scroll;

  /// Whether the session is settled, so its finished answer can be revealed.
  final bool settled;

  @override
  State<SessionLiveTimeline> createState() => _SessionLiveTimelineState();
}

class _SessionLiveTimelineState extends State<SessionLiveTimeline> {
  /// The passes one follow may take, for content that keeps growing in
  /// successive frames.
  static const int _maxFollowPasses = 3;

  int _followPasses = 0;
  bool _followScheduled = false;

  /// The largest content extent the viewport reported, so a growth is known
  /// whatever made it: a new item or a longer one.
  double? _lastMaxScrollExtent;

  /// The number of items and the signature of every one of them the
  /// previous build saw, so the arrival of content is known from the items
  /// themselves, even when the row that changed is not laid out.
  int _lastItemCount = 0;
  List<_ItemSignature>? _lastSignature;

  /// Whether the timeline already landed on the newest content.
  bool _landed = false;

  /// Whether a finished answer waits to be revealed once the follow settles.
  bool _revealPending = false;

  /// The context of the last assistant answer, while the list builds it.
  BuildContext? _answerContext;

  @override
  void initState() {
    super.initState();
    widget.scroll.controller.addListener(widget.scroll.onViewportChanged);
    _revealPending = widget.settled;
  }

  @override
  void didUpdateWidget(covariant SessionLiveTimeline old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.controller.removeListener(old.scroll.onViewportChanged);
      widget.scroll.controller.addListener(widget.scroll.onViewportChanged);
    }
    if (old.settled == widget.settled) return;
    if (widget.settled) {
      // The turn ended: its finished answer is offered from its start once
      // the follow reaches the tail, unless the reader is elsewhere.
      _revealPending = true;
      _requestFollow();
    } else {
      _revealPending = false;
      // A new turn started: a revealed answer was the timeline's choice, not
      // the reader's, so the timeline returns to the newest content.
      if (widget.scroll.revealed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.scroll.jumpToLatest();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.scroll.controller.removeListener(widget.scroll.onViewportChanged);
    super.dispose();
  }

  /// Whether a notification comes from the timeline's own list, not from a
  /// scrollable inside a row such as a code block, a formula or a diagram.
  static bool _ownList(ViewportNotificationMixin notification, Axis axis) =>
      notification.depth == 0 && axis == Axis.vertical;

  /// The reader's own scroll: a drag and the fling after it set a scroll
  /// direction, and so does a wheel; the timeline's jumps never do. A scroll
  /// that ends at the bottom, even one that could not move, gives the bottom
  /// back to the follow.
  ///
  /// A scroll that reports no direction of its own — a page key, a click on
  /// the scrollbar track — is the reader's too, and the scroll rules know it
  /// from the offset it moved.
  bool _onScroll(ScrollNotification notification) {
    if (!_ownList(notification, notification.metrics.axis)) return false;
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        widget.scroll.markUserIntent();
      } else {
        widget.scroll.onViewportChanged();
      }
    } else if (notification is ScrollEndNotification) {
      widget.scroll.onViewportChanged();
    }
    return false;
  }

  /// The content dimensions changed. A growth is followed while the reader
  /// is at the bottom; it never marks the control, because a smaller viewport
  /// or a taller header also grows the extent without any new content.
  bool _onMetrics(ScrollMetricsNotification notification) {
    if (!_ownList(notification, notification.metrics.axis)) return false;
    final extent = notification.metrics.maxScrollExtent;
    final last = _lastMaxScrollExtent;
    _lastMaxScrollExtent = extent;
    if (last != null && extent > last && widget.scroll.following) {
      _requestFollow();
    }
    return false;
  }

  /// Content arrived: a new item, or a last item that grew or changed. It is
  /// followed while the reader is at the bottom, and marked otherwise.
  void _contentArrived() {
    if (widget.scroll.following) {
      _requestFollow();
    } else {
      widget.scroll.onContentArrivedAway();
    }
  }

  /// Asks for one follow, coalesced to the next frame.
  void _requestFollow() {
    _followPasses = 0;
    if (_followScheduled) return;
    _followScheduled = true;
    _afterNextFrame(() {
      _followScheduled = false;
      _follow();
    });
  }

  /// Runs [action] after the next frame and asks for that frame: a post-frame
  /// callback alone waits for a frame something else requests, which may
  /// never come on a still screen.
  void _afterNextFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Moves the viewport to the newest content, in the frames the content
  /// takes to settle, then offers a pending finished answer.
  void _follow() {
    if (!widget.scroll.mayFollow) {
      // The reader is elsewhere: an answer that settled meanwhile is not
      // offered later, when it would pull the reader away from the tail.
      _revealPending = false;
      return;
    }
    final controller = widget.scroll.controller;
    if (!controller.hasClients) return;
    final target = controller.position.maxScrollExtent;
    if ((target - controller.position.pixels).abs() < 0.5) {
      _settled();
      return;
    }
    widget.scroll.runProgrammatic(() => controller.jumpTo(target));
    if (++_followPasses >= _maxFollowPasses) {
      _settled();
      return;
    }
    // The content may still grow in the next frame, and its extent is only
    // known then.
    _afterNextFrame(_follow);
  }

  /// The follow reached the tail: a pending finished answer is revealed.
  void _settled() {
    if (!_revealPending || !widget.settled) return;
    _revealPending = false;
    _revealAnswer();
  }

  /// Aligns the start of a finished answer that does not fit the viewport.
  ///
  /// The answer is read while it is revealed, so the control that returns to
  /// the newest content stays hidden until the reader moves.
  void _revealAnswer() {
    if (!widget.scroll.mayFollow) return;
    final context = _answerContext;
    if (context == null || !context.mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final controller = widget.scroll.controller;
    if (!controller.hasClients) return;
    if (box.size.height <= controller.position.viewportDimension) return;
    widget.scroll.runProgrammatic(() {
      Scrollable.ensureVisible(context, alignment: 0, duration: Duration.zero);
    });
    widget.scroll.reveal();
  }

  /// The index of the last assistant answer among the resident items.
  int? _lastAnswerIndex(List<TimelineItem> items) {
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i] is AssistantText) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final signature = _contentSignature(items);
    if (!_landed) {
      // The first build lands on the newest content.
      _landed = true;
      _requestFollow();
    } else if (items.length > _lastItemCount ||
        (items.length == _lastItemCount &&
            !listEquals(signature, _lastSignature))) {
      // Content arrived, even if the row that changed is not laid out. A
      // removal is not an arrival.
      _afterNextFrame(_contentArrived);
    }
    _lastItemCount = items.length;
    _lastSignature = signature;
    // The answer row sets its context again when the list lays it out.
    _answerContext = null;
    final answerIndex = _lastAnswerIndex(items);
    return ListenableBuilder(
      listenable: widget.scroll,
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  controller: widget.scroll.controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return widget.headerBuilder(context);
                    final item = items[index - 1];
                    final isAnswer = index - 1 == answerIndex;
                    // Every row has the same shape, so a row keeps its
                    // element when the last answer moves; the answer row
                    // keeps its context, so it can be measured and
                    // aligned.
                    return Builder(
                      key: ValueKey(item.id),
                      builder: (context) {
                        if (isAnswer) _answerContext = context;
                        return SessionTimelineTile(item: item);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          if (_showJumpControl)
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: _jumpToLatest(context),
            ),
        ],
      ),
    );
  }

  /// Whether the control that returns to the newest content is offered: the
  /// reader is away from the bottom, and the answer shown is not one the
  /// timeline revealed.
  bool get _showJumpControl =>
      !widget.scroll.following && !widget.scroll.revealed;

  /// The reader asked for the newest content: a finished answer that waited
  /// is not offered on top of it.
  void _onJumpToLatest() {
    _revealPending = false;
    widget.scroll.jumpToLatest();
  }

  /// The control that returns to the newest content, marked when content
  /// arrived below the reader.
  Widget _jumpToLatest(BuildContext context) {
    final unread = widget.scroll.unreadBelow;
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      key: const ValueKey('live-jump-latest'),
      heroTag: 'live-jump-latest',
      tooltip: context.v2L10n.chatGoToLatest,
      onPressed: _onJumpToLatest,
      backgroundColor: unread ? scheme.primary : scheme.surfaceContainerHigh,
      foregroundColor: unread ? scheme.onPrimary : scheme.onSurfaceVariant,
      child: Icon(
        unread ? Icons.mark_chat_unread : Icons.arrow_downward_rounded,
      ),
    );
  }
}

/// A bounded signature of one item: its identity, its known status, the size
/// of the content that can grow and the outcome it carries, when it has one.
/// A change means content arrived.
typedef _ItemSignature = (ItemId, ItemStatus?, int, int?);

/// The signature of every resident item, so a change in any of them — not
/// only in the last — is an arrival.
List<_ItemSignature> _contentSignature(List<TimelineItem> items) =>
    items.map(_itemSignature).toList(growable: false);

/// The signature of one item.
///
/// The generation is not part of it: a rehydration gives the item a new
/// generation without any new content, and the reader must not be told that
/// something arrived.
_ItemSignature _itemSignature(TimelineItem item) => (
  item.id,
  item.status.known,
  switch (item) {
    AssistantText(:final text) => text.length,
    Reasoning(:final text) => text.length,
    UserInput(:final text) => text.length,
    Notice(:final text) => text.length,
    TurnOutcome(:final reason) => reason?.length ?? 0,
    UnknownItem(:final fallbackText) => fallbackText?.length ?? 0,
    _ => 0,
  },
  switch (item) {
    ShellRun(:final exitCode) => exitCode,
    _ => null,
  },
);
