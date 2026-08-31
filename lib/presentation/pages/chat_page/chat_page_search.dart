part of '../chat_page.dart';

extension _ChatPageSearch on _ChatPageState {
  static const Duration _timelineSearchDebounce = Duration(milliseconds: 300);

  String? get _timelineSearchHighlightQuery {
    if (!_timelineSearchActive) {
      return null;
    }
    final query = _timelineSearchController.text.trim();
    return query.isEmpty ? null : query;
  }

  String _timelineSearchResultLabel() {
    final query = _timelineSearchController.text.trim();
    if (query.isEmpty) {
      return '';
    }
    if (_timelineSearchResult.isEmpty) {
      return context.l10n.chatSearchNoResults;
    }
    final current = (_timelineSearchCurrentIndex + 1).clamp(
      1,
      _timelineSearchResult.matches.length,
    );
    return context.l10n.chatSearchResultCount(
      current,
      _timelineSearchResult.matches.length,
    );
  }

  GlobalKey _timelineMessageKey(String messageId) {
    return _timelineMessageKeysByMessageId.putIfAbsent(
      messageId,
      () => GlobalKey(debugLabel: 'timeline_message_$messageId'),
    );
  }

  void _pruneTimelineMessageKeys(List<ChatMessage> messages) {
    final visibleIds = messages.map((message) => message.id).toSet();
    _timelineMessageKeysByMessageId.removeWhere(
      (messageId, _) => !visibleIds.contains(messageId),
    );
  }

  void _openTimelineSearch() {
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    _timelineSearchDebounceTimer?.cancel();
    _setState(() {
      _timelineSearchActive = true;
      _runTimelineSearchNow(chatProvider: chatProvider, notify: false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _timelineSearchFocusNode.requestFocus();
      _timelineSearchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _timelineSearchController.text.length,
      );
    });
  }

  void _closeTimelineSearch() {
    _timelineSearchDebounceTimer?.cancel();
    _setState(() {
      _timelineSearchActive = false;
      _timelineSearchController.clear();
      _timelineSearchResult = TimelineSearchResult.empty;
      _timelineSearchCurrentIndex = 0;
      _timelineSearchLastMessagesVersion = -1;
      _timelineSearchLastSessionId = null;
    });
  }

  void _onTimelineSearchChanged(String value) {
    _timelineSearchDebounceTimer?.cancel();
    _timelineSearchDebounceTimer = Timer(_timelineSearchDebounce, () {
      if (!mounted) {
        return;
      }
      final chatProvider = _chatProvider ?? context.read<ChatProvider>();
      _setState(() {
        _runTimelineSearchNow(chatProvider: chatProvider, notify: false);
      });
    });
  }

  void _runTimelineSearchNow({
    required ChatProvider chatProvider,
    required bool notify,
  }) {
    if (!_timelineSearchActive) {
      return;
    }
    final nextResult = _timelineSearchService.search(
      messages: chatProvider.messages,
      query: _timelineSearchController.text,
    );
    final previousMessageId = _timelineSearchResult.matches.isEmpty
        ? null
        : _timelineSearchResult
              .matches[_timelineSearchCurrentIndex.clamp(
                0,
                _timelineSearchResult.matches.length - 1,
              )]
              .messageId;
    final nextIndex = previousMessageId == null
        ? 0
        : nextResult.matches.indexWhere(
            (match) => match.messageId == previousMessageId,
          );

    void apply() {
      _timelineSearchResult = nextResult;
      _timelineSearchCurrentIndex = nextResult.matches.isEmpty
          ? 0
          : (nextIndex == -1 ? 0 : nextIndex);
      _timelineSearchLastMessagesVersion = chatProvider.messagesVersion;
      _timelineSearchLastSessionId = chatProvider.currentSession?.id;
    }

    if (notify) {
      _setState(apply);
    } else {
      apply();
    }
  }

  void _reconcileTimelineSearchForProviderChanged() {
    final chatProvider = _chatProvider;
    if (chatProvider == null) {
      return;
    }
    final sessionId = chatProvider.currentSession?.id;
    if (_timelineSearchLastSessionId != null &&
        _timelineSearchLastSessionId != sessionId) {
      _timelineSearchDebounceTimer?.cancel();
      _setState(() {
        _timelineSearchActive = false;
        _timelineSearchController.clear();
        _timelineSearchResult = TimelineSearchResult.empty;
        _timelineSearchCurrentIndex = 0;
        _timelineSearchLastMessagesVersion = -1;
        _timelineSearchLastSessionId = sessionId;
      });
      return;
    }
    if (!_timelineSearchActive ||
        _timelineSearchLastMessagesVersion == chatProvider.messagesVersion) {
      return;
    }
    _runTimelineSearchNow(chatProvider: chatProvider, notify: true);
  }

  Future<void> _goToTimelineSearchResult(int delta) async {
    if (_timelineSearchResult.matches.isEmpty) {
      return;
    }
    final resultCount = _timelineSearchResult.matches.length;
    final nextIndex =
        (_timelineSearchCurrentIndex + delta + resultCount) % resultCount;
    _setState(() {
      _timelineSearchCurrentIndex = nextIndex;
      _scrollFollowMode = _ScrollFollowMode.pausedByUser;
      _hasUnreadMessagesBelow = false;
    });
    await _scrollToTimelineSearchResult(
      _timelineSearchResult.matches[nextIndex].messageId,
    );
  }

  Future<void> _scrollToTimelineSearchResult(String messageId) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final opId = ++_timelineSearchScrollOpId;
    _setScrollOwner(_ScrollOwner.searchResult);
    try {
      var targetContext =
          _timelineMessageKeysByMessageId[messageId]?.currentContext;
      if (targetContext == null) {
        await _materializeTimelineSearchTarget(messageId, opId: opId);
        if (!mounted || opId != _timelineSearchScrollOpId) {
          return;
        }
        targetContext =
            _timelineMessageKeysByMessageId[messageId]?.currentContext;
      }
      if (targetContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.24,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } finally {
      if (mounted &&
          opId == _timelineSearchScrollOpId &&
          _currentScrollOwner == _ScrollOwner.searchResult) {
        _setScrollOwner(_ScrollOwner.none);
      }
    }
  }

  Future<void> _materializeTimelineSearchTarget(
    String messageId, {
    required int opId,
  }) async {
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    final messages = chatProvider.messages;
    final messageIndex = messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex == -1 ||
        messages.length <= 1 ||
        !_scrollController.hasClients) {
      return;
    }

    // SliverList children are lazy, so an offscreen result has no context for
    // ensureVisible. Approximate by chronological position first, then let
    // ensureVisible align the now-mounted message precisely on the next frame.
    final position = _scrollController.position;
    final targetOffset =
        position.maxScrollExtent * (messageIndex / (messages.length - 1));
    await position.animateTo(
      targetOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || opId != _timelineSearchScrollOpId) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
  }
}
