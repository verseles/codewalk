import 'package:codewalk/presentation/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldNotifyInstallProgress', () {
    final base = DateTime(2026, 9, 2, 12);

    test('always notifies on completion', () {
      expect(
        shouldNotifyInstallProgress(
          previous: 0.99,
          next: 1.0,
          lastNotifiedAt: base,
          now: base,
        ),
        isTrue,
      );
    });

    test('skips changes below the delta', () {
      expect(
        shouldNotifyInstallProgress(
          previous: 0.5,
          next: 0.505,
          lastNotifiedAt: null,
          now: base,
        ),
        isFalse,
      );
    });

    test('notifies on first sufficient delta', () {
      expect(
        shouldNotifyInstallProgress(
          previous: 0.5,
          next: 0.52,
          lastNotifiedAt: null,
          now: base,
        ),
        isTrue,
      );
    });

    test('throttles rapid sufficient deltas', () {
      expect(
        shouldNotifyInstallProgress(
          previous: 0.5,
          next: 0.52,
          lastNotifiedAt: base,
          now: base.add(const Duration(milliseconds: 50)),
        ),
        isFalse,
      );
      expect(
        shouldNotifyInstallProgress(
          previous: 0.5,
          next: 0.52,
          lastNotifiedAt: base,
          now: base.add(const Duration(milliseconds: 100)),
        ),
        isTrue,
      );
    });
  });
}
