/// Lower scores rank first. Unlike substring search, ordered characters may
/// have gaps, so e.g. `cwk` matches `codewalk`.
int? projectDirectoryMatchScore(String text, String query) {
  final haystack = text.toLowerCase();
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return 0;
  if (haystack == needle) return 0;
  if (haystack.startsWith(needle)) return 10 + haystack.length - needle.length;
  final substring = haystack.indexOf(needle);
  if (substring >= 0) return 100 + substring;
  var cursor = 0;
  var score = 1000;
  for (final character in needle.runes) {
    final index = haystack.indexOf(String.fromCharCode(character), cursor);
    if (index < 0) return null;
    score += (index - cursor) * 4;
    if (index == 0 || '/\\_- .'.contains(haystack[index - 1])) score -= 2;
    cursor = index + 1;
  }
  return score;
}
