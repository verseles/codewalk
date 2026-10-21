import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'shell_projection.dart';
import 'version_policy.dart';

enum OpenCodeToolProjectionFailure {
  malformed,
  unsupportedVersion,
  limitExceeded,
  itemKindMismatch,
  unsupportedValue,
}

/// Contains a finite category, never native content or identifiers.
final class OpenCodeToolProjectionException implements Exception {
  const OpenCodeToolProjectionException(this.failure);

  final OpenCodeToolProjectionFailure failure;

  @override
  String toString() => 'OpenCodeToolProjectionException(${failure.name})';
}

const _idLimit = 4096;
const _argumentLimit = 65536;
const _fieldLimit = 65536;
const _textLimit = 256 * 1024;
const _safeInteger = 9007199254740991;
const _types = {
  'session.tool.input.started',
  'session.tool.input.delta',
  'session.tool.input.ended',
  'session.tool.called',
  'session.tool.progress',
  'session.tool.success',
  'session.tool.failed',
};
const _credentials = {
  'password',
  'passwd',
  'secret',
  'apikey',
  'xapikey',
  'authorization',
  'token',
  'accesstoken',
  'refreshtoken',
  'apitoken',
  'privatekey',
  'clientsecret',
  'providerstate',
  'providerresultstate',
};

/// Projects the selected 2.0.22 tool phases without owning a stream or clock.
///
/// Project and reduce each observation against the latest [current] state.
/// Raw argument fragments/boundaries are validated and omitted: the finite
/// credential-key policy is safe only on structured `called.input`. Arbitrary
/// progress metadata is omitted. These three recognized phases return null.
/// Missing observed names or incompatible resident provenance request recovery;
/// this function never adopts a history/prior-epoch row or invents a tool name.
///
/// Selected strings have 4 KiB identity or 64 KiB raw-argument limits. Structured
/// input/output each have a 64 KiB JSON-escaped budget, depth 16 and 16384 shared
/// node visits; output has at most 128 parts. Text's 256 KiB cap is subordinate
/// to the structured-field budget. Rejection is atomic, without truncation.
/// These guards do not bound upstream decoding or total process memory.
SessionEvent? projectOpenCodeToolEvent(
  Object? value,
  SessionState current, {
  required String sourceVersion,
  required StreamPosition position,
  required DateTime receivedAt,
}) {
  final frame = _object(value);
  final type = frame['type'];
  if (type is! String) _fail(OpenCodeToolProjectionFailure.malformed);
  if (!_types.contains(type)) return null;
  final data = _object(frame['data']);
  final sessionId = _id(data['sessionID'], 'ses');
  if (sessionId != current.ref.nativeId) return null;
  if (OpenCodeCompatibility.parse(sourceVersion)?.toString() != '2.0.22') {
    _fail(OpenCodeToolProjectionFailure.unsupportedVersion);
  }
  for (final part in [
    current.ref.host.value,
    current.ref.harness.value,
    current.ref.nativeId,
    position.id,
    position.epoch,
  ]) {
    _text(part, cap: _idLimit, nonempty: true);
  }
  final nativeId = _id(frame['id'], 'evt_');
  final messageId = _id(data['assistantMessageID'], 'msg_');
  // Unlike event/message IDs, call IDs and names are plain schema strings.
  final callId = _text(data['id'], cap: _idLimit);
  final created = frame['created'];
  if (created is! num || !created.isFinite) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  final ephemeral =
      type == 'session.tool.input.delta' || type == 'session.tool.progress';
  final started = type == 'session.tool.input.started';
  final called = type == 'session.tool.called';
  final success = type == 'session.tool.success';
  final failed = type == 'session.tool.failed';
  final terminal = success || failed;
  String? aggregateId;
  BigInt? aggregateSeq;
  int? durableVersion;
  if (ephemeral) {
    if (frame.containsKey('durable')) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
  } else {
    final durable = _object(frame['durable']);
    aggregateId = _id(durable['aggregateID'], 'ses');
    if (aggregateId != sessionId) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
    durableVersion = _integer(durable['version']);
    if (durableVersion != (terminal ? 2 : 1)) {
      _fail(OpenCodeToolProjectionFailure.unsupportedVersion);
    }
    aggregateSeq = BigInt.from(_integer(durable['seq']));
  }
  if (type == 'session.tool.input.delta') {
    _text(data['delta'], cap: _argumentLimit);
    return null;
  }
  if (type == 'session.tool.input.ended') {
    _text(data['text'], cap: _argumentLimit);
    return null;
  }
  if (type == 'session.tool.progress') {
    _object(data['metadata']);
    return null;
  }

  final budget = _SelectedBudget();
  var inputRedacted = false;
  CanonicalValue selectedInput(Object? value) => budget.structured(
    _object(value),
    redact: true,
    onRedacted: () => inputRedacted = true,
  );
  var name = started ? _text(data['name'], cap: _idLimit) : '';
  CanonicalValue? input;
  CanonicalValue? output;
  ErrorInfo? error;
  bool? executed;
  bool? truncated;
  var outputOmitted = false;
  var outputRedacted = false;
  var errorRedacted = false;
  var status = ItemStatus.streaming;
  if (called || terminal) {
    executed = _boolean(data['executed']);
  }
  if (called) input = selectedInput(data['input']);
  if (success || (failed && data.containsKey('content'))) {
    (output, outputOmitted, outputRedacted) = _content(
      data['content'],
      budget,
    );
  }
  if (terminal && data.containsKey('metadata')) {
    final metadata = _object(data['metadata']);
    if (metadata.containsKey('truncated')) {
      truncated = _boolean(metadata['truncated']);
    }
  }
  if (success) status = ItemStatus.completed;
  if (failed) {
    final rawError = _object(data['error']);
    final errorType = _text(rawError['type'], cap: _idLimit);
    // Schema.String allows empty; Core ErrorInfo requires a nonempty rawType.
    if (errorType.isEmpty) {
      _fail(OpenCodeToolProjectionFailure.unsupportedValue);
    }
    status = errorType == 'aborted'
        ? ItemStatus.interrupted
        : ItemStatus.failed;
    // The message is shown, so it is redacted and bounded; the response body
    // is never copied.
    var message = '';
    if (rawError.containsKey('message')) {
      final raw = _text(rawError['message'], cap: _textLimit);
      final kept = openCodeRedactedText(raw, 8 * 1024);
      message = kept.text;
      errorRedacted = kept.redacted;
    }
    error = ErrorInfo(
      kind: const OpenValue.known(ErrorKind.toolFailure),
      rawType: errorType,
      rawMessage: message,
    );
  }

  final id = ItemId(
    jsonEncode([current.ref.storageKey, messageId, 'tool', callId]),
  );
  final generation = jsonEncode([
    'live',
    current.ref.storageKey,
    messageId,
    position.id,
    position.epoch,
  ]);
  EventMeta meta() => EventMeta(
    owner: SessionOwner(current.ref),
    position: position,
    receivedAt: receivedAt,
    source: SourceProvenance(
      harness: current.ref.harnessRef,
      version: sourceVersion,
      nativeType: type,
      nativeEventId: nativeId,
      aggregateId: aggregateId,
      aggregateSeq: aggregateSeq,
      durability: const OpenValue.known(Durability.durable),
      extra: CanonicalValue({
        'nativeCreated': created,
        'nativeMessageId': messageId,
        'nativeToolCallId': callId,
        'nativeDurableVersion': durableVersion,
        'rawInputNotProjected': true,
        if (input == null) 'inputNotProjected': true,
        if (inputRedacted) 'inputRedacted': true,
        if (outputRedacted) 'outputRedacted': true,
        if (errorRedacted) 'errorRedacted': true,
        if (outputOmitted) 'outputContentOmitted': true,
        'executed': ?executed,
        'truncated': ?truncated,
      }),
    ),
  );
  TimelineItem? resident;
  for (final item in current.timeline) {
    if (item.id == id) {
      resident = item;
      break;
    }
  }
  if (resident != null && resident is! ToolCall) {
    _fail(OpenCodeToolProjectionFailure.itemKindMismatch);
  }
  if (resident is ToolCall) {
    final extra = resident.source.extra?.value;
    if (resident.generation != generation ||
        resident.source.harness != current.ref.harnessRef ||
        OpenCodeCompatibility.parse(resident.source.version)?.toString() !=
            '2.0.22' ||
        !const {
          'session.tool.input.started',
          'session.tool.called',
          'session.tool.success',
          'session.tool.failed',
        }.contains(resident.source.nativeType) ||
        resident.source.nativeEventId?.startsWith('evt_') != true ||
        resident.source.durability.known != Durability.durable ||
        resident.source.aggregateId != sessionId ||
        resident.source.aggregateSeq == null ||
        extra is! Map<String, Object?> ||
        extra['nativeMessageId'] != messageId ||
        extra['nativeToolCallId'] != callId) {
      return ResyncRequired(meta: meta(), reason: 'toolResidentIncompatible');
    }
    final residentName = _text(resident.rawName, cap: _idLimit);
    if (resident.kind.known != _kind(residentName) ||
        resident.status.known == null) {
      return ResyncRequired(meta: meta(), reason: 'toolResidentIncompatible');
    }
    if (started) {
      return name == residentName
          ? null
          : ResyncRequired(meta: meta(), reason: 'toolNameMismatch');
    }
    if (!terminal && _settled(resident)) return null;
    name = residentName;
    // Carry only revalidated selected input, never arbitrary source/other fields.
    if (!called && resident.input != null) {
      input = selectedInput(resident.input!.value);
    }
  } else if (!started) {
    return ResyncRequired(meta: meta(), reason: 'toolStartMissing');
  }
  final eventMeta = meta();
  return ItemUpserted(
    meta: eventMeta,
    item: ToolCall(
      meta: ItemMeta(
        id: id,
        generation: generation,
        status: OpenValue.known(status),
        source: eventMeta.source,
      ),
      kind: OpenValue.known(_kind(name)),
      rawName: name,
      input: input,
      output: output,
      error: error,
    ),
  );
}

ToolKind _kind(String name) => name == 'read' ? ToolKind.read : ToolKind.other;
bool _settled(ToolCall item) => const {
  ItemStatus.completed,
  ItemStatus.failed,
  ItemStatus.interrupted,
}.contains(item.status.known);

(CanonicalValue, bool, bool) _content(
  Object? value,
  _SelectedBudget budget,
) {
  if (value is! List<Object?> || value.isEmpty) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  if (value.length > 128) _fail(OpenCodeToolProjectionFailure.limitExceeded);
  var omitted = false;
  var redacted = false;
  final selected = <Object?>[];
  for (final raw in value) {
    final part = _object(raw);
    final type = _text(part['type'], cap: _idLimit, nonempty: true);
    if (type == 'text') {
      final raw = _text(part['text'], cap: _textLimit);
      final clean = redactCredentialText(raw);
      redacted = redacted || clean != raw;
      selected.add({'type': 'text', 'text': clean});
    } else if (type == 'file') {
      selected.add({
        'type': 'file',
        'mime': _text(part['mime'], cap: _idLimit),
        'available': false,
      });
      omitted = true;
    } else {
      _fail(OpenCodeToolProjectionFailure.malformed);
    }
  }
  return (budget.structured(selected), omitted, redacted);
}

final class _SelectedBudget {
  var nodes = 0;
  var bytes = 0;

  CanonicalValue structured(
    Object? value, {
    bool redact = false,
    void Function()? onRedacted,
  }) {
    var fieldBytes = 0;
    void measure(Object? v, int depth, {bool key = false}) {
      if (++nodes > 16384 || depth > 16) {
        _fail(OpenCodeToolProjectionFailure.limitExceeded);
      }
      if (v is String) {
        // A redacted value is measured as it will be kept.
        final kept = redact && !key ? redactCredentialText(v) : v;
        _bytes(v, _fieldLimit);
        fieldBytes += _bytes(kept, _fieldLimit) + 2;
        for (final unit in kept.codeUnits) {
          if (unit == 0x22 ||
              unit == 0x5c ||
              unit == 8 ||
              unit == 9 ||
              unit == 10 ||
              unit == 12 ||
              unit == 13) {
            fieldBytes++;
          } else if (unit < 0x20) {
            fieldBytes += 5;
          }
        }
      } else if (v is num) {
        if (!v.isFinite) _fail(OpenCodeToolProjectionFailure.malformed);
        fieldBytes += v.toString().length;
      } else if (v == null || v is bool) {
        fieldBytes += 5;
      } else if (v is List) {
        fieldBytes += 2 + v.length;
        if (fieldBytes > _fieldLimit) {
          _fail(OpenCodeToolProjectionFailure.limitExceeded);
        }
        for (final child in v) {
          measure(child, depth + 1);
        }
      } else if (v is Map<String, Object?>) {
        fieldBytes += 2 + v.length * 2;
        if (fieldBytes > _fieldLimit) {
          _fail(OpenCodeToolProjectionFailure.limitExceeded);
        }
        for (final entry in v.entries) {
          measure(entry.key, depth + 1, key: true);
          final before = fieldBytes;
          measure(entry.value, depth + 1);
          // Short values expand to the JSON string "[redacted]" (12 bytes).
          // Retain the raw-tree guard while also bounding the canonical copy.
          if (redact && _credentialKey(entry.key) && fieldBytes - before < 12) {
            fieldBytes += 12 - (fieldBytes - before);
          }
        }
      } else {
        _fail(OpenCodeToolProjectionFailure.unsupportedValue);
      }
      if (fieldBytes > _fieldLimit) {
        _fail(OpenCodeToolProjectionFailure.limitExceeded);
      }
    }

    measure(value, 0);
    if ((bytes += fieldBytes) > 1024 * 1024) {
      _fail(OpenCodeToolProjectionFailure.limitExceeded);
    }
    Object? copy(Object? v) {
      if (v is List) return v.map(copy).toList();
      if (v is Map<String, Object?>) {
        return <String, Object?>{
          for (final entry in v.entries)
            entry.key: redact && _credentialKey(entry.key)
                ? (() {
                    onRedacted?.call();
                    return '[redacted]';
                  })()
                : copy(entry.value),
        };
      }
      if (redact && v is String) {
        final clean = redactCredentialText(v);
        if (clean != v) onRedacted?.call();
        return clean;
      }
      return v;
    }

    return CanonicalValue(copy(value));
  }
}

bool _credentialKey(String key) => _credentials.contains(
  key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''),
);

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) _fail(OpenCodeToolProjectionFailure.malformed);
  return value;
}

int _integer(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      value > _safeInteger ||
      value != value.truncate()) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return value.toInt();
}

String _id(Object? value, String prefix) {
  final result = _text(value, cap: _idLimit, nonempty: true);
  if (!result.startsWith(prefix)) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  return result;
}

String _text(Object? value, {required int cap, bool nonempty = false}) {
  if (value is! String || (nonempty && value.isEmpty)) {
    _fail(OpenCodeToolProjectionFailure.malformed);
  }
  _bytes(value, cap);
  return value;
}

int _bytes(String value, int cap) {
  if (value.length > cap) _fail(OpenCodeToolProjectionFailure.limitExceeded);
  var bytes = 0;
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= value.length) _fail(OpenCodeToolProjectionFailure.malformed);
      final low = value.codeUnitAt(i);
      if (low < 0xdc00 || low > 0xdfff) {
        _fail(OpenCodeToolProjectionFailure.malformed);
      }
      bytes += 4;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      _fail(OpenCodeToolProjectionFailure.malformed);
    } else {
      bytes += unit < 0x80 ? 1 : (unit < 0x800 ? 2 : 3);
    }
    if (bytes > cap) _fail(OpenCodeToolProjectionFailure.limitExceeded);
  }
  return bytes;
}

Never _fail(OpenCodeToolProjectionFailure failure) =>
    throw OpenCodeToolProjectionException(failure);
