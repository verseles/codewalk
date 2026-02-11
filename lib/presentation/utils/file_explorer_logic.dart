class FileTabSelectionState {
  const FileTabSelectionState({
    this.openPaths = const <String>[],
    this.activePath,
  });

  final List<String> openPaths;
  final String? activePath;

  bool get hasOpenTabs => openPaths.isNotEmpty;
}

FileTabSelectionState openFileTab(FileTabSelectionState state, String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    return state;
  }
  if (state.openPaths.contains(normalizedPath)) {
    return FileTabSelectionState(
      openPaths: List<String>.from(state.openPaths),
      activePath: normalizedPath,
    );
  }
  return FileTabSelectionState(
    openPaths: <String>[...state.openPaths, normalizedPath],
    activePath: normalizedPath,
  );
}

FileTabSelectionState closeFileTab(FileTabSelectionState state, String path) {
  final normalizedPath = path.trim();
  final index = state.openPaths.indexOf(normalizedPath);
  if (index < 0) {
    return state;
  }
  final next = List<String>.from(state.openPaths)..removeAt(index);
  if (next.isEmpty) {
    return const FileTabSelectionState();
  }
  if (state.activePath != normalizedPath) {
    return FileTabSelectionState(openPaths: next, activePath: state.activePath);
  }
  final replacementIndex = index == 0 ? 0 : index - 1;
  return FileTabSelectionState(
    openPaths: next,
    activePath: next[replacementIndex],
  );
}

FileTabSelectionState activateFileTab(
  FileTabSelectionState state,
  String path,
) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty || !state.openPaths.contains(normalizedPath)) {
    return state;
  }
  return FileTabSelectionState(
    openPaths: List<String>.from(state.openPaths),
    activePath: normalizedPath,
  );
}

List<String> rankQuickOpenPaths(
  Iterable<String> paths,
  String query, {
  int limit = 50,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final unique = <String>{};
  final ranked = <_PathRank>[];

  for (final rawPath in paths) {
    final normalizedPath = _normalizePath(rawPath);
    if (normalizedPath.isEmpty || !unique.add(normalizedPath)) {
      continue;
    }
    final basename = _basename(normalizedPath).toLowerCase();

    final band = _rankingBand(
      path: normalizedPath.toLowerCase(),
      basename: basename,
      query: normalizedQuery,
    );
    if (normalizedQuery.isNotEmpty && band == _RankingBand.none) {
      continue;
    }
    final normalizedLower = normalizedPath.toLowerCase();
    final prefersBasenameIndex =
        band == _RankingBand.exactBasename ||
        band == _RankingBand.basenamePrefix ||
        band == _RankingBand.basenameContains;
    final indexSource = prefersBasenameIndex ? basename : normalizedLower;
    final index = normalizedQuery.isEmpty
        ? 0
        : indexSource.indexOf(normalizedQuery);
    ranked.add(
      _PathRank(
        path: normalizedPath,
        band: band.index,
        matchIndex: index < 0 ? 1 << 20 : index,
        basenameLength: basename.length,
        fullLength: normalizedLower.length,
        basename: basename,
      ),
    );
  }

  ranked.sort((a, b) {
    final byBand = a.band.compareTo(b.band);
    if (byBand != 0) {
      return byBand;
    }
    final byIndex = a.matchIndex.compareTo(b.matchIndex);
    if (byIndex != 0) {
      return byIndex;
    }
    final byBaseLength = a.basenameLength.compareTo(b.basenameLength);
    if (byBaseLength != 0) {
      return byBaseLength;
    }
    final byFullLength = a.fullLength.compareTo(b.fullLength);
    if (byFullLength != 0) {
      return byFullLength;
    }
    return a.basename.compareTo(b.basename);
  });

  return ranked.take(limit).map((item) => item.path).toList(growable: false);
}

enum _RankingBand {
  exactBasename,
  basenamePrefix,
  fullPrefix,
  basenameContains,
  pathSegmentContains,
  fullContains,
  none,
}

_RankingBand _rankingBand({
  required String path,
  required String basename,
  required String query,
}) {
  if (query.isEmpty) {
    return _RankingBand.basenamePrefix;
  }
  if (basename == query) {
    return _RankingBand.exactBasename;
  }
  if (basename.startsWith(query)) {
    return _RankingBand.basenamePrefix;
  }
  if (path.startsWith(query)) {
    return _RankingBand.fullPrefix;
  }
  if (basename.contains(query)) {
    return _RankingBand.basenameContains;
  }
  if (path.contains('/$query')) {
    return _RankingBand.pathSegmentContains;
  }
  if (path.contains(query)) {
    return _RankingBand.fullContains;
  }
  return _RankingBand.none;
}

String _normalizePath(String value) {
  var normalized = value.trim().replaceAll('\\', '/');
  if (normalized.length > 1) {
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
  }
  return normalized;
}

String _basename(String path) {
  if (path.isEmpty || path == '/') {
    return path;
  }
  final separator = path.lastIndexOf('/');
  if (separator < 0 || separator == path.length - 1) {
    return path;
  }
  return path.substring(separator + 1);
}

class _PathRank {
  const _PathRank({
    required this.path,
    required this.band,
    required this.matchIndex,
    required this.basenameLength,
    required this.fullLength,
    required this.basename,
  });

  final String path;
  final int band;
  final int matchIndex;
  final int basenameLength;
  final int fullLength;
  final String basename;
}
