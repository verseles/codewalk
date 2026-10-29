import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';

import '../storage/payload_store.dart';
import 'prompt_outbox_store.dart';

/// A pending mutation is recorded before the wire. Reopening a lease or the
/// app may read it and reconcile its effect, but can never resend it. No draft,
/// file contents, paths or native error body is retained here.
final class TurnActionRecord {
  const TurnActionRecord({
    required this.operation,
    required this.id,
    this.anchor,
    this.input,
    this.tail = const [],
    this.completeTail = false,
    this.admittedInput,
  });
  final MutationOperation operation;
  final CommandId id;
  final MessageAnchor? anchor;
  final MessageRef? input;
  final List<MessageRef> tail;
  final bool completeTail;

  /// The server's admitted/coalesced compaction identity; admission is not
  /// completion, so this record stays until its terminal notice is observed.
  final MessageRef? admittedInput;

  TurnActionRecord withAdmission(MessageRef input) => TurnActionRecord(
    operation: operation,
    id: id,
    anchor: anchor,
    input: this.input,
    tail: tail,
    completeTail: completeTail,
    admittedInput: input,
  );
}

final class TurnActionJournal {
  TurnActionJournal(this.store, this.profile);
  final PayloadStore store;
  final EndpointProfile profile;

  static String keyFor(SessionRef ref) =>
      OpenCodePromptOutbox.keyFor(ref).replaceFirst('cw2.outbox.', 'cw2.turn.');

  /// Throws for an unreadable or different-binding record. Callers keep the
  /// fence and preserve that record rather than treating it as absence.
  Future<TurnActionRecord?> read(SessionRef ref) async {
    final key = keyFor(ref);
    final raw = await store.read(key);
    if (raw == null) {
      if (await store.contains(key)) throw const FormatException('unreadable');
      return null;
    }
    if (raw.length > 128 * 1024) throw const FormatException('oversized');
    final value = jsonDecode(raw);
    if (value is! Map<String, Object?> ||
        value['schema'] != 1 ||
        value['session'] != ref.storageKey ||
        value['endpoint'] != profile.endpoint.toString() ||
        value['binding'] != profile.bindingRevision) {
      throw const FormatException('sourceChanged');
    }
    String text(Object? value) {
      if (value is! String || value.isEmpty || value.length > 1024) {
        throw const FormatException('invalidIdentity');
      }
      return value;
    }

    final operation = switch (value['operation']) {
      'revertStage' => MutationOperation.revertStage,
      'revertClear' => MutationOperation.revertClear,
      'revertCommit' => MutationOperation.revertCommit,
      'compact' => MutationOperation.compact,
      _ => throw const FormatException('invalidOperation'),
    };
    MessageAnchor? anchor;
    if (value['anchor'] case final Map<String, Object?> data) {
      anchor = MessageAnchor(
        message: MessageRef(text(data['message'])),
        orderKey: text(data['orderKey']),
      );
    } else if (value['anchor'] != null) {
      throw const FormatException('invalidAnchor');
    }
    final input = value['input'] == null
        ? null
        : MessageRef(text(value['input']));
    final admitted = value['admittedInput'] == null
        ? null
        : MessageRef(text(value['admittedInput']));
    if (admitted != null && operation != MutationOperation.compact) {
      throw const FormatException('invalidAdmission');
    }
    final tail = value['tail'];
    if (tail is! List<Object?> ||
        tail.length > 500 ||
        value['completeTail'] is! bool) {
      throw const FormatException('invalidTail');
    }
    if ((operation == MutationOperation.compact && input == null) ||
        (operation != MutationOperation.compact && anchor == null)) {
      throw const FormatException('missingIdentity');
    }
    return TurnActionRecord(
      operation: operation,
      id: CommandId(text(value['id'])),
      anchor: anchor,
      input: input,
      tail: [for (final message in tail) MessageRef(text(message))],
      completeTail: value['completeTail'] as bool,
      admittedInput: admitted,
    );
  }

  Future<bool> write(SessionRef ref, TurnActionRecord record) async {
    final raw = jsonEncode({
      'schema': 1,
      'session': ref.storageKey,
      'endpoint': profile.endpoint.toString(),
      'binding': profile.bindingRevision,
      'operation': record.operation.name,
      'id': record.id.value,
      if (record.anchor case final anchor?)
        'anchor': {
          'message': anchor.message.value,
          'orderKey': anchor.orderKey,
        },
      if (record.input case final input?) 'input': input.value,
      if (record.admittedInput case final input?) 'admittedInput': input.value,
      'tail': [for (final message in record.tail) message.value],
      'completeTail': record.completeTail,
    });
    if (raw.length > 128 * 1024) return false;
    try {
      return await store.write(keyFor(ref), raw) !=
          PayloadWriteResult.refusedOversized;
    } on Object {
      // A write can have committed before reporting failure. No request may
      // follow it; the next read decides which record is actually present.
      return false;
    }
  }

  Future<bool> clear(SessionRef ref) async {
    try {
      await store.remove(keyFor(ref));
      return !await store.contains(keyFor(ref));
    } on Object {
      return false;
    }
  }
}
