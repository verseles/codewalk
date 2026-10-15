import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:crypto/crypto.dart';
import 'package:harness_opencode/harness_opencode.dart';

import '../../shared/sessions/prompt_outbox.dart';
import '../storage/payload_store.dart';
import '../storage/storage_support.dart';

/// One bounded JSON ledger per session, written atomically through the
/// payload store before each POST. A whole submit (read, record, POST,
/// update) and each reconcile step are serialized per session, so this
/// client's own mutations of a session stay ordered (plan §6.8). Only
/// [reconcile] resends, under the original id.
final class OpenCodePromptOutbox implements PromptOutbox {
  OpenCodePromptOutbox({
    required this.store,
    required this.client,
    required this.reader,
    required this.ids,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    KeySerialExecutor? queue,
  }) : _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed,
       _queue = queue ?? KeySerialExecutor() {
    if (reader.harness != client.harness ||
        reader.transport.endpoint != client.transport.endpoint) {
      throw ArgumentError('The reader and the client serve another server.');
    }
  }

  static const maxEntries = 24;
  static const maxLedgerChars = 1024 * 1024;

  /// Same-id replays after the original send; the wait before each next one.
  static const maxReplays = 3;
  static const replayBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final PayloadStore store;
  final OpenCodePromptClient client;
  final OpenCodeSessionReader reader;
  final OpenCodeMessageIds ids;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// Shared by every outbox of one server, so two instances writing the same
  /// session ledger still take turns.
  final KeySerialExecutor _queue;

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
      // Only an admitted, delivered or cancelled entry makes room: the server
      // already holds its text or no longer needs it. Rejected entries keep the user's text and uncertain
      // ones may need a replay, so without such an entry a full ledger
      // refuses.
      var base = ledger;
      if (base.records.length >= maxEntries) {
        final evicted = base.records.where(
          (r) =>
              (r.state == SubmissionKind.admitted ||
                  r.state == SubmissionKind.delivered ||
                  r.state == SubmissionKind.cancelled) &&
              // An unfinished cancel stays until it is settled.
              !_open(r.fence),
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

  @override
  Future<OutboxReconciliation> reconcile(
    SessionRef session,
    CommandId commandId,
  ) async {
    final key = keyFor(session);
    var posts = 0;
    // Each step reads, may post once and records; the lock is released while
    // waiting, and every step starts again from the durable ledger.
    for (var step = 0; ; step++) {
      final result = await _queue.run(
        key,
        () => _reconcileStep(key, session, commandId),
      );
      if (result.posted) posts++;
      final retryAt = result.retryAt;
      final record = result.record;
      if (record == null) return OutboxReconciliation.refused(result.refusal!);
      if (retryAt == null || step >= 2 * maxReplays) {
        return OutboxReconciliation.recorded(record.entry, posts: posts);
      }
      final delay = retryAt.difference(_now().toUtc());
      // A clock set back since the replay must not park the caller.
      if (delay > replayBackoff.last) {
        return OutboxReconciliation.recorded(record.entry, posts: posts);
      }
      if (delay > Duration.zero) await _wait(delay);
    }
  }

  /// Fences replays of one entry. A fence is never cleared, and a settled one
  /// (`cancelled`, `settled`) never changes; [cancel] is the production
  /// writer.
  Future<bool> setCancellationFence(
    SessionRef session,
    CommandId commandId,
    CancellationFence fence,
  ) {
    final key = keyFor(session);
    return _queue.run(key, () async {
      final read = await _read(key, session);
      if (read == null) return false;
      final ledger = await _recover(key, session, read);
      final record = ledger.find(commandId);
      if (record == null ||
          (record.fence != CancellationFence.none &&
              (fence == CancellationFence.none || !_open(record.fence)))) {
        return false;
      }
      return _persist(
        key,
        session,
        ledger.replacing(
          record,
          record.copyWith(
            state: record.state,
            reason: record.reason,
            fence: fence,
            updatedAt: _now().toUtc(),
          ),
        ),
      );
    });
  }

  @override
  Future<OutboxMutation> cancel(SessionRef session, CommandId commandId) {
    final key = keyFor(session);
    return _queue.run(key, () async {
      final read = await _read(key, session);
      if (read == null) return const OutboxMutation.refused('unreadable');
      var ledger = await _recover(key, session, read);
      var record = ledger.find(commandId);
      if (record == null) return const OutboxMutation.refused('unknownCommand');
      if (record.connectedVersion != client.connectedVersion) {
        return const OutboxMutation.refused('versionChanged');
      }
      // Only input the server may still hold can be cancelled; a settled
      // cancel is not repeated.
      if ((record.state != SubmissionKind.admitted &&
              record.state != SubmissionKind.uncertain) ||
          (record.fence != CancellationFence.none && !_open(record.fence))) {
        return OutboxMutation.recorded(record.entry);
      }
      // The server holds another record under this id: deleting it would
      // remove input that is not this prompt.
      if (record.reason == 'identityOccupied') {
        return const OutboxMutation.refused('identityOccupied');
      }
      Future<bool> write(_Record next) async {
        if (!await _persist(key, session, ledger.replacing(record!, next))) {
          return false;
        }
        ledger = ledger.replacing(record!, next);
        record = next;
        return true;
      }

      _Record fenced(CancellationFence fence, [String? reason]) =>
          record!.copyWith(
            state: record!.state,
            reason: reason ?? record!.reason,
            fence: fence,
            updatedAt: _now().toUtc(),
          );
      // The fence is durable before anything reaches the wire.
      if (record!.fence == CancellationFence.none &&
          !await write(fenced(CancellationFence.requested))) {
        return const OutboxMutation.refused('notPersisted');
      }
      if (!await write(fenced(CancellationFence.submitting))) {
        return const OutboxMutation.refused('notPersisted');
      }
      final result = await client.cancelInbox(
        session: session,
        messageId: record!.messageId,
      );
      if (result case OpenCodeInboxNotSent(:final reason)) {
        await write(fenced(CancellationFence.requested, reason));
        return OutboxMutation.recorded(record!.entry);
      }
      // Whatever the status, a crash from here must not look settled.
      await write(fenced(CancellationFence.uncertain));
      await write(await _afterCancel(session, record!));
      return OutboxMutation.recorded(record!.entry);
    });
  }

  @override
  Future<OutboxMutation> switchDelivery(
    SessionRef session,
    CommandId commandId,
    Delivery delivery,
  ) {
    if (delivery != Delivery.steer && delivery != Delivery.queue) {
      return Future.value(const OutboxMutation.refused('unsupportedDelivery'));
    }
    final key = keyFor(session);
    return _queue.run(key, () async {
      final read = await _read(key, session);
      if (read == null) return const OutboxMutation.refused('unreadable');
      final ledger = await _recover(key, session, read);
      final record = ledger.find(commandId);
      if (record == null) return const OutboxMutation.refused('unknownCommand');
      if (record.connectedVersion != client.connectedVersion) {
        return const OutboxMutation.refused('versionChanged');
      }
      if (record.state != SubmissionKind.admitted) {
        return const OutboxMutation.refused('notPending');
      }
      if (record.fence != CancellationFence.none) {
        return const OutboxMutation.refused('cancellationFence');
      }
      if (record.delivery == delivery) {
        return OutboxMutation.recorded(record.entry);
      }
      final result = await client.switchInboxDelivery(
        session: session,
        messageId: record.messageId,
        delivery: delivery,
      );
      if (result case OpenCodeInboxNotSent(:final reason)) {
        return OutboxMutation.refused(reason);
      }
      _Record next(
        String? reason, {
        SubmissionKind state = SubmissionKind.admitted,
        Delivery? delivery,
        CancellationFence? fence,
      }) => record.copyWith(
        state: state,
        reason: reason,
        delivery: delivery,
        fence: fence,
        updatedAt: _now().toUtc(),
      );
      // The server decides; an admitted entry never becomes uncertain here,
      // where it could be replayed.
      final _Record after;
      try {
        after = switch (await reader.locatePrompt(
          session,
          record.messageId,
          sourceVersion: client.connectedVersion,
        )) {
          OpenCodePromptPending(:final text, delivery: final shown)
              when text == record.text =>
            next(
              shown == delivery.name
                  ? null
                  : switch (result) {
                      OpenCodeInboxRefused(:final error) => error.rawType,
                      _ => 'switchNotApplied',
                    },
              delivery: _delivery(shown) ?? record.delivery,
            ),
          OpenCodePromptPromoted() => next(
            null,
            state: SubmissionKind.delivered,
          ),
          // Admitted and now gone: another client cancelled it.
          OpenCodePromptAbsent() => next(
            null,
            state: SubmissionKind.cancelled,
            fence: CancellationFence.cancelled,
          ),
          OpenCodePromptIncomplete() => next('historyIncomplete'),
          OpenCodePromptPending() ||
          OpenCodePromptOccupied() => next('identityOccupied'),
        };
      } on OpenCodeSessionReadException catch (error) {
        final failed = next(error.failure.name);
        return OutboxMutation.recorded(
          await _persist(key, session, ledger.replacing(record, failed))
              ? failed.entry
              : record.entry,
        );
      }
      return OutboxMutation.recorded(
        await _persist(key, session, ledger.replacing(record, after))
            ? after.entry
            : record.entry,
      );
    });
  }

  /// A cancel was asked but its outcome is not known yet.
  static bool _open(CancellationFence fence) =>
      fence != CancellationFence.none &&
      fence != CancellationFence.cancelled &&
      fence != CancellationFence.settled;

  static Delivery? _delivery(String native) => switch (native) {
    'steer' => Delivery.steer,
    'queue' => Delivery.queue,
    _ => null,
  };

  /// What the server shows for a prompt whose cancel was asked; it is never
  /// sent again. Absence proves cancellation only for an admitted prompt:
  /// an unconfirmed one may still arrive, and a cancelled id would be
  /// re-enqueued by a repost.
  Future<_Record> _afterCancel(SessionRef session, _Record record) async {
    _Record next(
      String? reason, {
      SubmissionKind? state,
      Delivery? delivery,
      CancellationFence? fence,
    }) => record.copyWith(
      state: state ?? record.state,
      reason: reason,
      delivery: delivery,
      fence: fence,
      updatedAt: _now().toUtc(),
    );
    try {
      return switch (await reader.locatePrompt(
        session,
        record.messageId,
        sourceVersion: client.connectedVersion,
      )) {
        OpenCodePromptPending(:final text, :final delivery)
            when text == record.text =>
          next(
            'cancelPending',
            state: SubmissionKind.admitted,
            delivery: _delivery(delivery),
          ),
        OpenCodePromptPromoted() => next(
          null,
          state: SubmissionKind.delivered,
          fence: CancellationFence.settled,
        ),
        OpenCodePromptAbsent() when record.state == SubmissionKind.admitted =>
          next(
            null,
            state: SubmissionKind.cancelled,
            fence: CancellationFence.cancelled,
          ),
        OpenCodePromptAbsent() => next('cancellationFence'),
        OpenCodePromptIncomplete() => next('historyIncomplete'),
        OpenCodePromptPending() ||
        OpenCodePromptOccupied() => next('identityOccupied'),
      };
    } on OpenCodeSessionReadException catch (error) {
      return next(error.failure.name);
    }
  }

  Future<_Step> _reconcileStep(
    String key,
    SessionRef session,
    CommandId commandId,
  ) async {
    final read = await _read(key, session);
    if (read == null) return const _Step.refused('unreadable');
    final ledger = await _recover(key, session, read);
    final record = ledger.find(commandId);
    if (record == null) return const _Step.refused('unknownCommand');
    // Only an unknown admission or an unsettled cancel is checked; a known
    // outcome never regresses, and an entry recorded under another version
    // is left to the user.
    final cancelling =
        _open(record.fence) &&
        (record.state == SubmissionKind.uncertain ||
            record.state == SubmissionKind.admitted);
    if ((record.state != SubmissionKind.uncertain && !cancelling) ||
        record.connectedVersion != client.connectedVersion) {
      return _Step(record);
    }
    if (cancelling) {
      final next = await _afterCancel(session, record);
      return _Step(
        await _persist(key, session, ledger.replacing(record, next))
            ? next
            : record,
      );
    }
    Future<_Step> settle(SubmissionKind state, String? reason) async {
      final next = record.copyWith(
        state: state,
        reason: reason,
        updatedAt: _now().toUtc(),
      );
      // A failed write leaves the entry uncertain, never resolved.
      return _Step(
        await _persist(key, session, ledger.replacing(record, next))
            ? next
            : record,
      );
    }

    final OpenCodePromptLocation location;
    try {
      location = await reader.locatePrompt(
        session,
        record.messageId,
        sourceVersion: client.connectedVersion,
      );
    } on OpenCodeSessionReadException catch (error) {
      return settle(SubmissionKind.uncertain, error.failure.name);
    }
    switch (location) {
      // Another client may have switched the delivery since; the text and
      // the minted id still make it this prompt.
      case OpenCodePromptPending(:final text):
        return text == record.text
            ? settle(SubmissionKind.admitted, null)
            : settle(SubmissionKind.uncertain, 'identityOccupied');
      case OpenCodePromptPromoted():
        return settle(SubmissionKind.delivered, null);
      case OpenCodePromptOccupied():
        return settle(SubmissionKind.uncertain, 'identityOccupied');
      case OpenCodePromptIncomplete():
        return settle(SubmissionKind.uncertain, 'historyIncomplete');
      case OpenCodePromptAbsent():
        break;
    }
    if (record.fence != CancellationFence.none) {
      return settle(SubmissionKind.uncertain, 'cancellationFence');
    }
    if (record.replays >= maxReplays) {
      return settle(SubmissionKind.uncertain, 'replayExhausted');
    }
    final now = _now().toUtc();
    final notBefore = record.notBefore;
    if (notBefore != null && now.isBefore(notBefore)) {
      return _Step(record, retryAt: notBefore);
    }
    final OpenCodePromptReady ready;
    switch (client.prepare(
      session: session,
      commandId: record.commandId,
      messageId: record.messageId,
      draft: PromptDraft(text: record.text),
      delivery: record.delivery,
      resume: record.resume,
    )) {
      case OpenCodePromptRefused(:final attempt):
        return settle(
          SubmissionKind.uncertain,
          attempt.receipt.reason ?? 'unavailable',
        );
      case final OpenCodePromptReady prepared:
        ready = prepared;
    }
    final decision = _replayContract.evaluate(
      original: ready.command,
      candidate: ready.command,
      persistedOriginalPayload: record.payload,
      candidatePayload: ready.payload,
      admission: AdmissionKnowledge.unresolved,
      currentPhase: const OpenValue.known(OperationPhase.initial),
      cancellation: OpenValue.known(record.fence),
      reconciled: true,
    );
    if (!decision.allowed) {
      return settle(SubmissionKind.uncertain, decision.reason);
    }
    // The attempt is counted before the POST, so a crash cannot reset it.
    final sending = record.copyWith(
      state: SubmissionKind.sending,
      reason: null,
      replays: record.replays + 1,
      notBefore: now.add(replayBackoff[record.replays]),
      updatedAt: now,
    );
    if (!await _persist(key, session, ledger.replacing(record, sending))) {
      return settle(SubmissionKind.uncertain, 'notPersisted');
    }
    final attempt = await client.post(ready);
    final result = sending.copyWith(
      // Unlike a first send, nothing posted keeps the earlier uncertainty.
      state: attempt.posted
          ? attempt.submission!.kind.known!
          : SubmissionKind.uncertain,
      reason: attempt.receipt.error?.rawType ?? attempt.receipt.reason,
      updatedAt: _now().toUtc(),
    );
    // If this write fails the ledger keeps `sending`, read back as uncertain.
    await _persist(key, session, ledger.replacing(record, result));
    return _Step(
      result,
      posted: attempt.posted,
      retryAt:
          result.state == SubmissionKind.uncertain &&
              result.replays < maxReplays
          ? result.notBefore
          : null,
    );
  }

  /// Only an id proven absent from the inbox and the complete history is
  /// posted again: V2-005B observed such a same-id retry admit exactly one
  /// prompt on 2.0.22, while a cancelled id would be re-enqueued.
  OperationContract get _replayContract => OperationContract(
    harness: client.harness,
    operation: const OpenValue.known(MutationOperation.prompt),
    connectedVersion: client.connectedVersion,
    phase: const OpenValue.known(OperationPhase.initial),
    replay: ReplayPolicy.verifiedUnresolvedAdmission,
    evidence:
        'test/contract/fixtures/opencode/2.0.22/b/prompt-matrix.json: '
        'an id absent after a lost request is admitted once by its retry',
  );

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
final class _Step {
  const _Step(this.record, {this.posted = false, this.retryAt})
    : refusal = null;
  const _Step.refused(String this.refusal)
    : record = null,
      posted = false,
      retryAt = null;
  final _Record? record;
  final String? refusal;
  final bool posted;

  /// Set when the entry is still uncertain and may be replayed after it.
  final DateTime? retryAt;
}

final class _Ledger {
  const _Ledger(this.records, this.forgotten);
  static const maxForgotten = 256;
  final List<_Record> records;
  final List<String> forgotten;

  _Ledger adding(_Record record) => _Ledger([...records, record], forgotten);

  _Record? find(CommandId commandId) =>
      records.where((r) => r.commandId == commandId).firstOrNull;

  _Ledger replacing(_Record old, _Record next) => _Ledger([
    for (final r in records) identical(r, old) ? next : r,
  ], forgotten);

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
    this.replays = 0,
    this.fence = CancellationFence.none,
    this.notBefore,
  });

  factory _Record.fromJson(Object? value, SessionRef session) {
    final json = value! as Map<String, Object?>;
    final state = SubmissionKind.values.byName(json['state']! as String);
    if (state == SubmissionKind.draft) {
      throw const FormatException('A draft is never recorded.');
    }
    // Absent in ledgers written before replays existed.
    final replays = json['replays'] as int? ?? 0;
    if (replays < 0 || replays > OpenCodePromptOutbox.maxReplays) {
      throw const FormatException('Replay count out of range.');
    }
    final notBefore = json['notBefore'] as String?;
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
      replays: replays,
      fence: CancellationFence.values.byName(
        json['fence'] as String? ?? CancellationFence.none.name,
      ),
      notBefore: notBefore == null ? null : DateTime.parse(notBefore),
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
  final int replays;
  final CancellationFence fence;

  /// The earliest time of the next replay.
  final DateTime? notBefore;

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
    replays: replays,
    fence: fence,
  );

  /// [reason] is replaced, even by null; the replay fields and the delivery
  /// are kept unless given. The recorded payload never changes.
  _Record copyWith({
    required SubmissionKind state,
    required DateTime updatedAt,
    String? reason,
    int? replays,
    CancellationFence? fence,
    DateTime? notBefore,
    Delivery? delivery,
  }) => _Record(
    session: session,
    commandId: commandId,
    messageId: messageId,
    text: text,
    delivery: delivery ?? this.delivery,
    connectedVersion: connectedVersion,
    resume: resume,
    payload: payload,
    state: state,
    createdAt: createdAt,
    updatedAt: updatedAt,
    reason: reason,
    replays: replays ?? this.replays,
    fence: fence ?? this.fence,
    notBefore: notBefore ?? this.notBefore,
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
    'replays': replays,
    'fence': fence.name,
    'notBefore': ?notBefore?.toIso8601String(),
  };
}
