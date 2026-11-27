import 'package:codewalk/features/sessions/session_variant_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  test('each effort level has its icon; others have none (#526)', () {
    expect(
      {
        for (final id in [
          'none',
          'minimal',
          'low',
          'medium',
          'high',
          'xhigh',
          'max',
          'ultra',
        ])
          id: sessionVariantIcon(id),
      },
      {
        'none': Symbols.clock_loader_10,
        'minimal': Symbols.clock_loader_10,
        'low': Symbols.clock_loader_20,
        'medium': Symbols.clock_loader_40,
        'high': Symbols.clock_loader_60,
        'xhigh': Symbols.clock_loader_80,
        'max': Symbols.psychology_alt,
        'ultra': Symbols.person_celebrate,
      },
    );
    // Case and surrounding spaces do not matter.
    expect(sessionVariantIcon(' XHigh '), Symbols.clock_loader_80);
    // Auto (the empty value) and a variant that names no level.
    for (final id in ['', 'fast', 'thinking', 'x-high', 'highest']) {
      expect(sessionVariantIcon(id), isNull, reason: id);
    }
  });
}
