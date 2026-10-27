import 'dart:math';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../shared/l10n/l10n_context.dart';
import '../../shared/theme/chat_appearance.dart';
import 'session_error_card.dart';
import 'session_live_scroll.dart';
import 'session_timeline_projection.dart';
import 'session_timeline_tile.dart';
import 'session_work_group.dart';

/// The live session timeline: the resident items, the header and the
/// viewport rules that keep the newest content in view.
///
/// The list is chronological and forward, like the retained reference: the
/// header is the first row and the items follow it, so a live update appends
/// below the reader and the newest content is at the end.
///
/// Older history pages in above the rows the timeline first showed. Those
/// rows open a center sliver: what comes before it grows upwards and what
/// comes after it grows downwards, so a page added on top never moves the row
/// the reader is reading, whatever the heights of the rows it adds.
///
/// The items are presented in rows ([SessionTimelinePresentation]): calls in
/// runs, and a finished turn's work collapsed behind its final answer. The
/// center and the arrivals are still measured on the items themselves.
class SessionLiveTimeline extends StatefulWidget {
  const SessionLiveTimeline({
    super.key,
    required this.items,
    required this.headerBuilder,
    required this.scroll,
    required this.settled,
    this.olderLoading = false,
    this.onLoadOlder,
    this.topBuilder,
    this.errorRecovery,
    this.onOpenChild,
    this.emptyBuilder,
  });

  /// The resident items, in the server's order.
  final List<TimelineItem> items;

  /// The block above the items: the phase, the notices and the retry.
  final WidgetBuilder headerBuilder;

  /// The scroll and viewport rules.
  final SessionLiveScroll scroll;

  /// Whether the session is settled, so its finished answer can be revealed.
  final bool settled;

  /// Whether an older page is being read, shown by a pill at the top.
  final bool olderLoading;

  /// The block at the very top, above the older rows; null for none.
  final WidgetBuilder? topBuilder;

  /// Reads the next older page; null when none can be read now. The reader
  /// asks for it by reaching the top of the list.
  final VoidCallback? onLoadOlder;

  /// The recovery a failed turn's error card offers; null for none.
  final SessionErrorRecovery? Function(ErrorInfo error)? errorRecovery;

  /// Opens the sub-conversation of a subagent card; null for none.
  final ValueChanged<ToolCall>? onOpenChild;

  /// The block below the header while there is no item: a loader while the
  /// session loads, or the empty conversation once it is known to be empty.
  /// Null for none.
  final WidgetBuilder? emptyBuilder;

  @override
  State<SessionLiveTimeline> createState() => _SessionLiveTimelineState();
}

class _SessionLiveTimelineState extends State<SessionLiveTimeline> {
  /// The passes one follow may take, for content that keeps growing in
  /// successive frames.
  static const int _maxFollowPasses = 3;

  /// The deferrals one follow may take, for a scroll that is in progress
  /// when the follow would jump and reports no direction of its own.
  static const int _maxDeferrals = 3;

  int _followPasses = 0;
  int _deferrals = 0;
  bool _followScheduled = false;

  /// Whether the scroll in progress is the reader's drag.
  ///
  /// A drag reports the gesture that started it. A scroll that reports no
  /// direction of its own - a page key, a click on the scrollbar track -
  /// does not, and the framework's own start carries no gesture either.
  bool _readerDrag = false;

  /// The largest content extent the viewport reported, so a growth is known
  /// whatever made it: a new item or a longer one.
  double? _lastMaxScrollExtent;

  /// The number of items and the signature of every one of them the
  /// previous build saw, so the arrival of content is known from the items
  /// themselves, even when the row that changed is not laid out.
  int _lastItemCount = 0;
  List<_ItemSignature>? _lastSignature;

  /// What the previous signature showed: a change of it is the reader's
  /// choice, not an arrival.
  _Display? _lastDisplay;

  /// Whether the timeline already landed on the newest content.
  bool _landed = false;

  /// Whether a finished answer waits to be revealed once the follow settles.
  bool _revealPending = false;

  /// Whether content arrived and the follow has not accounted for it yet.
  ///
  /// The follow is also requested by a growth of the extent that carries no
  /// new content, such as a taller header or a smaller viewport, so the
  /// arrival is known apart from the follow that would carry it.
  bool _arrivalPending = false;

  /// The context of the last assistant answer, while the list builds it.
  BuildContext? _answerContext;

  /// The first row of the center sliver; every row before it is older
  /// history that paged in above. It changes only when that row leaves the
  /// window, and then the center restarts at the window's first row.
  ItemId? _pivot;

  /// The rows read above the center so far, in chronological order.
  int _olderCount = 0;

  /// The center sliver's key, which the scroll view anchors to.
  final _centerKey = UniqueKey();

  /// What each row keeps while it is not built.
  final _rowState = PageStorageBucket();

  /// How the items are presented, and what the reader opened.
  final _presentation = SessionTimelinePresentation();

  /// The items, published after each build for the dialogs opened from rows.
  final _liveItems = ValueNotifier<List<TimelineItem>>(const []);

  /// Whether reaching the top may ask for an older page: armed once the
  /// reader is far from the top, so a list that stays near the top asks once.
  bool _olderArmed = false;

  /// The distance from the top within which the reader reached the top, and
  /// the distance that arms it again, in logical pixels; the retained
  /// reference's values.
  static const double _topReach = 72;
  static const double _topRearm = 220;

  @override
  void initState() {
    super.initState();
    widget.scroll.controller.addListener(widget.scroll.onViewportChanged);
    if (widget.scroll.timelineMemory case final _Memory memory) {
      // The session is shown again: the rows open around the same center, so
      // the kept offset is the reader's place, and what changed while it was
      // hidden is told as it would have been while it was shown.
      _pivot = memory.pivot;
      _lastSignature = memory.signature;
      _lastItemCount = memory.signature?.length ?? 0;
      _lastDisplay = memory.display;
      if (memory.settled != widget.settled) _settledChanged();
    } else {
      _revealPending = widget.settled;
    }
  }

  @override
  void didUpdateWidget(covariant SessionLiveTimeline old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.controller.removeListener(old.scroll.onViewportChanged);
      widget.scroll.controller.addListener(widget.scroll.onViewportChanged);
    }
    if (old.settled != widget.settled) _settledChanged();
  }

  /// The session settled, or a new turn started.
  void _settledChanged() {
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
    _liveItems.dispose();
    widget.scroll.controller.removeListener(widget.scroll.onViewportChanged);
    widget.scroll.timelineMemory = (
      pivot: _pivot,
      signature: _lastSignature,
      display: _lastDisplay,
      settled: widget.settled,
    );
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
  /// The direction is the evidence only when the list can still move in it: a
  /// gesture against the boundary reports its direction even when the physics
  /// clamp the offset, and a reader who holds the list at the tail has not
  /// asked for anything.
  ///
  /// A scroll that reports no direction of its own — a page key, a click on
  /// the scrollbar track — is the reader's too, and the scroll rules know it
  /// from the offset it moved.
  bool _onScroll(ScrollNotification notification) {
    if (!_ownList(notification, notification.metrics.axis)) return false;
    if (notification is UserScrollNotification) {
      final direction = notification.direction;
      if (direction == ScrollDirection.idle) {
        widget.scroll.onViewportChanged();
      } else if (_canMove(direction)) {
        widget.scroll.markUserIntent();
      }
    } else if (notification is ScrollStartNotification) {
      _readerDrag = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      widget.scroll.onViewportChanged();
    }
    if (notification is ScrollUpdateNotification &&
        !widget.scroll.programmatic) {
      _considerOlder(notification.metrics);
    }
    return false;
  }

  /// The reader reached the top: one older page is asked for, and the next
  /// one only after the reader went far enough from the top again. The
  /// timeline's own jumps never ask.
  void _considerOlder(ScrollMetrics metrics) {
    final fromTop = metrics.pixels - metrics.minScrollExtent;
    if (fromTop > _topRearm) {
      _olderArmed = true;
      return;
    }
    final load = widget.onLoadOlder;
    if (!_olderArmed || fromTop > _topReach || load == null) return;
    _olderArmed = false;
    load();
  }

  /// Whether the list can still move in the direction of the gesture.
  ///
  /// A drag against the boundary reports its direction even when the physics
  /// clamp the offset, so the direction alone is not the reader's intent: a
  /// reader who pulls at the tail cannot move the list, and the follow must
  /// go on. A gesture that can move the list is the reader's.
  bool _canMove(ScrollDirection direction) {
    final controller = widget.scroll.controller;
    if (!controller.hasClients) return false;
    final position = controller.position;
    return switch (direction) {
      // The reverse direction grows the offset, towards the end of the
      // list; the forward direction shrinks it, towards the zero position.
      ScrollDirection.reverse => position.pixels < position.maxScrollExtent,
      ScrollDirection.forward => position.pixels > position.minScrollExtent,
      ScrollDirection.idle => false,
    };
  }

  /// The reader opened or closed a row's content: the growth that makes is
  /// the reader's own, so the follow does not chase it.
  void _onReaderToggle() => _lastMaxScrollExtent = null;

  void _toggle(String id) {
    _onReaderToggle();
    setState(() => _presentation.toggle(id));
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
      _arrivalPending = false;
      widget.scroll.onContentArrivedAway();
    }
  }

  /// Asks for one follow, coalesced to the next frame.
  void _requestFollow() {
    _followPasses = 0;
    _deferrals = 0;
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
      // offered later, when it would pull the reader away from the tail,
      // and the content that arrived is under the reader now.
      _revealPending = false;
      if (_arrivalPending && !widget.scroll.revealed) {
        // The content that arrived is under the reader now. A revealed
        // answer is the reader's place, so it is not marked. A follow that
        // only a growth of the extent requested carries no arrival.
        _arrivalPending = false;
        widget.scroll.onContentArrivedAway();
      }
      return;
    }
    final controller = widget.scroll.controller;
    if (!controller.hasClients) return;
    if (controller.position.isScrollingNotifier.value && !_readerDrag) {
      // A scroll that reports no direction of its own - a page key, a click
      // on the scrollbar track - has not moved the viewport yet, so the
      // offset cannot tell it apart from the follow's own. The follow waits
      // for it instead of cancelling it.
      if (++_deferrals < _maxDeferrals) {
        _afterNextFrame(_follow);
        return;
      }
    }
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
    // The follow reached the content, so the arrival it may carry is
    // accounted for, whether the viewport was already there or the follow
    // jumped to it.
    _arrivalPending = false;
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

  /// The rows of [items] as [display] shows them.
  List<SessionTimelineRow> _project(
    List<TimelineItem> items,
    _Display display,
  ) => _presentation.project(
    items,
    settled: widget.settled,
    showReasoning: display.reasoning,
    showToolCalls: display.tools,
    renderMode: display.mode,
  );

  /// The signature of what [rows] show: a hidden call, or a response the
  /// Block render mode still holds, does not arrive. An opened work group
  /// lists its work twice, under its header and in its own rows.
  static List<_ItemSignature> _shownSignature(List<SessionTimelineRow> rows) {
    final shown = <ItemId>{};
    return _contentSignature([
      for (final row in rows)
        for (final item in row.items)
          if (shown.add(item.id)) item,
    ]);
  }

  /// The index of the row of the last assistant answer.
  int? _lastAnswerIndex(List<SessionTimelineRow> rows) {
    for (var i = rows.length - 1; i >= 0; i--) {
      if (rows[i] case SessionItemRow(item: AssistantText())) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final appearance = ChatAppearance.maybeOf(context);
    final display = (
      reasoning: appearance?.showReasoning ?? true,
      tools: appearance?.showToolCalls ?? true,
      mode: appearance?.renderMode ?? ChatRenderMode.live,
    );
    // What a new display choice shows or hides is not an arrival: the items
    // are compared as the previous choice showed them, so what arrived
    // meanwhile is still told.
    final last = _lastDisplay;
    final before = last == null || last == display
        ? null
        : _shownSignature(_project(items, last));
    final rows = _project(items, display);
    final signature = _shownSignature(rows);
    final now = before ?? signature;
    // Rows that paged in above the rows the previous build saw are history,
    // not an arrival: only what follows them is compared.
    final previous = _lastSignature;
    final kept = previous == null || previous.isEmpty
        ? 0
        : now.indexWhere((s) => s.id == previous.first.id);
    final compared = kept > 0 ? now.sublist(kept) : now;
    if (previous != null &&
        (compared.length > _lastItemCount ||
            (compared.length == _lastItemCount &&
                !listEquals(compared, previous)))) {
      // Content arrived, even if the row that changed is not laid out. A
      // removal is not an arrival.
      _arrivalPending = true;
      // A turn that ran and ended while the session was hidden is offered
      // like one that settled in view, once the follow reaches it.
      if (!_landed && widget.settled) _revealPending = true;
      _afterNextFrame(_contentArrived);
    }
    if (!_landed) {
      // The first build lands on the newest content.
      _landed = true;
      _requestFollow();
    }
    _lastItemCount = signature.length;
    _lastSignature = signature;
    _lastDisplay = display;
    if (!identical(_liveItems.value, items)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _liveItems.value = widget.items;
      });
    }
    final rowIndex = {for (final (i, row) in rows.indexed) row.key: i};
    _placePivot(rows);
    // The answer row sets its context again when the list lays it out.
    _answerContext = null;
    final answerIndex = _lastAnswerIndex(rows);
    // With no older rows above, the top block opens the center, so a list
    // that fits the screen still shows it; otherwise it tops the older rows.
    final topInCenter = widget.topBuilder != null && _olderCount == 0;
    final leads = <WidgetBuilder>[
      if (topInCenter) widget.topBuilder!,
      widget.headerBuilder,
    ];
    final lead = leads.length;
    return ListenableBuilder(
      listenable: widget.scroll,
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                // Rows keep what the reader opened while they leave the
                // lazily built list and come back.
                child: SessionTimelineScope(
                  items: _liveItems,
                  onReaderToggle: _onReaderToggle,
                  child: PageStorage(
                    bucket: _rowState,
                    child: CustomScrollView(
                      controller: widget.scroll.controller,
                      center: _centerKey,
                      slivers: [
                        if (widget.topBuilder case final top?
                            when _olderCount > 0)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: top(context),
                            ),
                          ),
                        // Older history, built from the center outwards: index
                        // 0 is the row right above the center.
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _row(
                                rows,
                                _olderCount - 1 - index,
                                answerIndex,
                              ),
                              childCount: _olderCount,
                              findChildIndexCallback: (key) {
                                final at = rowIndex[key];
                                return at == null || at >= _olderCount
                                    ? null
                                    : _olderCount - 1 - at;
                              },
                            ),
                          ),
                        ),
                        SliverPadding(
                          key: _centerKey,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index < lead) return leads[index](context);
                                return _row(
                                  rows,
                                  _olderCount + index - lead,
                                  answerIndex,
                                );
                              },
                              childCount: rows.length - _olderCount + lead,
                              findChildIndexCallback: (key) {
                                final at = rowIndex[key];
                                return at == null || at < _olderCount
                                    ? null
                                    : at - _olderCount + lead;
                              },
                            ),
                          ),
                        ),
                        if (rows.isEmpty && widget.emptyBuilder != null)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptySpace(builder: widget.emptyBuilder!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.olderLoading)
            PositionedDirectional(
              top: 12,
              start: 0,
              end: 0,
              child: Center(child: _olderPill(context)),
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

  /// Places the center: on the first rows the timeline shows, and again on
  /// the window's first row when the center item left the window. The center
  /// is an item, so it stays put while its row joins a run or a work group.
  void _placePivot(List<SessionTimelineRow> rows) {
    final pivot = _pivot;
    final at = pivot == null
        ? -1
        : rows.indexWhere((row) => row.items.any((item) => item.id == pivot));
    if (at >= 0) {
      _olderCount = at;
      return;
    }
    // The pending row holds no item.
    _pivot = rows.expand((row) => row.items).firstOrNull?.id;
    _olderCount = 0;
  }

  /// One row. Every row has the same shape, so a row keeps its element when
  /// the last answer moves; the answer row keeps its context, so it can be
  /// measured and aligned.
  Widget _row(List<SessionTimelineRow> rows, int index, int? answerIndex) {
    final row = rows[index];
    final isAnswer = index == answerIndex;
    return Builder(
      key: row.key,
      builder: (context) {
        if (isAnswer) _answerContext = context;
        return switch (row) {
          SessionItemRow(:final item, :final messageHeader) =>
            SessionTimelineTile(
              item: item,
              errorRecovery: widget.errorRecovery,
              onOpenChild: widget.onOpenChild,
              messageHeader: messageHeader,
            ),
          SessionToolRunRow() => SessionToolRun(
            row: row,
            onToggle: () => _toggle(row.id),
          ),
          SessionWorkGroupRow() => SessionWorkGroupHeader(
            row: row,
            onToggle: () => _toggle(row.id),
          ),
          SessionPendingRow() => const SessionGenerationPlaceholder(),
        };
      },
    );
  }

  /// The pill shown while an older page is read, like the retained
  /// reference's.
  Widget _olderPill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('live-older-loading'),
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            semanticsLabel: context.v2L10n.liveOlderLoading,
          ),
        ),
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

/// The block an empty timeline shows, in the space the header leaves: it
/// adds no scroll extent, so it never pushes the header away, and it scales
/// down, or steps aside, when that space is small.
class _EmptySpace extends SingleChildRenderObjectWidget {
  _EmptySpace({required WidgetBuilder builder})
    : super(
        child: LayoutBuilder(
          builder: (context, box) => box.maxHeight < 48
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: max(0, box.maxWidth - 32),
                        child: Center(child: builder(context)),
                      ),
                    ),
                  ),
                ),
        ),
      );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoIntrinsicHeight();
}

/// A box that asks for no height of its own, so the remaining space alone
/// sizes it.
class _RenderNoIntrinsicHeight extends RenderProxyBox {
  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}

/// What the timeline keeps with its scroll while it is not shown: the center
/// row, the signature of the rows it last saw and whether the session was
/// settled then.
typedef _Memory = ({
  ItemId? pivot,
  List<_ItemSignature>? signature,
  _Display? display,
  bool settled,
});

/// What the reader chose to show: reasoning, tool calls and the render mode.
typedef _Display = ({bool reasoning, bool tools, ChatRenderMode mode});

/// A signature of one item: its identity, its known status, the content it
/// carries that can change and the outcome it carries, when it has one. A
/// change means content arrived.
///
/// The content is the value itself, not its size: a replacement of the same
/// size is a change too, and the reader has to be told about it. The
/// comparison costs the size of the content when the items are rebuilt, as
/// a rehydration does; the rows that did not change keep the same string.
typedef _ItemSignature = ({
  ItemId id,
  ItemStatus? status,
  String? text,
  OutcomeKind? outcome,
  int? exitCode,
  Object? payload,
});

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
  id: item.id,
  status: item.status.known,
  text: switch (item) {
    AssistantText(:final text) => text,
    Reasoning(:final text) => text,
    UserInput(:final text) => text,
    Notice(:final text) => text,
    TurnOutcome(:final reason) => reason,
    UnknownItem(:final fallbackText) => fallbackText,
    // The rows show these on demand, so a change in them is content too.
    ShellRun(:final outputText, :final exitToken) =>
      exitToken == null ? outputText : '$exitToken\n$outputText',
    ToolCall(:final error) => error?.rawMessage,
  },
  // The outcome the row shows, which the reason behind it does not replace.
  outcome: switch (item) {
    TurnOutcome(:final kind) => kind.known,
    _ => null,
  },
  exitCode: switch (item) {
    ShellRun(:final exitCode) => exitCode,
    _ => null,
  },
  // A tool's input and output, compared by value: a re-read that brings the
  // same values back is not an arrival. A failed turn's error card too.
  payload: switch (item) {
    ToolCall(:final input, :final output) => (input, output),
    TurnOutcome(:final error) => (error?.kind.value, error?.rawMessage),
    _ => null,
  },
);
