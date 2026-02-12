enum DiffLineType {
  add,      // + linha
  remove,   // - linha
  hunk,     // @@ -l1,c1 +l2,c2 @@
  metadata, // ---, +++, diff --git, index
  context,  // linhas sem modificação
}

class DiffLine {
  const DiffLine(this.content, this.type);
  final String content;
  final DiffLineType type;
}

/// Parse unified diff text into typed lines
List<DiffLine> parseDiffLines(String text) {
  final lines = text.split('\n');
  final result = <DiffLine>[];

  for (final line in lines) {
    DiffLineType type;

    if (line.startsWith('+++') || line.startsWith('---')) {
      // Metadata comes before add/remove check
      type = DiffLineType.metadata;
    } else if (line.startsWith('+')) {
      type = DiffLineType.add;
    } else if (line.startsWith('-')) {
      type = DiffLineType.remove;
    } else if (line.startsWith('@@')) {
      type = DiffLineType.hunk;
    } else if (line.startsWith('diff --git') ||
               line.startsWith('index ')) {
      type = DiffLineType.metadata;
    } else {
      type = DiffLineType.context;
    }

    result.add(DiffLine(line, type));
  }

  return result;
}

/// Heuristic detection of unified diff format
/// Checks first 20 lines for diff markers
bool isDiffFormat(String text) {
  final lines = text.split('\n');
  int markerCount = 0;

  for (final line in lines.take(20)) {
    if (line.startsWith('diff --git') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ') ||
        line.startsWith('@@ ')) {
      markerCount++;
      if (markerCount >= 2) {
        return true;
      }
    }
  }

  return false;
}
