import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

/// Contract-derived (`plan/12` §6): every 2.0.22 `Session.StructuredError`
/// type and its category; null is an interruption without a card. These are
/// schema-derived, not observed: only `provider.auth` and
/// `provider.invalid-output` are captured (B, C and E replays).
const _types = <String, ErrorKind?>{
  'provider.rate-limit': ErrorKind.rateLimit,
  'provider.quota': ErrorKind.quota,
  'provider.auth': ErrorKind.auth,
  'provider.content-filter': ErrorKind.contentFilter,
  'provider.transport': ErrorKind.network,
  'provider.timeout': ErrorKind.network,
  'provider.internal': ErrorKind.provider,
  'provider.invalid-output': ErrorKind.provider,
  'provider.invalid-request': ErrorKind.provider,
  'provider.unsupported-operation': ErrorKind.provider,
  'provider.no-route': ErrorKind.provider,
  'provider.unknown': ErrorKind.provider,
  'provider.error': ErrorKind.provider,
  'aborted': null,
  'permission.rejected': ErrorKind.permissionRejected,
  'tool.execution': ErrorKind.toolFailure,
  'tool.unknown': ErrorKind.toolFailure,
  'tool.input-json': ErrorKind.toolFailure,
  'tool.result-missing': ErrorKind.toolFailure,
  'compaction.failed': ErrorKind.contextOverflow,
  'compaction.interrupted': ErrorKind.contextOverflow,
  'compaction.unavailable': ErrorKind.contextOverflow,
  'unknown': ErrorKind.unknown,
};

void main() {
  test('every 2.0.22 type maps to one category and one action', () {
    expect(_types, hasLength(23));
    for (final MapEntry(key: type, value: kind) in _types.entries) {
      final error = openCodeErrorInfo(type, 'Reported.');
      expect(error.rawType, type);
      expect(error.rawMessage, 'Reported.');
      expect(error.retryable, isFalse, reason: type);
      expect(error.retryAt, isNull, reason: type);
      expect(error.details, isNull, reason: type);
      expect(openCodeErrorHasCard(type), kind != null, reason: type);
      if (kind == null) {
        expect(error.kind.known, ErrorKind.unknown);
        expect(error.action, isNull);
      } else {
        expect(error.kind.known, kind, reason: type);
        expect(error.action!.known, ErrorAction.changeModel, reason: type);
      }
    }
  });

  test('an unrecognized type is unknown, never guessed from its text', () {
    for (final type in [
      'provider.future',
      'Provider.Auth',
      ' provider.auth',
      'auth',
      'rate-limit',
    ]) {
      final error = openCodeErrorInfo(type, 'HTTP 429 quota exceeded');
      expect(error.kind.known, ErrorKind.unknown, reason: type);
      expect(error.action!.known, ErrorAction.changeModel);
      expect(openCodeErrorHasCard(type), isTrue);
    }
  });

  test('the message is bounded in UTF-8 bytes on a code point', () {
    const limit = openCodeErrorMessageLimit;
    expect(limit, 8 * 1024);
    final exact = openCodeErrorInfo('unknown', 'a' * limit);
    expect(exact.rawMessage, hasLength(limit));
    expect(exact.details, isNull);
    final over = openCodeErrorInfo('unknown', 'a' * (limit + 1));
    expect(over.rawMessage, hasLength(limit));
    expect(over.details!.value, {'messageTruncated': true});
    final emoji = openCodeErrorInfo('unknown', 'a${'😀' * 2048}');
    expect(utf8.encode(emoji.rawMessage), hasLength(limit - 3));
    expect(emoji.rawMessage.runes.last, '😀'.runes.single);
    final empty = openCodeErrorInfo('unknown', null);
    expect(empty.rawMessage, '');
    expect(empty.details, isNull);
  });

  test('a credential is redacted, also where the bound cuts it', () {
    final bearer = openCodeErrorInfo(
      'provider.auth',
      'Denied. Authorization: Bearer abc.def.ghi',
    );
    expect(bearer.rawMessage, 'Denied. Authorization: Bearer [redacted]');
    expect(bearer.details!.value, {'messageRedacted': true});
    final crossing = openCodeErrorInfo(
      'provider.auth',
      '${'x' * (openCodeErrorMessageLimit - 30)} '
          'Authorization: Bearer secret-token-value-123',
    );
    expect(crossing.rawMessage, isNot(contains('secret')));
    expect(crossing.rawMessage, isNot(contains('token-value')));
    expect(utf8.encode(crossing.rawMessage).length <= 8 * 1024, isTrue);
  });
}
