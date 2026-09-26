import 'package:codewalk/core/utils/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('path_utils', () {
    test('drive-root joins parents and containment prefixes agree', () {
      expect(joinParentPath('C:/', 'apps'), 'C:/apps');
      expect(joinParentPath('C:/apps', 'file.txt'), 'C:/apps/file.txt');
      expect(parentFilePath('C:/file.txt'), 'C:/');
      expect(parentFilePath('C:/apps/file.txt'), 'C:/apps');
      expect(parentFilePath('C:/'), 'C:/');
      expect(filePathChildPrefix('C:/'), 'C:/');
      expect(filePathChildPrefix('C:/apps'), 'C:/apps/');
      expect(
        'C:/apps-other'.startsWith(filePathChildPrefix('C:/apps')),
        isFalse,
      );
      expect(isAbsoluteFilePath('C:/file.txt'), isTrue);
      expect(isAbsoluteFilePath('C:file.txt'), isFalse);
      expect(isAbsoluteFilePath(r'\\server\share'), isTrue);
      expect(parentFilePath('/repo/file.txt'), '/repo');
      expect(joinParentPath('.', 'file.txt'), 'file.txt');
    });
    test('normalizeOptionalFilePath trims separators and placeholders', () {
      expect(normalizeOptionalFilePath(' /repo/plain// '), '/repo/plain');
      expect(normalizeOptionalFilePath(r'\repo\plain\'), '/repo/plain');
      expect(normalizeOptionalFilePath('///'), '/');
      expect(normalizeOptionalFilePath('-'), isNull);
      expect(normalizeOptionalFilePath('   '), isNull);
    });

    test('areEquivalentFilePaths compares normalized paths', () {
      expect(areEquivalentFilePaths('/repo/plain/', '/repo/plain'), isTrue);
      expect(areEquivalentFilePaths(r'\repo\plain', '/repo/plain'), isTrue);
      expect(areEquivalentFilePaths('/repo/plain', '/repo/other'), isFalse);
    });
    test(
      'Windows drive roots stay absolute while drive-relative paths remain distinct',
      () {
        expect(normalizeFilePath('C:\\'), 'C:/');
        expect(normalizeFilePath('c:////'), 'c:/');
        expect(normalizeOptionalFilePath('C:/'), 'C:/');
        expect(normalizeFilePath('C:'), 'C:');
        expect(areEquivalentFilePaths('C:/', 'C:'), isFalse);
        expect(fileBasename('C:\\'), 'C:/');
        expect(normalizeFilePath(r'\\server\share\'), '//server/share');
      },
    );
  });
}
