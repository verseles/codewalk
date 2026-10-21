import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  group('redactCredentialText removes', () {
    final cases = {
      'password=hunter2xyz': 'password=[redacted]',
      'API_KEY: abc123def456': 'API_KEY: [redacted]',
      'export GITHUB_TOKEN=ghx_notatoken': 'export GITHUB_TOKEN=[redacted]',
      '{"client_secret": "s3cr3t-value"}': '{"client_secret": "[redacted]"}',
      'curl -H "Authorization: Bearer abcdefgh12345678"':
          'curl -H "Authorization: [redacted] [redacted]"',
      'Bearer abcdefgh12345678': 'Bearer [redacted]',
      'mysql --password=hunter2 db': 'mysql --password=[redacted] db',
      'tool --token "quoted value"': 'tool --token [redacted]',
      'git clone https://user:pa55word@example.com/r.git':
          'git clone https://[redacted]@example.com/r.git',
      'key sk-proj-ABCDEFGHIJKLMNOPQRST end': 'key [redacted] end',
      'ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345': '[redacted]',
      'github_pat_ABCDEFGHIJKLMNOPQRSTUVWX_YZ': '[redacted]',
      'xoxb-1234567890-abcdef': '[redacted]',
      'AKIAABCDEFGHIJKLMNOP': '[redacted]',
      'jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abcdefghijklmnop':
          'jwt [redacted]',
      '-----BEGIN RSA PRIVATE KEY-----\nMIIabc\n-----END RSA PRIVATE KEY-----\nok':
          '[redacted]\nok',
      'tail -----BEGIN OPENSSH PRIVATE KEY-----\nAAAA unterminated':
          'tail [redacted]',
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input.split('\n').first, () {
        expect(redactCredentialText(input), expected);
      });
    }
  });

  group('redactCredentialText keeps', () {
    for (final text in [
      r'echo $PATH',
      'PWD=/home/user/project',
      'the token is refreshed hourly',
      'max_tokens: 4096',
      'Bearer token',
      'https://example.com/path?q=1',
      'exit code 0',
      '',
    ]) {
      test(text.isEmpty ? '(empty)' : text, () {
        expect(redactCredentialText(text), text);
      });
    }
  });

  test('is idempotent', () {
    const text = 'password=abc Bearer abcdefgh12345678 https://u:p@h/x';
    final once = redactCredentialText(text);
    expect(once, isNot(contains('abcdefgh12345678')));
    expect(redactCredentialText(once), once);
  });
}
