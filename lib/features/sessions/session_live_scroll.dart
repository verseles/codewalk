import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The scroll and viewport rules of the live session timeline.
///
/// The list follows the newest content while the reader is at the bottom. A
/// deliberate scroll by the reader stops that follow, and the follow resumes
/// only when the reader's gesture ends at the bottom or the reader asks for
/// the newest content explicitly.
///
/// Every threshold is a logical pixel, so a scaled text and a right-to-left
/// locale need no separate rule.
final class SessionLiveScroll extends ChangeNotifier {
  SessionLiveScroll({ScrollController? controller})
    : controller = controller ?? _KeptScrollController();

  /// The distance from the bottom within which the viewport counts as the
  /// bottom. One logical pixel, like the retained reference.
  static const double bottomEpsilon = 1;

  /// The scrollable the live timeline renders.
  final ScrollController controller;

  bool _following = true;
  bool _unreadBelow = false;
  bool _revealed = false;
  bool _programmatic = false;

  /// How many times the reader moved the list.
  ///
  /// Counted even when the move changes no state, so a jump that waits for an
  /// older page knows the reader went elsewhere while it loaded.
  int _readerMoves = 0;
  int get readerMoves => _readerMoves;

  /// The offset the viewport was at the last time it was observed, so a move
  /// that the timeline did not start is known.
  double? _lastPixels;

  /// What the timeline saw when it was last shown, kept while it is not, so
  /// a session shown again lays out the same rows under the kept offset and
  /// is told what changed meanwhile. Only the timeline reads and writes it.
  Object? timelineMemory;

  /// Whether the timeline follows the newest content.
  bool get following => _following;

  /// Whether content arrived below the viewport while the reader was away.
  bool get unreadBelow => _unreadBelow;

  /// Whether a finished answer is shown from its start, which counts as read.
  bool get revealed => _revealed;

  /// Whether a programmatic scroll is in flight, so it is never read as the
  /// reader's.
  bool get programmatic => _programmatic;

  /// The distance from the bottom of the viewport, in logical pixels.
  double get distanceToBottom {
    if (!controller.hasClients) return 0;
    final position = controller.position;
    final distance = position.maxScrollExtent - position.pixels;
    return distance < 0 ? 0 : distance;
  }

  /// Whether the viewport is at the bottom.
  bool get atBottom => distanceToBottom <= bottomEpsilon;

  /// The distance from the top of the window, in logical pixels.
  double get distanceToTop {
    if (!controller.hasClients) return 0;
    final position = controller.position;
    final distance = position.pixels - position.minScrollExtent;
    return distance < 0 ? 0 : distance;
  }

  /// The distance from the bottom beyond which returning to the first message
  /// is worth its own control, like the retained reference's 360.
  static const double firstControlDistance = 360;

  /// Whether the control that returns to the first message is offered.
  ///
  /// Kept as state because the distance it depends on changes with every
  /// scroll, and the timeline only rebuilds on a notification.
  bool _offersJumpToFirst = false;
  bool get offersJumpToFirst => _offersJumpToFirst;

  /// Recomputes the first-message control from the current state and offset.
  ///
  /// A scroll reports itself, but an arrival or a growth of the extent moves
  /// the distance the control depends on without one, so the timeline asks
  /// for the recomputation then.
  void syncJumpToFirst() {
    final next =
        !_following && !_revealed && distanceToBottom >= firstControlDistance;
    if (next == _offersJumpToFirst) return;
    _offersJumpToFirst = next;
    notifyListeners();
  }

  /// Whether a gesture of the reader is moving the list right now: a drag,
  /// the fling after it or a wheel. The timeline's own jumps never set it.
  bool get userScrolling =>
      controller.hasClients &&
      controller.position.userScrollDirection != ScrollDirection.idle;

  /// Whether a follow may move the viewport now. The reader's priority is
  /// carried by [following]: it stays off until the reader is back at the
  /// bottom with no gesture in progress, or uses the control.
  bool get mayFollow => _following && !_programmatic;

  /// Records a deliberate scroll by the reader: a drag, a fling or a wheel.
  ///
  /// The follow stops and a revealed answer stops being the reader's place,
  /// so a live update never pulls the content away from the reader.
  void markUserIntent() {
    if (_programmatic) return;
    _readerMoves++;
    _held = false;
    if (!_following && !_revealed) return;
    _following = false;
    _revealed = false;
    syncJumpToFirst();
    notifyListeners();
  }

  /// Records that the viewport moved or a gesture ended.
  ///
  /// At the bottom, once no gesture is in progress, the follow resumes and
  /// the mark of unseen content is cleared. A gesture still in progress keeps
  /// its priority even while it is within the bottom epsilon.
  void onViewportChanged() {
    syncJumpToFirst();
    if (_takeReaderMove()) {
      // The reader moved the list and the viewport is no longer at the
      // bottom: the follow stops, so a live update never pulls the content
      // away from the reader.
      markUserIntent();
    }
    if (!atBottom || userScrolling || _held) return;
    if (_following && !_unreadBelow && !_revealed) return;
    _following = true;
    _unreadBelow = false;
    _revealed = false;
    notifyListeners();
  }

  /// Records the offset of the viewport and reports whether the reader moved
  /// it.
  ///
  /// A page key and a click on the scrollbar track move the list with
  /// `moveTo`, which reports no scroll direction of its own, so the direction
  /// alone cannot tell the reader's scroll from the timeline's own. The
  /// offset can: a move the timeline did not start, that leaves the viewport
  /// away from the bottom, is the reader's. A removal that clamps the
  /// viewport leaves it at the bottom, and the content that arrives below
  /// does not move the offset at all.
  bool _takeReaderMove() {
    if (!controller.hasClients) return false;
    final pixels = controller.position.pixels;
    final last = _lastPixels;
    _lastPixels = pixels;
    if (last == null || pixels == last) return false;
    return !_programmatic && !atBottom;
  }

  /// Records that content arrived while the reader was away from the bottom,
  /// so the control that returns to it is marked.
  ///
  /// A revealed answer is no longer the reader's place: the content that
  /// arrived under it is what the reader has to come back to, so the control
  /// is offered again.
  void onContentArrivedAway() {
    if (_following) return;
    _unreadBelow = true;
    _revealed = false;
    // The arrival is no longer the reader's revealed place, and it changes
    // the distance to the bottom, so the first-message control is offered
    // again.
    syncJumpToFirst();
    notifyListeners();
  }

  /// Records that a finished answer is shown from its start.
  ///
  /// The answer the reader sees is already read, so the control that returns
  /// to the newest content stays hidden until the reader moves.
  void reveal() {
    _following = false;
    _revealed = true;
    _unreadBelow = false;
    syncJumpToFirst();
    notifyListeners();
  }

  /// Keeps the follow off, even at the bottom, until the reader moves the
  /// list or jumps to the newest content: a search shows a match there and
  /// new content must not pull it away (#462).
  void holdFollow() {
    _held = true;
    if (!_following) return;
    _following = false;
    syncJumpToFirst();
    notifyListeners();
  }

  bool _held = false;

  /// Ends [holdFollow] once the search no longer shows a match: at the
  /// bottom the follow resumes.
  void releaseHold() {
    if (!_held) return;
    _held = false;
    onViewportChanged();
  }

  /// Runs a programmatic scroll, so the notifications it produces are never
  /// read as the reader's.
  void runProgrammatic(VoidCallback action) {
    _programmatic = true;
    try {
      action();
    } finally {
      _programmatic = false;
    }
  }

  /// Jumps to the newest content and resumes the follow.
  ///
  /// The jump is a single synchronous move: an animated scroll would trail
  /// the content it is chasing.
  void jumpToLatest() {
    _held = false;
    _following = true;
    _revealed = false;
    _unreadBelow = false;
    syncJumpToFirst();
    if (controller.hasClients) {
      runProgrammatic(
        () => controller.jumpTo(controller.position.maxScrollExtent),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// A scroll controller whose next list starts where the last one stopped,
/// so a session shown again opens at the reader's place.
final class _KeptScrollController extends ScrollController {
  double? _kept;

  @override
  double get initialScrollOffset => _kept ?? super.initialScrollOffset;

  @override
  void detach(ScrollPosition position) {
    if (position.hasPixels) _kept = position.pixels;
    super.detach(position);
  }
}
