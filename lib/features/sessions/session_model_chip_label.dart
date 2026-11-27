/// The composer chip's short model name (#524): long catalog names lose the
/// parts that add little in its small room. Only the chip shortens; its
/// tooltip, the screen reader, the search and the pick keep the full name.
///
/// The table is meant to be reviewed as model names change: each rule runs
/// once, in order, on the result of the one before; the Free word (16) is
/// read before them all.
final class ModelChipLabel {
  const ModelChipLabel(this.text, {this.free = false});

  final String text;

  /// The name said the model is free; the chip shows an icon instead.
  final bool free;
}

/// The owner's table (#524). A rule that removes a part replaces it with
/// nothing; `$1` and `$2` are the rule's groups.
final _rules = <(RegExp, String)>[
  // 1. Claude's family names the model: "Claude Opus 5.5" → "Opus 5.5".
  (RegExp('^Claude (Opus|Sonnet|Haiku|Fable) '), r'$1 '),
  // 2. GPT's codenames: "GPT-6.2 Sol" → "6.2 Sol".
  (RegExp(r'^GPT-([\d.]+) (Sol|Luna|Terra|Astra)'), r'$1 $2'),
  // 3. "Gemini 3.5 Flash Lite" → "Gemini 3.5 Lite".
  (RegExp(r'^Gemini (\S+) Flash[- ]Lite'), r'Gemini $1 Lite'),
  // 4. "Muse Spark 1.3 Contributor" → "Spark 1.3".
  (RegExp(r'^Muse Spark (\S+)( Contributor)?$'), r'Spark $1'),
  // 5. "(latest)" adds nothing to the chip.
  (RegExp(r'\s*\(latest\)$'), ''),
  // 6. Active parameters go; the total stays: "550B A55B" → "550B".
  (RegExp(r'[- ]A\d+B\b'), ''),
  // 7. Removed: snapshot dates stay, they change how a model behaves.
  // 8. Antigravity's ids: "antigravity-gemini-4-neon-high" → "AGY …".
  (RegExp('^antigravity-'), 'AGY '),
  // 9. "MiniMax-M3.1-Flash" → "M3.1 Flash", "MiniMax-M3" → "M3".
  (RegExp(r'^MiniMax[- ](M[\d.]+)[- ]?(.*)$'), r'$1 $2'),
  // 10. "Kimi K3.1 Pro" → "K3.1 Pro".
  (RegExp(r'^Kimi (K[\d.]+)'), r'$1'),
  // 11. "… Highspeed" → "… HS".
  (RegExp(r'\s+Highspeed$'), ' HS'),
  // 12. Gemini's codenames: "Gemini 4 Neon" → "4 Neon".
  (RegExp(r'^Gemini ([\d.]+) (Neon|Argon|Carbon|Hydrogen)'), r'$1 $2'),
  // 13. "DeepSeek V4 Pro" → "DS V4 Pro".
  (RegExp('^DeepSeek '), 'DS '),
  // 14. "Nemotron 3 Ultra" → "Nemo 3 Ultra".
  (RegExp('^Nemotron '), 'Nemo '),
  // 15. Instruct and IT both mean instruction-tuned.
  (RegExp(r'\bInstruct\b'), 'IT'),
];

/// 16. "Free" or "(free)" leaves the text and becomes the chip's icon. It is
/// read first, so the other rules still see the name's start and end, and
/// only as a word of its own: not "Freezer", not "(Free Preview)", not a
/// hyphenated id such as "fledge-alpha-free".
final _free = RegExp(r'\s*\(\s*[Ff]ree\s*\)|(?<![\w(-])[Ff]ree(?![\w)-])');

final _group = RegExp(r'\$(\d)');
final _spaces = RegExp(r'\s{2,}');

/// What a removed part can leave at an edge: "Big Pickle - Free" →
/// "Big Pickle".
final _edges = RegExp(r'^[\s\-–—·|/:,]+|[\s\-–—·|/:,]+$');

/// [name] as the chip shows it; the original when the rules would leave
/// nothing.
ModelChipLabel modelChipLabel(String name) {
  var text = name;
  final free = _free.hasMatch(text);
  text = text.replaceAll(_free, '').replaceAll(_edges, '');
  for (final (pattern, replacement) in _rules) {
    text = text.replaceFirstMapped(
      pattern,
      (match) => replacement.replaceAllMapped(
        _group,
        (group) => match.group(int.parse(group.group(1)!)) ?? '',
      ),
    );
  }
  text = text.replaceAll(_spaces, ' ').replaceAll(_edges, '');
  return text.isEmpty ? ModelChipLabel(name) : ModelChipLabel(text, free: free);
}

/// A `name#variant` the server names a default by: only the name before the
/// last `#` is shortened, the variant is kept as it is. A variant id is one
/// word, so a `#` followed by spaces (or by nothing) belongs to the name.
ModelChipLabel defaultModelChipLabel(String value) {
  final hash = value.lastIndexOf('#');
  final variant = hash < 0 ? '' : value.substring(hash + 1);
  if (hash <= 0 || variant.isEmpty || variant.contains(RegExp(r'\s'))) {
    return modelChipLabel(value);
  }
  final name = value.substring(0, hash);
  if (name.trimRight() != name) return modelChipLabel(value);
  final head = modelChipLabel(name);
  return ModelChipLabel(
    '${head.text}${value.substring(hash)}',
    free: head.free,
  );
}
