import 'package:codewalk/features/sessions/project_catalog.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProjectInfo entry(CatalogSource source, String path, [String? icon]) =>
    ProjectInfo(
      ProjectRef(source.harness.host, path),
      icon: icon == null ? null : Uri.parse(icon),
    );

class ThrowingSource extends CatalogSource {
  ThrowingSource() : super(profile('a'));
  @override
  CatalogRead<List<ProjectInfo>> projects() => throw StateError('unavailable');
}

void main() {
  late ProjectCatalog catalog;
  var notifications = 0;
  setUp(() {
    notifications = 0;
    catalog = ProjectCatalog(
      notify: () => notifications++,
      refreshInterval: Duration.zero,
    );
  });
  tearDown(() => catalog.dispose());

  test(
    'one read is shared, foreign hosts and duplicate directories excluded',
    () async {
      final source = CatalogSource(profile('a'));
      catalog.bind(source);
      final first = catalog.read();
      expect(identical(first, catalog.read(refresh: true)), isTrue);
      await settle();
      final icon = entry(source, '/app', 'https://example.com/icon.svg');
      source.projectReads.single.completion.complete([
        icon,
        entry(source, '/app'),
        entry(CatalogSource(profile('b')), '/other'),
      ]);
      expect(await first, [icon]);
      expect(catalog.iconFor(icon.ref), icon.icon);
      expect(
        catalog.iconFor(const ProjectRef(HostId('profile_b'), '/app')),
        isNull,
      );
      expect(catalog.iconFor(null), isNull);
      expect(await catalog.read(), [icon]);
      expect(source.projectReads, hasLength(1));
      expect(notifications, 1);
    },
  );

  test(
    'binding and credential replacement cancel stale replies and clear icons',
    () async {
      final a = CatalogSource(profile('a'));
      catalog.bind(a);
      await settle();
      a.projectReads.single.completion.complete([
        entry(a, '/app', 'https://example.com/a'),
      ]);
      await settle();
      expect(catalog.iconAt('/app'), isNotNull);
      final pending = catalog.read(refresh: true);
      await settle();
      final replacement = CatalogSource(profile('a'));
      catalog.bind(replacement);
      expect(catalog.iconAt('/app'), isNull);
      expect(a.projectReads.last.cancelled, isTrue);
      await settle();
      replacement.projectReads.single.completion.complete([
        entry(replacement, '/app', 'https://example.com/b'),
      ]);
      a.projectReads.last.completion.complete([
        entry(a, '/app', 'https://example.com/stale'),
      ]);
      expect(await pending, isEmpty);
      await settle();
      expect(catalog.iconAt('/app').toString(), 'https://example.com/b');
      catalog.dispose();
      expect(catalog.entries, isEmpty);
    },
  );

  test('failure keeps data and waits for a new refresh', () async {
    final source = CatalogSource(profile('a'));
    catalog.bind(source);
    await settle();
    source.projectReads.single.completion.complete([entry(source, '/app')]);
    await settle();
    final refresh = catalog.read(refresh: true);
    await settle();
    source.projectReads.last.completion.completeError(StateError('offline'));
    expect(await refresh, hasLength(1));
    expect(await catalog.read(), hasLength(1));
    expect(source.projectReads, hasLength(2));
  });

  test('events during reads and bursts get a single following pass', () async {
    final source = CatalogSource(profile('a'));
    catalog.bind(source);
    await settle();
    catalog.changed();
    catalog.changed();
    source.projectReads.single.completion.complete([]);
    await settle();
    expect(source.projectReads, hasLength(2));
    source.projectReads.last.completion.complete([entry(source, '/changed')]);
    await settle();
    expect(catalog.entries.single.ref.canonicalDirectory, '/changed');
    expect(source.tasks, isEmpty);
  });

  test('a throwing source does not leave a completed future latched', () async {
    catalog.bind(ThrowingSource());
    expect(await catalog.read(), isEmpty);
    expect(await catalog.read(refresh: true), isEmpty);
    expect(notifications, 2);
  });

  test(
    'dispose before dispatch opens no read and rejects later completion',
    () async {
      final source = CatalogSource(profile('a'));
      catalog.bind(source);
      catalog.dispose();
      await settle();
      expect(source.projectReads, isEmpty);
      catalog.bind(source);
      await settle();
      final pending = catalog.read();
      catalog.dispose();
      expect(source.projectReads.single.cancelled, isTrue);
      source.projectReads.single.completion.complete([entry(source, '/late')]);
      expect(await pending, isEmpty);
    },
  );
}
