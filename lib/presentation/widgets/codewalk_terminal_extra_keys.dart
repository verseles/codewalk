import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:xterm/xterm.dart';

import '../../core/i18n/l10n_context.dart';

const codewalkTerminalArrowRepeatInterval = Duration(milliseconds: 80);

/// Largest extra-key edge. Keys never grow past the standard target (#183).
const double kTerminalExtraKeyMaxSize = kMinInteractiveDimension;

/// Smallest key width before the strip wraps to a second row (#183).
/// Intentionally very low: wrapping becomes the rare safety fallback.
const double kTerminalExtraKeyMinSize = 24;

bool shouldShowCodewalkTerminalExtraKeys({
  required bool isWeb,
  required TargetPlatform platform,
  required bool hasActiveTerminal,
  required double keyboardInset,
}) {
  return !isWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS) &&
      hasActiveTerminal &&
      keyboardInset > 0;
}

class CodewalkTerminalExtraKeys extends StatelessWidget {
  const CodewalkTerminalExtraKeys({
    required this.controller,
    required this.requestTerminalFocus,
    super.key,
  });

  final CodewalkTerminalExtraKeysController controller;
  final VoidCallback requestTerminalFocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: context.l10n.terminalExtraKeys,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const keyCount = 8;
              const gap = 4.0;
              const horizontalPadding = 8.0;
              final available =
                  constraints.maxWidth -
                  horizontalPadding * 2 -
                  gap * (keyCount - 1);
              // Shrink-first (#183): keys scale down to fit one row and wrap
              // only when even the very-low floor cannot fit. No scroll (#123).
              final naturalSize = available / keyCount;
              final wraps = naturalSize < kTerminalExtraKeyMinSize;
              final keyWidth = wraps
                  ? kTerminalExtraKeyMaxSize
                  : naturalSize
                        .clamp(
                          kTerminalExtraKeyMinSize,
                          kTerminalExtraKeyMaxSize,
                        )
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 4,
                ),
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final keys = <Widget>[
                      _TerminalExtraKeyButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_escape',
                        ),
                        visibleLabel: 'Esc',
                        semanticLabel: context.l10n.terminalExtraKeyEscape,
                        tooltip: context.l10n.terminalExtraKeyEscape,
                        dimension: keyWidth,
                        onTap: () => _dispatchKey(TerminalKey.escape),
                      ),
                      _TerminalExtraKeyButton(
                        key: const ValueKey<String>('terminal_extra_key_tab'),
                        visibleLabel: 'Tab',
                        semanticLabel: context.l10n.terminalExtraKeyTab,
                        tooltip: context.l10n.terminalExtraKeyTab,
                        dimension: keyWidth,
                        onTap: () => _dispatchKey(TerminalKey.tab),
                      ),
                      _TerminalExtraKeyButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_control',
                        ),
                        visibleLabel: 'Ctrl',
                        semanticLabel: context.l10n.terminalExtraKeyControl,
                        tooltip: context.l10n.terminalExtraKeyControl,
                        dimension: keyWidth,
                        toggled: controller.controlEnabled,
                        onTap: () {
                          controller.toggleControl();
                          requestTerminalFocus();
                        },
                      ),
                      _TerminalExtraKeyButton(
                        key: const ValueKey<String>('terminal_extra_key_alt'),
                        visibleLabel: 'Alt',
                        semanticLabel: context.l10n.terminalExtraKeyAlt,
                        tooltip: context.l10n.terminalExtraKeyAlt,
                        dimension: keyWidth,
                        toggled: controller.altEnabled,
                        onTap: () {
                          controller.toggleAlt();
                          requestTerminalFocus();
                        },
                      ),
                      _arrowButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_arrow_left',
                        ),
                        terminalKey: TerminalKey.arrowLeft,
                        icon: Symbols.arrow_left_alt_rounded,
                        semanticLabel: context.l10n.terminalExtraKeyArrowLeft,
                        dimension: keyWidth,
                      ),
                      _arrowButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_arrow_up',
                        ),
                        terminalKey: TerminalKey.arrowUp,
                        icon: Symbols.arrow_upward_alt_rounded,
                        semanticLabel: context.l10n.terminalExtraKeyArrowUp,
                        dimension: keyWidth,
                      ),
                      _arrowButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_arrow_down',
                        ),
                        terminalKey: TerminalKey.arrowDown,
                        icon: Symbols.arrow_downward_alt_rounded,
                        semanticLabel: context.l10n.terminalExtraKeyArrowDown,
                        dimension: keyWidth,
                      ),
                      _arrowButton(
                        key: const ValueKey<String>(
                          'terminal_extra_key_arrow_right',
                        ),
                        terminalKey: TerminalKey.arrowRight,
                        icon: Symbols.arrow_right_alt_rounded,
                        semanticLabel: context.l10n.terminalExtraKeyArrowRight,
                        dimension: keyWidth,
                      ),
                    ];
                    if (wraps) {
                      return Wrap(
                        key: const ValueKey<String>('terminal_extra_keys_wrap'),
                        spacing: gap,
                        runSpacing: gap,
                        alignment: WrapAlignment.center,
                        children: keys,
                      );
                    }
                    return Row(
                      key: const ValueKey<String>('terminal_extra_keys_row'),
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: keys,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _arrowButton({
    required Key key,
    required TerminalKey terminalKey,
    required IconData icon,
    required String semanticLabel,
    double? dimension,
  }) {
    return _TerminalExtraKeyButton(
      key: key,
      icon: icon,
      dimension: dimension,
      semanticLabel: semanticLabel,
      onTap: () => _dispatchKey(terminalKey),
      onLongPress: () {
        controller.startArrowRepeat(terminalKey);
        requestTerminalFocus();
      },
      onPointerEnd: controller.stopRepeat,
    );
  }

  void _dispatchKey(TerminalKey key) {
    controller.dispatchKey(key);
    requestTerminalFocus();
  }
}

class _TerminalExtraKeyButton extends StatelessWidget {
  const _TerminalExtraKeyButton({
    required this.semanticLabel,
    required this.onTap,
    this.visibleLabel,
    this.icon,
    this.tooltip,
    this.toggled,
    this.onLongPress,
    this.onPointerEnd,
    super.key,
    this.dimension,
  }) : assert(visibleLabel != null || icon != null);

  final String semanticLabel;
  final String? visibleLabel;
  final IconData? icon;

  /// Key width. Null keeps the standard interactive size. Height is always
  /// the standard interactive size so the touch target stays tappable (#183).
  final double? dimension;
  final String? tooltip;
  final bool? toggled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPointerEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = toggled ?? false;
    final keyWidth = dimension ?? kMinInteractiveDimension;
    final compact = keyWidth < 40;
    Widget content = Center(
      child: icon != null
          ? Icon(icon, size: compact ? 18 : 22)
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                visibleLabel!,
                style: Theme.of(context).textTheme.labelLarge,
                maxLines: 1,
              ),
            ),
    );
    if (tooltip != null) {
      content = Tooltip(
        message: tooltip!,
        excludeFromSemantics: true,
        child: content,
      );
    }

    return Listener(
      onPointerUp: onPointerEnd == null ? null : (_) => onPointerEnd!(),
      onPointerCancel: onPointerEnd == null ? null : (_) => onPointerEnd!(),
      child: Semantics(
        button: true,
        label: semanticLabel,
        toggled: toggled,
        onTap: onTap,
        excludeSemantics: true,
        child: SizedBox(
          width: keyWidth,
          height: kMinInteractiveDimension,
          child: Material(
            color: isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              onLongPress: onLongPress,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class CodewalkTerminalExtraKeysController extends ChangeNotifier {
  Terminal? _terminal;
  TerminalInputHandler? _originalInputHandler;
  _CodewalkTerminalInputHandler? _installedInputHandler;
  Timer? _repeatTimer;
  bool _controlEnabled = false;
  bool _altEnabled = false;
  bool _disposed = false;

  bool get controlEnabled => _controlEnabled;
  bool get altEnabled => _altEnabled;

  void attach(Terminal terminal) {
    assert(!_disposed, 'Cannot attach a disposed controller.');
    if (identical(_terminal, terminal) &&
        identical(terminal.inputHandler, _installedInputHandler)) {
      return;
    }

    detach();
    final currentInputHandler = terminal.inputHandler;
    if (currentInputHandler is _CodewalkTerminalInputHandler &&
        !identical(currentInputHandler.owner, this)) {
      currentInputHandler.owner.detach();
    }
    _terminal = terminal;
    _originalInputHandler = terminal.inputHandler;
    _installedInputHandler = _CodewalkTerminalInputHandler(this);
    terminal.inputHandler = _installedInputHandler;
  }

  void detach() {
    stopRepeat();
    _clearModifiers(notify: false);
    final terminal = _terminal;
    final installedInputHandler = _installedInputHandler;
    if (terminal != null &&
        identical(terminal.inputHandler, installedInputHandler)) {
      terminal.inputHandler = _originalInputHandler;
    }
    _terminal = null;
    _originalInputHandler = null;
    _installedInputHandler = null;
  }

  void toggleControl() {
    _controlEnabled = !_controlEnabled;
    notifyListeners();
  }

  void toggleAlt() {
    _altEnabled = !_altEnabled;
    notifyListeners();
  }

  void dispatchKey(TerminalKey key) {
    stopRepeat();
    final terminal = _terminal;
    if (terminal == null) {
      _clearModifiers();
      return;
    }

    final sequence = _resolveKeyboardEvent(_eventFor(terminal, key));
    if (sequence != null) {
      terminal.textInput(sequence);
    }
  }

  void startArrowRepeat(TerminalKey key) {
    assert(_isArrowKey(key), 'Only arrow keys can repeat.');
    stopRepeat();
    final terminal = _terminal;
    if (terminal == null) {
      _clearModifiers();
      return;
    }

    final sequence = _resolveKeyboardEvent(_eventFor(terminal, key));
    if (sequence == null) {
      return;
    }

    terminal.textInput(sequence);
    _repeatTimer = Timer.periodic(codewalkTerminalArrowRepeatInterval, (_) {
      if (!identical(_terminal, terminal)) {
        stopRepeat();
        return;
      }
      terminal.textInput(sequence);
    });
  }

  void stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  bool handleRawTextInput(String text) {
    if (!_hasPendingModifiers || text.isEmpty) {
      return false;
    }

    final terminal = _terminal;
    final control = _controlEnabled;
    final alt = _altEnabled;
    _clearModifiers();
    if (terminal == null) {
      return true;
    }

    final scalars = text.runes.toList(growable: false);
    final first = String.fromCharCode(scalars.first);
    final remaining = String.fromCharCodes(scalars.skip(1));
    terminal.textInput(
      '${_modifyScalar(first, scalars.first, control: control, alt: alt)}'
      '$remaining',
    );
    return true;
  }

  void reset() {
    stopRepeat();
    _clearModifiers();
  }

  TerminalKeyboardEvent _eventFor(Terminal terminal, TerminalKey key) {
    return TerminalKeyboardEvent(
      key: key,
      shift: false,
      ctrl: false,
      alt: false,
      state: terminal,
      altBuffer: terminal.isUsingAltBuffer,
      platform: terminal.platform,
    );
  }

  String? _handleKeyboardEvent(TerminalKeyboardEvent event) {
    if (_isModifierKey(event.key)) {
      return _originalInputHandler?.call(event);
    }
    return _resolveKeyboardEvent(event);
  }

  String? _resolveKeyboardEvent(TerminalKeyboardEvent event) {
    if (!_hasPendingModifiers) {
      return _originalInputHandler?.call(event);
    }

    final modifiedEvent = event.copyWith(
      ctrl: event.ctrl || _controlEnabled,
      alt: event.alt || _altEnabled,
    );

    final arrowSuffix = _arrowSuffix(modifiedEvent.key);
    if (arrowSuffix != null &&
        (modifiedEvent.shift || modifiedEvent.ctrl || modifiedEvent.alt)) {
      final modifier = _modifierCode(modifiedEvent);
      _clearModifiers();
      return '\x1b[1;${modifier ?? 1}$arrowSuffix';
    }

    final letterIndex = _letterIndex(modifiedEvent.key);
    if (letterIndex != null && modifiedEvent.ctrl) {
      final controlCharacter = String.fromCharCode(letterIndex + 1);
      _clearModifiers();
      return modifiedEvent.alt ? '\x1b$controlCharacter' : controlCharacter;
    }
    if (letterIndex != null && modifiedEvent.alt) {
      final offset = modifiedEvent.shift ? 0x41 : 0x61;
      _clearModifiers();
      return '\x1b${String.fromCharCode(offset + letterIndex)}';
    }

    final sequence = _originalInputHandler?.call(modifiedEvent);
    if (sequence != null) {
      _clearModifiers();
    }
    return sequence;
  }

  String _modifyScalar(
    String scalar,
    int codePoint, {
    required bool control,
    required bool alt,
  }) {
    if (control) {
      final normalized = codePoint >= 0x41 && codePoint <= 0x5a
          ? codePoint + 0x20
          : codePoint;
      if (normalized >= 0x61 && normalized <= 0x7a) {
        final controlCharacter = String.fromCharCode(normalized - 0x60);
        return alt ? '\x1b$controlCharacter' : controlCharacter;
      }
      if (codePoint == 0x20) {
        return alt ? '\x1b\x00' : '\x00';
      }
      if (codePoint >= 0x5b && codePoint <= 0x5f) {
        final controlCharacter = String.fromCharCode(codePoint - 0x40);
        return alt ? '\x1b$controlCharacter' : controlCharacter;
      }
    }
    return alt ? '\x1b$scalar' : scalar;
  }

  bool get _hasPendingModifiers => _controlEnabled || _altEnabled;

  void _clearModifiers({bool notify = true}) {
    if (!_hasPendingModifiers) {
      return;
    }
    _controlEnabled = false;
    _altEnabled = false;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    detach();
    _disposed = true;
    super.dispose();
  }
}

class _CodewalkTerminalInputHandler implements TerminalInputHandler {
  const _CodewalkTerminalInputHandler(this.owner);

  final CodewalkTerminalExtraKeysController owner;

  @override
  String? call(TerminalKeyboardEvent event) =>
      owner._handleKeyboardEvent(event);
}

bool _isArrowKey(TerminalKey key) => _arrowSuffix(key) != null;

String? _arrowSuffix(TerminalKey key) {
  return switch (key) {
    TerminalKey.arrowUp => 'A',
    TerminalKey.arrowDown => 'B',
    TerminalKey.arrowRight => 'C',
    TerminalKey.arrowLeft => 'D',
    _ => null,
  };
}

int? _letterIndex(TerminalKey key) {
  if (key.index < TerminalKey.keyA.index ||
      key.index > TerminalKey.keyZ.index) {
    return null;
  }
  return key.index - TerminalKey.keyA.index;
}

String? _modifierCode(TerminalKeyboardEvent event) {
  if (event.shift && event.alt && event.ctrl) {
    return '8';
  }
  if (event.ctrl && event.alt) {
    return '7';
  }
  if (event.shift && event.ctrl) {
    return '6';
  }
  if (event.ctrl) {
    return '5';
  }
  if (event.shift && event.alt) {
    return '4';
  }
  if (event.alt) {
    return '3';
  }
  if (event.shift) {
    return '2';
  }
  return null;
}

bool _isModifierKey(TerminalKey key) {
  return key == TerminalKey.fn ||
      key == TerminalKey.fnLock ||
      key == TerminalKey.hyper ||
      key == TerminalKey.superKey ||
      key == TerminalKey.control ||
      key == TerminalKey.controlLeft ||
      key == TerminalKey.controlRight ||
      key == TerminalKey.alt ||
      key == TerminalKey.altLeft ||
      key == TerminalKey.altRight ||
      key == TerminalKey.shift ||
      key == TerminalKey.shiftLeft ||
      key == TerminalKey.shiftRight ||
      key == TerminalKey.meta ||
      key == TerminalKey.metaLeft ||
      key == TerminalKey.metaRight;
}
