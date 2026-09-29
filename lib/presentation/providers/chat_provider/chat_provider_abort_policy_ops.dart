part of '../chat_provider.dart';

extension _ChatProviderAbortPolicyOps on ChatProvider {
  bool _isAbortLikeMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return isAbortLikeError(message: message) ||
        normalized.contains('retry') ||
        normalized.contains('cancelled by user') ||
        normalized.contains('canceled by user');
  }

  void _startAbortSuppression(String sessionId) {
    _abortSuppressionSessionId = sessionId;
    _abortSuppressionStartedAt = _abortSuppressionNow();
  }

  void _clearAbortSuppression() {
    _abortSuppressionSessionId = null;
    _abortSuppressionStartedAt = null;
  }

  void _appendInlineAbortMessage({required String sessionId}) {
    AppLogger.info(
      'appendInlineAbortMessage session=$sessionId isCurrent=${_currentSession?.id == sessionId}',
    );
    if (_currentSession?.id != sessionId) {
      return;
    }

    final lastMessage = _messages.lastOrNull;
    if (lastMessage is AssistantMessage) {
      final lastError = lastMessage.error;
      if (lastError != null &&
          lastError.name == ChatProvider._remoteAbortInlineErrorName &&
          lastError.message == ChatProvider._remoteAbortNoticeMessage) {
        return;
      }
    }

    final now = DateTime.now();
    final messageId = 'msg_inline_abort_${now.microsecondsSinceEpoch}';
    _messages.add(
      AssistantMessage(
        id: messageId,
        sessionId: sessionId,
        time: now,
        completedTime: now,
        parts: const <MessagePart>[],
        error: const MessageError(
          name: ChatProvider._remoteAbortInlineErrorName,
          message: ChatProvider._remoteAbortNoticeMessage,
        ),
      ),
    );
    _messagesVersion++;
  }

  void _appendInlineServerErrorMessage({
    required String sessionId,
    required ChatServerErrorDisplay error,
  }) {
    if (_currentSession?.id != sessionId) {
      return;
    }

    final lastMessage = _messages.lastOrNull;
    if (lastMessage is AssistantMessage) {
      final lastError = lastMessage.error;
      if (lastError != null &&
          lastError.name == error.name &&
          lastError.message == error.message) {
        return;
      }
    }

    final now = DateTime.now();
    final messageId = 'msg_inline_server_error_${now.microsecondsSinceEpoch}';
    _messages.add(
      AssistantMessage(
        id: messageId,
        sessionId: sessionId,
        time: now,
        completedTime: now,
        parts: const <MessagePart>[],
        error: MessageError(name: error.name, message: error.message),
      ),
    );
    _messagesVersion++;
  }
}
