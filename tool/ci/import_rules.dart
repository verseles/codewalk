import 'dart:io';

import 'package:path/path.dart' as p;

import 'architecture/ast_rules.dart';
import 'architecture/dependency_graph.dart';
import 'architecture/manifest.dart';

/// Gate G4 for authored v2 paths. Retained v1 exclusions are temporary and
/// never permit a dependency from v2 into the excluded tree.
void main(List<String> arguments) {
  try {
    var root = Directory.current.absolute.path;
    String? manifestPath;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--help') {
        stdout.writeln(
          'dart run tool/ci/import_rules.dart [--root PATH] [--manifest PATH]',
        );
        return;
      }
      if ((argument == '--root' || argument == '--manifest') &&
          index + 1 < arguments.length) {
        final value = arguments[++index];
        if (argument == '--root') {
          root = p.normalize(p.absolute(value));
        } else {
          manifestPath = p.absolute(value);
        }
      } else {
        throw FormatException('Unknown or incomplete argument: $argument');
      }
    }
    root = Directory(root).resolveSymbolicLinksSync();
    final manifest = ArchitectureManifest.read(
      manifestPath ?? p.join(root, 'tool/ci/v2_architecture_manifest.json'),
    );
    final violations = <Violation>[];
    final graph = DependencyGraph(root, manifest, violations);
    final files = graph.governedFiles();
    for (final path in files) {
      final relative = graph.relative(path);
      final source = graph.source(path);
      if (source.errors.isNotEmpty) {
        violations.add(
          Violation(
            'syntax',
            relative,
            'Cannot establish architecture for invalid Dart: ${source.errors.first}',
          ),
        );
      }
      final count = source.contents.isEmpty
          ? 0
          : source.contents.split('\n').length -
                (source.contents.endsWith('\n') ? 1 : 0);
      if (count > 1500 && !manifest.sizeExceptions.containsKey(relative)) {
        violations.add(
          Violation(
            'file-size',
            relative,
            '$count lines exceeds the 1,500-line limit; an exact generated/vendor exception needs a recorded reason.',
          ),
        );
      }
      if (manifest.sizeExceptions[relative] == 'generated' &&
          !source.contents.contains('GENERATED CODE')) {
        violations.add(
          Violation(
            'manifest',
            relative,
            'Generated size exception requires a generated-code header.',
          ),
        );
      }
      AstRules(
        source,
        relative,
        manifest,
        violations,
        importedLocators: graph.importedLocators(path),
        widgetDeclarationNames: graph.widgetDeclarationNames(path),
        importedHarnessNames: manifest.isFeature(relative)
            ? graph.importedHarnessNames(path)
            : const {},
      ).check();
      graph.checkClosure(path);
    }
    for (final path in manifest.sizeExceptions.keys) {
      if (!File(p.join(root, path)).existsSync()) {
        violations.add(
          Violation(
            'manifest',
            path,
            'Stale size exception names a missing file.',
          ),
        );
      }
    }
    final unique = <String, Violation>{
      for (final violation in violations) violation.toString(): violation,
    };
    final sorted = unique.values.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    if (sorted.isNotEmpty) {
      for (final violation in sorted) {
        stderr.writeln(violation);
      }
      stderr.writeln(
        'V2 architecture guard failed: ${sorted.length} violation(s).',
      );
      exitCode = 1;
    } else {
      stdout.writeln(
        'V2 architecture guard passed: ${files.length} governed Dart files, ${graph.workspace.length} workspace packages.',
      );
    }
  } on Object catch (error) {
    stderr.writeln(
      'V2 architecture guard could not validate configuration: $error',
    );
    exitCode = 2;
  }
}
