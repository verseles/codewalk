import 'dart:convert';

import 'package:codewalk_core/codewalk_core.dart';
import 'package:harness_opencode/harness_opencode.dart';
import 'package:test/test.dart';

import 'history_test_data.dart';

ItemId _id(Object? value) => ItemId(jsonEncode(value));

void main() {
  const message = 'msg_0193a1b2c3d4ABCDEFGHIJKLMN';
  final key = historyRef.storageKey;

  test('decodes the native message id of an inbox or history item', () {
    expect(
      openCodeMessageIdOf(_id([key, message, 'user', 0]), historyRef),
      message,
    );
    expect(
      openCodeMessageIdOf(_id([key, message, 'text', 'part_1']), historyRef),
      message,
    );
  });

  test('ignores other sessions, shapes and non-message ids', () {
    final other = SessionRef(historyRef.host, historyRef.harness, 'ses_other');
    expect(openCodeMessageIdOf(_id([key, message, 'user', 0]), other), isNull);
    expect(
      openCodeMessageIdOf(_id([key, 'evt_1', 'notice', 0]), historyRef),
      isNull,
    );
    expect(
      openCodeMessageIdOf(_id([key, message, 'user']), historyRef),
      isNull,
    );
    expect(openCodeMessageIdOf(_id([key, message, 7, 0]), historyRef), isNull);
    expect(openCodeMessageIdOf(const ItemId('not json'), historyRef), isNull);
    expect(
      openCodeMessageIdOf(
        _id([key, 'msg_${'a' * (64 * 1024)}', 'user', 0]),
        historyRef,
      ),
      isNull,
    );
  });
}
