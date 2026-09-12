import 'package:codewalk/presentation/utils/chat_server_error_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isServerConnectionFailure', () {
    test('detects transport failure text', () {
      expect(
        isServerConnectionFailure(
          rawMessage: 'SocketException: Connection refused',
        ),
        isTrue,
      );
    });

    test('ignores authentication failures', () {
      expect(
        isServerConnectionFailure(rawMessage: 'Unauthorized', statusCode: 401),
        isFalse,
      );
    });
  });

  group('isServerUnavailableFailure', () {
    test('detects provider unavailable text', () {
      expect(
        isServerUnavailableFailure(rawMessage: 'service unavailable'),
        isTrue,
      );
    });

    test('ignores authentication failures', () {
      expect(
        isServerUnavailableFailure(rawMessage: 'Unauthorized', statusCode: 401),
        isFalse,
      );
    });
  });

  group('formatServerErrorForDisplay', () {
    test('maps quota signals to concise quota copy', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'insufficient_quota: billing hard limit reached',
      );

      expect(display.name, 'Quota exceeded');
      expect(
        display.message,
        'Quota exceeded. Check your provider plan or billing.',
      );
    });

    test('maps 429 and rate-limit text', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'Rate limit exceeded',
        statusCode: 429,
      );

      expect(display.name, 'Rate limit exceeded');
      expect(
        display.message,
        'Rate limit exceeded. Wait a moment and try again.',
      );
    });

    test('maps numeric 429 code without statusCode', () {
      final display = formatServerErrorForDisplay(code: '429');

      expect(display.name, 'Rate limit exceeded');
    });

    test('does not treat incidental 429 digits as rate limit', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'reset at 4290 seconds',
      );

      expect(display.name, 'Server error');
      expect(display.message, 'reset at 4290 seconds');
    });

    test('maps authentication failures', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'Unauthorized',
        statusCode: 401,
      );

      expect(display.name, 'Authentication required');
      expect(
        display.message,
        'Authentication failed. Reconnect the provider and try again.',
      );
    });

    test('maps network/connection failures', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'SocketException: Connection refused',
      );

      expect(display.name, 'Connection failed');
      expect(
        display.message,
        'Unable to reach the server. Check connection and server status.',
      );
    });

    test('keeps readable fallback message for unknown errors', () {
      final display = formatServerErrorForDisplay(
        rawMessage: 'Error: upstream policy denied',
      );

      expect(display.name, 'Server error');
      expect(display.message, 'upstream policy denied');
    });
  });
}
