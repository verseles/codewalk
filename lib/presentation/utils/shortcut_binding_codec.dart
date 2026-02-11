import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ShortcutBindingCodec {
  ShortcutBindingCodec._();

  static final Set<LogicalKeyboardKey> _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  static SingleActivator? parse(String binding) {
    final normalized = normalize(binding);
    if (normalized.isEmpty) {
      return null;
    }

    final tokens = normalized.split('+');
    var control = false;
    var meta = false;
    var alt = false;
    var shift = false;
    LogicalKeyboardKey? key;

    final isMac = defaultTargetPlatform == TargetPlatform.macOS;

    for (final token in tokens) {
      switch (token) {
        case 'mod':
          if (isMac) {
            meta = true;
          } else {
            control = true;
          }
          continue;
        case 'ctrl':
        case 'control':
          control = true;
          continue;
        case 'meta':
        case 'cmd':
        case 'command':
          meta = true;
          continue;
        case 'alt':
        case 'option':
          alt = true;
          continue;
        case 'shift':
          shift = true;
          continue;
        default:
          key = _logicalKeyFromToken(token);
      }
    }

    if (key == null) {
      return null;
    }

    return SingleActivator(
      key,
      control: control,
      meta: meta,
      alt: alt,
      shift: shift,
    );
  }

  static String normalize(String binding) {
    return binding
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('command', 'meta')
        .replaceAll('cmd', 'meta')
        .replaceAll('control', 'ctrl')
        .replaceAll('option', 'alt');
  }

  static String formatForDisplay(String binding) {
    final normalized = normalize(binding);
    if (normalized.isEmpty) {
      return 'Unassigned';
    }

    final parts = normalized
        .split('+')
        .map((token) {
          return switch (token) {
            'mod' =>
              defaultTargetPlatform == TargetPlatform.macOS ? 'Cmd' : 'Ctrl',
            'ctrl' => 'Ctrl',
            'meta' => 'Cmd',
            'alt' => 'Alt',
            'shift' => 'Shift',
            'escape' => 'Esc',
            'enter' => 'Enter',
            'tab' => 'Tab',
            _ => token.length == 1 ? token.toUpperCase() : _title(token),
          };
        })
        .toList(growable: false);

    return parts.join('+');
  }

  static String? fromKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return null;
    }
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) {
      return null;
    }

    final token = _tokenFromLogicalKey(key);
    if (token == null) {
      return null;
    }

    final parts = <String>[];
    final pressed = HardwareKeyboard.instance;

    if (pressed.isControlPressed) {
      parts.add('ctrl');
    }
    if (pressed.isMetaPressed) {
      parts.add('meta');
    }
    if (pressed.isAltPressed) {
      parts.add('alt');
    }
    if (pressed.isShiftPressed) {
      parts.add('shift');
    }
    parts.add(token);

    return parts.join('+');
  }

  static LogicalKeyboardKey? _logicalKeyFromToken(String token) {
    return switch (token) {
      'a' => LogicalKeyboardKey.keyA,
      'b' => LogicalKeyboardKey.keyB,
      'c' => LogicalKeyboardKey.keyC,
      'd' => LogicalKeyboardKey.keyD,
      'e' => LogicalKeyboardKey.keyE,
      'f' => LogicalKeyboardKey.keyF,
      'g' => LogicalKeyboardKey.keyG,
      'h' => LogicalKeyboardKey.keyH,
      'i' => LogicalKeyboardKey.keyI,
      'j' => LogicalKeyboardKey.keyJ,
      'k' => LogicalKeyboardKey.keyK,
      'l' => LogicalKeyboardKey.keyL,
      'm' => LogicalKeyboardKey.keyM,
      'n' => LogicalKeyboardKey.keyN,
      'o' => LogicalKeyboardKey.keyO,
      'p' => LogicalKeyboardKey.keyP,
      'q' => LogicalKeyboardKey.keyQ,
      'r' => LogicalKeyboardKey.keyR,
      's' => LogicalKeyboardKey.keyS,
      't' => LogicalKeyboardKey.keyT,
      'u' => LogicalKeyboardKey.keyU,
      'v' => LogicalKeyboardKey.keyV,
      'w' => LogicalKeyboardKey.keyW,
      'x' => LogicalKeyboardKey.keyX,
      'y' => LogicalKeyboardKey.keyY,
      'z' => LogicalKeyboardKey.keyZ,
      '0' => LogicalKeyboardKey.digit0,
      '1' => LogicalKeyboardKey.digit1,
      '2' => LogicalKeyboardKey.digit2,
      '3' => LogicalKeyboardKey.digit3,
      '4' => LogicalKeyboardKey.digit4,
      '5' => LogicalKeyboardKey.digit5,
      '6' => LogicalKeyboardKey.digit6,
      '7' => LogicalKeyboardKey.digit7,
      '8' => LogicalKeyboardKey.digit8,
      '9' => LogicalKeyboardKey.digit9,
      'escape' => LogicalKeyboardKey.escape,
      'enter' => LogicalKeyboardKey.enter,
      'tab' => LogicalKeyboardKey.tab,
      'space' => LogicalKeyboardKey.space,
      _ => null,
    };
  }

  static String? _tokenFromLogicalKey(LogicalKeyboardKey key) {
    final label = key.keyLabel.trim();
    if (label.length == 1) {
      final char = label.toLowerCase();
      final code = char.codeUnitAt(0);
      if ((code >= 97 && code <= 122) || (code >= 48 && code <= 57)) {
        return char;
      }
    }

    if (key == LogicalKeyboardKey.escape) {
      return 'escape';
    }
    if (key == LogicalKeyboardKey.enter) {
      return 'enter';
    }
    if (key == LogicalKeyboardKey.tab) {
      return 'tab';
    }
    if (key == LogicalKeyboardKey.space) {
      return 'space';
    }

    return null;
  }

  static String _title(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}
