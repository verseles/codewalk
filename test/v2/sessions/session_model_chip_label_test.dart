import 'package:codewalk/features/sessions/session_model_chip_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String short(String name) => modelChipLabel(name).text;

  test('each rule of the table, with the examples agreed (#524)', () {
    expect(
      {
        for (final name in [
          'Claude Opus 5.5',
          'Claude Fable 5.2',
          'Claude Sonnet 4.6',
          'GPT-6.2 Sol',
          'GPT-6 Astra',
          'GPT-5.4 mini',
          'Gemini 3.5 Flash Lite',
          'Gemini 2.5 Flash-Lite',
          'Muse Spark 1.3 Contributor',
          'Muse Spark 1.2',
          'Claude Haiku 4.5 (latest)',
          'Nemotron 3 Ultra 550B A55B',
          'antigravity-gemini-4-neon-high',
          'MiniMax-M3.1-Flash',
          'MiniMax M3.1 Flash',
          'MiniMax-M3',
          'Kimi K3.1 Pro',
          'Kimi K3.1 Pro Highspeed',
          'Gemini 4 Neon',
          'Gemini 4 Hydrogen',
          'DeepSeek V4 Pro',
          'Nemotron 3.5 Lightning 30B A3B',
          'Qwen3 235B A22B Instruct 2507',
        ])
          name: short(name),
      },
      {
        'Claude Opus 5.5': 'Opus 5.5',
        'Claude Fable 5.2': 'Fable 5.2',
        'Claude Sonnet 4.6': 'Sonnet 4.6',
        'GPT-6.2 Sol': '6.2 Sol',
        'GPT-6 Astra': '6 Astra',
        'GPT-5.4 mini': 'GPT-5.4 mini',
        'Gemini 3.5 Flash Lite': 'Gemini 3.5 Lite',
        'Gemini 2.5 Flash-Lite': 'Gemini 2.5 Lite',
        'Muse Spark 1.3 Contributor': 'Spark 1.3',
        'Muse Spark 1.2': 'Spark 1.2',
        'Claude Haiku 4.5 (latest)': 'Haiku 4.5',
        'Nemotron 3 Ultra 550B A55B': 'Nemo 3 Ultra 550B',
        'antigravity-gemini-4-neon-high': 'AGY gemini-4-neon-high',
        'MiniMax-M3.1-Flash': 'M3.1 Flash',
        'MiniMax M3.1 Flash': 'M3.1 Flash',
        'MiniMax-M3': 'M3',
        'Kimi K3.1 Pro': 'K3.1 Pro',
        'Kimi K3.1 Pro Highspeed': 'K3.1 Pro HS',
        'Gemini 4 Neon': '4 Neon',
        'Gemini 4 Hydrogen': '4 Hydrogen',
        'DeepSeek V4 Pro': 'DS V4 Pro',
        'Nemotron 3.5 Lightning 30B A3B': 'Nemo 3.5 Lightning 30B',
        'Qwen3 235B A22B Instruct 2507': 'Qwen3 235B IT 2507',
      },
    );
  });

  test('what the owner kept on purpose stays', () {
    for (final name in [
      'Gemini 3.1 Pro Preview',
      'Gemma 4 26B IT',
      'Gemini 2.5 Pro Preview 06-05',
      'Big Pickle',
      'Claude Opus', // no version: rule 1 needs the space after the family
    ]) {
      expect(short(name), name, reason: name);
    }
  });

  test('Free becomes the icon, only as a whole word', () {
    for (final (name, text) in [
      ('DeepSeek V4.1 Flash Free', 'DS V4.1 Flash'),
      ('Nemotron 3.5 Lightning (free)', 'Nemo 3.5 Lightning'),
      ('Beam Free', 'Beam'),
      // Read first, so an end-anchored rule still applies.
      ('Muse Spark 1.3 Contributor Free', 'Spark 1.3'),
    ]) {
      final label = modelChipLabel(name);
      expect(label.text, text, reason: name);
      expect(label.free, isTrue, reason: name);
    }
    // A leading Free leaves the start to the anchored rules.
    expect(short('Free GPT-6.2 Sol'), '6.2 Sol');
    expect(short('(free) Claude Opus 5.5'), 'Opus 5.5');
    // A separator it leaves behind goes too.
    expect(short('Big Pickle - Free'), 'Big Pickle');
    expect(short('qwen/qwen3:free'), 'qwen/qwen3');
    expect(short('Model - (latest)'), 'Model');
    for (final name in [
      'Freezer 2',
      'Carefree 1',
      'Opus 5.5',
      'Model (Free Preview)',
      'fledge-alpha-free',
      'gpt-free-eval',
    ]) {
      expect(modelChipLabel(name).free, isFalse, reason: name);
      expect(short(name), name);
    }
  });

  test('a name the rules would empty stays whole, with no icon', () {
    final label = modelChipLabel('Free');
    expect(label.text, 'Free');
    expect(label.free, isFalse);
    expect(short('(latest)'), '(latest)');
  });

  test('a default named with its variant keeps the variant as it is', () {
    expect(defaultModelChipLabel('Claude Opus 5.5#high').text, 'Opus 5.5#high');
    expect(
      defaultModelChipLabel('Kimi K3.1 Pro Highspeed#max').text,
      'K3.1 Pro HS#max',
    );
    // Only the last # separates the variant.
    expect(
      defaultModelChipLabel('Claude Opus 5.5 #2#low').text,
      'Opus 5.5 #2#low',
    );
    expect(defaultModelChipLabel('Claude Opus 5.5').text, 'Opus 5.5');
    // A # that is part of the name is not a variant.
    expect(defaultModelChipLabel('Model #2').text, 'Model #2');
    expect(defaultModelChipLabel('DeepSeek V4 #2 Free').text, 'DS V4 #2');
    expect(defaultModelChipLabel('DeepSeek V4 #2 Free').free, isTrue);
    expect(defaultModelChipLabel('Model#').text, 'Model#');
    expect(defaultModelChipLabel('DeepSeek V4 Free#high').free, isTrue);
  });
}
