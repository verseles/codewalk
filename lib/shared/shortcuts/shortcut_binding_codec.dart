import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ShortcutBindingCodec {
  ShortcutBindingCodec._();

  static const _letters = [
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyC,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyF,
    LogicalKeyboardKey.keyG,
    LogicalKeyboardKey.keyH,
    LogicalKeyboardKey.keyI,
    LogicalKeyboardKey.keyJ,
    LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.keyL,
    LogicalKeyboardKey.keyM,
    LogicalKeyboardKey.keyN,
    LogicalKeyboardKey.keyO,
    LogicalKeyboardKey.keyP,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyR,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyT,
    LogicalKeyboardKey.keyU,
    LogicalKeyboardKey.keyV,
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.keyY,
    LogicalKeyboardKey.keyZ,
  ];
  static const _digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  static const _special = {
    'escape': LogicalKeyboardKey.escape,
    'enter': LogicalKeyboardKey.enter,
    'tab': LogicalKeyboardKey.tab,
    'space': LogicalKeyboardKey.space,
    ',': LogicalKeyboardKey.comma,
  };

  static String normalize(String binding) => binding
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('command', 'meta')
      .replaceAll('cmd', 'meta')
      .replaceAll('control', 'ctrl')
      .replaceAll('option', 'alt')
      .replaceAll('comma', ',');

  static SingleActivator? parse(String binding, {TargetPlatform? platform}) {
    if (binding.length > 128) return null;
    final parts = normalize(binding).split('+');
    final trigger = _key(parts.last);
    if (trigger == null) return null;
    final modifiers = <String>{};
    for (final token in parts.take(parts.length - 1)) {
      final modifier = token == 'mod'
          ? (platform ?? defaultTargetPlatform) == TargetPlatform.macOS
                ? 'meta'
                : 'ctrl'
          : token;
      if (!const {'ctrl', 'meta', 'alt', 'shift'}.contains(modifier) ||
          !modifiers.add(modifier)) {
        return null;
      }
    }
    return SingleActivator(
      trigger,
      control: modifiers.contains('ctrl'),
      meta: modifiers.contains('meta'),
      alt: modifiers.contains('alt'),
      shift: modifiers.contains('shift'),
      includeRepeats: false,
    );
  }

  /// Compare physical chords, including aliases and modifier ordering.
  static String? fingerprint(String binding, {TargetPlatform? platform}) {
    final a = parse(binding, platform: platform);
    return a == null
        ? null
        : '${a.trigger.keyId}:${a.control}:${a.meta}:${a.alt}:${a.shift}';
  }

  static String display(String binding, {TargetPlatform? platform}) {
    final mac = (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;
    return normalize(binding)
        .split('+')
        .map(
          (token) => switch (token) {
            'mod' => mac ? 'Cmd' : 'Ctrl',
            'ctrl' => 'Ctrl',
            'meta' => 'Cmd',
            'alt' => mac ? 'Option' : 'Alt',
            'shift' => 'Shift',
            'escape' => 'Esc',
            'enter' => 'Enter',
            'tab' => 'Tab',
            'space' => 'Space',
            _ => token.toUpperCase(),
          },
        )
        .join('+');
  }

  static String? capture(KeyEvent event) {
    if (event is! KeyDownEvent || event.synthesized) return null;
    final key = event.logicalKey;
    final index = _letters.indexOf(key);
    final digit = _digits.indexOf(key);
    final special = _special.entries.where((entry) => entry.value == key);
    final token = index >= 0
        ? String.fromCharCode(97 + index)
        : digit >= 0
        ? '$digit'
        : special.isNotEmpty
        ? special.first.key
        : null;
    if (token == null) return null;
    final keyboard = HardwareKeyboard.instance;
    return [
      if (keyboard.isControlPressed) 'ctrl',
      if (keyboard.isMetaPressed) 'meta',
      if (keyboard.isAltPressed) 'alt',
      if (keyboard.isShiftPressed) 'shift',
      token,
    ].join('+');
  }

  static LogicalKeyboardKey? _key(String token) {
    if (token.length == 1) {
      final code = token.codeUnitAt(0);
      if (code >= 97 && code <= 122) return _letters[code - 97];
      if (code >= 48 && code <= 57) return _digits[code - 48];
    }
    return _special[token];
  }
}
