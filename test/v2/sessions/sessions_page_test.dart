import 'package:codewalk/app/composition_root.dart';
import 'package:codewalk/app/v2_bootstrap.dart';
import 'package:codewalk/shared/l10n/generated/v2_localizations.dart';
import 'package:codewalk/shared/sessions/session_catalog_changes.dart';
import 'package:codewalk/shared/sessions/session_catalog_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../hosts/fakes.dart';
import 'fakes.dart';
import 'live_fakes.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    for (final locale in V2Localizations.supportedLocales) {
      testWidgets(
        'catalog selection, paging and metadata at $size/${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final rig = CatalogRig();
          await rig.save('a');
          final dependencies = createAppDependencies(
            initialLink: Uri(path: '/sessions'),
            profileRepository: rig.repository,
            endpointProber: FakeProber(),
            sessionCatalogFactory: rig.create,
            sessionLiveDirectory: LiveDirectory.new,
          );
          dependencies.preferences.setLocale(locale);
          await tester.pumpWidget(
            CodeWalkV2Bootstrap(dependencies: dependencies),
          );
          await tester.pumpAndSettle();
          final controller = dependencies.sessions!;
          final l10n = dependencies.localizations.current;
          expect(rig.sources, isEmpty);
          final dropdown = tester.widget<DropdownButton<String>>(
            find.byKey(const ValueKey('sessions-profile')),
          );
          expect(dropdown.value, isNull);
          dropdown.onChanged!('profile_a');
          await tester.pump();
          final source = rig.sources.single;
          source.respond([source.row('first', title: '')], next: 'A');
          await tester.pumpAndSettle();
          expect(find.text(l10n.sessionExportUntitled), findsOneWidget);
          final row = find.byKey(ValueKey(source.row('first').info.ref));
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.text(l10n.historyReadOnly), findsOneWidget);
          expect(
            dependencies.router.routeInformationProvider.value.uri.path,
            '/sessions',
          );
          final more = find.byKey(const ValueKey('sessions-more'));
          await tester.ensureVisible(more);
          await tester.tap(more);
          await tester.pump();
          source.respond([source.row('second')]);
          await tester.pumpAndSettle();
          expect(controller.sessions, hasLength(2));
          expect(
            controller.selectedSession?.info.ref,
            source.row('first').info.ref,
          );
          expect(
            Directionality.of(tester.element(find.byType(Scaffold))),
            {'ar', 'ur'}.contains(locale.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(source.closes, 1);
          rig.dispose();
        },
      );
    }
  }

  testWidgets(
    'empty hosts, auth recovery and source failures remain actionable',
    (tester) async {
      final rig = CatalogRig();
      final dependencies = createAppDependencies(
        profileRepository: rig.repository,
        endpointProber: FakeProber(),
        sessionCatalogFactory: rig.create,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      expect(
        find.text(dependencies.localizations.current.serversNoServersFound),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('sessions-hosts')));
      await tester.pumpAndSettle();
      expect(
        dependencies.router.routeInformationProvider.value.uri.path,
        '/hosts',
      );
      await rig.save('a');
      await dependencies.hosts.load();
      dependencies.router.go('/sessions');
      await tester.pumpAndSettle();
      final read = dependencies.sessions!.selectProfile('profile_a');
      rig.sources.single.fail(SessionCatalogFailure.authenticationRequired);
      await read;
      await tester.pumpAndSettle();
      expect(
        find.text(dependencies.localizations.current.hostsAuthRequired),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sessions-hosts')), findsOneWidget);
      expect(
        find.text(dependencies.localizations.current.sessionsEmpty),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      rig.dispose();
    },
  );

  testWidgets('long plaintext title and 2x text scale fit compact RTL layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rig = CatalogRig();
    await rig.save('a');
    final dependencies = createAppDependencies(
      profileRepository: rig.repository,
      endpointProber: FakeProber(),
      sessionCatalogFactory: rig.create,
      sessionLiveDirectory: LiveDirectory.new,
    );
    dependencies.preferences.setLocale(const Locale('ar'));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: CodeWalkV2Bootstrap(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
    final read = dependencies.sessions!.selectProfile('profile_a');
    final source = rig.sources.single;
    final title = '**not markdown** ${'long '.padRight(400, 'x')}';
    source.respond([source.row('one', title: title)]);
    await read;
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(ValueKey(source.row('one').info.ref)),
    );
    await tester.tap(find.byKey(ValueKey(source.row('one').info.ref)));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    rig.dispose();
  });

  testWidgets(
    'a session created elsewhere appears without a manual refresh',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = CatalogRig();
      final directory = LiveDirectory();
      await rig.save('a');
      final dependencies = createAppDependencies(
        initialLink: Uri(path: '/sessions'),
        profileRepository: rig.repository,
        endpointProber: FakeProber(),
        sessionCatalogFactory: rig.create,
        sessionLiveDirectory: () => directory,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      final controller = dependencies.sessions!;
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('sessions-profile')),
      );
      dropdown.onChanged!('profile_a');
      await tester.pump();
      final source = rig.sources.single;
      source.respond([source.row('first')]);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(source.row('first').info.ref)), findsOneWidget);

      // A session starts elsewhere: the endpoint's stream reports it and the
      // list re-reads itself, without a manual refresh.
      directory.feeds.last.emit(const SessionCatalogChanged());
      // The catalog debounces the re-read; the clock has to pass it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      source.respond([source.row('first'), source.row('second')]);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(source.row('second').info.ref)), findsOneWidget);
      expect(controller.sessions, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.dispose();
    },
  );

  testWidgets(
    'a failed re-read keeps the rows and says the list is not up to date',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rig = CatalogRig();
      final directory = LiveDirectory();
      await rig.save('a');
      final dependencies = createAppDependencies(
        initialLink: Uri(path: '/sessions'),
        profileRepository: rig.repository,
        endpointProber: FakeProber(),
        sessionCatalogFactory: rig.create,
        sessionLiveDirectory: () => directory,
      );
      await tester.pumpWidget(CodeWalkV2Bootstrap(dependencies: dependencies));
      await tester.pumpAndSettle();
      final l10n = dependencies.localizations.current;
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('sessions-profile')),
      );
      dropdown.onChanged!('profile_a');
      await tester.pump();
      final source = rig.sources.single;
      source.respond([source.row('first')]);
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveStale), findsNothing);

      directory.feeds.last.emit(const SessionCatalogChanged());
      // The catalog debounces the re-read; the clock has to pass it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      source.fail(SessionCatalogFailure.connection);
      await tester.pumpAndSettle();
      expect(find.text(l10n.liveStale), findsOneWidget);
      expect(find.byKey(ValueKey(source.row('first').info.ref)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      rig.dispose();
    },
  );
}
