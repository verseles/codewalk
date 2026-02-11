import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/services/notification_service.dart';

void main() {
  test('serializes and parses notification payload with session id', () {
    const payload = NotificationTapPayload(
      category: 'agent',
      sessionId: 'ses_123',
    );

    final raw = payload.toRaw();
    final parsed = NotificationTapPayload.fromRaw(raw);

    expect(parsed, isNotNull);
    expect(parsed?.category, 'agent');
    expect(parsed?.sessionId, 'ses_123');
  });

  test('returns null for invalid payload', () {
    expect(NotificationTapPayload.fromRaw('invalid-json'), isNull);
    expect(NotificationTapPayload.fromRaw('{}'), isNull);
  });
}
