// This import is the assertion: dart test must compile the public surface.
import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

void main() {
  test('public identity surface compiles on the Dart VM', () {
    const session = SessionRef(
      HostId('host'),
      HarnessInstanceId('instance'),
      'id',
    );
    expect(session.nativeId, 'id');
  });
}
