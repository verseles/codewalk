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
    : controller = controller ?? ScrollController();

  /// The distance from the bottom within which the viewport counts as the
  /// bottom. One logical pixel, like the retained reference.
  static const double bottomEpsilon = 1;

  /// The scrollable the live timeline renders.
  final ScrollController controller;

  bool _following = true;
  bool _unreadBelow = false;
  bool _revealed = false;
  bool _programmatic = false;

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
    if (!_following && !_revealed) return;
    _following = false;
    _revealed = false;
    notifyListeners();
  }

  /// Records that the viewport moved or a gesture ended.
  ///
  /// At the bottom, once no gesture is in progress, the follow resumes and
  /// the mark of unseen content is cleared. A gesture still in progress keeps
  /// its priority even while it is within the bottom epsilon.
  void onViewportChanged() {
    if (!atBottom || userScrolling) return;
    if (_following && !_unreadBelow && !_revealed) return;
    _following = true;
    _unreadBelow = false;
    _revealed = false;
    notifyListeners();
  }

  /// Records that content arrived while the reader was away from the bottom,
  /// so the control that returns to it is marked.
  void onContentArrivedAway() {
    if (_following || _unreadBelow) return;
    _unreadBelow = true;
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
    notifyListeners();
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
    _following = true;
    _revealed = false;
    _unreadBelow = false;
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
