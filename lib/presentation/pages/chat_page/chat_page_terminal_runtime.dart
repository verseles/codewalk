part of '../chat_page.dart';

/// Smallest rendered height for the inline terminal panel.
const double kTerminalPanelMinHeight = 180;

/// Maximum fraction of the keyboard-shrunk chat column the inline terminal
/// panel may occupy, so the chat keeps usable room above the extra-key strip.
const double kTerminalPanelKeyboardMaxFraction = 0.55;

extension _ChatPageTerminalRuntime on _ChatPageState {
  Future<void> _toggleTerminalPanel() async {
    final settingsProvider = _settingsProvider;
    if (settingsProvider == null) {
      return;
    }
    if (!_terminalController.supportsRemoteTerminal) {
      await _showMobileTerminalInfoSheet();
      return;
    }
    // A second tap while the shell is starting would open another one.
    if (_isOpeningTerminal) {
      return;
    }
    final nextVisible = !settingsProvider.terminalPanelVisible;
    if (!nextVisible) {
      await settingsProvider.setTerminalPanelVisible(false);
      return;
    }
    _setState(() => _isOpeningTerminal = true);
    try {
      await settingsProvider.setTerminalPanelVisible(true);
      await _startTerminalForCurrentProject();
    } finally {
      // Always restored, so a failure never leaves the button spinning.
      if (mounted) {
        _setState(() => _isOpeningTerminal = false);
      } else {
        _isOpeningTerminal = false;
      }
    }
  }

  Future<void> _startTerminalForCurrentProject({bool force = false}) async {
    final projectProvider = _projectProvider;
    final activeServer = _appProvider?.activeServer;
    if (projectProvider == null || activeServer == null) {
      return;
    }
    final signature = _terminalSignatureFor(
      serverId: activeServer.id,
      directory: projectProvider.currentDirectory,
    );
    final isDeadState = _terminalController.isDeadState;
    if (!force && signature == _terminalSessionSignature && !isDeadState) {
      return;
    }
    _terminalSessionSignature = signature;
    await _terminalController.startShell(
      serverProfile: activeServer,
      workingDirectory: projectProvider.currentDirectory,
      force: force,
    );
  }

  String _terminalSignatureFor({
    required String? serverId,
    required String? directory,
  }) {
    return '${serverId ?? '-'}|${directory?.trim() ?? '-'}';
  }

  Future<void> _showMobileTerminalInfoSheet() async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final activeServer = _appProvider?.activeServer;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.terminalTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.terminalEmbeddedUnavailable(
                    activeServer?.displayName ??
                        context.l10n.chatPageStatusServer,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _restoreMaximizedTerminalIfNeeded({SettingsProvider? settingsProvider}) {
    final effectiveSettingsProvider =
        settingsProvider ??
        _settingsProvider ??
        context.read<SettingsProvider>();
    if (!effectiveSettingsProvider.terminalPanelVisible ||
        !effectiveSettingsProvider.terminalPanelMaximized) {
      return false;
    }
    unawaited(effectiveSettingsProvider.setTerminalPanelMaximized(false));
    return true;
  }

  Widget _buildTerminalPanel(
    SettingsProvider settingsProvider, {
    required double availableHeight,
  }) {
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isCompact = context.windowSizeClass.isCompact;
    final normalMaxPanelHeight = isCompact
        ? max(320.0, mediaHeight * 0.72)
        : min(480.0, mediaHeight * 0.55);
    // The scaffold shrinks the chat column by the IME. A fixed-height panel
    // taller than that column overflows, pushing its bottom extra-key strip
    // behind the keyboard (and its suggestion bar). While the keyboard is open
    // cap the rendered height to part of the real column so both the chat and
    // the strip stay visible; the persisted height is restored afterwards.
    final keyboardOpen = keyboardInset > 0;
    final effectiveMaxPanelHeight = keyboardOpen
        ? min(
            normalMaxPanelHeight,
            max(
              kTerminalPanelMinHeight,
              availableHeight * kTerminalPanelKeyboardMaxFraction,
            ),
          )
        : normalMaxPanelHeight;
    final panelHeight = settingsProvider.terminalPanelHeight.clamp(
      kTerminalPanelMinHeight,
      effectiveMaxPanelHeight,
    );
    return SizedBox(
      height: panelHeight,
      child: _buildTerminalPanelSurface(
        settingsProvider: settingsProvider,
        onHeightDelta: (delta) {
          settingsProvider.updateTerminalPanelHeightInMemory(
            (panelHeight + delta).clamp(
              kTerminalPanelMinHeight,
              normalMaxPanelHeight,
            ),
          );
          unawaited(settingsProvider.persistTerminalPanelHeight());
        },
      ),
    );
  }

  Widget _buildFullscreenTerminalOverlay(SettingsProvider settingsProvider) {
    KeyEventResult handleFullscreenTerminalKey(FocusNode _, KeyEvent event) {
      final activator = ShortcutBindingCodec.parse(
        settingsProvider.bindingFor(ShortcutAction.escape),
      );
      if (event is! KeyDownEvent ||
          activator == null ||
          !activator.accepts(event, HardwareKeyboard.instance)) {
        return KeyEventResult.ignored;
      }
      return _restoreMaximizedTerminalIfNeeded(
            settingsProvider: settingsProvider,
          )
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Focus(
            autofocus: true,
            onKeyEvent: handleFullscreenTerminalKey,
            child: _buildTerminalPanelSurface(
              settingsProvider: settingsProvider,
              onHeightDelta: (_) {},
              onTerminalKeyEvent: handleFullscreenTerminalKey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalPanelSurface({
    required SettingsProvider settingsProvider,
    required ValueChanged<double> onHeightDelta,
    FocusOnKeyEventCallback? onTerminalKeyEvent,
  }) {
    return CodewalkTerminalPanel(
      controller: _terminalController,
      isMaximized: settingsProvider.terminalPanelMaximized,
      onHide: () {
        unawaited(settingsProvider.setTerminalPanelVisible(false));
      },
      onReconnect: () {
        unawaited(_startTerminalForCurrentProject(force: true));
      },
      onStop: () {
        _terminalSessionSignature = null;
        unawaited(_terminalController.stop());
        unawaited(settingsProvider.setTerminalPanelVisible(false));
      },
      onToggleMaximize: () {
        unawaited(
          settingsProvider.setTerminalPanelMaximized(
            !settingsProvider.terminalPanelMaximized,
          ),
        );
      },
      onHeightDelta: (delta) {
        if (settingsProvider.terminalPanelMaximized) {
          return;
        }
        onHeightDelta(delta);
      },
      onTerminalKeyEvent: onTerminalKeyEvent,
      keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
    );
  }
}
