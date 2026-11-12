import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/window/desktop_window_port.dart';
import 'app_preferences_controller.dart';

/// The desktop window as the app uses it: whether the integrated band
/// replaces the system title bar, and what closing the window does.
///
/// The band is [active] only while the preference asks for it and the
/// window manager hid the system title bar; a refusal keeps the system title
/// bar, so the window never ends up without controls. Closing follows the
/// preference at the moment of the request: Close quits through [quit],
/// Minimize keeps the app running.
class DesktopWindowController extends ChangeNotifier {
  DesktopWindowController({
    required DesktopWindowPort port,
    required AppPreferencesController preferences,
    required Future<void> Function() quit,
  }) : _port = port,
       _preferences = preferences,
       _quit = quit;

  final DesktopWindowPort _port;
  final AppPreferencesController _preferences;
  final Future<void> Function() _quit;
  StreamSubscription<void>? _closes;
  bool? _applied;
  bool _active = false;
  bool _attached = false;
  bool _quitting = false;
  bool _disposed = false;

  bool get active => _active;
  ValueListenable<bool> get maximized => _port.maximized;

  /// Applies the saved choice before the first frame, then follows it.
  Future<void> attach() async {
    if (_attached || _disposed) return;
    _attached = true;
    _preferences.addListener(_onPreferences);
    await _sync();
    if (_disposed) return;
    // A window that cannot hold its close request closes as before; the
    // choice then still applies to the band's button and the shortcut.
    if (await _port.setPreventClose(true) && !_disposed) {
      _closes = _port.closeRequests.listen((_) => unawaited(requestClose()));
    }
  }

  void _onPreferences() => unawaited(_sync());

  Future<void> _sync() async {
    final wanted = _preferences.integratedWindowChrome;
    if (_disposed || _applied == wanted) return;
    _applied = wanted;
    final hidden = await _port.setTitleBarHidden(wanted);
    if (_disposed || _applied != wanted) return;
    final active = wanted && hidden;
    if (active == _active) return;
    _active = active;
    notifyListeners();
  }

  /// The window's close: its button in the band, the window manager's
  /// request, and mod+W with no tab to close.
  Future<void> requestClose() async {
    if (_disposed) return;
    if (_preferences.windowCloseAction == WindowCloseAction.minimize) {
      await _port.minimize();
      return;
    }
    // The platform takes one exit request at a time; a second click while
    // the app is quitting is the same request.
    if (_quitting) return;
    _quitting = true;
    try {
      await _quit();
    } finally {
      _quitting = false;
    }
  }

  void minimize() => unawaited(_port.minimize());
  void toggleMaximize() => unawaited(_port.toggleMaximize());
  void startDragging() => unawaited(_port.startDragging());

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _preferences.removeListener(_onPreferences);
    unawaited(_closes?.cancel());
    _port.dispose();
    super.dispose();
  }
}
