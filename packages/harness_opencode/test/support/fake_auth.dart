import 'dart:convert';

/// Explicitly synthetic credentials; no captured redaction can authenticate.
final class FakeAuth {
  FakeAuth(this.namespace) : bootstrapPassword = '$namespace-bootstrap' {
    _passwords.add(bootstrapPassword);
  }

  final String namespace;
  final String bootstrapPassword;
  final _passwords = <String>{};
  final _codes = <String, Duration>{};
  Duration _now = Duration.zero;
  int _sequence = 0;

  String authorization([String? password]) =>
      'Basic ${base64Encode(utf8.encode('opencode:${password ?? bootstrapPassword}'))}';

  bool accepts(String? header) {
    if (header == null) return false;
    return _passwords.any((password) => header == authorization(password));
  }

  Map<String, Object?> issuePairing() {
    final code = '$namespace-code-${++_sequence}';
    _codes[code] = _now + const Duration(minutes: 5);
    return {'code': code, 'expires_in': 300};
  }

  String? redeem(String code) {
    final expiry = _codes.remove(code);
    if (expiry == null || _now >= expiry) return null;
    final password = '$namespace-token-${++_sequence}';
    _passwords.add(password);
    return password;
  }

  void advance(Duration elapsed) {
    if (elapsed.isNegative) throw ArgumentError('Clock cannot move backwards.');
    _now += elapsed;
  }
}
