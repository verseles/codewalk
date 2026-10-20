import 'package:flutter/widgets.dart';

/// The scroll and viewport rules of the live session timeline.
///
/// The list follows the newest content while the reader is at the bottom. A
/// deliberate scroll by the reader stops that follow, and the follow resumes
/// when the reader comes back to the bottom or asks for the newest content
/// explicitly.
///
/// Every threshold is a logical pixel, so a scaled text and a right-to-left
/// locale need no separate rule.
final class SessionLiveScroll extends ChangeNotifier {
  SessionLiveScroll({DateTime Function()? now, ScrollController? controller})
    : _now = now ?? DateTime.now,
      controller = controller ?? ScrollController();

  /// The distance from the bottom within which the viewport counts as the
  /// bottom. One logical pixel, like the retained reference.
  static const double bottomEpsilon = 1;

  /// How long a reader's scroll keeps priority over the follow, like the
  /// retained reference. Reaching the bottom ends it early.
  static const Duration userIntentHold = Duration(milliseconds: 900);

  /// The clock the intent hold is measured against.
  final DateTime Function() _now;

  /// The scrollable the live timeline renders.
  final ScrollController controller;

  DateTime? _lastUserIntentAt;
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

  /// Whether the reader scrolled recently enough to keep priority over the
  /// follow.
  bool get hasUserIntent {
    final last = _lastUserIntentAt;
    if (last == null) return false;
    return _now().difference(last) < userIntentHold;
  }

  /// Whether a follow may move the viewport now.
  bool get mayFollow => _following && !hasUserIntent && !_programmatic;

  /// Records a deliberate scroll by the reader: a drag, a fling or a wheel.
  ///
  /// The follow stops and a revealed answer stops being the reader's place,
  /// so a live update never pulls the content away from the reader.
  void markUserIntent() {
    if (_programmatic) return;
    _lastUserIntentAt = _now();
    if (!_following && !_revealed) return;
    _following = false;
    _revealed = false;
    notifyListeners();
  }

  /// Records that the viewport moved.
  ///
  /// At the bottom the reader's priority ends, the follow resumes and the
  /// mark of unseen content is cleared.
  void onViewportChanged() {
    if (!atBottom) return;
    _lastUserIntentAt = null;
    if (_following && !_unreadBelow && !_revealed) return;
    _following = true;
    _unreadBelow = false;
    _revealed = false;
    notifyListeners();
  }

  /// Records that the content grew while the reader was away from the
  /// bottom, so the control that returns to it is marked.
  void onContentGrewAway() {
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
    _lastUserIntentAt = null;
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
