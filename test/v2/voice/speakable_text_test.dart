import 'package:codewalk/shared/voice/read_aloud.dart';
import 'package:codewalk/shared/voice/speakable_text.dart';
import 'package:flutter_test/flutter_test.dart';

// #541: what a message sounds like, and the read-aloud choices.

void main() {
  test('markdown leaves only the words to speak', () {
    const message = '''
# Done

Run `make check` and see [the docs](https://example.com).

```dart
final hidden = true;
```

| a | b |
|---|---|
| 1 | 2 |

- first **item**
- second <b>one</b>

\$\$x^2\$\$
''';
    expect(
      speakableText(message),
      'Done\nRun make check and see the docs.\nfirst item\nsecond one',
    );
    expect(speakableText('```\nonly code\n```'), isEmpty);
  });

  test('code and comparisons are read as written; math and HTML are not', () {
    expect(
      speakableText(
        r'Use `List<String>` when a < b and c > d, not $\frac{1}{2}$. '
        '<!-- note --><pre>hidden</pre><b>Bold</b> end.',
      ),
      'Use List<String> when a < b and c > d, not . Bold end.',
    );
  });

  test('provider addresses stay encrypted beyond the local network', () {
    bool secure(String address) => speechAddressSecure(Uri.parse(address));
    for (final address in [
      'https://api.example.com',
      'http://localhost:8000',
      'http://127.0.0.1:9000',
      'http://192.168.1.5',
      'http://10.0.0.2',
      'http://172.20.0.1',
      'http://100.100.1.1',
      'http://box.tail1234.ts.net',
      'http://printer.local',
      'http://[fd00::1]:80',
    ]) {
      expect(secure(address), isTrue, reason: address);
    }
    for (final address in [
      'http://example.com',
      'http://8.8.8.8',
      'http://172.32.0.1',
      'ftp://files.example.com',
    ]) {
      expect(secure(address), isFalse, reason: address);
    }
  });

  test('settings round-trip and tolerate bad values', () {
    const settings = ReadAloudSettings(
      provider: SpeechProvider.elevenLabs,
      voice: 'v',
      rate: 0.7,
      baseUrl: 'https://x',
      model: 'm',
    );
    final again = ReadAloudSettings.decode(
      '{"v":1,"enabled":true,"provider":"elevenLabs","voice":"v",'
      '"rate":0.7,"pitch":1.0,"baseUrl":"https://x","model":"m"}',
    );
    expect(again, settings);
    expect(settings.toJson().containsKey('apiKey'), isFalse);
    final odd = ReadAloudSettings.decode(
      '{"enabled":"yes","provider":"nope","rate":9,"voice":""}',
    )!;
    expect(odd.enabled, isTrue);
    expect(odd.provider, SpeechProvider.edge);
    expect(odd.rate, 1);
    expect(odd.voice, isNull);
    expect(ReadAloudSettings.decode('not json'), isNull);
  });
}
