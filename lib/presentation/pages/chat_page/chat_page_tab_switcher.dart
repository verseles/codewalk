part of '../chat_page.dart';

/// Browser-style session tab switcher (issue #171).
///
/// Hold-to-cycle / commit-on-release: `Ctrl+Tab` opens a small MRU overlay,
/// repeated `Tab` cycles the highlight locally (no provider notification),
/// releasing `Ctrl` activates once via [_activateSessionTab]. `Esc`,
/// barrier tap, backgrounding, or minimize cancels.
extension _ChatPageTabSwitcher on _ChatPageState {
  bool get _isTabSwitcherOpen => _tabSwitcherPreview.value != null;

  List<SessionTabRecord> _tabSwitcherCandidates(ChatProvider chatProvider) {
    return orderTabsForSwitcher(chatProvider.sessionTabs);
  }

  bool _handleTabSwitcherKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (!_isTabSwitcherOpen) return false;

    final hardwareKeyboard = HardwareKeyboard.instance;
    if (event is KeyUpEvent) {
      // Commit when the held Ctrl is fully released. Shift release alone
      // must not confirm.
      if (_isTabSwitcherControlRelease(event)) {
        if (!hardwareKeyboard.isControlPressed) {
          _commitTabSwitcher();
          return true;
        }
        return true;
      }
      return false;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!_isChatScreenActive()) {
      _cancelTabSwitcher();
      return true;
    }

    final logicalKey = event.logicalKey;
    if (logicalKey == LogicalKeyboardKey.escape) {
      _cancelTabSwitcher();
      return true;
    }
    if (logicalKey == LogicalKeyboardKey.enter) {
      _commitTabSwitcher();
      return true;
    }
    if (logicalKey == LogicalKeyboardKey.tab) {
      if (!hardwareKeyboard.isControlPressed ||
          hardwareKeyboard.isMetaPressed ||
          hardwareKeyboard.isAltPressed) {
        return false;
      }
      _cycleTabSwitcher(reverse: hardwareKeyboard.isShiftPressed);
      return true;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown ||
        logicalKey == LogicalKeyboardKey.arrowRight) {
      _cycleTabSwitcher(reverse: false);
      return true;
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.arrowLeft) {
      _cycleTabSwitcher(reverse: true);
      return true;
    }
    // Swallow other keys while the modifier is held so cycling does not
    // leak text into the composer.
    if (hardwareKeyboard.isControlPressed) return true;
    return false;
  }

  bool _isTabSwitcherControlRelease(KeyUpEvent event) {
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight;
  }

  /// Opens the overlay on first `Ctrl+Tab` or advances the highlight when
  /// already open. Returns true when the event was consumed.
  bool _openOrAdvanceTabSwitcher({required bool reverse}) {
    if (!mounted || !_isChatScreenActive()) return false;
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    if (_isTabSwitcherOpen) {
      _cycleTabSwitcher(reverse: reverse);
      return true;
    }
    final tabs = _tabSwitcherCandidates(chatProvider);
    if (tabs.length < 2) return false;
    _tabSwitcherTabs = tabs;
    // No valid tab selected (e.g. New Chat draft active): the MRU list has
    // no anchor, so forward starts at the most recent candidate (index 0).
    final hasCurrent = tabs.any((tab) => tab.isSelected);
    _tabSwitcherPreview.value = hasCurrent
        ? switcherInitialIndex(tabs.length, reverse: reverse)
        : (reverse ? tabs.length - 1 : 0);
    return true;
  }

  void _cycleTabSwitcher({required bool reverse}) {
    final tabs = _tabSwitcherTabs;
    if (tabs.length < 2) return;
    final current = _tabSwitcherPreview.value ?? 0;
    _tabSwitcherPreview.value =
        switcherStepIndex(current, tabs.length, reverse: reverse);
  }

  void _commitTabSwitcher() {
    final tabs = _tabSwitcherTabs;
    final index = _tabSwitcherPreview.value;
    _tabSwitcherPreview.value = null;
    _tabSwitcherTabs = const <SessionTabRecord>[];
    if (!mounted || tabs.isEmpty || index == null) return;
    if (!_isChatScreenActive()) return;
    final clamped = index.clamp(0, tabs.length - 1);
    final snapshotTarget = tabs[clamped];
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    var target = snapshotTarget;
    var foundFresh = false;
    for (final tab in chatProvider.sessionTabs) {
      if (tab.identity == snapshotTarget.identity) {
        target = tab;
        foundFresh = true;
        break;
      }
    }
    if (!foundFresh) return;
    if (target.isSelected &&
        _isSessionTabContextActive(target) &&
        chatProvider.currentSession?.id == target.identity.sessionId) {
      return;
    }
    unawaited(_activateSessionTab(target));
  }

  void _cancelTabSwitcher() {
    if (_tabSwitcherPreview.value == null && _tabSwitcherTabs.isEmpty) return;
    _tabSwitcherPreview.value = null;
    _tabSwitcherTabs = const <SessionTabRecord>[];
  }

  /// Remapped bindings that no longer use the built-in Ctrl+Tab shape.
  /// Ctrl-based customs join the hold-to-cycle overlay; anything else
  /// (Meta/Alt/modifier-free) commits a single MRU step immediately so the
  /// overlay never waits for a Ctrl release that will not come.
  bool _matchCustomTabSwitcherBinding(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final settingsProvider = context.read<SettingsProvider>();
    for (final reverse in const <bool>[true, false]) {
      final action = reverse
          ? ShortcutAction.cycleTabsBackward
          : ShortcutAction.cycleTabsForward;
      final activator =
          ShortcutBindingCodec.parse(settingsProvider.bindingFor(action));
      if (activator == null) continue;
      if (!activator.accepts(event, HardwareKeyboard.instance)) continue;
      // Built-in shape is already handled by the explicit Ctrl+Tab path.
      if (activator.control &&
          !activator.meta &&
          !activator.alt &&
          activator.trigger == LogicalKeyboardKey.tab) {
        continue;
      }
      if (activator.control && !activator.meta && !activator.alt) {
        return _openOrAdvanceTabSwitcher(reverse: reverse);
      }
      // Meta/Alt/modifier-free customs: single MRU step, KeyDown only so
      // auto-repeat cannot thrash the current session.
      if (event is! KeyDownEvent) return false;
      _commitSingleMruStep(reverse: reverse);
      return true;
    }
    return false;
  }

  void _commitSingleMruStep({required bool reverse}) {
    if (!mounted || !_isChatScreenActive()) return;
    final chatProvider = _chatProvider ?? context.read<ChatProvider>();
    final tabs = _tabSwitcherCandidates(chatProvider);
    if (tabs.length < 2) return;
    final target =
        tabs[switcherInitialIndex(tabs.length, reverse: reverse)];
    if (target.isSelected &&
        _isSessionTabContextActive(target) &&
        chatProvider.currentSession?.id == target.identity.sessionId) {
      return;
    }
    unawaited(_activateSessionTab(target));
  }

  Widget _buildTabSwitcherOverlay() {
    return ValueListenableBuilder<int?>(
      valueListenable: _tabSwitcherPreview,
      builder: (context, previewIndex, _) {
        if (previewIndex == null || _tabSwitcherTabs.length < 2) {
          return const SizedBox.shrink();
        }
        final clamped = previewIndex.clamp(0, _tabSwitcherTabs.length - 1);
        return Positioned.fill(
          child: SessionTabSwitcherOverlay(
            tabs: _tabSwitcherTabs,
            previewIndex: clamped,
            projects: context.read<ProjectProvider>().projects,
            onSelect: (index) {
              if (index == clamped) {
                _commitTabSwitcher();
                return;
              }
              _tabSwitcherPreview.value = index;
              _commitTabSwitcher();
            },
            onDismiss: _cancelTabSwitcher,
          ),
        );
      },
    );
  }
}
