import 'package:codewalk/presentation/utils/project_directory_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches ordered noncontiguous characters, case insensitively', () {
    expect(projectDirectoryMatchScore('CodeWalk', 'cwk'), isNotNull);
    expect(projectDirectoryMatchScore('/work/client-app', 'wcap'), isNotNull);
    expect(projectDirectoryMatchScore('codewalk', 'kwc'), isNull);
    expect(projectDirectoryMatchScore('project', 'zz'), isNull);
  });

  test('ranks exact and prefix ahead of substring and subsequence', () {
    final candidates = ['my codewalk', 'code', 'codewalk', 'c_o_d_e'];
    candidates.sort(
      (a, b) => projectDirectoryMatchScore(
        a,
        'code',
      )!.compareTo(projectDirectoryMatchScore(b, 'code')!),
    );
    expect(candidates, ['code', 'codewalk', 'my codewalk', 'c_o_d_e']);
  });

  test('accepts empty query and unicode paths', () {
    expect(projectDirectoryMatchScore('/projetos/ação', ''), 0);
    expect(projectDirectoryMatchScore('/projetos/ação', 'aç'), isNotNull);
    expect(projectDirectoryMatchScore('🚀project', '🚀p'), isNotNull);
  });
}
