import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';

/// The prompts the user sent in a session, oldest first: the text of each of
/// its own [UserInput] items, trimmed, without the empty ones, and at most
/// [limit] of the newest. A prompt sent twice is there twice, as in v1.
List<String> sessionInputHistory(
  Iterable<TimelineItem> items, {
  int limit = 100,
}) {
  final history = [
    for (final item in items)
      if (item case UserInput(:final text) when text.trim().isNotEmpty)
        text.trim(),
  ];
  return history.length > limit
      ? history.sublist(history.length - limit)
      : history;
}

/// Brings the session's sent prompts back into the field, as v1 does: Up
/// shows the previous prompt, Down the next one, and Down past the newest
/// gives back what was being written. The first Up or Down on a recalled
/// prompt moves the caret to its start or end, so a long prompt can still be
/// read line by line.
///
/// A recalled prompt is shown through [show], which keeps it out of the
/// saved draft; an edit ends the browsing and the edited text is the draft
/// from then on.
final class SessionInputRecall {
  SessionInputRecall({required this.show});

  final void Function(TextEditingValue value) show;

  List<String>? _history;
  int? _fromNewest;
  TextEditingValue? _stash;
  String? _shown;

  bool get browsing => _fromNewest != null;

  /// The field changed: unless it is the recalled prompt shown, the browsing
  /// ends.
  void changed(String text) {
    if (_fromNewest != null && text != _shown) end();
  }

  void end() {
    _history = null;
    _fromNewest = null;
    _stash = null;
    _shown = null;
  }

  /// Shows the previous prompt; [history] is read when the browsing starts.
  /// False when there is nothing to recall.
  bool up(TextEditingValue current, List<String> Function() history) {
    final index = _fromNewest;
    if (index == null) {
      final prompts = history();
      if (prompts.isEmpty) return false;
      _history = List.unmodifiable(prompts);
      _stash = current;
      _apply(0);
      return true;
    }
    if (_offset(current) > 0) {
      _caret(current, 0);
      return true;
    }
    if (index + 1 < _history!.length) _apply(index + 1);
    return true;
  }

  /// Shows the next prompt, or what was being written past the newest.
  /// False when not browsing.
  bool down(TextEditingValue current) {
    final index = _fromNewest;
    if (index == null) return false;
    if (_offset(current) < current.text.length) {
      _caret(current, current.text.length);
      return true;
    }
    if (index > 0) {
      _apply(index - 1);
      return true;
    }
    final stash = _stash!;
    end();
    show(stash.copyWith(composing: TextRange.empty));
    return true;
  }

  void _apply(int fromNewest) {
    final history = _history!;
    final text = history[history.length - 1 - fromNewest];
    _fromNewest = fromNewest;
    _shown = text;
    show(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  void _caret(TextEditingValue current, int offset) => show(
    current.copyWith(
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    ),
  );

  static int _offset(TextEditingValue value) => value.selection.isValid
      ? value.selection.baseOffset.clamp(0, value.text.length)
      : value.text.length;
}
