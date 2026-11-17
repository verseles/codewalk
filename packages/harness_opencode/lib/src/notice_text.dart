import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'subagent_child.dart';

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

/// Only synthetic messages carrying report metadata may become child replies.
/// The body can itself contain markup or other agent reports.
Notice openCodeSyntheticNotice(
  ItemMeta meta,
  SessionRef parent,
  String text,
  Map<String, Object?> payload,
) {
  final metadata = payload['metadata'];
  if (metadata is! Map<String, Object?> || metadata['source'] != 'subagent') {
    return Notice(
      meta: meta,
      kind: const OpenValue.known(NoticeKind.continuation),
      text: openCodeNoticeText(text),
    );
  }
  final child = openCodeSubagentChild({
    'sessionID': metadata['childID'],
  }, parent).child;
  // The producer interpolates the description verbatim, including quotes
  // and newlines. Match that boundary without trimming Markdown indentation.
  final description = payload['description'];
  const closing = '\n</subagent>';
  final header = _reportHeader.matchAsPrefix(text);
  var body = text;
  if (header != null && text.endsWith(closing)) {
    final end = description is String
        ? header.end + description.length
        : text.indexOf('">\n', header.end);
    if (end >= header.end &&
        end + 3 <= text.length - closing.length &&
        text.startsWith('">\n', end) &&
        (description is! String || text.startsWith(description, header.end))) {
      body = text.substring(end + 3, text.length - closing.length);
    }
  }
  String? label(Object? raw) =>
      raw is String &&
          raw.length <= 256 &&
          utf8.encode(raw).length <= 256 &&
          raw.trim().isNotEmpty
      ? raw.trim()
      : null;
  return Notice(
    meta: meta,
    kind: const OpenValue.known(NoticeKind.continuation),
    relatedSession: child,
    report: SubagentReport(
      agent: label(metadata['agent']),
      description: label(payload['description']),
      outcome: switch (metadata['state']) {
        'completed' => OutcomeKind.succeeded,
        'error' => OutcomeKind.failed,
        'cancelled' => OutcomeKind.interrupted,
        _ => null,
      },
    ),
    text: body,
  );
}

final _reportHeader = RegExp(
  r'^<subagent sessionID="[^"\r\n]+" state="[^"\r\n]+" description="',
);
