import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import 'attachment_projection.dart';
import 'bounded_structure.dart';
import 'compaction_projection.dart';
import 'display_label.dart';
import 'error_projection.dart';
import 'item_ids.dart';
import 'notice_text.dart';
import 'shell_projection.dart';
import 'subagent_child.dart';
import 'tool_metadata.dart';

/// Thrown when an entire history page exceeds its aggregate projection budget
/// (node count, projected bytes, or item count) and may succeed with a smaller
/// page limit. Does not extend [FormatException] so malformed payloads remain
/// distinct from shrinkable dense pages.
final class OpenCodeHistoryBudgetException implements Exception {
  const OpenCodeHistoryBudgetException(this.message);

  final String message;

  @override
  String toString() => 'OpenCodeHistoryBudgetException: $message';
}

/// Atomic, flat HTTP history projection. These are selected-content limits,
/// not OS memory limits: 128 blocks/message, 2000 items/page, depth 16,
/// 16384 nodes/page, 256 KiB/text, 64 KiB/4096 nodes per structured tool field
/// (bounded to a redacted prefix), 8 KiB/tool error, and 1 MiB/page.
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
  OpenCodeInlineMediaSink? onInlineMedia,
}) {
  if (maxItems <= 0) throw ArgumentError('maxItems must be positive.');
  if (sourceVersion.isEmpty) {
    throw const FormatException('History source version is required.');
  }
  var nodes = 0;
  var bytes = 0;
  // Optional display labels have their own small budget, so they can never
  // turn a page whose content fits into a rejected one.
  var labelBytes = 0;
  final items = <TimelineItem>[];
  final messageIds = <String>{};

  Never malformed() =>
      throw const FormatException('Malformed history content.');
  Never budgetExceeded(String reason) =>
      throw OpenCodeHistoryBudgetException(reason);
  void node() {
    if (++nodes > 16384) budgetExceeded('History node budget exceeded.');
  }

  void chargeNodes(int count) {
    if ((nodes += count) > 16384) {
      budgetExceeded('History node budget exceeded.');
    }
  }

  void chargeBytes(int size) {
    if ((bytes += size) > 1024 * 1024) {
      budgetExceeded('History byte budget exceeded.');
    }
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
    if (size > cap) malformed();
    if (charge) chargeBytes(size);
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
      for (final key in ['completed', 'streamed', 'firstToken', 'ran'])
        if (time.containsKey(key)) key: epoch(time[key]),
    };
  }

  void add(TimelineItem item) {
    if (items.length >= maxItems || items.length >= 2000) {
      budgetExceeded('History item budget exceeded.');
    }
    items.add(item);
  }

  CanonicalValue manifest(Object? value) {
    try {
      final bounded = boundOpenCodeStructure(value, redact: false);
      chargeNodes(bounded.nodes);
      chargeBytes(bounded.bytes);
      return bounded.value;
    } on OpenCodeBoundedStructureException {
      malformed();
    }
  }
  String? historyLabel(Object? raw) {
    final label = openCodeDisplayLabel(raw);
    if (label == null) return null;
    final size = utf8.encode(label).length;
    if (labelBytes + size > 64 * 1024) return null;
    labelBytes += size;
    return label;
  }

  text(sourceVersion, cap: 128, nonempty: true);
  // The last assistant message's error since the previous user or idle row.
  ErrorInfo? failure;
  for (final row in messages) {
    final message = map(row);
    final id = text(message['id'], cap: 4096);
    if (!id.startsWith('msg_') || !messageIds.add(id)) malformed();
    final type = text(message['type'], cap: 4096, nonempty: true);
    final time = times(message['time']);
    final context = type == 'assistant'
        ? _historyMessageContext(id, message, time, historyLabel)
        : null;
    ItemMeta meta(
      String kind,
      Object discriminator, {
      OpenValue<ItemStatus>? status,
      int? ordinal,
      Map<String, Object?> extra = const {},
    }) => ItemMeta(
      message: context,
      anchor: openCodeMessageAnchor(id),
      id: ItemId(jsonEncode([ref.storageKey, id, kind, discriminator])),
      generation: jsonEncode(['history', ref.storageKey, id]),
      status: status ?? OpenValue<ItemStatus>.unknown('completionUnverified'),
      ordinal: ordinal,
      source: SourceProvenance(
        harness: ref.harnessRef,
        version: sourceVersion,
        nativeType: type,
        durability: const OpenValue.known(Durability.unknown),
        extra: CanonicalValue({
          'nativeMessageId': id,
          'timestamps': time,
          ...extra,
        }),
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
        final rawUserText = text(message['text']);
        final projected = projectOpenCodeUserAttachments(
          messageId: id,
          rawText: rawUserText,
          rawFiles: message.containsKey('files') ? message['files'] : null,
          rawMetadata: message['metadata'],
          rawAgents: message.containsKey('agents') ? message['agents'] : null,
          rawSkills: message.containsKey('skills') ? message['skills'] : null,
          onInlineMedia: onInlineMedia,
        );
        add(
          UserInput(
            meta: meta('user', 0, status: completed),
            text: projected.displayText,
            attachments: projected.attachments,
            delivery: OpenValue.unknown('nativeHistoryDeliveryUnverified'),
            confirmed: true,
          ),
        );
        if (projected.unprojectedManifest case final unprojected?) {
          unknown(
            'context',
            'user-context-manifest',
            0,
            unprojected,
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
              DateTime? partInstant(Object? value) => value is num
                  ? DateTime.fromMillisecondsSinceEpoch(
                      value.floor(),
                      isUtc: true,
                    )
                  : null;
              add(
                blockType == 'text'
                    ? AssistantText(meta: m, text: content, complete: complete)
                    : Reasoning(
                        meta: m,
                        text: content,
                        complete: complete,
                        started: partInstant(partTime?['created']),
                        completed: partInstant(partTime?['completed']),
                      ),
              );
            case 'tool':
              final callId = text(block['id'], cap: 4096);
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
                // credential-key policy. Validate up to the media body ceiling
                // without charging page budgets, and preserve state only.
                try {
                  validateOpenCodeDiscardedText(
                    state['input'],
                    maxBytes: openCodeHistoryDiscardedInputLimit,
                  );
                } on FormatException {
                  malformed();
                } on RangeError {
                  malformed();
                }
                extra['inputNotProjected'] = true;
              } else {
                final rawInput = map(state['input']);
                try {
                  final bounded = boundOpenCodeStructure(
                    rawInput,
                    redact: true,
                    priorityKeys: openCodeToolInputPriorityKeys,
                  );
                  chargeNodes(bounded.nodes);
                  chargeBytes(bounded.bytes);
                  canonicalInput = bounded.value;
                  redacted = bounded.redacted;
                  if (bounded.truncated) extra['inputTruncated'] = true;
                } on OpenCodeBoundedStructureException {
                  malformed();
                }
              }
              final toolKind = openCodeToolKind(name);
              CanonicalValue? output;
              OutputRef? outputRef;
              if (stateType == 'completed' ||
                  (stateType == 'error' && state.containsKey('content'))) {
                try {
                  final bounded = boundOpenCodeToolContent(
                    state['content'],
                    shellTool: toolKind == ToolKind.shell,
                  );
                  chargeNodes(bounded.nodes);
                  chargeBytes(bounded.bytes);
                  output = bounded.value;
                  if (bounded.redacted) extra['outputRedacted'] = true;
                  if (bounded.omitted) extra['outputContentOmitted'] = true;
                  if (bounded.truncated) {
                    extra['outputTruncated'] = true;
                    outputRef = OutputRef(id: callId, truncated: true);
                  }
                } on OpenCodeBoundedStructureException {
                  malformed();
                }
              }
              ({bool present, SessionRef? child})? named;
              ToolRunFacts? runFacts;
              if (state['metadata'] is Map<String, Object?>) {
                final metadata = state['metadata'] as Map<String, Object?>;
                // Only the child this read names, with this read's source.
                if (toolKind == ToolKind.subagent) {
                  named = openCodeSubagentChild(metadata, ref);
                }
                if (toolKind == ToolKind.shell) {
                  try {
                    runFacts = openCodeShellToolRunFacts(metadata);
                  } on FormatException {
                    malformed();
                  } on RangeError {
                    malformed();
                  }
                }
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
                String? rawMessage;
                if (rawError.containsKey('message')) {
                  node();
                  final raw = rawError['message'];
                  if (raw is! String) malformed();
                  rawMessage = raw;
                }
                final ({ErrorInfo error, bool redacted, bool truncated})
                projectedError;
                try {
                  projectedError = openCodeToolErrorInfo(errorType, rawMessage);
                } on FormatException {
                  malformed();
                }
                if (projectedError.redacted) extra['errorRedacted'] = true;
                if (projectedError.truncated) extra['errorTruncated'] = true;
                chargeBytes(utf8.encode(projectedError.error.rawMessage).length);
                final message = projectedError.error.rawMessage;
                final shellStopped =
                    toolKind == ToolKind.shell &&
                    (message == 'Command cancelled' ||
                        (runFacts?.interrupted ?? false));
                status = OpenValue.known(
                  errorType == 'aborted' || shellStopped
                      ? ItemStatus.interrupted
                      : ItemStatus.failed,
                );
                error = projectedError.error;
              }
              if (redacted) extra['inputRedacted'] = true;
              final itemMeta = meta(
                'tool',
                callId,
                status: status,
                extra: extra,
              );
              final observed = named != null && named.present
                  ? openCodeChildEvidence(
                      named: named.child,
                      prior: null,
                      origin: itemMeta.source,
                      generation: itemMeta.generation,
                    )
                  : null;
              add(
                ToolCall(
                  meta: itemMeta,
                  kind: OpenValue.known(toolKind),
                  rawName: name,
                  input: canonicalInput,
                  output: output,
                  outputRef: outputRef,
                  child: observed?.child,
                  childEvidence: observed?.evidence,
                  error: error,
                  runFacts: runFacts,
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
          if (errorType == 'aborted') {
            add(
              Notice(
                meta: meta(
                  'interruption',
                  0,
                  status: const OpenValue.known(ItemStatus.interrupted),
                ),
                kind: const OpenValue.known(NoticeKind.interruption),
                text: '',
              ),
            );
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
        add(
          openCodeSyntheticNotice(
            meta('notice', 0, status: completed),
            ref,
            text(message['text']),
            message,
            readLabel: historyLabel,
          ),
        );
      case 'system':
        add(
          Notice(
            meta: meta('notice', 0, status: completed),
            kind: const OpenValue.known(NoticeKind.system),
            text: openCodeNoticeText(text(message['text'])),
          ),
        );
      // A switch of agent or model mid-session (#426), as the official
      // client shows it; `previous` is validated and not copied.
      case 'agent-switched':
        final agent = text(message['agent'], cap: 4096, nonempty: true);
        if (message['previous'] != null) {
          text(message['previous'], cap: 4096, nonempty: true);
        }
        add(
          Notice(
            meta: meta('notice', 0, status: completed),
            kind: const OpenValue.known(NoticeKind.selectionChanged),
            text: '',
            selection: Selection(agentId: agent),
          ),
        );
      case 'model-switched':
        final model = map(message['model']);
        final modelId = text(model['id'], cap: 4096, nonempty: true);
        final provider = text(model['providerID'], cap: 4096, nonempty: true);
        // An empty variant is none, as the session record reads it.
        String? variantOf(Map<String, Object?> ref) {
          final raw = ref['variant'];
          if (raw == null) return null;
          final value = text(raw, cap: 4096);
          return value.isEmpty ? null : value;
        }

        final variant = variantOf(model);
        if (message['previous'] != null) {
          final previous = map(message['previous']);
          text(previous['id'], cap: 4096, nonempty: true);
          text(previous['providerID'], cap: 4096, nonempty: true);
          variantOf(previous);
        }
        add(
          Notice(
            meta: meta('notice', 0, status: completed),
            kind: const OpenValue.known(NoticeKind.selectionChanged),
            text: '',
            selection: Selection(
              modelId: modelId,
              modelProviderId: provider,
              modelVariant: variant,
            ),
          ),
        );
      case 'compaction':
        final ({ItemStatus status, String text, CompactionInfo? compaction})?
        compact;
        try {
          compact = openCodeCompactionNotice(message);
        } on OpenCodeCompactionProjectionException {
          malformed();
        }
        if (compact == null) {
          final status = text(message['status'], cap: 4096, nonempty: true);
          unknown('compaction-status', status, 0, {
            'type': status,
            'reason': 'unsupportedCompactionStatus',
          });
          break;
        }
        add(
          Notice(
            meta: meta('notice', 0, status: OpenValue.known(compact.status)),
            kind: const OpenValue.known(NoticeKind.compaction),
            text: text(compact.text),
            compaction: compact.compaction,
          ),
        );
      case 'skill':
        if (message.containsKey('skill')) {
          text(message['skill'], cap: 4096, nonempty: true, charge: false);
        }
        final skillName = text(message['name'], cap: 4096, nonempty: true);
        if (message.containsKey('text')) {
          text(message['text'], charge: false);
        }
        add(
          Notice(
            meta: meta('notice', 0, status: completed),
            kind: const OpenValue.known(NoticeKind.skillActivated),
            text: redactCredentialText(skillName),
          ),
        );
      case 'location-switched':
        final location = map(message['location']);
        final directory = text(location['directory'], cap: 4096, nonempty: true);
        if (location.containsKey('workspaceID')) {
          text(location['workspaceID'], cap: 4096, charge: false);
        }
        if (message.containsKey('projectID')) {
          text(message['projectID'], cap: 4096, nonempty: true, charge: false);
        }
        if (message.containsKey('subpath')) {
          text(message['subpath'], cap: 4096, charge: false);
        }
        String? previousDir;
        if (message.containsKey('previous') && message['previous'] != null) {
          final previous = map(message['previous']);
          final prevLoc = map(previous['location']);
          previousDir = text(
            prevLoc['directory'],
            cap: 4096,
            nonempty: true,
            charge: false,
          );
          if (prevLoc.containsKey('workspaceID')) {
            text(prevLoc['workspaceID'], cap: 4096, charge: false);
          }
          if (previous.containsKey('projectID')) {
            text(
              previous['projectID'],
              cap: 4096,
              nonempty: true,
              charge: false,
            );
          }
          if (previous.containsKey('subpath')) {
            text(previous['subpath'], cap: 4096, charge: false);
          }
        }
        // Moving to the same directory changes nothing (official `movedInPlace`).
        if (previousDir != directory) {
          add(
            Notice(
              meta: meta('notice', 0, status: completed),
              kind: const OpenValue.known(NoticeKind.system),
              text: directory,
            ),
          );
        }
      case 'idle':
        final outcome = OpenValue.parse(
          text(message['outcome'], cap: 4096, nonempty: true),
          OutcomeKind.values,
        );
        ErrorInfo? idleError;
        if (message.containsKey('error') && message['error'] != null) {
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
            idleError = openCodeErrorInfo(errorType, errorMessage);
            text(idleError.rawMessage, charge: false);
          }
        }
        add(
          TurnOutcome(
            meta: meta('outcome', 0, status: completed),
            kind: outcome,
            error: outcome.known == OutcomeKind.failed
                ? (idleError ?? failure)
                : null,
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
            shellId: shellId,
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

/// What an assistant record reports about itself. History stays readable when
/// a display-only value is missing or unexpected: that value is unknown.
MessageContext _historyMessageContext(
  String id,
  Map<String, Object?> message,
  Map<String, Object?> time,
  String? Function(Object?) label,
) {
  DateTime? at(Object? value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.floor(), isUtc: true)
      : null;
  num? amount(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value : null;
  final model = message['model'];
  final tokens = message['tokens'];
  final cache = tokens is Map<String, Object?> ? tokens['cache'] : null;
  final cost = amount(message['cost']);
  return MessageContext(
    message: MessageRef(id),
    created: at(time['created']),
    firstToken: at(time['firstToken']),
    streamed: at(time['streamed']),
    completed: at(time['completed']),
    modelId: model is Map<String, Object?> ? label(model['id']) : null,
    modelProviderId: model is Map<String, Object?>
        ? label(model['providerID'])
        : null,
    modelVariant: model is Map<String, Object?>
        ? label(model['variant'])
        : null,
    agentId: label(message['agent']),
    tokens: tokens is Map<String, Object?>
        ? TokenBreakdown(
            input: amount(tokens['input']),
            output: amount(tokens['output']),
            reasoning: amount(tokens['reasoning']),
            cacheRead: cache is Map<String, Object?>
                ? amount(cache['read'])
                : null,
            cacheWrite: cache is Map<String, Object?>
                ? amount(cache['write'])
                : null,
          )
        : null,
    cost: cost == null ? null : Cost(amount: cost, currency: 'USD'),
    finish: label(message['finish']),
  );
}
