part of '../chat_page.dart';

extension _ChatPageComposerStatus on _ChatPageState {
  bool _shouldIgnoreProgressTool(ToolPart part) {
    final normalizedName = normalizeToolName(part.tool);
    return normalizedName == 'todowrite' ||
        normalizedName == 'todoread' ||
        normalizedName == 'task';
  }

  String _resolvePatchProgressLabel(PatchPart part) {
    if (part.files.isEmpty) {
      return context.l10n.chatStatusPatching;
    }
    if (part.files.length == 1) {
      return context.l10n.chatStatusPatchingOneFile;
    }
    return context.l10n.chatStatusPatchingMultipleFiles(part.files.length);
  }

  _ComposerStatusPresentation? _resolveLatestLiveProgress(
    List<ChatMessage> messages,
  ) {
    for (
      var messageIndex = messages.length - 1;
      messageIndex >= 0;
      messageIndex -= 1
    ) {
      final message = messages[messageIndex];
      if (message is! AssistantMessage || message.isCompleted) {
        continue;
      }
      for (
        var partIndex = message.parts.length - 1;
        partIndex >= 0;
        partIndex -= 1
      ) {
        final part = message.parts[partIndex];
        if (part is ToolPart) {
          if (_shouldIgnoreProgressTool(part)) {
            continue;
          }
          final presentation = toolPresentationForComposer(part.tool);
          return _ComposerStatusPresentation.activeProgress(
            label: toolResolveComposerDescriptionLabel(part),
            icon: presentation.icon,
          );
        }
        if (part is PatchPart) {
          return _ComposerStatusPresentation.activeProgress(
            label: _resolvePatchProgressLabel(part),
            icon: Symbols.compare_arrows,
          );
        }
        if (part is ReasoningPart) {
          final trimmed = part.text.trim();
          if (trimmed.isEmpty) {
            continue;
          }
          final label =
              parseReasoningStatusLabel(part.text) ??
              context.l10n.chatStatusThinking;
          return _ComposerStatusPresentation.dynamicReasoning(label);
        }
      }
    }
    return null;
  }

  void _scheduleCompactionStateSync({
    required bool wasCompactingContext,
    required String? frozenCompactionBoundaryId,
  }) {
    if (_wasCompactingContext == wasCompactingContext &&
        _frozenCompactionBoundaryId == frozenCompactionBoundaryId) {
      return;
    }

    _nextWasCompactingContext = wasCompactingContext;
    _nextFrozenCompactionBoundaryId = frozenCompactionBoundaryId;
    if (_compactionStateSyncScheduled) {
      return;
    }

    _compactionStateSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _compactionStateSyncScheduled = false;
      if (!mounted) {
        return;
      }
      if (_wasCompactingContext == _nextWasCompactingContext &&
          _frozenCompactionBoundaryId == _nextFrozenCompactionBoundaryId) {
        return;
      }
      _setState(() {
        _wasCompactingContext = _nextWasCompactingContext;
        _frozenCompactionBoundaryId = _nextFrozenCompactionBoundaryId;
      });
    });
  }

  _ComposerStatusPresentation? _resolveComposerStatusTarget(
    ChatProvider chatProvider,
  ) {
    final latestMessage = chatProvider.messages.isEmpty
        ? null
        : chatProvider.messages.last;
    final currentSessionId = chatProvider.currentSession?.id;
    if (currentSessionId != null &&
        isLatestTailSettledRevealable(
          chatProvider.messages,
          currentSessionId,
        )) {
      return null;
    }
    if (latestMessage is AssistantMessage && latestMessage.isCompleted) {
      return null;
    }

    final progressStage = _resolveAssistantProgressStage(chatProvider);
    if (progressStage == null) {
      return null;
    }

    final liveProgress = _resolveLatestLiveProgress(chatProvider.messages);
    if (liveProgress != null) {
      return liveProgress;
    }

    final reasoningStatusLabel = _resolveLatestReasoningStatusLabel(
      chatProvider.messages,
    );
    if (reasoningStatusLabel != null) {
      return _ComposerStatusPresentation.dynamicReasoning(reasoningStatusLabel);
    }

    // Both thinking and receiving stages show the same visual output:
    // - Tips enabled: rotating tips with lightbulb icon
    // - Tips disabled: static "Reasoning..." fallback
    // Internally they remain separate stages so the progress detection
    // logic is preserved, but visually the user sees no transition.
    return switch (progressStage) {
      _AssistantProgressStage.receiving || _AssistantProgressStage.thinking =>
        context.read<SettingsProvider>().showComposerTips
            ? _ComposerStatusPresentation.tip(
                _receivingTips[_currentTipIndex % _receivingTips.length],
              )
            : _ComposerStatusPresentation.receiving(
                label: context.l10n.chatReasoning,
              ),
      _AssistantProgressStage.retrying => _ComposerStatusPresentation.retrying(
        label: context.l10n.chatRetryingModelRequest,
      ),
    };
  }
}
