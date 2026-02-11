import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/utils/session_title_formatter.dart';

void main() {
  group('SessionTitleFormatter', () {
    test('returns explicit non-empty title when provided', () {
      final title = SessionTitleFormatter.displayTitle(
        time: DateTime(2026, 2, 11, 10, 30),
        title: '  My Session  ',
        now: DateTime(2026, 2, 11, 11, 0),
      );

      expect(title, 'My Session');
    });

    test('formats today fallback with absolute date to avoid ambiguity', () {
      final title = SessionTitleFormatter.displayTitle(
        time: DateTime(2026, 2, 11, 10, 30),
        title: null,
        now: DateTime(2026, 2, 11, 12, 0),
      );

      expect(title, 'Today 10:30 (2/11/2026)');
    });

    test('formats yesterday fallback with absolute date', () {
      final title = SessionTitleFormatter.fallbackTitle(
        time: DateTime(2026, 2, 10, 9, 5),
        now: DateTime(2026, 2, 11, 12, 0),
      );

      expect(title, 'Yesterday 09:05 (2/10/2026)');
    });

    test('formats recent weekday fallback', () {
      final title = SessionTitleFormatter.fallbackTitle(
        time: DateTime(2026, 2, 9, 14, 15),
        now: DateTime(2026, 2, 11, 12, 0),
      );

      expect(title, 'Mon 14:15 (2/9/2026)');
    });

    test('formats older fallback as absolute date and time', () {
      final title = SessionTitleFormatter.fallbackTitle(
        time: DateTime(2025, 12, 31, 23, 45),
        now: DateTime(2026, 2, 11, 12, 0),
      );

      expect(title, '12/31/2025 23:45');
    });
  });
}
