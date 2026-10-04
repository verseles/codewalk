import 'package:flutter/widgets.dart';

/// MD3 window size classes based on width breakpoints.
/// See: https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum WindowSizeClass {
  compact, // < 600dp
  medium, // 600–839dp
  expanded, // 840–1199dp
  large, // 1200–1599dp
  extraLarge // >= 1600dp
  ;

  factory WindowSizeClass.fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    if (width < 1200) return WindowSizeClass.expanded;
    if (width < 1600) return WindowSizeClass.large;
    return WindowSizeClass.extraLarge;
  }

  bool get isCompact => this == compact;
  bool get isAtLeastMedium => index >= medium.index;
  bool get isAtLeastExpanded => index >= expanded.index;
  bool get isAtLeastLarge => index >= large.index;
  bool get isAtLeastExtraLarge => index >= extraLarge.index;
}

extension WindowSizeClassContext on BuildContext {
  /// Resolve the window size class from the current media query width.
  WindowSizeClass get windowSizeClass =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
