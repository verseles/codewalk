/// The readable text of an OpenCode synthetic or system message (#491).
///
/// OpenCode wraps the reminders it injects, such as the Plan mode notes
/// added when the agent switches, in a `<system-reminder>` envelope meant for
/// the model. A text wholly inside one envelope is shown without it; any
/// other text is kept as written, and user text never passes through here.
String openCodeNoticeText(String text) {
  final inner = _envelope.firstMatch(text)?.group(1);
  return inner == null ? text : inner.trim();
}

// The body may hold no other envelope tag, so two envelopes side by side are
// left as written, and matching stays linear.
final _envelope = RegExp(
  r'^\s*<system-reminder>((?:(?!</?system-reminder>)[\s\S])*)</system-reminder>\s*$',
);
