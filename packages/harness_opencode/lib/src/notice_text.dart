import 'package:codewalk_core/codewalk_core.dart';

import 'display_label.dart';
import 'shell_observation.dart';
import 'shell_projection.dart';
import 'subagent_child.dart';

/// The readable text of an OpenCode synthetic or system message (#491).
///
/// OpenCode wraps the reminders it injects — such as Plan mode notes
/// (`<system-reminder>` / `<system-update>`) and fork notices (`<fork-notice>`)
/// — in a single XML-like envelope meant for the model. A text wholly inside
/// one envelope is shown without it; any other text is kept as written, and
/// user text never passes through here.
String openCodeNoticeText(String text) {
  for (final pattern in _envelopes) {
    final inner = pattern.firstMatch(text)?.group(1);
    if (inner != null) return inner.trim();
  }
  return text;
}

// Each body may hold no other tag of the same kind, so two envelopes side by
// side are left as written, and matching stays linear.
final _envelopes = [
  RegExp(
    r'^\s*<system-reminder>((?:(?!</?system-reminder>)[\s\S])*)</system-reminder>\s*$',
  ),
  RegExp(
    r'^\s*<system-update>((?:(?!</?system-update>)[\s\S])*)</system-update>\s*$',
  ),
  RegExp(
    r'^\s*<fork-notice>((?:(?!</?fork-notice>)[\s\S])*)</fork-notice>\s*$',
  ),
];

/// Projects one OpenCode synthetic message into a canonical [Notice].
///
/// Recognizes delegated subagent completions (`source == 'subagent'`, both
/// `<subagent ...>` and `<background-result kind="subagent" ...>`), background
/// shell results (`source == 'shell'`, both `<shell ...>` and
/// `<background-result kind="shell" ...>`, including user-shell echoes), and
/// other `<background-result ...>` envelopes (`codemode`, image/video jobs).
Notice openCodeSyntheticNotice(
  ItemMeta meta,
  SessionRef parent,
  String text,
  Map<String, Object?> payload, {
  String? Function(Object?) readLabel = openCodeDisplayLabel,
}) {
  final metadata = payload['metadata'];
  final metaMap = metadata is Map<String, Object?> ? metadata : null;
  final source = metaMap?['source'];

  if (source == 'subagent') {
    return _subagentNotice(
      meta,
      parent,
      text,
      payload,
      metaMap!,
      readLabel: readLabel,
    );
  }
  if (source == 'shell') {
    return _shellNotice(
      meta,
      text,
      payload,
      metaMap!,
      readLabel: readLabel,
    );
  }
  if (source == null) {
    final fallbackShell = _tryUnmarkedShellNotice(
      meta,
      text,
      payload,
      readLabel: readLabel,
    );
    if (fallbackShell != null) return fallbackShell;
  }
  if (source == 'codemode' ||
      source == 'experimental_image_generate' ||
      source == 'video_generate' ||
      source == 'experimental_video_generate') {
    final unwrapped = _unwrapBackgroundResult(text);
    if (unwrapped != null) {
      final clean = openCodeRedactedText(
        unwrapped,
        openCodeShellOutputLimit,
      ).text;
      return Notice(
        meta: meta,
        kind: const OpenValue.known(NoticeKind.continuation),
        text: clean,
      );
    }
  }
  return Notice(
    meta: meta,
    kind: const OpenValue.known(NoticeKind.continuation),
    text: openCodeNoticeText(text),
  );
}

Notice _subagentNotice(
  ItemMeta meta,
  SessionRef parent,
  String text,
  Map<String, Object?> payload,
  Map<String, Object?> metadata, {
  required String? Function(Object?) readLabel,
}) {
  final child = openCodeSubagentChild({
    'sessionID': metadata['childID'],
  }, parent).child;
  // The producer interpolates the description verbatim, including quotes
  // and newlines. Match that boundary without trimming Markdown indentation.
  final description = payload['description'];
  final body = _unwrapTagged(
        text,
        _subagentHeader,
        '\n</subagent>',
        verbatimTrailingAttr: description is String ? description : null,
      ) ??
      _unwrapTagged(
        text,
        _backgroundSubagentHeader,
        '\n</background-result>',
        verbatimTrailingAttr: description is String ? description : null,
      ) ??
      text;
  String? label(Object? raw) {
    final value = readLabel(raw)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

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

Notice _shellNotice(
  ItemMeta meta,
  String text,
  Map<String, Object?> payload,
  Map<String, Object?> metadata, {
  required String? Function(Object?) readLabel,
}) {
  final rawText = _stripUserShellPrefix(text);
  final description = payload['description'];
  final extracted =
      _extractShellEnvelope(
        rawText,
        _shellHeader,
        '\n</shell>',
        expectedCommand: description is String ? description : null,
      ) ??
      _extractShellEnvelope(
        rawText,
        _backgroundShellHeader,
        '\n</background-result>',
        expectedCommand: description is String ? description : null,
      );

  final rawCommand = _firstNonEmpty([
    readLabel(description),
    extracted?.command,
  ]);
  final command = rawCommand == null
      ? null
      : redactCredentialText(rawCommand).trim();
  final shellId = _safeShellId(metadata['shellID']) ??
      _safeShellId(extracted?.id);

  int? exitCode;
  String? exitToken;
  final rawExit = metadata['exit'] ?? metadata['exitCode'] ?? extracted?.exit;
  if (rawExit != null) {
    try {
      final parsed = openCodeShellExit(rawExit);
      exitCode = parsed.code;
      exitToken = parsed.token;
    } on FormatException {
      // Ignore malformed optional metadata rather than breaking the notice.
    }
  }
  final timedOut = metadata['timeout'] == true || (extracted?.timedOut ?? false);
  final killed = metadata['killed'] == true || (extracted?.killed ?? false);
  final truncated =
      metadata['truncated'] == true || (extracted?.truncated ?? false);
  final hasSignal =
      (metadata['signal'] is String &&
          (metadata['signal']! as String).isNotEmpty) ||
      (extracted?.hasSignal ?? false);

  final rawState = metadata['state'] is String
      ? metadata['state']! as String
      : extracted?.state;
  final outcome = _shellOutcome(
    rawState,
    exitCode: exitCode,
    timedOut: timedOut,
    killed: killed,
    hasSignal: hasSignal,
  );

  final cleanBody = _cleanShellBody(extracted?.body ?? rawText);
  return Notice(
    meta: meta,
    kind: const OpenValue.known(NoticeKind.continuation),
    shellReport: ShellReport(
      command: command == null || command.isEmpty ? null : command,
      outcome: outcome,
      exitCode: exitCode,
      exitToken: exitToken,
      timedOut: timedOut,
      killed: killed,
      truncated: truncated,
      shellId: shellId,
    ),
    text: cleanBody,
  );
}

/// Handles legacy/untagged synthetic shell notifications that carry OpenCode's
/// exact `<shell id="sh_..." state="...">...</shell>` or
/// `<background-result kind="shell" ...>...</background-result>` envelope
/// without a `metadata.source` field.
Notice? _tryUnmarkedShellNotice(
  ItemMeta meta,
  String text,
  Map<String, Object?> payload, {
  required String? Function(Object?) readLabel,
}) {
  final rawText = _stripUserShellPrefix(text);
  final description = payload['description'];
  final extracted =
      _extractShellEnvelope(
        rawText,
        _shellHeader,
        '\n</shell>',
        expectedCommand: description is String ? description : null,
      ) ??
      _extractShellEnvelope(
        rawText,
        _backgroundShellHeader,
        '\n</background-result>',
        expectedCommand: description is String ? description : null,
      );
  if (extracted == null) return null;
  final id = _safeShellId(extracted.id);
  if (id == null || !id.startsWith('sh_')) return null;
  final state = extracted.state;
  if (state != 'completed' && state != 'error' && state != 'cancelled') {
    return null;
  }
  final rawCommand = _firstNonEmpty([
    readLabel(description),
    extracted.command,
  ]);
  final command = rawCommand == null
      ? null
      : redactCredentialText(rawCommand).trim();
  int? exitCode;
  String? exitToken;
  if (extracted.exit != null) {
    try {
      final parsed = openCodeShellExit(extracted.exit);
      exitCode = parsed.code;
      exitToken = parsed.token;
    } on FormatException {
      // Ignore malformed optional attribute.
    }
  }
  return Notice(
    meta: meta,
    kind: const OpenValue.known(NoticeKind.continuation),
    shellReport: ShellReport(
      command: command == null || command.isEmpty ? null : command,
      outcome: _shellOutcome(
        state,
        exitCode: exitCode,
        timedOut: extracted.timedOut,
        killed: extracted.killed,
        hasSignal: extracted.hasSignal,
      ),
      exitCode: exitCode,
      exitToken: exitToken,
      timedOut: extracted.timedOut,
      killed: extracted.killed,
      truncated: extracted.truncated,
      shellId: id,
    ),
    text: _cleanShellBody(extracted.body),
  );
}

OutcomeKind? _shellOutcome(
  String? state, {
  required int? exitCode,
  required bool timedOut,
  required bool killed,
  required bool hasSignal,
}) => switch (state) {
  'cancelled' => OutcomeKind.interrupted,
  'error' => OutcomeKind.failed,
  'completed' =>
    timedOut || (exitCode != null && exitCode != 0)
        ? OutcomeKind.failed
        : (killed || (hasSignal && exitCode == null))
        ? OutcomeKind.interrupted
        : OutcomeKind.succeeded,
  _ => null,
};

String _cleanShellBody(String rawBody) {
  final sanitized = openCodeSanitizeShellToolOutputText(rawBody);
  final clean = openCodeRedactedText(sanitized, openCodeShellOutputLimit).text;
  if (clean.trim() == '(no output)') return '';
  return clean;
}

String _stripUserShellPrefix(String text) {
  const prefix = 'The following shell command was executed by the user:\n';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

String? _safeShellId(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final checked = openCodeCheckedShellText(raw, 4096, nonempty: true);
    for (var i = 0; i < checked.length; i++) {
      final unit = checked.codeUnitAt(i);
      if (unit < 0x20 || unit == 0x2f || unit == 0x5c || unit == 0x7f) {
        return null;
      }
    }
    return checked;
  } on Object {
    return null;
  }
}

String? _firstNonEmpty(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String? _unwrapTagged(
  String text,
  RegExp headerPattern,
  String closing, {
  String? verbatimTrailingAttr,
}) {
  final header = headerPattern.matchAsPrefix(text);
  if (header == null || !text.endsWith(closing)) return null;
  final end = verbatimTrailingAttr != null
      ? header.end + verbatimTrailingAttr.length
      : text.indexOf('">\n', header.end);
  if (end < header.end ||
      end + 3 > text.length - closing.length ||
      !text.startsWith('">\n', end)) {
    return null;
  }
  if (verbatimTrailingAttr != null &&
      !text.startsWith(verbatimTrailingAttr, header.end)) {
    // Fall back to delimiter search if description differs from the attribute.
    final fallbackEnd = text.indexOf('">\n', header.end);
    if (fallbackEnd < header.end ||
        fallbackEnd + 3 > text.length - closing.length) {
      return null;
    }
    return text.substring(fallbackEnd + 3, text.length - closing.length);
  }
  return text.substring(end + 3, text.length - closing.length);
}

({
  String id,
  String state,
  String? command,
  Object? exit,
  bool timedOut,
  bool killed,
  bool truncated,
  bool hasSignal,
  String body,
})?
_extractShellEnvelope(
  String text,
  RegExp headerPattern,
  String closing, {
  String? expectedCommand,
}) {
  final header = headerPattern.matchAsPrefix(text);
  if (header == null || !text.endsWith(closing)) return null;
  final id = header.group(1)!;
  final state = header.group(2)!;
  final restStart = header.end;
  final bodyEnd = text.length - closing.length;
  final tagEnd = text.indexOf('>\n', restStart);
  if (tagEnd < restStart || tagEnd + 2 > bodyEnd) return null;

  // Locate optional ` command="..."` attribute, whose value may contain
  // verbatim quotes or newlines; any attributes before it are single-line.
  const cmdPrefix = ' command="';
  final cmdIdx = text.indexOf(cmdPrefix, restStart);
  final hasCommand = cmdIdx >= restStart && cmdIdx < tagEnd;
  final String extraAttrs;
  final String? command;
  final int bodyStart;
  if (!hasCommand) {
    extraAttrs = text.substring(restStart, tagEnd);
    // Reject stray newlines in non-command attributes.
    if (extraAttrs.contains('\n') || extraAttrs.contains('\r')) return null;
    command = null;
    bodyStart = tagEnd + 2;
  } else {
    extraAttrs = text.substring(restStart, cmdIdx);
    if (extraAttrs.contains('\n') || extraAttrs.contains('\r')) return null;
    final cmdStart = cmdIdx + cmdPrefix.length;
    if (expectedCommand != null &&
        cmdStart + expectedCommand.length + 3 <= bodyEnd &&
        text.startsWith(expectedCommand, cmdStart) &&
        text.startsWith('">\n', cmdStart + expectedCommand.length)) {
      command = expectedCommand;
      bodyStart = cmdStart + expectedCommand.length + 3;
    } else {
      final end = text.indexOf('">\n', cmdStart);
      if (end < cmdStart || end + 3 > bodyEnd) return null;
      command = text.substring(cmdStart, end);
      bodyStart = end + 3;
    }
  }

  Object? exit;
  final exitMatch = _attrExit.firstMatch(extraAttrs);
  if (exitMatch != null) {
    final raw = exitMatch.group(1)!;
    exit = int.tryParse(raw) ?? raw;
  }
  return (
    id: id,
    state: state,
    command: command,
    exit: exit,
    timedOut: _attrTimedOut.hasMatch(extraAttrs),
    killed: _attrKilled.hasMatch(extraAttrs),
    truncated: _attrTruncated.hasMatch(extraAttrs),
    hasSignal: _attrSignal.hasMatch(extraAttrs),
    body: text.substring(bodyStart, bodyEnd),
  );
}

final _attrExit = RegExp(r'\b(?:exit|exitCode)="([^"\r\n]+)"');
final _attrTimedOut = RegExp(r'\btimeout="true"');
final _attrKilled = RegExp(r'\bkilled="true"');
final _attrTruncated = RegExp(r'\btruncated="true"');
final _attrSignal = RegExp(r'\bsignal="[^"\r\n]+"');

String? _unwrapBackgroundResult(String text) {
  const closing = '\n</background-result>';
  final match = _genericBackgroundResultHeader.matchAsPrefix(text);
  if (match == null || !text.endsWith(closing)) return null;
  if (match.end > text.length - closing.length) return null;
  return text.substring(match.end, text.length - closing.length);
}

final _subagentHeader = RegExp(
  r'^<subagent sessionID="[^"\r\n]+" state="[^"\r\n]+" description="',
);

final _backgroundSubagentHeader = RegExp(
  r'^<background-result kind="subagent" sessionID="[^"\r\n]+" state="[^"\r\n]+" description="',
);

final _shellHeader = RegExp(
  r'^<shell id="([^"\r\n]+)" state="([^"\r\n]+)"',
);

final _backgroundShellHeader = RegExp(
  r'^<background-result kind="shell" id="([^"\r\n]+)" state="([^"\r\n]+)"',
);

final _genericBackgroundResultHeader = RegExp(
  r'^<background-result kind="[^"\r\n]+"[^\r\n]*>\n',
);
