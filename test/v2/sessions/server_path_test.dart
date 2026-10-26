import 'package:codewalk/shared/sessions/server_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absolute paths on POSIX and Windows servers', () {
    for (final path in ['/', '/work/app', 'C:/', r'C:\Users', r'\\srv\share']) {
      expect(isAbsoluteServerPath(path), isTrue, reason: path);
    }
    // A bare drive is drive-relative, and a lone share name is not a root.
    for (final path in ['C:', 'work/app', '', r'\\srv', '..']) {
      expect(isAbsoluteServerPath(path), isFalse, reason: path);
    }
  });

  test('a directory is named by its last segment or its root', () {
    expect(serverPathName('/work/app/'), 'app');
    expect(serverPathName('/'), '/');
    expect(serverPathName('C:/'), 'C:/');
    expect(serverPathName(r'C:\Users\me'), 'me');
    expect(serverPathName(r'\\srv\share'), r'\\srv\share');
    expect(serverPathName(r'\\srv\share\repo'), 'repo');
  });

  test('a parent stops at the root, a drive root stays a root', () {
    expect(serverPathParent('/work/app'), '/work');
    expect(serverPathParent('/work'), '/');
    expect(serverPathParent('/'), isNull);
    expect(serverPathParent('C:/work'), 'C:/');
    expect(serverPathParent(r'C:\work\app'), r'C:\work');
    expect(serverPathParent('C:/'), isNull);
    expect(serverPathParent(r'\\srv\share\repo'), r'\\srv\share');
    expect(serverPathParent(r'\\srv\share'), isNull);
    expect(serverPathParent('relative/path'), isNull);
  });

  test('entries resolve against their location, never above the root', () {
    expect(resolveServerPath('/work/app', '../lib'), '/work/lib');
    expect(resolveServerPath('/work/app', './src/../test'), '/work/app/test');
    expect(resolveServerPath('/work', '../../..'), '/');
    expect(resolveServerPath('/work/app', '/etc'), '/etc');
    expect(resolveServerPath(r'C:\work\app', r'..\lib'), r'C:\work\lib');
    expect(resolveServerPath('C:/', '..'), 'C:/');
    expect(
      resolveServerPath(r'\\srv\share\repo', '../other'),
      r'\\srv\share\other',
    );
    expect(resolveServerPath(r'\\srv\share', '..'), r'\\srv\share');
  });
}
