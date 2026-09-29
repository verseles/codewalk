part of '../chat_provider.dart';

extension _ChatProviderErrorPolicy on ChatProvider {
  void _setState(ChatState newState) {
    _state = newState;
    _notifyListeners();
    _attemptPendingRemoteSelectionSync(reason: 'state-$newState');
  }

  void _setProvidersRefreshState(
    ChatProvidersRefreshState state, {
    String? errorMessage,
    bool notify = true,
  }) {
    final changed =
        _providersRefreshState != state ||
        _providersRefreshErrorMessage != errorMessage;
    _providersRefreshState = state;
    _providersRefreshErrorMessage = errorMessage;
    if (changed && notify) {
      _notifyListeners();
    }
  }

  void _setError(String message, {String? sessionId}) {
    final effectiveSessionId = sessionId ?? _currentSession?.id;
    if (_shouldSuppressAbortError(
      sessionId: effectiveSessionId,
      message: message,
    )) {
      AppLogger.info(
        'Suppressing expected abort error session=${effectiveSessionId ?? "-"} message=$message',
      );
      _errorMessage = null;
      _setState(ChatState.loaded);
      return;
    }
    _errorMessage = message;
    _setState(ChatState.error);
  }

  void _enqueueUiNotice({
    required ChatUiNoticeType type,
    required String message,
    String? actionLabel,
  }) {
    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return;
    }
    _pendingUiNotice = ChatUiNotice(
      id: DateTime.now().microsecondsSinceEpoch,
      type: type,
      message: normalizedMessage,
      actionLabel: actionLabel,
    );
  }

  void _presentServerErrorForCurrentSession({
    required String sessionId,
    required String rawMessage,
    String? code,
    int? statusCode,
  }) {
    if (_currentSession?.id != sessionId) {
      return;
    }
    final display = formatServerErrorForDisplay(
      rawMessage: rawMessage,
      code: code,
      statusCode: statusCode,
    );
    _sessionStatusById[sessionId] = const SessionStatusInfo(
      type: SessionStatusType.idle,
    );
    _clearSessionAttentionForSession(sessionId);
    _errorMessage = null;
    _markIncompleteAssistantMessagesAsCompleted(sessionId: sessionId);
    _appendInlineServerErrorMessage(sessionId: sessionId, error: display);
    _enqueueUiNotice(
      type: ChatUiNoticeType.serverError,
      message: display.message,
    );
    _setState(ChatState.loaded);
  }

  bool _isAbortSuppressionActiveForSession(String? sessionId) {
    if (sessionId == null ||
        _abortSuppressionSessionId == null ||
        _abortSuppressionStartedAt == null ||
        sessionId != _abortSuppressionSessionId) {
      return false;
    }
    final startedAt = _abortSuppressionStartedAt!;
    if (_abortSuppressionNow().difference(startedAt) > _abortSuppressionWindow) {
      _clearAbortSuppression();
      return false;
    }
    return true;
  }

  bool _isRemoteAbortError({required String message, String? code}) {
    final normalizedMessage = message.trim().toLowerCase();
    final normalizedCode = code?.trim().toLowerCase() ?? '';
    if (normalizedCode.contains('abort') || normalizedCode.contains('cancel')) {
      return true;
    }
    return isAbortLikeError(message: normalizedMessage);
  }

  bool _shouldSuppressAbortError({
    required String? sessionId,
    required String message,
    String? code,
  }) {
    if (!_isAbortSuppressionActiveForSession(sessionId)) {
      return false;
    }
    return _isRemoteAbortError(message: message, code: code) ||
        _isAbortLikeMessage(message);
  }
}
