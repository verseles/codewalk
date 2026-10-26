import 'dart:async';

import 'package:codewalk/features/sessions/project_contexts_controller.dart';
import 'package:codewalk/features/sessions/project_picker_controller.dart';
import 'package:codewalk/platform/sessions/project_workspace_store.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/storage_fakes.dart';
import 'fakes.dart';

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _host = HostId('profile_a');

FileEntry _folder(String location, String path) => FileEntry(
  ref: FileRef(project: ProjectRef(_host, location), path: path),
  kind: const OpenValue.known(FileKind.directory),
);

FileEntry _file(String location, String path) => FileEntry(
  ref: FileRef(project: ProjectRef(_host, location), path: path),
  kind: const OpenValue.known(FileKind.file),
);

void main() {
  late CatalogRig rig;
  late ProjectContextsController contexts;
  late ProjectPickerController picker;
  var opened = false;

  CatalogSource source() => rig.sources.single;

  Future<void> open({Duration debounce = Duration.zero}) async {
    opened = true;
    rig = CatalogRig(withFeed: false);
    contexts = ProjectContextsController(
      catalog: rig.sessions,
      store: ProjectWorkspaceStore(
        store: V2MetadataStore(backend: FakeMetadataBackend()),
      ),
    );
    await rig.save('a');
    await rig.sessions.initialize();
    await contexts.initialize();
    final read = rig.sessions.selectProfile('profile_a');
    source().respond([
      source().row('w1', directory: '/work/web'),
      source().row('a1', directory: '/work/api'),
    ]);
    await read;
    await settle();
    picker = ProjectPickerController(
      catalog: rig.sessions,
      contexts: contexts,
      debounce: debounce,
    )..start();
  }

  tearDown(() {
    if (!opened) return;
    opened = false;
    picker.dispose();
    contexts.dispose();
    rig.dispose();
  });

  test('exact and prefix matches rank ahead of ordered fuzzy ones', () {
    expect(projectMatchScore('/work/web', 'web'), 0);
    expect(projectMatchScore('/work/web', '/work/web'), 0);
    expect(projectMatchScore('/work/webapp', 'web'), 1);
    expect(projectMatchScore('/work/old-web', '/work'), 2);
    expect(projectMatchScore('/work/old-web', 'web'), 3);
    expect(projectMatchScore('/srv/web/site', 'web'), 4);
    expect(projectMatchScore('/work/my-website', 'mws'), 5);
    expect(projectMatchScore('/work/x', 'wx'), 6);
    expect(projectMatchScore('/work/x', 'zz'), isNull);
  });

  test('known projects, server projects and found folders merge', () async {
    await open();
    expect(contexts.active, '/work/web');
    source().projectReads.single.completion.complete([
      const ProjectRef(_host, '/work/web'),
      const ProjectRef(_host, '/srv/tools'),
    ]);
    await settle();
    expect(
      [for (final entry in picker.results) entry.directory],
      ['/work/web', '/srv/tools'],
    );
    expect(picker.results.first.source, ProjectPickerSource.open);

    picker.setQuery('to');
    await settle();
    final (base, query, find) = source().findReads.single;
    expect((base, query), ('/work/web', 'to'));
    find.completion.complete([
      _folder('/work/web', 'docs/tools'),
      _folder('/work/web', '../tooling'),
    ]);
    await settle();
    expect(
      [for (final entry in picker.results) entry.directory],
      ['/srv/tools', '/work/web/docs/tools', '/work/tooling'],
    );
    expect(picker.results.last.source, ProjectPickerSource.found);
  });

  test('a late search reply never replaces a newer one', () async {
    await open();
    picker.setQuery('alp');
    await settle();
    final first = source().findReads.single.$3;
    picker.setQuery('bet');
    await settle();
    expect(first.cancelled, isTrue);
    final second = source().findReads.last.$3;
    second.completion.complete([_folder('/work/web', 'beta')]);
    first.completion.complete([_folder('/work/web', 'alpha')]);
    await settle();
    expect(
      [for (final entry in picker.results) entry.directory],
      ['/work/web/beta'],
    );
  });

  test('a new query drops the folders found for the previous one', () async {
    await open();
    picker.setQuery('alp');
    await settle();
    source().findReads.single.$3.completion.complete([
      _folder('/work/web', 'alpha'),
    ]);
    await settle();
    expect([
      for (final entry in picker.results) entry.directory,
    ], contains('/work/web/alpha'));
    picker.setQuery('zzz');
    expect([
      for (final entry in picker.results) entry.directory,
    ], isNot(contains('/work/web/alpha')));
  });

  test('a folder the server returned is opened exactly as returned', () async {
    await open();
    picker.setQuery('spa');
    await settle();
    source().findReads.single.$3.completion.complete([
      _folder('/work/web', 'space '),
    ]);
    await settle();
    final found = picker.results.singleWhere(
      (entry) => entry.source == ProjectPickerSource.found,
    );
    final opening = picker.open(found);
    await settle();
    expect(source().locationReads.last.$1, '/work/web/space ');
    source().locationReads.last.$2.completion.complete(
      const ProjectRef(_host, '/work/web/space '),
    );
    expect(await opening, isTrue);
    expect(contexts.active, '/work/web/space ');
  });

  test(
    'a completed server path stays exact; failures belong to their query',
    () async {
      await open();
      picker.setQuery('spa');
      await settle();
      source().findReads.single.$3.completion.complete([
        _folder('/work/web', 'space '),
      ]);
      await settle();
      picker.moveHighlight(1);
      final completed = picker.completion()!;
      expect(completed, '/work/web/space ');
      picker.setQuery(completed);
      final opening = picker.openPath(completed, typed: true);
      await settle();
      expect(source().locationReads.last.$1, '/work/web/space ');
      source().locationReads.last.$2.completion.completeError(
        const SessionCatalogException(SessionCatalogFailure.notFound),
      );
      expect(await opening, isFalse);
      expect(picker.failure, ProjectPickerFailure.open);
      picker.setQuery('/other');
      expect(picker.failure, ProjectPickerFailure.none);
    },
  );

  test('a late open failure is not shown against a newer query', () async {
    await open();
    picker.setQuery('/missing');
    final opening = picker.openPath('/missing', typed: true);
    await settle();
    picker.setQuery('/other');
    source().locationReads.last.$2.completion.completeError(
      const SessionCatalogException(SessionCatalogFailure.notFound),
    );
    expect(await opening, isFalse);
    expect(picker.failure, ProjectPickerFailure.none);
  });

  test('an absolute path is opened as the server resolves it', () async {
    await open();
    for (final path in ['/opt/x', 'C:/', r'C:\work', r'\\srv\share\repo']) {
      picker.setQuery(path);
      expect(picker.canOpenPath, isTrue, reason: path);
    }
    picker.setQuery('C:');
    expect(picker.canOpenPath, isFalse);
    // An absolute path is not searched.
    expect(source().findReads, isEmpty);

    final opening = picker.openPath('/opt/x/');
    final (asked, location) = source().locationReads.last;
    expect(asked, '/opt/x/');
    location.completion.complete(const ProjectRef(_host, '/opt/x'));
    expect(await opening, isTrue);
    expect(contexts.active, '/opt/x');

    final failing = picker.openPath('/missing');
    source().locationReads.last.$2.completion.completeError(
      const SessionCatalogException(SessionCatalogFailure.notFound),
    );
    expect(await failing, isFalse);
    expect(picker.failure, ProjectPickerFailure.open);
    expect(contexts.active, '/opt/x');
  });

  test('the browser lists folders resolved against the location', () async {
    await open();
    final browsing = picker.startBrowsing();
    await settle();
    final (base, path, list) = source().listReads.single;
    expect((base, path), ('/work/web', '/work/web'));
    list.completion.complete([
      _folder('/work/web', 'src'),
      _file('/work/web', 'README.md'),
      _folder('/work/web', '../api'),
    ]);
    await browsing;
    expect(picker.browseEntries, ['/work/web/src', '/work/api']);
    final up = picker.browseUp();
    await settle();
    expect(source().listReads.last.$2, '/work');
    source().listReads.last.$3.completion.complete([]);
    await up;
    expect(picker.browseDirectory, '/work');
    picker.stopBrowsing();
    expect(picker.browsing, isFalse);
  });

  test('closed projects reopen; history entries can be forgotten', () async {
    await open();
    expect(await contexts.openContext('/work/api'), isTrue);
    expect(await contexts.close('/work/api'), isTrue);
    final closed = picker.results.singleWhere(
      (entry) => entry.source == ProjectPickerSource.closed,
    );
    expect(await picker.forget(closed.directory), isTrue);
    expect(contexts.closed, isEmpty);
    expect(await contexts.openContext('/work/api'), isTrue);
    expect(await contexts.close('/work/api'), isTrue);
    final again = picker.results.singleWhere(
      (entry) => entry.source == ProjectPickerSource.closed,
    );
    expect(await picker.open(again), isTrue);
    expect(contexts.active, '/work/api');
  });

  test('a change of server dismisses the picker', () async {
    await open();
    await rig.save('b');
    expect(picker.dismissed, isFalse);
    unawaited(rig.sessions.selectProfile('profile_b'));
    await settle();
    expect(picker.dismissed, isTrue);
    expect(await picker.openPath('/opt/x'), isFalse);
  });
}
