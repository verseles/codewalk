/// An agent's configured color: OpenCode 2 keeps six-digit hex only, and its
/// v1 config migration writes `#aaaaaa` for a theme name it cannot keep, so
/// that value means no color. Anything else is no color, never a failure.
String? openCodeAgentColor(Object? value) {
  if (value is! String) return null;
  final color = value.trim().toLowerCase();
  if (!RegExp(r'^#[0-9a-f]{6}$').hasMatch(color) || color == '#aaaaaa') {
    return null;
  }
  return color;
}
