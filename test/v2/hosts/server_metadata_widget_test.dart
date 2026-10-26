import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/platform/storage/metadata_store.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';

import '../sessions/fakes.dart';
import '../sessions/live_fakes.dart';
import '../storage/storage_fakes.dart';
import 'fakes.dart';

class _EmptyCatalog extends CatalogSource {
  _EmptyCatalog(super.profile);

  @override
  CatalogTask list(SessionQuery query) {
    final task = super.list(query);
    task.completion.complete(Page(items: const []));
    return task;
  }
}

void main() {
  for (final (locale, width, scale) in [
    ('en', 390.0, 1.0),
    ('ar', 390.0, 2.0),
    ('ur', 1280.0, 2.0),
  ]) {
    testWidgets('server metadata actions: $locale/$width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final a = profile('a');
      final b = profile('b');
      final repo = MemoryProfiles()
        ..profiles.addAll([a, b])
        ..secrets.addAll({a.id: 'fake-a', b.id: 'fake-b'});
      final sources = <_EmptyCatalog>[];
      final prober = FakeProber();
      final graph = createAppDependencies(
        initialLink: Uri(path: '/hosts'),
        profileRepository: repo,
        metadataStore: V2MetadataStore(backend: FakeMetadataBackend()),
        endpointProber: prober,
        sessionLiveDirectory: LiveDirectory.new,
        sessionCatalogFactory: (profile, credential) {
          final source = _EmptyCatalog(profile);
          sources.add(source);
          return source;
        },
      );
      await graph.preferences.initialize();
      graph.preferences.setLocale(Locale(locale));
      await tester.pumpWidget(
        CodeWalkV2Bootstrap(
          dependencies: graph,
          dynamicColors: (builder) => builder(null, null),
        ),
      );
      await tester.pumpAndSettle();
      await graph.sessions!.selectProfile(a.id);
      await tester.pumpAndSettle();
      final l = graph.localizations.current;
      final selected = graph.sessions!.selectedProfile!.id;
      expect(selected, a.id);
      expect(find.byKey(ValueKey('server-active-${a.id}')), findsOneWidget);

      Future<void> action(EndpointProfile p, String title) async {
        final menu = find.byKey(ValueKey('endpoint-actions-${p.id}'));
        await tester.ensureVisible(menu);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(title).hitTestable());
        await tester.pumpAndSettle();
      }

      final probes = prober.tasks.length;
      final catalogs = sources.length;
      await action(b, l.serversSetDefault);
      expect(graph.workspace!.defaultProfile, b.id);
      expect(graph.sessions!.selectedProfile!.id, selected);
      expect(find.byKey(ValueKey('server-default-${b.id}')), findsOneWidget);
      expect(sources.length, catalogs);
      expect(prober.tasks.length, probes);
      await action(b, l.serversClearDefault);
      expect(graph.workspace!.defaultProfile, isNull);
      expect(graph.sessions!.selectedProfile!.id, selected);
      expect(find.byKey(ValueKey('server-default-${b.id}')), findsNothing);

      await action(a, l.serversEdit);
      await tester.enterText(
        find.byKey(const ValueKey('edit-endpoint-label')),
        'Renamed active server',
      );
      await tester.tap(find.byKey(const ValueKey('edit-endpoint-save')));
      await tester.pumpAndSettle();
      expect(repo.profiles.first.label, 'Renamed active server');
      expect(repo.profiles.first.bindingRevision, 0);
      expect(graph.sessions!.selectedProfile!.id, selected);
      expect(sources.length, catalogs);
      expect(prober.tasks.length, probes);

      await action(repo.profiles.first, l.serversEdit);
      await tester.enterText(
        find.byKey(const ValueKey('edit-endpoint-url')),
        'http://127.0.0.1:4096/edited/',
      );
      await tester.tap(find.byKey(const ValueKey('edit-endpoint-save')));
      await tester.pumpAndSettle();
      expect(repo.profiles.first.bindingRevision, 1);
      expect(repo.profiles.first.endpoint.path, '/edited/');
      expect(sources.length, greaterThan(catalogs));
      expect(graph.sessions!.selectedProfile!.endpoint.path, '/edited/');
      expect(graph.sessions!.selectedProfile!.id, selected);
      expect(tester.takeException(), isNull);
    });
  }
}
