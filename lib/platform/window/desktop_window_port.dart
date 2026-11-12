import 'package:flutter/foundation.dart';

/// The native desktop window: its title bar, its controls and its close
/// request. Only the Linux implementation talks to the window manager; tests
/// stand in for it.
abstract interface class DesktopWindowPort {
  /// Hides or shows the system title bar; false when the platform refused.
  Future<bool> setTitleBarHidden(bool hidden);

  /// Whether a close request from the window manager waits for
  /// [closeRequests] instead of closing the window; false when refused.
  Future<bool> setPreventClose(bool prevent);

  /// The window manager asked to close the window (its close button,
  /// Alt+F4 or the taskbar).
  Stream<void> get closeRequests;

  /// Whether the window is maximized, kept current by the window manager.
  ValueListenable<bool> get maximized;

  Future<void> minimize();
  Future<void> toggleMaximize();

  /// Moves the window with the pointer that is down.
  Future<void> startDragging();

  void dispose();
}
