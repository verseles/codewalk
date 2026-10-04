import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final class Violation {
  const Violation(this.rule, this.path, this.message, {this.line});
  final String rule;
  final String path;
  final String message;
  final int? line;

  @override
  String toString() => '$path${line == null ? '' : ':$line'} [$rule] $message';
}

bool matchesPath(String path, String scope) =>
    scope.endsWith('/') ? path.startsWith(scope) : path == scope;

String portable(String path) => p.split(path).join('/');

final class ArchitectureManifest {
  ArchitectureManifest(this.data) {
    if (data['version'] != 1) {
      throw const FormatException('Unsupported architecture manifest version.');
    }
    rootPackage = _string(data['rootPackage'], 'rootPackage');
    final scope = _map(data['governed'], 'governed');
    paths = _paths(scope['paths'], 'governed.paths');
    entrypoints = _paths(scope['entrypoints'], 'governed.entrypoints');
    packagePrefixes = _strings(scope['packagePrefixes'], 'packagePrefixes');
    if (!paths.toSet().containsAll(const {
          'lib/app/',
          'lib/features/',
          'lib/platform/',
          'lib/shared/',
        }) ||
        !entrypoints.contains('lib/main_v2.dart') ||
        !packagePrefixes.toSet().containsAll(const {'codewalk_', 'harness_'})) {
      throw const FormatException(
        'The mandatory v2 governed scope may not be removed.',
      );
    }
    retainedLegacy = _reasonedPaths('retainedLegacy');
    vendored = _reasonedPaths('vendored');
    generated = _reasonedPaths('generated');
    compositionRoots = _paths(data['compositionRoots'], 'compositionRoots');
    if (compositionRoots.any(
      (path) => !path.startsWith('lib/app/') || !path.endsWith('.dart'),
    )) {
      throw const FormatException(
        'Composition roots must name exact Dart files inside lib/app/.',
      );
    }
    harnessNames = _strings(
      data['harnessNames'],
      'harnessNames',
    ).map(normalizeHarness).toSet();
    if (!harnessNames.containsAll(const {
      'opencode',
      'codex',
      'claude',
      'claudecode',
      'pi',
      'muse',
      'grok',
      'dsh',
    })) {
      throw const FormatException(
        'The known harness names may not be removed.',
      );
    }
    final graph = _map(data['packageDependencies'], 'packageDependencies');
    packageDependencies = {
      for (final entry in graph.entries)
        entry.key: _strings(
          entry.value,
          'dependencies of ${entry.key}',
        ).toSet(),
    };
    sizeExceptions = {};
    final exceptions = data['sizeExceptions'];
    if (exceptions is! List) {
      throw const FormatException('sizeExceptions must be a list.');
    }
    for (final entry in exceptions) {
      final exception = _map(entry, 'size exception');
      final path = _path(exception['path'], 'size exception path');
      final category = _string(
        exception['category'],
        'size exception category',
      );
      _string(exception['reason'], 'size exception reason');
      if (path.endsWith('/') || !path.endsWith('.dart')) {
        throw FormatException('Size exception must name one Dart file: $path');
      }
      final classification = switch (category) {
        'generated' => generated,
        'vendor' => vendored,
        _ => throw FormatException('Invalid exception category: $category'),
      };
      if (!classification.any((scope) => matchesPath(path, scope))) {
        throw FormatException(
          'Size exception lacks $category provenance: $path',
        );
      }
      if (sizeExceptions.containsKey(path)) {
        throw FormatException('Duplicate size exception: $path');
      }
      sizeExceptions[path] = category;
    }
    // Generated classifications are exact files, never a blanket suffix rule.
    if (generated.any(
      (path) => path.endsWith('/') || !path.endsWith('.dart'),
    )) {
      throw const FormatException('generated must list exact Dart files.');
    }
    for (final legacy in retainedLegacy) {
      if (isGoverned(legacy) ||
          paths.any((scope) => matchesPath(scope, legacy))) {
        throw FormatException(
          'Legacy exclusion overlaps governed scope: $legacy',
        );
      }
    }
    if (paths.isEmpty || packagePrefixes.isEmpty) {
      throw const FormatException('Governed scope must not be empty.');
    }
  }

  factory ArchitectureManifest.read(String path) {
    final decoded = jsonDecode(File(path).readAsStringSync());
    return ArchitectureManifest(_map(decoded, 'manifest'));
  }

  final Map<String, dynamic> data;
  late final String rootPackage;
  late final List<String> paths;
  late final List<String> entrypoints;
  late final List<String> packagePrefixes;
  late final List<String> retainedLegacy;
  late final List<String> vendored;
  late final List<String> generated;
  late final List<String> compositionRoots;
  late final Set<String> harnessNames;
  late final Map<String, Set<String>> packageDependencies;
  late final Map<String, String> sizeExceptions;

  bool isGoverned(String path) {
    if (paths.any((scope) => matchesPath(path, scope)) ||
        entrypoints.contains(path)) {
      return true;
    }
    final segments = path.split('/');
    return segments.length > 2 &&
        segments.first == 'packages' &&
        segments[2] != 'build' &&
        segments[2] != '.dart_tool' &&
        packagePrefixes.any(segments[1].startsWith);
  }

  bool isLegacy(String path) =>
      retainedLegacy.any((scope) => matchesPath(path, scope));
  bool isVendor(String path) =>
      vendored.any((scope) => matchesPath(path, scope));
  bool isComposition(String path) =>
      compositionRoots.any((scope) => matchesPath(path, scope));
  bool isFeature(String path) => path.startsWith('lib/features/');
  bool isCore(String path) => path.startsWith('packages/codewalk_core/lib/');
  bool allowsDio(String path) =>
      path.startsWith('packages/codewalk_net/') ||
      path.startsWith('packages/harness_');

  bool isClassifiedProduction(String path) =>
      isGoverned(path) || isLegacy(path) || isVendor(path);

  static String normalizeHarness(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

  List<String> _reasonedPaths(String key) {
    final entries = data[key];
    if (entries is! List) throw FormatException('$key must be a list.');
    return entries.map((entry) {
      final item = _map(entry, key);
      _string(item['reason'], '$key reason');
      return _path(item['path'], '$key path');
    }).toList();
  }

  static String _string(Object? value, String key) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a nonempty string.');
    }
    return value;
  }

  static Map<String, dynamic> _map(Object? value, String key) {
    if (value is! Map) throw FormatException('$key must be an object.');
    return Map<String, dynamic>.from(value);
  }

  static List<String> _strings(Object? value, String key) {
    if (value is! List) throw FormatException('$key must be a list.');
    return value.map((item) => _string(item, key)).toList();
  }

  static List<String> _paths(Object? value, String key) =>
      _strings(value, key).map((item) => _path(item, key)).toList();

  static String _path(Object? value, String key) {
    final path = _string(value, key);
    final withoutSlash = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    if (p.isAbsolute(path) ||
        path.contains('\\') ||
        path.contains('*') ||
        portable(p.normalize(withoutSlash)) != withoutSlash ||
        path.split('/').contains('..') ||
        withoutSlash == '.') {
      throw FormatException(
        '$key must be a normalized, explicit repository path: $path',
      );
    }
    return path;
  }
}
