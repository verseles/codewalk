import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'manifest.dart';

final class DartSource {
  DartSource(this.path, this.contents) {
    final result = parseString(
      content: contents,
      path: path,
      throwIfDiagnostics: false,
    );
    unit = result.unit;
    errors = result.errors.map((error) => error.toString()).toList();
    for (final directive in unit.directives) {
      if (directive is NamespaceDirective) {
        _add(directive.uri);
        for (final configuration in directive.configurations) {
          _add(configuration.uri);
        }
      } else if (directive is PartDirective) {
        _add(directive.uri);
      }
    }
  }

  final String path;
  final String contents;
  late final CompilationUnit unit;
  late final List<String> errors;
  final List<ImportEdge> edges = [];

  void _add(StringLiteral literal) {
    final uri = literal.stringValue;
    if (uri != null) edges.add(ImportEdge(uri, literal.offset));
  }

  int line(int offset) =>
      '\n'.allMatches(contents.substring(0, offset)).length + 1;
}

final class ImportEdge {
  const ImportEdge(this.uri, this.offset);
  final String uri;
  final int offset;
}

final class WorkspacePackage {
  WorkspacePackage(this.name, this.directory, this.spec);
  final String name;
  final String directory;
  final YamlMap spec;
}

/// Reads every import/export alternative; it does not select a platform branch.
/// SDK URIs are checked at their edge, not by parsing the SDK implementation.
final class DependencyGraph {
  DependencyGraph(this.root, this.manifest, this.violations) {
    _readPackages();
    _readPackageConfig();
  }

  final String root;
  final ArchitectureManifest manifest;
  final List<Violation> violations;
  final Map<String, WorkspacePackage> workspace = {};
  final Map<String, String> packageLibraries = {};
  final Map<String, DartSource> _sources = {};

  String relative(String path) => portable(p.relative(path, from: root));
  bool isLocal(String path) => p.isWithin(root, path);

  DartSource source(String path) => _sources.putIfAbsent(
    path,
    () => DartSource(path, File(path).readAsStringSync()),
  );

  Set<String> importedLocators(String path) => _importedLocators(path, {path});

  Set<String> _importedLocators(String path, Set<String> visited) {
    final names = <String>{};
    for (final directive in source(
      path,
    ).unit.directives.whereType<ImportDirective>()) {
      for (final uri in [
        directive.uri.stringValue,
        ...directive.configurations.map((item) => item.uri.stringValue),
      ]) {
        if (uri == null) continue;
        final resolved = resolve(path, uri);
        if (resolved == null || !isLocal(resolved)) continue;
        final exported = _locatorExports(resolved, {...visited});
        final visible = _visible(exported, directive.combinators);
        final prefix = directive.prefix?.name;
        names.addAll(
          visible.map((name) => prefix == null ? name : '$prefix.$name'),
        );
      }
    }
    return names;
  }

  Set<String> _locatorExports(String path, Set<String> visited) {
    if (!visited.add(path)) return {};
    final unit = source(path).unit;
    final names = <String>{};
    final imported = _importedLocators(path, visited);
    final bindings = <String, AstNode>{};
    for (final declaration in unit.declarations) {
      if (declaration is TopLevelVariableDeclaration) {
        for (final variable in declaration.variables.variables) {
          if (variable.initializer != null) {
            bindings[variable.name.lexeme] = variable.initializer!;
          }
          if (declaration.variables.type is NamedType &&
              (declaration.variables.type! as NamedType).name.lexeme ==
                  'GetIt') {
            names.add(variable.name.lexeme);
          }
        }
      } else if (declaration is FunctionDeclaration) {
        bindings[declaration.name.lexeme] = declaration.functionExpression;
      }
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (final binding in bindings.entries) {
        if (_referencesLocator(binding.value, {...names, ...imported})) {
          changed = names.add(binding.key) || changed;
        }
      }
    }
    for (final directive in unit.directives.whereType<ExportDirective>()) {
      for (final uri in [
        directive.uri.stringValue,
        ...directive.configurations.map((item) => item.uri.stringValue),
      ]) {
        if (uri == null) continue;
        final resolved = resolve(path, uri);
        if (resolved == null || !isLocal(resolved)) continue;
        names.addAll(
          _visible(
            _locatorExports(resolved, {...visited}),
            directive.combinators,
          ),
        );
      }
    }
    return names.where((name) => !name.startsWith('_')).toSet();
  }

  bool _referencesLocator(AstNode node, Set<String> names) {
    if (node is PrefixedIdentifier &&
        names.contains('${node.prefix.name}.${node.identifier.name}')) {
      return true;
    }
    if (node is SimpleIdentifier &&
        (node.name == 'GetIt' || names.contains(node.name))) {
      return true;
    }
    return node.childEntities.whereType<AstNode>().any(
      (child) => _referencesLocator(child, names),
    );
  }

  Set<String> _visible(Set<String> names, Iterable<Combinator> combinators) {
    var visible = {...names};
    for (final combinator in combinators) {
      if (combinator is ShowCombinator) {
        visible = visible.intersection(
          combinator.shownNames.map((item) => item.name).toSet(),
        );
      }
      if (combinator is HideCombinator) {
        visible.removeAll(combinator.hiddenNames.map((item) => item.name));
      }
    }
    return visible;
  }

  Set<String> importedWidgetTypes(String path) {
    final classes = <String, String>{};
    final visited = <String>{};
    final queue = <String>[path];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) continue;
      final unit = source(current).unit;
      for (final declaration
          in unit.declarations.whereType<ClassDeclaration>()) {
        final base = declaration.extendsClause?.superclass.name.lexeme;
        if (base != null) classes[declaration.namePart.typeName.lexeme] = base;
      }
      for (final alias in unit.declarations.whereType<GenericTypeAlias>()) {
        final type = alias.type;
        if (type is NamedType) classes[alias.name.lexeme] = type.name.lexeme;
      }
      for (final alias in unit.declarations.whereType<ClassTypeAlias>()) {
        classes[alias.name.lexeme] = alias.superclass.name.lexeme;
      }
      for (final directive in unit.directives.whereType<NamespaceDirective>()) {
        for (final uri in [
          directive.uri.stringValue,
          ...directive.configurations.map((item) => item.uri.stringValue),
        ]) {
          if (uri == null) continue;
          final resolved = resolve(current, uri);
          if (resolved != null && isLocal(resolved)) queue.add(resolved);
        }
      }
    }
    final widgets = <String>{
      'Widget',
      'StatelessWidget',
      'StatefulWidget',
      'State',
      'HookWidget',
      'ConsumerWidget',
      'ConsumerStatefulWidget',
      'ConsumerState',
    };
    var changed = true;
    while (changed) {
      changed = false;
      for (final entry in classes.entries) {
        if (widgets.contains(entry.value)) {
          changed = widgets.add(entry.key) || changed;
        }
      }
    }
    return widgets;
  }

  Set<String> importedHarnessNames(String path) =>
      _importedHarnessNames(path, {path});

  Set<String> _importedHarnessNames(String path, Set<String> visited) {
    final names = <String>{};
    for (final directive in source(
      path,
    ).unit.directives.whereType<ImportDirective>()) {
      for (final uri in [
        directive.uri.stringValue,
        ...directive.configurations.map((item) => item.uri.stringValue),
      ]) {
        if (uri == null) continue;
        final resolved = resolve(path, uri);
        if (resolved == null || !isLocal(resolved)) continue;
        final visible = _visible(
          _harnessExports(resolved, {...visited}),
          directive.combinators,
        );
        final prefix = directive.prefix?.name;
        names.addAll(
          visible.map((name) => prefix == null ? name : '$prefix.$name'),
        );
      }
    }
    return names;
  }

  Set<String> _harnessExports(String path, Set<String> visited) {
    if (!visited.add(path)) return {};
    final unit = source(path).unit;
    final names = <String>{};
    final imported = _importedHarnessNames(path, visited);
    final bindings = <String, Expression>{};
    for (final declaration
        in unit.declarations.whereType<TopLevelVariableDeclaration>()) {
      for (final variable in declaration.variables.variables) {
        if (variable.initializer != null) {
          bindings[variable.name.lexeme] = variable.initializer!;
        }
      }
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (final binding in bindings.entries) {
        if (_referencesHarness(binding.value, {...names, ...imported})) {
          changed = names.add(binding.key) || changed;
        }
      }
    }
    for (final directive in unit.directives.whereType<ExportDirective>()) {
      for (final uri in [
        directive.uri.stringValue,
        ...directive.configurations.map((item) => item.uri.stringValue),
      ]) {
        if (uri == null) continue;
        final resolved = resolve(path, uri);
        if (resolved != null && isLocal(resolved)) {
          names.addAll(
            _visible(
              _harnessExports(resolved, {...visited}),
              directive.combinators,
            ),
          );
        }
      }
    }
    return names.where((name) => !name.startsWith('_')).toSet();
  }

  bool _referencesHarness(AstNode node, Set<String> names) {
    if (node is StringLiteral &&
        node.stringValue != null &&
        manifest.harnessNames.contains(
          ArchitectureManifest.normalizeHarness(node.stringValue!),
        )) {
      return true;
    }
    if (node is SimpleIdentifier && names.contains(node.name)) return true;
    if (node is PrefixedIdentifier &&
        (names.contains('${node.prefix.name}.${node.identifier.name}') ||
            manifest.harnessNames.contains(
              ArchitectureManifest.normalizeHarness(node.identifier.name),
            ))) {
      return true;
    }
    return node.childEntities.whereType<AstNode>().any(
      (child) => _referencesHarness(child, names),
    );
  }

  List<String> governedFiles() {
    final files = <String>[];
    for (final entrypoint in manifest.entrypoints) {
      if (!File(p.join(root, entrypoint)).existsSync()) {
        violations.add(
          Violation('scope', entrypoint, 'Required v2 entry point is missing.'),
        );
      }
    }
    for (final directory in ['lib', 'packages']) {
      final tree = Directory(p.join(root, directory));
      if (!tree.existsSync()) continue;
      for (final entity in tree.listSync(recursive: true, followLinks: false)) {
        final entityPath = relative(entity.path);
        if (RegExp(
          r'^packages/[^/]+/(?:\.dart_tool|build)(?:/|$)',
        ).hasMatch(entityPath)) {
          continue;
        }
        if (entity is Link) {
          final path = relative(entity.path);
          if (manifest.isGoverned(path) ||
              manifest.isGoverned('$path/') ||
              !manifest.isLegacy(path) &&
                  !manifest.isVendor(path) &&
                  (path.startsWith('lib/') ||
                      RegExp('^packages/[^/]+/?\u0024').hasMatch(path))) {
            violations.add(
              Violation(
                'scope',
                path,
                'Governed source may not be hidden behind a symlink.',
              ),
            );
          }
          continue;
        }
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = relative(entity.path);
        if (manifest.isGoverned(path)) {
          files.add(p.normalize(entity.absolute.path));
        } else if (_production(path) &&
            !manifest.isClassifiedProduction(path)) {
          violations.add(
            Violation(
              'scope',
              path,
              'Authored production path is not classified in the transitional manifest.',
            ),
          );
        }
      }
    }
    files.sort();
    return files;
  }

  bool _production(String path) =>
      path.startsWith('lib/') || RegExp('^packages/[^/]+/lib/').hasMatch(path);

  String? resolve(String importer, String uri) {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return null;
    String? target;
    if (parsed.scheme == 'package') {
      final segments = parsed.pathSegments;
      if (segments.length < 2) return null;
      final library = packageLibraries[segments.first];
      if (library == null ||
          segments.any((part) => part == '..' || part == '.')) {
        return null;
      }
      target = p.joinAll([library, ...segments.skip(1)]);
      if (!p.isWithin(library, p.normalize(target))) return null;
    } else if (parsed.scheme.isEmpty &&
        !parsed.hasAuthority &&
        !p.isAbsolute(parsed.path)) {
      target = p.join(p.dirname(importer), parsed.toFilePath());
    }
    if (target == null) return null;
    final normalized = p.normalize(p.absolute(target));
    if (!File(normalized).existsSync()) return null;
    // A symlink must not turn a harmless-looking local path into an excluded leaf.
    return File(normalized).resolveSymbolicLinksSync();
  }

  void checkClosure(String origin) {
    final originPath = relative(origin);
    final visited = <String>{};
    final queue = <(String, List<String>, bool)>[
      (origin, [originPath], manifest.allowsDio(originPath)),
    ];
    final emitted = <String>{};
    void fail(String rule, String message, List<String> route, {int? line}) {
      final identity = '$rule|$message';
      if (!emitted.add(identity)) return;
      violations.add(
        Violation(
          rule,
          originPath,
          '$message Via ${route.join(' → ')}.',
          line: line,
        ),
      );
    }

    while (queue.isNotEmpty) {
      final (path, route, throughNetwork) = queue.removeLast();
      if (!visited.add('$path|$throughNetwork')) continue;
      final localPath = isLocal(path) ? relative(path) : path;
      if (isLocal(path) && manifest.isLegacy(localPath)) {
        fail('legacy-import', 'New v2 code reaches retained v1 code', route);
        continue;
      }
      if (isLocal(path) &&
          !manifest.isGoverned(localPath) &&
          !manifest.isVendor(localPath)) {
        fail('scope', 'Dependency reaches unclassified local Dart code', route);
      }
      if (manifest.isFeature(originPath) &&
          localPath.startsWith('packages/harness_')) {
        fail(
          'feature-harness',
          'Features must consume canonical ports, not harness packages',
          route,
        );
      }
      if (manifest.isCore(originPath) &&
          isLocal(path) &&
          !_coreLeaf(localPath)) {
        fail(
          'core-purity',
          'Core reaches app, transport or harness code',
          route,
        );
        continue;
      }
      final node = source(path);
      for (final edge in node.edges) {
        final uri = edge.uri;
        final edgeRoute = [...route, uri];
        if (uri.startsWith('package:dio/') &&
            !throughNetwork &&
            !manifest.allowsDio(localPath)) {
          fail(
            'dio-boundary',
            'Dio must be reached through a net/harness package',
            edgeRoute,
            line: path == origin ? node.line(edge.offset) : null,
          );
        }
        if (manifest.isCore(originPath) && !_pureUri(uri)) {
          fail(
            'core-purity',
            'Core reaches platform or protocol dependency $uri',
            edgeRoute,
            line: path == origin ? node.line(edge.offset) : null,
          );
        }
        if (isLocal(path) && manifest.isGoverned(localPath)) {
          if (uri.startsWith('package:dio/') &&
              !manifest.allowsDio(localPath)) {
            fail(
              'dio-boundary',
              'Dio is allowed only in net/harness packages ($localPath)',
              edgeRoute,
              line: path == origin ? node.line(edge.offset) : null,
            );
          }
          if (uri.startsWith('package:get_it/') &&
              !manifest.isComposition(localPath)) {
            fail(
              'get-it-boundary',
              'get_it is allowed only in the composition root ($localPath)',
              edgeRoute,
              line: path == origin ? node.line(edge.offset) : null,
            );
          }
        }
        if (manifest.isFeature(originPath) &&
            RegExp('^package:harness_[^/]+/').hasMatch(uri)) {
          fail(
            'feature-harness',
            'Features reach harness import $uri',
            edgeRoute,
            line: path == origin ? node.line(edge.offset) : null,
          );
        }
        if (uri.startsWith('dart:')) continue;
        final resolved = resolve(path, uri);
        if (resolved == null) {
          fail(
            'unresolved-import',
            'Cannot prove dependency boundary for $uri',
            edgeRoute,
            line: path == origin ? node.line(edge.offset) : null,
          );
          continue;
        }
        if (isLocal(path) &&
            !isLocal(resolved) &&
            Uri.parse(uri).scheme.isEmpty) {
          fail(
            'scope',
            'Relative dependency escapes the repository',
            edgeRoute,
          );
          continue;
        }
        queue.add((
          resolved,
          edgeRoute,
          throughNetwork ||
              manifest.allowsDio(
                isLocal(resolved) ? relative(resolved) : resolved,
              ),
        ));
      }
    }
  }

  bool _coreLeaf(String path) =>
      path.startsWith('packages/codewalk_core/lib/') || manifest.isVendor(path);

  bool _pureUri(String uri) {
    if (uri.startsWith('dart:')) {
      return const {
        'dart:async',
        'dart:collection',
        'dart:convert',
        'dart:core',
        'dart:math',
        'dart:typed_data',
      }.contains(uri);
    }
    if (!uri.startsWith('package:')) return true;
    final name = Uri.parse(uri).pathSegments.first;
    return name != manifest.rootPackage &&
        name != 'codewalk_net' &&
        !name.startsWith('harness_') &&
        !name.startsWith('flutter') &&
        !const {
          'dio',
          'http',
          'web_socket_channel',
          'grpc',
          'ffi',
          'web',
        }.contains(name);
  }

  void _readPackages() {
    final rootSpec = _pubspec(p.join(root, 'pubspec.yaml'));
    if (rootSpec == null) return;
    if (rootSpec['name'] != manifest.rootPackage) {
      violations.add(
        const Violation(
          'workspace',
          'pubspec.yaml',
          'Root package name differs from the architecture manifest.',
        ),
      );
    }
    packageLibraries[manifest.rootPackage] = p.join(root, 'lib');
    final listed = rootSpec['workspace'];
    final entries = listed is YamlList
        ? listed.whereType<String>().toList()
        : <String>[];
    if (listed is! YamlList) {
      violations.add(
        const Violation(
          'workspace',
          'pubspec.yaml',
          'Root must declare an explicit pub workspace.',
        ),
      );
    }
    final packageTree = Directory(p.join(root, 'packages'));
    if (packageTree.existsSync()) {
      for (final entity in packageTree.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final directory = p.basename(entity.path);
        if (!manifest.packagePrefixes.any(directory.startsWith)) continue;
        final specPath = p.join(entity.path, 'pubspec.yaml');
        final spec = _pubspec(specPath);
        if (spec == null) continue;
        final name = spec['name'];
        if (name is! String ||
            name != directory ||
            workspace.containsKey(name)) {
          violations.add(
            Violation(
              'workspace',
              relative(specPath),
              'Workspace package must have a unique name matching its directory.',
            ),
          );
          continue;
        }
        workspace[name] = WorkspacePackage(name, entity.path, spec);
        packageLibraries[name] = p.join(entity.path, 'lib');
        if (spec['resolution'] != 'workspace' ||
            !entries.contains('packages/$directory')) {
          violations.add(
            Violation(
              'workspace',
              relative(specPath),
              'Governed package must use resolution: workspace and an explicit root workspace entry.',
            ),
          );
        }
      }
    }
    for (final name in manifest.packageDependencies.keys) {
      if (!workspace.containsKey(name)) {
        violations.add(
          Violation(
            'workspace',
            'pubspec.yaml',
            'Required workspace package is missing: $name.',
          ),
        );
      }
    }
    for (final entry in entries) {
      if (entry != portable(p.normalize(entry)) ||
          p.isAbsolute(entry) ||
          entry.split('/').contains('..') ||
          !File(p.join(root, entry, 'pubspec.yaml')).existsSync()) {
        violations.add(
          Violation(
            'workspace',
            'pubspec.yaml',
            'Invalid explicit workspace entry: $entry.',
          ),
        );
      }
    }
    for (final package in workspace.values) {
      final path = relative(p.join(package.directory, 'pubspec.yaml'));
      final allowed = manifest.packageDependencies[package.name];
      if (allowed == null) {
        violations.add(
          Violation(
            'workspace',
            path,
            'Package dependency policy must be explicitly registered.',
          ),
        );
        continue;
      }
      final dependencies = package.spec['dependencies'];
      if (dependencies is! YamlMap) continue;
      for (final dependency in dependencies.entries) {
        final name = dependency.key.toString();
        if ((workspace.containsKey(name) || name == manifest.rootPackage) &&
            !allowed.contains(name)) {
          violations.add(
            Violation(
              'package-layering',
              path,
              '${package.name} may not depend on $name.',
            ),
          );
        }
        if (package.name == 'codewalk_core' &&
            !_pureUri('package:$name/library.dart')) {
          violations.add(
            Violation(
              'core-purity',
              path,
              'Core may not declare platform/protocol dependency $name.',
            ),
          );
        }
        final value = dependency.value;
        if (value is YamlMap && value['path'] is String) {
          final target = p.normalize(
            p.join(package.directory, value['path'] as String),
          );
          final targetSpec = _pubspec(p.join(target, 'pubspec.yaml'));
          if (targetSpec == null || targetSpec['name'] != name) {
            violations.add(
              Violation(
                'workspace',
                path,
                'Path dependency $name does not resolve to a package with the same name.',
              ),
            );
          }
        }
      }
    }
  }

  YamlMap? _pubspec(String path) {
    if (!File(path).existsSync()) {
      violations.add(
        Violation('workspace', relative(path), 'Required pubspec is missing.'),
      );
      return null;
    }
    final value = loadYaml(File(path).readAsStringSync());
    if (value is! YamlMap) {
      violations.add(
        Violation('workspace', relative(path), 'Pubspec must be a YAML map.'),
      );
      return null;
    }
    return value;
  }

  void _readPackageConfig() {
    final configFile = File(p.join(root, '.dart_tool', 'package_config.json'));
    if (!configFile.existsSync()) return;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    for (final item in config['packages'] as List<dynamic>) {
      final package = item as Map<String, dynamic>;
      final name = package['name'] as String;
      if (packageLibraries.containsKey(name)) continue;
      final base = configFile.uri.resolve(package['rootUri'] as String);
      if (base.scheme == 'file') {
        packageLibraries[name] = p.normalize(
          p.join(
            base.toFilePath(),
            (package['packageUri'] as String?) ?? 'lib/',
          ),
        );
      }
    }
  }
}
