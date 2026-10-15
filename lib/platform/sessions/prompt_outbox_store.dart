import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/prompt_outbox.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';

/// One bounded JSON ledger per session, written atomically through the
/// payload store before each POST. A whole submit (read, record, POST,
/// update) is serialized per session, so this client's own mutations of a
/// session stay ordered (plan §6.8). Nothing is resent here.
final class OpenCodePromptOutbox implements PromptOutbox {
  OpenCodePromptOutbox({
    required this.store,
    required this.client,
    required this.ids,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const maxEntries = 24;
  static const maxLedgerChars = 1024 * 1024;

  final PayloadStore store;
  final OpenCodePromptClient client;
  final OpenCodeMessageIds ids;
  final DateTime Function() _now;
  final _queue = KeySerialExecutor();

  static String keyFor(SessionRef session) =>
      'cw2.outbox.v1.${sha256.convert(utf8.encode(session.storageKey))}';

  @override
  Future<OutboxSubmission> submit({
    required SessionRef session,
    required CommandId commandId,
    required PromptDraft draft,
    required Delivery delivery,
  }) {
    final key = keyFor(session);
    return _queue.run(key, () async {
      final read = await _read(key, session);
      if (read == null) return const OutboxSubmission.refused('unreadable');
      final ledger = await _recover(key, session, read);
      for (final record in ledger.records) {
        if (record.commandId == commandId) {
          // A deliberate resend is a new command; this one is never reposted.
          return OutboxSubmission.recorded(record.entry, sent: false);
        }
      }
      if (ledger.forgotten.contains(commandId.value)) {
        return const OutboxSubmission.refused('alreadySubmitted');
      }
      // Ids minted before a restart stay below the next one.
      for (final record in ledger.records) {
        ids.observe(record.messageId);
      }
      final OpenCodePromptReady ready;
      switch (client.prepare(
        session: session,
        commandId: commandId,
        messageId: ids.mint(),
        draft: draft,
        delivery: delivery,
      )) {
        case OpenCodePromptRefused(:final attempt):
          return OutboxSubmission.refused(
            attempt.receipt.reason ?? 'unavailable',
          );
        case final OpenCodePromptReady prepared:
          ready = prepared;
      }
      // Only an admitted entry makes room: the server already holds its text.
      // Rejected entries keep the user's text and uncertain ones may need a
      // replay, so without an admitted one a full ledger refuses.
      var base = ledger;
      if (base.records.length >= maxEntries) {
        final evicted = base.records.where(
          (r) => r.state == SubmissionKind.admitted,
        );
        if (evicted.isEmpty) return const OutboxSubmission.refused('full');
        base = base.without(evicted.first);
      }
      final now = _now().toUtc();
      final record = _Record(
        session: session,
        commandId: commandId,
        messageId: ready.messageId,
        text: ready.text,
        delivery: ready.delivery,
        connectedVersion: ready.command.connectedVersion,
        resume: ready.resume,
        payload: ready.payload,
        state: SubmissionKind.sending,
        createdAt: now,
        updatedAt: now,
      );
      if (!await _persist(key, session, base.adding(record))) {
        return const OutboxSubmission.refused('notPersisted');
      }
      final attempt = await client.post(ready);
      final result = record.copyWith(
        // Refused locally before the wire: definitely not admitted.
        state: attempt.posted
            ? attempt.submission!.kind.known!
            : SubmissionKind.rejected,
        reason: attempt.receipt.error?.rawType ?? attempt.receipt.reason,
        updatedAt: _now().toUtc(),
      );
      // If this write fails the ledger keeps `sending`, read back later as
      // uncertain: never as unsent.
      await _persist(key, session, base.adding(result));
      return OutboxSubmission.recorded(result.entry, sent: attempt.posted);
    });
  }

  @override
  Future<List<OutboxEntry>> entries(SessionRef session) {
    final key = keyFor(session);
    return _queue.run(key, () async {
      final ledger = await _read(key, session);
      if (ledger == null) {
        throw StateError('The outbox of this session is unreadable.');
      }
      return [
        for (final record in (await _recover(key, session, ledger)).records)
          record.entry,
      ];
    });
  }

  @override
  Future<bool> dismiss(SessionRef session, CommandId commandId) {
    final key = keyFor(session);
    return _queue.run(key, () async {
      final ledger = await _read(key, session);
      if (ledger == null) return false;
      final matches = ledger.records.where(
        (r) => r.commandId == commandId && r.state != SubmissionKind.sending,
      );
      if (matches.isEmpty) return false;
      return _persist(key, session, ledger.without(matches.first));
    });
  }

  /// Operations are serialized per session, so a `sending` record seen here
  /// outlived its process: whether it reached the server is unknown. It is
  /// rewritten as uncertain, never as unsent.
  Future<_Ledger> _recover(
    String key,
    SessionRef session,
    _Ledger ledger,
  ) async {
    if (!ledger.records.any((r) => r.state == SubmissionKind.sending)) {
      return ledger;
    }
    final recovered = _Ledger([
      for (final record in ledger.records)
        record.state == SubmissionKind.sending
            ? record.copyWith(
                state: SubmissionKind.uncertain,
                reason: 'interrupted',
                updatedAt: _now().toUtc(),
              )
            : record,
    ], ledger.forgotten);
    await _persist(key, session, recovered);
    return recovered;
  }

  /// Null when present but unreadable: such a ledger is never overwritten.
  Future<_Ledger?> _read(String key, SessionRef session) async {
    try {
      final raw = await store.read(key);
      if (raw == null) {
        return await store.contains(key) ? null : const _Ledger([], []);
      }
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?> ||
          json['schema'] != 1 ||
          SessionRef.fromJson(json['session']) != session) {
        return null;
      }
      return _Ledger(
        [
          for (final item in json['entries']! as List<Object?>)
            _Record.fromJson(item, session),
        ],
        [
          for (final id in json['forgotten'] as List<Object?>? ?? const [])
            id! as String,
        ],
      );
    } on Object {
      return null;
    }
  }

  /// True only when the ledger now durably holds [ledger]; a failed write is
  /// re-read, since it may have committed before failing.
  Future<bool> _persist(String key, SessionRef session, _Ledger ledger) async {
    final value = jsonEncode({
      'schema': 1,
      'session': session.toJson(),
      'entries': [for (final record in ledger.records) record.toJson()],
      'forgotten': ledger.forgotten,
    });
    if (value.length > maxLedgerChars) return false;
    try {
      final result = await store.write(key, value);
      if (result != PayloadWriteResult.refusedOversized) return true;
      return false;
    } on Object {
      try {
        return await store.read(key) == value;
      } on Object {
        return false;
      }
    }
  }
}

/// Records, plus the bounded ids of commands no longer recorded: a forgotten
/// command was already submitted and is never posted again under a new id.
/// Every deliberate send has a fresh command id, so the bound only matters for
/// an id reused hundreds of sends later.
final class _Ledger {
  const _Ledger(this.records, this.forgotten);
  static const maxForgotten = 256;
  final List<_Record> records;
  final List<String> forgotten;

  _Ledger adding(_Record record) => _Ledger([...records, record], forgotten);

  _Ledger without(_Record record) {
    final ids = [...forgotten, record.commandId.value];
    return _Ledger(
      [
        for (final r in records)
          if (!identical(r, record)) r,
      ],
      ids.length > maxForgotten ? ids.sublist(ids.length - maxForgotten) : ids,
    );
  }
}

final class _Record {
  const _Record({
    required this.session,
    required this.commandId,
    required this.messageId,
    required this.text,
    required this.delivery,
    required this.connectedVersion,
    required this.resume,
    required this.payload,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.reason,
  });

  factory _Record.fromJson(Object? value, SessionRef session) {
    final json = value! as Map<String, Object?>;
    final state = SubmissionKind.values.byName(json['state']! as String);
    if (state == SubmissionKind.draft) {
      throw const FormatException('A draft is never recorded.');
    }
    return _Record(
      session: session,
      commandId: CommandId.fromJson(json['commandId']),
      messageId: json['messageId']! as String,
      text: json['text']! as String,
      delivery: Delivery.values.byName(json['delivery']! as String),
      connectedVersion: json['connectedVersion']! as String,
      resume: json['resume']! as bool,
      payload: json['payload']! as String,
      state: state,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      reason: json['reason'] as String?,
    );
  }

  final SessionRef session;
  final CommandId commandId;
  final String messageId;
  final String text;
  final Delivery delivery;
  final String connectedVersion;
  final bool resume;

  /// The exact body posted; a later same-id replay must repeat it unchanged.
  final String payload;
  final SubmissionKind state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? reason;

  OutboxEntry get entry => OutboxEntry(
    session: session,
    commandId: commandId,
    messageId: messageId,
    text: text,
    delivery: delivery,
    state: state,
    createdAt: createdAt,
    updatedAt: updatedAt,
    reason: reason,
  );

  _Record copyWith({
    required SubmissionKind state,
    required DateTime updatedAt,
    String? reason,
  }) => _Record(
    session: session,
    commandId: commandId,
    messageId: messageId,
    text: text,
    delivery: delivery,
    connectedVersion: connectedVersion,
    resume: resume,
    payload: payload,
    state: state,
    createdAt: createdAt,
    updatedAt: updatedAt,
    reason: reason,
  );

  Map<String, Object?> toJson() => {
    'commandId': commandId.toJson(),
    'messageId': messageId,
    'text': text,
    'delivery': delivery.name,
    'connectedVersion': connectedVersion,
    'resume': resume,
    'payload': payload,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reason': ?reason,
  };
}
