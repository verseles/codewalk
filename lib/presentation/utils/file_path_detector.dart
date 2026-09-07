import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Detected file path with optional line and column numbers.
class FilePathMatch {
  const FilePathMatch({
    required this.fullText,
    required this.path,
    this.lineNumber,
    this.columnNumber,
  });

  /// The full matched text (e.g. "lib/main.dart:42:10").
  final String fullText;

  /// The file path portion only (e.g. "lib/main.dart").
  final String path;

  /// Optional 1-based line number.
  final int? lineNumber;

  /// Optional 1-based column number.
  final int? columnNumber;

  @override
  String toString() =>
      'FilePathMatch(path: $path, line: $lineNumber, col: $columnNumber)';
}

/// Detects clickable file paths with optional line:column suffixes in text.
///
/// Matches patterns like:
/// - `lib/main.dart`
/// - `src/components/App.tsx:42`
/// - `path/to/file.dart:10:5`
/// - `./relative/path.py:100`
/// - `../parent/file.go:7`
///
/// Does NOT match:
/// - URLs (`https://...`, `http://...`, `ftp://...`)
/// - Paths without a file extension (reduces false positives)
/// - Windows absolute paths on non-Windows platforms
/// - Paths inside markdown fenced code blocks (handled by the caller
///   splitting text on code-block boundaries before calling detect)
class FilePathDetector {
  FilePathDetector();

  /// Common source file extensions used to anchor path detection.
  /// Requiring a known extension dramatically reduces false positives.
  static const Set<String> _knownExtensions = {
    // Dart & Flutter
    'dart', 'yaml', 'yml', 'json', 'arb',
    // Web
    'ts', 'tsx', 'js', 'jsx', 'html', 'css', 'scss', 'less', 'vue', 'svelte',
    // Python
    'py', 'pyi', 'pyx', 'toml', 'cfg', 'ini',
    // Go
    'go', 'mod', 'sum',
    // Rust
    'rs',
    // Java / Kotlin
    'java', 'kt', 'kts', 'gradle', 'xml', 'properties',
    // C / C++
    'c', 'h', 'cpp', 'hpp', 'cc', 'cxx',
    // Ruby
    'rb', 'gemspec', 'rake',
    // Swift / Obj-C
    'swift', 'm', 'mm',
    // Shell
    'sh', 'bash', 'zsh', 'fish',
    // Config / data
    'env', 'lock', 'csv', 'sql',
    // Markup / docs
    'md', 'rst', 'txt', 'adoc', 'org',
    // Protobuf / IDL
    'proto', 'thrift',
    // Docker / CI
    'dockerfile', 'containerfile',
    // Make
    'mk',
    // Lua
    'lua',
    // Zig
    'zig',
    // Nix
    'nix',
    // Haskell
    'hs', 'lhs',
    // Elixir / Erlang
    'ex', 'exs', 'erl',
    // R
    'r',
  };

  /// Pre-computed extension alternation for the regex pattern.
  /// Sorted longest-first so that e.g. 'dockerfile' matches before 'docker'.
  /// Public so that [FilePathSyntax] can reuse it for its own pattern.
  static final String extensionPattern = () {
    final sorted = _knownExtensions.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return sorted.map((e) => e.replaceAll('.', r'\.')).join('|');
  }();

  /// Regex that matches a file path with optional :line and :line:col suffix.
  ///
  /// Breakdown:
  /// - Group 1 (path): optional relative prefix (./ ../ ~/), then
  ///   one or more path segments separated by /, ending in a known extension
  /// - Group 2 (line): optional :digits
  /// - Group 3 (column): optional :digits after line
  static final RegExp _filePathRe = RegExp(
    '(?<![/\\w.:])' // negative lookbehind: not preceded by /, word char, dot, or colon
    '(' // group 1: path
    '(?:\\.{1,2}/|~/)?' // optional relative/home prefix
    '(?:[\\w.\\-]+/)+' // one or more directory segments
    '[\\w.\\-]+' // filename stem
    '\\.(?:$extensionPattern)' // known extension
    ')' // end group 1
    '(?::(\\d+))?' // group 2: optional :line
    '(?::(\\d+))?' // group 3: optional :column
    '(?![/\\w])', // negative lookahead: not followed by / or word char
  );

  /// Regex for Windows absolute paths (C:\...).
  static final RegExp _windowsPathRe = RegExp(
    '(?<![/\\w.:])'
    '('
    '[A-Za-z]:\\\\' // drive letter + colon + backslash
    '(?:[^\\s<>:"|?*]+\\\\)*' // directory segments
    '[^\\s<>:"|?*]+' // filename
    '\\.(?:$extensionPattern)'
    ')'
    '(?::(\\d+))?'
    '(?::(\\d+))?'
    '(?![/\\w])',
  );

  /// URL scheme prefix to exclude.
  static final RegExp _urlSchemeRe = RegExp(r'^https?://|^ftp://|^file://');

  /// Detects all file path matches in [text], excluding ranges inside
  /// [codeBlockRanges] (fenced code block spans that should not be linkified).
  List<FilePathMatch> detect(
    String text, {
    List<(int, int)> codeBlockRanges = const [],
  }) {
    final results = <FilePathMatch>[];
    final matches = _filePathRe.allMatches(text);

    for (final match in matches) {
      if (_isExcludedByCodeBlock(match.start, match.end, codeBlockRanges)) {
        continue;
      }
      if (_isPartOfUrl(text, match.start)) {
        continue;
      }
      final path = match[1]!;
      final line = match[2] != null ? int.tryParse(match[2]!) : null;
      final col = match[3] != null ? int.tryParse(match[3]!) : null;
      results.add(FilePathMatch(
        fullText: match[0]!,
        path: path,
        lineNumber: line,
        columnNumber: col,
      ));
    }

    // Also detect Windows paths on Windows platforms only. Guarded by
    // kIsWeb because dart:io Platform getters throw UnsupportedError on web.
    if (!kIsWeb && Platform.isWindows) {
      final winMatches = _windowsPathRe.allMatches(text);
      for (final match in winMatches) {
        if (_isExcludedByCodeBlock(match.start, match.end, codeBlockRanges)) {
          continue;
        }
        if (_isPartOfUrl(text, match.start)) {
          continue;
        }
        final path = match[1]!;
        final line = match[2] != null ? int.tryParse(match[2]!) : null;
        final col = match[3] != null ? int.tryParse(match[3]!) : null;
        results.add(FilePathMatch(
          fullText: match[0]!,
          path: path,
          lineNumber: line,
          columnNumber: col,
        ));
      }
    }

    return results;
  }

  /// Returns true if [start..end) overlaps any code-block range.
  bool _isExcludedByCodeBlock(int start, int end, List<(int, int)> ranges) {
    for (final range in ranges) {
      final (rangeStart, rangeEnd) = range;
      if (start >= rangeStart && end <= rangeEnd) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if the match at [start] is part of a URL.
  bool _isPartOfUrl(String text, int start) {
    // Check if the match is preceded by a URL scheme.
    final precedingStart = (start - 12).clamp(0, text.length);
    final preceding = text.substring(precedingStart, start);
    if (_urlSchemeRe.hasMatch(preceding)) {
      return true;
    }
    // Check if the match is inside a markdown link [text](url) —
    // look for "(path" pattern before the match.
    final linkPrefixStart = (start - 1).clamp(0, text.length);
    if (linkPrefixStart < start && text[linkPrefixStart] == '(') {
      return true;
    }
    return false;
  }

  /// Extracts code-block ranges from markdown text.
  ///
  /// Returns a list of (start, end) tuples for fenced code blocks
  /// (```...```) and indented code blocks. This is used to exclude
  /// file paths inside code blocks from linkification.
  static List<(int, int)> extractCodeBlockRanges(String text) {
    final ranges = <(int, int)>[];
    final fencedRe = RegExp(r'```[\s\S]*?```', multiLine: true);
    for (final match in fencedRe.allMatches(text)) {
      ranges.add((match.start, match.end));
    }
    return ranges;
  }
}
