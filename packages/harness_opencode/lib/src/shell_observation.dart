import 'package:codewalk_core/codewalk_core.dart';

import 'session_projection.dart';
import 'shell_projection.dart';
import 'version_policy.dart';

const _idByteLimit = 4096;
const _commandByteLimit = 64 * 1024;
const _signalByteLimit = 128;
const _maxEpochMs = 8640000000000000;

const _shellEventTypes = {'shell.created', 'shell.exited', 'shell.deleted'};

final _backgroundCaptureNotice = RegExp(
  r'(Command moved to the background \(shell ID: sh_[^)\r\n]+\)\.)(?:\r?\nPID: \d+)?\r?\nOutput is streaming to:[^\r\n]*',
);

final _interruptedCaptureNotice = RegExp(
  r'\[(?:no output; output file:|full output saved to) [^\r\n\]]+\]\r?\n\r?\n(Command interrupted by the user \(shell ID: sh_[^)\r\n]+\)[^\r\n]*)',
);

final _standaloneCaptureNotice = RegExp(
  r'(?:^|\r?\n)\[(?:no output; output file:|full output saved to) [^\r\n\]]+\](?=$|\r?\n)',
);

/// Strips OpenCode's host-private capture-file path lines (and background PID)
/// when paired with OpenCode's generated shell notices, so host-private paths
/// and PIDs never reach canonical timeline items or detail dialogs while
/// ordinary user shell output is left intact.
String openCodeSanitizeShellToolOutputText(String text) {
  var result = _backgroundCaptureNotice.hasMatch(text)
      ? text.replaceAllMapped(_backgroundCaptureNotice, (m) => m[1]!)
      : text;
  if (_interruptedCaptureNotice.hasMatch(result)) {
    result = result.replaceAllMapped(_interruptedCaptureNotice, (m) => m[1]!);
  }
  if (_standaloneCaptureNotice.hasMatch(result)) {
    result = result.replaceAll(_standaloneCaptureNotice, '');
    if (result.startsWith('\r\n')) {
      result = result.substring(2);
    } else if (result.startsWith('\n')) {
      result = result.substring(1);
    }
  }
  return result;
}

/// Whether [type] is one of the OpenCode v2 ephemeral shell lifecycle events.
bool isOpenCodeShellLifecycleEvent(Object? type) =>
    type is String && _shellEventTypes.contains(type);

/// Validates an OpenCode `Shell.ID` (`sh_...`): starts with `sh_`, non-empty
/// suffix, valid UTF-16 surrogates, within 4 KiB UTF-8, and free of path
/// separators or control characters.
String openCodeShellId(Object? value) {
  final text = openCodeCheckedShellText(value, _idByteLimit, nonempty: true);
  if (!text.startsWith('sh_') || text.length <= 3) {
    throw const FormatException('Malformed OpenCode shell ID.');
  }
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0x20 || unit == 0x2f || unit == 0x5c || unit == 0x7f) {
      throw const FormatException('Unsafe characters in OpenCode shell ID.');
    }
  }
  return text;
}

/// Validates UTF-16 surrogate pairing and enforces a UTF-8 byte cap [byteCap],
/// throwing [FormatException] for malformed values or unpaired surrogates and
/// [RangeError] if [byteCap] is exceeded.
String openCodeCheckedShellText(
  Object? value,
  int byteCap, {
  bool nonempty = false,
}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    throw const FormatException('Malformed shell string.');
  }
  if (value.length > byteCap) {
    throw RangeError('Shell string exceeds limit.');
  }
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) {
        throw const FormatException('Unpaired high surrogate in shell text.');
      }
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        throw const FormatException('Invalid surrogate pair in shell text.');
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('Unpaired low surrogate in shell text.');
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > byteCap) throw RangeError('Shell string exceeds UTF-8 limit.');
  }
  return value;
}

/// Extracts an optional validated `location.directory` string from an SSE shell
/// frame envelope for adapter-private per-shell location routing.
String? openCodeShellFrameDirectory(Object? frame) {
  if (frame is! Map<String, Object?>) return null;
  final location = frame['location'];
  if (location is! Map<String, Object?>) return null;
  final directory = location['directory'];
  if (directory is! String || directory.isEmpty) return null;
  try {
    return openCodeCheckedShellText(directory, _idByteLimit, nonempty: true);
  } on Object {
    return null;
  }
}

/// Extracts a valid `metadata.sessionID` string from a raw `Shell.Info` object,
/// or returns `null` if absent or not a valid session ID. Never reads `file`,
/// `cwd`, `pid`, or `shell`.
String? openCodeShellInfoSessionId(Object? rawInfo) {
  if (rawInfo is! Map<String, Object?>) return null;
  final metadata = rawInfo['metadata'];
  if (metadata is! Map<String, Object?>) return null;
  final sessionId = metadata['sessionID'];
  if (sessionId is! String || sessionId.isEmpty) return null;
  try {
    return openCodeSessionId(sessionId);
  } on FormatException {
    return null;
  }
}

/// Maps one verified OpenCode `Shell.Info` object to canonical [ShellWork] for
/// [session], returning `null` if `metadata.sessionID` does not strictly match
/// [session.nativeId].
///
/// Host-private fields (`file`, `cwd`, `pid`, `shell`) are never read or
/// copied. Command text is surrogate-validated, redacted, and UTF-8 bounded
/// up to 64 KiB before construction.
ShellWork? openCodeShellInfoToWork(
  Object? rawInfo, {
  required SessionRef session,
  required String sourceVersion,
  String nativeType = 'shell.list',
  String? nativeEventId,
}) {
  if (rawInfo is! Map<String, Object?>) {
    throw const FormatException('Malformed Shell.Info object.');
  }
  final id = openCodeShellId(rawInfo['id']);
  final metadata = rawInfo['metadata'];
  if (metadata is! Map<String, Object?>) {
    throw const FormatException('Malformed Shell.Info metadata.');
  }
  final rawSessionId = metadata['sessionID'];
  if (rawSessionId is! String || rawSessionId != session.nativeId) {
    return null;
  }

  final rawStatus = openCodeCheckedShellText(
    rawInfo['status'],
    _signalByteLimit,
    nonempty: true,
  );
  final OpenValue<ShellStatus> status = switch (openCodeShellStatus(
    rawStatus,
  )) {
    final known? => OpenValue<ShellStatus>.known(known),
    null => OpenValue<ShellStatus>.unknown(rawStatus),
  };

  final rawCommand = openCodeCheckedShellText(
    rawInfo['command'],
    _commandByteLimit,
  );
  final command = openCodeRedactedText(rawCommand, _commandByteLimit).text;

  int? exitCode;
  String? exitToken;
  if (rawInfo.containsKey('exit') && rawInfo['exit'] != null) {
    final exit = openCodeShellExit(rawInfo['exit']);
    exitCode = exit.code;
    exitToken = exit.token;
  }

  String? signal;
  if (rawInfo.containsKey('signal') && rawInfo['signal'] != null) {
    signal = openCodeCheckedShellText(
      rawInfo['signal'],
      _signalByteLimit,
      nonempty: true,
    );
  }

  final rawTime = rawInfo['time'];
  if (rawTime is! Map<String, Object?>) {
    throw const FormatException('Malformed Shell.Info time.');
  }
  final startedAt = _timestamp(rawTime['started']);
  DateTime? completedAt;
  if (rawTime.containsKey('completed') && rawTime['completed'] != null) {
    completedAt = _timestamp(rawTime['completed']);
    if (startedAt != null &&
        completedAt != null &&
        completedAt.isBefore(startedAt)) {
      completedAt = startedAt;
    }
  }

  return ShellWork(
    id: id,
    owner: SessionOwner(session),
    command: command,
    status: status,
    startedAt: startedAt,
    completedAt: completedAt,
    exitCode: exitCode,
    exitToken: exitToken,
    signal: signal,
    source: SourceProvenance(
      harness: session.harnessRef,
      version: sourceVersion,
      nativeType: nativeType,
      nativeEventId: nativeEventId,
      durability: const OpenValue.known(Durability.ephemeral),
    ),
  );
}

/// Projects OpenCode ephemeral shell SSE frames (`shell.created`,
/// `shell.exited`, `shell.deleted`) into a full-session [ShellChanged] level
/// set for [current], completely isolated from `WorkChanged`.
///
/// Returns `null` for unrelated frame types, foreign/untagged `shell.created`
/// frames, or `shell.exited`/`shell.deleted` frames whose ID is not currently
/// tracked on [current].
ShellChanged? projectOpenCodeShellLifecycleEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Malformed shell lifecycle frame.');
  }
  final type = value['type'];
  if (!isOpenCodeShellLifecycleEvent(type)) return null;
  if (!OpenCodeCompatibility.supportsV2(sourceVersion)) {
    throw const FormatException('Unsupported OpenCode version for shell.');
  }
  final eventType = type! as String;
  final data = value['data'];
  if (data is! Map<String, Object?>) {
    throw const FormatException('Malformed shell lifecycle data.');
  }
  final rawEventId = value['id'];
  final nativeEventId = rawEventId is String && rawEventId.startsWith('evt_')
      ? openCodeCheckedShellText(rawEventId, _idByteLimit, nonempty: true)
      : null;

  final meta = EventMeta(
    owner: SessionOwner(current.ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: current.ref.harnessRef,
      version: sourceVersion,
      nativeType: eventType,
      nativeEventId: nativeEventId,
      durability: const OpenValue.known(Durability.ephemeral),
    ),
  );

  switch (eventType) {
    case 'shell.created':
      final work = openCodeShellInfoToWork(
        data['info'],
        session: current.ref,
        sourceVersion: sourceVersion,
        nativeType: eventType,
        nativeEventId: nativeEventId,
      );
      if (work == null) return null;
      final next = [
        for (final existing in current.shells)
          if (existing.id != work.id) existing,
        work,
      ];
      return ShellChanged(meta: meta, items: next);

    case 'shell.exited':
      final id = openCodeShellId(data['id']);
      final index = current.shells.indexWhere((shell) => shell.id == id);
      if (index < 0) return null;
      final prior = current.shells[index];
      final rawStatus = openCodeCheckedShellText(
        data['status'],
        _signalByteLimit,
        nonempty: true,
      );
      final OpenValue<ShellStatus> status = switch (openCodeShellStatus(
        rawStatus,
      )) {
        final known? => OpenValue<ShellStatus>.known(known),
        null => OpenValue<ShellStatus>.unknown(rawStatus),
      };
      var exitCode = prior.exitCode;
      var exitToken = prior.exitToken;
      if (data.containsKey('exit') && data['exit'] != null) {
        final exit = openCodeShellExit(data['exit']);
        exitCode = exit.code;
        exitToken = exit.token;
      }
      final rawCreated = value['created'];
      DateTime? completedAt = rawCreated is num
          ? _timestamp(rawCreated)
          : receivedAt.toUtc();
      if (prior.startedAt != null &&
          completedAt != null &&
          completedAt.isBefore(prior.startedAt!)) {
        completedAt = prior.startedAt;
      }
      final updated = ShellWork(
        id: prior.id,
        owner: prior.owner,
        command: prior.command,
        status: status,
        startedAt: prior.startedAt,
        completedAt: completedAt,
        exitCode: exitCode,
        exitToken: exitToken,
        signal: prior.signal,
        source: meta.source,
      );
      final next = List<ShellWork>.of(current.shells);
      next[index] = updated;
      return ShellChanged(meta: meta, items: next);

    case 'shell.deleted':
      final id = openCodeShellId(data['id']);
      if (!current.shells.any((shell) => shell.id == id)) return null;
      final next = [
        for (final existing in current.shells)
          if (existing.id != id) existing,
      ];
      return ShellChanged(meta: meta, items: next);

    default:
      return null;
  }
}

/// OpenCode v2 canonical capabilities for shell observation and stopping,
/// verified only for supported OpenCode v2 server versions.
Map<String, Capability> openCodeShellCapabilities(String connectedVersion) {
  final verified = OpenCodeCompatibility.supportsV2(connectedVersion);
  return {
    ShellCapabilities.observe: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
    ),
    ShellCapabilities.stop: Capability(
      support: const OpenValue.known(Support.native),
      verified: verified,
      reason: verified ? null : 'unverifiedVersion',
    ),
  };
}

DateTime? _timestamp(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Malformed shell timestamp.');
  }
  if (value < 0 || value > _maxEpochMs) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.floor(), isUtc: true);
}
