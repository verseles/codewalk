import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'item_ids.dart';
import 'version_policy.dart';

enum OpenCodeShellProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,

  /// The end of a shell command whose start is not resident; the session is
  /// re-read instead of inventing the row.
  missingStart,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeShellProjectionException implements Exception {
  const OpenCodeShellProjectionException(this.failure);

  final OpenCodeShellProjectionFailure failure;

  @override
  String toString() => 'OpenCodeShellProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _commandLimit = 64 * 1024;

/// The most captured output a shell row keeps, in UTF-8 bytes; more is
/// recorded as truncated, never fetched here.
const openCodeShellOutputLimit = 64 * 1024;
const _safeInteger = 9007199254740991;
const _maxEpochMillis = 8640000000000000;
const _started = 'session.shell.started';
const _ended = 'session.shell.ended';

/// The durable version of both shell events (`schema/session-event.ts`).
const _durableVersion = 1;

/// The item status a native shell lifecycle maps to: running is streaming,
/// an exit of zero completes, another exit, a timeout or a kill does not,
/// and an exit without a code stays unknown.
OpenValue<ItemStatus> openCodeShellItemStatus(ShellStatus status, int? exit) =>
    switch (status) {
      ShellStatus.running => const OpenValue.known(ItemStatus.streaming),
      ShellStatus.exited when exit == 0 => const OpenValue.known(
        ItemStatus.completed,
      ),
      ShellStatus.exited when exit != null => const OpenValue.known(
        ItemStatus.failed,
      ),
      ShellStatus.exited => OpenValue.unknown('shellExitUnreported'),
      ShellStatus.timeout => const OpenValue.known(ItemStatus.failed),
      ShellStatus.killed => const OpenValue.known(ItemStatus.interrupted),
    };

/// A native exit: a finite integral code, or the exact token of a non-finite
/// value. History encodes non-finite numbers as `Infinity`, `-Infinity` or
/// `NaN`; any other finite value that is not a safe integer reports neither.
({int? code, String? token}) openCodeShellExit(Object? value) {
  if (value == null) return (code: null, token: null);
  if (value is String) {
    if (const {'Infinity', '-Infinity', 'NaN'}.contains(value)) {
      return (code: null, token: value);
    }
    throw const FormatException('Malformed shell exit.');
  }
  if (value is! num) throw const FormatException('Malformed shell exit.');
  if (!value.isFinite) {
    return (
      code: null,
      token: value.isNaN ? 'NaN' : (value > 0 ? 'Infinity' : '-Infinity'),
    );
  }
  if (value == value.truncateToDouble() && value.abs() <= _safeInteger) {
    return (code: value.toInt(), token: null);
  }
  // A finite exit that is not a safe integer has no canonical form: it is
  // kept as no reported code, so the outcome stays unknown.
  return (code: null, token: null);
}

/// The native shell status, or null for a value the contract does not name.
ShellStatus? openCodeShellStatus(Object? value) => switch (value) {
  'running' => ShellStatus.running,
  'exited' => ShellStatus.exited,
  'timeout' => ShellStatus.timeout,
  'killed' => ShellStatus.killed,
  _ => null,
};

/// The leading part of [text] within [limit] UTF-8 bytes, cut on a character
/// boundary, and whether anything was cut.
({String text, bool cut}) openCodeBoundedText(String text, int limit) {
  var bytes = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final pair = unit >= 0xd800 && unit <= 0xdbff && i + 1 < text.length;
    final size = pair ? 4 : (unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3));
    if (bytes + size > limit) return (text: text.substring(0, i), cut: true);
    bytes += size;
    if (pair) i++;
  }
  return (text: text, cut: false);
}

/// The redacted leading part of [text] within [limit] UTF-8 bytes. A slice
/// with some margin is redacted first, so a credential that crosses the limit
/// is still recognized whole, and the redacted text is cut again, so the
/// replacement never takes the value past the limit.
({String text, bool cut, bool redacted}) openCodeRedactedText(
  String text,
  int limit,
) {
  final slice = openCodeBoundedText(text, limit + 4096);
  final clean = redactCredentialText(slice.text);
  final bounded = openCodeBoundedText(clean, limit);
  // Whether what is kept differs from the same prefix unredacted: a
  // credential that only appeared past the limit was not shown anyway.
  return (
    text: bounded.text,
    cut: slice.cut || bounded.cut,
    redacted: bounded.text != openCodeBoundedText(text, limit).text,
  );
}

/// Projects the durable 2.0.22 `session.shell.started` and
/// `session.shell.ended` events into [ShellRun] items, the same rows a history
/// read projects from the `shell` message they write, without owning a stream
/// or clock.
///
/// The start inserts the row: its message ID derives from the event ID, as
/// the server's own reducer does. The end updates the resident row of the
/// same shell with its status, exit and the bounded captured output; an end
/// without that row fails with [OpenCodeShellProjectionFailure.missingStart],
/// so the session is read again instead of inventing a row.
///
/// The command and the output are redacted before they are kept; the working
/// directory, the shell, the capture file, the process ID, the signal and the
/// metadata are validated where read and never copied.
List<SessionEvent> projectOpenCodeShellEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type != _started && type != _ended) return const [];
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  final ref = current.ref;
  if (sessionId != ref.nativeId) return const [];
  if (!OpenCodeCompatibility.supportsV2(sourceVersion)) {
    _fail(OpenCodeShellProjectionFailure.unsupportedVersion);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final created = frame['created'];
  if (created is! num ||
      !created.isFinite ||
      created < 0 ||
      created > _maxEpochMillis) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  final durable = _object(frame['durable']);
  if (_id(durable['aggregateID'], 'ses') != sessionId) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  if (_integer(durable['version']) != _durableVersion) {
    _fail(OpenCodeShellProjectionFailure.unsupportedVersion);
  }
  final aggregateSeq = BigInt.from(_integer(durable['seq']));

  final shell = _object(data['shell']);
  final shellId = _id(shell['id'], 'sh_');
  final status = openCodeShellStatus(shell['status']);
  if (status == null) _fail(OpenCodeShellProjectionFailure.malformed);
  final command = _text(shell['command'], cap: _commandLimit);
  for (final key in ['cwd', 'shell', 'file']) {
    _text(shell[key], cap: _commandLimit);
  }
  if (shell.containsKey('signal')) _text(shell['signal'], cap: _idLimit);
  if (shell.containsKey('pid')) _integer(shell['pid']);
  _object(shell['metadata']);
  final time = _object(shell['time']);
  _epoch(time['started']);
  if (time.containsKey('completed')) _epoch(time['completed']);
  // The live schema allows only a finite exit.
  final rawExit = shell['exit'];
  if (rawExit != null && (rawExit is! num || !rawExit.isFinite)) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  final exit = openCodeShellExit(rawExit);

  final ShellRun? resident;
  final String messageId;
  if (type == _started) {
    messageId = 'msg_${nativeId.substring(4)}';
    resident = null;
  } else {
    resident = current.timeline
        .whereType<ShellRun>()
        .where((item) => item.output?.id == shellId)
        .lastOrNull;
    final message = resident?.meta.source.extra?.toJson();
    final stored = message is Map<String, Object?>
        ? message['nativeMessageId']
        : null;
    if (resident == null || stored is! String) {
      _fail(OpenCodeShellProjectionFailure.missingStart);
    }
    messageId = stored;
  }
  final id = ItemId(jsonEncode([ref.storageKey, messageId, 'shell', shellId]));
  for (final item in current.timeline) {
    if (item.id == id && item is! ShellRun) {
      _fail(OpenCodeShellProjectionFailure.itemKindMismatch);
    }
  }

  String? outputText = resident?.outputText;
  var outputRef = resident?.output ?? OutputRef(id: shellId);
  var redacted = false;
  if (type == _ended) {
    final output = _object(data['output']);
    final text = _text(output['output'], cap: 16 * 1024 * 1024);
    final cursor = _integer(output['cursor']);
    final size = _integer(output['size']);
    final truncated = output['truncated'];
    if (truncated is! bool) _fail(OpenCodeShellProjectionFailure.malformed);
    final kept = openCodeRedactedText(text, openCodeShellOutputLimit);
    redacted = kept.redacted;
    outputText = kept.text;
    outputRef = OutputRef(
      id: shellId,
      sizeBytes: size,
      truncated: truncated || cursor < size || kept.cut,
    );
  }
  final cleanCommand = redactCredentialText(command);
  final source = SourceProvenance(
    harness: ref.harnessRef,
    version: sourceVersion,
    nativeType: type as String,
    nativeEventId: nativeId,
    aggregateId: sessionId,
    aggregateSeq: aggregateSeq,
    durability: const OpenValue.known(Durability.durable),
    extra: CanonicalValue({
      'nativeCreated': created,
      'nativeDurableVersion': _durableVersion,
      'nativeMessageId': messageId,
      'nativeShellId': shellId,
      if (cleanCommand != command) 'commandRedacted': true,
      if (redacted) 'outputRedacted': true,
    }),
  );
  return List.unmodifiable([
    ItemUpserted(
      meta: EventMeta(
        owner: SessionOwner(ref),
        position: position,
        receivedAt: receivedAt,
        source: source,
      ),
      item: ShellRun(
        meta: ItemMeta(
          id: id,
          anchor: openCodeMessageAnchor(messageId),
          generation: jsonEncode([
            'live',
            ref.storageKey,
            messageId,
            position.id,
            position.epoch,
          ]),
          status: openCodeShellItemStatus(status, exit.code),
          source: source,
        ),
        command: cleanCommand,
        exitCode: exit.code,
        exitToken: exit.token,
        output: outputRef,
        shellStatus: OpenValue.known(status),
        outputText: outputText,
      ),
    ),
  ]);
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  return value.toInt();
}

void _epoch(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _maxEpochMillis) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeShellProjectionFailure.malformed);
  }
  if (value.length > cap) _fail(OpenCodeShellProjectionFailure.limitExceeded);
  return value;
}

Never _fail(OpenCodeShellProjectionFailure failure) =>
    throw OpenCodeShellProjectionException(failure);
