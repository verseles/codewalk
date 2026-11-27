import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The level a reasoning-effort variant shows beside its name in the
/// variant menu (#526), or null for Auto and for a variant that names no
/// known level. Only the glyph is chosen here: the variant keeps its id.
IconData? sessionVariantIcon(String variant) =>
    switch (variant.trim().toLowerCase()) {
      'none' || 'minimal' => Symbols.clock_loader_10,
      'low' => Symbols.clock_loader_20,
      'medium' => Symbols.clock_loader_40,
      'high' => Symbols.clock_loader_60,
      'xhigh' => Symbols.clock_loader_80,
      'max' => Symbols.psychology_alt,
      'ultra' => Symbols.person_celebrate,
      _ => null,
    };
