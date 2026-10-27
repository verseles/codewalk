import 'package:flutter/foundation.dart';

/// The composer the workspace shows, so mod+L and a single Escape reach it
/// from anywhere in the workspace, not only from inside its page.
final class ShownComposer {
  VoidCallback? _focus;

  /// Makes [focus] the way to the shown composer until it is released.
  void claim(VoidCallback focus) => _focus = focus;

  /// Lets [focus] go, unless another composer claimed the place since.
  void release(VoidCallback focus) {
    if (_focus == focus) _focus = null;
  }

  /// Focuses the shown composer; false when none is shown.
  bool focus() {
    final focus = _focus;
    focus?.call();
    return focus != null;
  }
}
