import 'package:flutter/material.dart';

/// Centralized MD3 shape constants.
/// See: https://m3.material.io/styles/shape/overview
class AppShapes {
  AppShapes._();

  // Raw radius values
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 28;
  static const double full = 999;

  // Pre-built BorderRadius for convenience
  static final BorderRadius borderNone = BorderRadius.circular(none);
  static final BorderRadius borderExtraSmall = BorderRadius.circular(
    extraSmall,
  );
  static final BorderRadius borderSmall = BorderRadius.circular(small);
  static final BorderRadius borderMedium = BorderRadius.circular(medium);
  static final BorderRadius borderLarge = BorderRadius.circular(large);
  static final BorderRadius borderExtraLarge = BorderRadius.circular(
    extraLarge,
  );
  static final BorderRadius borderFull = BorderRadius.circular(full);
}
