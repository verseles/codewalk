import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../domain/entities/chat_session.dart';

enum ChatComposerMode { normal, shell }

enum ChatComposerSuggestionType { file, agent }

enum ChatComposerPopoverType { none, mention, slash }

class ChatInputController {
  _ChatInputWidgetState? _state;

  bool get canOpenAttachmentOptions =>
      _state?._canOpenAttachmentOptions ?? false;

  void openAttachmentOptions() {
    _state?._openAttachmentOptionsFromExternal();
  }

  void _attach(_ChatInputWidgetState state) {
    _state = state;
  }

  void _detach(_ChatInputWidgetState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }
}

class ChatInputSubmission {
  const ChatInputSubmission({
    required this.text,
    required this.attachments,
    required this.mode,
  });

  final String text;
  final List<FileInputPart> attachments;
  final ChatComposerMode mode;
}

class ChatComposerMentionSuggestion {
  const ChatComposerMentionSuggestion({
    required this.value,
    required this.type,
    this.subtitle,
  });

  final String value;
  final ChatComposerSuggestionType type;
  final String? subtitle;
}

class ChatComposerSlashCommandSuggestion {
  const ChatComposerSlashCommandSuggestion({
    required this.name,
    required this.source,
    this.description,
    this.isBuiltin = false,
  });

  final String name;
  final String source;
  final String? description;
  final bool isBuiltin;
}

@visibleForTesting
Color microphoneButtonBackgroundColor({
  required bool isListening,
  required ColorScheme colorScheme,
}) {
  return isListening ? colorScheme.error : colorScheme.secondaryContainer;
}

@visibleForTesting
Color microphoneButtonForegroundColor({
  required bool isListening,
  required ColorScheme colorScheme,
}) {
  return isListening ? colorScheme.onError : colorScheme.onSecondaryContainer;
}

/// Chat input widget
class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.onSendMessage,
    this.sentMessageHistory = const <String>[],
    this.prefilledText,
    this.prefilledTextVersion = 0,
    this.onMentionQuery,
    this.onSlashQuery,
    this.onBuiltinSlashCommand,
    this.enabled = true,
    this.isResponding = false,
    this.onStopRequested,
    this.focusNode,
    this.showAttachmentButton = false,
    this.showInlineAttachmentButton = true,
    this.allowImageAttachment = true,
    this.allowPdfAttachment = true,
    this.controller,
  });

  final FutureOr<void> Function(ChatInputSubmission submission) onSendMessage;
  final List<String> sentMessageHistory;
  final String? prefilledText;
  final int prefilledTextVersion;
  final Future<List<ChatComposerMentionSuggestion>> Function(String query)?
  onMentionQuery;
  final Future<List<ChatComposerSlashCommandSuggestion>> Function(String query)?
  onSlashQuery;
  final FutureOr<bool> Function(String commandName)? onBuiltinSlashCommand;
  final bool enabled;
  final bool isResponding;
  final FutureOr<void> Function()? onStopRequested;
  final FocusNode? focusNode;
  final bool showAttachmentButton;
  final bool showInlineAttachmentButton;
  final bool allowImageAttachment;
  final bool allowPdfAttachment;
  final ChatInputController? controller;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  static const double _inputRowHeight = 52;
  static const double _popoverInputHeightMultiplier = 3;
  static const int _composerMaxLines = 6;
  static const double _composerActionButtonSize = 42;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  final List<FileInputPart> _attachments = <FileInputPart>[];
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final RegExp _mentionTriggerPattern = RegExp(r'(^|\s)@([^\s@]*)$');
  final RegExp _slashTriggerPattern = RegExp(r'^/(\S*)$');
  final RegExp _mentionTokenPattern = RegExp(r'@([^\s@]+)');
  bool _isComposing = false;
  bool _isSending = false;
  bool _isListening = false;
  bool _isInitializingSpeech = false;
  bool _isSpeechEnabled = false;
  bool _isLoadingSuggestions = false;
  ChatComposerMode _mode = ChatComposerMode.normal;
  ChatComposerPopoverType _popoverType = ChatComposerPopoverType.none;
  List<ChatComposerMentionSuggestion> _mentionSuggestions =
      <ChatComposerMentionSuggestion>[];
  List<ChatComposerSlashCommandSuggestion> _slashSuggestions =
      <ChatComposerSlashCommandSuggestion>[];
  int _activeSuggestionIndex = 0;
  String _activeMentionQuery = '';
  String _activeSlashQuery = '';
  String _speechPrefix = '';
  Timer? _sendHoldTimer;
  Timer? _suggestionDebounce;
  DateTime? _lastSecondarySendActionAt;
  bool _holdSendTriggered = false;
  int? _historyIndexFromNewest;
  TextEditingValue? _historyDraftValue;
  bool _isApplyingHistoryValue = false;
  bool _suppressEnsureInputFocus = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  bool get _isDesktopPlatform {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  bool get _shouldHideKeyboardAfterSend => !_isDesktopPlatform;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    unawaited(_initializeSpeech());
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _sendHoldTimer?.cancel();
    _suggestionDebounce?.cancel();
    unawaited(_speechToText.stop());
    _controller.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.prefilledTextVersion != oldWidget.prefilledTextVersion) {
      final prefilledText = widget.prefilledText?.trim();
      if (prefilledText != null && prefilledText.isNotEmpty) {
        _exitHistoryNavigation(updateDraft: false);
        _historyDraftValue = null;
        _suppressEnsureInputFocus = true;
        _applyHistoryMessage(prefilledText);
      }
    }
    if (!listEquals(oldWidget.sentMessageHistory, widget.sentMessageHistory)) {
      _exitHistoryNavigation(updateDraft: false);
      _historyDraftValue = null;
    }
    if (!widget.showAttachmentButton && _attachments.isNotEmpty) {
      setState(() {
        _attachments.clear();
      });
      return;
    }

    if (_attachments.isEmpty) {
      return;
    }

    final filtered = _attachments
        .where((attachment) => _isMimeAllowed(attachment.mime))
        .toList(growable: false);
    if (filtered.length != _attachments.length) {
      setState(() {
        _attachments
          ..clear()
          ..addAll(filtered);
      });
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _controller.text.trim();
    final payloadText = _mode == ChatComposerMode.shell
        ? _normalizeShellPayload(text)
        : text;
    if (!widget.enabled || _isSending || widget.isResponding) {
      return;
    }
    if (payloadText.isEmpty &&
        (_mode == ChatComposerMode.shell || _attachments.isEmpty)) {
      return;
    }
    if (_isListening) {
      await _stopListening();
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendMessage(
        ChatInputSubmission(
          text: payloadText,
          attachments: _mode == ChatComposerMode.shell
              ? const <FileInputPart>[]
              : List<FileInputPart>.unmodifiable(_attachments),
          mode: _mode,
        ),
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      setState(() {
        _isComposing = false;
        _attachments.clear();
        _mode = ChatComposerMode.normal;
        _popoverType = ChatComposerPopoverType.none;
        _mentionSuggestions = <ChatComposerMentionSuggestion>[];
        _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
        _activeSuggestionIndex = 0;
      });
      if (_shouldHideKeyboardAfterSend) {
        _effectiveFocusNode.unfocus();
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to attach files: $error')));
    } finally {
      if (mounted) {
        setState(() {
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
    setState(() {
      _isComposing = text.trim().isNotEmpty;
    });
    if (_suppressEnsureInputFocus) {
      _suppressEnsureInputFocus = false;
      return;
    }
    _ensureInputFocus();
  }

  void _ensureInputFocus() {
    if (!widget.enabled) {
      return;
    }
    if (!_effectiveFocusNode.hasFocus) {
      _effectiveFocusNode.requestFocus();
    }
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
    setState(() {
      _mode = nextMode;
    });
  }

  int get _activeSuggestionsCount {
    switch (_popoverType) {
      case ChatComposerPopoverType.mention:
        return _mentionSuggestions.length;
      case ChatComposerPopoverType.slash:
        return _slashSuggestions.length;
      case ChatComposerPopoverType.none:
        return 0;
    }
  }

  void _scheduleSuggestionQuery() {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(
      const Duration(milliseconds: 120),
      _refreshSuggestions,
    );
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
    setState(() {
      _popoverType = ChatComposerPopoverType.none;
      _mentionSuggestions = <ChatComposerMentionSuggestion>[];
      _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
      _activeSuggestionIndex = 0;
      _isLoadingSuggestions = false;
    });
    _ensureInputFocus();
  }

  Future<void> _loadMentionSuggestions(String query) async {
    final loader = widget.onMentionQuery;
    if (loader == null) {
      return;
    }
    setState(() {
      _isLoadingSuggestions = true;
      _popoverType = ChatComposerPopoverType.mention;
    });
    try {
      final suggestions = await loader(query);
      if (!mounted || query != _activeMentionQuery) {
        return;
      }
      setState(() {
        _mentionSuggestions = suggestions;
        _activeSuggestionIndex = 0;
        _popoverType = suggestions.isEmpty
            ? ChatComposerPopoverType.none
            : ChatComposerPopoverType.mention;
      });
      _ensureInputFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
        _ensureInputFocus();
      }
    }
  }

  Future<void> _loadSlashSuggestions(String query) async {
    final loader = widget.onSlashQuery;
    if (loader == null) {
      return;
    }
    setState(() {
      _isLoadingSuggestions = true;
      _popoverType = ChatComposerPopoverType.slash;
    });
    try {
      final suggestions = await loader(query);
      if (!mounted || query != _activeSlashQuery) {
        return;
      }
      setState(() {
        _slashSuggestions = suggestions;
        _activeSuggestionIndex = 0;
        _popoverType = suggestions.isEmpty
            ? ChatComposerPopoverType.none
            : ChatComposerPopoverType.slash;
      });
      _ensureInputFocus();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
        _ensureInputFocus();
      }
    }
  }

  KeyEventResult _handleInputKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final logicalKey = event.logicalKey;
    final hasPopover = _popoverType != ChatComposerPopoverType.none;

    if (hasPopover && _activeSuggestionsCount > 0) {
      if (logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _activeSuggestionIndex =
              (_activeSuggestionIndex + 1) % _activeSuggestionsCount;
        });
        return KeyEventResult.handled;
      }

      if (logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _activeSuggestionIndex =
              (_activeSuggestionIndex - 1 + _activeSuggestionsCount) %
              _activeSuggestionsCount;
        });
        return KeyEventResult.handled;
      }

      if (logicalKey == LogicalKeyboardKey.enter ||
          logicalKey == LogicalKeyboardKey.tab) {
        unawaited(_applyActiveSuggestion());
        return KeyEventResult.handled;
      }
    }

    if (logicalKey == LogicalKeyboardKey.escape) {
      if (hasPopover) {
        _closePopover();
        return KeyEventResult.handled;
      }
      if (_mode == ChatComposerMode.shell) {
        setState(() {
          _mode = ChatComposerMode.normal;
          _controller.clear();
          _isComposing = false;
        });
        return KeyEventResult.handled;
      }
    }

    if (logicalKey == LogicalKeyboardKey.backspace &&
        _mode == ChatComposerMode.shell) {
      final normalized = _normalizeShellPayload(_controller.text);
      if (normalized.isEmpty) {
        setState(() {
          _mode = ChatComposerMode.normal;
          _controller.clear();
          _isComposing = false;
        });
        return KeyEventResult.handled;
      }
    }

    if (hasPopover) {
      return KeyEventResult.ignored;
    }

    if (_isDesktopPlatform && logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_navigateHistoryUp()) {
        return KeyEventResult.handled;
      }
    }

    if (_isDesktopPlatform && logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_navigateHistoryDown()) {
        return KeyEventResult.handled;
      }
    }

    if (_isDesktopPlatform && logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _insertComposerNewline();
        return KeyEventResult.handled;
      }
      unawaited(_handleSendMessage());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _navigateHistoryUp() {
    final history = widget.sentMessageHistory;
    if (history.isEmpty) {
      return false;
    }

    if (_historyIndexFromNewest == null) {
      _historyDraftValue = _controller.value;
      _historyIndexFromNewest = 0;
      _applyHistoryMessage(history.last, caretAtStart: false);
      return true;
    }

    final selectionOffset = _safeSelectionOffset(_controller.value);
    if (selectionOffset > 0) {
      _moveCaretToBoundary(atStart: true);
      return true;
    }

    final nextIndex = _historyIndexFromNewest! + 1;
    if (nextIndex >= history.length) {
      return true;
    }
    _historyIndexFromNewest = nextIndex;
    _applyHistoryMessage(history[history.length - 1 - nextIndex]);
    return true;
  }

  bool _navigateHistoryDown() {
    if (_historyIndexFromNewest == null) {
      return false;
    }

    final selectionOffset = _safeSelectionOffset(_controller.value);
    final textLength = _controller.text.length;
    if (selectionOffset < textLength) {
      _moveCaretToBoundary(atStart: false);
      return true;
    }

    final currentIndex = _historyIndexFromNewest!;
    if (currentIndex == 0) {
      final draft = _historyDraftValue;
      _exitHistoryNavigation(updateDraft: false);
      if (draft != null) {
        _applyTextValue(draft);
      }
      return true;
    }

    final nextIndex = currentIndex - 1;
    final history = widget.sentMessageHistory;
    if (nextIndex >= history.length) {
      return true;
    }
    _historyIndexFromNewest = nextIndex;
    _applyHistoryMessage(history[history.length - 1 - nextIndex]);
    return true;
  }

  int _safeSelectionOffset(TextEditingValue value) {
    final length = value.text.length;
    if (!value.selection.isValid) {
      return length;
    }
    return value.selection.baseOffset.clamp(0, length).toInt();
  }

  void _moveCaretToBoundary({required bool atStart}) {
    final length = _controller.text.length;
    _controller.value = _controller.value.copyWith(
      selection: TextSelection.collapsed(offset: atStart ? 0 : length),
      composing: TextRange.empty,
    );
  }

  void _applyHistoryMessage(String text, {bool caretAtStart = false}) {
    _applyTextValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: caretAtStart ? 0 : text.length,
        ),
      ),
    );
  }

  void _applyTextValue(TextEditingValue value) {
    _isApplyingHistoryValue = true;
    _controller.value = value.copyWith(composing: TextRange.empty);
    _handleTextChanged(value.text);
    _isApplyingHistoryValue = false;
  }

  void _exitHistoryNavigation({required bool updateDraft}) {
    if (_historyIndexFromNewest == null && _historyDraftValue == null) {
      return;
    }
    if (updateDraft) {
      _historyDraftValue = _controller.value;
    }
    _historyIndexFromNewest = null;
  }

  Future<void> _applyActiveSuggestion() async {
    if (!mounted || _activeSuggestionsCount == 0) {
      return;
    }

    switch (_popoverType) {
      case ChatComposerPopoverType.mention:
        final suggestion = _mentionSuggestions[_activeSuggestionIndex];
        _applyMentionSuggestion(suggestion);
        return;
      case ChatComposerPopoverType.slash:
        final suggestion = _slashSuggestions[_activeSuggestionIndex];
        await _applySlashSuggestion(suggestion);
        return;
      case ChatComposerPopoverType.none:
        return;
    }
  }

  void _applyMentionSuggestion(ChatComposerMentionSuggestion suggestion) {
    final value = _controller.value;
    final text = value.text;
    final selectionOffset = value.selection.isValid
        ? value.selection.baseOffset
        : text.length;
    final safeOffset = selectionOffset.clamp(0, text.length).toInt();
    final prefix = text.substring(0, safeOffset);
    final match = _mentionTriggerPattern.firstMatch(prefix);
    if (match == null) {
      return;
    }
    final fullMatch = match.group(0) ?? '';
    final mentionStart = safeOffset - fullMatch.length;
    final replacementPrefix = '${match.group(1) ?? ''}@${suggestion.value} ';
    final suffix = text.substring(safeOffset).replaceFirst(RegExp(r'^\s+'), '');
    final nextText =
        '${text.substring(0, mentionStart)}$replacementPrefix$suffix';
    final nextOffset = mentionStart + replacementPrefix.length;

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );

    setState(() {
      _isComposing = nextText.trim().isNotEmpty;
      _popoverType = ChatComposerPopoverType.none;
      _mentionSuggestions = <ChatComposerMentionSuggestion>[];
      _activeSuggestionIndex = 0;
    });
    _effectiveFocusNode.requestFocus();
  }

  Future<void> _applySlashSuggestion(
    ChatComposerSlashCommandSuggestion suggestion,
  ) async {
    if (suggestion.isBuiltin && widget.onBuiltinSlashCommand != null) {
      final handled = await widget.onBuiltinSlashCommand!(suggestion.name);
      if (handled) {
        setState(() {
          _popoverType = ChatComposerPopoverType.none;
          _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
          _activeSuggestionIndex = 0;
          _controller.clear();
          _isComposing = false;
        });
        return;
      }
    }

    final replacement = '/${suggestion.name} ';
    _controller.value = TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: replacement.length),
    );
    setState(() {
      _isComposing = replacement.trim().isNotEmpty;
      _popoverType = ChatComposerPopoverType.none;
      _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
      _activeSuggestionIndex = 0;
    });
    _effectiveFocusNode.requestFocus();
  }

  void _closePopover() {
    setState(() {
      _popoverType = ChatComposerPopoverType.none;
      _mentionSuggestions = <ChatComposerMentionSuggestion>[];
      _slashSuggestions = <ChatComposerSlashCommandSuggestion>[];
      _activeSuggestionIndex = 0;
    });
  }

  List<RegExpMatch> _extractMentionTokens(String text) {
    return _mentionTokenPattern.allMatches(text).toList(growable: false);
  }

  IconData _mentionIconForToken(String value) {
    if (value.contains('/') || value.contains('.')) {
      return Icons.insert_drive_file_outlined;
    }
    return Icons.smart_toy_outlined;
  }

  String _composerHintText() {
    if (_mode == ChatComposerMode.shell) {
      return 'Shell command (Esc to exit)';
    }
    return 'Type a message... (`@` file/agent, `/` command, `!` shell)';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mentionTokens = _extractMentionTokens(_controller.text);
    final showAttachments =
        _attachments.isNotEmpty && _mode == ChatComposerMode.normal;
    final canSend =
        (_isComposing ||
            (_attachments.isNotEmpty && _mode == ChatComposerMode.normal)) &&
        widget.enabled &&
        !_isSending &&
        !widget.isResponding;
    final showPopover = _popoverType != ChatComposerPopoverType.none;
    final inputBubbleColor = _mode == ChatComposerMode.shell
        ? colorScheme.tertiaryContainer.withValues(alpha: 0.5)
        : colorScheme.surface;
    final inputBubbleBorderColor = _mode == ChatComposerMode.shell
        ? colorScheme.tertiary.withValues(alpha: 0.25)
        : colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mode == ChatComposerMode.shell)
              Padding(
                key: const ValueKey<String>('composer_shell_mode_row'),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    key: const ValueKey<String>('composer_shell_mode_chip'),
                    avatar: const Icon(Icons.terminal_rounded, size: 16),
                    label: const Text('Shell mode'),
                    onDeleted: widget.enabled
                        ? () {
                            setState(() {
                              _mode = ChatComposerMode.normal;
                              _controller.clear();
                              _isComposing = false;
                            });
                          }
                        : null,
                  ),
                ),
              ),
            if (mentionTokens.isNotEmpty)
              Padding(
                key: const ValueKey<String>('composer_mention_tokens_row'),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: mentionTokens
                        .map((token) {
                          final value = token.group(1) ?? '';
                          return InputChip(
                            key: ValueKey<String>('mention_token_$value'),
                            avatar: Icon(_mentionIconForToken(value), size: 16),
                            label: Text('@$value'),
                            onDeleted: widget.enabled
                                ? () {
                                    final start = token.start;
                                    final end = token.end;
                                    final current = _controller.text;
                                    if (start < 0 || end > current.length) {
                                      return;
                                    }
                                    final nextText = current.replaceRange(
                                      start,
                                      end,
                                      '',
                                    );
                                    _controller.value = TextEditingValue(
                                      text: nextText,
                                      selection: TextSelection.collapsed(
                                        offset: start.clamp(0, nextText.length),
                                      ),
                                    );
                                    _handleTextChanged(nextText);
                                  }
                                : null,
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ),
            if (showAttachments)
              Padding(
                key: const ValueKey<String>('composer_attachments_row'),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(_attachments.length, (index) {
                    final attachment = _attachments[index];
                    return InputChip(
                      avatar: Icon(
                        attachment.mime.startsWith('image/')
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined,
                        size: 18,
                      ),
                      label: Text(attachment.filename ?? 'attachment'),
                      onDeleted: widget.enabled
                          ? () {
                              setState(() {
                                _attachments.removeAt(index);
                              });
                            }
                          : null,
                    );
                  }),
                ),
              ),
            if (showPopover)
              Padding(
                key: const ValueKey<String>('composer_popover_row'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: _buildSuggestionPopover(
                  colorScheme: colorScheme,
                  maxHeight: _popoverMaxHeight(context),
                ),
              ),
            Padding(
              key: const ValueKey<String>('composer_input_row'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.showAttachmentButton &&
                      widget.showInlineAttachmentButton &&
                      _mode == ChatComposerMode.normal) ...[
                    IconButton.filledTonal(
                      onPressed: widget.enabled ? _showAttachmentOptions : null,
                      tooltip: 'Add attachment',
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _composerActionButtonSize,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: inputBubbleColor,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: inputBubbleBorderColor,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Focus(
                          onKeyEvent: _handleInputKeyEvent,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _effectiveFocusNode,
                                  enabled: widget.enabled,
                                  minLines: 1,
                                  maxLines: _composerMaxLines,
                                  textAlignVertical: TextAlignVertical.center,
                                  textInputAction: _isDesktopPlatform
                                      ? TextInputAction.newline
                                      : TextInputAction.send,
                                  keyboardType: TextInputType.multiline,
                                  onChanged: _handleTextChanged,
                                  onSubmitted: (_) =>
                                      unawaited(_handleSendMessage()),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  decoration: InputDecoration(
                                    hintText: _composerHintText(),
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      16,
                                      7,
                                      8,
                                      7,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: IconButton.filledTonal(
                                  onPressed:
                                      widget.enabled &&
                                          !_isSending &&
                                          !widget.isResponding
                                      ? () => unawaited(_toggleVoiceInput())
                                      : null,
                                  tooltip: _isListening
                                      ? 'Stop voice input'
                                      : 'Start voice input',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(40, 40),
                                    maximumSize: const Size(40, 40),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        microphoneButtonBackgroundColor(
                                          isListening: _isListening,
                                          colorScheme: colorScheme,
                                        ),
                                    foregroundColor:
                                        microphoneButtonForegroundColor(
                                          isListening: _isListening,
                                          colorScheme: colorScheme,
                                        ),
                                  ),
                                  icon: Icon(
                                    _isListening
                                        ? Icons.mic_rounded
                                        : Icons.mic_none_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Listener(
                    onPointerDown: (_) =>
                        _handleSendButtonPressStart(canSend: canSend),
                    onPointerUp: (_) => _handleSendButtonPressEnd(),
                    onPointerCancel: (_) => _handleSendButtonPressEnd(),
                    child: FilledButton(
                      onPressed: widget.isResponding
                          ? (widget.enabled &&
                                    !_isSending &&
                                    widget.onStopRequested != null
                                ? () => unawaited(
                                    Future<void>.sync(widget.onStopRequested!),
                                  )
                                : null)
                          : (canSend ? _handleSendButtonTap : null),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          _composerActionButtonSize,
                          _composerActionButtonSize,
                        ),
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: widget.isResponding
                            ? const Color(0xFF424242)
                            : (canSend
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest),
                        foregroundColor: widget.isResponding
                            ? colorScheme.error
                            : (canSend
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant),
                        elevation: canSend ? 1.5 : 0,
                        shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : widget.isResponding
                          ? Icon(
                              Icons.stop_rounded,
                              size: 24,
                              color: colorScheme.error,
                            )
                          : SizedBox(
                              width: _composerActionButtonSize,
                              height: _composerActionButtonSize,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const Align(
                                    alignment: Alignment.center,
                                    child: Icon(Icons.send_rounded, size: 24),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        right: 3,
                                        bottom: 3,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: canSend
                                              ? colorScheme.onPrimary
                                                    .withValues(alpha: 0.16)
                                              : colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(1),
                                          child: Icon(
                                            Icons.keyboard_return_rounded,
                                            size: 9,
                                            color: canSend
                                                ? colorScheme.onPrimary
                                                : colorScheme
                                                      .onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _popoverMaxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final visibleHeight = media.size.height - media.viewInsets.bottom;
    final reservedInputSpace = _inputRowHeight + 18 + media.viewPadding.bottom;
    final availableForPopover = visibleHeight - reservedInputSpace;
    final maxByInput = _inputRowHeight * _popoverInputHeightMultiplier;
    return math.max(0, math.min(maxByInput, availableForPopover));
  }

  Widget _buildSuggestionPopover({
    required ColorScheme colorScheme,
    required double maxHeight,
  }) {
    final isMention = _popoverType == ChatComposerPopoverType.mention;
    final suggestions = isMention
        ? _mentionSuggestions
              .map(
                (item) => (
                  title: item.value,
                  subtitle: item.subtitle,
                  icon: item.type == ChatComposerSuggestionType.file
                      ? Icons.insert_drive_file_outlined
                      : Icons.smart_toy_outlined,
                  badge: item.type == ChatComposerSuggestionType.file
                      ? 'file'
                      : 'agent',
                ),
              )
              .toList(growable: false)
        : _slashSuggestions
              .map(
                (item) => (
                  title: '/${item.name}',
                  subtitle: item.description,
                  icon: item.isBuiltin
                      ? Icons.bolt_outlined
                      : Icons.extension_outlined,
                  badge: item.source,
                ),
              )
              .toList(growable: false);

    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      skipTraversal: true,
      child: Material(
        key: ValueKey<String>('composer_popover_panel_${_popoverType.name}'),
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _isLoadingSuggestions && suggestions.isEmpty
              ? const SizedBox(
                  height: 72,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : suggestions.isEmpty
              ? const SizedBox(
                  height: 72,
                  child: Center(child: Text('No suggestions')),
                )
              : ListView.builder(
                  key: ValueKey<String>(
                    'composer_popover_${_popoverType.name}',
                  ),
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  shrinkWrap: false,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                    final selected = index == _activeSuggestionIndex;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      leading: Icon(item.icon, size: 18),
                      title: Text(item.title),
                      subtitle: item.subtitle == null || item.subtitle!.isEmpty
                          ? null
                          : Text(
                              item.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.badge,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _activeSuggestionIndex = index;
                        });
                        unawaited(_applyActiveSuggestion());
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    if (!widget.allowImageAttachment && !widget.allowPdfAttachment) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (widget.allowImageAttachment)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Select Images'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickImages());
                },
              ),
            if (widget.allowPdfAttachment)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Select PDF'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(_pickPdf());
                },
              ),
          ],
        ),
      ),
    );
  }

  bool get _canOpenAttachmentOptions =>
      widget.showAttachmentButton &&
      widget.enabled &&
      _mode == ChatComposerMode.normal &&
      (widget.allowImageAttachment || widget.allowPdfAttachment);

  void _openAttachmentOptionsFromExternal() {
    if (!_canOpenAttachmentOptions) {
      return;
    }
    _showAttachmentOptions();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    _appendAttachments(result.files, forcePdf: false);
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }
    _appendAttachments(result.files, forcePdf: true);
  }

  void _appendAttachments(List<PlatformFile> files, {required bool forcePdf}) {
    final nextAttachments = <FileInputPart>[];
    for (final file in files) {
      final url = _resolveAttachmentUrl(file, forcePdf: forcePdf);
      if (url == null) {
        continue;
      }
      final mime = forcePdf ? 'application/pdf' : _resolveImageMime(file);
      if (!_isMimeAllowed(mime)) {
        continue;
      }
      nextAttachments.add(
        FileInputPart(
          mime: mime,
          url: url,
          filename: file.name.isEmpty ? null : file.name,
        ),
      );
    }

    if (nextAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid files were selected')),
      );
      return;
    }

    setState(() {
      final dedupe = <String>{
        for (final existing in _attachments)
          '${existing.mime}|${existing.url}|${existing.filename ?? ""}',
      };
      for (final attachment in nextAttachments) {
        final key =
            '${attachment.mime}|${attachment.url}|'
            '${attachment.filename ?? ""}';
        if (dedupe.add(key)) {
          _attachments.add(attachment);
        }
      }
    });
  }

  bool _isMimeAllowed(String mime) {
    if (mime.startsWith('image/')) {
      return widget.allowImageAttachment;
    }
    if (mime == 'application/pdf') {
      return widget.allowPdfAttachment;
    }
    return false;
  }

  String? _resolveAttachmentUrl(PlatformFile file, {required bool forcePdf}) {
    final mime = forcePdf ? 'application/pdf' : _resolveImageMime(file);
    if (file.bytes case final bytes?) {
      if (bytes.isEmpty) {
        return null;
      }
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    final path = file.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return Uri.file(path).toString();
  }

  String _resolveImageMime(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/png';
    }
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

    setState(() {
      _isComposing = nextText.trim().isNotEmpty;
    });
  }

  Future<void> _toggleVoiceInput() async {
    if (_isInitializingSpeech) {
      return;
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    if (!widget.enabled || _isSending) {
      return;
    }

    if (!_isSpeechEnabled) {
      await _initializeSpeech();
    }
    if (!_isSpeechEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice input is unavailable on this device'),
        ),
      );
      return;
    }

    _speechPrefix = _controller.text;
    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = _speechToText.isListening;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start voice input')),
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {
      // Ignore platform stop errors to keep compose flow resilient.
    } finally {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  Future<void> _initializeSpeech() async {
    if (_isInitializingSpeech) {
      return;
    }

    _isInitializingSpeech = true;
    try {
      final enabled = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeechEnabled = enabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeechEnabled = false;
      });
    } finally {
      _isInitializingSpeech = false;
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }

    final recognized = result.recognizedWords.trim();
    final prefix = _speechPrefix;
    final shouldAddSpace =
        prefix.isNotEmpty &&
        recognized.isNotEmpty &&
        !prefix.endsWith(' ') &&
        !prefix.endsWith('\n');
    final nextText = recognized.isEmpty
        ? prefix
        : shouldAddSpace
        ? '$prefix $recognized'
        : '$prefix$recognized';

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );

    setState(() {
      _isComposing = nextText.trim().isNotEmpty;
    });
  }

  void _onSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final listening = status == 'listening' || _speechToText.isListening;
    if (_isListening == listening) {
      return;
    }
    setState(() {
      _isListening = listening;
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
    });
  }
}
