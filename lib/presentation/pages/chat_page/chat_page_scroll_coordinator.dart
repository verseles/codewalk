part of '../chat_page.dart';

extension _ChatPageScrollCoordinator on _ChatPageState {
  bool _hasActiveUserScrollActivity() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final activity = _scrollController.position.activity;
    return activity is DragScrollActivity ||
        activity is BallisticScrollActivity;
  }

  bool _isUserScrollActivity({required ScrollDirection userScrollDirection}) {
    if (_hasActiveUserScrollActivity()) {
      return true;
    }
    if (_isProgrammaticScrollInFlight) {
      return false;
    }
    return userScrollDirection != ScrollDirection.idle ||
        _scrollController.position.activity is DrivenScrollActivity;
  }

  bool _hasRecentUserScrollIntent() {
    final lastIntentAt = _lastUserScrollIntentAt;
    if (lastIntentAt == null) {
      return false;
    }
    return DateTime.now().difference(lastIntentAt) <
        _ChatPageState._userScrollIntentHoldDuration;
  }

  bool _hasActiveOrRecentUserScrollIntent() {
    return _hasActiveUserScrollActivity() || _hasRecentUserScrollIntent();
  }

  bool _hasUserScrollPriority() {
    final hasActiveUserScroll = _hasActiveUserScrollActivity();
    if (hasActiveUserScroll) {
      return true;
    }
    if (_scrollController.hasClients &&
        _distanceToBottom() <= _ChatPageState._scrollToBottomEpsilon) {
      _lastUserScrollIntentAt = null;
      if (_currentScrollOwner == _ScrollOwner.userDrag) {
        _setScrollOwner(_ScrollOwner.none);
      }
      return false;
    }
    if (_hasRecentUserScrollIntent()) {
      return true;
    }
    if (_currentScrollOwner == _ScrollOwner.userDrag) {
      _setScrollOwner(_ScrollOwner.none);
    }
    return false;
  }

  void _markUserScrollIntent() {
    _clearSessionViewportNavigationState(
      reason: 'user-scroll-intent',
      clearSnapshots: false,
    );
    final hadIntentLock =
        _currentScrollOwner == _ScrollOwner.userDrag ||
        _hasRecentUserScrollIntent();
    _lastUserScrollIntentAt = DateTime.now();
    if (!hadIntentLock) {
      _scrollToBottomRequestToken += 1;
      _returnRevealGeneration += 1;
    }
    if (_currentScrollOwner != _ScrollOwner.userDrag) {
      _setScrollOwner(_ScrollOwner.userDrag);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }
    if (event.scrollDelta.dy == 0 && event.scrollDelta.dx == 0) {
      return;
    }
    _markUserScrollIntent();
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }

    final userScrollDirection = _scrollController.position.userScrollDirection;
    if (_isUserScrollActivity(userScrollDirection: userScrollDirection)) {
      _markUserScrollIntent();
    }
    _maybeLoadOlderMessagesFromTop(userScrollDirection: userScrollDirection);

    if (_isProgrammaticScrollInFlight) {
      return;
    }

    final distance = _distanceToBottom();
    final nearBottom = _isNearBottom();
    final shouldShowJumpToFirst = _shouldShowJumpToFirstFab();

    if (distance <= _ChatPageState._scrollToBottomEpsilon) {
      if (_currentScrollOwner == _ScrollOwner.userDrag &&
          !_hasActiveOrRecentUserScrollIntent()) {
        _setScrollOwner(_ScrollOwner.none);
      }
      if (_scrollFollowMode != _ScrollFollowMode.following) {
        _setState(() {
          _scrollFollowMode = _ScrollFollowMode.following;
          _hasUnreadMessagesBelow = false;
          _showScrollToFirstFab = shouldShowJumpToFirst;
        });
      }
      return;
    }

    if (_currentScrollOwner == _ScrollOwner.userDrag &&
        !_hasActiveOrRecentUserScrollIntent()) {
      _setScrollOwner(_ScrollOwner.none);
    }

    // If user dragged/scrolled away from the very bottom, or if they scrolled past 200px
    if (_currentScrollOwner == _ScrollOwner.userDrag || !nearBottom) {
      if (_scrollFollowMode != _ScrollFollowMode.pausedByUser) {
        _setState(() {
          _scrollFollowMode = _ScrollFollowMode.pausedByUser;
          _showScrollToFirstFab = shouldShowJumpToFirst;
        });
      } else {
        if (_showScrollToFirstFab != shouldShowJumpToFirst) {
          _setState(() {
            _showScrollToFirstFab = shouldShowJumpToFirst;
          });
        }
      }
    } else {
      // Not dragging and within 200px (but not at 0px)
      if (_showScrollToFirstFab != shouldShowJumpToFirst) {
        _setState(() {
          _showScrollToFirstFab = shouldShowJumpToFirst;
        });
      }
    }
  }

  void _maybeLoadOlderMessagesFromTop({
    required ScrollDirection userScrollDirection,
  }) {
    final provider = _chatProvider;
    if (provider == null ||
        provider.currentSession == null ||
        !provider.hasMoreOldMessages ||
        provider.isLoadingOlderMessages ||
        _olderMessagesAnchorRestoreInFlight) {
      return;
    }

    final pixels = _scrollController.position.pixels;
    if (pixels > _ChatPageState._olderMessagesTopLoadArmThreshold) {
      _olderMessagesLoadTriggerArmed = true;
      return;
    }

    if (!_olderMessagesLoadTriggerArmed) {
      return;
    }

    if (!_isUserScrollActivity(userScrollDirection: userScrollDirection)) {
      return;
    }

    if (userScrollDirection != ScrollDirection.forward) {
      return;
    }

    if (pixels > _ChatPageState._olderMessagesTopLoadThreshold) {
      return;
    }

    final maxBefore = _scrollController.position.maxScrollExtent;
    _olderMessagesLoadTriggerArmed = false;
    unawaited(
      _loadOlderMessagesAndRestoreAnchor(
        provider: provider,
        maxExtentBefore: maxBefore,
      ),
    );
  }

  Future<void> _loadOlderMessagesAndRestoreAnchor({
    required ChatProvider provider,
    required double maxExtentBefore,
    bool restoreAnchor = true,
  }) async {
    _setScrollOwner(_ScrollOwner.paginationRestore);
    try {
      await provider.loadOlderMessages();
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      await Future<void>.microtask(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      // Some sliver/layout updates settle one microtask after endOfFrame.
      // Use the final extent immediately before restoring the anchor so older
      // message prepends do not under-correct and create a second visible jump.
      await Future<void>.microtask(() {});
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxAfter = _scrollController.position.maxScrollExtent;
      if (restoreAnchor) {
        final delta = maxAfter - maxExtentBefore;
        if (delta <= 0) {
          return;
        }

        final nextPixels = (_scrollController.position.pixels + delta).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(nextPixels);
        return;
      }

      // Programmatic jump-to-first lands on the newly loaded top instead of
      // restoring the pre-load reading anchor.
      final target = _scrollController.position.minScrollExtent;
      if (_scrollController.position.pixels > target) {
        _scrollController.jumpTo(target);
      }
    } finally {
      if (_currentScrollOwner == _ScrollOwner.paginationRestore) {
        _setScrollOwner(_ScrollOwner.none);
      }
    }
  }

  Future<void> _runScrollToBottom({
    required int requestToken,
    required bool force,
    required bool animate,
  }) async {
    if (!_canContinueScrollToBottomRequest(requestToken)) {
      return;
    }

    if (!force && _hasUserScrollPriority()) {
      _markUnreadMessagesBelow();
      return;
    }

    if (_isReturnRevealInFlight && !force) {
      return;
    }

    if (_olderMessagesAnchorRestoreInFlight && !force) {
      return;
    }

    if (force) {
      _scrollFollowMode = _ScrollFollowMode.following;
    }
    final shouldScroll =
        force || _scrollFollowMode == _ScrollFollowMode.following;
    if (!shouldScroll) {
      _markUnreadMessagesBelow();
      return;
    }

    _setScrollOwner(force ? _ScrollOwner.newMessage : _ScrollOwner.streaming);
    try {
      if (!animate) {
        for (
          var pass = 0;
          pass < _ChatPageState._maxScrollToBottomPasses;
          pass += 1
        ) {
          if (!force && _hasUserScrollPriority()) {
            _markUnreadMessagesBelow();
            return;
          }
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          await WidgetsBinding.instance.endOfFrame;
          if (!_canContinueScrollToBottomRequest(requestToken)) {
            return;
          }
          if (_distanceToBottom() <= _ChatPageState._scrollToBottomEpsilon) {
            break;
          }
        }
        if (!force && _hasUserScrollPriority()) {
          _markUnreadMessagesBelow();
          return;
        }
        if (_distanceToBottom() > _ChatPageState._scrollToBottomEpsilon) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      } else {
        for (
          var pass = 0;
          pass < _ChatPageState._maxScrollToBottomPasses;
          pass += 1
        ) {
          if (!_canContinueScrollToBottomRequest(requestToken)) {
            return;
          }

          if (!force && _hasUserScrollPriority()) {
            _markUnreadMessagesBelow();
            return;
          }

          final distance = _distanceToBottom();
          if (distance <= _ChatPageState._scrollToBottomEpsilon) {
            break;
          }

          // Automatic follow is a layout anchor, not a visual transition. Keep
          // incoming message growth pinned without per-delta scroll motion.
          if (!force) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
            await WidgetsBinding.instance.endOfFrame;
            continue;
          }

          final targetDuration = pass == 0
              ? _ChatPageState._scrollToBottomFirstPassDuration
              : _ChatPageState._scrollToBottomNextPassDuration;

          if (targetDuration == Duration.zero) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          } else {
            await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: targetDuration,
              curve: Curves.easeOut,
            );
          }

          if (!_canContinueScrollToBottomRequest(requestToken)) {
            return;
          }
          await WidgetsBinding.instance.endOfFrame;
        }

        if (!force && _hasUserScrollPriority()) {
          _markUnreadMessagesBelow();
          return;
        }
        if (_canContinueScrollToBottomRequest(requestToken) &&
            _distanceToBottom() > _ChatPageState._scrollToBottomEpsilon) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    } catch (error, stackTrace) {
      AppLogger.debug(
        'Scroll-to-bottom interrupted for request=$requestToken',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (requestToken == _scrollToBottomRequestToken) {
        _setScrollOwner(_ScrollOwner.none);
      }
    }

    if (!_canContinueScrollToBottomRequest(requestToken)) {
      return;
    }

    if (_scrollFollowMode != _ScrollFollowMode.following ||
        _hasUnreadMessagesBelow ||
        _showScrollToFirstFab) {
      _setState(() {
        _scrollFollowMode = _ScrollFollowMode.following;
        _hasUnreadMessagesBelow = false;
        _showScrollToFirstFab = false;
      });
    }
  }
}
