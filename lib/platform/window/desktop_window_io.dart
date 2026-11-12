import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_window_port.dart';

/// The Linux window, the only shipped desktop target; other platforms keep
/// their system chrome until their runners are prepared for it.
DesktopWindowPort? platformDesktopWindow() =>
    Platform.isLinux ? _WindowManagerPort() : null;

/// The window_manager plugin behind the port. Hiding the title bar hides the
/// GTK header bar, so GNOME keeps its native frame, resize borders and
/// snapping. A call the compositor refuses leaves the window as it was.
class _WindowManagerPort with WindowListener implements DesktopWindowPort {
  final _closes = StreamController<void>.broadcast();
  final _maximized = ValueNotifier(false);
  Future<bool>? _ready;

  Future<bool> _init() => _ready ??= () async {
    try {
      await windowManager.ensureInitialized();
      if (_closes.isClosed) return false;
      windowManager.addListener(this);
      final maximized = await windowManager.isMaximized();
      if (_closes.isClosed) return false;
      _maximized.value = maximized;
      return true;
    } catch (_) {
      return false;
    }
  }();

  Future<bool> _call(Future<void> Function() action) async {
    if (_closes.isClosed || !await _init() || _closes.isClosed) return false;
    try {
      await action();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setTitleBarHidden(bool hidden) => _call(
    () => windowManager.setTitleBarStyle(
      hidden ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
  );

  @override
  Future<bool> setPreventClose(bool prevent) =>
      _call(() => windowManager.setPreventClose(prevent));

  @override
  Stream<void> get closeRequests => _closes.stream;

  @override
  ValueListenable<bool> get maximized => _maximized;

  @override
  Future<void> minimize() => _call(windowManager.minimize);

  @override
  Future<void> toggleMaximize() => _call(() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  });

  @override
  Future<void> startDragging() => _call(windowManager.startDragging);

  @override
  void onWindowClose() {
    if (!_closes.isClosed) _closes.add(null);
  }

  @override
  void onWindowMaximize() => _maximized.value = true;

  @override
  void onWindowUnmaximize() => _maximized.value = false;

  @override
  void dispose() {
    if (_closes.isClosed) return;
    windowManager.removeListener(this);
    unawaited(_closes.close());
    _maximized.dispose();
  }
}
