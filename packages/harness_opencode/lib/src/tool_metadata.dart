import 'package:codewalk_core/codewalk_core.dart';

import 'shell_projection.dart';
import 'subagent_child.dart';

const _metaLimit = 4096;

/// Validates UTF-16 surrogate pairing and enforces a UTF-8 byte cap [cap],
/// throwing [FormatException] on invalid surrogates and [RangeError] if [cap]
/// is exceeded.
String _checkedMetaText(String value, int cap) {
  if (value.length > cap) throw RangeError('Metadata text exceeds limit.');
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const FormatException('Unpaired high surrogate in metadata.');
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const FormatException('Invalid surrogate pair in metadata.');
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('Unpaired low surrogate in metadata.');
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) throw RangeError('Metadata text exceeds UTF-8 limit.');
  }
  return value;
}

/// Maps an OpenCode v2 built-in tool name to its canonical [ToolKind].
///
/// Names outside the documented OpenCode v2 built-in catalog stay
/// [ToolKind.other]; underscored names are never guessed as MCP tools.
ToolKind openCodeToolKind(String name) => switch (name) {
  'read' => ToolKind.read,
  'edit' || 'patch' || 'apply_patch' => ToolKind.edit,
  'write' => ToolKind.write,
  'grep' || 'glob' => ToolKind.search,
  'webfetch' => ToolKind.fetch,
  'websearch' => ToolKind.webSearch,
  'shell' || 'bash' => ToolKind.shell,
  'skill' => ToolKind.skill,
  'question' => ToolKind.question,
  openCodeSubagentTool || 'task' => ToolKind.subagent,
  _ => ToolKind.other,
};

/// Extracts harness-neutral [ToolRunFacts] from OpenCode shell tool metadata,
/// preserving earlier facts (such as a `shellID` observed during progress)
/// when a later event omits them.
///
/// Only `shellID`, `exit`, `status`, `timeout`, `interrupted`, and `background`
/// are inspected; host paths (`file`, `cwd`) and process IDs (`pid`) are never
/// read or copied.
///
/// Throws [FormatException] for malformed values and [RangeError] if a string
/// field exceeds the identity limit.
ToolRunFacts? openCodeShellToolRunFacts(
  Map<String, Object?> metadata, {
  ToolRunFacts? prior,
}) {
  var exitCode = prior?.exitCode;
  var exitToken = prior?.exitToken;
  var shellStatus = prior?.shellStatus;
  var timedOut = prior?.timedOut ?? false;
  var interrupted = prior?.interrupted ?? false;
  var background = prior?.background ?? false;
  var shellId = prior?.shellId;

  if (metadata.containsKey('shellID') && metadata['shellID'] != null) {
    final raw = metadata['shellID'];
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Malformed shell tool shellID.');
    }
    shellId = _checkedMetaText(raw, _metaLimit);
  }

  final rawExit = metadata['exit'] ?? metadata['exitCode'];
  if (rawExit != null) {
    final exit = openCodeShellExit(rawExit);
    exitCode = exit.code;
    exitToken = exit.token;
  }

  if (metadata.containsKey('status') && metadata['status'] != null) {
    final raw = metadata['status'];
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Malformed shell tool status.');
    }
    final checked = _checkedMetaText(raw, _metaLimit);
    shellStatus = switch (checked) {
      'completed' => const OpenValue.known(ShellStatus.exited),
      _ => switch (openCodeShellStatus(checked)) {
        final known? => OpenValue.known(known),
        null => OpenValue.unknown(checked),
      },
    };
  }

  if (metadata.containsKey('timeout') && metadata['timeout'] != null) {
    final raw = metadata['timeout'];
    if (raw is! bool) {
      throw const FormatException('Malformed shell tool timeout.');
    }
    timedOut = raw;
  }

  if (metadata.containsKey('interrupted') && metadata['interrupted'] != null) {
    final raw = metadata['interrupted'];
    if (raw is! bool) {
      throw const FormatException('Malformed shell tool interrupted.');
    }
    interrupted = raw;
  }

  if (metadata.containsKey('background') && metadata['background'] != null) {
    final raw = metadata['background'];
    if (raw is! bool) {
      throw const FormatException('Malformed shell tool background.');
    }
    background = raw;
  }

  var killed = false;
  if (metadata.containsKey('killed') && metadata['killed'] != null) {
    final raw = metadata['killed'];
    if (raw is! bool) {
      throw const FormatException('Malformed shell tool killed.');
    }
    killed = raw;
  }

  String? signal;
  if (metadata.containsKey('signal') && metadata['signal'] != null) {
    final raw = metadata['signal'];
    if (raw is! String || raw.isEmpty) {
      throw const FormatException('Malformed shell tool signal.');
    }
    signal = _checkedMetaText(raw, _metaLimit);
  }

  if (!timedOut &&
      (killed ||
          (signal != null &&
              exitCode == null &&
              (shellStatus == null ||
                  shellStatus.known == ShellStatus.exited)))) {
    shellStatus = const OpenValue.known(ShellStatus.killed);
  }

  final facts = ToolRunFacts(
    exitCode: exitCode,
    exitToken: exitToken,
    shellStatus: shellStatus,
    timedOut: timedOut,
    interrupted: interrupted,
    background: background,
    shellId: shellId,
  );
  return facts.isEmpty ? null : facts;
}
