import 'dart:io';

Directory captureFixtures() {
  var directory = Directory.current.absolute;
  while (true) {
    final candidate = Directory(
      '${directory.path}/test/contract/fixtures/opencode/2.0.22',
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Observed transport fixtures not found.');
    }
    directory = parent;
  }
}
