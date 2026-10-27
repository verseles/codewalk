import 'package:flutter/foundation.dart';

/// Actions of the shown chat, also reached from the pane and app bar.
final class WorkspaceActions {
  VoidCallback? _focus;
  bool Function()? _closeTab;

  /// Makes [focus] the way to the shown composer until it is released.
  void claimComposer(VoidCallback focus) => _focus = focus;

  /// Lets [focus] go, unless another composer claimed the place since.
  void releaseComposer(VoidCallback focus) {
    if (_focus == focus) _focus = null;
  }

  /// Focuses the shown composer; false when none is shown.
  bool focusComposer() {
    final focus = _focus;
    focus?.call();
    return focus != null;
  }

  void claimTab(bool Function() close) => _closeTab = close;

  void releaseTab(bool Function() close) {
    if (_closeTab == close) _closeTab = null;
  }

  /// False only when the shown route has no eligible local tab to close.
  bool closeTab() => _closeTab?.call() ?? false;
}
