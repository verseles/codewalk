part of '../chat_input_widget.dart';

extension _ChatInputStateMachine on _ChatInputWidgetState {
  Future<void> _handleSendMessage() async {
    if (!widget.enabled || _isSending) {
      return;
    }
    _setState(() {
      _isSending = true;
    });
    try {
      if (_isListening) {
        await _stopListening();
      }
      if (!mounted) {
        return;
      }
      final text = _controller.text.trim();
      final payloadText = _mode == ChatComposerMode.shell
          ? _normalizeShellPayload(text)
          : text;
      if (payloadText.isEmpty &&
          (_mode == ChatComposerMode.shell ||
              (_attachments.isEmpty && widget.contextItems.isEmpty))) {
        return;
      }

      final draftTextAtSendStart = _controller.text;
      final draftAttachmentsAtSendStart = List<FileInputPart>.unmodifiable(
        _attachments,
      );
      final draftModeAtSendStart = _mode;
      // Format file line references as inline text so the LLM sees the
      // selected code directly instead of receiving opaque file parts.
      final fullPayload = _buildPayloadWithContext(payloadText);

      await widget.onSendMessage(
        ChatInputSubmission(
          text: fullPayload,
          attachments: _mode == ChatComposerMode.shell
              ? const <FileInputPart>[]
              : List<FileInputPart>.unmodifiable(_attachments),
          mode: _mode,
        ),
      );
      if (!mounted) {
        return;
      }
      final draftChangedDuringSend =
          _controller.text != draftTextAtSendStart ||
          !listEquals(_attachments, draftAttachmentsAtSendStart) ||
          _mode != draftModeAtSendStart;

      if (!draftChangedDuringSend) {
        final shouldHideKeyboardAfterSend = _shouldHideKeyboardAfterSend;
        if (shouldHideKeyboardAfterSend) {
          _suppressEnsureInputFocus = true;
        }
        _controller.clear();
        _setState(() {
          _isComposing = false;
          _attachments.clear();
          _mode = ChatComposerMode.normal;
          _popoverType = ChatComposerPopoverType.none;
          _mentionSuggestions = <ChatComposerMentionSuggestion>[];
          _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
          _activeSuggestionIndex = 0;
        });
        _notifyDraftChanged();
        if (shouldHideKeyboardAfterSend) {
          _effectiveFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
          unawaited(
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
          );
        }
      } else {
        _setState(() {
          _isComposing = _controller.text.trim().isNotEmpty;
        });
        _notifyDraftChanged();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.msgFailedToSendMessage)),
      );
      _ensureInputFocus();
    } finally {
      if (mounted) {
        _setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _handleTextChanged(String text) {
    if (!_isApplyingHistoryValue) {
      _exitHistoryNavigation(updateDraft: true);
    }
    _refreshComposerMode(text);
    _scheduleSuggestionQuery();
    if (_popoverType != ChatComposerPopoverType.none &&
        _activeSuggestionIndex >= _activeSuggestionsCount) {
      _activeSuggestionIndex = _activeSuggestionsCount > 0
          ? _activeSuggestionsCount - 1
          : 0;
    }
    _setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
    _notifyDraftChanged();
    if (_suppressEnsureInputFocus) {
      _suppressEnsureInputFocus = false;
      return;
    }
    _ensureInputFocus();
  }

  String _normalizeShellPayload(String text) {
    final normalized = text.startsWith('!') ? text.substring(1) : text;
    return normalized.trim();
  }

  void _refreshComposerMode(String text) {
    final nextMode = text.startsWith('!')
        ? ChatComposerMode.shell
        : ChatComposerMode.normal;
    if (_mode == nextMode) {
      return;
    }
    _setState(() {
      _mode = nextMode;
    });
  }

  void _scheduleSuggestionQuery() {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 120),
      _refreshSuggestions,
    );
  }

  /// Build the final message text by appending file line references as
  /// fenced code blocks so the LLM receives the selected content inline.
  String _buildPayloadWithContext(String userText) {
    if (widget.contextItems.isEmpty) {
      return userText;
    }
    final buffer = StringBuffer(userText);
    for (final item in widget.contextItems) {
      final source = item.source;
      if (source == null) {
        continue;
      }
      final header = '${item.filename}:${source.text.start}-${source.text.end}';
      buffer.writeln();
      buffer.writeln();
      buffer.writeln('`$header`');
      buffer.writeln('```');
      buffer.writeln(source.text.value);
      buffer.write('```');
    }
    return buffer.toString();
  }

  Future<void> _refreshSuggestions() async {
    if (!mounted) {
      return;
    }

    final value = _controller.value;
    final text = value.text;
    final selectionOffset = value.selection.isValid
        ? value.selection.baseOffset
        : text.length;
    final safeOffset = selectionOffset.clamp(0, text.length).toInt();
    final prefix = text.substring(0, safeOffset);

    final mentionMatch = _mentionTriggerPattern.firstMatch(prefix);
    if (mentionMatch != null && widget.onMentionQuery != null) {
      final query = mentionMatch.group(2) ?? '';
      _activeMentionQuery = query;
      await _loadMentionSuggestions(query);
      return;
    }

    final slashMatch = _slashTriggerPattern.firstMatch(text.trim());
    if (slashMatch != null && widget.onSlashQuery != null) {
      final query = slashMatch.group(1) ?? '';
      _activeSlashQuery = query;
      await _loadSlashSuggestions(query);
      return;
    }

    if (!mounted) {
      return;
    }
    _setState(() {
      _popoverType = ChatComposerPopoverType.none;
      _mentionSuggestions = <ChatComposerMentionSuggestion>[];
      _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
      _activeSuggestionIndex = 0;
      _isLoadingSuggestions = false;
    });
    _ensureInputFocus();
  }
}
