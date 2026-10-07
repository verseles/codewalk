// GENERATED CODE - DO NOT MODIFY BY HAND.
// Offline selective port: tool/theme/port_v2_appearance.py

import 'package:flutter/material.dart';

/// Brand color presets for the color picker when dynamic color is disabled.
enum BrandColor {
  codewalkBlue(0xFF3A6EA5, 'CodeWalk Blue'),
  deepPurple(0xFF6750A4, 'Deep Purple'),
  oceanTeal(0xFF006B5E, 'Ocean Teal'),
  sunsetOrange(0xFFBC5B2E, 'Sunset Orange'),
  forestGreen(0xFF386A20, 'Forest Green');

  const BrandColor(this.value, this.label);

  final int value;
  final String label;

  Color get seed => Color(value);
}
