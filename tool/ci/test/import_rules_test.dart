import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory compiled;
  late String executable;
  late Map<String, dynamic> manifest;

  setUpAll(() async {
    manifest =
        jsonDecode(
              File('tool/ci/v2_architecture_manifest.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    compiled = Directory.systemTemp.createTempSync('codewalk-g4-cli-');
    executable = p.join(compiled.path, 'guard.dill');
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      'tool/ci/import_rules.dart',
      '-o',
      executable,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  tearDownAll(() => compiled.deleteSync(recursive: true));

  Future<ProcessResult> run({
    Map<String, String> files = const {},
    void Function(Map<String, dynamic>)? changeManifest,
    void Function(String)? changeTree,
  }) async {
    final tree = Directory.systemTemp.createTempSync('codewalk-g4-fixture-');
    final cache = Directory.systemTemp.createTempSync('codewalk-g4-external-');
    void write(String path, String contents) {
      final file = File(
        path.startsWith('.dart_tool/stubs/')
            ? p.join(cache.path, path.substring('.dart_tool/stubs/'.length))
            : p.join(tree.path, path),
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    try {
      const packages = [
        'codewalk_core',
        'codewalk_net',
        'harness_opencode',
        'harness_host',
      ];
      write('pubspec.yaml', '''
name: codewalk
environment:
  sdk: ^3.8.1
workspace:
${packages.map((name) => '  - packages/$name').join('\n')}
dependencies:
${packages.map((name) => '  $name: 0.0.0').join('\n')}
''');
      for (final name in packages) {
        write('packages/$name/pubspec.yaml', '''
name: $name
version: 0.0.0
resolution: workspace
environment:
  sdk: ^3.8.1
''');
        write('packages/$name/lib/$name.dart', 'library;\n');
      }
      write('lib/main_v2.dart', 'void main() {}\n');
      write('lib/app/composition_root.dart', 'void registerServices() {}\n');
      write('lib/core/legacy.dart', 'class OldService {}\n');
      final fixtureManifest =
          jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
      changeManifest?.call(fixtureManifest);
      write(
        'tool/ci/v2_architecture_manifest.json',
        jsonEncode(fixtureManifest),
      );
      final external = <Map<String, dynamic>>[];
      for (final name in ['flutter', 'dio', 'get_it', 'facade']) {
        final path = '.dart_tool/stubs/$name';
        external.add({
          'name': name,
          'rootUri': Directory(p.join(cache.path, name)).uri.toString(),
          'packageUri': 'lib/',
        });
        write('$path/lib/$name.dart', 'library;\n');
      }
      write('.dart_tool/stubs/flutter/lib/widgets.dart', 'library;\n');
      write(
        '.dart_tool/package_config.json',
        jsonEncode({'configVersion': 2, 'packages': external}),
      );
      files.forEach(write);
      changeTree?.call(tree.path);
      return await Process.run(Platform.resolvedExecutable, [
        executable,
        '--root',
        tree.path,
      ]);
    } finally {
      tree.deleteSync(recursive: true);
      cache.deleteSync(recursive: true);
    }
  }

  Future<void> reject(
    String rule,
    Map<String, String> files, {
    String? path,
  }) async {
    final result = await run(files: files);
    expect(result.exitCode, 1, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stderr.toString(), contains('[$rule]'));
    if (path != null) expect(result.stderr.toString(), contains(path));
  }

  test('real CLI accepts explicit workspace and pure foundation', () async {
    final result = await run();
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString(), contains('4 workspace packages'));
  });

  for (final uri in [
    'dart:io',
    'dart:ui',
    'dart:html',
    'dart:ffi',
    'dart:js_interop',
    'package:flutter/widgets.dart',
    'package:dio/dio.dart',
    'package:codewalk_net/codewalk_net.dart',
    'package:harness_opencode/harness_opencode.dart',
    'package:codewalk/shared/plain.dart',
  ]) {
    test(
      'pure core rejects $uri',
      () => reject('core-purity', {
        'packages/codewalk_core/lib/codewalk_core.dart': "import '$uri';\n",
        'lib/shared/plain.dart': 'class Plain {}\n',
      }, path: 'packages/codewalk_core/lib/codewalk_core.dart'),
    );
  }

  test(
    'external facade cannot hide platform imports from core',
    () => reject('core-purity', {
      'packages/codewalk_core/lib/codewalk_core.dart':
          "export 'package:facade/facade.dart';\n",
      '.dart_tool/stubs/facade/lib/facade.dart': "import 'dart:io';\n",
    }),
  );

  test('pure external facade remains valid for core', () async {
    final result = await run(
      files: {
        'packages/codewalk_core/lib/codewalk_core.dart':
            "export 'package:facade/facade.dart';\n",
        '.dart_tool/stubs/facade/lib/facade.dart':
            "import 'dart:collection';\nclass Value {}\n",
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test(
    'external facade cannot hide Dio from shared app code',
    () => reject('dio-boundary', {
      'lib/shared/network.dart': "export 'package:facade/facade.dart';\n",
      '.dart_tool/stubs/facade/lib/facade.dart':
          "import 'package:dio/dio.dart';\n",
    }),
  );

  test('Dio stays in transport and harness packages', () async {
    final result = await run(
      files: {
        'packages/codewalk_net/lib/codewalk_net.dart':
            "import 'package:dio/dio.dart';\n",
        'packages/harness_opencode/lib/harness_opencode.dart':
            "import 'package:codewalk_net/codewalk_net.dart';\n",
        'lib/app/bootstrap.dart':
            "import 'package:harness_opencode/harness_opencode.dart';\n",
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    await reject('dio-boundary', {
      'lib/platform/direct.dart': "import 'package:dio/dio.dart';\n",
    });
  });

  test(
    'features reject direct and exported harness facades',
    () => reject('feature-harness', {
      'lib/features/chat/page.dart':
          "import 'package:codewalk/shared/adapter.dart' as wire;\n",
      'lib/shared/adapter.dart':
          "export 'package:harness_opencode/harness_opencode.dart' show Adapter;\n",
    }, path: 'lib/features/chat/page.dart'),
  );

  for (final kind in ['import', 'export']) {
    test(
      'all conditional $kind alternatives are checked',
      () => reject('legacy-import', {
        'lib/shared/choice.dart':
            "$kind 'safe.dart' if (dart.library.io) '../core/legacy.dart';\n",
        'lib/shared/safe.dart': 'class Safe {}\n',
      }),
    );
  }

  test(
    'normalized paths, export chains and cycles cannot hide legacy',
    () => reject('legacy-import', {
      'lib/features/chat/page.dart': "import '../../shared/one.dart';\n",
      'lib/shared/one.dart': "export 'two.dart';\n",
      'lib/shared/two.dart':
          "export 'one.dart';\nexport '../shared/../core/legacy.dart';\n",
    }, path: 'lib/features/chat/page.dart'),
  );

  test(
    'package-prefixed legacy import is forbidden',
    () => reject('legacy-import', {
      'lib/app/leak.dart': "import 'package:codewalk/core/legacy.dart';\n",
    }),
  );

  test(
    'unresolved dependencies fail closed',
    () => reject('unresolved-import', {
      'lib/shared/unknown.dart':
          "import 'package:unregistered/unknown.dart';\n",
    }),
  );

  test(
    'part of is rejected even in a small file',
    () => reject('part-of', {
      'lib/shared/fragment.dart': "part of 'whole.dart';\n",
    }),
  );

  test(
    'line limit applies to generated-looking suffixes',
    () => reject('file-size', {
      'lib/shared/oversized.g.dart':
          '${List.filled(1501, '// line').join('\n')}\n',
    }),
  );

  test('exact size exception never waives import rules', () async {
    final result = await run(
      files: {
        'lib/shared/generated.dart':
            "// GENERATED CODE\nimport '../core/legacy.dart';\n${List.filled(1500, '// line').join('\n')}\n",
      },
      changeManifest: (value) {
        (value['generated'] as List).add({
          'path': 'lib/shared/generated.dart',
          'reason': 'Recorded generator output.',
        });
        (value['sizeExceptions'] as List).add({
          'path': 'lib/shared/generated.dart',
          'category': 'generated',
          'reason': 'Recorded generator emits one large library.',
        });
      },
    );
    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('[legacy-import]'));
    expect(result.stderr.toString(), isNot(contains('[file-size]')));
  });

  test('generated exception without provenance marker fails', () async {
    final result = await run(
      files: {'lib/shared/not_generated.dart': 'class Authored {}\n'},
      changeManifest: (value) {
        (value['generated'] as List).add({
          'path': 'lib/shared/not_generated.dart',
          'reason': 'Claimed output.',
        });
        (value['sizeExceptions'] as List).add({
          'path': 'lib/shared/not_generated.dart',
          'category': 'generated',
          'reason': 'Claimed size.',
        });
      },
    );
    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('[manifest]'));
  });

  for (final path in [
    'lib/mystery/new.dart',
    'packages/unknown/lib/new.dart',
  ]) {
    test(
      'unclassified production path fails: $path',
      () => reject('scope', {path: 'class Unknown {}\n'}),
    );
  }

  test('missing entrypoint fails', () async {
    final result = await run(
      changeManifest: (value) => (value['governed'] as Map)['entrypoints'] = [
        'lib/main_v2.dart',
        'lib/absent_v2.dart',
      ],
    );
    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('[scope]'));
  });

  test(
    'package graph rejects reverse dependency',
    () => reject('package-layering', {
      'packages/codewalk_core/pubspec.yaml': '''
name: codewalk_core
resolution: workspace
dependencies:
  harness_opencode: 0.0.0
''',
    }),
  );

  test(
    'explicit workspace membership is required',
    () => reject('workspace', {
      'packages/codewalk_net/pubspec.yaml':
          'name: codewalk_net\nresolution: independent\n',
    }),
  );

  test('mandatory scope and harness names cannot be removed', () async {
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (value) =>
          ((value['governed'] as Map)['paths'] as List).remove('lib/features/'),
      (value) => value['harnessNames'] = <String>[],
      (value) => value['compositionRoots'] = ['lib/app/'],
      (value) => value['sizeExceptions'] = [
        {
          'path': 'lib/shared/',
          'category': 'generated',
          'reason': 'Broad exemption.',
        },
      ],
    ]) {
      final result = await run(changeManifest: mutation);
      expect(result.exitCode, 2, reason: result.stderr.toString());
    }
  });

  for (final expression in [
    "kind == 'OpenCode'",
    "'opencode' != kind",
    'kind == HarnessKind.opencode',
    "['opencode', 'codex'].contains(kind)",
    "{'opencode': true}.containsKey(kind)",
    "kind == 'open' 'code'",
    "kind == 'open\\u0063ode'",
  ]) {
    test(
      'features reject harness expression $expression',
      () => reject('harness-branch', {
        'lib/features/chat/branch.dart':
            'bool show(dynamic kind) => $expression;\n',
      }),
    );
  }

  for (final source in [
    "int show(dynamic kind) { switch (kind) { case 'opencode': return 1; default: return 0; } }",
    'int show(dynamic kind) => switch (kind) { HarnessKind.opencode => 1, _ => 0 };',
    "bool show(dynamic kind) { if (kind case 'opencode') return true; return false; }",
    "const vendor = 'opencode'; bool show(dynamic kind) => kind == vendor;",
  ]) {
    test(
      'features reject switch, pattern and constant aliases: $source',
      () => reject('harness-branch', {
        'lib/features/chat/branch.dart': '$source\n',
      }),
    );
  }

  test(
    'get_it imports are restricted to the exact composition root',
    () => reject('get-it-boundary', {
      'lib/app/router.dart': "import 'package:get_it/get_it.dart';\n",
    }),
  );

  for (final declaration in [
    'GetIt locator() => GetIt.I;',
    'GetIt locator() { return GetIt.I; }',
    'final locator = () => GetIt.I;',
    'final locator = () { return GetIt.I; };',
  ]) {
    test(
      'widgets reject locator factories: $declaration',
      () => reject('widget-locator', {
        'lib/app/composition_root.dart':
            "import 'package:get_it/get_it.dart'; $declaration class Page extends StatelessWidget { Object build() => locator().get<Object>(); }\n",
      }),
    );
  }

  test(
    'widgets reject service locator lookup tearoffs',
    () => reject('widget-locator', {
      'lib/app/composition_root.dart':
          "import 'package:get_it/get_it.dart'; final lookup = GetIt.I.get; class Page extends StatelessWidget { Object build() => lookup<Object>(); }\n",
    }),
  );

  for (final source in [
    'class Page extends StatelessWidget { final value = GetIt.I<Object>(); }',
    'class Page extends fw.StatelessWidget { Object build() => gi.GetIt.instance.get<Object>(); }',
    'class PageState extends State<Page> { void ready() { () async => GetIt.I.getAsync<Object>(); } }',
    'final locator = GetIt.instance; class Page extends StatelessWidget { Object build() => locator<Object>(); }',
    'class Page extends StatelessWidget { final GetIt locator; Page(this.locator); Object build() => locator.get<Object>(); }',
  ]) {
    test(
      'widgets reject locator lookups: $source',
      () => reject('widget-locator', {
        'lib/app/composition_root.dart':
            "import 'package:get_it/get_it.dart';\n$source\n",
      }),
    );
  }

  test('symlink cannot hide a governed directory', () async {
    final result = await run(
      changeTree: (root) {
        final hidden = Directory(p.join(root, 'hidden'))..createSync();
        File(
          p.join(hidden.path, 'bad.dart'),
        ).writeAsStringSync("import 'package:dio/dio.dart';\n");
        Link(p.join(root, 'lib/features')).createSync(hidden.path);
      },
    );
    expect(result.exitCode, 1);
    expect(result.stderr.toString(), contains('[scope]'));
  });

  for (final invocation in [
    'locator<Object>()',
    'root.locator.get<Object>()',
  ]) {
    test(
      'imported locator facade cannot hide widget lookup: $invocation',
      () => reject('widget-locator', {
        'lib/app/composition_root.dart':
            "import 'package:get_it/get_it.dart'; final locator = GetIt.instance;\n",
        'lib/app/facade.dart': "export 'composition_root.dart' show locator;\n",
        'lib/app/page.dart':
            "import 'facade.dart'${invocation.startsWith('root.') ? ' as root' : ''}; class Page extends StatelessWidget { Object build() => $invocation; }\n",
      }),
    );
  }

  test('local scopes and ordinary shadowed aliases remain valid', () async {
    final result = await run(
      files: {
        'lib/features/chat/scopes.dart':
            "void unrelated() { const kind = 'opencode'; } bool valid(String kind) => kind == 'generic';\n",
        'lib/app/composition_root.dart':
            "import 'package:get_it/get_it.dart'; final locator = GetIt.I; class Page extends StatelessWidget { Object build(Object Function() locator) => locator(); }\n",
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test(
    'locator re-exported through an imported alias is still detected',
    () => reject('widget-locator', {
      'lib/app/composition_root.dart':
          "import 'package:get_it/get_it.dart'; final locator = GetIt.instance;\n",
      'lib/app/facade.dart':
          "import 'composition_root.dart' as root; final exposed = root.locator;\n",
      'lib/app/page.dart':
          "import 'facade.dart' show exposed; class Page extends StatelessWidget { Object build() => exposed<Object>(); }\n",
    }),
  );

  test(
    'ordinary functions outside composition cannot use imported locator',
    () => reject('get-it-boundary', {
      'lib/app/composition_root.dart':
          "import 'package:get_it/get_it.dart'; final locator = GetIt.instance;\n",
      'lib/shared/leak.dart':
          "import '../app/composition_root.dart'; Object read() => locator<Object>();\n",
    }),
  );

  test(
    'imported custom widget base does not hide a lookup',
    () => reject('widget-locator', {
      'lib/shared/base.dart': 'class CustomBase extends StatelessWidget {}\n',
      'lib/app/composition_root.dart':
          "import '../shared/base.dart'; import 'package:get_it/get_it.dart'; class Page extends CustomBase { Object build() => GetIt.I<Object>(); }\n",
    }),
  );

  test(
    'hidden governed files are checked',
    () => reject('dio-boundary', {
      'lib/shared/.internal/network.dart': "import 'package:dio/dio.dart';\n",
    }),
  );

  test('1,500 lines and exact generated size exception remain valid', () async {
    final result = await run(
      files: {
        'lib/shared/boundary.dart':
            '${List.filled(1500, '// authored line').join('\n')}\n',
        'lib/shared/generated.dart':
            '// GENERATED CODE\n${List.filled(1500, '// generated line').join('\n')}\n',
      },
      changeManifest: (value) {
        (value['generated'] as List).add({
          'path': 'lib/shared/generated.dart',
          'reason': 'Recorded generator output.',
        });
        (value['sizeExceptions'] as List).add({
          'path': 'lib/shared/generated.dart',
          'category': 'generated',
          'reason': 'Recorded generator emits one large library.',
        });
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test(
    'production build directories are governed',
    () => reject('dio-boundary', {
      'packages/codewalk_core/lib/build/hidden.dart':
          "import 'package:dio/dio.dart';\n",
    }),
  );

  test(
    'tool facade cannot escape governed source rules',
    () => reject('scope', {
      'lib/shared/facade.dart': "import '../../tool/helper.dart';\n",
      'tool/helper.dart': 'class Helper {}\n',
    }),
  );

  test(
    'package cache is not an authored import escape',
    () => reject('scope', {
      'packages/harness_host/lib/harness_host.dart':
          "import '../build/helper.dart';\n",
      'packages/harness_host/build/helper.dart': 'class Helper {}\n',
    }),
  );

  for (final expression in ['openCodeName', 'names.openCodeName', 'aliased']) {
    test(
      'imported harness constants cannot hide branches: $expression',
      () => reject('harness-branch', {
        'lib/shared/names.dart': "const openCodeName = 'opencode';\n",
        'lib/shared/facade.dart':
            "import 'names.dart' as names; const aliased = names.openCodeName; export 'names.dart' show openCodeName;\n",
        'lib/features/chat/page.dart':
            "import '../../shared/facade.dart'${expression.startsWith('names.') ? ' as names' : ''}; bool show(dynamic kind) => kind == $expression;\n",
      }),
    );
  }

  test('imported harness labels used only for display remain valid', () async {
    final result = await run(
      files: {
        'lib/shared/names.dart': "const openCodeName = 'OpenCode';\n",
        'lib/features/chat/page.dart':
            "import '../../shared/names.dart' as names; String label() => names.openCodeName;\n",
      },
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  for (final alias in [
    'typedef WidgetBase = StatelessWidget;',
    'mixin M {} class WidgetBase = StatelessWidget with M;',
  ]) {
    test(
      'widget type aliases cannot hide service lookups: $alias',
      () => reject('widget-locator', {
        'lib/app/composition_root.dart':
            "import 'package:get_it/get_it.dart'; $alias class Page extends WidgetBase { Object build() => GetIt.I<Object>(); }\n",
      }),
    );
  }

  test(
    'ordinary composition wiring, display labels and comments are valid',
    () async {
      final result = await run(
        files: {
          'lib/app/composition_root.dart':
              "import 'package:get_it/get_it.dart'; Object resolve() => GetIt.I<Object>();\n",
          'lib/features/chat/labels.dart': '''
// import 'package:harness_opencode/harness_opencode.dart';
const label = 'OpenCode';
const sample = "GetIt.I<Object>(); import 'dart:io';";
String display() => label;
bool canUndo(dynamic capabilities) => capabilities.undo == true;
''',
        },
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
    },
  );
}
