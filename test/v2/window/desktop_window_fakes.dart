import 'dart:async';

import 'package:codewalk/platform/window/desktop_window_port.dart';
import 'package:flutter/foundation.dart';

/// A desktop window that records what the app asks of it; [hides] and
/// [prevents] say whether the window manager accepts those requests.
class FakeDesktopWindowPort implements DesktopWindowPort {
  FakeDesktopWindowPort({this.hides = true, this.prevents = true});

  bool hides;
  bool prevents;
  final titleBarHidden = <bool>[];
  final preventClose = <bool>[];
  var minimized = 0;
  var toggled = 0;
  var drags = 0;
  var disposed = false;
  final _closes = StreamController<void>.broadcast();
  final maximizedNotifier = ValueNotifier(false);

  /// The window manager's close button, Alt+F4 or the taskbar.
  void requestClose() => _closes.add(null);

  @override
  Future<bool> setTitleBarHidden(bool hidden) async {
    titleBarHidden.add(hidden);
    return hides;
  }

  @override
  Future<bool> setPreventClose(bool prevent) async {
    preventClose.add(prevent);
    return prevents;
  }

  @override
  Stream<void> get closeRequests => _closes.stream;

  @override
  ValueListenable<bool> get maximized => maximizedNotifier;

  @override
  Future<void> minimize() async => minimized++;

  @override
  Future<void> toggleMaximize() async => toggled++;

  @override
  Future<void> startDragging() async => drags++;

  @override
  void dispose() {
    disposed = true;
    unawaited(_closes.close());
  }
}
