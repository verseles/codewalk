import 'dart:async';
import 'dart:convert';

import 'package:codewalk/shared/sessions/prompt_outbox.dart';
import 'package:codewalk_core/codewalk_core.dart';

/// Records every call; each answer can be scripted.
final class FakeOutbox implements PromptOutbox {
  final calls = <String>[];
  final list = <OutboxEntry>[];
  Object? entriesError;
  SubmissionKind submitState = SubmissionKind.admitted;
  String? submitReason;
  String? submitRefusal;
  Completer<void>? holdSubmit;
  Completer<void>? holdReconcile;
  Completer<void>? holdDismiss;
  OutboxEntry Function(OutboxEntry)? onReconcile;
  OutboxEntry Function(OutboxEntry)? onCancel;
  OutboxEntry Function(OutboxEntry, Delivery)? onSwitch;
  bool dismissOk = true;
  int _ids = 100;

  OutboxEntry _get(CommandId id) => list.singleWhere((e) => e.commandId == id);
  void _put(OutboxEntry entry) {
    list
      ..removeWhere((e) => e.commandId == entry.commandId)
      ..add(entry);
  }

  @override
  Future<OutboxSubmission> submit({
    required SessionRef session,
    required CommandId commandId,
    required PromptDraft draft,
    required Delivery delivery,
  }) async {
    calls.add('submit ${commandId.value} ${delivery.name} ${draft.text}');
    await holdSubmit?.future;
    if (submitRefusal case final refusal?) {
      return OutboxSubmission.refused(refusal);
    }
    final entry = entryOf(
      session,
      commandId.value,
      'msg_${(++_ids).toString().padLeft(4, '0')}',
      draft.text,
      delivery,
      submitState,
      reason: submitReason,
    );
    _put(entry);
    return OutboxSubmission.recorded(entry, sent: true);
  }

  @override
  Future<List<OutboxEntry>> entries(SessionRef session) async {
    if (entriesError case final error?) throw error;
    return List.of(list);
  }

  @override
  Future<bool> dismiss(SessionRef session, CommandId commandId) async {
    calls.add('dismiss ${commandId.value}');
    await holdDismiss?.future;
    if (dismissOk) list.removeWhere((e) => e.commandId == commandId);
    return dismissOk;
  }

  @override
  Future<OutboxReconciliation> reconcile(
    SessionRef session,
    CommandId commandId,
  ) async {
    calls.add('reconcile ${commandId.value}');
    await holdReconcile?.future;
    final next = (onReconcile ?? (e) => e)(_get(commandId));
    _put(next);
    return OutboxReconciliation.recorded(next, posts: 0);
  }

  @override
  Future<OutboxMutation> cancel(SessionRef session, CommandId commandId) async {
    calls.add('cancel ${commandId.value}');
    final next = (onCancel ?? (e) => e)(_get(commandId));
    _put(next);
    return OutboxMutation.recorded(next);
  }

  @override
  Future<OutboxMutation> switchDelivery(
    SessionRef session,
    CommandId commandId,
    Delivery delivery,
  ) async {
    calls.add('switch ${commandId.value} ${delivery.name}');
    final next = (onSwitch ?? (e, _) => e)(_get(commandId), delivery);
    _put(next);
    return OutboxMutation.recorded(next);
  }
}

OutboxEntry entryOf(
  SessionRef session,
  String command,
  String message,
  String text,
  Delivery delivery,
  SubmissionKind state, {
  String? reason,
  CancellationFence fence = CancellationFence.none,
}) => OutboxEntry(
  session: session,
  commandId: CommandId(command),
  messageId: message,
  text: text,
  delivery: delivery,
  state: state,
  createdAt: DateTime.utc(2026, 10, 15),
  updatedAt: DateTime.utc(2026, 10, 15),
  reason: reason,
  fence: fence,
);

/// A pending inbox row as the live projection shapes it.
PendingInput pendingRow(
  SessionRef ref,
  String message,
  String text, {
  Delivery delivery = Delivery.queue,
}) => PendingInput(
  id: ItemId(jsonEncode([ref.storageKey, message, 'user', 0])),
  text: text,
  delivery: OpenValue.known(delivery),
);
