import 'desktop_window_port.dart';

/// No native window to drive on this platform: the browser or the system
/// keeps its own chrome.
DesktopWindowPort? platformDesktopWindow() => null;
