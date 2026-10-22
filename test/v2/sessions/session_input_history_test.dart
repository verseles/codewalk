import 'package:codewalk/features/sessions/session_input_history.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

const _delivered = OpenValue<DeliveryState>.known(DeliveryState.delivered);
const _ref = SessionRef(HostId('a'), HarnessInstanceId('a'), 's1');

UserInput _input(String id, String text) =>
    UserInput(meta: liveMeta(_ref, id), text: text, delivery: _delivered);

TextEditingValue _value(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

/// A field driven by the recall, as the composer drives it.
final class _Field {
  _Field(this.history, [String text = '']) : value = _value(text);
  final List<String> history;
  TextEditingValue value;
  late final SessionInputRecall recall = SessionInputRecall(
    show: (next) {
      value = next;
      recall.changed(next.text);
    },
  );

  bool up() => recall.up(value, () => history);
  bool down() => recall.down(value);

  void type(String text) {
    value = _value(text);
    recall.changed(text);
  }
}

void main() {
  group('sessionInputHistory', () {
    test('keeps the sent prompts, trimmed and oldest first', () {
      final items = [
        _input('u1', '  first  '),
        AssistantText(meta: liveMeta(_ref, 'a1'), text: 'no', complete: true),
        _input('u2', '   '),
        _input('u3', 'second'),
        _input('u4', 'second'),
      ];
      expect(sessionInputHistory(items), ['first', 'second', 'second']);
    });

    test('keeps only the newest of a long session', () {
      final items = [for (var i = 0; i < 120; i++) _input('u$i', 'p$i')];
      final history = sessionInputHistory(items);
      expect(history, hasLength(100));
      expect(history.first, 'p20');
      expect(history.last, 'p119');
    });
  });

  group('SessionInputRecall', () {
    test('Up goes back through the prompts and Down gives the draft back', () {
      final field = _Field(['one', 'two'], 'half');
      expect(field.up(), isTrue);
      expect(field.value.text, 'two');
      // The caret goes to the start first, then the older prompt shows.
      expect(field.up(), isTrue);
      expect(field.value, _value('two', 0));
      expect(field.up(), isTrue);
      expect(field.value.text, 'one');
      field.up();
      expect(field.up(), isTrue);
      expect(field.value.text, 'one', reason: 'the oldest stays');

      // Down moves the caret to the end first, then the newer prompt shows.
      expect(field.down(), isTrue);
      expect(field.value, _value('one'));
      expect(field.down(), isTrue);
      expect(field.value.text, 'two');
      expect(field.down(), isTrue);
      expect(field.value, _value('half'));
      expect(field.recall.browsing, isFalse);
      expect(field.down(), isFalse);
    });

    test('Down past the newest puts the caret back where it was', () {
      final field = _Field(['one'], 'half');
      field.value = _value('half', 2);
      field.up();
      expect(field.down(), isTrue);
      expect(field.value, _value('half', 2));
    });

    test('nothing to recall leaves the key to the field', () {
      final field = _Field([], 'text');
      expect(field.up(), isFalse);
      expect(field.down(), isFalse);
      expect(field.value.text, 'text');
    });

    test('an edit ends the browsing and stays', () {
      final field = _Field(['one', 'two'], 'half');
      field.up();
      field.type('two, edited');
      expect(field.recall.browsing, isFalse);
      expect(field.down(), isFalse);
      expect(field.value.text, 'two, edited');
      // Browsing again starts from the newest and keeps the edit.
      field.up();
      expect(field.value.text, 'two');
      field.down();
      expect(field.value.text, 'two, edited');
    });

    test('the history is read when the browsing starts', () {
      final field = _Field(['one'], '');
      field.up();
      field.history.add('two');
      field.up();
      field.up();
      expect(field.value.text, 'one');
    });
  });
}
