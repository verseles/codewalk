import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'error_projection.dart';
import 'shell_projection.dart';

/// Atomic, flat HTTP history projection. These are selected-content limits,
/// not OS memory limits: 128 blocks/message, 2000 items/page, depth 16,
/// 16384 nodes/page, 256 KiB/text, 64 KiB/structured field, 1 MiB/page.
/// Generations are deterministic, full-session/message-scoped history identities;
/// they are not live-stream generations or turn/completion evidence.
///
/// A failed `idle` row carries the error of the turn's last assistant message
/// ([openCodeErrorInfo]), which `session.execution.failed` reports live; a
/// user row or any other outcome clears it. Known limit: when that message is
/// on an older page than its `idle` row, the outcome carries no error.
List<TimelineItem> projectOpenCodeHistory(
  List<Object?> messages,
  SessionRef ref, {
  required String sourceVersion,
  int maxItems = 2000,
}) {
  if (maxItems <= 0) throw ArgumentError('maxItems must be positive.');
  if (sourceVersion.isEmpty) {
    throw const FormatException('History source version is required.');
  }
  var nodes = 0;
  var bytes = 0;
  final items = <TimelineItem>[];
  final messageIds = <String>{};
  const credentials = {
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
    'secretaccesskey',
    'awssecretaccesskey',
    'clientsecret',
    'providerstate',
    'providerresultstate',
  };

  /// A credential key: a named one, or any whose normalized name ends with
  /// `authorization` (`Proxy-Authorization`, `HTTP_AUTHORIZATION`).
  bool credentialKey(String key) {
    final name = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    return credentials.contains(name) || name.endsWith('authorization');
  }

  Never malformed() =>
      throw const FormatException('Malformed history content.');
  void node() {
    if (++nodes > 16384) malformed();
  }

  int stringBytes(String value) {
    if (value.length > 256 * 1024) malformed();
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c >= 0xd800 && c <= 0xdbff) {
        if (++i >= value.length) malformed();
        final low = value.codeUnitAt(i);
        if (low < 0xdc00 || low > 0xdfff) malformed();
      } else if (c >= 0xdc00 && c <= 0xdfff) {
        malformed();
      }
    }
    return utf8.encode(value).length;
  }

  String text(
    Object? value, {
    int cap = 256 * 1024,
    bool nonempty = false,
    bool charge = true,
  }) {
    node();
    if (value is! String || (nonempty && value.isEmpty)) malformed();
    final size = stringBytes(value);
    if (size > cap || (charge && (bytes += size) > 1024 * 1024)) malformed();
    return value;
  }

  Map<String, Object?> map(Object? value) {
    node();
    if (value is! Map<String, Object?>) malformed();
    return value;
  }

  List<Object?> list(Object? value) {
    node();
    if (value is! List<Object?>) malformed();
    return value;
  }

  num epoch(Object? value) {
    node();
    if (value is! num || !value.isFinite || value.abs() > 8640000000000000) {
      malformed();
    }
    return value;
  }

  Map<String, Object?> times(Object? value) {
    final time = map(value);
    return {
      'created': epoch(time['created']),
      for (final key in ['completed', 'streamed', 'ran'])
        if (time.containsKey(key)) key: epoch(time[key]),
    };
  }

  void add(TimelineItem item) {
    if (items.length >= maxItems || items.length >= 2000) malformed();
    items.add(item);
  }

  // Validate the entire selected tree before copying or CanonicalValue freezing.
  CanonicalValue structured(
    Object? value, {
    required bool redact,
    required void Function() onRedacted,
  }) {
    var fieldBytes = 0;
    void measure(Object? v, int depth, {bool key = false}) {
      node();
      if (depth > 16) malformed();
      if (v is String) {
        // A redacted value is measured as it will be kept.
        final kept = redact && !key ? redactCredentialText(v) : v;
        stringBytes(v);
        fieldBytes += stringBytes(kept) + 2;
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
        if (!v.isFinite) malformed();
        fieldBytes += v.toString().length;
      } else if (v == null || v is bool) {
        fieldBytes += 5;
      } else if (v is List) {
        fieldBytes += 2 + v.length;
        if (fieldBytes > 65536) malformed();
        for (final child in v) {
          measure(child, depth + 1);
        }
      } else if (v is Map<String, Object?>) {
        fieldBytes += 2 + v.length * 2;
        if (fieldBytes > 65536) malformed();
        for (final entry in v.entries) {
          measure(entry.key, depth + 1, key: true);
          final before = fieldBytes;
          measure(entry.value, depth + 1);
          // Short values expand to the JSON string "[redacted]" (12 bytes).
          if (redact && credentialKey(entry.key) && fieldBytes - before < 12) {
            fieldBytes += 12 - (fieldBytes - before);
          }
        }
      } else {
        malformed();
      }
      if (fieldBytes > 65536) malformed();
    }

    measure(value, 0);
    if ((bytes += fieldBytes) > 1024 * 1024) malformed();
    Object? copy(Object? v) {
      if (v is List) return v.map(copy).toList();
      if (v is Map<String, Object?>) {
        return <String, Object?>{
          for (final e in v.entries)
            e.key: redact && credentialKey(e.key)
                ? (() {
                    onRedacted();
                    return '[redacted]';
                  })()
                : copy(e.value),
        };
      }
      if (redact && v is String) {
        final clean = redactCredentialText(v);
        if (clean != v) onRedacted();
        return clean;
      }
      return v;
    }

    return CanonicalValue(copy(value));
  }

  CanonicalValue manifest(Object? value) =>
      structured(value, redact: false, onRedacted: () {});
  text(sourceVersion, cap: 128, nonempty: true);
  // The last assistant message's error since the previous user or idle row.
  ErrorInfo? failure;
  for (final row in messages) {
    final message = map(row);
    // Trace manifests charge this identifier when retaining it; validation
    // itself must not consume the selected-content budget a second time.
    final id = text(message['id'], cap: 4096, charge: false);
    if (!id.startsWith('msg_') || !messageIds.add(id)) malformed();
    final type = text(message['type'], cap: 4096, nonempty: true);
    final time = times(message['time']);
    ItemMeta meta(
      String kind,
      Object discriminator, {
      OpenValue<ItemStatus>? status,
      int? ordinal,
      Map<String, Object?> extra = const {},
    }) => ItemMeta(
      id: ItemId(jsonEncode([ref.storageKey, id, kind, discriminator])),
      generation: jsonEncode(['history', ref.storageKey, id]),
      status: status ?? OpenValue<ItemStatus>.unknown('completionUnverified'),
      ordinal: ordinal,
      source: SourceProvenance(
        harness: ref.harnessRef,
        version: sourceVersion,
        nativeType: type,
        durability: const OpenValue.known(Durability.unknown),
        extra: manifest({'nativeMessageId': id, 'timestamps': time, ...extra}),
      ),
    );
    void unknown(
      String category,
      String rawType,
      Object discriminator,
      Map<String, Object?> raw, {
      Map<String, Object?> extra = const {},
    }) {
      add(
        UnknownItem(
          meta: meta('unknown', [
            category,
            rawType,
            discriminator,
          ], extra: extra),
          rawType: rawType,
          raw: manifest(raw),
        ),
      );
    }

    const completed = OpenValue.known(ItemStatus.completed);
    switch (type) {
      case 'user':
        failure = null;
        add(
          UserInput(
            meta: meta('user', 0, status: completed),
            text: text(message['text']),
            delivery: OpenValue.unknown('nativeHistoryDeliveryUnverified'),
          ),
        );
        final counts = <String, Object?>{};
        final files = <Object?>[];
        for (final key in ['files', 'agents', 'skills']) {
          if (!message.containsKey(key)) continue;
          final entries = list(message[key]);
          counts[key] = entries.length;
          for (final entry in entries) {
            final context = map(entry);
            if (key == 'files') {
              final source = map(context['source']);
              files.add({
                'mime': text(context['mime'], cap: 4096, charge: false),
                'sourceKind': text(
                  source['type'],
                  cap: 4096,
                  nonempty: true,
                  charge: false,
                ),
              });
            }
            if (context.containsKey('mention')) {
              final mention = map(context['mention']);
              for (final key in ['start', 'end']) {
                node();
                final v = mention[key];
                if (v is! num || !v.isFinite) malformed();
              }
            }
          }
        }
        if (counts.values.any((v) => (v as int) > 0)) {
          unknown(
            'context',
            'user-context-manifest',
            0,
            {
              'type': 'user-context-manifest',
              'reason': 'contentResolutionUnavailable',
              'counts': counts,
              'files': files,
              'contextNotProjected': true,
            },
            extra: {'contextNotProjected': true},
          );
        }
      case 'assistant':
        final blocks = list(message['content']);
        if (blocks.length > 128) malformed();
        var textOrdinal = 0;
        var reasoningOrdinal = 0;
        final callIds = <String>{};
        for (var index = 0; index < blocks.length; index++) {
          final block = map(blocks[index]);
          final blockType = text(
            block['type'],
            cap: 4096,
            nonempty: true,
            charge: false,
          );
          final extra = <String, Object?>{
            'blockType': blockType,
            'ordinal': index,
          };
          switch (blockType) {
            case 'text':
            case 'reasoning':
              final partTime =
                  blockType == 'reasoning' && block.containsKey('time')
                  ? times(block['time'])
                  : null;
              final complete =
                  time.containsKey('completed') ||
                  time.containsKey('streamed') ||
                  (partTime?.containsKey('completed') ?? false);
              final ordinal = blockType == 'text'
                  ? textOrdinal++
                  : reasoningOrdinal++;
              final m = meta(
                blockType,
                ordinal,
                ordinal: ordinal,
                status: complete ? completed : null,
                extra: {...extra, 'blockTimestamps': ?partTime},
              );
              final content = text(block['text']);
              add(
                blockType == 'text'
                    ? AssistantText(meta: m, text: content, complete: complete)
                    : Reasoning(meta: m, text: content, complete: complete),
              );
            case 'tool':
              final callId = text(block['id'], cap: 4096, charge: false);
              final name = text(block['name'], cap: 4096);
              if (!callIds.add(callId)) malformed();
              final toolTime = times(block['time']);
              final state = map(block['state']);
              final stateType = text(
                state['status'],
                cap: 4096,
                nonempty: true,
                charge: false,
              );
              if (block.containsKey('executed') && block['executed'] is! bool) {
                malformed();
              }
              extra.addAll({
                'callId': callId,
                'blockTimestamps': toolTime,
                if (block.containsKey('executed'))
                  'executed': block['executed'],
              });
              if (![
                'streaming',
                'running',
                'completed',
                'error',
              ].contains(stateType)) {
                unknown('tool-state', stateType, callId, {
                  'type': stateType,
                  'reason': 'unsupportedToolState',
                }, extra: extra);
                continue;
              }
              var redacted = false;
              CanonicalValue? canonicalInput;
              if (stateType == 'streaming') {
                // A JSON fragment cannot be safely inspected by the finite
                // credential-key policy. Preserve its state, not its bytes.
                text(state['input'], cap: 65536, charge: false);
                extra['inputNotProjected'] = true;
              } else {
                canonicalInput = structured(
                  map(state['input']),
                  redact: true,
                  onRedacted: () {
                    redacted = true;
                  },
                );
              }
              CanonicalValue? output;
              if (stateType == 'completed' ||
                  (stateType == 'error' && state.containsKey('content'))) {
                final content = list(state['content']);
                if (content.isEmpty) malformed();
                final selected = <Object?>[];
                for (final raw in content) {
                  final part = map(raw);
                  final kind = text(
                    part['type'],
                    cap: 4096,
                    nonempty: true,
                    charge: false,
                  );
                  if (kind == 'text') {
                    final raw = text(part['text'], charge: false);
                    final clean = redactCredentialText(raw);
                    if (clean != raw) extra['outputRedacted'] = true;
                    selected.add({'type': 'text', 'text': clean});
                  } else if (kind == 'file') {
                    selected.add({
                      'type': 'file',
                      'mime': text(part['mime'], cap: 4096, charge: false),
                      'available': false,
                    });
                    extra['outputContentOmitted'] = true;
                  } else {
                    malformed();
                  }
                }
                output = manifest(selected);
              }
              if (state['metadata'] is Map<String, Object?>) {
                final metadata = state['metadata'] as Map<String, Object?>;
                if (metadata.containsKey('truncated')) {
                  if (metadata['truncated'] is! bool) malformed();
                  extra['truncated'] = metadata['truncated'];
                }
              }
              ErrorInfo? error;
              var status = const OpenValue.known(ItemStatus.streaming);
              if (stateType == 'completed') status = completed;
              if (stateType == 'error') {
                final rawError = map(state['error']);
                final errorType = text(
                  rawError['type'],
                  cap: 4096,
                  nonempty: true,
                );
                status = OpenValue.known(
                  errorType == 'aborted'
                      ? ItemStatus.interrupted
                      : ItemStatus.failed,
                );
                // The message is shown, so it is redacted and bounded; the
                // response body is never copied.
                var message = '';
                if (rawError.containsKey('message')) {
                  final raw = text(rawError['message'], charge: false);
                  final kept = openCodeRedactedText(raw, 8 * 1024);
                  message = kept.text;
                  if (kept.redacted) extra['errorRedacted'] = true;
                }
                error = ErrorInfo(
                  kind: const OpenValue.known(ErrorKind.toolFailure),
                  rawType: errorType,
                  rawMessage: message,
                );
              }
              if (redacted) extra['inputRedacted'] = true;
              add(
                ToolCall(
                  meta: meta('tool', callId, status: status, extra: extra),
                  kind: OpenValue.known(
                    name == 'read' ? ToolKind.read : ToolKind.other,
                  ),
                  rawName: name,
                  input: canonicalInput,
                  output: output,
                  error: error,
                ),
              );
            default:
              unknown('block', blockType, index, {
                'type': blockType,
                'reason': 'unsupportedBlockType',
              }, extra: extra);
          }
        }
        // A message that failed before any content is shown by its error.
        if (blocks.isEmpty && !message.containsKey('error')) {
          unknown('empty', 'assistant', 0, {
            'type': 'assistant',
            'reason': 'emptyAssistantContent',
          });
        }
        failure = null;
        if (message.containsKey('error')) {
          final error = map(message['error']);
          final errorType = text(
            error['type'],
            cap: 4096,
            nonempty: true,
            charge: false,
          );
          String? errorMessage;
          if (error.containsKey('message')) {
            node();
            final raw = error['message'];
            if (raw is! String) malformed();
            errorMessage = raw;
          }
          if (openCodeErrorHasCard(errorType)) {
            failure = openCodeErrorInfo(errorType, errorMessage);
            // A message larger than one text field is bounded like the live
            // failure, not rejected: only the kept prefix is validated.
            text(failure.rawMessage, charge: false);
          }
        }
        if (message.containsKey('retry')) {
          final retry = map(message['retry']);
          node();
          final attempt = retry['attempt'];
          if (attempt is! num ||
              !attempt.isFinite ||
              attempt <= 0 ||
              attempt != attempt.truncateToDouble()) {
            malformed();
          }
          final error = map(retry['error']);
          final errorType = text(
            error['type'],
            cap: 4096,
            nonempty: true,
            charge: false,
          );
          unknown('retry', errorType, 0, {
            'type': errorType,
            'reason': 'assistantRetryNotProjected',
            'attempt': attempt,
            'at': epoch(retry['at']),
          });
        }
      case 'synthetic':
      case 'system':
        add(
          Notice(
            meta: meta('notice', 0, status: completed),
            kind: OpenValue.known(
              type == 'synthetic' ? NoticeKind.continuation : NoticeKind.system,
            ),
            text: text(message['text']),
          ),
        );
      case 'idle':
        final outcome = OpenValue.parse(
          text(message['outcome'], cap: 4096, nonempty: true),
          OutcomeKind.values,
        );
        add(
          TurnOutcome(
            meta: meta('outcome', 0, status: completed),
            kind: outcome,
            error: outcome.known == OutcomeKind.failed ? failure : null,
          ),
        );
        failure = null;
      case 'shell':
        final shellId = text(message['shellID'], cap: 4096, nonempty: true);
        if (!shellId.startsWith('sh_')) malformed();
        final rawStatus = text(
          message['status'],
          cap: 4096,
          nonempty: true,
          charge: false,
        );
        final status = openCodeShellStatus(rawStatus);
        if (status == null) {
          unknown('shell-status', rawStatus, shellId, {
            'type': rawStatus,
            'reason': 'unsupportedShellStatus',
          });
          break;
        }
        node();
        final ({int? code, String? token}) exit;
        try {
          exit = openCodeShellExit(message['exit']);
        } on FormatException {
          malformed();
        }
        final command = text(message['command'], cap: 64 * 1024);
        final cleanCommand = redactCredentialText(command);
        String? outputText;
        var outputRef = OutputRef(id: shellId);
        var outputRedacted = false;
        if (message.containsKey('output')) {
          final output = map(message['output']);
          node();
          // A capture larger than one text field is bounded, not rejected:
          // only the kept prefix is validated and charged to the page.
          final raw = output['output'];
          if (raw is! String) malformed();
          int count(Object? value) {
            node();
            if (value is! num ||
                !value.isFinite ||
                value < 0 ||
                value != value.truncateToDouble() ||
                value > 9007199254740991) {
              malformed();
            }
            return value.toInt();
          }

          final cursor = count(output['cursor']);
          final size = count(output['size']);
          node();
          final truncated = output['truncated'];
          if (truncated is! bool) malformed();
          final kept = openCodeRedactedText(raw, openCodeShellOutputLimit);
          outputText = text(kept.text);
          outputRedacted = kept.redacted;
          outputRef = OutputRef(
            id: shellId,
            sizeBytes: size,
            truncated: truncated || cursor < size || kept.cut,
          );
        }
        add(
          ShellRun(
            meta: meta(
              'shell',
              shellId,
              status: openCodeShellItemStatus(status, exit.code),
              extra: {
                'nativeShellId': shellId,
                if (cleanCommand != command) 'commandRedacted': true,
                if (outputRedacted) 'outputRedacted': true,
              },
            ),
            command: cleanCommand,
            exitCode: exit.code,
            exitToken: exit.token,
            output: outputRef,
            shellStatus: OpenValue.known(status),
            outputText: outputText,
          ),
        );
      default:
        unknown('message', type, 0, {
          'type': type,
          'reason': 'unsupportedMessageType',
        });
    }
  }
  return List<TimelineItem>.unmodifiable(items);
}
