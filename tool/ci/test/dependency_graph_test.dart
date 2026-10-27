import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../architecture/dependency_graph.dart';
import '../architecture/manifest.dart';

class _Fixture {
  _Fixture() {
    final packages = manifest.packageDependencies.keys;
    write('pubspec.yaml', '''
name: ${manifest.rootPackage}
environment:
  sdk: ^3.8.1
workspace:
${packages.map((name) => '  - packages/$name').join('\n')}
''');
    for (final name in packages) {
      write('packages/$name/pubspec.yaml', '''
name: $name
resolution: workspace
environment:
  sdk: ^3.8.1
''');
      write('packages/$name/lib/$name.dart', 'library;\n');
    }
    write('lib/main_v2.dart', 'void main() {}\n');
    final getIt = File(p.join(external.path, 'lib/get_it.dart'));
    getIt.parent.createSync(recursive: true);
    getIt.writeAsStringSync('class GetIt { static dynamic I; }\n');
    write(
      '.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'get_it',
            'rootUri': external.uri.toString(),
            'packageUri': 'lib/',
          },
        ],
      }),
    );
  }

  final directory = Directory.systemTemp.createTempSync('codewalk-g4-facts-');
  final external = Directory.systemTemp.createTempSync('codewalk-g4-getit-');
  final manifest = ArchitectureManifest.read(
    'tool/ci/v2_architecture_manifest.json',
  );
  final violations = <Violation>[];

  void write(String path, String contents) {
    final file = File(p.join(directory.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  String path(String relative) =>
      p.join(directory.resolveSymbolicLinksSync(), relative);

  DependencyGraph graph() => DependencyGraph(
    directory.resolveSymbolicLinksSync(),
    manifest,
    violations,
  );

  void dispose() {
    directory.deleteSync(recursive: true);
    external.deleteSync(recursive: true);
  }
}

enum _Channel { locator, lookup, harness }

const _symbols = '''
import 'package:get_it/get_it.dart';
final _privateLocator = GetIt.I;
final locator = _privateLocator;
Object service() => locator.get<Object>();
const _privateHarness = 'opencode';
const harness = _privateHarness;
''';

Set<String> _read(DependencyGraph graph, _Channel channel, String path) =>
    switch (channel) {
      _Channel.locator => graph.importedLocators(path),
      _Channel.lookup => graph.importedLookupHelpers(path),
      _Channel.harness => graph.importedHarnessNames(path),
    };

/// A bounded-degree diamond whose terminal nodes return to the entry.
/// Even empty summaries must not enumerate every path through this cycle.
({String root, int nodes, int edges}) _diamond(
  _Fixture fixture,
  int layers, {
  required bool seeded,
}) {
  var edges = 2;
  fixture.write(
    'lib/app/consumer.dart',
    "import 'n0_a.dart';\nimport 'n0_b.dart';\n",
  );
  for (var layer = 0; layer < layers; layer++) {
    for (final side in ['a', 'b']) {
      final targets = layer + 1 < layers
          ? ['n${layer + 1}_a.dart', 'n${layer + 1}_b.dart']
          : ['n0_a.dart', if (seeded) 'seed.dart'];
      edges += targets.length;
      fixture.write(
        'lib/app/n${layer}_$side.dart',
        targets.map((name) => "export '$name';\n").join(),
      );
    }
  }
  if (seeded) {
    fixture.write(
      'lib/app/seed.dart',
      "import 'package:get_it/get_it.dart';\n"
          "final locator = GetIt.I;\nconst harness = 'opencode';\n",
    );
  }
  return (
    root: fixture.path('lib/app/consumer.dart'),
    nodes: 1 + 2 * layers + (seeded ? 1 : 0),
    edges: edges,
  );
}

void main() {
  test('imports, reexports, private aliases and prefixes stay distinct', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.write('lib/app/seed.dart', _symbols);
    fixture.write('lib/app/facade.dart', '''
import 'seed.dart';
export 'seed.dart' show locator, service, harness;
final own = locator;
Object ownService() => service();
''');
    fixture.write('lib/app/consumer.dart', '''
import 'facade.dart' as p show locator, own, service, ownService, harness hide service;
''');
    final expected = {
      _Channel.locator: {'p.locator', 'p.own'},
      _Channel.lookup: {'p.locator', 'p.own', 'p.ownService'},
      _Channel.harness: {'p.harness'},
    };
    for (final order in [_Channel.values, _Channel.values.reversed]) {
      final graph = fixture.graph();
      for (final channel in order) {
        final names = _read(
          graph,
          channel,
          fixture.path('lib/app/consumer.dart'),
        );
        expect(names, expected[channel]);
        expect(() => names.add('intruder'), throwsUnsupportedError);
      }
    }
    expect(fixture.violations, isEmpty);
  });

  test('ordinary imports do not leak and reexports are not local inputs', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.write('lib/app/seed.dart', _symbols);
    fixture.write('lib/app/import_only.dart', "import 'seed.dart';\n");
    fixture.write('lib/app/export_only.dart', '''
export 'seed.dart';
Object notInScope() => locator();
''');
    fixture.write('lib/app/consumer.dart', '''
import 'import_only.dart' as hidden;
import 'export_only.dart' as visible;
''');
    final graph = fixture.graph();
    final root = fixture.path('lib/app/consumer.dart');
    expect(graph.importedLocators(root), {'visible.locator'});
    expect(graph.importedLookupHelpers(root), {
      'visible.locator',
      'visible.service',
    });
    expect(graph.importedHarnessNames(root), {'visible.harness'});
  });

  test('each conditional alternative and each export filter is preserved', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.write('lib/app/seed.dart', _symbols);
    fixture.write('lib/app/empty.dart', 'library;\n');
    fixture.write('lib/app/facade.dart', '''
export 'empty.dart' if (dart.library.html) 'seed.dart' hide locator;
export 'seed.dart' show locator;
''');
    fixture.write('lib/app/consumer.dart', "import 'facade.dart' as f;\n");
    final graph = fixture.graph();
    final root = fixture.path('lib/app/consumer.dart');
    expect(graph.importedLocators(root), {'f.locator'});
    expect(graph.importedLookupHelpers(root), {'f.locator', 'f.service'});
    expect(graph.importedHarnessNames(root), {'f.harness'});
  });

  test('late and disconnected roots reuse only completed component facts', () {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    fixture.write('lib/app/seed.dart', _symbols);
    fixture.write('lib/app/left.dart', "export 'seed.dart';\n");
    fixture.write('lib/app/left_consumer.dart', "import 'left.dart' as l;\n");
    fixture.write('lib/app/right.dart', '''
import 'left.dart' as root;
final alias = root.locator;
final read = root.service;
const rightHarness = root.harness;
''');
    fixture.write('lib/app/right_consumer.dart', "import 'right.dart';\n");
    fixture.write('lib/app/disconnected.dart', "const other = 'codex';\n");
    fixture.write(
      'lib/app/disconnected_consumer.dart',
      "import 'disconnected.dart';\n",
    );
    final leftExpected = {
      _Channel.locator: {'l.locator'},
      _Channel.lookup: {'l.locator', 'l.service'},
      _Channel.harness: {'l.harness'},
    };
    final rightExpected = {
      _Channel.locator: {'alias'},
      _Channel.lookup: {'alias', 'read'},
      _Channel.harness: {'rightHarness'},
    };
    final graph = fixture.graph();
    for (final channel in _Channel.values) {
      final left = _read(
        graph,
        channel,
        fixture.path('lib/app/left_consumer.dart'),
      );
      expect(left, leftExpected[channel]);
      expect(
        _read(graph, channel, fixture.path('lib/app/right_consumer.dart')),
        rightExpected[channel],
      );
      expect(
        _read(
          graph,
          channel,
          fixture.path('lib/app/disconnected_consumer.dart'),
        ),
        channel == _Channel.harness ? {'other'} : <String>{},
      );
      expect(left, leftExpected[channel]);
      final work = graph.summaryWork;
      expect(
        _read(graph, channel, fixture.path('lib/app/left_consumer.dart')),
        leftExpected[channel],
      );
      expect(graph.summaryWork, work);
    }
  });

  for (final layers in [8, 12, 32, 64, 128]) {
    for (final seeded in [false, true]) {
      for (final channel in _Channel.values) {
        test('cyclic summary work stays bounded '
            '($layers layers, seeded=$seeded, ${channel.name})', () {
          final fixture = _Fixture();
          addTearDown(fixture.dispose);
          final shape = _diamond(fixture, layers, seeded: seeded);
          final graph = fixture.graph();
          final expected = !seeded
              ? <String>{}
              : {channel == _Channel.harness ? 'harness' : 'locator'};
          expect(_read(graph, channel, shape.root), expected);
          expect(fixture.violations, isEmpty);
          final work = graph.summaryWork;
          stdout.writeln(
            '${channel.name} seeded=$seeded layers=$layers '
            'V=${shape.nodes} E=${shape.edges} work=$work',
          );
          final bound = 3 * (shape.nodes + shape.edges);
          expect(work.evaluations, lessThanOrEqualTo(bound));
          expect(work.transfers, lessThanOrEqualTo(2 * bound));
          for (var i = 0; i < 3; i++) {
            expect(_read(graph, channel, shape.root), expected);
          }
          expect(graph.summaryWork, work);
        });
      }
    }
  }
}
