part of '../chat_input_widget.dart';

extension _ChatInputSendController on _ChatInputWidgetState {
  bool get _canSendContinue =>
      widget.enabled &&
      !widget.isResponding &&
      !_isSending &&
      !_isListening &&
      !_isStartingListening &&
      _mode == ChatComposerMode.normal &&
      _controller.text.trim().isEmpty &&
      _attachments.isEmpty &&
      widget.contextItems.isEmpty;

  void _handleEmptySendDoubleTap() {
    if (!_canSendContinue) {
      return;
    }
    unawaited(_handleSendMessage(continueWhenEmpty: true));
  }

  void _handleSendButtonTap() {
    if (_holdSendTriggered) {
      _holdSendTriggered = false;
      return;
    }
    final lastSecondaryAction = _lastSecondarySendActionAt;
    if (lastSecondaryAction != null &&
        DateTime.now().difference(lastSecondaryAction) <
            const Duration(milliseconds: 500)) {
      return;
    }
    unawaited(_handleSendMessage());
  }

  void _handleSendButtonPressStart({required bool canSend}) {
    if (!canSend || _isSending) {
      return;
    }
    _holdSendTriggered = false;
    _sendHoldTimer?.cancel();
    _sendHoldTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      _holdSendTriggered = true;
      _lastSecondarySendActionAt = DateTime.now();
      _insertComposerNewline();
    });
  }

  void _handleSendButtonPressEnd() {
    _sendHoldTimer?.cancel();
    _sendHoldTimer = null;
  }

  void _insertComposerNewline() {
    if (!widget.enabled || _isSending) {
      return;
    }

    final current = _controller.value;
    final text = current.text;
    final selection = current.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final from = start <= end ? start : end;
    final to = start <= end ? end : start;
    final safeFrom = from.clamp(0, text.length).toInt();
    final safeTo = to.clamp(0, text.length).toInt();
    final nextText = text.replaceRange(safeFrom, safeTo, '\n');
    final nextOffset = safeFrom + 1;

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    _effectiveFocusNode.requestFocus();

    _setState(() {
      _isComposing = nextText.trim().isNotEmpty;
    });
  }
}
