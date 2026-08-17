import 'package:codewalk/core/logging/android_process_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes only safe native process diagnostics', () {
    final normalized =
        AndroidProcessDiagnostics.normalizeNativeDiagnostics(<Object?, Object?>{
          'pid': 42.9,
          'activityId': 10,
          'engineId': 11,
          'activityRecreated': true,
          'lastExitReason': 5,
          'lastExitPssKb': 1234.8,
          'secret': 'must be dropped',
          'description': 'must be dropped',
        });

    expect(normalized['pid'], 42);
    expect(normalized['activityId'], 10);
    expect(normalized['engineId'], 11);
    expect(normalized['activityRecreated'], isTrue);
    expect(normalized['lastExitReason'], 5);
    expect(normalized['lastExitPssKb'], 1234);
    expect(normalized.containsKey('secret'), isFalse);
    expect(normalized.containsKey('description'), isFalse);
  });

  test('drops invalid native diagnostic types', () {
    final normalized = AndroidProcessDiagnostics.normalizeNativeDiagnostics(
      <Object?, Object?>{
        'pid': '42',
        'activityRecreated': 'true',
        'lastExitReason': null,
      },
    );

    expect(normalized, isEmpty);
  });
}
