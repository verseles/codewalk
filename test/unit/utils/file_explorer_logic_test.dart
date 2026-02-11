import 'package:flutter_test/flutter_test.dart';

import 'package:codewalk/presentation/utils/file_explorer_logic.dart';

void main() {
  group('rankQuickOpenPaths', () {
    test('prioritizes exact and prefix basename matches', () {
      final ranked = rankQuickOpenPaths(<String>[
        '/repo/lib/chat_page.dart',
        '/repo/lib/chat_provider.dart',
        '/repo/docs/chat.md',
        '/repo/lib/pages/home.dart',
      ], 'chat');

      expect(ranked.first, '/repo/docs/chat.md');
      expect(ranked[1], '/repo/lib/chat_page.dart');
      expect(ranked[2], '/repo/lib/chat_provider.dart');
    });

    test('filters out unrelated paths when query is not empty', () {
      final ranked = rankQuickOpenPaths(<String>[
        '/repo/a.txt',
        '/repo/lib/main.dart',
        '/repo/test/widget.dart',
      ], 'main');
      expect(ranked, <String>['/repo/lib/main.dart']);
    });
  });

  group('file tab reducer', () {
    test(
      'open + activate + close follows deterministic active tab selection',
      () {
        var state = const FileTabSelectionState();
        state = openFileTab(state, '/repo/a.dart');
        state = openFileTab(state, '/repo/b.dart');
        state = openFileTab(state, '/repo/c.dart');
        expect(state.activePath, '/repo/c.dart');

        state = activateFileTab(state, '/repo/b.dart');
        expect(state.activePath, '/repo/b.dart');

        state = closeFileTab(state, '/repo/b.dart');
        expect(state.openPaths, <String>['/repo/a.dart', '/repo/c.dart']);
        expect(state.activePath, '/repo/a.dart');
      },
    );

    test('closing last tab clears active selection', () {
      var state = const FileTabSelectionState();
      state = openFileTab(state, '/repo/one.txt');
      expect(state.activePath, '/repo/one.txt');

      state = closeFileTab(state, '/repo/one.txt');
      expect(state.openPaths, isEmpty);
      expect(state.activePath, isNull);
    });
  });
}
