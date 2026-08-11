import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kLongPressTimeout, kPrimaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../../core/i18n/l10n_context.dart';
import '../../core/logging/app_logger.dart';
import '../providers/settings_provider.dart';
import '../services/codewalk_terminal_controller.dart';
import 'codewalk_terminal_extra_keys.dart';

class CodewalkTerminalPanel extends StatefulWidget {
  const CodewalkTerminalPanel({
    required this.controller,
    required this.isMaximized,
    required this.onHide,
    required this.onReconnect,
    required this.onStop,
    required this.onToggleMaximize,
    required this.onHeightDelta,
    required this.keyboardInset,
    this.onTerminalKeyEvent,
    super.key,
  });

  final CodewalkTerminalController controller;
  final bool isMaximized;
  final VoidCallback onHide;
  final VoidCallback onReconnect;
  final VoidCallback onStop;
  final VoidCallback onToggleMaximize;
  final ValueChanged<double> onHeightDelta;
  final double keyboardInset;
  final FocusOnKeyEventCallback? onTerminalKeyEvent;

  @override
  State<CodewalkTerminalPanel> createState() => _CodewalkTerminalPanelState();
}

class _CodewalkTerminalPanelState extends State<CodewalkTerminalPanel> {
  TerminalController _viewController = TerminalController();
  late final FocusNode _terminalFocusNode;
  late final CodewalkTerminalExtraKeysController _extraKeysController;
  int? _terminalGeneration;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode(debugLabel: 'codewalk_terminal');
    _extraKeysController = CodewalkTerminalExtraKeysController();
    _terminalGeneration = widget.controller.terminalGeneration;
    widget.controller.addListener(_handleTerminalControllerChanged);
    _syncTerminalController();
  }

  @override
  void didUpdateWidget(CodewalkTerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleTerminalControllerChanged);
      widget.controller.addListener(_handleTerminalControllerChanged);
      _terminalGeneration = null;
      _syncTerminalController();
    }
    if (oldWidget.keyboardInset > 0 && widget.keyboardInset <= 0) {
      _extraKeysController.reset();
    }
  }

  void _handleTerminalControllerChanged() {
    _syncTerminalController();
  }

  void _syncTerminalController() {
    final generation = widget.controller.terminalGeneration;
    if (_terminalGeneration != generation) {
      _terminalGeneration = generation;
      _viewController = TerminalController();
    }
    if (_isSupportedMobilePlatform && _hasActiveTerminal) {
      _extraKeysController.attach(widget.controller.terminal);
    } else {
      _extraKeysController.detach();
    }
  }

  bool get _isSupportedMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasActiveTerminal {
    final state = widget.controller.state;
    return state == CodewalkTerminalState.running ||
        state == CodewalkTerminalState.starting ||
        state == CodewalkTerminalState.exited;
  }

  bool _shouldShowExtraKeys(BuildContext context) {
    return shouldShowCodewalkTerminalExtraKeys(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      hasActiveTerminal: _hasActiveTerminal,
      keyboardInset: widget.keyboardInset,
    );
  }

  void _requestTerminalFocus() {
    if (!_terminalFocusNode.hasFocus) {
      _terminalFocusNode.requestFocus();
    }
  }

  /// Records that a header control actually fired.
  void _traceHeaderAction(String action) {
    AppLogger.debug(
      'terminal header action=$action maximized=${widget.isMaximized} '
      'keyboardInset=${widget.keyboardInset}',
    );
  }

  void _reconnect() {
    _traceHeaderAction('reconnect');
    _extraKeysController.reset();
    widget.onReconnect();
  }

  void _stop() {
    _traceHeaderAction('stop');
    _extraKeysController.reset();
    _extraKeysController.detach();
    widget.onStop();
  }

  void _hide() {
    _traceHeaderAction('hide');
    _extraKeysController.reset();
    _extraKeysController.detach();
    widget.onHide();
  }

  void _toggleMaximize() {
    _traceHeaderAction('toggleMaximize');
    _extraKeysController.reset();
    _extraKeysController.detach();
    widget.onToggleMaximize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTerminalControllerChanged);
    _extraKeysController.dispose();
    _terminalFocusNode.dispose();
    _viewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panelRadius = widget.isMaximized
        ? BorderRadius.zero
        : BorderRadius.circular(20);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        _syncTerminalController();
        return Container(
          key: const ValueKey<String>('terminal_panel'),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: panelRadius,
            border: widget.isMaximized
                ? null
                : Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              if (!widget.isMaximized)
                GestureDetector(
                  key: const ValueKey<String>('terminal_panel_resize_handle'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    widget.onHeightDelta(-details.delta.dy);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                child: Row(
                  children: [
                    const Icon(Symbols.terminal_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.controller.statusMessage,
                        key: const ValueKey<String>(
                          'terminal_panel_status_text',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _TerminalHeaderIconButton(
                      buttonKey: const ValueKey<String>(
                        'terminal_panel_reconnect_button',
                      ),
                      tooltip: context.l10n.terminalReconnect,
                      onPressed: _reconnect,
                      icon: const Icon(Symbols.refresh_rounded),
                      keyboardInset: widget.keyboardInset,
                      debugAction: 'reconnect',
                    ),
                    _TerminalHeaderIconButton(
                      buttonKey: const ValueKey<String>(
                        'terminal_panel_maximize_button',
                      ),
                      tooltip: widget.isMaximized
                          ? context.l10n.terminalRestoreSize
                          : context.l10n.terminalMaximize,
                      onPressed: _toggleMaximize,
                      icon: Icon(
                        widget.isMaximized
                            ? Symbols.close_fullscreen_rounded
                            : Symbols.open_in_full_rounded,
                      ),
                      keyboardInset: widget.keyboardInset,
                      debugAction: 'toggleMaximize',
                    ),
                    _TerminalHeaderIconButton(
                      buttonKey: const ValueKey<String>(
                        'terminal_panel_stop_button',
                      ),
                      tooltip: context.l10n.terminalClose,
                      onPressed: _stop,
                      icon: const Icon(Symbols.close_rounded),
                      keyboardInset: widget.keyboardInset,
                      debugAction: 'stop',
                    ),
                    _TerminalHeaderIconButton(
                      buttonKey: const ValueKey<String>(
                        'terminal_panel_hide_button',
                      ),
                      tooltip: context.l10n.terminalMinimize,
                      onPressed: _hide,
                      icon: const Icon(Symbols.keyboard_arrow_down_rounded),
                      keyboardInset: widget.keyboardInset,
                      debugAction: 'hide',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: widget.isMaximized
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                  child: Column(
                    children: [
                      Expanded(child: _buildBody(context)),
                      if (_shouldShowExtraKeys(context))
                        CodewalkTerminalExtraKeys(
                          key: const ValueKey<String>('terminal_extra_keys'),
                          controller: _extraKeysController,
                          requestTerminalFocus: _requestTerminalFocus,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final state = widget.controller.state;
    if (state == CodewalkTerminalState.running ||
        state == CodewalkTerminalState.starting ||
        state == CodewalkTerminalState.exited) {
      final terminalFontSize = context.select<SettingsProvider, double>(
        (settings) => settings.terminalFontSize,
      );
      return KeyedSubtree(
        key: ValueKey<int>(widget.controller.terminalGeneration),
        child: TerminalView(
          widget.controller.terminal,
          controller: _viewController,
          focusNode: _terminalFocusNode,
          autofocus: true,
          // Android terminals work better with a raw text keyboard that
          // suppresses prediction/composition side effects.
          keyboardType: defaultTargetPlatform == TargetPlatform.android
              ? TextInputType.visiblePassword
              : TextInputType.emailAddress,
          // Mobile IMEs often do not emit a hardware backspace event; keep
          // xterm's hidden edit buffer primed so delete deltas are detected.
          deleteDetection:
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS,
          onKeyEvent: widget.onTerminalKeyEvent,
          onRawTextInput: _extraKeysController.handleRawTextInput,
          textStyle: TerminalStyle(fontSize: terminalFontSize),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.terminal_rounded,
              size: 36,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              widget.controller.statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _reconnect,
              icon: const Icon(Symbols.refresh_rounded),
              label: Text(context.l10n.terminalTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalHeaderIconButton extends StatefulWidget {
  const _TerminalHeaderIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    required this.keyboardInset,
    required this.debugAction,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;
  final double keyboardInset;
  final String debugAction;

  @override
  State<_TerminalHeaderIconButton> createState() =>
      _TerminalHeaderIconButtonState();
}

class _TerminalHeaderIconButtonState extends State<_TerminalHeaderIconButton> {
  int? _pointer;
  Offset? _pointerOrigin;
  Duration? _pointerDownTime;
  bool _movedBeyondSlop = false;
  bool _keyboardWasVisible = false;
  int _activationGeneration = 0;

  bool get _canRecoverAndroidImeTap =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _handlePointerDown(PointerDownEvent event) {
    if (!_canRecoverAndroidImeTap ||
        widget.keyboardInset <= 0 ||
        event.kind != PointerDeviceKind.touch ||
        event.buttons != kPrimaryButton ||
        _pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _pointerOrigin = event.position;
    _pointerDownTime = event.timeStamp;
    _movedBeyondSlop = false;
    _keyboardWasVisible = true;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _pointerOrigin;
    if (event.pointer != _pointer || origin == null) {
      return;
    }
    if ((event.position - origin).distance > kTouchSlop) {
      _movedBeyondSlop = true;
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final pointerDownTime = _pointerDownTime;
    final pressDuration = pointerDownTime == null
        ? kLongPressTimeout
        : event.timeStamp - pointerDownTime;
    final shouldRecover =
        _keyboardWasVisible &&
        !_movedBeyondSlop &&
        _pointerOrigin != null &&
        pressDuration >= Duration.zero &&
        pressDuration < kLongPressTimeout;
    final activationGeneration = _activationGeneration;
    _clearPointerTracking();
    if (!shouldRecover) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (!mounted ||
          activationGeneration != _activationGeneration ||
          (lifecycleState != null &&
              lifecycleState != AppLifecycleState.resumed)) {
        return;
      }
      _activationGeneration += 1;
      AppLogger.debug(
        'terminal header recovered cancelled Android IME tap '
        'action=${widget.debugAction}',
      );
      widget.onPressed();
    });
  }

  void _clearPointerTracking() {
    _pointer = null;
    _pointerOrigin = null;
    _pointerDownTime = null;
    _movedBeyondSlop = false;
    _keyboardWasVisible = false;
  }

  void _handlePressed() {
    _activationGeneration += 1;
    _clearPointerTracking();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: IconButton(
        key: widget.buttonKey,
        tooltip: widget.tooltip,
        onPressed: _handlePressed,
        icon: widget.icon,
      ),
    );
  }
}
