import 'package:dio/dio.dart';

import '../../../data/car_messaging/car_messaging_store.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../domain/entities/car_messaging.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/entities/session_attention_overlay/session_attention_models.dart';
import '../../services/tts/read_aloud_text_extractor.dart';
import 'car_messaging_notification.dart';

class CarMessagingDispatchResult {
  const CarMessagingDispatchResult({
    this.pending = false,
    this.notifiedSessionIds = const <String>{},
  });

  final bool pending;
  final Set<String> notifiedSessionIds;
}

enum CarMessagingCompletionResult { published, notHandled }

class CarMessagingDispatchWorker {
  CarMessagingDispatchWorker({
    required Dio dio,
    required String serverId,
    CarMessagingStore? store,
    CarMessagingNotifier? notifier,
    DateTime Function()? now,
    bool Function()? gateOpen,
  }) : _dio = dio,
       _serverId = serverId.trim(),
       _store = store ?? CarMessagingStore(),
       _notifier = notifier ?? CarMessagingNotifier(),
       _now = now ?? DateTime.now,
       _gateOpen = gateOpen;

  final Dio _dio;
  final String _serverId;
  final CarMessagingStore _store;
  final CarMessagingNotifier _notifier;
  final DateTime Function() _now;
  final bool Function()? _gateOpen;

  bool get _gateIsOpen => _gateOpen?.call() ?? true;

  Future<CarMessagingDispatchResult> processReplies(
    Map<String, String> statusById, {
    String? replyId,
  }) async {
    if (!_gateIsOpen) return const CarMessagingDispatchResult();
    final initial = await _store.read();
    var pending = false;
    final notified = <String>{};
    for (final reply in initial.replies.where(
      (reply) =>
          reply.identity.serverId == _serverId &&
          (replyId == null || reply.id == replyId),
    )) {
      if (!_gateIsOpen) {
        pending = true;
        continue;
      }
      var current = reply;
      if (current.state == CarMessagingReplyState.failed) continue;
      if (current.state == CarMessagingReplyState.queued) {
        final claimed = await _store.claimReply(
          replyId: current.id,
          from: CarMessagingReplyState.queued,
          to: CarMessagingReplyState.sending,
        );
        if (claimed == null) {
          continue;
        }
        current = claimed;
        try {
          final response = await _dio.post(
            '/session/${current.identity.rootSessionId}/prompt_async',
            queryParameters: <String, dynamic>{
              'directory': current.identity.directory,
            },
            data: <String, dynamic>{
              'parts': <Map<String, dynamic>>[
                <String, dynamic>{'type': 'text', 'text': current.text},
              ],
            },
          );
          if (response.statusCode != 200 && response.statusCode != 204) {
            await _failReply(current);
            continue;
          }
          await _store.updateReply(
            CarMessagingReply(
              id: current.id,
              identity: current.identity,
              text: current.text,
              createdAtEpochMs: current.createdAtEpochMs,
              state: CarMessagingReplyState.awaitingFinal,
              attempts: current.attempts,
              baselineAssistantMessageId: current.baselineAssistantMessageId,
            ),
          );
          current = CarMessagingReply(
            id: current.id,
            identity: current.identity,
            text: current.text,
            createdAtEpochMs: current.createdAtEpochMs,
            state: CarMessagingReplyState.awaitingFinal,
            attempts: current.attempts,
            baselineAssistantMessageId: current.baselineAssistantMessageId,
          );
        } on DioException catch (error) {
          final wasProvablyNotSent =
              error.response == null &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.badCertificate);
          if (error.response != null) {
            await _failReply(current);
            continue;
          }
          if (wasProvablyNotSent && current.attempts < 3) {
            await _store.updateReply(
              CarMessagingReply(
                id: current.id,
                identity: current.identity,
                text: current.text,
                createdAtEpochMs: current.createdAtEpochMs,
                state: CarMessagingReplyState.queued,
                attempts: current.attempts,
                baselineAssistantMessageId: current.baselineAssistantMessageId,
              ),
            );
          } else if (wasProvablyNotSent) {
            await _failReply(current);
            continue;
          }
          // Timeouts without a server response are ambiguous: the request may
          // have been dispatched. Fail closed and reconcile the tail instead.
          pending = true;
          continue;
        } catch (_) {
          await _failReply(current);
          continue;
        }
      }
      if (current.state == CarMessagingReplyState.sending ||
          current.state == CarMessagingReplyState.awaitingFinal) {
        final status = statusById[current.identity.rootSessionId];
        if (status == 'busy' || status == 'retry') {
          pending = true;
          continue;
        }
        final fetched = await _fetchNewFinal(current);
        if (fetched == null) {
          pending = true;
          continue;
        }
        final state = await _store.read();
        final existing = state.threads
            .where((thread) => thread.identity == current.identity)
            .firstOrNull;
        final lastAgentId = existing?.entries
            .where((entry) => entry.role == CarMessagingRole.agent)
            .map((entry) => entry.messageId)
            .whereType<String>()
            .lastOrNull;
        if (lastAgentId == fetched.id) {
          await _store.removeReply(current.id);
          notified.add(current.identity.rootSessionId);
          continue;
        }
        if (!_gateIsOpen) {
          pending = true;
          continue;
        }
        final appended = await _appendAgentMessage(
          identityKey: current.identity.key,
          message: fetched,
        );
        if (!appended) {
          pending = true;
          continue;
        }
        await _store.removeReply(current.id);
        notified.add(current.identity.rootSessionId);
      }
    }
    return CarMessagingDispatchResult(
      pending: pending,
      notifiedSessionIds: notified,
    );
  }

  Future<CarMessagingCompletionResult> publishCompletion({
    required String sessionId,
    required String directory,
    required String title,
  }) async {
    if (!_gateIsOpen) return CarMessagingCompletionResult.notHandled;
    final state = await _store.read();
    final identity = SessionAttentionIdentity(
      serverId: _serverId,
      directory: directory,
      rootSessionId: sessionId,
    ).normalized();
    final identityKey = identity.key;
    final existing = state.threads
        .where((thread) => thread.identity.key == identityKey)
        .firstOrNull;
    final baseline = existing?.entries
        .where((entry) => entry.role == CarMessagingRole.agent)
        .map((entry) => entry.messageId)
        .whereType<String>()
        .lastOrNull;
    final message = await _fetchLatestFinal(
      sessionId: sessionId,
      directory: directory,
    );
    if (message == null) return CarMessagingCompletionResult.notHandled;
    if (baseline != null && baseline == message.id) {
      return CarMessagingCompletionResult.notHandled;
    }
    final lastAgentId = existing?.entries
        .where((entry) => entry.role == CarMessagingRole.agent)
        .map((entry) => entry.messageId)
        .whereType<String>()
        .lastOrNull;
    if (lastAgentId == message.id) {
      return CarMessagingCompletionResult.notHandled;
    }
    if (!_gateIsOpen) return CarMessagingCompletionResult.notHandled;
    final appended = await _appendAgentMessage(
      identityKey: identityKey,
      message: message,
      fallbackTitle: title,
      fallbackIdentity: identity,
    );
    return appended
        ? CarMessagingCompletionResult.published
        : CarMessagingCompletionResult.notHandled;
  }

  Future<void> _failReply(CarMessagingReply reply) async {
    await _store.updateReply(
      CarMessagingReply(
        id: reply.id,
        identity: reply.identity,
        text: reply.text,
        createdAtEpochMs: reply.createdAtEpochMs,
        state: CarMessagingReplyState.failed,
        attempts: reply.attempts,
        baselineAssistantMessageId: reply.baselineAssistantMessageId,
      ),
    );
    await _notifier.showDeliveryFailure(identity: reply.identity);
    await _store.removeReply(reply.id);
  }

  Future<ChatMessageModel?> _fetchNewFinal(CarMessagingReply reply) {
    return _fetchLatestFinal(
      sessionId: reply.identity.rootSessionId,
      directory: reply.identity.directory,
      baselineAssistantMessageId: reply.baselineAssistantMessageId,
      notBeforeEpochMs: reply.createdAtEpochMs,
    );
  }

  Future<ChatMessageModel?> _fetchLatestFinal({
    required String sessionId,
    required String directory,
    String? baselineAssistantMessageId,
    int? notBeforeEpochMs,
  }) async {
    try {
      final response = await _dio.get(
        '/session/$sessionId/message',
        queryParameters: <String, dynamic>{'directory': directory, 'limit': 20},
      );
      if (response.statusCode != 200 || response.data is! List) return null;
      final all =
          (response.data as List)
              .whereType<Map>()
              .map((raw) {
                final envelope = Map<String, dynamic>.from(raw);
                final info = Map<String, dynamic>.from(
                  envelope['info'] as Map? ?? const {},
                );
                final parts = List<dynamic>.from(
                  envelope['parts'] as List? ?? const [],
                );
                return ChatMessageModel.fromJson(<String, dynamic>{
                  ...info,
                  'parts': parts,
                });
              })
              .toList(growable: false)
            ..sort((left, right) => left.time.compareTo(right.time));
      var baselineIndex = -1;
      for (var index = 0; index < all.length; index += 1) {
        if (all[index].id == baselineAssistantMessageId) {
          baselineIndex = index;
          break;
        }
      }
      if (baselineAssistantMessageId != null && baselineIndex < 0) {
        return null;
      }
      final startIndex = baselineAssistantMessageId == null
          ? 0
          : baselineIndex + 1;
      for (var index = all.length - 1; index >= startIndex; index -= 1) {
        final message = all[index];
        if (message.sessionId == sessionId &&
            message.role == 'assistant' &&
            message.completedTime != null &&
            (notBeforeEpochMs == null ||
                message.completedTime!.millisecondsSinceEpoch >=
                    notBeforeEpochMs)) {
          return message;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _appendAgentMessage({
    required String identityKey,
    required ChatMessageModel message,
    String? fallbackTitle,
    SessionAttentionIdentity? fallbackIdentity,
  }) async {
    final state = await _store.read();
    final existing = state.threads
        .where((thread) => thread.identity.key == identityKey)
        .firstOrNull;
    if (existing == null && fallbackTitle == null) return false;
    final domainMessage = message.toDomain();
    if (domainMessage is! AssistantMessage) return false;
    final text = ReadAloudTextExtractor.extract(domainMessage).trim();
    if (text.isEmpty) return false;
    final identity = existing?.identity ?? fallbackIdentity;
    if (identity == null) return false;
    if (existing?.entries.any((entry) => entry.messageId == message.id) ==
        true) {
      return true;
    }
    final thread = CarMessagingThread(
      identity: identity,
      title: existing?.title ?? fallbackTitle ?? 'CodeWalk',
      entries: <CarMessagingEntry>[
        ...?existing?.entries,
        CarMessagingEntry(
          role: CarMessagingRole.agent,
          text: text,
          timestampEpochMs:
              message.completedTime?.millisecondsSinceEpoch ??
              _now().millisecondsSinceEpoch,
          messageId: message.id,
        ),
      ],
      updatedAtEpochMs: _now().millisecondsSinceEpoch,
      unread: true,
    );
    await _store.upsertThread(thread);
    await _notifier.show(thread);
    return true;
  }
}
